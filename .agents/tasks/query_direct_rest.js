/**
 * Direct Firestore REST API query using stored access_token from Firebase CLI.
 */
const fs = require('fs');
const https = require('https');
const OUTPUT = 'd:/k/wink/teknik_bakis/.agents/tasks/firestore_results.json';

const results = {
  timestamp: new Date().toISOString(),
  kap_sync_logs_latest: null,
  meta_kap: null,
  errors: [],
  method: 'Firestore REST API with stored access_token'
};

// Read stored access token
const configPath = 'C:/Users/k/.config/configstore/firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const ACCESS_TOKEN = config.tokens.access_token;
const REFRESH_TOKEN = config.tokens.refresh_token;
const PROJECT_ID = 'teknik-bakis';

function httpsReq(method, hostname, path, headers, body) {
  return new Promise((resolve, reject) => {
    const bodyStr = body ? JSON.stringify(body) : null;
    const opts = {
      hostname,
      port: 443,
      path,
      method,
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

// Try to refresh token using firebase-tools' own OAuth client
// Read client credentials from firebase-tools source
function getClientCreds() {
  try {
    // Try to find client credentials in firebase-tools source
    const toolsBase = 'C:/Users/k/AppData/Roaming/npm/node_modules/firebase-tools';
    // Check lib/auth.js or similar
    const authFile = toolsBase + '/lib/auth.js';
    if (fs.existsSync(authFile)) {
      const content = fs.readFileSync(authFile, 'utf8');
      // Look for client_id and client_secret patterns
      const idMatch = content.match(/client_id['":\s]+['"]([^'"]+)['"]/);
      const secretMatch = content.match(/client_secret['":\s]+['"]([^'"]+)['"]/);
      if (idMatch && secretMatch) {
        return { client_id: idMatch[1], client_secret: secretMatch[1] };
      }
    }
  } catch(e) {}
  return null;
}

async function refreshToken() {
  const creds = getClientCreds();
  if (!creds) {
    // Use the google-auth-library which firebase-tools uses
    const { GoogleAuth } = require('C:/Users/k/AppData/Roaming/npm/node_modules/firebase-tools/node_modules/google-auth-library');
    // can't easily use without proper setup
    throw new Error('Cannot find client credentials');
  }
  
  const resp = await httpsReq('POST', 'oauth2.googleapis.com', '/token', {}, null);
  // Actually use URLSearchParams
  return new Promise((resolve, reject) => {
    const postData = `grant_type=refresh_token&refresh_token=${encodeURIComponent(REFRESH_TOKEN)}&client_id=${encodeURIComponent(creds.client_id)}&client_secret=${encodeURIComponent(creds.client_secret)}`;
    const opts = {
      hostname: 'oauth2.googleapis.com',
      port: 443,
      path: '/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(postData)
      }
    };
    const req = https.request(opts, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(d);
          if (parsed.access_token) resolve(parsed.access_token);
          else reject(new Error('No access_token: ' + d));
        } catch(e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

async function queryWithToken(token) {
  const dbBase = `/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
  const authHeader = { 'Authorization': 'Bearer ' + token };
  
  // Query kap_sync_logs
  try {
    const resp = await httpsReq(
      'POST',
      'firestore.googleapis.com',
      `${dbBase}:runQuery`,
      authHeader,
      {
        structuredQuery: {
          from: [{ collectionId: 'kap_sync_logs' }],
          orderBy: [{ field: { fieldPath: 'createdAt' }, direction: 'DESCENDING' }],
          limit: 1
        }
      }
    );
    
    results.kap_sync_logs_http_status = resp.status;
    
    if (resp.status === 200 && Array.isArray(resp.body) && resp.body[0] && resp.body[0].document) {
      const doc = resp.body[0].document;
      const data = fromFirestoreDoc(doc);
      results.kap_sync_logs_latest = {
        id: (doc.name || '').split('/').pop(),
        status: data.status !== undefined ? data.status : null,
        error_message: data.error_message !== undefined ? data.error_message : null,
        trigger: data.trigger !== undefined ? data.trigger : null,
        createdAt: data.createdAt !== undefined ? data.createdAt : null,
        details: data.details !== undefined ? data.details : null,
        all_fields: Object.keys(data)
      };
    } else if (resp.status === 200 && Array.isArray(resp.body) && resp.body[0] && !resp.body[0].document) {
      // Empty result set
      results.kap_sync_logs_latest = { found: false, message: 'Collection is empty', raw: resp.body[0] };
    } else {
      results.kap_sync_logs_latest = { error: `HTTP ${resp.status}`, body_preview: JSON.stringify(resp.body).substring(0, 500) };
    }
  } catch(e) {
    results.errors.push('kap_sync_logs error: ' + e.message);
  }
  
  // Get meta/kap
  try {
    const resp = await httpsReq(
      'GET',
      'firestore.googleapis.com',
      `${dbBase}/meta/kap`,
      authHeader
    );
    
    results.meta_kap_http_status = resp.status;
    
    if (resp.status === 200 && resp.body && resp.body.fields) {
      const data = fromFirestoreDoc(resp.body);
      results.meta_kap = {
        lastSyncStatus: data.lastSyncStatus !== undefined ? data.lastSyncStatus : null,
        lastSyncAt: data.lastSyncAt !== undefined ? data.lastSyncAt : null,
        lastError: data.lastError !== undefined ? data.lastError : null,
        all_fields: Object.keys(data)
      };
    } else {
      results.meta_kap = { error: `HTTP ${resp.status}`, body_preview: JSON.stringify(resp.body).substring(0, 500) };
    }
  } catch(e) {
    results.errors.push('meta/kap error: ' + e.message);
  }
}

async function main() {
  // First try with stored access_token
  try {
    await queryWithToken(ACCESS_TOKEN);
    
    // Check if we got auth errors
    const authError = (results.kap_sync_logs_latest && results.kap_sync_logs_latest.error && 
      results.kap_sync_logs_http_status === 401) ||
      (results.meta_kap && results.meta_kap.error && results.meta_kap_http_status === 401);
    
    if (authError) {
      results.errors.push('Access token expired, trying to get fresh token via google-auth-library...');
      // Try with google-auth-library using the refresh token
      const { OAuth2Client } = require('C:/Users/k/AppData/Roaming/npm/node_modules/firebase-tools/node_modules/google-auth-library');
      
      // Look for client credentials
      const toolsBase = 'C:/Users/k/AppData/Roaming/npm/node_modules/firebase-tools';
      let clientId, clientSecret;
      
      // Try to extract from firebase-tools source
      const files = ['lib/auth.js', 'lib/commands/login.js'];
      for (const f of files) {
        try {
          const content = fs.readFileSync(toolsBase + '/' + f, 'utf8');
          if (content.includes('client_id') || content.includes('clientId')) {
            results.auth_file_found = f;
            // Extract a snippet for inspection
            const idx = content.indexOf('client_id');
            if (idx > 0) results.auth_snippet = content.substring(Math.max(0, idx-20), idx+100);
            break;
          }
        } catch(e2) {}
      }
    }
  } catch(e) {
    results.errors.push('main error: ' + e.message);
  }
  
  fs.writeFileSync(OUTPUT, JSON.stringify(results, null, 2));
}

main().catch(e => {
  results.errors.push('fatal: ' + e.message);
  fs.writeFileSync(OUTPUT, JSON.stringify(results, null, 2));
});
