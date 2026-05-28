import os
import re

lib_dir = r'C:\rustnotepad\sonarpad_mobile_starter\lib'
matches = set()
for root, _, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart') and f != 'app_localizations.dart':
            path = os.path.join(root, f)
            with open(path, 'r', encoding='utf-8') as fp:
                content = fp.read()
                # Find simple Text('...') or Text("...") without interpolation
                for m in re.finditer(r"Text\(\s*'([^'\$]+)'\s*\)", content):
                    matches.add((f, m.group(1)))
                for m in re.finditer(r'Text\(\s*"([^"\$]+)"\s*\)', content):
                    matches.add((f, m.group(1)))

files_with_strings = {}
for f, s in matches:
    if f not in files_with_strings:
        files_with_strings[f] = []
    files_with_strings[f].append(s)

for f in sorted(files_with_strings.keys()):
    print(f"{f}: {len(files_with_strings[f])} strings")
