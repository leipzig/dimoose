#!/usr/bin/env python3
import os
import re
import json
import pickle
from graphviz import Digraph

# Import the key functions from our existing script
from arachnida_key_tree import get_arachnida_key, parse_key_entries, clean_id, build_tree, Node

# Create output directory
os.makedirs('tree_formats', exist_ok=True)

def save_as_anytree():
    """Save the Arachnida key as anytree format."""
    try:
        from anytree import Node as AnyNode, RenderTree
        from anytree.exporter import DotExporter, JsonExporter
        
        print("Saving as anytree format...")
        
        # Get the parsed key and build our internal tree
        key_entries = get_arachnida_key()
        parsed_entries = parse_key_entries(key_entries)
        root, nodes = build_tree(parsed_entries)
        
        # Create anytree nodes
        anytree_nodes = {}
        
        # First create the root node
        anytree_nodes["title"] = AnyNode(id="title", name="Key to the Orders of Arachnida")
        
        # Create all nodes
        for node_id, node in nodes.items():
            content = node.content
            if node.order:
                content += f" (Order: {node.order})"
            anytree_nodes[node_id] = AnyNode(
                id=node_id, 
                name=content,
                parent=anytree_nodes["title"] if node_id == "1" else None
            )
        
        # Connect nodes
        for node_id, node in nodes.items():
            any_node = anytree_nodes[node_id]
            
            if node.choice_a and node.choice_a.id in anytree_nodes:
                anytree_nodes[node.choice_a.id].parent = any_node
                
            if node.choice_b and node.choice_b.id in anytree_nodes:
                anytree_nodes[node.choice_b.id].parent = any_node
        
        # Export as JSON
        exporter = JsonExporter(indent=2, sort_keys=True)
        with open('tree_formats/arachnida_anytree.json', 'w') as f:
            exporter.write(anytree_nodes["title"], f)
        
        # Export as DOT
        DotExporter(anytree_nodes["title"]).to_picture("tree_formats/arachnida_anytree.png")
        
        print("Anytree format saved to tree_formats/arachnida_anytree.json and .png")
        return True
    except ImportError:
        print("anytree library not installed. Skipping anytree format.")
        return False

def save_as_treelib():
    """Save the Arachnida key as treelib format."""
    try:
        from treelib import Tree
        
        print("Saving as treelib format...")
        
        # Get the parsed key and build our internal tree
        key_entries = get_arachnida_key()
        parsed_entries = parse_key_entries(key_entries)
        root, nodes = build_tree(parsed_entries)
        
        # Create treelib tree
        tree = Tree()
        
        # Add the root node
        tree.create_node("Key to the Orders of Arachnida", "title")
        
        # Add the first node as a child of the title
        if root:
            tree.create_node(f"{root.id}: {root.content}", root.id, parent="title")
        
        # Add all other nodes
        for node_id, node in nodes.items():
            if node_id == "1":  # Skip root, already added
                continue
                
            # Find parent through choice_a or choice_b links
            parent_found = False
            for parent_id, parent_node in nodes.items():
                if (parent_node.choice_a and parent_node.choice_a.id == node_id) or \
                   (parent_node.choice_b and parent_node.choice_b.id == node_id):
                    if not tree.contains(node_id):
                        content = node.content
                        if node.order:
                            content += f" (Order: {node.order})"
                        tree.create_node(f"{node_id}: {content}", node_id, parent=parent_id)
                        parent_found = True
            
            # If no parent found through links, try to infer from ID format
            if not parent_found and not tree.contains(node_id):
                if node_id.endswith("'"):
                    base_id = node_id[:-1]
                    if tree.contains(base_id):
                        content = node.content
                        if node.order:
                            content += f" (Order: {node.order})"
                        tree.create_node(f"{node_id}: {content}", node_id, parent=base_id)
                
                # For nodes like 2(1), parent is 1
                match = re.search(r'\((\d+\'?)\)', node_id)
                if match:
                    parent_id = match.group(1)
                    if tree.contains(parent_id):
                        content = node.content
                        if node.order:
                            content += f" (Order: {node.order})"
                        tree.create_node(f"{node_id}: {content}", node_id, parent=parent_id)
        
        # Save as text
        with open('tree_formats/arachnida_treelib.txt', 'w') as f:
            f.write(tree.show(stdout=False))
        
        # Save as JSON
        tree_dict = {
            "nodes": [],
            "edges": []
        }
        
        for node in tree.all_nodes():
            node_data = {"id": node.identifier, "tag": node.tag}
            tree_dict["nodes"].append(node_data)
            
            if node.identifier != "title":
                parent_id = tree.parent(node.identifier).identifier
                tree_dict["edges"].append({"source": parent_id, "target": node.identifier})
        
        with open('tree_formats/arachnida_treelib.json', 'w') as f:
            json.dump(tree_dict, f, indent=2)
        
        print("Treelib format saved to tree_formats/arachnida_treelib.txt and .json")
        return True
    except ImportError:
        print("treelib library not installed. Skipping treelib format.")
        return False

