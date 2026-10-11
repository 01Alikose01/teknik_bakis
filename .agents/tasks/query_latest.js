/**
 * Get the LATEST kap_sync_logs entry by finished_at (since createdAt doesn't exist on docs).
 */
const fs = require('fs');
const https = require('https');
const OUTPUT = 'd:/k/wink/teknik_bakis/.agents/tasks/firestore_latest.json';

const results = { timestamp: new Date().toISOString(), errors: [] };
const configPath = 'C:/Users/k/.config/configstore/firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const ACCESS_TOKEN = config.tokens.access_token;
const PROJECT_ID = 'teknik-bakis';
const dbBase = `/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const authHeader = { 'Authorization': 'Bearer ' + ACCESS_TOKEN };

function httpsReq(method, hostname, path, headers, body) {
  return new Promise((resolve, reject) => {
    const bodyStr = body ? JSON.stringify(body) : null;
    const opts = {
      hostname, port: 443, path, method,
      headers: { ...headers, ...(bodyStr ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(bodyStr) } : {}) }
    };
    const req = https.request(opts, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => { try { resolve({ status: res.statusCode, body: JSON.parse(d) }); } catch(e) { resolve({ status: res.statusCode, body: d }); } });
    });
    req.on('error', reject);
    if (bodyStr) req.write(bodyStr);
    req.end();
  });
}

function fromFirestoreValue(val) {
  if (!val) return null;
  if (val.stringValue !== undefined) return val.stringValue;
  if (val.integerValue !== undefined) return parseInt(val.integerValue);
  if (val.doubleValue !== undefined) return parseFloat(val.doubleValue);
  if (val.booleanValue !== undefined) return val.booleanValue;
  if (val.timestampValue !== undefined) return val.timestampValue;
  if (val.nullValue !== undefined) return null;
  if (val.mapValue) { const o = {}; for (const [k,v] of Object.entries(val.mapValue.fields || {})) o[k] = fromFirestoreValue(v); return o; }
  if (val.arrayValue) return (val.arrayValue.values || []).map(fromFirestoreValue);
  return JSON.stringify(val);
}
function fromFirestoreDoc(doc) {
  if (!doc || !doc.fields) return {};
  const o = {};
  for (const [k, v] of Object.entries(doc.fields)) o[k] = fromFirestoreValue(v);
  return o;
}

async function main() {
  // Try ordering by finished_at descending (most recent completion)
  const resp = await httpsReq('POST', 'firestore.googleapis.com', `${dbBase}:runQuery`, authHeader, {
    structuredQuery: {
      from: [{ collectionId: 'kap_sync_logs' }],
      orderBy: [{ field: { fieldPath: 'finished_at' }, direction: 'DESCENDING' }],
      limit: 3
    }
  });
  
  results.status = resp.status;
  if (Array.isArray(resp.body)) {
    results.latest_docs = resp.body
      .filter(r => r.document)
      .map(r => {
        const data = fromFirestoreDoc(r.document);
        return {
          id: (r.document.name || '').split('/').pop(),
          createTime: r.document.createTime,
          updateTime: r.document.updateTime,
          ...data
        };
      });
  }
  
  // Also try ordering by started_at
  const resp2 = await httpsReq('POST', 'firestore.googleapis.com', `${dbBase}:runQuery`, authHeader, {
    structuredQuery: {
      from: [{ collectionId: 'kap_sync_logs' }],
      orderBy: [{ field: { fieldPath: 'started_at' }, direction: 'DESCENDING' }],
      limit: 1
    }
  });
  
  results.status2 = resp2.status;
  if (Array.isArray(resp2.body) && resp2.body[0] && resp2.body[0].document) {
    const data = fromFirestoreDoc(resp2.body[0].document);
    results.latest_by_started_at = {
      id: (resp2.body[0].document.name || '').split('/').pop(),
      createTime: resp2.body[0].document.createTime,
      ...data
    };
  }

  fs.writeFileSync(OUTPUT, JSON.stringify(results, null, 2));
}

main().catch(e => {
  results.errors.push('fatal: ' + e.message);
  fs.writeFileSync(OUTPUT, JSON.stringify(results, null, 2));
});
