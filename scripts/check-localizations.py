#!/usr/bin/env python3
"""Check that translation catalogs have matching keys and format placeholders."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1] / 'Sources' / 'Spacer'
pattern = re.compile(r'^\s*("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*");\s*$', re.M)

def read(path):
    lines = pattern.findall(path.read_text())
    data = {json.loads(k): json.loads(v) for k, v in lines}
    assert len(data) == len(lines), f'Duplicate keys in {path}'
    assert len(lines) == len(path.read_text().splitlines()), f'Unparsed lines in {path}'
    return data

english = read(root / 'Resources/en.lproj/Localizable.strings')
for path in (root / 'Resources').glob('*.lproj/Localizable.strings'):
    data = read(path)
    assert data.keys() == english.keys(), f'Key mismatch: {path}'
    for key, value in data.items():
        assert re.findall(r'%(?:@|[diuf])', value) == re.findall(r'%(?:@|[diuf])', english[key]), f'Placeholder mismatch: {path}: {key}'
    print(f'PASS: {path.parent.name}: {len(data)} keys, matching placeholders')
for path in root.glob('*.swift'):
    for match in re.finditer(r'\bT\(("(?:[^"\\]|\\.)*")', path.read_text()):
        key = json.loads(match.group(1))
        assert key in english, f'Missing key: {path.name}: {key}'
print('PASS: literal UI translation keys are present')
