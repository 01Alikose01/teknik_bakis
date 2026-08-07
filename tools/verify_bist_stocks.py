from pathlib import Path
import re
root = Path('d:/k/wink/teknik_bakis')
app = root / 'lib/services/bist_stocks.dart'
text = app.read_text(encoding='utf-8')
entries = re.findall(r"\{'symbol'\s*:\s*'([A-Z0-9]+)'\s*,\s*'name'\s*:\s*'([^']+)'\s*\}", text)
syms = [s for s, _ in entries]
dups = sorted({s for s in syms if syms.count(s) > 1})
print('entry_count', len(entries))
print('unique_symbols', len(set(syms)))
print('dup_count', len(dups))
print('dups', dups[:50])
if dups:
    for d in dups:
        print(d, [i for i, s in enumerate(syms) if s == d])