def save_as_ete3():
    """Save the Arachnida key as ete3 format."""
    try:
        from ete3 import Tree as EteTree
        
        print("Saving as ete3 format...")
        
        # Get the parsed key and build our internal tree
        key_entries = get_arachnida_key()
        parsed_entries = parse_key_entries(key_entries)
        root, nodes = build_tree(parsed_entries)
        
        # Create the root of the tree
        ete_tree = EteTree(name="Key to the Orders of Arachnida")
        
        # Function to recursively build the tree
        def add_children(parent_ete, parent_id):
            parent_node = nodes.get(parent_id)
            if not parent_node:
                return
                
            if parent_node.choice_a:
                choice_a_id = parent_node.choice_a.id
                choice_a_content = parent_node.choice_a.content
                if parent_node.choice_a.order:
                    choice_a_content += f" (Order: {parent_node.choice_a.order})"
                
                child_a = parent_ete.add_child(name=f"{choice_a_id}: {choice_a_content}")
                add_children(child_a, choice_a_id)
            
            if parent_node.choice_b:
                choice_b_id = parent_node.choice_b.id
                choice_b_content = parent_node.choice_b.content
                if parent_node.choice_b.order:
                    choice_b_content += f" (Order: {parent_node.choice_b.order})"
                
                child_b = parent_ete.add_child(name=f"{choice_b_id}: {choice_b_content}")
                add_children(child_b, choice_b_id)
        
        # Start from the root
        if root:
            root_content = root.content
            if root.order:
                root_content += f" (Order: {root.order})"
            root_node = ete_tree.add_child(name=f"1: {root_content}")
            add_children(root_node, "1")
        
        # Save as Newick format
        ete_tree.write(outfile="tree_formats/arachnida_ete3.newick")
        
        # Save in text format for better readability
        with open('tree_formats/arachnida_ete3.txt', 'w') as f:
            f.write(ete_tree.get_ascii(show_internal=True))
        
        print("ETE3 format saved to tree_formats/arachnida_ete3.newick and .txt")
        return True
    except ImportError:
        print("ete3 library not installed. Skipping ete3 format.")
        return False
    except Exception as e:
        print(f"Error saving ETE3 format: {e}")
        return False

def save_as_binarytree():
    """Save the Arachnida key as binarytree format."""
    try:
        from binarytree import Node as BinaryNode, build
        
        print("Saving as binarytree format...")
        
        # Get the parsed key and build our internal tree
        key_entries = get_arachnida_key()
        parsed_entries = parse_key_entries(key_entries)
        root, nodes = build_tree(parsed_entries)
        
        # Create a dictionary to store BinaryNode objects
        binary_nodes = {}
        
        # First pass: Create all nodes without connections
        for node_id, node in nodes.items():
            # Value will be numeric for sorting
            # Convert 1' to 1.5, 2 to 2, etc.
            if node_id.endswith("'"):
                value = float(node_id[:-1]) + 0.5
            else:
                try:
                    value = float(node_id)
                except:
                    value = 0
            
            # Create a binary node with the value and our node data
            content = node.content
            if node.order:
                content = f"{content} (Order: {node.order})"
            binary_nodes[node_id] = BinaryNode(int(value * 10))
            binary_nodes[node_id].val = int(value * 10)  # Numeric value for sorting
            binary_nodes[node_id].meta = f"{node_id}: {content}"  # Store text in metadata
        
        # Second pass: Connect nodes based on choice_a (left) and choice_b (right)
        for node_id, node in nodes.items():
            binary_node = binary_nodes.get(node_id)
            if not binary_node:
                continue
                
            if node.choice_a and node.choice_a.id in binary_nodes:
                binary_node.left = binary_nodes.get(node.choice_a.id)
            if node.choice_b and node.choice_b.id in binary_nodes:
                binary_node.right = binary_nodes.get(node.choice_b.id)
        
        # Get the root binary node
        binary_root = binary_nodes.get("1")
        
        # Save as string representation
        with open('tree_formats/arachnida_binarytree.txt', 'w') as f:
            f.write(str(binary_root))
            # Add metadata mapping
            f.write("\n\nNode Metadata:\n")
            for node_id, binary_node in binary_nodes.items():
                f.write(f"{node_id} (value={binary_node.val}): {binary_node.meta}\n")
        
        # Save as pickle
        with open('tree_formats/arachnida_binarytree.pkl', 'wb') as f:
            pickle.dump(binary_root, f)
        
        print("Binary tree format saved to tree_formats/arachnida_binarytree.txt and .pkl")
        return True
    except ImportError:
        print("binarytree library not installed. Skipping binarytree format.")
        return False
    except Exception as e:
        print(f"Error saving binarytree format: {e}")
        return False

