#!/usr/bin/env python3
import re
import json
from typing import Dict, List, Optional, Union, Any
import os

class Node:
    def __init__(self, id: str, content: str, parent: Optional['Node'] = None):
        self.id = id
        self.content = content
        self.parent = parent
        self.choice_a = None  # For option '1' or 'n'
        self.choice_b = None  # For option '1'' or 'n''
        self.result = None  # For terminal nodes that identify a taxon
    
    def to_dict(self) -> Dict:
        result = {
            "id": self.id,
            "content": self.content.strip()
        }
        
        if self.choice_a:
            result["choice_a"] = self.choice_a.to_dict()
        
        if self.choice_b:
            result["choice_b"] = self.choice_b.to_dict()
        
        if self.result:
            result["result"] = self.result
            
        return result

class DichotomousKey:
    def __init__(self, title: str):
        self.title = title
        self.root = None
        self.nodes = {}
    
    def add_node(self, id: str, content: str, parent_id: Optional[str] = None) -> Node:
        parent = None
        if parent_id and parent_id in self.nodes:
            parent = self.nodes[parent_id]
        
        node = Node(id, content, parent)
        self.nodes[id] = node
        
        if parent:
            if id.endswith("'"):
                parent.choice_b = node
            else:
                parent.choice_a = node
        
        if not self.root and not parent and not id.endswith("'"):
            self.root = node
            
        return node
    
    def to_dict(self) -> Dict:
        return {
            "title": self.title,
            "tree": self.root.to_dict() if self.root else {}
        }

def extract_keys_directly(text_file: str) -> List[Dict[str, Any]]:
    """Direct approach to extract dichotomous keys from text based on numbered patterns."""
    keys = []
    
    with open(text_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Key section patterns
    key_start_patterns = [
        r'^Key to (the )?Orders of ([A-Za-z]+)',
        r'^Key to (the )?([A-Za-z]+) Orders',
        r'^Key to (the )?([A-Za-z]+) Families',
        r'^Key to (the )?Families of ([A-Za-z]+)',
        r'^Key to (the )?Genera of ([A-Za-z]+)'
    ]
    
    current_key = None
    current_content = []
    i = 0
    
    while i < len(lines):
        line = lines[i].strip()
        
        # Check for key section start
        is_key_start = False
        for pattern in key_start_patterns:
            if re.match(pattern, line):
                # If we already have a key in progress, save it
                if current_key:
                    keys.append({
                        "title": current_key,
                        "content": "".join(current_content)
                    })
                
                current_key = line
                current_content = [line + "\n"]
                is_key_start = True
                break
        
        # If we found a new key, continue to next line
        if is_key_start:
            i += 1
            continue
        
        # If we're in a key section, add the line
        if current_key:
            # Check if it's a numbered key entry (1. or 1'.)
            if re.match(r'^\d+\.|\d+\'\.', line):
                current_content.append(line + "\n")
            
            # Check for end of a key section (blank lines, new chapter, etc.)
            elif line == "" and i+1 < len(lines) and lines[i+1].strip() == "":
                # Two blank lines often indicate end of a section
                if i+2 < len(lines) and not re.match(r'^\d+\.|\d+\'\.', lines[i+2].strip()):
                    keys.append({
                        "title": current_key,
                        "content": "".join(current_content)
                    })
                    current_key = None
                    current_content = []
            else:
                # Include other lines that might be continuations of key entries
                current_content.append(line + "\n")
        
        i += 1
    
    # Don't forget the last key
    if current_key:
        keys.append({
            "title": current_key,
            "content": "".join(current_content)
        })
    
    return keys

def process_key_content(content: str) -> List[Dict[str, str]]:
    """Process key content to extract individual entries."""
    # Split content into lines
    lines = content.split('\n')
    
    # Extract key entries
    entries = []
    current_entry = None
    
    for line in lines:
        # Check if it's a new key entry
        match = re.match(r'^(\d+\.|\d+\'\.)\s+(.*)', line.strip())
        if match:
            # If there's a current entry, add it
            if current_entry:
                entries.append(current_entry)
            
            # Start a new entry
            current_entry = {
                "id": match.group(1).strip(),
                "content": match.group(2).strip()
            }
        elif current_entry and line.strip():
            # Continue the current entry
            current_entry["content"] += " " + line.strip()
    
    # Add the last entry
    if current_entry:
        entries.append(current_entry)
    
    return entries

def build_key_tree(entries: List[Dict[str, str]]) -> DichotomousKey:
    """Build a dichotomous key tree from the entries."""
    title = entries[0]["content"] if entries else "Unknown Key"
    key = DichotomousKey(title)
    
    # First pass: create all nodes
    for entry in entries[1:]:  # Skip the title
        node_id = entry["id"]
        if node_id.endswith('.'):
            node_id = node_id[:-1]
        
        # Determine parent
        parent_id = None
        if node_id.endswith("'"):
            # This is a choice B node, find its parent
            parent_id = node_id[:-1]
        elif len(node_id) > 1:
            # This is a sub-node, find its parent
            parent_id = node_id[:-1]
        
        # Add the node
        key.add_node(node_id, entry["content"], parent_id)
    
    return key

def save_keys_as_json(keys: List[DichotomousKey], output_file: str):
    """Save the keys as a JSON file."""
    result = [key.to_dict() for key in keys]
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(result, f, indent=2)

def extract_from_key_sections(key_sections: List[Dict[str, str]]) -> List[DichotomousKey]:
    """Extract dichotomous keys from text sections."""
    keys = []
    
    for section in key_sections:
        title = section["title"]
        content = section["content"]
        
        # Process the content to extract entries
        entries = process_key_content(content)
        
        if entries:
            # Build the key tree
            key = build_key_tree(entries)
            key.title = title
            keys.append(key)
    
    return keys

def main():
    text_file = "borror-the-study-of-insect1.txt"
    output_file = "dichotomous_keys.json"
    
    # Extract key sections from the text
    key_sections = extract_keys_directly(text_file)
    print(f"Found {len(key_sections)} key sections")
    
    # Extract keys from the sections
    keys = extract_from_key_sections(key_sections)
    print(f"Built {len(keys)} dichotomous keys")
    
    # Save the keys to a JSON file
    save_keys_as_json(keys, output_file)
    print(f"Saved {len(keys)} keys to {output_file}")
    
    # Create a visualization script for the keys
    with open("visualize_keys.py", 'w', encoding='utf-8') as f:
        f.write('''#!/usr/bin/env python3
import json
import os
from graphviz import Digraph

def visualize_tree(tree, dot, prefix=""):
    """Recursively visualize a tree."""
    node_id = prefix + tree["id"]
    
    # Format the node label
    label = tree["content"][:100] + "..." if len(tree["content"]) > 100 else tree["content"]
    if "result" in tree:
        label += "\\n→ " + tree["result"]
    
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
''')
    print("Created visualize_keys.py for visualizing the extracted keys")

if __name__ == "__main__":
    main() 