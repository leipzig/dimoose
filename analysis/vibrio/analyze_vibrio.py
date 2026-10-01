import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
from sklearn.cluster import KMeans, DBSCAN
from sklearn.manifold import TSNE
import matplotlib.pyplot as plt
from sklearn.metrics import silhouette_score
from sklearn.impute import SimpleImputer
import seaborn as sns

# Read the data
df = pd.read_csv('vibrio.tsv', sep='\t', index_col=0)

# Remove non-data columns
df = df.drop(['Acid from:', 'Resistance to: '], axis=1)

# Replace special characters with numeric values
replacement_dict = {
    '+': 1.0,
    '-': 0.0,
    'v': 0.5,
    '(+)': 0.75,
    '(-)': 0.25,
    'ND': np.nan,
    'd': 0.5,
    '': np.nan  # Handle empty cells
}

# Create a copy of the dataframe for processing
df_processed = df.copy()

# Convert data to numeric format
for col in df_processed.columns:
    df_processed[col] = df_processed[col].map(replacement_dict)

# Convert to float type
df_processed = df_processed.astype(float)

# Use SimpleImputer to handle missing values
imputer = SimpleImputer(strategy='mean')
X = imputer.fit_transform(df_processed)

# Prepare features for analysis
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# 1. PCA Analysis
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

# 2. K-means Clustering
# Find optimal number of clusters using silhouette score
silhouette_scores = []
K = range(2, 11)
for k in K:
    kmeans = KMeans(n_clusters=k, random_state=42)
    kmeans.fit(X_scaled)
    score = silhouette_score(X_scaled, kmeans.labels_)
    silhouette_scores.append(score)

optimal_k = K[np.argmax(silhouette_scores)]
kmeans = KMeans(n_clusters=optimal_k, random_state=42)
kmeans_labels = kmeans.fit_predict(X_scaled)

# 3. DBSCAN Clustering
dbscan = DBSCAN(eps=2.5, min_samples=3)
dbscan_labels = dbscan.fit_predict(X_scaled)

# 4. t-SNE visualization
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

# Save results to a file
with open('clustering_analysis.txt', 'w') as f:
    f.write('Vibrio Species Clustering Analysis\n')
    f.write('================================\n\n')
    
    f.write('1. K-means Clustering Results\n')
    f.write(f'Optimal number of clusters: {optimal_k}\n')
    f.write('Species in each cluster:\n')
    for cluster in range(optimal_k):
        species_in_cluster = df.index[kmeans_labels == cluster]
        f.write(f'\nCluster {cluster + 1}:\n')
        for sp in species_in_cluster:
            f.write(f'- {sp}\n')
    
    f.write('\n2. DBSCAN Clustering Results\n')
    n_clusters = len(set(dbscan_labels)) - (1 if -1 in dbscan_labels else 0)
    f.write(f'Number of clusters: {n_clusters}\n')
    f.write('Species in each cluster:\n')
    for cluster in range(-1, max(dbscan_labels) + 1):
        species_in_cluster = df.index[dbscan_labels == cluster]
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
    
    # Add feature importance analysis
    f.write('\n4. Most Important Features\n')
    feature_importance = pd.DataFrame(
        abs(pca.components_[0]),
        index=df.columns,
        columns=['Importance']
    ).sort_values('Importance', ascending=False)
    
    f.write('Top 10 most important biochemical characteristics:\n')
    for idx, row in feature_importance.head(10).iterrows():
        f.write(f'- {idx}: {row["Importance"]:.3f}\n')

    # Add cluster characteristics
    f.write('\n5. Cluster Characteristics\n')
    df_processed['Cluster'] = kmeans_labels
    for cluster in range(optimal_k):
        f.write(f'\nCluster {cluster + 1} characteristics:\n')
        cluster_mean = df_processed[df_processed['Cluster'] == cluster].mean()
        top_features = cluster_mean.sort_values(ascending=False)[:5]
        f.write('Top 5 most common characteristics:\n')
        for feat, val in top_features.items():
            if feat != 'Cluster':
                f.write(f'- {feat}: {val:.3f}\n')

print("Analysis complete. Results saved to 'clustering_analysis.txt' and visualizations saved as PNG files.") 