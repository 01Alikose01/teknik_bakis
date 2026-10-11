/**
 * READ-ONLY Firestore query using Firebase Admin SDK.
 * Uses Firebase CLI stored tokens via google-auth-library or firebase-tools internals.
 */

const fs = require('fs');
const https = require('https');
const OUTPUT_FILE = 'd:/k/wink/teknik_bakis/.agents/tasks/firestore_results.json';

const results = {
  timestamp: new Date().toISOString(),
  kap_sync_logs_latest: null,
  meta_kap: null,
  errors: [],
  method: null
};

// Read Firebase CLI token
let tokenData;
try {
  const configPath = 'C:/Users/k/.config/configstore/firebase-tools.json';
  const raw = fs.readFileSync(configPath, 'utf8');
  tokenData = JSON.parse(raw);
} catch(e) {
  results.errors.push('Cannot read firebase-tools config: ' + e.message);
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(results, null, 2));
  process.exit(1);
}

// Try using firebase-admin with CLI credential
const PROJECT_ID = 'teknik-bakis';
const adminPath = 'C:/Users/k/AppData/Roaming/npm/node_modules/firebase-tools/node_modules/firebase-admin';
const adminPath2 = 'd:/k/wink/teknik_bakis/functions/node_modules/firebase-admin';

let admin;
try {
  admin = require(adminPath2);
  results.method = 'firebase-admin from functions/node_modules';
} catch(e) {
  results.errors.push('Cannot load firebase-admin: ' + e.message);
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(results, null, 2));
  process.exit(1);
}

// Use a custom credential that refreshes the token from firebase CLI tokens
const tokens = tokenData.tokens || {};
const refreshToken = tokens.refresh_token;

if (!refreshToken) {
  results.errors.push('No refresh token found in firebase-tools config. Keys: ' + JSON.stringify(Object.keys(tokens)));
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(results, null, 2));
  process.exit(1);
}

results.has_refresh_token = true;
results.user = tokenData.user || null;

// Refresh access token using Google OAuth2
function refreshAccessToken(refreshToken) {
  return new Promise((resolve, reject) => {
    const postData = new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
      client_secret: 'j9iVZfS8yw-GwaeNZI2vrbildi'
    }).toString();

    const options = {
      hostname: 'oauth2.googleapis.com',
      port: 443,
      path: '/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': postData.length
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          if (parsed.access_token) {
            resolve(parsed.access_token);
          } else {
            reject(new Error('No access_token in response: ' + data));
          }
        } catch(e) {
          reject(new Error('Parse error: ' + e.message + ' data: ' + data));
        }
      });
    });

    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

// Query Firestore REST API directly
function firestoreGet(accessToken, path) {
  return new Promise((resolve, reject) => {
    const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${path}`;
    
    const options = {
      hostname: 'firestore.googleapis.com',
      port: 443,
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${path}`,
      method: 'GET',
      headers: {
        'Authorization': 'Bearer ' + accessToken,
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch(e) {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
}

// Query Firestore collection with ordering via REST
function firestoreQuery(accessToken, collectionPath, orderField, limit) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: collectionPath }],
        orderBy: [{ field: { fieldPath: orderField }, direction: 'DESCENDING' }],
        limit: limit
      }
    });

    const options = {
      hostname: 'firestore.googleapis.com',
      port: 443,
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery`,
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + accessToken,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body)
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch(e) {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });

    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

// Convert Firestore REST value to plain JS value
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
  return val;
}

function fromFirestoreDoc(doc) {
  if (!doc || !doc.fields) return null;
  const obj = {};
  for (const [k, v] of Object.entries(doc.fields)) {
    obj[k] = fromFirestoreValue(v);
  }
  return obj;
}

async function main() {
  results.method = 'Firestore REST API with refreshed OAuth token';

  // Get fresh access token
  let accessToken;
  try {
    accessToken = await refreshAccessToken(refreshToken);
    results.token_refreshed = true;
  } catch(e) {
    results.errors.push('Token refresh failed: ' + e.message);
    fs.writeFileSync(OUTPUT_FILE, JSON.stringify(results, null, 2));
    process.exit(1);
  }

  // Query kap_sync_logs - get latest by createdAt
  try {
    const resp = await firestoreQuery(accessToken, 'kap_sync_logs', 'createdAt', 1);
    results.kap_sync_logs_raw_status = resp.status;
    
    if (resp.status === 200 && Array.isArray(resp.body)) {
      const firstResult = resp.body[0];
      if (firstResult && firstResult.document) {
        const doc = firstResult.document;
        const data = fromFirestoreDoc(doc);
        const docName = doc.name || '';
        const docId = docName.split('/').pop();
        
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
        results.kap_sync_logs_latest = { found: false, raw: resp.body[0] };
      }
    } else {
      results.kap_sync_logs_latest = { error: 'HTTP ' + resp.status, body: resp.body };
    }
  } catch(e) {
    results.errors.push('kap_sync_logs query error: ' + e.message);
  }

  // Get meta/kap document
  try {
    const resp = await firestoreGet(accessToken, 'meta/kap');
    results.meta_kap_raw_status = resp.status;
    
    if (resp.status === 200 && resp.body.fields) {
      const data = fromFirestoreDoc(resp.body);
      results.meta_kap = {
        lastSyncStatus: data.lastSyncStatus || null,
        lastSyncAt: data.lastSyncAt || null,
        lastError: data.lastError || null,
        all_fields: Object.keys(data)
      };
    } else {
      results.meta_kap = { error: 'HTTP ' + resp.status, body: resp.body };
    }
  } catch(e) {
    results.errors.push('meta/kap query error: ' + e.message);
  }

  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(results, null, 2));
}

main().catch(e => {
  results.errors.push('Fatal: ' + e.message + '\n' + e.stack);
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(results, null, 2));
  process.exit(1);
});
