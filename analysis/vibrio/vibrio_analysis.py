import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.impute import SimpleImputer
from sklearn.ensemble import RandomForestClassifier
from sklearn.tree import DecisionTreeClassifier, plot_tree, export_text
from sklearn.cluster import KMeans, DBSCAN
from sklearn.decomposition import PCA
from sklearn.manifold import TSNE
from sklearn.metrics import silhouette_score
import xgboost as xgb

# Set non-interactive backend for matplotlib
plt.switch_backend('Agg')

def load_data():
    print("Loading data...")
    # Read the TSV file
    df = pd.read_csv('vibrio.tsv', sep='\t')
    
    print("\nDataFrame Info:")
    print(df.info())
    print("\nFirst few rows:")
    print(df.head())
    
    return df

def prepare_data(df):
    print("\nPreparing data...")
    
    # Get the species column name (first column)
    species_col = df.columns[0]
    
    # Remove non-data columns
    data_df = df.copy()
    if 'Acid from:' in df.columns:
        data_df = data_df.drop(['Acid from:'], axis=1)
    if 'Resistance to: ' in df.columns:
        data_df = data_df.drop(['Resistance to: '], axis=1)
    
    # Create mapping for special characters
    replacement_dict = {
        '+': 1.0,
        '-': 0.0,
        'd': 0.5,  # for "variable" results
        'v': 0.5,  # for "variable" results
        '(+)': 0.75,
        '(-)': 0.25,
        'ND': np.nan,  # for "Not Determined"
        '': np.nan  # Handle empty cells
    }
    
    # Convert data to numeric using the mapping
    for col in data_df.columns:
        if col != species_col:
            data_df[col] = data_df[col].map(replacement_dict)
    
    # Handle missing values
    imputer = SimpleImputer(strategy='mean')
    X = imputer.fit_transform(data_df.drop(species_col, axis=1))
    
    # Scale the features
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    # Create integer labels for species
    le = LabelEncoder()
    y = le.fit_transform(data_df[species_col])
    
    # Print number of samples per species
    species_counts = data_df[species_col].value_counts()
    print("\nNumber of samples per species:")
    print(species_counts)
    print("\nTotal number of species:", len(species_counts))
    print()
    
    return X_scaled, y, data_df, le.classes_

