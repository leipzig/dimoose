#!/usr/bin/env python3
import re
import json
import os
from typing import Dict, List, Any, Optional, Tuple

class Node:
    def __init__(self, id: str, content: str):
        self.id = id
        self.content = content
        self.choice_a = None
        self.choice_b = None
        self.is_terminal = False
        self.taxon = None
    
    def to_dict(self) -> Dict:
        result = {
            "id": self.id,
            "content": self.content
        }
        
        if self.choice_a:
            result["choice_a"] = self.choice_a.to_dict()
        
        if self.choice_b:
            result["choice_b"] = self.choice_b.to_dict()
        
        if self.is_terminal:
            result["is_terminal"] = True
        
        if self.taxon:
            result["taxon"] = self.taxon
        
        return result

class DichotomousKey:
    def __init__(self, title: str):
        self.title = title
        self.root = None
        self.nodes = {}
    
    def to_dict(self) -> Dict:
        return {
            "title": self.title,
            "tree": self.root.to_dict() if self.root else {}
        }

def find_key_sections(text_file: str) -> List[Tuple[str, int, int]]:
    """Find all key sections in the text file."""
    sections = []
    
    with open(text_file, 'r', encoding='utf-8') as f:
        text = f.read()
    
    # Patterns to identify key sections
    key_patterns = [
        r'Key to the Orders of ([A-Za-z]+)',
        r'Key to the ([A-Za-z]+) Orders',
        r'Key to the Families of ([A-Za-z]+)',
        r'Key to the Genera of ([A-Za-z]+)'
    ]
    
    # Find all potential key sections
    for pattern in key_patterns:
        for match in re.finditer(pattern, text):
            start_pos = match.start()
            title = match.group(0)
            
            # Look for the end of the section
            # Check for patterns that would indicate the end
            end_patterns = [
                r'Key to the',
                r'Chapter \d+',
                r'REFERENCES'
            ]
            
            # Find the closest end marker
            end_pos = len(text)
            for end_pattern in end_patterns:
                next_match = re.search(end_pattern, text[start_pos + len(title):])
                if next_match:
                    potential_end = start_pos + len(title) + next_match.start()
                    if potential_end < end_pos:
                        end_pos = potential_end
            
            sections.append((title, start_pos, end_pos))
    
    # Sort by start position
    sections.sort(key=lambda x: x[1])
    
    return sections

def extract_key_entries(text: str) -> List[Dict[str, str]]:
    """Extract key entries from the text."""
    entries = []
    
    # Pattern to match key entries
    entry_pattern = r'(?:^|\n)(\d+\.|\d+\'\.)\s+(.*?)(?=\n\d+\.|\n\d+\'\.|\Z)'
    
    # Find all entries
    for match in re.finditer(entry_pattern, text, re.DOTALL):
        entry_id = match.group(1).strip()
        content = match.group(2).strip()
        
        # Clean up content
        content = re.sub(r'\s+', ' ', content)
        
        entries.append({
            "id": entry_id,
            "content": content
        })
    
    return entries

def build_key_tree(entries: List[Dict[str, str]]) -> Optional[DichotomousKey]:
    """Build a dichotomous key tree from the entries."""
    if not entries:
        return None
    
    key = DichotomousKey("Dichotomous Key")
    nodes = {}
    
    # First pass: create all nodes
    for entry in entries:
        entry_id = entry["id"]
        content = entry["content"]
        
        # Remove the trailing period
        if entry_id.endswith('.'):
            entry_id = entry_id[:-1]
        
        # Create the node
        node = Node(entry_id, content)
        
        # Check if it's a terminal node (leads to a taxon)
        # Look for patterns like "Family XYZ" or "Order ABC"
        terminal_match = re.search(r'(Family|Order|Genus|Species)\s+([A-Z][a-z]+)', content)
        if terminal_match:
            node.is_terminal = True
            node.taxon = terminal_match.group(2)
        
        nodes[entry_id] = node
    
    # Second pass: build the tree
    for node_id, node in nodes.items():
        # Check if it's a couplet (has a paired node)
        if node_id.endswith("'"):
            # This is a choice B, find its choice A
            choice_a_id = node_id[:-1]
            if choice_a_id in nodes:
                # Link to next couplet if mentioned in content
                choice_a = nodes[choice_a_id]
                
                # Look for "go to X" or "see X" patterns in content
                next_match_a = re.search(r'go to (\d+)|see (\d+)', choice_a.content)
                next_match_b = re.search(r'go to (\d+)|see (\d+)', node.content)
                
                if next_match_a:
                    next_id = next_match_a.group(1) or next_match_a.group(2)
                    if next_id + '.' in [e["id"] for e in entries]:
                        choice_a.choice_a = nodes.get(next_id)
                
                if next_match_b:
                    next_id = next_match_b.group(1) or next_match_b.group(2)
                    if next_id + '.' in [e["id"] for e in entries]:
                        node.choice_a = nodes.get(next_id)
        else:
            # This is a choice A, find its choice B
            choice_b_id = node_id + "'"
            if choice_b_id in nodes:
                node.choice_b = nodes[choice_b_id]
    
    # Find the root node (usually 1)
    if "1" in nodes:
        key.root = nodes["1"]
    
    return key

def process_key_section(title: str, text: str) -> Optional[DichotomousKey]:
    """Process a key section to extract and build a dichotomous key."""
    # Extract key entries
    entries = extract_key_entries(text)
    
    if not entries:
        return None
    
    # Build the key tree
    key = build_key_tree(entries)
    
    if key:
        key.title = title
    
    return key

def main():
    text_file = "borror-the-study-of-insect1.txt"
    output_dir = "dichotomous_keys"
    
    # Find key sections
    print("Finding key sections...")
    sections = find_key_sections(text_file)
    print(f"Found {len(sections)} potential key sections")
    
    # Process each section
    keys = []
    for i, (title, start, end) in enumerate(sections):
        print(f"Processing section {i+1}: {title}")
        
        # Extract the section text
        with open(text_file, 'r', encoding='utf-8') as f:
            f.seek(start)
            section_text = f.read(end - start)
        
        # Process the section
        key = process_key_section(title, section_text)
        
        if key and key.root:
            keys.append(key)
    
    print(f"Successfully built {len(keys)} dichotomous keys")
    
    # Create the output directory
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # Save each key as a separate JSON file
    for i, key in enumerate(keys):
        # Create a safe filename
        safe_title = re.sub(r'[^a-zA-Z0-9_]', '_', key.title)
        filename = f"{output_dir}/key_{i+1}_{safe_title}.json"
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(key.to_dict(), f, indent=2)
        
        print(f"Saved {key.title} to {filename}")
    
    # Also save all keys in one file
    with open(f"{output_dir}/all_keys.json", 'w', encoding='utf-8') as f:
        json.dump([key.to_dict() for key in keys], f, indent=2)
    
    print(f"Saved all keys to {output_dir}/all_keys.json")
    
    # Create a script to visualize the keys
    with open(f"{output_dir}/visualize_keys.py", 'w', encoding='utf-8') as f:
        f.write('''#!/usr/bin/env python3
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
        label += "\\n→ " + tree["taxon"]
    
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
''')
    
    print(f"Created visualization script at {output_dir}/visualize_keys.py")
    print(f"Run 'cd {output_dir} && python visualize_keys.py' to visualize all keys")

if __name__ == "__main__":
    main() 