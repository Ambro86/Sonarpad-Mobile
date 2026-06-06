import subprocess
import re

def main():
    result = subprocess.run(['git', 'show', 'HEAD:lib/screens/bdciechi_dashboard_screen.dart'], capture_output=True, text=True, encoding='utf-8')
    content = result.stdout
    
    # We want to replace the _normalize function
    old_func = """  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll('à', 'a')
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ù', 'u');
  }"""
    
    new_func = """  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll('à', 'a')
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ù', 'u')
        .replaceAll(',', ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
  }"""
    
    new_content = content.replace(old_func, new_func)
    
    with open('lib/screens/bdciechi_dashboard_screen.dart', 'w', encoding='utf-8') as f:
        f.write(new_content)
        
    print("Fixed!")

if __name__ == '__main__':
    main()