def analyze_features(X_scaled, y, df, species_names, feature_names):
    print("Analyzing features...")
    
    # Train Random Forest
    rf = RandomForestClassifier(n_estimators=100, random_state=42)
    rf.fit(X_scaled, y)
    
    # Get feature importance from Random Forest
    feature_importance_rf = pd.DataFrame({
        'feature': feature_names,
        'importance': rf.feature_importances_
    }).sort_values('importance', ascending=False)
    
    # Train a single decision tree for visualization
    dt = DecisionTreeClassifier(random_state=42, max_depth=4)
    dt.fit(X_scaled, y)
    
    # Plot the decision tree
    plt.figure(figsize=(20, 10))
    plot_tree(dt, feature_names=feature_names, class_names=species_names, filled=True, rounded=True)
    plt.savefig('decision_tree.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # Save tree structure as text
    tree_text = export_text(dt, feature_names=feature_names)
    with open('decision_tree.txt', 'w') as f:
        f.write("Decision Tree Structure:\n")
        f.write("======================\n\n")
        f.write(tree_text)
        f.write("\n\nComparison with Paper's A/L/O Primary Tests:\n")
        f.write("=========================================\n")
        alo_tests = ['Arginine dihydrolase (moller)', 'Lysine decarboxylase(Moller)', 'Ornithine decarboxylase(moller)']
        f.write("\nImportance of A/L/O tests in Random Forest:\n")
        for test in alo_tests:
            importance = feature_importance_rf[feature_importance_rf['feature'] == test]['importance'].values
            if len(importance) > 0:
                f.write(f"{test}: {importance[0]:.4f}\n")
    
    # Train XGBoost
    xgb_clf = xgb.XGBClassifier(n_estimators=100, random_state=42)
    xgb_clf.fit(X_scaled, y)
    
    # Get feature importance from XGBoost
    feature_importance_xgb = pd.DataFrame({
        'feature': feature_names,
        'importance': xgb_clf.feature_importances_
    }).sort_values('importance', ascending=False)
    
    # Plot top 15 important features for both models
    plt.figure(figsize=(12, 6))
    
    plt.subplot(1, 2, 1)
    sns.barplot(data=feature_importance_rf.head(15), x='importance', y='feature')
    plt.title('Top 15 Important Features (Random Forest)')
    plt.tight_layout()
    
    plt.subplot(1, 2, 2)
    sns.barplot(data=feature_importance_xgb.head(15), x='importance', y='feature')
    plt.title('Top 15 Important Features (XGBoost)')
    plt.tight_layout()
    
    plt.savefig('feature_importance.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    return feature_importance_rf, feature_importance_xgb

def perform_clustering(X_scaled, species_names, feature_names):
    print("Performing clustering analysis...")
    
    # PCA for dimensionality reduction
    pca = PCA()
    X_pca = pca.fit_transform(X_scaled)
    
    # Plot explained variance ratio
    plt.figure(figsize=(10, 6))
    plt.plot(range(1, len(pca.explained_variance_ratio_) + 1), np.cumsum(pca.explained_variance_ratio_))
    plt.xlabel('Number of Components')
    plt.ylabel('Cumulative Explained Variance Ratio')
    plt.title('PCA Explained Variance Ratio')
    plt.grid(True)
    plt.savefig('pca_variance.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # Find optimal number of clusters using silhouette score
    silhouette_scores = []
    K = range(2, 11)
    for k in K:
        kmeans = KMeans(n_clusters=k, random_state=42)
        kmeans.fit(X_scaled)
        score = silhouette_score(X_scaled, kmeans.labels_)
        silhouette_scores.append(score)
    
    optimal_k = K[np.argmax(silhouette_scores)]
    
    # K-means clustering with optimal k
    kmeans = KMeans(n_clusters=optimal_k, random_state=42)
    kmeans_labels = kmeans.fit_predict(X_scaled)
    
    # DBSCAN clustering
    dbscan = DBSCAN(eps=2.5, min_samples=2)
    dbscan_labels = dbscan.fit_predict(X_scaled)
    
    # t-SNE for visualization
    tsne = TSNE(n_components=2, random_state=42)
    X_tsne = tsne.fit_transform(X_scaled)
    
    # Create visualizations
    plt.figure(figsize=(20, 6))
    
    # t-SNE with K-means
    plt.subplot(131)
    scatter = plt.scatter(X_tsne[:, 0], X_tsne[:, 1], c=kmeans_labels, cmap='viridis')
    plt.title(f'K-means Clustering (k={optimal_k})')
    plt.colorbar(scatter)
    plt.grid(True)
    
    # t-SNE with DBSCAN
    plt.subplot(132)
    scatter = plt.scatter(X_tsne[:, 0], X_tsne[:, 1], c=dbscan_labels, cmap='viridis')
    plt.title('DBSCAN Clustering')
    plt.colorbar(scatter)
    plt.grid(True)
    
    # PCA (first two components)
    plt.subplot(133)
    scatter = plt.scatter(X_pca[:, 0], X_pca[:, 1], c=kmeans_labels, cmap='viridis')
    plt.title('PCA (First Two Components)')
    plt.colorbar(scatter)
    plt.grid(True)
    
    plt.tight_layout()
    plt.savefig('clustering_results.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # Save clustering results
    results = pd.DataFrame({
        'Species': species_names,
        'KMeans_Cluster': kmeans_labels,
        'DBSCAN_Cluster': dbscan_labels,
        'PCA1': X_pca[:, 0],
        'PCA2': X_pca[:, 1],
        'tSNE1': X_tsne[:, 0],
        'tSNE2': X_tsne[:, 1]
    })
    
    results.to_csv('clustering_results.csv', index=False)
    
    # Save detailed analysis
    with open('clustering_analysis.txt', 'w') as f:
        f.write('Vibrio Species Clustering Analysis\n')
        f.write('================================\n\n')
        
        f.write('1. K-means Clustering Results\n')
        f.write(f'Optimal number of clusters: {optimal_k}\n')
        f.write('Species in each cluster:\n')
        for cluster in range(optimal_k):
            species_in_cluster = species_names[kmeans_labels == cluster]
            f.write(f'\nCluster {cluster + 1}:\n')
            for sp in species_in_cluster:
                f.write(f'- {sp}\n')
        
        f.write('\n2. DBSCAN Clustering Results\n')
        n_clusters = len(set(dbscan_labels)) - (1 if -1 in dbscan_labels else 0)
        f.write(f'Number of clusters: {n_clusters}\n')
        f.write('Species in each cluster:\n')
        for cluster in range(-1, max(dbscan_labels) + 1):
            species_in_cluster = species_names[dbscan_labels == cluster]
            if cluster == -1:
                f.write('\nNoise points (outliers):\n')
            else:
                f.write(f'\nCluster {cluster + 1}:\n')
            for sp in species_in_cluster:
                f.write(f'- {sp}\n')
        
        f.write('\n3. PCA Analysis\n')
        f.write('Cumulative explained variance ratio for first 5 components:\n')
        cum_var_ratio = np.cumsum(pca.explained_variance_ratio_)
        for i, ratio in enumerate(cum_var_ratio[:5], 1):
            f.write(f'Component {i}: {ratio:.3f}\n')
    
    return results, optimal_k, pca

def main():
    # Load and prepare data
    df = load_data()
    X_scaled, y, data_df, species_names = prepare_data(df)
    
    # Get feature names (excluding species column and other non-data columns)
    feature_names = [col for col in data_df.columns if col not in [df.columns[0], 'Acid from:', 'Resistance to: ']]
    
    # Analyze features
    rf_importance, xgb_importance = analyze_features(X_scaled, y, data_df, species_names, feature_names)
    
    # Perform clustering
    clustering_results, optimal_k, pca = perform_clustering(X_scaled, species_names, feature_names)
    
    # Save feature importance analysis
    with open('analysis_results.txt', 'w') as f:
        f.write("Feature Importance Analysis\n")
        f.write("=========================\n\n")
        
        f.write("1. Random Forest Important Features\n")
        f.write(rf_importance.head(15).to_string())
        
        f.write("\n\n2. XGBoost Important Features\n")
        f.write(xgb_importance.head(15).to_string())
        
        f.write("\n\n3. Common Important Features\n")
        common_features = set(rf_importance.head(10)['feature']) & set(xgb_importance.head(10)['feature'])
        f.write("\n".join(common_features))
        
        f.write("\n\n4. PCA Feature Importance\n")
        pca_importance = pd.DataFrame(
            abs(pca.components_[0]),
            index=feature_names,
            columns=['Importance']
        ).sort_values('Importance', ascending=False)
        
        f.write('\nTop 10 most important features (PCA):\n')
        f.write(pca_importance.head(10).to_string())
    
    print("\nAnalysis complete! Results have been saved to:")
    print("- feature_importance.png")
    print("- clustering_results.png")
    print("- clustering_results.csv")
    print("- clustering_analysis.txt")
    print("- analysis_results.txt")
    print("- pca_variance.png")

if __name__ == "__main__":
    main() 