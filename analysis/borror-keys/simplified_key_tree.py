#!/usr/bin/env python3
"""
Simplified Couplet Tree Generator
---------------------------------
This script creates a simplified visualization of the Arachnida key with
couplet numbers as edge labels and blank nodes except for terminal orders.
"""

import os
import json
from graphviz import Digraph
from arachnida_key_tree import get_arachnida_key, parse_key_entries

def get_couplet_definitions():
    """Extract couplet definitions and save them to a JSON file."""
    key_entries = get_arachnida_key()
    parsed_entries = parse_key_entries(key_entries)
    
    # Create a dictionary of couplet definitions
    couplet_defs = {}
    for entry in parsed_entries:
        couplet_id = entry["id"].rstrip(".")
        content = entry["content"]
        if entry["order"]:
            content = f"{content} → {entry['order']}"
        couplet_defs[couplet_id] = content
    
    # Save to JSON file
    if not os.path.exists('visualizations'):
        os.makedirs('visualizations')
    
    with open('visualizations/couplet_definitions.json', 'w') as f:
        json.dump(couplet_defs, f, indent=2)
    
    return couplet_defs

def create_simplified_tree():
    """Create a simplified version of the Arachnida key tree."""
    # Get the key entries to extract order names and descriptions
    key_entries = get_arachnida_key()
    parsed_entries = parse_key_entries(key_entries)
    
    # Also get and save couplet definitions
    couplet_defs = get_couplet_definitions()
    
    # Create the graph
    dot = Digraph(comment='Simplified Arachnida Key Tree')
    dot.attr(rankdir='TB')  # Top to bottom layout
    dot.attr(size='12,18')  # Canvas size
    dot.attr(dpi='300')     # High resolution
    dot.attr('node', fontsize='12', fontname='Arial')
    dot.attr('edge', fontsize='10', fontname='Arial Bold')
    
    # Add a start node
    dot.node('start', 'Start', shape='oval', style='filled', fillcolor='gold')
    
    # Create terminal nodes for orders
    terminal_nodes = {
        "2": "Araneae",
        "2'": "Acari",
        "4": "Scorpiones",
        "5": "Palpigradi",
        "6": "Uropygi",
        "6'": "Schizomida",
        "7": "Pseudoscorpiones",
        "8": "Solifugae",
        "10": "Schizomida",
        "10'": "Amblypygi",
        "11": "Ricinulei",
        "11'": "Opiliones"
    }
    
    # Track nodes we've added
    added_nodes = set()
    
    # Function to add a node with a unique ID
    def add_node(node_id, is_terminal=False, order_name=None):
        if node_id not in added_nodes:
            if is_terminal:
                # Terminal nodes show the order name
                dot.node(node_id, order_name, shape='box', style='filled,bold',
                        fillcolor='#AAFFAA', fontsize='14', margin='0.15,0.1')
            else:
                # Non-terminal nodes are blank
                dot.node(node_id, "", shape='circle', style='filled',
                        fillcolor='lightblue', width='0.5', height='0.5')
            added_nodes.add(node_id)
    
    # Add nodes and edges for the tree structure
    # Level 1
    add_node('n1')
    dot.edge('start', 'n1', '1', color='darkgreen', fontcolor='darkgreen')
    
    # Level 1'
    add_node('n1p')  # 1 prime
    dot.edge('start', 'n1p', '1\'', color='darkred', fontcolor='darkred')
    
    # From 1
    add_node('n2')
    dot.edge('n1', 'n2', '2', color='darkgreen', fontcolor='darkgreen')
    add_node('n2p')
    dot.edge('n1', 'n2p', '2\'', color='darkred', fontcolor='darkred')
    
    # Terminal nodes from 2 and 2'
    add_node('araneae', True, 'Araneae')
    add_node('acari', True, 'Acari')
    dot.edge('n2', 'araneae', color='black', style='solid', arrowhead='vee', penwidth='1.5')
    dot.edge('n2p', 'acari', color='black', style='solid', arrowhead='vee', penwidth='1.5')
    
    # From 1'
    add_node('n3')
    dot.edge('n1p', 'n3', '3', color='darkgreen', fontcolor='darkgreen')
    add_node('n3p')
    dot.edge('n1p', 'n3p', '3\'', color='darkred', fontcolor='darkred')
    
    # From 3
    add_node('n4')
    dot.edge('n3', 'n4', '4', color='darkgreen', fontcolor='darkgreen')
    add_node('n4p')
    dot.edge('n3', 'n4p', '4\'', color='darkred', fontcolor='darkred')
    
    # Terminal node from 4
    add_node('scorpiones', True, 'Scorpiones')
    dot.edge('n4', 'scorpiones', color='black', style='solid', arrowhead='vee', penwidth='1.5')
    
    # From 4'
    add_node('n5')
    dot.edge('n4p', 'n5', '5', color='darkgreen', fontcolor='darkgreen')
    add_node('n5p')
    dot.edge('n4p', 'n5p', '5\'', color='darkred', fontcolor='darkred')
    
    # Terminal node from 5
    add_node('palpigradi', True, 'Palpigradi')
    dot.edge('n5', 'palpigradi', color='black', style='solid', arrowhead='vee', penwidth='1.5')
    
    # From 5'
    add_node('n6')
    dot.edge('n5p', 'n6', '6', color='darkgreen', fontcolor='darkgreen')
    add_node('n6p')
    dot.edge('n5p', 'n6p', '6\'', color='darkred', fontcolor='darkred')
    
    # Terminal nodes from 6 and 6'
    add_node('uropygi', True, 'Uropygi')
    add_node('schizomida1', True, 'Schizomida')
    dot.edge('n6', 'uropygi', color='black', style='solid', arrowhead='vee', penwidth='1.5')
    dot.edge('n6p', 'schizomida1', color='black', style='solid', arrowhead='vee', penwidth='1.5')
    
    # From 3'
    add_node('n7')
    dot.edge('n3p', 'n7', '7', color='darkgreen', fontcolor='darkgreen')
    add_node('n7p')
    dot.edge('n3p', 'n7p', '7\'', color='darkred', fontcolor='darkred')
    
    # Terminal node from 7
    add_node('pseudoscorpiones', True, 'Pseudoscorpiones')
    dot.edge('n7', 'pseudoscorpiones', color='black', style='solid', arrowhead='vee', penwidth='1.5')
    
    # From 7'
    add_node('n8')
    dot.edge('n7p', 'n8', '8', color='darkgreen', fontcolor='darkgreen')
    add_node('n8p')
    dot.edge('n7p', 'n8p', '8\'', color='darkred', fontcolor='darkred')
    
    # Terminal node from 8
    add_node('solifugae', True, 'Solifugae')
    dot.edge('n8', 'solifugae', color='black', style='solid', arrowhead='vee', penwidth='1.5')
    
    # From 8'
    add_node('n9')
    dot.edge('n8p', 'n9', '9', color='darkgreen', fontcolor='darkgreen')
    add_node('n9p')
    dot.edge('n8p', 'n9p', '9\'', color='darkred', fontcolor='darkred')
    
    # From 9
    add_node('n10')
    dot.edge('n9', 'n10', '10', color='darkgreen', fontcolor='darkgreen')
    add_node('n10p')
    dot.edge('n9', 'n10p', '10\'', color='darkred', fontcolor='darkred')
    
    # Terminal nodes from 10 and 10'
    add_node('schizomida2', True, 'Schizomida')
    add_node('amblypygi', True, 'Amblypygi')
    dot.edge('n10', 'schizomida2', color='black', style='solid', arrowhead='vee', penwidth='1.5')
    dot.edge('n10p', 'amblypygi', color='black', style='solid', arrowhead='vee', penwidth='1.5')
    
    # From 9'
    add_node('n11')
    dot.edge('n9p', 'n11', '11', color='darkgreen', fontcolor='darkgreen')
    add_node('n11p')
    dot.edge('n9p', 'n11p', '11\'', color='darkred', fontcolor='darkred')
    
    # Terminal nodes from 11 and 11'
    add_node('ricinulei', True, 'Ricinulei')
    add_node('opiliones', True, 'Opiliones')
    dot.edge('n11', 'ricinulei', color='black', style='solid', arrowhead='vee', penwidth='1.5')
    dot.edge('n11p', 'opiliones', color='black', style='solid', arrowhead='vee', penwidth='1.5')
    
    # Create output directory if it doesn't exist
    if not os.path.exists('visualizations'):
        os.makedirs('visualizations')
    
    # Render the tree
    dot.render('visualizations/arachnida_simplified_tree', format='png', cleanup=True)
    dot.render('visualizations/arachnida_simplified_tree', format='pdf', cleanup=True)
    
    print(f"Simplified tree visualization saved to visualizations/arachnida_simplified_tree.png and .pdf")

if __name__ == "__main__":
    create_simplified_tree() 