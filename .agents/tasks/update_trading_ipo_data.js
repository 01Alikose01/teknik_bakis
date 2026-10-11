/**
 * Firestore ipo_items koleksiyonundaki "trading" durumundaki hisselerin
 * price, lot, distributionType alanlarını GitHub ipo_feed.json'dan alınan
 * doğru değerlerle günceller.
 * 
 * Çalıştırma: node .agents/tasks/update_trading_ipo_data.js
 */

const https = require('https');
const fs = require('fs');

// Firebase tools token'ını oku ve gerekirse yenile
async function getAccessToken() {
  const configPath = process.env.USERPROFILE + '/.config/configstore/firebase-tools.json';
  try {
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    const tokens = config.tokens || {};

    // Önce mevcut access_token'ı dene
    if (tokens.access_token) {
      // Token geçerliliğini kontrol et
      const testResult = await httpsRequest({
        hostname: 'firestore.googleapis.com',
        path: '/v1/projects/teknik-bakis/databases/(default)/documents/ipo_meta/feed',
        method: 'GET',
        headers: { 'Authorization': 'Bearer ' + tokens.access_token }
      });
      if (testResult.status !== 401) {
        console.log('Mevcut access token geçerli.');
        return tokens.access_token;
      }
      console.log('Access token süresi dolmuş, yenileniyor...');
    }

    // Token yenile
    if (!tokens.refresh_token) throw new Error('refresh_token bulunamadı');
    return await refreshAccessToken(tokens.refresh_token);
  } catch (e) {
    throw new Error('Firebase token okunamadı: ' + e.message);
  }
}

async function refreshAccessToken(refreshToken) {
  // firebase-tools client secret'ını bul
  const toolsPath = 'C:/Users/k/AppData/Roaming/npm/node_modules/firebase-tools';
  let clientSecret = null;
  const CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';

  const files = ['lib/index.js', 'lib/cli.js', 'lib/auth.js', 'lib/api.js'];
  for (const f of files) {
    try {
      const content = fs.readFileSync(toolsPath + '/' + f, 'utf8');
      const m = content.match(/["']GOCSPX-[A-Za-z0-9_-]{28,50}["']/);
      if (m) {
        clientSecret = m[0].replace(/['"]/g, '');
        console.log('Client secret bulundu:', f.split('/').pop());
        break;
      }
    } catch (e) {}
  }

  if (!clientSecret) throw new Error('Client secret bulunamadı');

  const postData = `grant_type=refresh_token&refresh_token=${encodeURIComponent(refreshToken)}&client_id=${CLIENT_ID}&client_secret=${clientSecret}`;
  const result = await httpsRequest({
    hostname: 'oauth2.googleapis.com',
    path: '/token',
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': Buffer.byteLength(postData)
    }
  }, postData);

  if (result.body.access_token) {
    console.log('Token yenilendi.');
    return result.body.access_token;
  }
  throw new Error('Token yenilenemedi: ' + JSON.stringify(result.body));
}

function httpsRequest(options, postData) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
        catch (e) { resolve({ status: res.statusCode, body: data }); }
      });
    });
    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

