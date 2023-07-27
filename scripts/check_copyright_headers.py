# Created by ChatGPT
# chat.openai.com

import os
import re

def has_copyright_header(file_path):
    with open(file_path, 'r') as file:
        content = file.read()

        # Define a regular expression pattern to match common copyright headers
        # copyright_pattern = r"(?i)\b(?:Copyright|©)\b[\s\w-]+(?:\d{4})"
        copyright_pattern = "Copyright"

        return re.search(copyright_pattern, content) is not None

def find_files_without_copyright(directory):
    for root, _, files in os.walk(directory):
            for file_name in files:
                    file_path = os.path.join(root, file_name)
                    if file_path.endswith('.py'):  # Only check Python files
                            if not has_copyright_header(file_path):
                                print(f"File without copyright header: {file_path}")

if __name__ == "__main__":
    directory_to_check = "."
    find_files_without_copyright(directory_to_check)
