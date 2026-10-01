#!/usr/bin/env python3
"""
Tree Format Demonstration
------------------------
This script demonstrates loading and displaying the Arachnida key tree
in various formats.
"""

import os
import json
import pickle
import sys

def print_separator():
    """Print a separator line."""
    print("\n" + "="*70 + "\n")

def demo_generic():
    """Demonstrate the generic JSON format."""
    print("GENERIC JSON FORMAT")
    print("-----------------")
    
    try:
        with open('tree_formats/arachnida_generic.json', 'r') as f:
            tree_data = json.load(f)
        
        print(f"Tree title: {tree_data['title']}")
        print(f"Root node: {tree_data['root']}")
        print(f"Number of nodes: {len(tree_data['nodes'])}")
        
        # Display the first few nodes
        print("\nSample nodes:")
        for i, (node_id, node) in enumerate(list(tree_data['nodes'].items())[:5]):
            print(f"  Node {node_id}: {node['content']}")
            if node['order']:
                print(f"    Order: {node['order']}")
            if node['choice_a']:
                print(f"    Choice A (Yes) → {node['choice_a']}")
            if node['choice_b']:
                print(f"    Choice B (No) → {node['choice_b']}")
            print()
        
        return True
    except Exception as e:
        print(f"Error demonstrating generic format: {e}")
        return False

def demo_anytree():
    """Demonstrate the anytree format."""
    print("ANYTREE FORMAT")
    print("-------------")
    
    try:
        from anytree.importer import JsonImporter
        from anytree import RenderTree
        
        # Import the tree
        importer = JsonImporter()
        with open('tree_formats/arachnida_anytree.json', 'r') as f:
            root = importer.read(f)
        
        # Print tree structure
        print("Tree structure (first 10 nodes):")
        for i, (pre, _, node) in enumerate(RenderTree(root)):
            print(f"{pre}{node.name}")
            if i >= 9:  # Display only first 10 nodes
                print(f"{pre}...")
                break
        
        return True
    except ImportError:
        print("anytree library not installed. Skipping demonstration.")
        return False
    except Exception as e:
        print(f"Error demonstrating anytree format: {e}")
        return False

def demo_treelib():
    """Demonstrate the treelib format."""
    print("TREELIB FORMAT")
    print("-------------")
    
    try:
        from treelib import Tree
        
        # Load the tree data
        with open('tree_formats/arachnida_treelib.json', 'r') as f:
            tree_data = json.load(f)
        
        # Reconstruct the tree
        tree = Tree()
        
        # Add the title node
        for node in tree_data['nodes']:
            if node['id'] == 'title':
                tree.create_node(node['tag'], node['id'])
                break
        
        # Add the first few nodes (for demonstration)
        nodes_to_add = []
        edges_to_add = []
        
        # Find the root node
        for edge in tree_data['edges']:
            if edge['source'] == 'title':
                root_id = edge['target']
                edges_to_add.append(edge)
                nodes_to_add.append(next(n for n in tree_data['nodes'] if n['id'] == root_id))
                break
        
        # Add some child nodes
        for edge in tree_data['edges']:
            if edge['source'] == root_id and len(edges_to_add) < 5:
                edges_to_add.append(edge)
                nodes_to_add.append(next(n for n in tree_data['nodes'] if n['id'] == edge['target']))
        
        # Add the nodes to the tree
        for node in nodes_to_add:
            # Find its parent
            parent_id = next((e['source'] for e in edges_to_add if e['target'] == node['id']), 'title')
            if parent_id in tree.nodes:  # Only add if parent exists
                tree.create_node(node['tag'], node['id'], parent=parent_id)
        
        # Print a truncated view of the tree
        print(tree.show())
        
        return True
    except ImportError:
        print("treelib library not installed. Skipping demonstration.")
        return False
    except Exception as e:
        print(f"Error demonstrating treelib format: {e}")
        return False

def demo_binarytree():
    """Demonstrate the binarytree format."""
    print("BINARYTREE FORMAT")
    print("----------------")
    
    try:
        from binarytree import Node
        
        # Load the tree
        with open('tree_formats/arachnida_binarytree.pkl', 'rb') as f:
            binary_tree = pickle.load(f)
        
        # Print the tree structure
        print(binary_tree)
        
        # Print the metadata for some nodes
        with open('tree_formats/arachnida_binarytree.txt', 'r') as f:
            content = f.read()
        
        # Extract the metadata section
        if "Node Metadata:" in content:
            metadata = content.split("Node Metadata:")[1].strip()
            # Print the first few entries
            lines = metadata.split('\n')
            for line in lines[:5]:
                print(line)
            if len(lines) > 5:
                print("...")
        
        return True
    except ImportError:
        print("binarytree library not installed. Skipping demonstration.")
        return False
    except Exception as e:
        print(f"Error demonstrating binarytree format: {e}")
        return False

def demo_sklearn():
    """Demonstrate the scikit-learn format."""
    print("SCIKIT-LEARN FORMAT")
    print("------------------")
    
    try:
        # Load the mapping
        with open('tree_formats/arachnida_sklearn_mapping.json', 'r') as f:
            mapping = json.load(f)
        
        # Print some info about the mapping
        print(f"Number of nodes in the decision tree: {len(mapping)}")
        print("\nSample node mappings:")
        for i, (idx, data) in enumerate(list(mapping.items())[:5]):
            print(f"Node index {idx}:")
            print(f"  Original ID: {data['id']}")
            print(f"  Content: {data['content'][:50]}...")
            if data['order']:
                print(f"  Order: {data['order']}")
            print()
        
        # Mention the visualization
        print("The decision tree visualization is available in:")
        print("  tree_formats/arachnida_sklearn.png")
        
        return True
    except Exception as e:
        print(f"Error demonstrating scikit-learn format: {e}")
        return False

def main():
    """Demonstrate loading and displaying various tree formats."""
    if not os.path.exists('tree_formats'):
        print("Error: tree_formats directory not found!")
        print("Please run arachnida_tree_formats.py first to generate the tree formats.")
        return
    
    print_separator()
    print("ARACHNIDA KEY TREE FORMAT DEMONSTRATION")
    print_separator()
    
    # Dictionary of demo functions
    demos = {
        "Generic JSON": demo_generic,
        "Anytree": demo_anytree,
        "Treelib": demo_treelib,
        "Binarytree": demo_binarytree,
        "Scikit-learn": demo_sklearn
    }
    
    successful = 0
    for name, func in demos.items():
        print_separator()
        if func():
            successful += 1
        print_separator()
    
    print(f"\nDemonstration completed. Successfully demonstrated {successful}/{len(demos)} formats.")
    print("For full details and code examples on how to use these formats,")
    print("please refer to tree_formats/README.md")

if __name__ == "__main__":
    main() 