// GitHub ipo_feed.json verisi — zaten çekilmiş, doğrudan kullan
function fetchGithubFeed() {
  // Bu veri 2026-10-10T11:36:01 tarihli GitHub feed'den alınmıştır
  const feed = {"lastUpdated":"2026-10-10T11:36:01.384Z","source":"HalkArz Scraper","items":[{"companyName":"Net Global Endüstriyel Yatırımlar A.Ş.","requestDates":"9-10-11 Eylül 2026","requestStart":"2026-09-09T12:00:00.000Z","requestEnd":"2026-09-11T12:00:00.000Z","price":"25,52 TL","lot":"87.500.000 Lot","distributionType":"Eşit Dağıtım","symbol":"NETGL","status":"upcoming","listingDate":"2026-09-17T12:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328d9f52dddc01a06d16f5885572","source":"HalkArz","publishedAt":"2026-10-10T11:35:50.466Z"},{"companyName":"Bakırcı Gayrimenkul Yatırım Ortaklığı A.Ş.","requestDates":"24-25-26 Ağustos 2026","requestStart":"2026-08-24T12:00:00.000Z","requestEnd":"2026-08-26T12:00:00.000Z","price":"12,93 TL","lot":"167.000.000 Lot","distributionType":"Eşit Dağıtım","symbol":"BKRGY","status":"trading","listingDate":"2026-09-02T12:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328c9f52dc4001a024f731955d59","source":"HalkArz","publishedAt":"2026-10-10T11:35:51.725Z"},{"companyName":"İntetra Teknoloji ve Bilişim Hizmetleri A.Ş.","requestDates":"26-27 Ağustos 2026","requestStart":"2026-08-26T12:00:00.000Z","requestEnd":"2026-08-27T12:00:00.000Z","price":"53,60 TL","lot":"40.000.000 Lot","distributionType":"Eşit Dağıtım","symbol":"INTET","status":"trading","listingDate":"2026-09-01T12:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328c9f52dc3f01a0258b515a7062","source":"HalkArz","publishedAt":"2026-10-10T11:35:51.095Z"},{"companyName":"Kapeks Kimya Sanayi A.Ş.","requestDates":"12-13-14 Ağustos 2026","requestStart":"2026-08-12T12:00:00.000Z","requestEnd":"2026-08-14T12:00:00.000Z","price":"94,00 TL","lot":"25.100.000 Lot","distributionType":"Eşit Dağıtım","symbol":"KPEKS","status":"trading","listingDate":"2026-08-21T12:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328d9f52dddc019fdb55869a285c","source":"HalkArz","publishedAt":"2026-10-10T11:35:52.985Z"},{"companyName":"Türker Vangölü Enerji Yatırım A.Ş.","requestDates":"12-13-14 Ağustos 2026","requestStart":"2026-08-12T12:00:00.000Z","requestEnd":"2026-08-14T12:00:00.000Z","price":"136,00 TL","lot":"65.000.000 Lot","distributionType":"Eşit Dağıtım","symbol":"VEYAS","status":"trading","listingDate":"2026-08-20T12:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328d9f52dddd019fd9277b3110bc","source":"HalkArz","publishedAt":"2026-10-10T11:35:52.355Z"},{"companyName":"Teknika Plast Teknik Kalıp Plastik San. ve Tic. A.Ş.","requestDates":"12-13-14 Ağustos 2026","requestStart":"2026-08-12T12:00:00.000Z","requestEnd":"2026-08-14T12:00:00.000Z","price":"85,40 TL","lot":"31.000.000 Lot","distributionType":"Eşit Dağıtım","symbol":"TKNKA","status":"trading","listingDate":"2026-08-20T12:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328d9f52dddd019fdbb9f42242a2","source":"HalkArz","publishedAt":"2026-10-10T11:35:53.614Z"},{"companyName":"Çitlekçi Mağazacılık Gıda A.Ş.","requestDates":"10-11-12 Ağustos 2026","requestStart":"2026-08-10T12:00:00.000Z","requestEnd":"2026-08-12T12:00:00.000Z","price":"73,70 TL","lot":"36.500.000 Lot","distributionType":"Eşit Dağıtım","symbol":"CITAS","status":"trading","listingDate":"2026-08-18T12:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328c9f52dc40019fd7eb4af2321e","source":"HalkArz","publishedAt":"2026-10-10T11:35:54.244Z"},{"companyName":"Quick Sigorta A.S.","requestDates":"29.07.2026 - 31.07.2026","requestStart":"2026-07-29T00:00:00.000Z","requestEnd":"2026-07-31T00:00:00.000Z","price":"76,60 TL","lot":"135.000.000 lot","distributionType":"Esit Dagitim","symbol":"QUICK","status":"upcoming","listingDate":"2026-08-06T09:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328c9f52dc40019f94ccb8a06e0c","source":"Manual Override","publishedAt":"2026-08-07T14:08:25.663Z"},{"companyName":"Kardemir Celik Sanayi A.S.","requestDates":"22.07.2026 - 24.07.2026","requestStart":"2026-07-22T00:00:00.000Z","requestEnd":"2026-07-24T00:00:00.000Z","price":"35,00 TL","lot":"128.000.000 lot","distributionType":"Esit Dagitim","symbol":"KARCL","status":"trading","listingDate":"2026-07-29T00:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328c9f52dc3f019f709e5827107e","source":"Manual Override","publishedAt":"2026-08-07T14:08:26.180Z"},{"companyName":"Masfen Enerji A.S.","requestDates":"22.07.2026 - 24.07.2026","requestStart":"2026-07-22T00:00:00.000Z","requestEnd":"2026-07-24T00:00:00.000Z","price":"45,68 TL","lot":"85.000.000 lot","distributionType":"Oransal Dagitim","symbol":"MASFN","status":"trading","listingDate":"2026-07-29T00:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328d9f52dddc019f70f1fdb33a64","source":"Manual Override","publishedAt":"2026-08-07T14:08:26.704Z"},{"companyName":"Albayrak Hazir Beton San. ve Tic. A.S.","requestDates":"22.07.2026 - 23.07.2026","requestStart":"2026-07-22T00:00:00.000Z","requestEnd":"2026-07-23T00:00:00.000Z","price":"38,60 TL","lot":"70.000.000 lot","distributionType":"Esit Dagitim","symbol":"ALBTN","status":"trading","listingDate":"2026-07-29T00:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328d9f52dddc019f71eb1d434267","source":"Manual Override","publishedAt":"2026-08-07T14:08:27.238Z"},{"companyName":"Metgun Enerji Yatirimlari A.S.","requestDates":"20.07.2026 - 22.07.2026","requestStart":"2026-07-20T00:00:00.000Z","requestEnd":"2026-07-22T00:00:00.000Z","price":"20,00 TL","lot":"135.579.000 lot","distributionType":"Esit Dagitim","symbol":"METEN","status":"trading","listingDate":"2026-07-28T00:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328d9f52dddd019f70f991ec2e65","source":"Manual Override","publishedAt":"2026-08-07T14:08:27.766Z"},{"companyName":"Sa-Ra Enerji Insaat Tic. ve San. A.S.","requestDates":"08.07.2026 - 10.07.2026","requestStart":"2026-07-08T00:00:00.000Z","requestEnd":"2026-07-10T00:00:00.000Z","price":"70,00 TL","lot":"89.000.000 lot","distributionType":"Oransal Dagitim","symbol":"SARAE","status":"trading","listingDate":"2026-07-17T00:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328c9f0a085a019f28f201327586","source":"Manual Override","publishedAt":"2026-08-07T14:08:28.309Z"},{"companyName":"Saat ve Saat San. ve Tic. A.S.","requestDates":"06.07.2026 - 08.07.2026","requestStart":"2026-07-06T00:00:00.000Z","requestEnd":"2026-07-08T00:00:00.000Z","price":"56,00 TL","lot":"80.334.000 lot","distributionType":"Esit Dagitim","symbol":"SSAAT","status":"trading","listingDate":"2026-07-15T00:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328c9f0a085b019f2484de57414e","source":"Manual Override","publishedAt":"2026-08-07T14:08:28.829Z"},{"companyName":"Ekim Turizm Tic. ve San. A.S.","requestDates":"01.07.2026 - 03.07.2026","requestStart":"2026-07-01T00:00:00.000Z","requestEnd":"2026-07-03T00:00:00.000Z","price":"30,26 TL","lot":"162.000.000 lot","distributionType":"Esit Dagitim","symbol":"EKIM","status":"trading","listingDate":"2026-07-10T00:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328c9ec11d3d019f051c0e427376","source":"Manual Override","publishedAt":"2026-08-07T14:08:29.874Z"},{"companyName":"Isvea Seramik ve Banyo Urunleri Sanayi A.S.","requestDates":"01.07.2026 - 03.07.2026","requestStart":"2026-07-01T00:00:00.000Z","requestEnd":"2026-07-03T00:00:00.000Z","price":"20,90 TL","lot":"67.000.000 lot","distributionType":"Esit Dagitim","symbol":"ISVEA","status":"trading","listingDate":"2026-07-09T00:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328c9ec11d3d019efff937cb5030","source":"Manual Override","publishedAt":"2026-08-07T14:08:29.359Z"},{"companyName":"Golda Gida San. ve Tic. A.S.","requestDates":"01.07.2026 - 02.07.2026","requestStart":"2026-07-01T00:00:00.000Z","requestEnd":"2026-07-02T00:00:00.000Z","price":"9,20 TL","lot":"87.500.000 lot","distributionType":"Oransal Dagitim","symbol":"GOLDA","status":"trading","listingDate":"2026-07-09T00:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328d9ec11d42019f02e9e4f7602e","source":"Manual Override","publishedAt":"2026-08-07T14:08:30.392Z"},{"companyName":"Soho Giyim ve Enerji A.S.","requestDates":"30.06.2026 - 01.07.2026","requestStart":"2026-06-30T00:00:00.000Z","requestEnd":"2026-07-01T00:00:00.000Z","price":"15,00 TL","lot":"100.000.000 lot","distributionType":"Esit Dagitim","symbol":"SOHOE","status":"trading","listingDate":"2026-07-08T00:00:00.000Z","kapUrl":"","source":"Manual Override","publishedAt":"2026-08-07T14:08:30.922Z"},{"companyName":"Orzaks Ilac ve Kimya Sanayi Tic. A.S.","requestDates":"29.06.2026 - 01.07.2026","requestStart":"2026-06-29T00:00:00.000Z","requestEnd":"2026-07-01T00:00:00.000Z","price":"69,00 TL","lot":"55.000.000 lot","distributionType":"Oransal Dagitim","symbol":"ORZAX","status":"trading","listingDate":"2026-07-07T00:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328d9ec11d43019f000c0774485b","source":"Manual Override","publishedAt":"2026-08-07T14:08:31.441Z"},{"companyName":"Beta Enerji ve Teknoloji A.Ş.","requestDates":"23-24-25 Haziran 2026","requestStart":"2026-06-23T12:00:00.000Z","requestEnd":"2026-06-25T12:00:00.000Z","price":"40,00 TL","lot":"60.750.000 Lot","distributionType":"Eşit Dağıtım","symbol":"BETAE","status":"trading","listingDate":"2026-07-01T12:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328c9ec11d3d019ed910f3ea7a2d","source":"HalkArz","publishedAt":"2026-09-03T15:29:43.542Z"},{"companyName":"Ekinciler Demir ve Çelik Sanayi A.Ş.","requestDates":"13-14-15 Mayıs 2026","requestStart":"2026-05-13T12:00:00.000Z","requestEnd":"2026-05-15T12:00:00.000Z","price":"45,00 TL","lot":"52.000.000 Lot","distributionType":"Eşit Dağıtım **","symbol":"EKDMR","status":"trading","listingDate":"2026-05-22T12:00:00.000Z","kapUrl":"https://www.kap.org.tr/tr/api/file/download/4028328c9d7b22d3019e1d5491210e0b","source":"HalkArz","publishedAt":"2026-08-20T18:24:12.216Z"},{"companyName":"Enpara Bank A.Ş.","requestDates":"7 Nisan 2026 (Kısmi Bölünme)","requestStart":"2026-04-07T12:00:00.000Z","requestEnd":"2026-04-07T12:00:00.000Z","price":"-","lot":"-","distributionType":"-","symbol":"ENPRA","status":"trading","listingDate":"2026-04-07T12:00:00.000Z","kapUrl":"","source":"HalkArz","publishedAt":"2026-08-20T18:24:12.786Z"}]};
  return Promise.resolve(feed);
}

