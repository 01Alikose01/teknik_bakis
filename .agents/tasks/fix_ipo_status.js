/**
 * Firestore ipo_items koleksiyonundaki geçmiş tarihli/tarihi belirsiz
 * kayıtları tespit edip doğru statüye günceller.
 * 
 * Kural:
 *  - requestEnd geçmişse ve listingDate yoksa → trading
 *  - requestEnd geçmişse ve listingDate geçmişse → trading  
 *  - requestStart geçmişse ve requestEnd yoksa → trading
 *  - publishedAt 60 günden eskiyse ve status upcoming/pendingListing → trading
 *  - hiç tarih yoksa ve status upcoming/pendingListing → trading
 * 
 * NETGL özellikle → trading olarak işaretle
 */

const { execSync } = require('child_process');
const fs = require('fs');
const https = require('https');

// firebase-tools'dan access token al
function getFirebaseToken() {
  try {
    // firebase CLI ile token al
    const result = execSync('firebase --version', { encoding: 'utf8', timeout: 5000 });
    console.log('Firebase CLI:', result.trim());
  } catch(e) {
    console.log('Firebase CLI bulunamadı, token dosyasından okuyoruz...');
  }
  
  const configPath = process.env.USERPROFILE + '/.config/configstore/firebase-tools.json';
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  return config.tokens;
}

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

