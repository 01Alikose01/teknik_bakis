const fs = require('fs');

const out = {};

// Check all possible config locations
const toCheck = [
  process.env.APPDATA + '/gcloud/configstore/firebase-tools.json',
  process.env.USERPROFILE + '/.config/configstore/firebase-tools.json',
  'C:/Users/k/AppData/Roaming/gcloud/configstore/firebase-tools.json',
  process.env.APPDATA + '/firebase',
  'C:/Users/k/AppData/Roaming/npm/node_modules/firebase-tools/package.json',
  'd:/k/wink/teknik_bakis/functions/node_modules/firebase-admin/package.json',
];

out.checks = {};
for (const p of toCheck) {
  try {
    const exists = fs.existsSync(p);
    out.checks[p] = exists ? 'EXISTS' : 'NOT FOUND';
    if (exists && p.endsWith('firebase-tools.json')) {
      const data = JSON.parse(fs.readFileSync(p, 'utf8'));
      out.checks[p + '__keys'] = Object.keys(data);
    }
  } catch(e) {
    out.checks[p] = 'ERROR: ' + e.message;
  }
}

out.env_GOOGLE_APPLICATION_CREDENTIALS = process.env.GOOGLE_APPLICATION_CREDENTIALS || 'not set';
out.env_FIREBASE_TOKEN = process.env.FIREBASE_TOKEN ? 'SET' : 'not set';
out.env_GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'not set';
out.env_FIREBASE_CONFIG = process.env.FIREBASE_CONFIG || 'not set';
out.cwd = process.cwd();
out.node_version = process.version;

fs.writeFileSync('d:/k/wink/teknik_bakis/.agents/tasks/creds_check.json', JSON.stringify(out, null, 2));
