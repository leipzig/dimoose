import os
import requests
import json

# API endpoint
url = 'http://127.0.0.1:8000/api/v1/sparrow-llm/inference'

# Prepare the form data
files = {
    'file': ('noguerola2008.pdf', open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "references", "noguerola2008.pdf"), 'rb'), 'application/pdf')
}

data = {
    'query': json.dumps([{"species": "str", "test_results": "str"}]),
    'pipeline': 'sparrow-parse',
    'options': 'mlx,mlx-community/Qwen2.5-VL-72B-Instruct-4bit,tables_only',
    'page_type': '',
    'crop_size': '',
    'debug_dir': '',
    'debug': 'true',
    'sparrow_key': ''
}

# Make the request
response = requests.post(url, files=files, data=data)

# Print the response
print(json.dumps(response.json(), indent=2)) 