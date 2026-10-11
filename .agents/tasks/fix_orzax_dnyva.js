const fs = require('fs');
const https = require('https');

const configPath = process.env.USERPROFILE + '/.config/configstore/firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const accessToken = config.tokens.access_token;
const PROJECT_ID = 'teknik-bakis';

function httpsRequest(options, postData) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
        catch(e) { resolve({ status: res.statusCode, body: data }); }
      });
    });
    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

async function updateStatus(docId, newStatus) {
  const url = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/ipo_items/${docId}?updateMask.fieldPaths=status`;
  const body = JSON.stringify({ fields: { status: { stringValue: newStatus } } });
  
  return httpsRequest({
    hostname: 'firestore.googleapis.com',
    path: url,
    method: 'PATCH',
    headers: {
      'Authorization': 'Bearer ' + accessToken,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body)
    }
  }, body);
}

async function main() {
  const toFix = ['ORZAX', 'DNYVA', 'BEWEN'];
  
  for (const id of toFix) {
    const result = await updateStatus(id, 'trading');
    console.log(`${id}: HTTP ${result.status}`, result.status === 200 ? 'OK' : JSON.stringify(result.body).slice(0, 100));
  }
  
  console.log('Tamamlandı.');
}

main().catch(e => { console.error(e.message); process.exit(1); });
