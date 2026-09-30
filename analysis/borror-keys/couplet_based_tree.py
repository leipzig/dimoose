#!/usr/bin/env python3
"""
Couplet-Based Tree Generator
----------------------------
This script creates a tree visualization of the Arachnida key based on
couplet relationships rather than Yes/No choices.
"""

import os
import re
import json
from graphviz import Digraph
from arachnida_key_tree import get_arachnida_key, parse_key_entries

def extract_couplet_info(entries):
    """Extract couplet numbers and their relationships."""
    couplets = {}
    
    # Extract all couplet numbers
    for entry in entries:
        # Extract the ID without parenthetical references
        match = re.match(r'(\d+\'?)', entry["id"])
        if match:
            couplet_id = match.group(1)
            couplets[couplet_id] = {
                "content": entry["content"],
                "order": entry["order"],
                "id": entry["id"],
                "children": [],
                "paired_with": None,
                "parent": None
            }
    
    # Find parent-child relationships based on couplet format
    for couplet_id in couplets:
        # Find children through references in content
        for other_id in couplets:
            # Skip self-references
            if other_id == couplet_id:
                continue
                
            # Format: If 10 and 10' are derived from 9, then they start with "10(9)" and "10'(9)"
            parent_match = re.match(r'\d+\'?\((\d+\'?)\)', couplets[other_id]["id"])
            if parent_match and parent_match.group(1) == couplet_id:
                couplets[couplet_id]["children"].append(other_id)
                couplets[other_id]["parent"] = couplet_id
            
            # Find paired couplets (like 1 and 1')
            if not couplet_id.endswith("'"):  # Only for base couplets
                base_id = couplet_id
                if other_id == f"{base_id}'":
                    # Mark them as paired, but not as parent-child
                    couplets[couplet_id]["paired_with"] = other_id
                    couplets[other_id]["paired_with"] = couplet_id
    
    return couplets

def build_tree_from_couplets(couplets):
    """Build a tree structure from couplet relationships."""
    # Find the root node (typically "1")
    root_id = "1"
    if root_id not in couplets:
        raise ValueError("Root couplet '1' not found")
    
    # Create a dictionary of nodes to track the tree structure
    nodes = {}
    for couplet_id, couplet_data in couplets.items():
        nodes[couplet_id] = {
            "id": couplet_id,
            "content": couplet_data["content"],
            "order": couplet_data["order"],
            "full_id": couplet_data["id"],
            "children": couplet_data["children"],
            "paired_with": couplet_data["paired_with"],
            "parent": couplet_data["parent"]
        }
    
    return root_id, nodes

def create_label(node):
    """Create a formatted label for a node."""
    # Format the content with line breaks for readability
    content = node['content']
    # Break at semicolons, periods, and other logical points
    content = content.replace('; ', ';\n')
    content = content.replace('. ', '.\n')
    content = content.replace(') ', ')\n')
    
    # Now couplet numbers are on edges, so node only shows the content
    label = content
    if node['order']:
        label += f"\nOrder: {node['order']}"
    return label

def extract_key_feature(content, max_length=30):
    """Extract a key feature from the content for edge labels."""
    # Try to get the first distinctive feature
    if ';' in content:
        feature = content.split(';')[0]
    elif ',' in content:
        feature = content.split(',')[0]
    else:
        feature = content
    
    # Truncate if too long
    if len(feature) > max_length:
        feature = feature[:max_length-3] + '...'
    
    return feature.strip()

