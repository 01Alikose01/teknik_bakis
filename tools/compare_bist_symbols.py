from pathlib import Path
import re

root = Path('d:/k/wink/teknik_bakis')
md = root / 'bistguncel.md'
app = root / 'lib/services/bist_stocks.dart'
text = md.read_text(encoding='utf-8')
lines = [line.strip() for line in text.splitlines() if line.strip()]
entries = []
seen = set()
for line in lines:
    if line.lower().startswith('menkul') or line.lower().startswith('fiyat') or line.startswith('---'):
        continue
    parts = re.split(r'\s{2,}|\t+', line)
    if not parts:
        continue
    sym = parts[0].strip().upper()
    if sym and re.match(r'^[A-Z0-9]+$', sym) and sym not in seen:
        entries.append(sym)
        seen.add(sym)

app_text = app.read_text(encoding='utf-8')
app_symbols = set(re.findall(r"'symbol'\s*:\s*'([A-Z0-9]+)'", app_text, flags=re.IGNORECASE))
missing = sorted(set(entries) - app_symbols)
extra = sorted(app_symbols - set(entries))
print('md_symbols', len(entries))
print('app_symbols', len(app_symbols))
print('missing_count', len(missing))
print('extra_count', len(extra))
print('missing_first50', missing[:50])
print('extra_first50', extra[:50])
print('missing_symbols:' + ','.join(missing))
print('extra_symbols:' + ','.join(extra))
