import os
import re
import json

with open('strings_utf8.json', 'r', encoding='utf-8') as f:
    unique_strings = json.load(f)

def to_camel_case(s):
    s = re.sub(r'[^a-zA-Z0-9\s]', '', s)
    words = s.split()
    if not words: return "empty"
    return words[0].lower() + ''.join(w.capitalize() for w in words[1:])

keys = {}
key_set = set()
for s in unique_strings:
    base_key = to_camel_case(s)
    key = base_key
    idx = 1
    while key in key_set or not key:
        key = f"{base_key if base_key else 'string'}{idx}"
        idx += 1
    key_set.add(key)
    keys[s] = key

l10n_path = r'C:\rustnotepad\sonarpad_mobile_starter\lib\l10n\app_localizations.dart'
with open(l10n_path, 'r', encoding='utf-8') as f:
    l10n_content = f.read()

last_brace = l10n_content.rfind('}')
if last_brace != -1:
    prefix = l10n_content[:last_brace]
    suffix = l10n_content[last_brace:]
    
    for s, key in keys.items():
        escaped_s = s.replace("'", "\\'")
        prefix += f"  String get {key} => _isEn ? '{escaped_s}' : (_isFr ? '{escaped_s}' : (_isEs ? '{escaped_s}' : '{escaped_s}'));\n"
    
    l10n_content = prefix + suffix

with open(l10n_path, 'w', encoding='utf-8') as f:
    f.write(l10n_content)

lib_dir = r'C:\rustnotepad\sonarpad_mobile_starter\lib'
for root, _, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart') and f != 'app_localizations.dart':
            path = os.path.join(root, f)
            with open(path, 'r', encoding='utf-8') as fp:
                content = fp.read()
            
            orig_content = content
            
            for s, key in keys.items():
                escaped_for_re_single = re.escape(s)
                escaped_for_re_double = re.escape(s)
                
                content = re.sub(r"Text\(\s*'" + escaped_for_re_single + r"'\s*\)", r"Text(AppLocalizations.of(context)." + key + r")", content)
                content = re.sub(r'Text\(\s*"' + escaped_for_re_double + r'"\s*\)', r"Text(AppLocalizations.of(context)." + key + r")", content)
            
            if content != orig_content:
                if 'app_localizations.dart' not in content:
                    rel_path = os.path.relpath(l10n_path, start=root)
                    rel_path = rel_path.replace(os.sep, '/')
                    import_stmt = f"import '{rel_path}';\n"
                    
                    last_import_idx = content.rfind('import ')
                    if last_import_idx != -1:
                        end_of_line = content.find('\n', last_import_idx)
                        content = content[:end_of_line+1] + import_stmt + content[end_of_line+1:]
                    else:
                        content = import_stmt + content
                        
                with open(path, 'w', encoding='utf-8') as fp:
                    fp.write(content)

print("Done")