def visualize_couplet_tree(root_id, nodes):
    """Create a visualization of the couplet-based tree."""
    dot = Digraph(comment='Couplet-Based Key to the Orders of Arachnida')
    dot.attr(rankdir='TB')  # Top to bottom layout
    dot.attr(size='14,24')  # Larger canvas
    dot.attr(dpi='300')     # Higher resolution
    dot.attr(overlap='false')  # Minimize node overlap
    dot.attr(splines='true')   # Use curved lines
    dot.attr('node', fontsize='10', fontname='Arial')
    dot.attr('edge', fontsize='9', fontname='Arial')
    
    # Add a title node
    dot.node('title', 'Couplet-Based Key to the Orders of Arachnida', 
             shape='box', style='filled', fillcolor='lightgreen', 
             fontsize='16', fontname='Arial Bold')
    
    # Add special start node
    dot.node('start', 'Start', shape='oval', style='filled', fillcolor='gold')
    
    # Dictionary to track node IDs for content (since we're using content as node IDs now)
    content_to_id = {}
    node_count = 0
    
    # First create all nodes with unique IDs based on their content
    for node_id, node in nodes.items():
        content = node['content']
        # Create a unique ID for this content
        if content in content_to_id:
            continue  # Skip if we've already created a node for this content
            
        node_count += 1
        unique_id = f"node_{node_count}"
        content_to_id[content] = unique_id
        
        # Terminal nodes (with order) in green, others in blue
        fillcolor = '#AAFFAA' if node['order'] else 'lightblue'
        
        label = create_label(node)
        dot.node(unique_id, label, shape='box', style='filled, rounded',
                fillcolor=fillcolor, margin='0.15,0.1')
    
    # Connect title to start
    dot.edge('title', 'start', style='dashed')
    
    # Now add edges with couplet numbers as labels
    # First for couplet 1 and 1'
    start_content_1 = nodes['1']['content']
    start_content_1_prime = nodes['1\'']['content']
    dot.edge('start', content_to_id[start_content_1], label='1', color='darkgreen', fontcolor='darkgreen')
    dot.edge('start', content_to_id[start_content_1_prime], label='1\'', color='darkred', fontcolor='darkred')
    
    # Then for all other connections
    for node_id, node in nodes.items():
        from_content = node['content']
        from_node_id = content_to_id[from_content]
        
        for child_id in node['children']:
            if child_id in nodes and child_id != node.get('paired_with'):
                child_node = nodes[child_id]
                to_content = child_node['content']
                to_node_id = content_to_id[to_content]
                
                # Use couplet number as the edge label
                label = child_id
                
                # Color based on prime or not
                if child_id.endswith("'"):
                    color = 'darkred'
                else:
                    color = 'darkgreen'
                    
                dot.edge(from_node_id, to_node_id, label=label, color=color, fontcolor=color)
    
    # Create output directory if it doesn't exist
    if not os.path.exists('visualizations'):
        os.makedirs('visualizations')
    
    # Render the tree
    dot.render('visualizations/arachnida_couplet_tree_edge_labels', format='png', cleanup=True)
    dot.render('visualizations/arachnida_couplet_tree_edge_labels', format='pdf', cleanup=True)
    
    print(f"Edge-labeled couplet tree visualization saved to visualizations/arachnida_couplet_tree_edge_labels.png and .pdf")

def save_as_json(root_id, nodes):
    """Save the couplet-based tree as JSON."""
    tree_data = {
        "title": "Couplet-Based Key to the Orders of Arachnida",
        "root": root_id,
        "nodes": nodes
    }
    
    # Create output directory if it doesn't exist
    if not os.path.exists('tree_formats'):
        os.makedirs('tree_formats')
    
    # Save as JSON
    with open('tree_formats/arachnida_couplet_tree.json', 'w') as f:
        json.dump(tree_data, f, indent=2)
    
    print(f"Couplet-based tree data saved to tree_formats/arachnida_couplet_tree.json")

def print_tree_structure(root_id, nodes, indent=0, max_depth=None, visited=None):
    """Print the tree structure in a readable format."""
    if visited is None:
        visited = set()
    
    if root_id in visited:
        return
    
    visited.add(root_id)
    
    if max_depth is not None and indent > max_depth:
        print("  " * indent + "...")
        return
    
    node = nodes[root_id]
    prefix = "  " * indent
    
    # Print the current node
    print(f"{prefix}{root_id}: {node['content']}")
    if node['order']:
        print(f"{prefix}  Order: {node['order']}")
    
    # Print children (but not paired couplets)
    for child_id in sorted(node['children']):
        if child_id in nodes and child_id != node.get('paired_with'):
            print_tree_structure(child_id, nodes, indent + 1, max_depth, visited)

def main():
    """Generate a couplet-based tree for the Arachnida key."""
    print("Generating corrected couplet-based tree for the Arachnida key...")
    
    # Get the key entries
    key_entries = get_arachnida_key()
    parsed_entries = parse_key_entries(key_entries)
    
    # Extract couplet information
    couplets = extract_couplet_info(parsed_entries)
    
    # Build the tree structure
    root_id, nodes = build_tree_from_couplets(couplets)
    
    # Print the tree structure (limited depth for readability)
    print("\nCouplet-Based Tree Structure (limited depth):")
    print(f"Starting with couplet 1:")
    print_tree_structure('1', nodes, max_depth=3)
    
    if '1\'' in nodes:
        print(f"\nAlternate path starting with couplet 1':")
        print_tree_structure('1\'', nodes, max_depth=3)
    
    # Save the tree as JSON
    save_as_json(root_id, nodes)
    
    # Visualize the tree
    visualize_couplet_tree(root_id, nodes)

if __name__ == "__main__":
    main() 