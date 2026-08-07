from pathlib import Path
import re

root = Path('d:/k/wink/teknik_bakis')
source_md = root / 'bistguncel.md'
stock_file = root / 'lib/services/bist_stocks.dart'
text = stock_file.read_text(encoding='utf-8')
start_marker = "const List<Map<String, String>> _baseBistStocks = ["
end_marker = "List<Map<String, String>> kBistStocks = List<Map<String, String>>.from(_baseBistStocks);"
start_idx = text.index(start_marker)
end_idx = text.index(end_marker)
pre = text[:start_idx]
post = text[end_idx:]
list_text = text[start_idx + len(start_marker):end_idx]
lines = [line.strip() for line in list_text.splitlines() if line.strip()]
entries = []
for line in lines:
    if line.startswith('{') and line.endswith('},'):
        match = re.search(r"'symbol'\s*:\s*'([^']+)'\s*,\s*'name'\s*:\s*'([^']+)'", line)
        if match:
            entries.append((match.group(1).strip().upper(), match.group(2).strip()))
    elif line.startswith('{') and line.endswith('}'):
        match = re.search(r"'symbol'\s*:\s*'([^']+)'\s*,\s*'name'\s*:\s*'([^']+)'", line)
        if match:
            entries.append((match.group(1).strip().upper(), match.group(2).strip()))

md_text = source_md.read_text(encoding='utf-8')
md_lines = [line.strip() for line in md_text.splitlines() if line.strip()]
md_symbols = []
seen_symbols = set()
for line in md_lines:
    if line.lower().startswith('menkul') or line.lower().startswith('fiyat') or line.startswith('---'):
        continue
    parts = re.split(r'\s{2,}|\t+', line)
    if not parts:
        continue
    sym = parts[0].strip().upper()
    if sym and re.match(r'^[A-Z0-9]+$', sym) and sym not in seen_symbols:
        md_symbols.append(sym)
        seen_symbols.add(sym)

existing_symbols = {symbol for symbol, _ in entries}
missing = sorted([sym for sym in md_symbols if sym not in existing_symbols])

combined = entries.copy()
for sym in missing:
    combined.append((sym, sym))
combined.sort(key=lambda item: item[0])

with stock_file.open('w', encoding='utf-8') as f:
    f.write(pre)
    f.write(start_marker)
    f.write('\n')
    for sym, name in combined:
        f.write("  {'symbol': '%s', 'name': '%s'},\n" % (sym, name))
    f.write('];\n\n')
    f.write(post)

print(f'Added {len(missing)} missing symbols to {stock_file}')
print('Missing sample:', missing[:50])
