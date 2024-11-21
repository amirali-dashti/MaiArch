import json

# Define the path to the JSON file
file_path = 'configs.json'

# Load JSON data from the file
with open(file_path, 'r') as file:
    data = json.load(file)

def saveConfig():
    """Save the modified data back to the JSON file."""
    with open(file_path, 'w') as file:
        json.dump(data, file, indent=4)

def updateConfig(name, value):
    """
    Update a specific field in the config. 
    Supports both top-level and nested fields.
    """
    keys = name.split(".")  # Allow 'dot notation' for nested keys
    d = data
    for key in keys[:-1]:
        d = d.get(key, {})
    d[keys[-1]] = value

    saveConfig()  # Save changes immediately
