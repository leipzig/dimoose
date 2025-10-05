# Phylotree Parser

A Python parser for phylotree.txt files in Newick format with mutation annotations.

## Overview

The phylotree format represents human mitochondrial DNA haplogroups as a phylogenetic tree in Newick format, with mutations annotated on the nodes. This parser can:

1. Parse the Newick format with mutation annotations (e.g., `H2a2a+16235`)
2. Extract haplogroup names and mutations separately
3. Produce clean Newick trees (with or without mutations)
4. Generate structured JSON output with haplogroup hierarchy
5. Extract mutation mappings to JSON
6. Provide tree statistics

## Usage

### Basic Parsing and Statistics

```bash
python3 phylotree_parser.py phylotree.txt --stats
```

Output:
```
📊 Tree Statistics:
  Total nodes: 5435
  Leaf nodes: 3015
  Internal nodes: 2420
  Nodes with mutations: 255
  Total mutations: 281
  Maximum depth: 27
```

### Generate Clean Newick Format

```bash
# Without mutations
python3 phylotree_parser.py phylotree.txt -o output.newick

# With mutations included
python3 phylotree_parser.py phylotree.txt -o output.newick --include-mutations
```

### Extract Mutations to JSON

```bash
python3 phylotree_parser.py phylotree.txt --mutations mutations.json
```

Example output:
```json
{
  "H2a2a": ["16235"],
  "H2a1": ["146"],
  "H1": ["16311"],
  "H1n": ["146", "195"]
}
```

### Generate Tree as JSON

```bash
python3 phylotree_parser.py phylotree.txt --json tree.json
```

### Combined Operations

```bash
python3 phylotree_parser.py phylotree.txt \
  -o output.newick \
  --json tree.json \
  --mutations mutations.json \
  --stats
```

## Mutation Format

The phylotree format includes various mutation notations:

- `H2a2a+(16235)` - Mutation in parentheses
- `H2a2a+16235` - Mutation without parentheses
- `H2a2a+16235+152` - Multiple mutations
- `H2a2a+@16298` - Uncertain mutation (@ prefix)
- `H2a2a+(114)+152` - Mixed format

The parser handles all these formats and extracts the mutations correctly.

## Architecture

### PhyloNode Class

Represents a node in the phylogenetic tree with:
- `name`: Haplogroup name (e.g., "H2a2a")
- `mutations`: List of mutations (e.g., ["16235", "152"])
- `children`: List of child nodes
- `parent`: Reference to parent node

### PhylotreeParser Class

Main parser with methods:
- `parse_file(filepath)`: Parse a phylotree file
- `parse_newick(newick_str)`: Parse a Newick string
- `to_newick(include_mutations)`: Generate Newick format
- `to_json(output_file)`: Generate JSON representation
- `extract_mutations()`: Extract all mutation mappings
- `get_statistics()`: Get tree statistics

## Implementation Notes

The parser uses a recursive descent approach to parse the Newick format:

1. **Node Parsing**: Detects `(` for internal nodes, parses children recursively
2. **Label Parsing**: Extracts haplogroup names and mutations from labels
3. **Mutation Extraction**: Handles various mutation notation formats
4. **Tree Building**: Constructs PhyloNode objects with parent-child relationships

## Integration with Moose

This parser is designed to work with the moose package for dichotomous keys and phylogenetic trees. It provides a clean interface for working with phylotree data that can be:

- Converted to other tree formats (as demonstrated in `tree_formats/`)
- Used in R through the moose package
- Analyzed with machine learning tools (scikit-learn, etc.)
- Visualized with various tools (Graphviz, ete3, etc.)

## Testing

The parser has been tested with the full phylotree.txt file containing:
- 5,435 total nodes
- 3,015 leaf nodes (haplogroups)
- 2,420 internal nodes
- 255 nodes with mutations
- 281 total mutations
- Maximum tree depth of 27

## Requirements

- Python 3.6+
- No external dependencies (uses only standard library)

## Future Enhancements

Potential improvements:
- Add support for branch lengths if available
- Implement tree comparison and distance metrics
- Add visualization capabilities
- Support for reading directly from XML sources
- Integration with BioPython for phylogenetic analysis
