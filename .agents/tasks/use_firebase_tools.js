/**
 * Use firebase-tools directly to read Firestore data.
 * firebase-tools has built-in auth using the stored CLI tokens.
 */
const fs = require('fs');
const OUTPUT = 'd:/k/wink/teknik_bakis/.agents/tasks/firestore_results.json';
const results = { timestamp: new Date().toISOString(), errors: [] };

// Set environment so firebase-tools knows which project
process.env.GCLOUD_PROJECT = 'teknik-bakis';
process.env.FIREBASE_PROJECT = 'teknik-bakis';

try {
  const firebase = require('C:/Users/k/AppData/Roaming/npm/node_modules/firebase-tools');
  results.firebase_tools_loaded = true;
  results.firebase_tools_keys = Object.keys(firebase);
  fs.writeFileSync(OUTPUT, JSON.stringify(results, null, 2));
} catch(e) {
  results.errors.push('load error: ' + e.message);
  fs.writeFileSync(OUTPUT, JSON.stringify(results, null, 2));
}
