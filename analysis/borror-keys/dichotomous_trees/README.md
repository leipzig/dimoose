# Dichotomous Tree Extraction

This project extracts dichotomous keys from the "Borror and DeLong's Study of Insects" text and converts them into tree data structures.

## Files

- `extract_keys.py` - Initial script to extract dichotomous keys
- `extract_keys_improved.py` - Improved version with better tree structure
- `simple_extract_keys.py` - Simplified approach focusing on couplet extraction

## Directories

- `dichotomous_keys/` - Output from the initial extraction attempts
- `insect_keys/` - Output from the simplified extraction approach
  - `visualizations/` - Visualizations of extracted dichotomous keys

## Extracted Keys

The extraction found several dichotomous keys, including:

1. Key to the Orders of Arachnida (Spiders and their relatives)
2. Key to the Orders of Diplopoda (Millipedes) 
3. Key to the Orders of Chilopoda (Centipedes)
4. Various keys to families within insect orders

## Visualization

The visualizations represent the dichotomous keys as directed graphs, with:
- Green nodes for key titles
- Blue nodes for couplet points
- White nodes for choice options (A and B)

## Data Structure

The JSON representation of each key includes:
- Title
- Entries (all numbered couplet items)
- Couplets (structured representation of paired choices)

## Usage

To generate visualizations:
```
cd insect_keys
python visualize_couplets.py
```

The resulting images will be saved in the `visualizations/` directory. 