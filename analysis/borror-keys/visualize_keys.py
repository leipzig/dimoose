#!/usr/bin/env python3
import json
import os
from graphviz import Digraph

def visualize_tree(tree, dot, prefix=""):
    """Recursively visualize a tree."""
    node_id = prefix + tree["id"]
    
    # Format the node label
    label = tree["content"][:100] + "..." if len(tree["content"]) > 100 else tree["content"]
    if "result" in tree:
        label += "\n→ " + tree["result"]
    
    # Add the node to the graph
    dot.node(node_id, label)
    
    if "choice_a" in tree:
        choice_a_id = prefix + tree["choice_a"]["id"]
        dot.edge(node_id, choice_a_id, label="A")
        visualize_tree(tree["choice_a"], dot, prefix)
    
    if "choice_b" in tree:
        choice_b_id = prefix + tree["choice_b"]["id"]
        dot.edge(node_id, choice_b_id, label="B")
        visualize_tree(tree["choice_b"], dot, prefix)

def main():
    with open("dichotomous_keys.json", 'r', encoding='utf-8') as f:
        keys = json.load(f)
    
    if not os.path.exists("key_visualizations"):
        os.makedirs("key_visualizations")
    
    for i, key in enumerate(keys):
        print(f"Processing visualization for {key['title']}")
        dot = Digraph(comment=key["title"])
        dot.attr(rankdir="LR")
        dot.attr('node', shape='box', style='filled', fillcolor='lightblue')
        
        # Add a title node
        dot.node(f"title_{i}", key["title"], shape='box', style='filled', fillcolor='lightgreen')
        
        if "tree" in key and key["tree"]:
            # If the tree has nodes, visualize it
            visualize_tree(key["tree"], dot, prefix=f"key{i}_")
            
            # Connect the title to the root node
            root_id = f"key{i}_{key['tree']['id']}"
            dot.edge(f"title_{i}", root_id)
            
            # Render the diagram
            filename = f"key_visualizations/key_{i}_{key['title'].replace(' ', '_').replace('/', '_')[:50]}"
            dot.render(filename, format="png", cleanup=True)
            print(f"Generated visualization for {key['title']} at {filename}.png")
        else:
            print(f"Warning: No tree data for {key['title']}")

if __name__ == "__main__":
    main()