def save_as_btree():
    """Save the Arachnida key as btree format."""
    try:
        import btree
        
        print("Saving as btree format...")
        
        # Get the parsed key and build our internal tree
        key_entries = get_arachnida_key()
        parsed_entries = parse_key_entries(key_entries)
        root, nodes = build_tree(parsed_entries)
        
        # For B-tree, we'll create a list of (key, value) pairs
        # The key will be the node ID, value will be the content
        items = []
        
        for node_id, node in nodes.items():
            # Convert node IDs to strings that can be used as keys
            key = node_id.replace("'", "_prime")
            
            value = {
                "id": node_id,
                "content": node.content,
                "order": node.order,
                "choice_a": node.choice_a.id if node.choice_a else None,
                "choice_b": node.choice_b.id if node.choice_b else None
            }
            
            items.append((key, value))
        
        # Sort items by key for btree
        items.sort(key=lambda x: x[0])
        
        # Create a B-tree and insert items
        t = btree.BTree(order=3)  # Small order for our small tree
        for key, value in items:
            t[key] = value
        
        # Save as pickle
        with open('tree_formats/arachnida_btree.pkl', 'wb') as f:
            pickle.dump(t, f)
        
        # Save keys and structure as text
        with open('tree_formats/arachnida_btree.txt', 'w') as f:
            f.write("B-Tree Keys:\n")
            for key in t.keys():
                f.write(f"{key}\n")
        
        print("B-tree format saved to tree_formats/arachnida_btree.pkl and .txt")
        return True
    except ImportError:
        print("btree library not installed. Skipping btree format.")
        return False

def save_as_sklearn():
    """Save the Arachnida key as scikit-learn tree format."""
    try:
        from sklearn import tree as sklearn_tree
        import numpy as np
        import matplotlib.pyplot as plt
        
        print("Saving as scikit-learn format...")
        
        # Get the parsed key and build our internal tree
        key_entries = get_arachnida_key()
        parsed_entries = parse_key_entries(key_entries)
        _, nodes = build_tree(parsed_entries)
        
        # For scikit-learn, we need to transform our tree into a decision tree
        # We will use the node IDs as features and convert choices to binary decisions
        
        # First, create a mapping of node IDs to indices
        node_ids = list(nodes.keys())
        id_to_index = {node_id: i for i, node_id in enumerate(node_ids)}
        
        # Create a simple decision tree structure
        # Each node will make a decision based on its ID
        X = np.array([[i] for i in range(len(node_ids))])
        
        # For the target, we'll use 1 for nodes that lead to an order (terminal nodes)
        # and 0 for decision nodes
        y = np.array([1 if nodes[node_id].order else 0 for node_id in node_ids])
        
        # Train a decision tree classifier
        clf = sklearn_tree.DecisionTreeClassifier(max_depth=10)
        clf = clf.fit(X, y)
        
        # Save as dot file
        sklearn_tree.export_graphviz(
            clf,
            out_file='tree_formats/arachnida_sklearn.dot',
            feature_names=['Node ID'],
            class_names=['Decision', 'Order'],
            filled=True,
            rounded=True
        )
        
        # Save as PNG using matplotlib
        plt.figure(figsize=(20, 10))
        sklearn_tree.plot_tree(
            clf,
            feature_names=['Node ID'],
            class_names=['Decision', 'Order'],
            filled=True,
            rounded=True,
            fontsize=10
        )
        plt.savefig('tree_formats/arachnida_sklearn.png', dpi=300, bbox_inches='tight')
        plt.close()
        
        # Save the model
        with open('tree_formats/arachnida_sklearn.pkl', 'wb') as f:
            pickle.dump(clf, f)
        
        # Save a mapping of indices to node data for reference
        node_data = {}
        for node_id, index in id_to_index.items():
            node = nodes[node_id]
            node_data[str(index)] = {
                "id": node_id,
                "content": node.content,
                "order": node.order,
                "choice_a": node.choice_a.id if node.choice_a else None,
                "choice_b": node.choice_b.id if node.choice_b else None
            }
        
        with open('tree_formats/arachnida_sklearn_mapping.json', 'w') as f:
            json.dump(node_data, f, indent=2)
        
        print("Scikit-learn format saved to tree_formats/arachnida_sklearn.pkl, .dot, and .png")
        return True
    except ImportError:
        print("scikit-learn library not installed. Skipping scikit-learn format.")
        return False

