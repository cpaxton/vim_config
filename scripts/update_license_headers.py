# Created by ChatGPT
# chat.openai.com

import os

license_header = """
# This file is licensed under the XYZ License.
# (c) Your Name or Organization
"""

directory = '/path/to/your/directory'

# Iterate over all files in the directory
for root, dirs, files in os.walk(directory):
    for file_name in files:
        if file_name.endswith('.py'):
            file_path = os.path.join(root, file_name)
            
            # Read the existing content of the file
            with open(file_path, 'r') as file:
                content = file.read()
            
            # Add the license header if it doesn't already exist
            if not content.startswith('# This file is licensed under the XYZ License.'):
                new_content = license_header + content
                
                # Write the modified content back to the file
                with open(file_path, 'w') as file:
                    file.write(new_content)
                    
                print(f"License header added to: {file_path}")
