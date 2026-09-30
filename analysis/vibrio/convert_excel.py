import pandas as pd

# Read the Excel file
df = pd.read_excel('vibrio.xlsx')

# Replace special characters in column names
df.columns = df.columns.str.replace('°', ' deg ')  # Replace degree symbol
df.columns = df.columns.str.replace('₂', '2')      # Replace subscript 2
df.columns = df.columns.str.replace('ꭒ', 'u')      # Replace special u character
df.columns = df.columns.str.replace('α', 'alpha')   # Replace alpha symbol

# Replace special characters in data
for col in df.columns:
    if df[col].dtype == 'object':  # Only process string columns
        df[col] = df[col].str.replace('°', ' deg ') if pd.notna(df[col]).any() else df[col]
        df[col] = df[col].str.replace('₂', '2') if pd.notna(df[col]).any() else df[col]
        df[col] = df[col].str.replace('ꭒ', 'u') if pd.notna(df[col]).any() else df[col]
        df[col] = df[col].str.replace('α', 'alpha') if pd.notna(df[col]).any() else df[col]

# Save as CSV with tab separator
df.to_csv('vibrio.tsv', sep='\t', index=False, encoding='ascii', errors='replace')

# Also save as regular CSV
df.to_csv('vibrio.csv', index=False, encoding='ascii', errors='replace')

print("Conversion complete. Files created: vibrio.tsv and vibrio.csv with ASCII characters only") 