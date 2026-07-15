import os
import re

example_dir = '/Users/sebastiand/WebstormProjects/zenify/example'

# 1. Remove initController from all files
def remove_init_controller(content):
    # Matches `@override\n  SomethingController Function()? get initController => ...;`
    # Also handles multiline if it ends with `;`
    pattern = r'@override\s+[A-Za-z0-9_]+ Function\(\)\?\s*get initController\s*=>[\s\S]*?;'
    return re.sub(pattern, '', content)

for root, dirs, files in os.walk(example_dir):
    for f in files:
        if f.endswith('.dart'):
            path = os.path.join(root, f)
            with open(path, 'r') as file:
                content = file.read()
            
            new_content = remove_init_controller(content)
            if new_content != content:
                with open(path, 'w') as file:
                    file.write(new_content)
                print(f"Removed initController from {path}")

