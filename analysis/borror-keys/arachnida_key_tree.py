#!/usr/bin/env python3
import re
import os
from graphviz import Digraph

class Node:
    def __init__(self, id, content, order=None):
        self.id = id
        self.content = content
        self.order = order
        self.choice_a = None
        self.choice_b = None
        self.next_couplet = None
    
    def __str__(self):
        return f"{self.id}: {self.content}"

def get_arachnida_key():
    """Return the manually defined Key to the Orders of Arachnida."""
    return [
        "1. Opisthosoma (abdomen) unsegmented or, if segmented, with spinnerets posteriorly on ventral side (Figures 5-5 and 5-8, ALS,PLS,PMS) 2",
        "1'. Opisthosoma distinctly segmented, without spinnerets 3",
        "2(1). Opisthosoma petiolate (Figures 5-5 and 5-9 through 5-13) Araneae p. 105",
        "2'. Opisthosoma not petiolate, but broadly joined to prosoma (Figures 5-15 through 5-22) Acari p. 129",
        "3(1'). Opisthosoma with a tail-like prolongation that is either thick and terminating in a sting (Figure 5-3) or slender and more or less whiplike (Figure 5-4A,B); mostly tropical 4",
        "3'. Opisthosoma without a tail-like prolongation or with a very short leaflike appendage 7",
        "4(3). Opisthosoma ending in a sting (Figure 5-3); first pair of legs not greatly elongated; second ventral segment of opisthosoma with a pair of comblike organs Scorpiones p. 104",
        "4'. Opisthosoma not ending in a sting; first pair of legs longer than other pairs (Figure 5-4A,B); second ventral segment of opisthosoma without comblike organs 5",
        "5(4'). Pedipalps slender, similar to legs (Figure 5-4A); minute forms, 5 mm or less in length Palpigradi p. 104",
        "5'. Pedipalps usually much stouter than any of the legs (Figure 5-4B); mostly larger forms 6",
        "6(5'). With two median eyes on a tubercle anteriorly and a group of three eyes on each lateral margin; tail long, filiform, and many-segmented; pedipalps nearly straight or curved mesad, extending forward, and moving laterally (Figure 5-4B); body blackish, more than 50 mm in length Uropygi p. 104",
        "6'. Eyes lacking; tail short, one- to four-segmented; pedipalps arching upward, forward, and downward and moving vertically; body yellowish or brownish, less than 8 mm in length Schizomida p. 105",
        "7(3'). Pedipalps chelate (pincerlike) (Figure 5-23); body more or less oval, flattened, usually less than 5 mm in length Pseudoscorpiones p. 135",
        "7'. Pedipalps raptorial or leglike, but not chelate; body not particularly flattened; size variable 8",
        "8(7'). Chelicerae very large, usually about as long as prosoma, and extending forward, and body slightly narrowed in middle (Figure 5-4C); color pale yellow to brownish; length 20 to 30 mm; mostly nocturnal desert forms occurring in western United States Solifugae p. 135",
        "8'. Without the preceding combination of characters 9",
        "9(8'). First pair of legs very long, with long tarsi; opisthosoma constricted at base; mainly tropical 10",
        "9'. First legs similar to the others and (except in the Opiliones) not usually long; opisthosoma not particularly constricted at base 11",
        "10(9). Prosoma longer than wide, lateral margins nearly parallel, and with a transverse membranous suture in caudal third; opisthosoma with a very short terminal appendage; length 5-8 mm (see also couplet 6') Schizomida p. 105",
        "10'. Prosoma wider than long, lateral margins rounded or arched, and without a transverse suture; opisthosoma without a terminal appendage; length variable, up to about 50 mm Amblypygi p. 105",
        "11(9'). Orange-red to brown arachnids, about 3 mm in length, with broad flap at anterior end of prosoma concealing chelicerae; legs not unusually long, animal somewhat mitelike or ticklike in appearance; recorded from Rio Grande Valley of Texas Ricinulei p. 128",
        "11'. Size and color variable, but without broad flap at anterior end of prosoma covering chelicerae; legs variable in length, often very long and slender (Figure 5-14); widely distributed Opiliones p. 129"
    ]

def parse_key_entries(entries):
    """Parse the key entries into a structured format."""
    parsed_entries = []
    
    for entry in entries:
        # First replace lowercase 'l.' with '1.' if it occurs at the beginning
        if entry.startswith("l."):
            entry = "1." + entry[2:]
        
        # Extract the ID and content
        match = re.match(r'(\d+\'?(?:\(\d+\'?\))?)\.?\s+(.*)', entry)
        if match:
            entry_id = match.group(1).strip()
            content = match.group(2).strip()
            
            # Look for an order/taxon name and page number at the end
            order_match = re.search(r'([A-Z][a-z]+(?:\s+[a-z]+)?)\s+(?:p\.\s+\d+)?$', content)
            order = None
            if order_match:
                order = order_match.group(1)
                # Remove the page reference but keep the order name in the content
                content = re.sub(r'(p\.\s+\d+)$', '', content).strip()
            
            # Look for the next couplet number at the end
            next_couplet = None
            next_match = re.search(r'\s+(\d+)$', content)
            if next_match:
                next_couplet = next_match.group(1)
                # Remove the next couplet number from content for clean display
                content = re.sub(r'\s+\d+$', '', content)
            
            parsed_entries.append({
                "id": entry_id,
                "content": content,
                "order": order,
                "next_couplet": next_couplet
            })
        else:
            print(f"Failed to parse entry: {entry}")
    
    return parsed_entries

def clean_id(id_str):
    """Clean and standardize node IDs."""
    # Handle references in parentheses
    match = re.match(r'(\d+\'?)\((\d+\'?)\)', id_str)
    if match:
        return match.group(1)
    
    return id_str

