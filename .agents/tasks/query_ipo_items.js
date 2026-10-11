const fs = require('fs');
const https = require('https');

// Firebase CLI token'ını oku
const configPath = process.env.USERPROFILE + '/.config/configstore/firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const tokens = config.tokens;
const refreshToken = tokens && tokens.refresh_token;

const PROJECT_ID = 'teknik-bakis';
const OUTPUT_FILE = 'd:/k/wink/teknik_bakis/.agents/tasks/ipo_items_sample.json';

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

async function getAccessToken() {
  const postData = `grant_type=refresh_token&refresh_token=${encodeURIComponent(refreshToken)}&client_id=563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com&client_secret=j9iVZfS8yt4i4opLS4pmw44J`;
  const result = await httpsRequest({
    hostname: 'oauth2.googleapis.com',
    path: '/token',
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
  }, postData);
  if (result.body.access_token) return result.body.access_token;
  throw new Error('Token alınamadı: ' + JSON.stringify(result.body));
}

async function queryFirestore(accessToken, pageToken) {
  const path = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/ipo_items?pageSize=300${pageToken ? '&pageToken=' + pageToken : ''}`;
  return httpsRequest({
    hostname: 'firestore.googleapis.com',
    path,
    method: 'GET',
    headers: { 'Authorization': 'Bearer ' + accessToken }
  });
}

function extractValue(v) {
  if (!v) return null;
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.integerValue !== undefined) return parseInt(v.integerValue);
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.timestampValue !== undefined) return v.timestampValue;
  if (v.doubleValue !== undefined) return v.doubleValue;
  if (v.nullValue !== undefined) return null;
  return JSON.stringify(v);
}

function parseDoc(doc) {
  const fields = doc.fields || {};
  const result = { _id: doc.name.split('/').pop() };
  for (const [k, v] of Object.entries(fields)) {
    result[k] = extractValue(v);
  }
  return result;
}

async function main() {
  console.log('Access token alınıyor...');
  const accessToken = await getAccessToken();
  console.log('Token alındı, Firestore sorgulanıyor...');

  let allDocs = [];
  let pageToken = null;
  do {
    const result = await queryFirestore(accessToken, pageToken);
    if (result.status !== 200) {
      console.error('Firestore hatası:', result.status, JSON.stringify(result.body).slice(0, 200));
      break;
    }
    const docs = (result.body.documents || []).map(parseDoc);
    allDocs = allDocs.concat(docs);
    pageToken = result.body.nextPageToken;
    console.log(`${allDocs.length} kayıt alındı...`);
  } while (pageToken);

  // İstatistikler
  const statusCounts = {};
  let noAnyDate = 0;
  const samples = {};

  for (const doc of allDocs) {
    const status = (doc.status || 'unknown').toLowerCase();
    statusCounts[status] = (statusCounts[status] || 0) + 1;

    const hasDate = doc.requestStart || doc.requestEnd || doc.listingDate || doc.publishedAt || doc.createdAt;
    if (!hasDate) noAnyDate++;

    if (!samples[status]) samples[status] = [];
    if (samples[status].length < 2) samples[status].push(doc);
  }

  const output = {
    totalDocs: allDocs.length,
    statusCounts,
    noAnyDate,
    samples
  };

  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(output, null, 2));
  console.log('Sonuç yazıldı:', OUTPUT_FILE);
  console.log('Toplam:', allDocs.length, '| Status dağılımı:', JSON.stringify(statusCounts));
  console.log('Hiç tarihi olmayan kayıt sayısı:', noAnyDate);
}

main().catch(e => { console.error(e); process.exit(1); });
