# Arachnida Key in Various Tree Formats

This directory contains the "Key to the Orders of Arachnida" represented in various tree data structures and formats.

## Overview

The Arachnida key from "Borror and DeLong's Study of Insects" has been converted to multiple tree formats, each with its own characteristics and uses. These formats can be used for different applications such as visualization, data processing, or integration with different software libraries.

## Available Formats

### Generic JSON (`arachnida_generic.json`)
A simple JSON format that represents the tree structure with nodes and their relationships. This format is library-agnostic and easy to parse in any programming language.

### Graphviz (`arachnida_graphviz.dot`, `.png`, `.pdf`)
A visual representation using the Graphviz DOT language. The PNG and PDF files provide ready-to-use visualizations, while the DOT file can be modified or rendered with different styles.

### Anytree (`arachnida_anytree.json`, `.png`)
Uses the [anytree](https://anytree.readthedocs.io/) library format, which is useful for tree traversal, manipulation, and visualization in Python.

### Treelib (`arachnida_treelib.txt`, `.json`)
Uses the [treelib](https://treelib.readthedocs.io/) library format, which provides a simple implementation of tree data structures and utility functions.

### ETE3 (`arachnida_ete3.newick`, `.txt`)
Represents the tree in [ETE Toolkit](http://etetoolkit.org/) format, which is commonly used for working with hierarchical trees in computational biology.

### Binarytree (`arachnida_binarytree.txt`, `.pkl`)
Uses the [binarytree](https://binarytree.readthedocs.io/) library for representing binary trees, with nodes that can have at most two children (choice_a and choice_b).

### Scikit-learn (`arachnida_sklearn.dot`, `.png`, `.pkl`, `_mapping.json`)
Represents the key as a decision tree using scikit-learn, which can be used for machine learning applications. The mapping file provides a reference between the node indices in scikit-learn and the original key entries.

## Usage

Each format can be loaded using its corresponding library. Here are some examples:

### Loading the Generic JSON

```python
import json

with open('tree_formats/arachnida_generic.json', 'r') as f:
    tree_data = json.load(f)
    
root_id = tree_data['root']
nodes = tree_data['nodes']
```

### Loading the Anytree Format

```python
from anytree.importer import JsonImporter
from anytree import RenderTree

importer = JsonImporter()
with open('tree_formats/arachnida_anytree.json', 'r') as f:
    root = importer.read(f)
    
# Print the tree
for pre, _, node in RenderTree(root):
    print(f"{pre}{node.name}")
```

### Loading the Treelib Format

```python
from treelib import Tree
import json

with open('tree_formats/arachnida_treelib.json', 'r') as f:
    tree_data = json.load(f)
    
tree = Tree()
# Reconstruct the tree from the JSON data
for node in tree_data['nodes']:
    if node['id'] == 'title':
        tree.create_node(node['tag'], node['id'])
    
# Add all other nodes
for edge in tree_data['edges']:
    # Find the node data
    node_data = next(n for n in tree_data['nodes'] if n['id'] == edge['target'])
    tree.create_node(node_data['tag'], node_data['id'], parent=edge['source'])
    
# Print the tree
print(tree.show())
```

### Loading the Binarytree Format

```python
import pickle

with open('tree_formats/arachnida_binarytree.pkl', 'rb') as f:
    binary_tree = pickle.load(f)
    
# Print the tree
print(binary_tree)
```

### Loading the Scikit-learn Decision Tree

```python
import pickle
import json
from sklearn import tree
import matplotlib.pyplot as plt

# Load the trained model
with open('tree_formats/arachnida_sklearn.pkl', 'rb') as f:
    clf = pickle.load(f)
    
# Load the mapping between indices and node data
with open('tree_formats/arachnida_sklearn_mapping.json', 'r') as f:
    node_mapping = json.load(f)
    
# Visualize the decision tree
plt.figure(figsize=(20, 10))
tree.plot_tree(clf, feature_names=['Node ID'], class_names=['Decision', 'Order'], 
                filled=True, rounded=True, fontsize=10)
plt.show()
```

## Tree Structure

All formats follow the same basic structure:

1. The root node represents the starting point of the key: "Opisthosoma (abdomen) unsegmented or segmented with spinnerets"
2. Each node has up to two children:
   - `choice_a` represents the "Yes" path (the specimen matches the description)
   - `choice_b` represents the "No" path (the specimen does not match)
3. Terminal nodes (green in visualizations) identify specific orders of Arachnida

## Note on Dichotomous Keys

A dichotomous key is a tool that allows the user to determine the identity of items through a pathway of choices. Each choice leads to another set of choices, until a determination is made. In our case, the key helps identify the orders of Arachnida (spiders, scorpions, mites, etc.) based on observable characteristics. 