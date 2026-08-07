from pathlib import Path
import re
root = Path('d:/k/wink/teknik_bakis')
stock_file = root / 'lib/services/bist_stocks.dart'
text = stock_file.read_text(encoding='utf-8')
start_marker = "const List<Map<String, String>> _baseBistStocks = ["
end_marker = "List<Map<String, String>> kBistStocks = List<Map<String, String>>.from(_baseBistStocks);"
start_idx = text.index(start_marker)
end_idx = text.index(end_marker)
pre = text[:start_idx + len(start_marker)]
post = text[end_idx:]
inner = text[start_idx + len(start_marker):end_idx]
entries = []
for line in inner.splitlines():
    stripped = line.strip()
    if not stripped:
        continue
    m = re.search(r"'symbol'\s*:\s*'([^']+)'\s*,\s*'name'\s*:\s*'([^']+)'", stripped)
    if m:
        entries.append((m.group(1).upper(), m.group(2)))
seen = set()
deduped = []
for sym, name in entries:
    if sym in seen:
        continue
    seen.add(sym)
    deduped.append((sym, name))
with stock_file.open('w', encoding='utf-8') as f:
    f.write(pre)
    f.write('\n')
    for sym, name in deduped:
        f.write(f"  {{'symbol': '{sym}', 'name': '{name}'}},\n")
    f.write('];\n\n')
    f.write(post)
print('rewrote', len(deduped), 'unique entries')
