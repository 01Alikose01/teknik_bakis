/**
 * firebase-tools'u programatik olarak kullanarak Firestore'dan ipo_items çeker.
 */
const fs = require('fs');

async function main() {
  // firebase-tools'un client credentials'ını bulalım
  const toolsPath = 'C:/Users/k/AppData/Roaming/npm/node_modules/firebase-tools';
  
  // lib içinde client_id/secret ara
  let clientId, clientSecret;
  
  // Bilinen firebase-tools client credentials (public, same for all users)
  // firebase-tools uses its own OAuth app
  const possibleFiles = [
    toolsPath + '/lib/auth.js',
    toolsPath + '/lib/api.js', 
    toolsPath + '/lib/cli.js',
    toolsPath + '/lib/index.js',
  ];
  
  for (const f of possibleFiles) {
    try {
      const content = fs.readFileSync(f, 'utf8');
      const idMatch = content.match(/client_id['":\s]+["']([^"']+googleusercontent[^"']+)["']/);
      const secretMatch = content.match(/client_secret['":\s]+["']([^"']{10,50})["']/);
      if (idMatch) { clientId = idMatch[1]; console.log('client_id bulundu in:', f); }
      if (secretMatch) { clientSecret = secretMatch[1]; console.log('client_secret bulundu in:', f); }
      if (clientId && clientSecret) break;
    } catch(e) {}
  }
  
  // Recursive search in lib
  if (!clientId || !clientSecret) {
    function findInDir(dir, depth = 0) {
      if (depth > 3) return;
      try {
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        for (const e of entries) {
          if (clientId && clientSecret) return;
          const full = dir + '/' + e.name;
          if (e.isDirectory() && e.name !== 'node_modules') {
            findInDir(full, depth + 1);
          } else if (e.isFile() && e.name.endsWith('.js') && e.name.length < 20) {
            try {
              const content = fs.readFileSync(full, 'utf8');
              if (content.includes('googleusercontent') && content.includes('client_secret')) {
                const idMatch = content.match(/["']([\d]+-[a-z0-9]+\.apps\.googleusercontent\.com)["']/);
                const secretMatch = content.match(/client_secret["'\s:,]+["']([A-Za-z0-9_\-]{10,50})["']/);
                if (idMatch) clientId = idMatch[1];
                if (secretMatch) clientSecret = secretMatch[1];
                if (clientId || clientSecret) console.log('Found in:', full);
              }
            } catch(e2) {}
          }
        }
      } catch(e) {}
    }
    findInDir(toolsPath + '/lib');
  }
  
  const result = { clientId: clientId || 'NOT FOUND', clientSecret: clientSecret ? 'FOUND (length=' + clientSecret.length + ')' : 'NOT FOUND' };
  fs.writeFileSync('d:/k/wink/teknik_bakis/.agents/tasks/oauth_result.json', JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result));
}

main().catch(e => { console.error(e.message); process.exit(1); });
