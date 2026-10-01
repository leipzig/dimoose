# Vibrio Species Analysis

This directory contains code and data for analyzing Vibrio species biochemical characteristics using machine learning approaches.

## Files

- `vibrio.tsv` - Input data containing biochemical test results for various Vibrio species
- `vibrio_analysis.py` - Main analysis script with machine learning models and visualizations
- `analyze_vibrio.py` - Initial analysis script focusing on clustering approaches

## Generated Output Files

- `feature_importance.png` - Visualization of important features from Random Forest and XGBoost models
- `clustering_results.png` - Visualization of clustering results using K-means and DBSCAN
- `clustering_results.csv` - Detailed clustering results for each species
- `clustering_analysis.txt` - In-depth analysis of clustering patterns
- `analysis_results.txt` - Feature importance analysis results
- `pca_variance.png` - PCA explained variance plot
- `decision_tree.png` - Visualization of a decision tree model
- `decision_tree.txt` - Detailed decision tree structure and comparison with traditional A/L/O tests

## Analysis Methods

The analysis includes:
1. Feature importance analysis using Random Forest and XGBoost
2. Clustering analysis using K-means and DBSCAN
3. Dimensionality reduction using PCA and t-SNE
4. Decision tree analysis for comparison with traditional dichotomous keys

## Requirements

Required Python packages:
- pandas
- numpy
- scikit-learn
- matplotlib
- seaborn
- xgboost

These can be installed in a virtual environment using the requirements in the root directory. 