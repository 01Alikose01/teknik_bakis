/**
 * READ-ONLY Firestore query script.
 * Uses Firebase Admin SDK with Application Default Credentials or Firebase CLI token.
 * Writes results to a JSON output file.
 */

const fs = require('fs');
const path = require('path');
const OUTPUT_FILE = 'd:/k/wink/teknik_bakis/.agents/tasks/firestore_results.json';

const results = {
  timestamp: new Date().toISOString(),
  firebaseConfigFound: false,
  authMethod: null,
  kap_sync_logs_latest: null,
  meta_kap: null,
  errors: []
};

// Check Firebase CLI config locations for auth tokens
const configStorePaths = [
  path.join(process.env.APPDATA || '', 'gcloud', 'configstore', 'firebase-tools.json'),
  path.join(process.env.USERPROFILE || '', '.config', 'configstore', 'firebase-tools.json'),
];

let firebaseToken = null;

for (const p of configStorePaths) {
  try {
    if (fs.existsSync(p)) {
      const data = JSON.parse(fs.readFileSync(p, 'utf8'));
      results.firebaseConfigFound = true;
      results.authMethod = 'firebase-cli-token';
      results.firebaseConfigPath = p;
      results.configKeys = Object.keys(data);
      if (data.tokens) {
        firebaseToken = data.tokens.refresh_token || data.tokens.access_token || null;
        results.hasRefreshToken = !!data.tokens.refresh_token;
        results.hasAccessToken = !!data.tokens.access_token;
      }
      break;
    }
  } catch (e) {
    results.errors.push('Config read error: ' + e.message);
  }
}

// Check for service account files in workspace
const serviceAccountPaths = [
  'd:/k/wink/teknik_bakis/functions/service-account.json',
  'd:/k/wink/teknik_bakis/service-account.json',
  'd:/k/wink/teknik_bakis/teknik-bakis-firebase-adminsdk.json',
];

let serviceAccountPath = null;
for (const p of serviceAccountPaths) {
  if (fs.existsSync(p)) {
    serviceAccountPath = p;
    results.serviceAccountFound = p;
    break;
  }
}

// Try to initialize Firebase Admin SDK
const adminPath = 'd:/k/wink/teknik_bakis/functions/node_modules/firebase-admin';
try {
  const admin = require(adminPath);

  let initConfig = { projectId: 'teknik-bakis' };

  if (serviceAccountPath) {
    const sa = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
    initConfig.credential = admin.credential.cert(sa);
    results.authMethod = 'service-account';
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    initConfig.credential = admin.credential.applicationDefault();
    results.authMethod = 'GOOGLE_APPLICATION_CREDENTIALS env';
  } else {
    // Try Application Default Credentials
    initConfig.credential = admin.credential.applicationDefault();
    results.authMethod = 'application-default-credentials';
  }

  admin.initializeApp(initConfig);
  const db = admin.firestore();

  async function queryData() {
    try {
      // 1. Get latest kap_sync_logs document
      const logsSnap = await db.collection('kap_sync_logs')
        .orderBy('createdAt', 'desc')
        .limit(1)
        .get();

      if (!logsSnap.empty) {
        const doc = logsSnap.docs[0];
        const data = doc.data();
        results.kap_sync_logs_latest = {
          id: doc.id,
          status: data.status || null,
          error_message: data.error_message || null,
          trigger: data.trigger || null,
          createdAt: data.createdAt ? (data.createdAt.toDate ? data.createdAt.toDate().toISOString() : String(data.createdAt)) : null,
          details: data.details || null,
          all_fields: Object.keys(data)
        };
      } else {
        results.kap_sync_logs_latest = { found: false, message: 'Collection empty or does not exist' };
      }
    } catch (e) {
      results.errors.push('kap_sync_logs query error: ' + e.message);
    }

    try {
      // 2. Get meta/kap document
      const metaKap = await db.doc('meta/kap').get();
      if (metaKap.exists) {
        const data = metaKap.data();
        results.meta_kap = {
          lastSyncStatus: data.lastSyncStatus || null,
          lastSyncAt: data.lastSyncAt ? (data.lastSyncAt.toDate ? data.lastSyncAt.toDate().toISOString() : String(data.lastSyncAt)) : null,
          lastError: data.lastError || null,
          all_fields: Object.keys(data)
        };
      } else {
        results.meta_kap = { found: false, message: 'Document does not exist' };
      }
    } catch (e) {
      results.errors.push('meta/kap query error: ' + e.message);
    }

    fs.writeFileSync(OUTPUT_FILE, JSON.stringify(results, null, 2));
    console.log('Done');
    process.exit(0);
  }

  queryData().catch(e => {
    results.errors.push('Fatal async error: ' + e.message);
    fs.writeFileSync(OUTPUT_FILE, JSON.stringify(results, null, 2));
    process.exit(1);
  });

} catch (e) {
  results.errors.push('Admin SDK init error: ' + e.message);
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(results, null, 2));
  process.exit(1);
}
