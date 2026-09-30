import os
from sparrow_parse import SparrowParse
import json

# Initialize Sparrow Parse
sparrow = SparrowParse()

# Define the query structure for the consensus matrix
query = [
    {
        "species": "str",
        "tests": ["str"]
    }
]

# Process the PDF
result = sparrow.process_document(
    file_path=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "references", "noguerola2008.pdf"),
    query=json.dumps(query),
    page_numbers=[3],
    options={
        "backend": "mlx",
        "model": "mlx-community/Qwen2.5-VL-72B-Instruct-4bit",
        "tables_only": True
    }
)

# Print the extracted data
print(json.dumps(result, indent=2)) 