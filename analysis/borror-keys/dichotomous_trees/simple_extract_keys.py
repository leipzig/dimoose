#!/usr/bin/env python3
import re
import json
import os
from collections import defaultdict
from typing import Dict, List, Any, Tuple

def extract_key_entries(text_file: str, pattern: str) -> List[Dict[str, str]]:
    """Extract dichotomous key entries from the text file using a specific pattern."""
    entries = []
    
    with open(text_file, 'r', encoding='utf-8') as f:
        text = f.read()
    
    # Find all matches of the pattern
    for match in re.finditer(pattern, text, re.MULTILINE | re.DOTALL):
        entry_id = match.group(1).strip()
        content = match.group(2).strip()
        
        # Clean up content: replace multiple whitespace with a single space
        content = re.sub(r'\s+', ' ', content)
        
        entries.append({
            "id": entry_id,
            "content": content
        })
    
    return entries

def organize_entries_by_key(entries: List[Dict[str, str]]) -> Dict[str, List[Dict[str, str]]]:
    """Organize entries by potential key sections."""
    # Group entries based on proximity and patterns
    key_groups = []
    current_group = []
    last_id = None
    
    for entry in entries:
        entry_id = entry["id"]
        
        # Check if this is a new key or part of the current one
        if last_id and ((last_id.endswith('.') and entry_id.endswith("'.")) or
                         int(entry_id.rstrip("'.")) - int(last_id.rstrip("'.")) <= 2):
            # This entry is part of the current key
            current_group.append(entry)
        else:
            # This is a new key section
            if current_group:
                key_groups.append(current_group)
            current_group = [entry]
        
        last_id = entry_id
    
    # Add the last group
    if current_group:
        key_groups.append(current_group)
    
    # Assign titles to the key groups
    titled_keys = {}
    for i, group in enumerate(key_groups):
        # Default title
        key_title = f"Dichotomous_Key_{i+1}"
        
        # Try to identify the key from content
        for entry in group:
            if "Key to" in entry["content"]:
                match = re.search(r'Key to(?: the)? (?:Orders|Families|Genera) of ([A-Za-z]+)', entry["content"])
                if match:
                    key_title = f"Key_to_{match.group(1)}"
                    break
        
        titled_keys[key_title] = group
    
    return titled_keys

def process_entries(entries: List[Dict[str, str]]) -> List[Dict[str, Any]]:
    """Process entries into a tree-like structure."""
    # Group entries by their IDs (a key-value map for quick lookup)
    entries_map = {entry["id"]: entry for entry in entries}
    
    # Identify couplets (pairs of entries with IDs n and n')
    couplets = defaultdict(dict)
    for entry_id, entry in entries_map.items():
        if entry_id.endswith("'."):
            # This is a choice B
            choice_a_id = entry_id.rstrip("'.")+"."
            if choice_a_id in entries_map:
                couplets[choice_a_id.rstrip(".")]["choice_a"] = entries_map[choice_a_id]
                couplets[choice_a_id.rstrip(".")]["choice_b"] = entry
    
    # Build the tree structure
    nodes = []
    for couplet_id, couplet in couplets.items():
        nodes.append({
            "id": couplet_id,
            "choice_a": {
                "id": couplet["choice_a"]["id"],
                "content": couplet["choice_a"]["content"]
            },
            "choice_b": {
                "id": couplet["choice_b"]["id"],
                "content": couplet["choice_b"]["content"]
            }
        })
    
    return nodes

def main():
    text_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "references", "borror-the-study-of-insect1.txt")
    output_dir = "insect_keys"
    
    # Create output directory
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # Pattern 1: Standard numbered key entries
    pattern1 = r'(?:^|\n)(\d+\.|\d+\'\.)\s+(.*?)(?=\n\d+\.|\n\d+\'\.|\Z)'
    
    # Extract entries using pattern 1
    print(f"Extracting key entries from {text_file}...")
    entries = extract_key_entries(text_file, pattern1)
    print(f"Found {len(entries)} key entries using pattern 1")
    
    # Organize entries by key
    keys = organize_entries_by_key(entries)
    print(f"Organized entries into {len(keys)} potential key sections")
    
    # Process and save each key
    all_keys = []
    for i, (title, key_entries) in enumerate(keys.items()):
        # Use a simple title with index to avoid filename issues
        simple_title = f"key_{i+1}"
        print(f"Processing key {i+1}: {title}")
        
        # Process the entries into a tree-like structure
        nodes = process_entries(key_entries)
        
        # Create the key structure
        key_data = {
            "title": title,
            "entries": key_entries,
            "couplets": nodes
        }
        
        # Save to a separate file
        filename = f"{output_dir}/{simple_title}.json"
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(key_data, f, indent=2)
        
        print(f"Saved key to {filename}")
        
        # Add to the collection of all keys
        all_keys.append(key_data)
    
    # Save all keys to a single file
    with open(f"{output_dir}/all_keys.json", 'w', encoding='utf-8') as f:
        json.dump(all_keys, f, indent=2)
    
    print(f"Saved all keys to {output_dir}/all_keys.json")
    
    # Create a visualization script
    with open(f"{output_dir}/visualize_couplets.py", 'w', encoding='utf-8') as f:
        f.write('''#!/usr/bin/env python3
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
''')
    
    print(f"Created visualization script at {output_dir}/visualize_couplets.py")
    print(f"Run 'cd {output_dir} && python visualize_couplets.py' to visualize all keys")

if __name__ == "__main__":
    main() 