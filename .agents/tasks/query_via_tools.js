/**
 * Use firebase-tools firestore internals to query Firestore.
 */
const fs = require('fs');
const OUTPUT = 'd:/k/wink/teknik_bakis/.agents/tasks/firestore_results.json';
const results = { timestamp: new Date().toISOString(), errors: [], method: null };

process.env.GCLOUD_PROJECT = 'teknik-bakis';

const toolsBase = 'C:/Users/k/AppData/Roaming/npm/node_modules/firebase-tools';

// Try to use firebase-tools' built-in Firestore access via its API module
async function main() {
  try {
    // firebase-tools has internal apiv2 / api modules that handle auth
    const { Client } = require(toolsBase + '/lib/apiv2');
    results.method = 'firebase-tools apiv2 Client';
    
    const client = new Client({
      urlPrefix: 'https://firestore.googleapis.com',
      auth: true
    });

    // Query kap_sync_logs - runQuery
    const project = 'teknik-bakis';
    const dbPath = `projects/${project}/databases/(default)`;
    
    const queryBody = {
      structuredQuery: {
        from: [{ collectionId: 'kap_sync_logs' }],
        orderBy: [{ field: { fieldPath: 'createdAt' }, direction: 'DESCENDING' }],
        limit: 1
      }
    };

    try {
      const logsResp = await client.request({
        method: 'POST',
        path: `/v1/${dbPath}/documents:runQuery`,
        body: queryBody,
        responseType: 'json'
      });
      
      results.kap_sync_logs_raw = logsResp.body;
      
      if (Array.isArray(logsResp.body) && logsResp.body[0] && logsResp.body[0].document) {
        const doc = logsResp.body[0].document;
        const data = fromFirestoreDoc(doc);
        const docId = (doc.name || '').split('/').pop();
        results.kap_sync_logs_latest = {
          id: docId,
          status: data.status || null,
          error_message: data.error_message || null,
          trigger: data.trigger || null,
          createdAt: data.createdAt || null,
          details: data.details || null,
          all_fields: Object.keys(data)
        };
      } else {
        results.kap_sync_logs_latest = { found: false };
      }
    } catch(e) {
      results.errors.push('kap_sync_logs query error: ' + e.message);
    }

    try {
      const metaResp = await client.request({
        method: 'GET',
        path: `/v1/${dbPath}/documents/meta/kap`,
        responseType: 'json'
      });
      
      if (metaResp.body && metaResp.body.fields) {
        const data = fromFirestoreDoc(metaResp.body);
        results.meta_kap = {
          lastSyncStatus: data.lastSyncStatus || null,
          lastSyncAt: data.lastSyncAt || null,
          lastError: data.lastError || null,
          all_fields: Object.keys(data)
        };
      } else {
        results.meta_kap = { error: 'unexpected response', body: metaResp.body };
      }
    } catch(e) {
      results.errors.push('meta/kap query error: ' + e.message);
    }

  } catch(e) {
    results.errors.push('apiv2 setup error: ' + e.message + '\n' + e.stack);
    
    // Fallback: try direct REST with existing token from configstore
    results.method = 'direct REST with stored access_token';
    try {
      await tryDirectRest();
    } catch(e2) {
      results.errors.push('direct REST fallback error: ' + e2.message);
    }
  }

  fs.writeFileSync(OUTPUT, JSON.stringify(results, null, 2));
}

function fromFirestoreValue(val) {
  if (!val) return null;
  if (val.stringValue !== undefined) return val.stringValue;
  if (val.integerValue !== undefined) return parseInt(val.integerValue);
  if (val.doubleValue !== undefined) return parseFloat(val.doubleValue);
  if (val.booleanValue !== undefined) return val.booleanValue;
  if (val.timestampValue !== undefined) return val.timestampValue;
  if (val.nullValue !== undefined) return null;
  if (val.mapValue !== undefined) {
    const obj = {};
    for (const [k, v] of Object.entries(val.mapValue.fields || {})) {
      obj[k] = fromFirestoreValue(v);
    }
    return obj;
  }
  if (val.arrayValue !== undefined) {
    return (val.arrayValue.values || []).map(fromFirestoreValue);
  }
  return JSON.stringify(val);
}

function fromFirestoreDoc(doc) {
  if (!doc || !doc.fields) return {};
  const obj = {};
  for (const [k, v] of Object.entries(doc.fields)) {
    obj[k] = fromFirestoreValue(v);
  }
  return obj;
}

async function tryDirectRest() {
  const https = require('https');
  // Try to get the access_token directly from firebase-tools auth module
  const getAccessToken = require(toolsBase + '/lib/auth').getAccessToken;
  const token = await getAccessToken(null, []);
  results.got_token_via_auth = true;
  
  // Use it to query
  const PROJECT_ID = 'teknik-bakis';
  
  function httpsPost(path, body, token) {
    return new Promise((resolve, reject) => {
      const bodyStr = JSON.stringify(body);
      const opts = {
        hostname: 'firestore.googleapis.com',
        port: 443,
        path,
        method: 'POST',
        headers: {
          'Authorization': 'Bearer ' + token,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(bodyStr)
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
      req.write(bodyStr);
      req.end();
    });
  }

  function httpsGet(path, token) {
    return new Promise((resolve, reject) => {
      const opts = {
        hostname: 'firestore.googleapis.com',
        port: 443,
        path,
        method: 'GET',
        headers: { 'Authorization': 'Bearer ' + token }
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
      req.end();
    });
  }

  const logsResp = await httpsPost(
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery`,
    {
      structuredQuery: {
        from: [{ collectionId: 'kap_sync_logs' }],
        orderBy: [{ field: { fieldPath: 'createdAt' }, direction: 'DESCENDING' }],
        limit: 1
      }
    },
    token.access_token
  );

  results.kap_sync_logs_rest_status = logsResp.status;
  if (logsResp.status === 200 && Array.isArray(logsResp.body) && logsResp.body[0] && logsResp.body[0].document) {
    const doc = logsResp.body[0].document;
    const data = fromFirestoreDoc(doc);
    results.kap_sync_logs_latest = {
      id: (doc.name || '').split('/').pop(),
      status: data.status,
      error_message: data.error_message,
      trigger: data.trigger,
      createdAt: data.createdAt,
      details: data.details,
      all_fields: Object.keys(data)
    };
  } else {
    results.kap_sync_logs_latest = { error: 'status ' + logsResp.status, body: logsResp.body };
  }

  const metaResp = await httpsGet(
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/meta/kap`,
    token.access_token
  );

  results.meta_kap_rest_status = metaResp.status;
  if (metaResp.status === 200 && metaResp.body && metaResp.body.fields) {
    const data = fromFirestoreDoc(metaResp.body);
    results.meta_kap = {
      lastSyncStatus: data.lastSyncStatus,
      lastSyncAt: data.lastSyncAt,
      lastError: data.lastError,
      all_fields: Object.keys(data)
    };
  } else {
    results.meta_kap = { error: 'status ' + metaResp.status, body: metaResp.body };
  }
}

main().catch(e => {
  results.errors.push('Fatal: ' + e.message);
  fs.writeFileSync(OUTPUT, JSON.stringify(results, null, 2));
});
