const admin = require('../../functions/node_modules/firebase-admin');

admin.initializeApp({ credential: admin.credential.applicationDefault() });
const db = admin.firestore();

async function main() {
  // Önce toplam sayıyı ve status dağılımını görelim
  const snap = await db.collection('ipo_items').get();
  console.log('Toplam kayıt:', snap.size);

  const statusCounts = {};
  const noDateCount = { noRequestStart: 0, noPublishedAt: 0, noAnyDate: 0 };
  const samples = { upcoming: [], pendingListing: [] };

  snap.docs.forEach(doc => {
    const d = doc.data();
    const status = d.status || 'unknown';
    statusCounts[status] = (statusCounts[status] || 0) + 1;

    if (!d.requestStart) noDateCount.noRequestStart++;
    if (!d.publishedAt) noDateCount.noPublishedAt++;
    if (!d.requestStart && !d.requestEnd && !d.listingDate && !d.publishedAt && !d.createdAt) {
      noDateCount.noAnyDate++;
    }

    if ((status === 'upcoming' || status === 'yaklasan' || status === 'yaklaşan') && samples.upcoming.length < 3) {
      samples.upcoming.push({ id: doc.id, ...d });
    }
    if ((status === 'listeleme_bekliyor' || status === 'pending_listing' || status === 'pendingListing' || status === 'listeleme bekliyor') && samples.pendingListing.length < 5) {
      samples.pendingListing.push({ id: doc.id, ...d });
    }
  });

  console.log('Status dağılımı:', JSON.stringify(statusCounts, null, 2));
  console.log('Tarih eksik istatistikleri:', JSON.stringify(noDateCount, null, 2));
  console.log('Örnek upcoming kayıtlar:', JSON.stringify(samples.upcoming, null, 2));
  console.log('Örnek pendingListing kayıtlar:', JSON.stringify(samples.pendingListing, null, 2));
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
