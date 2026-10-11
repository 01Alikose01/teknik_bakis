const fs = require('fs');
const https = require('https');

const configPath = process.env.USERPROFILE + '/.config/configstore/firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const accessToken = config.tokens.access_token;

const PROJECT_ID = 'teknik-bakis';

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

function extractValue(v) {
  if (!v) return null;
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.integerValue !== undefined) return parseInt(v.integerValue);
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.timestampValue !== undefined) return v.timestampValue;
  if (v.doubleValue !== undefined) return v.doubleValue;
  if (v.nullValue !== undefined) return null;
  return null;
}

async function main() {
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
    
    if (result.status !== 200) {
      console.error('Hata:', result.status, JSON.stringify(result.body).slice(0, 300));
      process.exit(1);
    }
    
    const docs = (result.body.documents || []).map(doc => {
      const fields = doc.fields || {};
      const r = { _id: doc.name.split('/').pop() };
      for (const [k, v] of Object.entries(fields)) r[k] = extractValue(v);
      return r;
    });
    allDocs = allDocs.concat(docs);
    pageToken = result.body.nextPageToken;
  } while (pageToken);
  
  console.log('Toplam:', allDocs.length);
  
  const now = new Date(Date.now() + 3 * 3600000);
  const upcoming = allDocs.filter(d => (d.status || '').toLowerCase() === 'upcoming');
  
  // requestStart dağılımı
  const withFutureStart = upcoming.filter(d => d.requestStart && new Date(d.requestStart) > now);
  const withPastStart = upcoming.filter(d => d.requestStart && new Date(d.requestStart) <= now);
  const withNoStart = upcoming.filter(d => !d.requestStart);
  
  console.log('Upcoming toplam:', upcoming.length);
  console.log('- Gelecekte requestStart:', withFutureStart.length);
  console.log('- Geçmişte requestStart:', withPastStart.length);
  console.log('- requestStart yok:', withNoStart.length);
  
  // Gelecekteki kayıtların tarihleri
  console.log('\n-- Gelecekte requestStart olan ilk 10 kayıt --');
  withFutureStart.slice(0, 10).forEach(d => {
    console.log(`  ${d.symbol || d._id}: requestStart=${d.requestStart}, requestEnd=${d.requestEnd}, listingDate=${d.listingDate}`);
  });
  
  // Geçmişteki kayıtlar (bunlar upcoming kalmamalı)
  console.log('\n-- Geçmişte requestStart olan kayıtlar (upcoming olmamalı) --');
  withPastStart.forEach(d => {
    console.log(`  ${d.symbol || d._id}: requestStart=${d.requestStart}, requestEnd=${d.requestEnd}`);
  });
  
  // requestStart yok olanlar
  console.log('\n-- requestStart yok olan ilk 10 kayıt --');
  withNoStart.slice(0, 10).forEach(d => {
    console.log(`  ${d.symbol || d._id}: status=${d.status}, publishedAt=${d.publishedAt}, requestDates=${d.requestDates}`);
  });
  
  // Özet rapor kaydet
  const report = {
    total: allDocs.length,
    statusCounts: {},
    upcomingBreakdown: {
      total: upcoming.length,
      withFutureStart: withFutureStart.length,
      withPastStart: withPastStart.length,
      withNoStart: withNoStart.length,
    },
    futureStartSamples: withFutureStart.slice(0, 20).map(d => ({
      id: d._id, symbol: d.symbol, requestStart: d.requestStart, requestEnd: d.requestEnd, listingDate: d.listingDate, companyName: d.companyName
    })),
    pastStartList: withPastStart.map(d => ({ id: d._id, symbol: d.symbol, requestStart: d.requestStart, requestEnd: d.requestEnd })),
    noStartSamples: withNoStart.slice(0, 20).map(d => ({ id: d._id, symbol: d.symbol, publishedAt: d.publishedAt, requestDates: d.requestDates, companyName: d.companyName }))
  };
  
  allDocs.forEach(d => {
    const s = (d.status || 'null').toLowerCase();
    report.statusCounts[s] = (report.statusCounts[s] || 0) + 1;
  });
  
  fs.writeFileSync('d:/k/wink/teknik_bakis/.agents/tasks/upcoming_inspect.json', JSON.stringify(report, null, 2));
  console.log('\nRapor: .agents/tasks/upcoming_inspect.json');
}

main().catch(e => { console.error(e.message); process.exit(1); });
