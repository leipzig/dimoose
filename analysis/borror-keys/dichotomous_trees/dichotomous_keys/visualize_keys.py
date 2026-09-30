#!/usr/bin/env python3
import json
import os
import sys
from graphviz import Digraph

def visualize_tree(tree, dot, prefix=""):
    """Recursively visualize a tree."""
    node_id = prefix + tree["id"]
    
    # Format the node label
    label = tree["content"][:100] + "..." if len(tree["content"]) > 100 else tree["content"]
    
    if "taxon" in tree:
        label += "\n→ " + tree["taxon"]
    
    # Set node style based on whether it's terminal
    node_attrs = {
        "shape": "box",
        "style": "filled",
        "fillcolor": "lightblue" if not tree.get("is_terminal") else "lightgreen"
    }
    
    # Add the node to the graph
    dot.node(node_id, label, **node_attrs)
    
    if "choice_a" in tree:
        choice_a_id = prefix + tree["choice_a"]["id"]
        dot.edge(node_id, choice_a_id, label="A")
        visualize_tree(tree["choice_a"], dot, prefix)
    
    if "choice_b" in tree:
        choice_b_id = prefix + tree["choice_b"]["id"]
        dot.edge(node_id, choice_b_id, label="B")
        visualize_tree(tree["choice_b"], dot, prefix)

def main():
    if len(sys.argv) > 1:
        # Visualize a specific key
        key_file = sys.argv[1]
        with open(key_file, 'r', encoding='utf-8') as f:
            key = json.load(f)
        
        visualize_key(key, os.path.splitext(key_file)[0])
    else:
        # Visualize all keys
        with open("all_keys.json", 'r', encoding='utf-8') as f:
            keys = json.load(f)
        
        if not os.path.exists("visualizations"):
            os.makedirs("visualizations")
        
        for i, key in enumerate(keys):
            print(f"Visualizing key {i+1}: {key['title']}")
            visualize_key(key, f"visualizations/key_{i+1}")

def visualize_key(key, output_path):
    """Visualize a single key."""
    if "tree" not in key or not key["tree"]:
        print(f"Warning: No tree data for {key['title']}")
        return
    
    dot = Digraph(comment=key["title"])
    dot.attr(rankdir="LR")
    
    # Add a title node
    dot.node("title", key["title"], shape="box", style="filled", fillcolor="lightgreen")
    
    # Visualize the tree
    visualize_tree(key["tree"], dot, prefix="node_")
    
    # Connect the title to the root node
    root_id = "node_" + key["tree"]["id"]
    dot.edge("title", root_id)
    
    # Render the diagram
    dot.render(output_path, format="png", cleanup=True)
    print(f"Generated visualization at {output_path}.png")

if __name__ == "__main__":
    main()
