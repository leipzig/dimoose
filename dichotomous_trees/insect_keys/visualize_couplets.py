#!/usr/bin/env python3
import json
import os
import sys
from graphviz import Digraph

def visualize_key(key_data, output_file):
    """Visualize a key's couplets."""
    title = key_data["title"]
    couplets = key_data["couplets"]
    
    # Create a directed graph
    dot = Digraph(comment=title)
    dot.attr(rankdir="LR")
    
    # Add a title node
    dot.node("title", title, shape="box", style="filled", fillcolor="lightgreen")
    
    # Process each couplet
    for couplet in couplets:
        couplet_id = couplet["id"]
        
        # Add the couplet node
        dot.node(couplet_id, f"Couplet {couplet_id}", shape="box", style="filled", fillcolor="lightblue")
        
        # Add the choice nodes
        choice_a_id = f"{couplet_id}_A"
        choice_a_content = couplet["choice_a"]["content"][:100] + "..." if len(couplet["choice_a"]["content"]) > 100 else couplet["choice_a"]["content"]
        dot.node(choice_a_id, choice_a_content, shape="box")
        
        choice_b_id = f"{couplet_id}_B"
        choice_b_content = couplet["choice_b"]["content"][:100] + "..." if len(couplet["choice_b"]["content"]) > 100 else couplet["choice_b"]["content"]
        dot.node(choice_b_id, choice_b_content, shape="box")
        
        # Connect couplet to choices
        dot.edge(couplet_id, choice_a_id, label="A")
        dot.edge(couplet_id, choice_b_id, label="B")
        
        # Connect to title if it's the first couplet
        if couplet_id == "1":
            dot.edge("title", couplet_id)
    
    # Render the diagram
    dot.render(output_file, format="png", cleanup=True)
    print(f"Generated visualization at {output_file}.png")

def main():
    if len(sys.argv) > 1:
        # Visualize a specific key
        key_file = sys.argv[1]
        with open(key_file, 'r', encoding='utf-8') as f:
            key_data = json.load(f)
        
        output_file = os.path.splitext(key_file)[0]
        visualize_key(key_data, output_file)
    else:
        # Visualize all keys
        with open("all_keys.json", 'r', encoding='utf-8') as f:
            keys = json.load(f)
        
        if not os.path.exists("visualizations"):
            os.makedirs("visualizations")
        
        for i, key in enumerate(keys):
            if key["couplets"]:  # Only visualize keys with couplets
                output_file = f"visualizations/key_{i+1}"
                visualize_key(key, output_file)

if __name__ == "__main__":
    main()