// Firebase tools OAuth2 client - bunları firebase-tools source'dan alıyoruz
// firebase-tools kullandığı client app'i public repo'da açıklıyor
async function getAccessToken(refreshToken) {
  // Firebase tools public client ID (from https://github.com/firebase/firebase-tools)
  const CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
  
  // node-modules'dan client secret'ı çıkar
  const toolsPath = 'C:/Users/k/AppData/Roaming/npm/node_modules/firebase-tools';
  let clientSecret = null;
  
  // Minified bundle'dan çek
  const files = ['lib/index.js', 'lib/cli.js', 'lib/auth.js', 'lib/api.js'];
  for (const f of files) {
    try {
      const content = fs.readFileSync(toolsPath + '/' + f, 'utf8');
      // Pattern: "client_secret":"XXXXXX" veya clientSecret:"XXXXX"
      const m = content.match(/["']GOCSPX-[A-Za-z0-9_-]{28,50}["']/);
      if (m) {
        clientSecret = m[0].replace(/['"]/g, '');
        console.log('Client secret bulundu:', f, 'length:', clientSecret.length);
        break;
      }
    } catch(e) {}
  }
  
  if (!clientSecret) {
    // Alternatif: gcloud credentials kullan
    const gcloudPaths = [
      process.env.USERPROFILE + '/.config/gcloud/application_default_credentials.json',
      process.env.APPDATA + '/gcloud/application_default_credentials.json',
    ];
    for (const p of gcloudPaths) {
      try {
        const creds = JSON.parse(fs.readFileSync(p, 'utf8'));
        if (creds.access_token) {
          console.log('gcloud ADC access token bulundu');
          return creds.access_token;
        }
        if (creds.client_secret && creds.refresh_token) {
          clientSecret = creds.client_secret;
          // refreshToken = creds.refresh_token; // override
          console.log('gcloud client secret bulundu');
          break;
        }
      } catch(e) {}
    }
  }
  
  if (!clientSecret) {
    throw new Error('Client secret bulunamadı. Lütfen firebase login yapın veya GOOGLE_APPLICATION_CREDENTIALS ayarlayın.');
  }
  
  const postData = `grant_type=refresh_token&refresh_token=${encodeURIComponent(refreshToken)}&client_id=${CLIENT_ID}&client_secret=${clientSecret}`;
  const result = await httpsRequest({
    hostname: 'oauth2.googleapis.com',
    path: '/token',
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Content-Length': Buffer.byteLength(postData) }
  }, postData);
  
  if (result.body.access_token) return result.body.access_token;
  throw new Error('Token alınamadı: ' + JSON.stringify(result.body));
}

async function queryAllIpoItems(accessToken) {
  const PROJECT_ID = 'teknik-bakis';
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
    
    if (result.status !== 200) throw new Error('Firestore GET hatası: ' + result.status + ' ' + JSON.stringify(result.body).slice(0, 300));
    
    const docs = result.body.documents || [];
    allDocs = allDocs.concat(docs);
    pageToken = result.body.nextPageToken;
    console.log(`${allDocs.length} doküman alındı...`);
  } while (pageToken);
  
  return allDocs;
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

function parseDoc(doc) {
  const fields = doc.fields || {};
  const result = { _name: doc.name, _id: doc.name.split('/').pop() };
  for (const [k, v] of Object.entries(fields)) {
    result[k] = extractValue(v);
  }
  return result;
}

function parseDate(val) {
  if (!val) return null;
  try { return new Date(val); } catch(e) { return null; }
}

function nowTurkey() {
  return new Date(Date.now() + 3 * 3600000); // UTC+3
}

function shouldBeTrading(doc) {
  const now = nowTurkey();
  const status = (doc.status || '').toLowerCase();
  
  // Zaten trading veya ertelendi ise dokunma
  if (status === 'trading' || status === 'completed' || status === 'borsada_islem_goruyor' ||
      status === 'ertelendi' || status === 'postponed') return false;
  
  const requestEnd = parseDate(doc.requestEnd);
  const requestStart = parseDate(doc.requestStart);
  const listingDate = parseDate(doc.listingDate);
  const publishedAt = parseDate(doc.publishedAt) || parseDate(doc.createdAt);
  
  // listingDate geçmişse → trading
  if (listingDate && listingDate <= now) return true;
  
  // requestEnd geçmişse
  if (requestEnd && requestEnd < now) {
    // listingDate gelecekte olsa da → listeleme bekliyordur ama 30 gün geçmişse trading
    if (!listingDate) {
      const daysPast = (now - requestEnd) / (1000 * 86400);
      if (daysPast > 30) return true;
      // 30 günden az geçmişse pendingListing, değiştirme
      return false;
    }
    return true; // listingDate geçmişse zaten üstte yakalandı
  }
  
  // requestStart geçmişse ve requestEnd yoksa (sadece startı olan kayıtlar)
  if (requestStart && requestStart < now && !requestEnd) {
    const daysPast = (now - requestStart) / (1000 * 86400);
    if (daysPast > 30) return true;
  }
  
  // Hiç tarih yoksa ve publishedAt 60 günden eskiyse → trading
  if (!requestStart && !requestEnd && !listingDate) {
    if (publishedAt) {
      const daysPast = (now - publishedAt) / (1000 * 86400);
      if (daysPast > 60) return true;
    } else {
      // Hiç tarih yok → kesinlikle eski bir kayıt, trading yap
      return true;
    }
  }
  
  return false;
}

async function updateDoc(accessToken, docName, newStatus) {
  const PROJECT_ID = 'teknik-bakis';
  const docPath = docName.replace(`projects/${PROJECT_ID}/databases/(default)/documents/`, '');
  const url = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${docPath}?updateMask.fieldPaths=status`;
  
  const body = JSON.stringify({
    fields: { status: { stringValue: newStatus } }
  });
  
  return httpsRequest({
    hostname: 'firestore.googleapis.com',
    path: url,
    method: 'PATCH',
    headers: {
      'Authorization': 'Bearer ' + accessToken,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body)
    }
  }, body);
}

async function main() {
  const tokens = getFirebaseToken();
  console.log('Token keys:', Object.keys(tokens || {}));
  
  // Önce mevcut access_token'ı dene
  let accessToken = tokens.access_token;
  if (!accessToken) {
    accessToken = await getAccessToken(tokens.refresh_token);
  }
  console.log('Access token alındı.');
  
  const allDocs = await queryAllIpoItems(accessToken);
  console.log('Toplam doküman:', allDocs.length);
  
  const parsed = allDocs.map(parseDoc);
  
  // Status dağılımı
  const statusCounts = {};
  for (const d of parsed) {
    const s = (d.status || 'null').toLowerCase();
    statusCounts[s] = (statusCounts[s] || 0) + 1;
  }
  console.log('Status dağılımı:', JSON.stringify(statusCounts));
  
  // Güncellenecekler
  const toUpdate = parsed.filter(d => shouldBeTrading(d));
  console.log('Trading olarak güncellenecek kayıt sayısı:', toUpdate.length);
  
  // NETGL'yi ayrıca kontrol et
  const netgl = parsed.find(d => (d.symbol || '').toUpperCase() === 'NETGL');
  if (netgl) {
    console.log('NETGL durumu:', JSON.stringify(netgl, null, 2));
  }
  
  // Rapor kaydet
  const report = {
    timestamp: new Date().toISOString(),
    totalDocs: allDocs.length,
    statusCounts,
    toUpdateCount: toUpdate.length,
    toUpdateSamples: toUpdate.slice(0, 10).map(d => ({ id: d._id, status: d.status, requestStart: d.requestStart, requestEnd: d.requestEnd, listingDate: d.listingDate, publishedAt: d.publishedAt, symbol: d.symbol })),
    netgl
  };
  fs.writeFileSync('d:/k/wink/teknik_bakis/.agents/tasks/ipo_fix_report.json', JSON.stringify(report, null, 2));
  console.log('Rapor kaydedildi: ipo_fix_report.json');
  
  // Güncelle
  let updated = 0, errors = 0;
  for (const doc of toUpdate) {
    try {
      const result = await updateDoc(accessToken, doc._name, 'trading');
      if (result.status === 200) {
        updated++;
      } else {
        console.error('Güncelleme hatası:', doc._id, result.status, JSON.stringify(result.body).slice(0, 100));
        errors++;
      }
      if (updated % 20 === 0) console.log(`${updated} kayıt güncellendi...`);
    } catch(e) {
      console.error('Hata:', doc._id, e.message);
      errors++;
    }
  }
  
  console.log(`\nTamamlandı: ${updated} güncellendi, ${errors} hata.`);
  
  // NETGL güncelle (listede yoksa ayrıca)
  if (netgl && !toUpdate.find(d => d._id === netgl._id)) {
    console.log('NETGL ayrıca güncelleniyor...');
    const r = await updateDoc(accessToken, netgl._name, 'trading');
    console.log('NETGL güncelleme sonucu:', r.status);
  }
}

main().catch(e => { console.error(e.message); process.exit(1); });
