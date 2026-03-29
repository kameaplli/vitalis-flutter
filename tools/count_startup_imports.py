"""Count unique .dart files transitively imported from main.dart.

Metric for autoresearch: lower = fewer files loaded at startup = faster init.
Only counts local project files (lib/**/*.dart), not packages or dart: imports.
"""
import os
import re
import sys

def get_imports(filepath):
    imports = []
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            for line in f:
                m = re.match(r"import\s+'([^']+)'", line)
                if not m:
                    m = re.match(r'import\s+"([^"]+)"', line)
                if m:
                    imports.append(m.group(1))
    except Exception:
        pass
    return imports

def resolve_import(imp, current_dir):
    if imp.startswith('package:') or imp.startswith('dart:'):
        return None
    resolved = os.path.normpath(os.path.join(current_dir, imp))
    if os.path.exists(resolved):
        return resolved
    return None

def trace(start):
    visited = set()
    queue = [os.path.normpath(start)]
    while queue:
        f = queue.pop(0)
        if f in visited:
            continue
        visited.add(f)
        d = os.path.dirname(f)
        for imp in get_imports(f):
            resolved = resolve_import(imp, d)
            if resolved and resolved not in visited:
                queue.append(resolved)
    return visited

if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(__file__), '..', 'lib'))
    files = trace('main.dart')
    print(len(files))
