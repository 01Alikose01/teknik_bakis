/**
 * Firebase Admin SDK ile Firestore ipo_items güncellemesi
 * Çalıştırma: node .agents/tasks/update_ipo_admin.js
 */

const admin = require('../../functions/node_modules/firebase-admin');
const fs = require('fs');

// Firebase tools'dan refresh token ile credential oluştur
function getFirebaseCredential() {
  const configPath = process.env.USERPROFILE + '/.config/configstore/firebase-tools.json';
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const tokens = config.tokens || {};
  if (!tokens.refresh_token) throw new Error('refresh_token bulunamadı');
  return admin.credential.refreshToken({
    type: 'authorized_user',
    client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: tokens.client_secret || '',
    refresh_token: tokens.refresh_token,
  });
}

// Önce applicationDefault dene, olmazsa refreshToken ile dene
let credential;
try {
  credential = admin.credential.applicationDefault();
} catch (e) {
  console.log('applicationDefault yok, refreshToken deniyor...');
  credential = getFirebaseCredential();
}

admin.initializeApp({ credential });
const db = admin.firestore();

// GitHub ipo_feed.json'dan alınan güncel veri (2026-10-10T11:36:01)
const GITHUB_FEED = [
  { symbol: 'NETGL',  price: '25,52 TL',  lot: '87.500.000 Lot',   distributionType: 'Eşit Dağıtım',    status: 'trading', requestStart: '2026-09-09T12:00:00.000Z', requestEnd: '2026-09-11T12:00:00.000Z', listingDate: '2026-09-17T12:00:00.000Z' },
  { symbol: 'BKRGY',  price: '12,93 TL',  lot: '167.000.000 Lot',  distributionType: 'Eşit Dağıtım',    status: 'trading', requestStart: '2026-08-24T12:00:00.000Z', requestEnd: '2026-08-26T12:00:00.000Z', listingDate: '2026-09-02T12:00:00.000Z' },
  { symbol: 'INTET',  price: '53,60 TL',  lot: '40.000.000 Lot',   distributionType: 'Eşit Dağıtım',    status: 'trading', requestStart: '2026-08-26T12:00:00.000Z', requestEnd: '2026-08-27T12:00:00.000Z', listingDate: '2026-09-01T12:00:00.000Z' },
  { symbol: 'KPEKS',  price: '94,00 TL',  lot: '25.100.000 Lot',   distributionType: 'Eşit Dağıtım',    status: 'trading', requestStart: '2026-08-12T12:00:00.000Z', requestEnd: '2026-08-14T12:00:00.000Z', listingDate: '2026-08-21T12:00:00.000Z' },
  { symbol: 'VEYAS',  price: '136,00 TL', lot: '65.000.000 Lot',   distributionType: 'Eşit Dağıtım',    status: 'trading', requestStart: '2026-08-12T12:00:00.000Z', requestEnd: '2026-08-14T12:00:00.000Z', listingDate: '2026-08-20T12:00:00.000Z' },
  { symbol: 'TKNKA',  price: '85,40 TL',  lot: '31.000.000 Lot',   distributionType: 'Eşit Dağıtım',    status: 'trading', requestStart: '2026-08-12T12:00:00.000Z', requestEnd: '2026-08-14T12:00:00.000Z', listingDate: '2026-08-20T12:00:00.000Z' },
  { symbol: 'CITAS',  price: '73,70 TL',  lot: '36.500.000 Lot',   distributionType: 'Eşit Dağıtım',    status: 'trading', requestStart: '2026-08-10T12:00:00.000Z', requestEnd: '2026-08-12T12:00:00.000Z', listingDate: '2026-08-18T12:00:00.000Z' },
  { symbol: 'QUICK',  price: '76,60 TL',  lot: '135.000.000 Lot',  distributionType: 'Eşit Dağıtım',    status: 'trading', requestStart: '2026-07-29T00:00:00.000Z', requestEnd: '2026-07-31T00:00:00.000Z', listingDate: '2026-08-06T09:00:00.000Z' },
  { symbol: 'KARCL',  price: '35,00 TL',  lot: '128.000.000 Lot',  distributionType: 'Eşit Dağıtım',    status: 'trading', requestStart: '2026-07-22T00:00:00.000Z', requestEnd: '2026-07-24T00:00:00.000Z', listingDate: '2026-07-29T00:00:00.000Z' },
  { symbol: 'MASFN',  price: '45,68 TL',  lot: '85.000.000 Lot',   distributionType: 'Oransal Dağıtım', status: 'trading', requestStart: '2026-07-22T00:00:00.000Z', requestEnd: '2026-07-24T00:00:00.000Z', listingDate: '2026-07-29T00:00:00.000Z' },
  { symbol: 'ALBTN',  price: '38,60 TL',  lot: '70.000.000 Lot',   distributionType: 'Eşit Dağıtım',    status: 'trading', requestStart: '2026-07-22T00:00:00.000Z', requestEnd: '2026-07-23T00:00:00.000Z', listingDate: '2026-07-29T00:00:00.000Z' },
  { symbol: 'METEN',  price: '20,00 TL',  lot: '135.579.000 Lot',  distributionType: 'Eşit Dağıtım',    status: 'trading', requestStart: '2026-07-20T00:00:00.000Z', requestEnd: '2026-07-22T00:00:00.000Z', listingDate: '2026-07-28T00:00:00.000Z' },
  { symbol: 'SARAE',  price: '70,00 TL',  lot: '89.000.000 Lot',   distributionType: 'Oransal Dağıtım', status: 'trading', requestStart: '2026-07-08T00:00:00.000Z', requestEnd: '2026-07-10T00:00:00.000Z', listingDate: '2026-07-17T00:00:00.000Z' },
  { symbol: 'SSAAT',  price: '56,00 TL',  lot: '80.334.000 Lot',   distributionType: 'Eşit Dağıtım',    status: 'trading', requestStart: '2026-07-06T00:00:00.000Z', requestEnd: '2026-07-08T00:00:00.000Z', listingDate: '2026-07-15T00:00:00.000Z' },
  { symbol: 'EKIM',   price: '30,26 TL',  lot: '162.000.000 Lot',  distributionType: 'Eşit Dağıtım',    status: 'trading', requestStart: '2026-07-01T00:00:00.000Z', requestEnd: '2026-07-03T00:00:00.000Z', listingDate: '2026-07-10T00:00:00.000Z' },
  { symbol: 'ISVEA',  price: '20,90 TL',  lot: '67.000.000 Lot',   distributionType: 'Eşit Dağıtım',    status: 'trading', requestStart: '2026-07-01T00:00:00.000Z', requestEnd: '2026-07-03T00:00:00.000Z', listingDate: '2026-07-09T00:00:00.000Z' },
  { symbol: 'GOLDA',  price: '9,20 TL',   lot: '87.500.000 Lot',   distributionType: 'Oransal Dağıtım', status: 'trading', requestStart: '2026-07-01T00:00:00.000Z', requestEnd: '2026-07-02T00:00:00.000Z', listingDate: '2026-07-09T00:00:00.000Z' },
  { symbol: 'SOHOE',  price: '15,00 TL',  lot: '100.000.000 Lot',  distributionType: 'Eşit Dağıtım',    status: 'trading', requestStart: '2026-06-30T00:00:00.000Z', requestEnd: '2026-07-01T00:00:00.000Z', listingDate: '2026-07-08T00:00:00.000Z' },
  { symbol: 'ORZAX',  price: '69,00 TL',  lot: '55.000.000 Lot',   distributionType: 'Oransal Dağıtım', status: 'trading', requestStart: '2026-06-29T00:00:00.000Z', requestEnd: '2026-07-01T00:00:00.000Z', listingDate: '2026-07-07T00:00:00.000Z' },
  { symbol: 'BETAE',  price: '40,00 TL',  lot: '60.750.000 Lot',   distributionType: 'Eşit Dağıtım',    status: 'trading', requestStart: '2026-06-23T12:00:00.000Z', requestEnd: '2026-06-25T12:00:00.000Z', listingDate: '2026-07-01T12:00:00.000Z' },
  { symbol: 'EKDMR',  price: '45,00 TL',  lot: '52.000.000 Lot',   distributionType: 'Eşit Dağıtım',    status: 'trading', requestStart: '2026-05-13T12:00:00.000Z', requestEnd: '2026-05-15T12:00:00.000Z', listingDate: '2026-05-22T12:00:00.000Z' },
  // ENPRA: kısmi bölünme, fiyat/lot yok — güncelleme yapma
  // BEWEN: ertelendi
];

