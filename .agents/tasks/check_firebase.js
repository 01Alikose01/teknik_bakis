const fs = require('fs');
const path = require('path');

// Check Firebase config locations
const locations = [
  process.env.APPDATA + '/firebase',
  process.env.USERPROFILE + '/.config/firebase',
  process.env.USERPROFILE + '/.firebase',
];

console.log('=== Firebase Config Locations ===');
for (const loc of locations) {
  try {
    const files = fs.readdirSync(loc);
    console.log('FOUND:', loc);
    console.log('Files:', files);
  } catch (e) {
    console.log('NOT FOUND:', loc, '-', e.message.split('\n')[0]);
  }
}

// Check for Firebase CLI config/tokens
const configStorePaths = [
  process.env.APPDATA + '/gcloud/configstore/firebase-tools.json',
  process.env.USERPROFILE + '/.config/configstore/firebase-tools.json',
];

console.log('\n=== Firebase CLI Token ===');
for (const p of configStorePaths) {
  try {
    const content = fs.readFileSync(p, 'utf8');
    const data = JSON.parse(content);
    // Only show keys, not actual token values
    console.log('FOUND:', p);
    console.log('Keys:', Object.keys(data));
    if (data.tokens) console.log('Token keys:', Object.keys(data.tokens));
  } catch (e) {
    console.log('NOT FOUND:', p, '-', e.message.split('\n')[0]);
  }
}
