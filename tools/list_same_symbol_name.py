from pathlib import Path
import re

path = Path('lib/services/bist_stocks.dart')
text = path.read_text(encoding='utf-8')
pattern = re.compile(r"\{\s*'symbol':\s*'([^']+)',\s*'name':\s*'([^']+)'\s*\}")
entries = pattern.findall(text)
results = [entry for entry in entries if entry[0] == entry[1] and entry[0].upper() == entry[0]]
for symbol, name in results:
    print(f"{{'symbol': '{symbol}', 'name': '{name}'}}")
print('count:', len(results))