function isMissing(val) {
  return !val || val.trim() === '' || val.trim() === '-';
}

function toTimestamp(isoStr) {
  if (!isoStr) return null;
  try { return admin.firestore.Timestamp.fromDate(new Date(isoStr)); } 
  catch (e) { return null; }
}

async function main() {
  console.log('=== IPO Fiyat/Lot/Dağıtım Güncelleme (Admin SDK) ===\n');

  const snap = await db.collection('ipo_items').get();
  console.log(`Firestore'da toplam ${snap.size} kayıt\n`);

  // Firestore doc id → doc data map
  const fsMap = {};
  snap.docs.forEach(doc => { fsMap[doc.id.toUpperCase()] = { id: doc.id, data: doc.data() }; });

  // GitHub feed → Firestore map
  const githubMap = {};
  GITHUB_FEED.forEach(item => { githubMap[item.symbol.toUpperCase()] = item; });

  let updated = 0, skipped = 0, errors = 0;
  const report = [];

  for (const githubItem of GITHUB_FEED) {
    const sym = githubItem.symbol.toUpperCase();
    const fsEntry = fsMap[sym];

    if (!fsEntry) {
      console.log(`[${sym}] Firestore'da bulunamadı — atlanıyor`);
      skipped++;
      continue;
    }

    const fsData = fsEntry.data;
    const updates = {};
    const changes = [];

    // price
    if (isMissing(fsData.price) && !isMissing(githubItem.price)) {
      updates.price = githubItem.price;
      changes.push(`price: ${githubItem.price}`);
    }

    // lot
    if (isMissing(fsData.lot) && !isMissing(githubItem.lot)) {
      updates.lot = githubItem.lot;
      changes.push(`lot: ${githubItem.lot}`);
    }

    // distributionType
    if (isMissing(fsData.distributionType) && !isMissing(githubItem.distributionType)) {
      updates.distributionType = githubItem.distributionType;
      changes.push(`distributionType: ${githubItem.distributionType}`);
    }

    // status → trading (eğer değilse)
    const fsStatus = (fsData.status || '').toLowerCase();
    if (fsStatus !== 'trading' && fsStatus !== 'ertelendi' && fsStatus !== 'postponed') {
      updates.status = 'trading';
      changes.push(`status: ${fsData.status} → trading`);
    }

    // listingDate (Timestamp yoksa)
    if (!fsData.listingDate && githubItem.listingDate) {
      const ts = toTimestamp(githubItem.listingDate);
      if (ts) { updates.listingDate = ts; changes.push(`listingDate: ${githubItem.listingDate}`); }
    }

    // requestStart
    if (!fsData.requestStart && githubItem.requestStart) {
      const ts = toTimestamp(githubItem.requestStart);
      if (ts) { updates.requestStart = ts; changes.push(`requestStart: ${githubItem.requestStart}`); }
    }

    // requestEnd
    if (!fsData.requestEnd && githubItem.requestEnd) {
      const ts = toTimestamp(githubItem.requestEnd);
      if (ts) { updates.requestEnd = ts; changes.push(`requestEnd: ${githubItem.requestEnd}`); }
    }

    if (Object.keys(updates).length === 0) {
      console.log(`[${sym}] Zaten güncel — atlanıyor`);
      skipped++;
      continue;
    }

    try {
      await db.collection('ipo_items').doc(fsEntry.id).update(updates);
      console.log(`[${sym}] ✓ Güncellendi: ${changes.join(', ')}`);
      updated++;
      report.push({ symbol: sym, changes });
    } catch (e) {
      console.error(`[${sym}] ✗ Hata: ${e.message}`);
      errors++;
    }
  }

  console.log(`\n=== TAMAMLANDI ===`);
  console.log(`✓ ${updated} kayıt güncellendi`);
  console.log(`- ${skipped} atlandı (zaten güncel veya bulunamadı)`);
  console.log(`✗ ${errors} hata`);

  fs.writeFileSync(
    'd:/k/wink/teknik_bakis/.agents/tasks/ipo_price_update_report.json',
    JSON.stringify({ timestamp: new Date().toISOString(), updated, skipped, errors, report }, null, 2)
  );
  console.log('\nRapor kaydedildi: ipo_price_update_report.json');
}

main()
  .then(() => process.exit(0))
  .catch(e => { console.error('FATAL:', e.message); process.exit(1); });
