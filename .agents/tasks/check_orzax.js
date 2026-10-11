const fs = require('fs');
const https = require('https');

const configPath = process.env.USERPROFILE + '/.config/configstore/firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const accessToken = config.tokens.access_token;
const PROJECT_ID = 'teknik-bakis';

function httpsRequest(options) {
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
    req.end();
  });
}

function extractValue(v) {
  if (!v) return null;
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.integerValue !== undefined) return parseInt(v.integerValue);
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.timestampValue !== undefined) return v.timestampValue;
  return null;
}

async function main() {
  // Tüm dokümanları çek ve requestDates "-" olmayan upcoming'leri filtrele
  let allDocs = [];
  let pageToken = null;
  
  do {
    const path = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/ipo_items?pageSize=300${pageToken ? '&pageToken=' + pageToken : ''}`;
    const result = await httpsRequest({
      hostname: 'firestore.googleapis.com',
      path,
      method: 'GET',
      headers: { 'Authorization': 'Bearer ' + accessToken }
    });
    
    if (result.status !== 200) { console.error(result.status, JSON.stringify(result.body).slice(0, 200)); process.exit(1); }
    
    const docs = (result.body.documents || []).map(doc => {
      const fields = doc.fields || {};
      const r = { _id: doc.name.split('/').pop(), _name: doc.name };
      for (const [k, v] of Object.entries(fields)) r[k] = extractValue(v);
      return r;
    });
    allDocs = allDocs.concat(docs);
    pageToken = result.body.nextPageToken;
  } while (pageToken);

  const now = new Date(Date.now() + 3 * 3600000);
  
  // requestDates "-" olmayan upcoming'ler (bunlar gerçek tarih verisi olan ama hâlâ upcoming statüslü)
  const upcomingWithDates = allDocs.filter(d => {
    if ((d.status || '').toLowerCase() !== 'upcoming') return false;
    const rd = (d.requestDates || '').trim();
    return rd && rd !== '-';
  });
  
  console.log('Tarih bilgisi olan upcoming kayıt sayısı:', upcomingWithDates.length);
  upcomingWithDates.forEach(d => {
    console.log(`  ${d.symbol || d._id}: requestDates="${d.requestDates}", requestStart=${d.requestStart}, requestEnd=${d.requestEnd}`);
  });
  
  // ORZAX
  const orzax = allDocs.find(d => (d.symbol || '').toUpperCase() === 'ORZAX' || d._id === 'ORZAX');
  console.log('\nORZAX:', JSON.stringify(orzax, null, 2));
  
  fs.writeFileSync('d:/k/wink/teknik_bakis/.agents/tasks/upcoming_with_dates.json', JSON.stringify(upcomingWithDates, null, 2));
}

main().catch(e => { console.error(e.message); process.exit(1); });
