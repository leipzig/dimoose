#!/usr/bin/env python3
"""
Verify Phylotree Parser
-----------------------
This script extracts the phylotree structure from the official HTML file
and compares it with our Newick parser output to ensure correctness.
"""

import re
from html.parser import HTMLParser
from collections import defaultdict
import json
from phylotree_parser import PhylotreeParser


class PhylotreeHTMLParser(HTMLParser):
    """Parser for the official phylotree HTML file."""
    
    def __init__(self):
        super().__init__()
        self.in_table = False
        self.current_row = []
        self.rows = []
        self.in_td = False
        self.current_data = []
        
    def handle_starttag(self, tag, attrs):
        if tag == 'table':
            self.in_table = True
        elif tag == 'td' and self.in_table:
            self.in_td = True
            self.current_data = []
    
    def handle_endtag(self, tag):
        if tag == 'table':
            self.in_table = False
        elif tag == 'td' and self.in_td:
            self.in_td = False
            # Join the data and clean it
            data = ''.join(self.current_data).strip()
            self.current_row.append(data)
        elif tag == 'tr' and self.in_table:
            if self.current_row:
                self.rows.append(self.current_row)
            self.current_row = []
    
    def handle_data(self, data):
        if self.in_td:
            self.current_data.append(data)


def extract_haplogroups_from_html(html_file):
    """Extract haplogroup names and structure from HTML file."""
    with open(html_file, 'r', encoding='iso-8859-1') as f:
        content = f.read()
    
    haplogroups = {}
    mutations_map = {}
    
    # Use regex to extract haplogroup names from HTML
    # Pattern matches: >L0<, >H1a2b<, etc. in the HTML
    haplogroup_pattern = r'>([A-Z][0-9a-z\']*)<'
    matches = re.findall(haplogroup_pattern, content)
    
    for hg in matches:
        # Filter for valid haplogroup names
        # Must start with capital letter, contain alphanumeric and possibly prime
        if re.match(r'^[A-Z][0-9a-z\']+$', hg) and len(hg) <= 20:
            haplogroups[hg] = True
    
    # Also try to use HTMLParser for more structured extraction
    parser = PhylotreeHTMLParser()
    parser.feed(content)
    
    for row in parser.rows:
        if len(row) > 0 and row[0]:
            haplogroup = row[0].strip()
            if re.match(r'^[A-Z][0-9a-z\']+$', haplogroup) and len(haplogroup) <= 20:
                haplogroups[haplogroup] = True
                
                # Extract mutations from subsequent cells
                mutations = []
                for cell in row[1:10]:
                    if cell:
                        mutation_matches = re.findall(r'[ACGT]?\d+[ACGT]?\.?\d*[dinsACGT]*', cell)
                        mutations.extend(mutation_matches)
                
                if mutations:
                    mutations_map[haplogroup] = mutations
    
    return haplogroups, mutations_map


def extract_haplogroups_from_newick(newick_file):
    """Extract haplogroup names from Newick file using our parser."""
    parser = PhylotreeParser()
    parser.parse_file(newick_file)
    
    haplogroups = {}
    
    def traverse(node):
        haplogroups[node.name] = True
        for child in node.children:
            traverse(child)
    
    if parser.root:
        traverse(parser.root)
    
    return haplogroups


def compare_structures(html_haplogroups, newick_haplogroups):
    """Compare haplogroup structures between HTML and Newick."""
    html_set = set(html_haplogroups.keys())
    newick_set = set(newick_haplogroups.keys())
    
    in_both = html_set & newick_set
    only_in_html = html_set - newick_set
    only_in_newick = newick_set - html_set
    
    return {
        'in_both': in_both,
        'only_in_html': only_in_html,
        'only_in_newick': only_in_newick,
        'html_total': len(html_set),
        'newick_total': len(newick_set),
        'overlap': len(in_both)
    }


def verify_tree_structure(html_file, newick_file):
    """Main verification function."""
    print("=" * 70)
    print("PHYLOTREE VERIFICATION")
    print("=" * 70)
    
    print("\n1. Extracting haplogroups from HTML...")
    html_haplogroups, html_mutations = extract_haplogroups_from_html(html_file)
    print(f"   Found {len(html_haplogroups)} haplogroups in HTML")
    print(f"   Found {len(html_mutations)} haplogroups with mutations")
    
    print("\n2. Extracting haplogroups from Newick...")
    newick_haplogroups = extract_haplogroups_from_newick(newick_file)
    print(f"   Found {len(newick_haplogroups)} haplogroups in Newick")
    
    print("\n3. Comparing structures...")
    comparison = compare_structures(html_haplogroups, newick_haplogroups)
    
    print(f"\n   Haplogroups in both:     {comparison['overlap']}")
    print(f"   Only in HTML:            {len(comparison['only_in_html'])}")
    print(f"   Only in Newick:          {len(comparison['only_in_newick'])}")
    print(f"   HTML total:              {comparison['html_total']}")
    print(f"   Newick total:            {comparison['newick_total']}")
    
    overlap_percentage = (comparison['overlap'] / max(comparison['html_total'], comparison['newick_total'])) * 100
    print(f"\n   Overlap percentage:      {overlap_percentage:.1f}%")
    
    # Show samples
    if comparison['only_in_html']:
        print("\n4. Sample haplogroups only in HTML (first 20):")
        for hg in sorted(list(comparison['only_in_html']))[:20]:
            print(f"   - {hg}")
    
    if comparison['only_in_newick']:
        print("\n5. Sample haplogroups only in Newick (first 20):")
        for hg in sorted(list(comparison['only_in_newick']))[:20]:
            print(f"   - {hg}")
    
    # Verify some specific haplogroups
    print("\n6. Verifying specific well-known haplogroups:")
    test_haplogroups = ['L0', 'L1', 'L2', 'L3', 'H', 'H1', 'H2', 'U', 'J', 'R', 'N']
    for hg in test_haplogroups:
        in_html = hg in html_haplogroups
        in_newick = hg in newick_haplogroups
        status = "✓" if (in_html and in_newick) else "✗"
        print(f"   {status} {hg:10s} - HTML: {str(in_html):5s}  Newick: {str(in_newick):5s}")
    
    # Summary
    print("\n" + "=" * 70)
    if overlap_percentage > 90:
        print("✓ VERIFICATION PASSED - Good alignment between HTML and Newick")
    elif overlap_percentage > 75:
        print("⚠ VERIFICATION WARNING - Acceptable but some differences found")
    else:
        print("✗ VERIFICATION FAILED - Significant differences detected")
    print("=" * 70)
    
    return comparison


def main():
    html_file = "mtDNA tree Build 17.htm"
    newick_file = "/Users/leipzig/Documents/dev/moose/phylotree.txt"
    
    try:
        comparison = verify_tree_structure(html_file, newick_file)
        
        # Save comparison results
        with open('verification_results.json', 'w') as f:
            json.dump({
                'html_total': comparison['html_total'],
                'newick_total': comparison['newick_total'],
                'overlap': comparison['overlap'],
                'only_in_html': sorted(list(comparison['only_in_html'])),
                'only_in_newick': sorted(list(comparison['only_in_newick']))
            }, f, indent=2)
        print("\nDetailed results saved to verification_results.json")
        
    except FileNotFoundError as e:
        print(f"\n✗ Error: {e}")
        print("\nMake sure both files exist:")
        print(f"  - {html_file}")
        print(f"  - {newick_file}")
        return 1
    
    return 0


if __name__ == '__main__':
    exit(main())
