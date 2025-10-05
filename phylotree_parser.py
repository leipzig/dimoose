#!/usr/bin/env python3
"""
Phylotree Parser
----------------
Parses phylotree.txt (Newick format with mutations) and produces clean Newick output.
The phylotree format includes mutations as annotations on node names (e.g., H2a2a+16235).
This parser can:
1. Parse the existing Newick format from phylotree.txt
2. Extract haplogroup names and mutations
3. Produce a clean Newick tree
4. Generate structured JSON output with haplogroup hierarchy
"""

import re
import json
import argparse
from typing import Dict, List, Optional, Tuple


class PhyloNode:
    """Represents a node in the phylogenetic tree."""
    
    def __init__(self, name: str):
        self.name = name
        self.mutations = []
        self.children = []
        self.parent = None
        
    def add_child(self, child: 'PhyloNode'):
        """Add a child node."""
        child.parent = self
        self.children.append(child)
        
    def add_mutation(self, mutation: str):
        """Add a mutation to this node."""
        self.mutations.append(mutation)
    
    def to_newick(self, include_mutations: bool = False) -> str:
        """Convert node and descendants to Newick format."""
        if not self.children:
            # Leaf node
            if include_mutations and self.mutations:
                return f"{self.name}_{'+'.join(self.mutations)}"
            return self.name
        
        # Internal node with children
        children_str = ','.join(child.to_newick(include_mutations) for child in self.children)
        
        if include_mutations and self.mutations:
            return f"({children_str}){self.name}_{'+'.join(self.mutations)}"
        return f"({children_str}){self.name}"
    
    def to_dict(self) -> Dict:
        """Convert node to dictionary representation."""
        return {
            'name': self.name,
            'mutations': self.mutations,
            'children': [child.to_dict() for child in self.children]
        }
    
    def __repr__(self):
        return f"PhyloNode({self.name}, mutations={self.mutations}, children={len(self.children)})"


class PhylotreeParser:
    """Parser for phylotree Newick format."""
    
    def __init__(self):
        self.root = None
        
    def parse_file(self, filepath: str) -> PhyloNode:
        """Parse a phylotree file in Newick format."""
        with open(filepath, 'r') as f:
            newick_str = f.read().strip()
        
        return self.parse_newick(newick_str)
    
    def parse_newick(self, newick_str: str) -> PhyloNode:
        """Parse a Newick format string with mutation annotations.
        
        The phylotree format includes mutations in the form:
        - H2a2a+(16235) - node with mutation
        - H2a2a+16235 - node with mutation (alternative format)
        - (children)H2a2a - internal node
        - H2a2a - simple leaf node
        """
        # Remove trailing semicolon if present
        newick_str = newick_str.rstrip(';').strip()
        
        # Parse the tree structure
        self.root, _ = self._parse_node(newick_str)
        return self.root
    
    def _parse_node(self, s: str, start: int = 0) -> Tuple[PhyloNode, int]:
        """Recursively parse a node from the Newick string.
        
        Returns: (PhyloNode, end_position)
        """
        pos = start
        node = None
        
        # Check if this node has children (starts with '(')
        if pos < len(s) and s[pos] == '(':
            # Parse children
            pos += 1  # Skip '('
            children = []
            
            while pos < len(s) and s[pos] != ')':
                if s[pos] == ',':
                    pos += 1  # Skip comma
                    continue
                
                child, pos = self._parse_node(s, pos)
                if child:
                    children.append(child)
            
            if pos < len(s) and s[pos] == ')':
                pos += 1  # Skip ')'
            
            # Parse node label after ')'
            label, mutations, pos = self._parse_label(s, pos)
            
            node = PhyloNode(label if label else 'unnamed')
            for mutation in mutations:
                node.add_mutation(mutation)
            
            for child in children:
                node.add_child(child)
        else:
            # Leaf node - parse label
            label, mutations, pos = self._parse_label(s, pos)
            node = PhyloNode(label if label else 'unnamed')
            for mutation in mutations:
                node.add_mutation(mutation)
        
        return node, pos
    
    def _parse_label(self, s: str, start: int) -> Tuple[str, List[str], int]:
        """Parse a node label including mutations.
        
        Formats handled:
        - H2a2a+(16235) - with parentheses
        - H2a2a+16235 - without parentheses  
        - H2a2a+16235+152 - multiple mutations
        - H2a2a+@16298 - @ prefix (uncertain?)
        - H2a2a+(114)+152 - mixed formats
        
        Returns: (label, [mutations], end_position)
        """
        pos = start
        label = []
        mutations = []
        
        # Read until we hit a delimiter: ',', ')', or end
        while pos < len(s) and s[pos] not in ',)':
            # Check for mutation marker '+'
            if s[pos] == '+':
                # Extract the base label if we haven't yet
                if not label or label[-1] == '+':
                    # The label is everything before the first '+'
                    label_str = ''.join(label).rstrip('+')
                    if not label_str:
                        # Look backwards to find where the label started
                        # This handles cases where we're at the start
                        pass
                    
                # Skip the '+'
                pos += 1
                
                # Check if mutation is in parentheses
                if pos < len(s) and s[pos] == '(':
                    pos += 1  # Skip '('
                    mutation = []
                    while pos < len(s) and s[pos] != ')':
                        mutation.append(s[pos])
                        pos += 1
                    if pos < len(s) and s[pos] == ')':
                        pos += 1  # Skip ')'
                    mutations.append(''.join(mutation))
                else:
                    # Mutation without parentheses
                    # Read until next '+', ',', ')', or space
                    mutation = []
                    while pos < len(s) and s[pos] not in '+,) ':
                        mutation.append(s[pos])
                        pos += 1
                    mutations.append(''.join(mutation))
            else:
                label.append(s[pos])
                pos += 1
        
        # Clean up the label - remove trailing '+'
        label_str = ''.join(label).rstrip('+').strip()
        
        return label_str, mutations, pos
    
    def to_newick(self, include_mutations: bool = False) -> str:
        """Convert the tree to Newick format."""
        if not self.root:
            return ""
        return self.root.to_newick(include_mutations) + ";"
    
    def to_json(self, output_file: Optional[str] = None) -> Dict:
        """Convert the tree to JSON format."""
        if not self.root:
            return {}
        
        tree_dict = {
            'title': 'Phylotree - Human Mitochondrial DNA Tree',
            'root': self.root.to_dict()
        }
        
        if output_file:
            with open(output_file, 'w') as f:
                json.dump(tree_dict, f, indent=2)
        
        return tree_dict
    
    def extract_mutations(self) -> Dict[str, List[str]]:
        """Extract all haplogroup-mutation mappings."""
        mutations_dict = {}
        
        def traverse(node):
            if node.mutations:
                mutations_dict[node.name] = node.mutations
            for child in node.children:
                traverse(child)
        
        if self.root:
            traverse(self.root)
        
        return mutations_dict
    
    def get_statistics(self) -> Dict:
        """Get statistics about the tree."""
        stats = {
            'total_nodes': 0,
            'leaf_nodes': 0,
            'internal_nodes': 0,
            'nodes_with_mutations': 0,
            'total_mutations': 0,
            'max_depth': 0
        }
        
        def traverse(node, depth=0):
            stats['total_nodes'] += 1
            stats['max_depth'] = max(stats['max_depth'], depth)
            
            if node.mutations:
                stats['nodes_with_mutations'] += 1
                stats['total_mutations'] += len(node.mutations)
            
            if not node.children:
                stats['leaf_nodes'] += 1
            else:
                stats['internal_nodes'] += 1
                for child in node.children:
                    traverse(child, depth + 1)
        
        if self.root:
            traverse(self.root)
        
        return stats