def build_tree(entries):
    """Build a tree structure from the parsed entries."""
    nodes = {}
    
    # First, create all nodes
    for entry in entries:
        entry_id = clean_id(entry["id"])
        node = Node(entry_id, entry["content"], entry["order"])
        # Also add the next_couplet property to the node
        node.next_couplet = entry.get("next_couplet")
        nodes[entry_id] = node
    
    # For debugging
    print(f"Created nodes with IDs: {list(nodes.keys())}")
    
    # Then, find the parent-child relationships
    for entry in entries:
        entry_id = clean_id(entry["id"])
        node = nodes.get(entry_id)
        if not node:
            print(f"Warning: Node {entry_id} not found")
            continue
        
        # Find reference to parent in the ID (e.g., "2(1)" references parent "1")
        parent_match = re.search(r'\((\d+\'?)\)', entry["id"])
        if parent_match:
            parent_id = parent_match.group(1)
            parent = nodes.get(parent_id)
            
            if parent:
                # If this is a prime entry, it's option B, otherwise option A
                if entry_id.endswith("'"):
                    parent.choice_b = node
                else:
                    parent.choice_a = node
            else:
                print(f"Warning: Parent {parent_id} not found for node {entry_id}")
        
        # For entries like 1', find the corresponding non-prime entry
        elif entry_id.endswith("'"):
            base_id = entry_id[:-1]
            base_node = nodes.get(base_id)
            if base_node:
                base_node.choice_b = node
            else:
                print(f"Warning: Base node {base_id} not found for prime node {entry_id}")
        
        # For entries with next couplet referenced
        if entry.get("next_couplet"):
            next_id = entry["next_couplet"]
            next_node = nodes.get(next_id)
            if next_node:
                node.choice_a = next_node
    
    # Find the root node (should be "1")
    root = nodes.get("1")
    if not root:
        print("Root node not found, looking for other potential roots...")
        # Try other nodes that might be the root
        for node_id in nodes:
            if re.match(r'^\d+$', node_id) and int(node_id) == 1:
                root = nodes[node_id]
                print(f"Found alternative root: {node_id}")
                break
    
    return root, nodes

def visualize_tree(root, nodes):
    """Create a visualization of the tree."""
    dot = Digraph(comment='Key to the Orders of Arachnida')
    dot.attr(rankdir='TB')  # Top to bottom layout (vertical)
    dot.attr(size='14,20')  # Larger canvas
    dot.attr(dpi='300')     # Higher resolution
    dot.attr(ratio='fill')
    dot.attr('node', fontsize='10', fontname='Arial')
    dot.attr('edge', fontsize='9', fontname='Arial')
    
    # Add a title node
    dot.node('title', 'Key to the Orders of Arachnida', shape='box', style='filled', 
             fillcolor='lightgreen', fontsize='16', fontname='Arial Bold')
    
    # Add nodes
    for node_id, node in nodes.items():
        # Extract the key characteristic for this node
        content = node.content
        
        # Remove the reference to the next couplet if present
        if node.next_couplet:
            content = re.sub(r'\s+\d+$', '', content)
        
        # Format the content with line breaks for readability
        # Break at semicolons and other logical points
        content = content.replace('; ', ';\n')
        content = content.replace(') ', ')\n')
        
        # Special formatting for nodes that lead to an order
        if node.order:
            # Extract the main identifying feature before the order name
            main_feature = content.split(node.order)[0].strip()
            label = f"{node_id}:\n{main_feature}\n\nOrder: {node.order}"
            fillcolor = '#AAFFAA'  # Light green for terminal nodes
            shape = 'box'
        else:
            label = f"{node_id}:\n{content}"
            fillcolor = 'lightblue'
            shape = 'box'
        
        # Set node attributes
        attrs = {
            'shape': shape,
            'style': 'filled, rounded',
            'fillcolor': fillcolor,
            'margin': '0.15,0.1',
            'fontsize': '10'
        }
        
        dot.node(node_id, label, **attrs)
    
    # Add edges with better labels
    for node_id, node in nodes.items():
        if node.choice_a:
            # Extract a short version of the first feature for the edge label
            feature = node.content.split(';')[0].strip()
            if len(feature) > 30:
                feature = feature[:27] + "..."
            
            dot.edge(node_id, node.choice_a.id, label='Yes', color='darkgreen', 
                    fontcolor='darkgreen', penwidth='1.5')
        
        if node.choice_b:
            dot.edge(node_id, node.choice_b.id, label='No', color='darkred', 
                    fontcolor='darkred', penwidth='1.5')
    
    # Connect title to root
    if root:
        dot.edge('title', root.id, style='dashed')
    
    # Save and render with higher resolution
    if not os.path.exists('visualizations'):
        os.makedirs('visualizations')
    
    dot.render('visualizations/arachnida_key_tree_vertical', format='png', cleanup=True)
    print(f"Visualization saved to visualizations/arachnida_key_tree_vertical.png")
    
    # Also generate a PDF version for better quality
    dot.render('visualizations/arachnida_key_tree_vertical', format='pdf', cleanup=True)
    print(f"PDF version saved to visualizations/arachnida_key_tree_vertical.pdf")

def main():
    # Get the manually defined key entries
    key_entries = get_arachnida_key()
    
    print(f"Found {len(key_entries)} key entries.")
    
    # Parse the entries
    parsed_entries = parse_key_entries(key_entries)
    print(f"Parsed {len(parsed_entries)} entries.")
    
    # Build the tree
    root, nodes = build_tree(parsed_entries)
    if not root:
        print("Failed to build the tree: Root node not found.")
        return
    
    print(f"Built tree with {len(nodes)} nodes.")
    
    # Visualize the tree
    visualize_tree(root, nodes)

if __name__ == "__main__":
    main() 