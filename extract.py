import os
import re
import json

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
                    matches.add(m.group(1))
                for m in re.finditer(r'Text\(\s*"([^"\$]+)"\s*\)', content):
                    matches.add(m.group(1))

unique_strings = sorted(list(matches))
with open('strings_utf8.json', 'w', encoding='utf-8') as f:
    json.dump(unique_strings, f, indent=2, ensure_ascii=False)