def save_as_graphviz():
    """Save the Arachnida key as graphviz format."""
    try:
        print("Saving as graphviz format...")
        
        # Get the parsed key and build our internal tree
        key_entries = get_arachnida_key()
        parsed_entries = parse_key_entries(key_entries)
        root, nodes = build_tree(parsed_entries)
        
        # Create graphviz dot object
        dot = Digraph(comment='Key to the Orders of Arachnida')
        dot.attr(rankdir='TB')  # Top to bottom layout
        
        # Add a title node
        dot.node('title', 'Key to the Orders of Arachnida', shape='box', style='filled', fillcolor='lightgreen')
        
        # Add all nodes
        for node_id, node in nodes.items():
            # Format the content
            content = node.content
            if node.order:
                content += f"\nOrder: {node.order}"
                
            # Add the node
            dot.node(node_id, f"{node_id}: {content}", 
                    shape='box', 
                    style='filled', 
                    fillcolor='lightblue' if not node.order else 'lightgreen')
        
        # Add edges
        for node_id, node in nodes.items():
            if node.choice_a:
                dot.edge(node_id, node.choice_a.id, label='Yes', color='darkgreen')
            if node.choice_b:
                dot.edge(node_id, node.choice_b.id, label='No', color='darkred')
        
        # Connect title to root
        if root:
            dot.edge('title', root.id, style='dashed')
        
        # Save as dot file
        dot.save('tree_formats/arachnida_graphviz.dot')
        
        # Render as PNG and PDF
        dot.render('tree_formats/arachnida_graphviz', format='png', cleanup=True)
        dot.render('tree_formats/arachnida_graphviz', format='pdf', cleanup=True)
        
        print("Graphviz format saved to tree_formats/arachnida_graphviz.dot, .png, and .pdf")
        return True
    except Exception as e:
        print(f"Error saving graphviz format: {e}")
        return False

def save_as_json():
    """Save the Arachnida key as a generic JSON format."""
    print("Saving as generic JSON format...")
    
    # Get the parsed key and build our internal tree
    key_entries = get_arachnida_key()
    parsed_entries = parse_key_entries(key_entries)
    root, nodes = build_tree(parsed_entries)
    
    # Create a JSON structure
    tree_data = {
        "title": "Key to the Orders of Arachnida",
        "nodes": {},
        "root": "1"
    }
    
    # Add all nodes to the structure
    for node_id, node in nodes.items():
        tree_data["nodes"][node_id] = {
            "id": node_id,
            "content": node.content,
            "order": node.order,
            "choice_a": node.choice_a.id if node.choice_a else None,
            "choice_b": node.choice_b.id if node.choice_b else None
        }
    
    # Save as JSON
    with open('tree_formats/arachnida_generic.json', 'w') as f:
        json.dump(tree_data, f, indent=2)
    
    print("Generic JSON format saved to tree_formats/arachnida_generic.json")
    return True

def main():
    """Export the Arachnida key in various tree formats."""
    print("Exporting Arachnida key to various tree formats...")
    
    # Save as various formats
    results = [
        save_as_json(),  # Always save as generic JSON
        save_as_graphviz(),  # Always attempt graphviz format
        save_as_anytree(),
        save_as_treelib(),
        save_as_ete3(),
        save_as_binarytree(),
        save_as_btree(),
        save_as_sklearn()
    ]
    
    successful = sum(1 for result in results if result)
    print(f"\nExport completed. Successfully exported to {successful} formats.")
    print(f"All files saved in the 'tree_formats' directory.")

if __name__ == "__main__":
    main() 