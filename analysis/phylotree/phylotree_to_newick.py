#!/usr/bin/env python3
"""
Script to fetch and parse phylotree XML into Newick format.
"""

import requests
from lxml import etree
import json

class PhyloNode:
    def __init__(self, name):
        self.name = name
        self.children = []
        self.mutations = []

    def add_child(self, child):
        self.children.append(child)

    def add_mutation(self, mutation):
        self.mutations.append(mutation)

    def to_newick(self):
        if not self.children:
            return self.name
        
        children_str = ','.join(child.to_newick() for child in self.children)
        return f"({children_str}){self.name}"

def fetch_xml(url):
    try:
        response = requests.get(url)
        response.raise_for_status()
        return response.content
    except requests.RequestException as e:
        print(f"Error fetching XML: {e}")
        return None

def parse_xml_to_tree(xml_content):
    try:
        root = etree.fromstring(xml_content)
        print("XML parsed successfully")
        return build_tree(root.find(".//haplogroup"))
    except etree.XMLSyntaxError as e:
        print(f"Error parsing XML: {e}")
        return None

def build_tree(node):
    if node is None:
        return None

    name = node.get('name')
    print(f"Processing node: {name}")
    
    tree_node = PhyloNode(name)
    
    # Get mutations from poly elements within details
    details = node.find('details')
    if details is not None:
        mutations = details.findall('poly')
        for mutation in mutations:
            if mutation.text:
                tree_node.add_mutation(mutation.text)
    
    print(f"Found {len(tree_node.mutations)} mutations for {name}")
    
    # Process child haplogroups
    for child in node.findall('./haplogroup'):
        child_node = build_tree(child)
        if child_node:
            tree_node.add_child(child_node)
    
    print(f"Found {len(tree_node.children)} children for {name}")
    return tree_node

def save_tree(tree, output_file):
    if tree:
        newick = tree.to_newick()
        with open(output_file, 'w') as f:
            f.write(newick)
        print(f"Tree saved to {output_file}")
        
        # Save mutations to JSON
        mutations_dict = {}
        def collect_mutations(node):
            if node.mutations:
                mutations_dict[node.name] = node.mutations
            for child in node.children:
                collect_mutations(child)
        
        collect_mutations(tree)
        
        mutations_file = output_file.replace('.txt', '_mutations.json')
        with open(mutations_file, 'w') as f:
            json.dump(mutations_dict, f, indent=2)
        print(f"Mutations saved to {mutations_file}")
    else:
        print("No tree to save")

def main():
    url = "https://raw.githubusercontent.com/trichelab/MTseekerData/refs/heads/master/inst/extdata/haplogrep_data/phylotree/phylotree17.xml"
    xml_content = fetch_xml(url)
    
    if xml_content:
        tree = parse_xml_to_tree(xml_content)
        if tree:
            save_tree(tree, "phylotree.txt")
        else:
            print("Failed to build tree")
    else:
        print("Failed to fetch XML")

if __name__ == "__main__":
    main() 