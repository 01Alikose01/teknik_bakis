const fs = require('fs');
const path = require('path');

const toolsBase = 'C:/Users/k/AppData/Roaming/npm/node_modules/firebase-tools';

function findFiles(dir, pattern, results = []) {
  try {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const e of entries) {
      const full = path.join(dir, e.name);
      if (e.isDirectory() && !e.name.startsWith('.') && e.name !== 'node_modules') {
        findFiles(full, pattern, results);
      } else if (e.isFile() && (e.name.endsWith('.js') || e.name.endsWith('.ts'))) {
        try {
          const content = fs.readFileSync(full, 'utf8');
          if (content.includes('client_secret') || content.includes('clientSecret')) {
            results.push(full);
          }
        } catch(e2) {}
      }
    }
  } catch(e) {}
  return results;
}

const found = findFiles(toolsBase, 'client_secret');
fs.writeFileSync('d:/k/wink/teknik_bakis/.agents/tasks/oauth_files.json', JSON.stringify(found.slice(0, 20), null, 2));
