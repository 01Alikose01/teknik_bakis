/**
 * Full Firestore query - get all fields from meta/kap and check collections.
 */
const fs = require('fs');
const https = require('https');
const OUTPUT = 'd:/k/wink/teknik_bakis/.agents/tasks/firestore_full_results.json';

const results = {
  timestamp: new Date().toISOString(),
  errors: []
};

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
      headers: {
        ...headers,
        ...(bodyStr ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(bodyStr) } : {})
      }
    };
    const req = https.request(opts, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(d) }); }
        catch(e) { resolve({ status: res.statusCode, body: d }); }
      });
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
  if (val.mapValue) {
    const obj = {};
    for (const [k, v] of Object.entries(val.mapValue.fields || {})) obj[k] = fromFirestoreValue(v);
    return obj;
  }
  if (val.arrayValue) return (val.arrayValue.values || []).map(fromFirestoreValue);
  return JSON.stringify(val);
}

function fromFirestoreDoc(doc) {
  if (!doc || !doc.fields) return {};
  const obj = {};
  for (const [k, v] of Object.entries(doc.fields)) obj[k] = fromFirestoreValue(v);
  return obj;
}

async function main() {
  // 1. Get FULL meta/kap document (all fields)
  try {
    const resp = await httpsReq('GET', 'firestore.googleapis.com', `${dbBase}/meta/kap`, authHeader);
    results.meta_kap_status = resp.status;
    if (resp.status === 200 && resp.body && resp.body.fields) {
      const data = fromFirestoreDoc(resp.body);
      results.meta_kap_all_fields = data;
      results.meta_kap_field_names = Object.keys(data);
    } else {
      results.meta_kap_error = JSON.stringify(resp.body).substring(0, 1000);
    }
  } catch(e) {
    results.errors.push('meta/kap: ' + e.message);
  }

  // 2. Check kap_sync_logs collection - try with different orderings  
  // Maybe it's ordered differently
  try {
    const resp = await httpsReq(
      'POST', 'firestore.googleapis.com', `${dbBase}:runQuery`, authHeader,
      {
        structuredQuery: {
          from: [{ collectionId: 'kap_sync_logs' }],
          limit: 5
        }
      }
    );
    results.kap_sync_logs_count_status = resp.status;
    results.kap_sync_logs_any = resp.body;
    
    if (Array.isArray(resp.body)) {
      results.kap_sync_logs_result_count = resp.body.length;
      // Count docs vs empty reads
      const withDocs = resp.body.filter(r => r.document);
      results.kap_sync_logs_docs_found = withDocs.length;
      
      if (withDocs.length > 0) {
        results.kap_sync_logs_sample = withDocs.map(r => {
          const data = fromFirestoreDoc(r.document);
          return {
            id: (r.document.name || '').split('/').pop(),
            ...data
          };
        });
      }
    }
  } catch(e) {
    results.errors.push('kap_sync_logs list: ' + e.message);
  }

  // 3. Check meta collection for other documents
  try {
    const resp = await httpsReq(
      'POST', 'firestore.googleapis.com', `${dbBase}:runQuery`, authHeader,
      {
        structuredQuery: {
          from: [{ collectionId: 'meta' }],
          limit: 10
        }
      }
    );
    results.meta_collection_status = resp.status;
    if (Array.isArray(resp.body)) {
      const withDocs = resp.body.filter(r => r.document);
      results.meta_collection_docs = withDocs.map(r => ({
        id: (r.document.name || '').split('/').pop(),
        fields: Object.keys(r.document.fields || {})
      }));
    }
  } catch(e) {
    results.errors.push('meta collection: ' + e.message);
  }

  // 4. List top-level collections
  try {
    const resp = await httpsReq(
      'POST', 'firestore.googleapis.com',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents:listCollectionIds`,
      authHeader, {}
    );
    results.collections_status = resp.status;
    results.collections = resp.body;
  } catch(e) {
    results.errors.push('list collections: ' + e.message);
  }

  fs.writeFileSync(OUTPUT, JSON.stringify(results, null, 2));
}

main().catch(e => {
  results.errors.push('fatal: ' + e.message);
  fs.writeFileSync(OUTPUT, JSON.stringify(results, null, 2));
});