def main():
    """Main function to demonstrate the parser."""
    parser = argparse.ArgumentParser(
        description='Parse phylotree.txt and produce Newick format',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Parse and output clean Newick
  python phylotree_parser.py phylotree.txt -o output.newick
  
  # Include mutations in Newick output
  python phylotree_parser.py phylotree.txt -o output.newick --include-mutations
  
  # Output as JSON
  python phylotree_parser.py phylotree.txt --json output.json
  
  # Show statistics
  python phylotree_parser.py phylotree.txt --stats
  
  # Extract mutations to JSON
  python phylotree_parser.py phylotree.txt --mutations mutations.json
        """
    )
    
    parser.add_argument('input', help='Input phylotree file (Newick format)')
    parser.add_argument('-o', '--output', help='Output Newick file')
    parser.add_argument('--include-mutations', action='store_true',
                       help='Include mutations in Newick output')
    parser.add_argument('--json', help='Output tree as JSON')
    parser.add_argument('--mutations', help='Extract mutations to JSON file')
    parser.add_argument('--stats', action='store_true',
                       help='Display tree statistics')
    
    args = parser.parse_args()
    
    # Parse the tree
    print(f"Parsing {args.input}...")
    phylo_parser = PhylotreeParser()
    
    try:
        phylo_parser.parse_file(args.input)
        print("✓ Successfully parsed phylotree")
    except Exception as e:
        print(f"✗ Error parsing phylotree: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    # Output Newick format
    if args.output:
        newick = phylo_parser.to_newick(include_mutations=args.include_mutations)
        with open(args.output, 'w') as f:
            f.write(newick)
        print(f"✓ Newick format saved to {args.output}")
    
    # Output JSON format
    if args.json:
        phylo_parser.to_json(args.json)
        print(f"✓ JSON format saved to {args.json}")
    
    # Extract mutations
    if args.mutations:
        mutations = phylo_parser.extract_mutations()
        with open(args.mutations, 'w') as f:
            json.dump(mutations, f, indent=2)
        print(f"✓ Mutations saved to {args.mutations}")
    
    # Show statistics
    if args.stats:
        stats = phylo_parser.get_statistics()
        print("\n📊 Tree Statistics:")
        print(f"  Total nodes: {stats['total_nodes']}")
        print(f"  Leaf nodes: {stats['leaf_nodes']}")
        print(f"  Internal nodes: {stats['internal_nodes']}")
        print(f"  Nodes with mutations: {stats['nodes_with_mutations']}")
        print(f"  Total mutations: {stats['total_mutations']}")
        print(f"  Maximum depth: {stats['max_depth']}")
    
    # If no output specified, print a preview
    if not (args.output or args.json or args.mutations or args.stats):
        print("\nPreview (first 500 characters of Newick format):")
        newick = phylo_parser.to_newick(include_mutations=False)
        print(newick[:500] + "...")
        print("\nUse --help to see output options")
    
    return 0


if __name__ == '__main__':
    exit(main())