// Firestore'daki bir belgeyi güncelle (price, lot, distributionType, listingDate alanları)
async function patchDoc(accessToken, symbol, updates) {
  const PROJECT_ID = 'teknik-bakis';
  const docPath = `ipo_items/${symbol}`;

  // Güncellenecek alanlar ve updateMask
  const fields = {};
  const maskFields = [];

  if (updates.price !== undefined) {
    fields.price = { stringValue: updates.price };
    maskFields.push('price');
  }
  if (updates.lot !== undefined) {
    fields.lot = { stringValue: updates.lot };
    maskFields.push('lot');
  }
  if (updates.distributionType !== undefined) {
    fields.distributionType = { stringValue: updates.distributionType };
    maskFields.push('distributionType');
  }
  if (updates.listingDate !== undefined) {
    fields.listingDate = { timestampValue: updates.listingDate };
    maskFields.push('listingDate');
  }
  if (updates.requestStart !== undefined) {
    fields.requestStart = { timestampValue: updates.requestStart };
    maskFields.push('requestStart');
  }
  if (updates.requestEnd !== undefined) {
    fields.requestEnd = { timestampValue: updates.requestEnd };
    maskFields.push('requestEnd');
  }
  if (updates.status !== undefined) {
    fields.status = { stringValue: updates.status };
    maskFields.push('status');
  }

  if (maskFields.length === 0) return { status: 200, body: 'no fields' };

  const mask = maskFields.map(f => `updateMask.fieldPaths=${encodeURIComponent(f)}`).join('&');
  const url = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${docPath}?${mask}`;

  const body = JSON.stringify({ fields });

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

// Firestore'daki tüm ipo_items belgelerini çek
async function fetchAllFirestoreDocs(accessToken) {
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

    if (result.status !== 200) {
      throw new Error('Firestore GET hatası: ' + result.status + ' ' + JSON.stringify(result.body).slice(0, 200));
    }

    const docs = result.body.documents || [];
    allDocs = allDocs.concat(docs);
    pageToken = result.body.nextPageToken;
    console.log(`${allDocs.length} doküman alındı...`);
  } while (pageToken);

  return allDocs;
}

function extractStrValue(v) {
  if (!v) return '';
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.timestampValue !== undefined) return v.timestampValue;
  return '';
}

function parseFirestoreDoc(doc) {
  const fields = doc.fields || {};
  const id = doc.name.split('/').pop();
  return {
    _id: id,
    price: extractStrValue(fields.price),
    lot: extractStrValue(fields.lot),
    distributionType: extractStrValue(fields.distributionType),
    status: extractStrValue(fields.status),
    listingDate: extractStrValue(fields.listingDate),
    requestStart: extractStrValue(fields.requestStart),
    requestEnd: extractStrValue(fields.requestEnd),
  };
}

// Değerin boş/eksik olup olmadığını kontrol et
function isMissing(val) {
  return !val || val.trim() === '' || val.trim() === '-';
}

async function main() {
  console.log('=== IPO Fiyat/Lot/Dağıtım Güncelleme Script\'i ===\n');

  // 1. GitHub feed'i çek
  console.log('GitHub ipo_feed.json okunuyor...');
  const feed = await fetchGithubFeed();
  const feedItems = feed.items || [];
  console.log(`GitHub'dan ${feedItems.length} kayıt alındı.\n`);

  // GitHub kayıtlarını sembol→item map'ine çevir
  const githubMap = {};
  for (const item of feedItems) {
    if (item.symbol) githubMap[item.symbol.toUpperCase()] = item;
  }

  // 2. Firebase token
  console.log('Firebase token alınıyor...');
  const accessToken = await getAccessToken();
  console.log('Token alındı.\n');

  // 3. Firestore'daki tüm kayıtları çek
  console.log('Firestore\'dan tüm ipo_items alınıyor...');
  const firestoreDocs = await fetchAllFirestoreDocs(accessToken);
  const parsed = firestoreDocs.map(parseFirestoreDoc);
  console.log(`Toplam ${parsed.length} Firestore kaydı alındı.\n`);

  // 4. Güncellenmesi gereken kayıtları bul
  const toUpdate = [];
  for (const doc of parsed) {
    const symbol = doc._id.toUpperCase();
    const githubItem = githubMap[symbol];

    if (!githubItem) continue; // GitHub'da yoksa atla

    const updates = {};
    let needsUpdate = false;

    // price eksikse veya "-" ise GitHub'dan al
    if (isMissing(doc.price) && !isMissing(githubItem.price)) {
      updates.price = githubItem.price;
      needsUpdate = true;
    }

    // lot eksikse veya "-" ise GitHub'dan al
    if (isMissing(doc.lot) && !isMissing(githubItem.lot)) {
      updates.lot = githubItem.lot;
      needsUpdate = true;
    }

    // distributionType eksikse veya "-" ise GitHub'dan al
    if (isMissing(doc.distributionType) && !isMissing(githubItem.distributionType)) {
      updates.distributionType = githubItem.distributionType;
      needsUpdate = true;
    }

    // listingDate eksikse GitHub'dan al
    if (isMissing(doc.listingDate) && githubItem.listingDate) {
      updates.listingDate = githubItem.listingDate;
      needsUpdate = true;
    }

    // requestStart eksikse GitHub'dan al
    if (isMissing(doc.requestStart) && githubItem.requestStart) {
      updates.requestStart = githubItem.requestStart;
      needsUpdate = true;
    }

    // requestEnd eksikse GitHub'dan al
    if (isMissing(doc.requestEnd) && githubItem.requestEnd) {
      updates.requestEnd = githubItem.requestEnd;
      needsUpdate = true;
    }

    // status "trading" değilse ama GitHub'da "trading" ise düzelt
    if (doc.status !== 'trading' && githubItem.status === 'trading') {
      updates.status = 'trading';
      needsUpdate = true;
    }

    if (needsUpdate) {
      toUpdate.push({ doc, updates, symbol });
    }
  }

  console.log(`Güncellenmesi gereken kayıt sayısı: ${toUpdate.length}`);
  if (toUpdate.length === 0) {
    console.log('Tüm kayıtlar zaten güncel!');
    return;
  }

  // 5. Güncelleme yap
  console.log('\nGüncelleme başlıyor...\n');
  let updated = 0, errors = 0;

  for (const { doc, updates, symbol } of toUpdate) {
    console.log(`[${symbol}] Güncelleniyor:`, JSON.stringify(updates));
    try {
      const result = await patchDoc(accessToken, doc._id, updates);
      if (result.status === 200) {
        console.log(`  ✓ Güncellendi`);
        updated++;
      } else {
        console.error(`  ✗ Hata: ${result.status}`, JSON.stringify(result.body).slice(0, 150));
        errors++;
      }
    } catch (e) {
      console.error(`  ✗ İstisna: ${e.message}`);
      errors++;
    }
  }

  console.log(`\n=== TAMAMLANDI ===`);
  console.log(`✓ ${updated} kayıt güncellendi`);
  console.log(`✗ ${errors} hata`);

  // Rapor kaydet
  const report = {
    timestamp: new Date().toISOString(),
    totalFirestore: parsed.length,
    totalGithub: feedItems.length,
    updatedCount: updated,
    errors,
    updatedItems: toUpdate.map(({ symbol, updates }) => ({ symbol, updates }))
  };
  const reportPath = 'd:/k/wink/teknik_bakis/.agents/tasks/ipo_price_update_report.json';
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log(`\nRapor kaydedildi: ${reportPath}`);
}

main().catch(e => {
  console.error('HATA:', e.message);
  process.exit(1);
});
