/**
 * Firebase Cloud Function ÔÇö KAP Bildirim + Temel G├Âstergeler G├╝ncelleyici
 *
 * ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
 * KAP MKK B─░LD─░R─░M SYNC S─░STEM─░
 *
 * MKK VYK API'sinden KAP bildirimlerini merkezi olarak ├ğeker.
 * Flutter uygulamas─▒ KAP API'ye H─░├çB─░R ZAMAN direkt ba─şlanmaz.
 * API credentials sadece Cloud Function environment'─▒nda tutulur.
 * 1000+ kullan─▒c─▒ Firestore'dan okur ÔåÆ KAP/MKK API'ye tek istek biz atar─▒z.
 *
 * Zamanlama stratejisi (T├╝rkiye saati = UTC+3):
 *
 *   syncKapOpeningWindow  ÔÇö Her g├╝n 06:55ÔÇô07:30 UTC (09:55ÔÇô10:30 TR)
 *                           Her 5 dakikada bir ÔåÆ borsa a├ğ─▒l─▒┼ş verilerini h─▒zl─▒ yakalar
 *                           cron: 55 6 * * *        ÔåÆ 09:55 TR
 *                                 0,5,10,15,20,25,30 7 * * *  ÔåÆ 10:00ÔÇô10:30 TR
 *
 *   syncKapDisclosures    ÔÇö Her g├╝n s├╝rekli, 15 dakikada bir (t├╝m g├╝n)
 *                           cron: '* /15 * * * *' ÔåÆ g├╝nde 96x ├ğal─▒┼ş─▒r
 *                           A├ğ─▒l─▒┼ş penceresi d─▒┼ş─▒ndaki saatleri kapsar.
 *                           openingWindow zaten 09:55ÔÇô10:30 aras─▒ daha s─▒k ├ğal─▒┼ş─▒r,
 *                           15dk'l─▒k genel sync onlar─▒ da kapsad─▒─ş─▒ i├ğin
 *                           ikisi birlikte ├ğal─▒┼şmak sorun de─şil (idempotent UPSERT).
 *
 * Firestore yap─▒s─▒:
 *   kap_members/{id}         ÔÇö ┼Şirket listesi
 *   kap_disclosures/{index}  ÔÇö Bildirimler (UPSERT)
 *   kap_sync_logs/{id}       ÔÇö Sync loglar─▒
 *   meta/kap                 ÔÇö Son sync zaman─▒, lastDisclosureIndex
 *
 * Environment Variables (Firebase Secret Manager'dan okunur):
 *   KAP_API_KEY  ÔÇö MKK VYK API anahtar─▒
 *   KAP_TOKEN    ÔÇö MKK VYK Bearer token
 *
 * KAP API base URL: https://apigwdev.mkk.com.tr/api/vyk/
 * ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
 */

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest }  = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp }  = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const https = require('https');

initializeApp();
const db = getFirestore();

// ÔöÇÔöÇ KAP API Secrets (Firebase Secret Manager) ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
const KAP_API_KEY  = defineSecret('KAP_API_KEY');
const KAP_TOKEN    = defineSecret('KAP_TOKEN');
const ADMIN_SECRET = defineSecret('ADMIN_SECRET'); // Manuel sync korumas─▒
const NVIDIA_API_KEY = defineSecret('NVIDIA_API_KEY'); // NVIDIA NIM AI API

// ÔöÇÔöÇ KAP API base ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
const KAP_BASE = 'https://apigwdev.mkk.com.tr/api/vyk';

// ÔöÇÔöÇ Retry yap─▒land─▒rmas─▒ ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
const RETRY_DELAYS_MS = [0, 30_000, 120_000]; // an─▒nda, 30s, 2dk

// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// YARDIMCI FONKS─░YONLAR
// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

/** HTTPS GET ile JSON ├ğeker. apiKey ve token parametrelerini header'a ekler. */
function kapGet(path, apiKey, token, queryParams = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(`${KAP_BASE}${path}`);
    for (const [k, v] of Object.entries(queryParams)) {
      if (v !== undefined && v !== null && v !== '') {
        url.searchParams.set(k, String(v));
      }
    }

    const options = {
      hostname: url.hostname,
      path: url.pathname + url.search,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
        'X-Api-Key':     apiKey,
        'Accept':        'application/json',
        'Content-Type':  'application/json',
      },
      timeout: 20000,
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          try { resolve(JSON.parse(body)); }
          catch (e) { reject(new Error(`JSON parse hatas─▒ (${path}): ${e.message}`)); }
        } else {
          reject(new Error(`HTTP ${res.statusCode} ÔÇö ${path} ÔÇö ${body.substring(0, 200)}`));
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error(`Timeout: ${path}`)); });
    req.end();
  });
}

/** BilancoVeri i├ğin genel JSON fetch (credentials gerektirmez). */
function fetchJson(url) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, {
      headers: { 'User-Agent': 'TeknikBakis-Backend/1.0', 'Accept': 'application/json' },
      timeout: 10000,
    }, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(body)); }
        catch (e) { reject(new Error('JSON parse hatas─▒: ' + e.message)); }
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('Timeout')); });
  });
}

/** Retry wrapper ÔÇö otomatik yeniden deneme. */
async function withRetry(fn, label) {
  let lastErr;
  for (let attempt = 0; attempt < RETRY_DELAYS_MS.length; attempt++) {
    if (attempt > 0) {
      console.log(`${label} ÔÇö ${attempt}. yeniden deneme (${RETRY_DELAYS_MS[attempt] / 1000}s sonra)...`);
      await new Promise(r => setTimeout(r, RETRY_DELAYS_MS[attempt]));
    }
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      console.warn(`${label} ÔÇö deneme ${attempt + 1} ba┼şar─▒s─▒z:`, err.message);
    }
  }
  throw lastErr;
}

// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// KAP ┼Ş─░RKET L─░STES─░ SYNC
// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

async function syncMembers(apiKey, token) {
  console.log('┼Şirket listesi senkronizasyonu ba┼şlad─▒...');
  const data = await kapGet('/members', apiKey, token);

  // API dizi d├Ând├╝rebilir veya { data: [...] } format─▒nda olabilir
  const members = Array.isArray(data) ? data : (data.data || data.items || data.members || []);
  if (members.length === 0) throw new Error('┼Şirket listesi bo┼ş geldi');

  console.log(`${members.length} ┼şirket al─▒nd─▒`);

  // Duplicate temizleme: ayn─▒ id i├ğin kfifUrl olan kayd─▒ tercih et
  const byId = new Map();
  for (const m of members) {
    const id = String(m.id || m.memberId || '');
    if (!id) continue;
    const existing = byId.get(id);
    if (!existing || (!existing.kfifUrl && m.kfifUrl)) {
      byId.set(id, m);
    }
  }

  // Batch write
  const BATCH_SIZE = 400;
  const entries = [...byId.entries()];
  let written = 0;

  for (let i = 0; i < entries.length; i += BATCH_SIZE) {
    const chunk = entries.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const [id, m] of chunk) {
      const ref = db.collection('kap_members').doc(id);
      batch.set(ref, {
        id:          id,
        title:       m.title || m.name || '',
        stockCode:   (m.stockCode || m.code || '').toUpperCase(),
        memberType:  m.memberType || m.type || '',
        kfifUrl:     m.kfifUrl || '',
        updatedAt:   FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    await batch.commit();
    written += chunk.length;
  }

  console.log(`┼Şirket listesi tamamland─▒: ${written} kay─▒t`);
  return written;
}

// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// KAP B─░LD─░R─░MLER SYNC
// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

async function getLastDisclosureIndex() {
  try {
    const doc = await db.collection('meta').doc('kap').get();
    return doc.exists ? (doc.data().lastDisclosureIndex || 0) : 0;
  } catch (_) { return 0; }
}

async function setLastDisclosureIndex(index) {
  await db.collection('meta').doc('kap').set({
    lastDisclosureIndex: index,
    lastSyncAt: FieldValue.serverTimestamp(),
  }, { merge: true });
}

async function syncDisclosures(apiKey, token) {
  // Son bildirim index'ini al
  const lastIndex = await getLastDisclosureIndex();

  // ├ûnce mevcut son index'i KAP'tan ├Â─şren
  let currentMaxIndex;
  try {
    const latestData = await kapGet('/lastDisclosureIndex', apiKey, token);
    currentMaxIndex = latestData.lastDisclosureIndex || latestData.index || latestData;
    console.log(`Son bildirim index: ${currentMaxIndex}, son sync index: ${lastIndex}`);
  } catch (err) {
    console.warn('lastDisclosureIndex al─▒namad─▒, t├╝m yeni bildirimleri ├ğekmeye devam:', err.message);
    currentMaxIndex = null;
  }

  // E─şer de─şi┼şiklik yoksa atla
  if (currentMaxIndex && Number(currentMaxIndex) <= Number(lastIndex)) {
    console.log('Yeni bildirim yok, sync atland─▒');
    return { added: 0, updated: 0 };
  }

  // Yeni bildirimleri ├ğek ÔÇö lastIndex'ten sonras─▒n─▒ al
  const queryParams = {
    disclosureIndex: lastIndex > 0 ? lastIndex : undefined,
  };

  const data = await kapGet('/disclosures', apiKey, token, queryParams);
  const disclosures = Array.isArray(data) ? data : (data.data || data.items || data.disclosures || []);

  if (disclosures.length === 0) {
    console.log('Yeni bildirim bulunamad─▒');
    return { added: 0, updated: 0 };
  }

  console.log(`${disclosures.length} bildirim al─▒nd─▒`);

  // Batch UPSERT
  const BATCH_SIZE = 400;
  let added = 0, updated = 0;
  let maxIndexSeen = Number(lastIndex);

  for (let i = 0; i < disclosures.length; i += BATCH_SIZE) {
    const chunk = disclosures.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const d of chunk) {
      const discIdx = String(d.disclosureIndex || d.id || '');
      if (!discIdx) continue;

      const numIdx = Number(discIdx);
      if (numIdx > maxIndexSeen) maxIndexSeen = numIdx;

      const ref = db.collection('kap_disclosures').doc(discIdx);
      const existing = (await ref.get()).exists;

      batch.set(ref, {
        disclosure_id:      discIdx,
        company_id:         String(d.companyId || d.memberId || ''),
        stock_code:         (d.stockCode || d.code || '').toUpperCase(),
        company_title:      d.title || d.companyName || d.companyTitle || '',
        publish_date:       d.publishDate || d.date || '',
        publish_time:       d.publishTime || d.time || '',
        subject:            d.subject || d.disclosureClass || '',
        summary:            d.summary || d.description || '',
        disclosure_type:    d.disclosureType || d.type || '',
        related_companies:  d.relatedCompanies || [],
        year:               d.year || '',
        period:             d.period || '',
        detail_url:         d.detailUrl || (discIdx ? `https://www.kap.org.tr/tr/Bildirim/${discIdx}` : ''),
        attachment_url:     d.attachmentUrl || d.fileUrl || '',
        raw_data:           d,
        created_at:         existing ? FieldValue.serverTimestamp() : FieldValue.serverTimestamp(),
        updated_at:         FieldValue.serverTimestamp(),
      }, { merge: true }); // UPSERT

      if (existing) updated++; else added++;
    }

    await batch.commit();
  }

  // Son index'i kaydet
  if (maxIndexSeen > Number(lastIndex)) {
    await setLastDisclosureIndex(maxIndexSeen);
  }

  console.log(`Bildirim sync tamamland─▒: ${added} yeni, ${updated} g├╝ncellendi`);
  return { added, updated };
}

// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// SYNC LOG
// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

async function writeSyncLog(status, details) {
  try {
    await db.collection('kap_sync_logs').add({
      started_at:      details.startedAt || FieldValue.serverTimestamp(),
      finished_at:     FieldValue.serverTimestamp(),
      status:          status,          // 'success' | 'failed' | 'partial'
      records_added:   details.added   || 0,
      records_updated: details.updated || 0,
      error_message:   details.error   || null,
      trigger:         details.trigger || 'scheduled',
    });
  } catch (err) {
    console.error('Sync log yaz─▒lamad─▒:', err.message);
  }
}

// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// ANA SYNC FONKS─░YONU
// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

async function runKapSync(apiKey, token, trigger = 'scheduled') {
  const startedAt = new Date();
  console.log(`KAP sync ba┼şlad─▒ [${trigger}]:`, startedAt.toISOString());

  let syncResult = { added: 0, updated: 0 };
  let syncError  = null;

  try {
    // ┼Şirket listesi (g├╝nde 1 kez yeterli, sabah sync'te yap─▒l─▒r)
    if (trigger === 'scheduled' || trigger === 'manual') {
      await withRetry(() => syncMembers(apiKey, token), 'syncMembers');
    }

    // Bildirimler
    syncResult = await withRetry(() => syncDisclosures(apiKey, token), 'syncDisclosures');

    // Meta g├╝ncelle
    await db.collection('meta').doc('kap').set({
      lastSuccessfulSync: FieldValue.serverTimestamp(),
      lastSyncStatus:     'success',
    }, { merge: true });

  } catch (err) {
    syncError = err.message;
    console.error('KAP sync hatas─▒:', err.message);

    await db.collection('meta').doc('kap').set({
      lastSyncStatus: 'failed',
      lastSyncError:  err.message,
    }, { merge: true });
  }

  await writeSyncLog(
    syncError ? 'failed' : 'success',
    { ...syncResult, error: syncError, startedAt, trigger },
  );

  if (syncError) throw new Error(syncError);
  return syncResult;
}

// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// SCHEDULED FUNCTION 1 ÔÇö A├ğ─▒l─▒┼ş Penceresi: 09:55ÔÇô10:30 T├╝rkiye (UTC+3)
//
//   Her 5 dakikada bir ├ğal─▒┼ş─▒r, borsa a├ğ─▒l─▒┼ş─▒nda bildirimleri h─▒zl─▒ yakalar.
//   T├╝rkiye 09:55 = UTC 06:55  ÔåÆ  cron: 55 6 * * *
//   T├╝rkiye 10:00ÔÇô10:30        ÔåÆ  cron: 0,5,10,15,20,25,30 7 * * *
//
//   1000+ kullan─▒c─▒ varken bile KAP/MKK API'ye tek istek biz atar─▒z,
//   kullan─▒c─▒lar Firestore'dan okur ÔåÆ rate-limit veya block riski s─▒f─▒r.
// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

// 09:55 TR (UTC 06:55) ÔÇö a├ğ─▒l─▒┼ş ├Âncesi son haz─▒rl─▒k
exports.syncKapOpeningPre = onSchedule({
  schedule:       '55 6 * * *',
  timeZone:       'UTC',
  region:         'europe-west1',
  memory:         '512MiB',
  timeoutSeconds: 300,
  secrets:        [KAP_API_KEY, KAP_TOKEN],
}, async () => {
  const apiKey = KAP_API_KEY.value();
  const token  = KAP_TOKEN.value();
  await runKapSync(apiKey, token, 'opening-pre');
});

// 10:00, 10:05, 10:10, 10:15, 10:20, 10:25, 10:30 TR (UTC 07:xx) ÔÇö a├ğ─▒l─▒┼ş penceresi
exports.syncKapOpeningWindow = onSchedule({
  schedule:       '0,5,10,15,20,25,30 7 * * *',
  timeZone:       'UTC',
  region:         'europe-west1',
  memory:         '512MiB',
  timeoutSeconds: 300,
  secrets:        [KAP_API_KEY, KAP_TOKEN],
}, async () => {
  const apiKey = KAP_API_KEY.value();
  const token  = KAP_TOKEN.value();
  await runKapSync(apiKey, token, 'opening-window');
});

// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// SCHEDULED FUNCTION 2 ÔÇö S├╝rekli Sync: Her 15 dakikada bir (t├╝m g├╝n)
//
//   A├ğ─▒l─▒┼ş penceresi d─▒┼ş─▒ndaki t├╝m seans─▒ ve g├╝n i├ği bildirimleri yakalar.
//   A├ğ─▒l─▒┼ş penceresiyle ├ğak─▒┼şsa da UPSERT idempotent oldu─şu i├ğin sorun yok.
//   G├╝nde 96 ├ğal─▒┼ş─▒r; Firestore yazma maliyeti ihmal edilebilir seviyede.
// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

exports.syncKapDisclosures = onSchedule({
  schedule:       '*/15 * * * *',
  timeZone:       'UTC',
  region:         'europe-west1',
  memory:         '512MiB',
  timeoutSeconds: 300,
  secrets:        [KAP_API_KEY, KAP_TOKEN],
}, async () => {
  const apiKey = KAP_API_KEY.value();
  const token  = KAP_TOKEN.value();
  await runKapSync(apiKey, token, 'scheduled');
});

// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// MANUEL SYNC ÔÇö Sadece admin yetkisiyle
// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

exports.syncKapManual = onRequest({
  region:  'europe-west1',
  memory:  '512MiB',
  timeoutSeconds: 300,
  secrets: [KAP_API_KEY, KAP_TOKEN, ADMIN_SECRET],
}, async (req, res) => {
  // Admin do─şrulama ÔÇö secret de─şerini trim et (echo'dan gelen \n)
  const adminSecret = ADMIN_SECRET.value().trim();
  const provided    = (req.headers['x-admin-secret'] || req.query.secret || '').trim();
  if (!adminSecret || provided !== adminSecret) {
    res.status(403).json({ error: 'Unauthorized' });
    return;
  }

  try {
    const apiKey = KAP_API_KEY.value();
    const token  = KAP_TOKEN.value();
    const result = await runKapSync(apiKey, token, 'manual');
    res.json({ success: true, ...result });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// BilancoVeri ÔÇö Temel G├Âstergeler (mevcut, de─şi┼şmedi)
// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

async function fetchAllFundamentals() {
  const url = 'https://bilancoveri.com/api/v1/sirketler.json';
  const data = await fetchJson(url);
  return data.companies || data.items || [];
}

async function writeBatch(items) {
  const BATCH_SIZE = 400;
  let written = 0;
  for (let i = 0; i < items.length; i += BATCH_SIZE) {
    const chunk = items.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const item of chunk) {
      const ticker = (item.ticker || '').toUpperCase();
      if (!ticker) continue;
      const ref = db.collection('fundamentals').doc(ticker);
      batch.set(ref, {
        pe:                toNum(item.pe),
        pb:                toNum(item.pb),
        ev_ebitda:         toNum(item.ev_ebitda),
        roe:               toNum(item.roe),
        roa:               toNum(item.roa),
        dividend_yield:    toNum(item.dividend_yield),
        float_ratio:       toNum(item.float_ratio),
        market_cap_mn_try: toNum(item.market_cap_mn_try),
        name:              item.name || ticker,
        sector:            item.sector || '',
        updatedAt:         FieldValue.serverTimestamp(),
        source:            'BilancoVeri/KAP',
      }, { merge: true });
    }
    await batch.commit();
    written += chunk.length;
    console.log(`Yaz─▒ld─▒: ${written}/${items.length}`);
  }
}

function toNum(val) {
  if (val === null || val === undefined) return 0;
  const n = parseFloat(val);
  return isNaN(n) ? 0 : n;
}

exports.updateFundamentals = onSchedule({
  schedule: '0 5,9,15 * * *',
  timeZone: 'UTC',
  region:   'europe-west1',
  memory:   '256MiB',
  timeoutSeconds: 120,
}, async () => {
  try {
    const items = await fetchAllFundamentals();
    if (items.length === 0) { console.warn('Veri bo┼ş geldi'); return; }
    await writeBatch(items);
    await db.collection('meta').doc('fundamentals').set({
      lastUpdatedAt: FieldValue.serverTimestamp(),
      tickerCount:   items.length,
      source:        'BilancoVeri/KAP',
    });
  } catch (err) { console.error('G├╝ncelleme hatas─▒:', err); throw err; }
});

exports.updateFundamentalsManual = require('firebase-functions').https.onRequest(
  async (req, res) => {
    try {
      const items = await fetchAllFundamentals();
      await writeBatch(items);
      res.json({ success: true, count: items.length });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  }
);

// ÔöÇÔöÇ Yard─▒mc─▒: HTTPS GET ÔåÆ JSON ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
function fetchJson(url) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, {
      headers: { 'User-Agent': 'TeknikBakis-Backend/1.0', 'Accept': 'application/json' },
      timeout: 10000,
    }, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(body)); }
        catch (e) { reject(new Error('JSON parse hatas─▒: ' + e.message)); }
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('Timeout')); });
  });
}

// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// HALKA ARZ (IPO) SYNC ÔÇö HalkArz.com ÔåÆ Firestore
//
// De─şi┼şiklikler (v2):
//  - T├╝m sayfa linkleri takip edilerek 50'ye kadar hisse ├ğekilir (pagination)
//  - HTML selector'lar─▒ daha esnek: birden fazla class/yap─▒ desteklenir
//  - Tarih ayr─▒┼şt─▒rma: "30 Haziran, 1 Temmuz" format─▒ da i┼şlenir
//  - Tarih s─▒n─▒r─▒ ge├ğmi┼ş kay─▒tlar Firestore'da otomatik "trading" yap─▒l─▒r
//  - Hata tolerans─▒: tek hisse ba┼şar─▒s─▒z olursa di─şerleri etkilenmez
//
// Firestore yap─▒s─▒:
//   ipo_items/{symbol}   ÔÇö Her hisse bir belge (sembols├╝zler companyName hash)
//   ipo_meta/feed        ÔÇö lastUpdated, itemCount, source
// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

const HALKARZ_UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36';

/** T├╝rk├ğe ay ad─▒ ÔåÆ 0-bazl─▒ ay indeksi */
const TR_MONTHS = {
  ocak:0, subat:1, ┼şubat:1, mart:2, nisan:3, mayis:4, may─▒s:4, haziran:5,
  temmuz:6, agustos:7, a─şustos:7, eylul:8, eyl├╝l:8, ekim:9, kasim:10, kas─▒m:10, aralik:11, aral─▒k:11,
};

/** HTML tag'lar─▒n─▒ temizler ve bo┼şluklar─▒ normalize eder */
function cleanTxt(v) {
  return v == null ? '' : String(v).replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
}

/** Date ÔåÆ ISO 8601 string; ge├ğersizse '' */
function toIso(date) {
  return (date instanceof Date && !isNaN(date)) ? date.toISOString() : '';
}

/**
 * T├╝rk├ğe tarih metni ÔåÆ { start: Date|null, end: Date|null }
 *
 * Desteklenen formatlar:
 *   "9-10-11 Eyl├╝l 2026"          ÔåÆ 9ÔÇô11 Eyl├╝l
 *   "31 Temmuz - 2 A─şustos 2026"  ÔåÆ 31 Tem ÔÇô 2 A─şu
 *   "30 Haziran, 1 Temmuz 2026"   ÔåÆ 30 Haz ÔÇô 1 Tem
 *   "6 A─şustos 2026"              ÔåÆ tek g├╝n
 *   "29.07.2026 - 31.07.2026"     ÔåÆ ISO-benzeri
 *   "29-31 Temmuz 2026"           ÔåÆ aral─▒k, ayn─▒ ay
 */
function parseTrDateRange(text) {
  const raw = cleanTxt(text);
  if (!raw) return { start: null, end: null };

  // Harfleri normalle┼ştir (b├╝y├╝k/k├╝├ğ├╝k, T├╝rk├ğe ├Âzel)
  const norm = raw.toLowerCase()
    .replace(/─ş/g,'g').replace(/├ğ/g,'c').replace(/┼ş/g,'s')
    .replace(/├╝/g,'u').replace(/├Â/g,'o').replace(/─▒/g,'i');

  // ÔöÇÔöÇ Format 1: "9-10-11 eylul 2026" veya "29-31 temmuz 2026" ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  const m1 = norm.match(/^(\d{1,2})(?:[-,\s]+\d{1,2})*[-,\s]+(\d{1,2})\s+([a-z]+)\s+(\d{4})/);
  if (m1) {
    const mo = TR_MONTHS[m1[3]];
    if (mo !== undefined) {
      const yr = parseInt(m1[4]);
      // ─░lk say─▒y─▒ bul
      const firstDay = parseInt(norm.match(/^(\d{1,2})/)[1]);
      return {
        start: new Date(yr, mo, firstDay, 12, 0, 0),
        end:   new Date(yr, mo, parseInt(m1[2]), 12, 0, 0),
      };
    }
  }

  // ÔöÇÔöÇ Format 2: "31 temmuz - 2 agustos 2026" ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  const m2 = norm.match(/^(\d{1,2})\s+([a-z]+)\s*[-,]\s*(\d{1,2})\s+([a-z]+)\s+(\d{4})/);
  if (m2) {
    const sm = TR_MONTHS[m2[2]], em = TR_MONTHS[m2[4]];
    if (sm !== undefined && em !== undefined) {
      const yr = parseInt(m2[5]);
      return {
        start: new Date(yr, sm, parseInt(m2[1]), 12, 0, 0),
        end:   new Date(yr, em, parseInt(m2[3]), 12, 0, 0),
      };
    }
  }

  // ÔöÇÔöÇ Format 3: "30 haziran, 1 temmuz 2026" (virg├╝ll├╝ ├ğapraz ay) ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  const m3 = norm.match(/^(\d{1,2})\s+([a-z]+)[,\s]+(\d{1,2})\s+([a-z]+)\s+(\d{4})/);
  if (m3) {
    const sm = TR_MONTHS[m3[2]], em = TR_MONTHS[m3[4]];
    if (sm !== undefined && em !== undefined) {
      const yr = parseInt(m3[5]);
      return {
        start: new Date(yr, sm, parseInt(m3[1]), 12, 0, 0),
        end:   new Date(yr, em, parseInt(m3[3]), 12, 0, 0),
      };
    }
  }

  // ÔöÇÔöÇ Format 4: "6 agustos 2026" (tek g├╝n) ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  const m4 = norm.match(/^(\d{1,2})\s+([a-z]+)\s+(\d{4})/);
  if (m4) {
    const mo = TR_MONTHS[m4[2]];
    if (mo !== undefined) {
      const d = new Date(parseInt(m4[3]), mo, parseInt(m4[1]), 12, 0, 0);
      return { start: d, end: d };
    }
  }

  // ÔöÇÔöÇ Format 5: "29.07.2026 - 31.07.2026" veya "29.07.2026" ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  const datePattern = /(\d{1,2})[.\-\/](\d{1,2})[.\-\/](\d{4})/g;
  const dates = [];
  let dm;
  while ((dm = datePattern.exec(raw)) !== null) {
    dates.push(new Date(parseInt(dm[3]), parseInt(dm[2]) - 1, parseInt(dm[1]), 12, 0, 0));
  }
  if (dates.length >= 2) return { start: dates[0], end: dates[dates.length - 1] };
  if (dates.length === 1) return { start: dates[0], end: dates[0] };

  return { start: null, end: null };
}

/**
 * IPO stat├╝s├╝n├╝ BIST varl─▒─ş─▒ ve tarih bilgisine g├Âre hesaplar.
 *
 * ├ûncelik s─▒ras─▒:
 *   1. BIST'te listelenmi┼ş sembol ÔåÆ 'trading'
 *   2. listingDate < now          ÔåÆ 'trading'
 *   3. requestEnd < endOfDay      ÔåÆ 'pending_listing'
 *   4. requestStart <= now        ÔåÆ 'collecting'
 *   5. Aksi h├ólde                 ÔåÆ 'upcoming'
 *
 * @param {{ requestStart, requestEnd, listingDate, symbol, bistSymbols }} params
 * @param {Set<string>} [params.bistSymbols] ÔÇö Firestore bist_stocks koleksiyonundan ├ğekilmi┼ş sembol k├╝mesi
 */
function computeIpoStatus({ requestStart, requestEnd, listingDate, symbol, bistSymbols }) {
  const now = new Date();

  // 1. BIST'te aktif sembol ÔåÆ kesinlikle i┼şlem g├Âr├╝yor
  if (symbol && bistSymbols instanceof Set && bistSymbols.has(symbol.toUpperCase())) {
    return 'trading';
  }

  // 2. Listeleme tarihi ge├ğtiyse ÔåÆ borsada i┼şlem g├Âr├╝yor
  if (listingDate && listingDate <= now) return 'trading';

  // 3. Talep s├╝resi bittiyse ÔåÆ listeleme bekleniyor
  if (requestEnd) {
    const endOfDay = new Date(
      requestEnd.getFullYear(), requestEnd.getMonth(), requestEnd.getDate(), 23, 59, 59,
    );
    if (now > endOfDay) return 'pending_listing';
  }

  // 4. Talep devam ediyor ÔåÆ toplama a┼şamas─▒
  if (requestStart) {
    const startOfDay = new Date(
      requestStart.getFullYear(), requestStart.getMonth(), requestStart.getDate(),
    );
    return now < startOfDay ? 'upcoming' : 'collecting';
  }

  // 5. Listeleme tarihi hen├╝z gelmemi┼ş ama talep tarihi yok
  if (listingDate) {
    const lStart = new Date(
      listingDate.getFullYear(), listingDate.getMonth(), listingDate.getDate(),
    );
    return now < lStart ? 'upcoming' : 'trading';
  }

  return 'upcoming';
}

/**
 * Firestore bist_stocks koleksiyonundan t├╝m sembol ID'lerini bir Set olarak d├Ând├╝r├╝r.
 * Hata durumunda bo┼ş Set d├Âner ÔÇö di─şer durum mant─▒─ş─▒ ├ğal─▒┼şmaya devam eder.
 */
async function loadBistSymbols() {
  try {
    const refs = await db.collection('bist_stocks').listDocuments();
    const symbolSet = new Set(refs.map(r => r.id.toUpperCase()));
    console.log(`loadBistSymbols: ${symbolSet.size} sembol y├╝klendi`);
    return symbolSet;
  } catch (err) {
    console.warn('loadBistSymbols hatas─▒ (bo┼ş Set ile devam):', err.message);
    return new Set();
  }
}

/**
 * HalkArz.com ana sayfas─▒ndan hisse URL'lerini toplar.
 * "Daha Fazla G├Âster" butonu yerine /sayfa/N format─▒ndaki linkleri takip eder.
 * Maksimum maxPages ├ù 10 hisse (varsay─▒lan 5 sayfa = 50 hisse).
 */
async function collectHalkArzUrls(maxPages = 5) {
  const seen   = new Set();
  const items  = [];

  for (let page = 1; page <= maxPages; page++) {
    const url  = page === 1 ? 'https://halkarz.com/' : `https://halkarz.com/page/${page}/`;
    let html;

    try {
      const res = await fetch(url, {
        headers: { 'User-Agent': HALKARZ_UA },
        signal:  AbortSignal.timeout(20000),
      });
      if (!res.ok) {
        // 404 ÔåÆ son sayfa ge├ğildi
        if (res.status === 404) break;
        console.warn(`HalkArz sayfa ${page}: HTTP ${res.status}`);
        break;
      }
      html = await res.text();
    } catch (err) {
      console.warn(`HalkArz sayfa ${page} fetch hatas─▒:`, err.message);
      break;
    }

    // ÔöÇÔöÇ Makale bloklar─▒n─▒ ay─▒r ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
    // Farkl─▒ class isimlerini destekle: "index-list", "entry-list", "post-"
    const articleBlocks = [];
    const splitPatterns = [
      '<article class="index-list',
      '<article class="entry-list',
      '<article class="post ',
      '<article id="post-',
    ];

    for (const pat of splitPatterns) {
      const parts = html.split(pat);
      if (parts.length > 1) {
        for (let i = 1; i < parts.length; i++) {
          articleBlocks.push(parts[i].split('</article>')[0]);
        }
        break; // ─░lk e┼şle┼şen pattern yeterli
      }
    }

    if (articleBlocks.length === 0) {
      // Fallback: t├╝m <article> i├ğeriklerini regex ile ├ğek
      const artRe = /<article[^>]*>([\s\S]*?)<\/article>/gi;
      let am;
      while ((am = artRe.exec(html)) !== null) articleBlocks.push(am[1]);
    }

    let foundOnPage = 0;
    for (const chunk of articleBlocks) {
      // ┼Şirket ad─▒ + URL ÔÇö birden fazla selector deste─şi
      const linkPatterns = [
        /class="il-halka-arz-sirket"[^>]*>.*?<a\s+href="([^"]+)"[^>]*>(.*?)<\/a>/s,
        /class="[^"]*halka-arz[^"]*"[^>]*>.*?<a\s+href="([^"]+)"[^>]*>(.*?)<\/a>/s,
        /<h2[^>]*class="[^"]*entry-title[^"]*"[^>]*>.*?<a\s+href="([^"]+)"[^>]*>(.*?)<\/a>/s,
        /<a\s+href="(https?:\/\/halkarz\.com\/[^"]+)"[^>]*>(.*?)<\/a>/s,
      ];
      let companyName = '', detailUrl = '';
      for (const pat of linkPatterns) {
        const m = chunk.match(pat);
        if (m && m[1].includes('halkarz.com')) {
          detailUrl   = m[1];
          companyName = cleanTxt(m[2]);
          break;
        }
      }
      if (!detailUrl || seen.has(detailUrl)) continue;

      // Borsa kodu
      const codeM = chunk.match(/class="(?:il-bist-kod|bist-kod|ticker)[^"]*"\s*>([^<]+)/s)
                 || chunk.match(/\b([A-Z]{4,6})\b/);
      const symbol = codeM ? cleanTxt(codeM[1]).toUpperCase().replace(/[^A-Z]/g, '') : '';

      // Talep tarihleri ÔÇö <time> veya metin i├ğinde
      const timeM   = chunk.match(/<time[^>]*datetime="([^"]+)"/);
      const dateM   = chunk.match(/class="[^"]*date[^"]*"[^>]*>([^<]+)/s);
      const reqDates = timeM ? cleanTxt(timeM[1]) : (dateM ? cleanTxt(dateM[1]) : '');

      seen.add(detailUrl);
      items.push({ companyName, symbol, url: detailUrl, requestDates: reqDates });
      foundOnPage++;
    }

    console.log(`HalkArz sayfa ${page}: ${foundOnPage} hisse bulundu`);
    if (foundOnPage === 0) break; // Bo┼ş sayfa ÔåÆ dur
  }

  return items;
}

/**
 * Detay sayfas─▒ndan fiyat, lot, da─ş─▒t─▒m tipi, listeleme tarihi ve KAP URL'ini ├ğeker.
 * Her selector i├ğin birden fazla pattern denenir.
 */
async function fetchIpoDetail(item, bistSymbols) {
  const res = await fetch(item.url, {
    headers: { 'User-Agent': HALKARZ_UA },
    signal:  AbortSignal.timeout(18000),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const html = await res.text();

  /** Tablo sat─▒r─▒ndan de─şer ├ğeker: etiket i├ğeren <td>'nin yan─▒ndaki <td> */
  function tableVal(labelRe) {
    const m = html.match(
      new RegExp(labelRe.source + '[^<]*<\\/td>\\s*<td[^>]*>(?:<[^>]+>)*(.*?)(?:<\\/[^>]+>)*\\s*<\\/td>', 'is'),
    );
    return m ? cleanTxt(m[1]) : '';
  }

  // ÔöÇÔöÇ Fiyat ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  const pricePatterns = [
    /Halka\s+Arz\s+Fiyat/i,
    /Fiyat\s*(?:Aral[i─▒][g─ş][i─▒])?/i,
    /Teklif\s+Fiyat/i,
  ];
  let price = '';
  for (const p of pricePatterns) { price = tableVal(p); if (price && price !== '-') break; }

  // ÔöÇÔöÇ Lot / Pay adedi ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  const lotPatterns = [
    /(?:Toplam\s+)?Pay\s+(?:Adedi|Miktar)/i,
    /(?:Toplam\s+)?Lot\s+(?:Say[i─▒]s[i─▒]|Adedi)/i,
    /Pay\s*:/i,
  ];
  let lot = '';
  for (const p of lotPatterns) { lot = tableVal(p); if (lot && lot !== '-') break; }

  // ÔöÇÔöÇ Da─ş─▒t─▒m y├Ântemi ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  const distPatterns = [
    /Da[g─ş][i─▒]t[i─▒]m\s+Y[o├Â]ntemi/i,
    /Da[g─ş][i─▒]t[i─▒]m\s+[Tt]ipi/i,
    /[Yy][o├Â]ntem/i,
  ];
  let distributionType = '';
  for (const p of distPatterns) { distributionType = tableVal(p); if (distributionType && distributionType !== '-') break; }

  // ÔöÇÔöÇ Talep tarihleri (sayfa ba┼şl─▒─ş─▒ndan veya tablodan) ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  let requestDatesFromDetail = item.requestDates; // Ana sayfadan gelen fallback
  const reqPatterns = [
    /Talep\s+Toplama\s+Tarihleri?/i,
    /Ba[┼şs]vuru\s+Tarihleri?/i,
    /Talep\s+Tarihleri?/i,
  ];
  for (const p of reqPatterns) {
    const v = tableVal(p);
    if (v && v !== '-') { requestDatesFromDetail = v; break; }
  }
  // H1/H2 ba┼şl─▒─ş─▒ndaki tarih bilgisi
  const titleDateM = html.match(/<h[12][^>]*>.*?(\d{1,2}[-ÔÇô]\d{1,2}[-ÔÇô]\d{1,2}\s+\w+\s+\d{4}|[\d.]+\s*[-ÔÇô]\s*[\d.]+\s+\w+\s+\d{4}).*?<\/h[12]>/si);
  if (titleDateM && !requestDatesFromDetail) requestDatesFromDetail = cleanTxt(titleDateM[1]);

  // ÔöÇÔöÇ Listeleme tarihi ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  const listingPatterns = [
    /Bist\s+[─░I]lk\s+[─░I][┼şs]lem\s+Tarihi/i,
    /[─░I]lk\s+[─░I][┼şs]lem\s+Tarihi/i,
    /Borsada\s+[─░I][┼şs]lem\s+G[o├Â]r/i,
    /Kotasyon\s+Tarihi/i,
    /Halka\s+Arz\s+Sonras[i─▒]\s+[─░I][┼şs]lem/i,
  ];
  let listingDateText = '';
  for (const p of listingPatterns) {
    const v = tableVal(p);
    if (v && v !== '-' && v.length > 3) { listingDateText = v; break; }
  }

  // ÔöÇÔöÇ KAP URL ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  const kapM = html.match(/https?:\/\/(?:www\.)?kap\.org\.tr\/[^\s"'>]+/i);

  // ÔöÇÔöÇ Hesaplama ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  const range       = parseTrDateRange(requestDatesFromDetail);
  const listingDate = parseTrDateRange(listingDateText).start || null;
  const status      = computeIpoStatus({
    requestStart: range.start,
    requestEnd:   range.end,
    listingDate,
    symbol:       item.symbol,
    bistSymbols,
  });

  return {
    companyName:      item.companyName,
    requestDates:     requestDatesFromDetail || '-',
    requestStart:     toIso(range.start),
    requestEnd:       toIso(range.end),
    price:            price   || '-',
    lot:              lot     || '-',
    distributionType: distributionType || '-',
    symbol:           item.symbol,
    status,
    listingDate:      toIso(listingDate),
    kapUrl:           kapM ? kapM[0] : '',
    source:           'HalkArz',
    publishedAt:      new Date().toISOString(),
  };
}

/**
 * T├╝m hisse listesini ├ğeker ve detaylar─▒ toplar.
 * Her hisse aras─▒nda 400ms bekler (politeness delay).
 */
async function fetchHalkArzItems(bistSymbols) {
  const pageItems = await collectHalkArzUrls(5); // Maksimum 5 sayfa = ~50 hisse
  console.log(`HalkArz: toplam ${pageItems.length} hisse URL'i, detaylar ├ğekiliyor...`);

  const results = [];
  for (const item of pageItems) {
    try {
      await new Promise(r => setTimeout(r, 400));
      const detail = await fetchIpoDetail(item, bistSymbols);
      results.push(detail);
    } catch (err) {
      console.warn(`HalkArz detay hatas─▒ (${item.symbol || item.companyName}):`, err.message);
      // Hata durumunda bile temel bilgilerle kay─▒t olu┼ştur
      const range  = parseTrDateRange(item.requestDates);
      const status = computeIpoStatus({
        requestStart: range.start,
        requestEnd:   range.end,
        listingDate:  null,
        symbol:       item.symbol,
        bistSymbols,
      });
      results.push({
        companyName:      item.companyName,
        requestDates:     item.requestDates || '-',
        requestStart:     toIso(range.start),
        requestEnd:       toIso(range.end),
        price:            '-',
        lot:              '-',
        distributionType: '-',
        symbol:           item.symbol,
        status,
        listingDate:      '',
        kapUrl:           '',
        source:           'HalkArz',
        publishedAt:      new Date().toISOString(),
      });
    }
  }

  console.log(`HalkArz: ${results.length} hisse i┼şlendi`);
  return results;
}

/**
 * Firestore'daki t├╝m mevcut kay─▒tlar─▒ okur ve tarihi ge├ğmi┼ş olanlar─▒n
 * stat├╝s├╝n├╝ "trading" olarak g├╝nceller (scraper'─▒n ka├ğ─▒rd─▒─ş─▒ ge├ği┼şler).
 * bistSymbols: BIST'te aktif olan semboller; bunlar her zaman trading yap─▒l─▒r.
 */
async function reconcileStaleIpoStatuses(bistSymbols) {
  const now = new Date();
  const snapshot = await db.collection('ipo_items').get();
  if (snapshot.empty) return 0;

  const stale = [];
  for (const doc of snapshot.docs) {
    const d = doc.data();
    if (d.status === 'trading') continue; // Zaten do─şru

    // BIST'te listelenmi┼ş hisse ÔåÆ trading
    if (d.symbol && bistSymbols instanceof Set && bistSymbols.has(d.symbol.toUpperCase())) {
      stale.push({ ref: doc.ref, status: 'trading' });
      continue;
    }

    // listingDate ge├ğtiyse ÔåÆ trading
    if (d.listingDate) {
      const ld = new Date(d.listingDate);
      if (!isNaN(ld) && ld <= now) {
        stale.push({ ref: doc.ref, status: 'trading' });
        continue;
      }
    }

    // requestEnd ge├ğtiyse ve listingDate yoksa ÔåÆ pending_listing
    if (d.requestEnd && !d.listingDate && d.status !== 'pending_listing') {
      const re = new Date(d.requestEnd);
      if (!isNaN(re)) {
        const endOfDay = new Date(re.getFullYear(), re.getMonth(), re.getDate(), 23, 59, 59);
        if (now > endOfDay) stale.push({ ref: doc.ref, status: 'pending_listing' });
      }
    }
  }

  if (!stale.length) return 0;

  // Batch g├╝ncelle
  let updated = 0;
  for (let i = 0; i < stale.length; i += 400) {
    const batch = db.batch();
    for (const { ref, status } of stale.slice(i, i + 400)) {
      batch.update(ref, { status, updatedAt: FieldValue.serverTimestamp() });
    }
    await batch.commit();
    updated += Math.min(400, stale.length - i);
  }

  console.log(`IPO reconcile: ${updated} kayd─▒n stat├╝s├╝ g├╝ncellendi`);
  return updated;
}

/**
 * Yeni ├ğekilen kay─▒tlar─▒ Firestore'a yazar.
 * ├ûncelik s─▒ras─▒: trading > pending_listing > collecting > upcoming
 * Ayn─▒ sembol i├ğin daha y├╝ksek ├Âncelikli stat├╝ kazan─▒r.
 * Mevcut Firestore'da 'trading' olan kay─▒t, HalkArz'dan daha d├╝┼ş├╝k stat├╝ gelse bile korunur.
 */
async function writeIpoToFirestore(items, bistSymbols) {
  if (!items.length) return 0;
  const PRI = { trading: 4, pending_listing: 3, collecting: 2, upcoming: 1 };
  const deduped = new Map();

  for (const item of items) {
    const key = item.symbol
      ? item.symbol.toUpperCase()
      : `NO_SYMBOL_${item.companyName.replace(/\s+/g, '_').substring(0, 30)}`;
    const ex = deduped.get(key);
    if (!ex) { deduped.set(key, item); continue; }
    const ep = PRI[ex.status]   || 0;
    const np = PRI[item.status] || 0;
    if (np > ep || (np === ep && (item.publishedAt || '') > (ex.publishedAt || ''))) {
      deduped.set(key, item);
    }
  }

  const entries = [...deduped.entries()];

  // Mevcut Firestore durumlar─▒n─▒ oku (trading korumas─▒ i├ğin)
  let existingStatuses = new Map();
  try {
    const refs = entries.map(([docId]) => db.collection('ipo_items').doc(docId));
    if (refs.length > 0) {
      // db.getAll 500 limit ÔÇö chunk'a b├Âl
      for (let i = 0; i < refs.length; i += 400) {
        const chunk = refs.slice(i, i + 400);
        const snaps = await db.getAll(...chunk);
        for (const snap of snaps) {
          if (snap.exists) {
            existingStatuses.set(snap.id, snap.data().status || null);
          }
        }
      }
    }
  } catch (err) {
    console.warn('writeIpoToFirestore: mevcut stat├╝ler okunamad─▒, trading korumas─▒ devre d─▒┼ş─▒:', err.message);
  }

  let written = 0;
  for (let i = 0; i < entries.length; i += 400) {
    const batch = db.batch();
    for (const [docId, item] of entries.slice(i, i + 400)) {
      let finalStatus = item.status;

      // Kural 1: Firestore'da zaten trading varsa koru
      if (existingStatuses.get(docId) === 'trading') {
        finalStatus = 'trading';
      }
      // Kural 2: BIST'te aktif sembol ÔåÆ trading
      if (item.symbol && bistSymbols instanceof Set && bistSymbols.has(item.symbol.toUpperCase())) {
        finalStatus = 'trading';
      }

      batch.set(
        db.collection('ipo_items').doc(docId),
        { ...item, status: finalStatus, updatedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
    }
    await batch.commit();
    written += Math.min(400, entries.length - i);
  }

  await db.collection('ipo_meta').doc('feed').set({
    lastUpdated:  FieldValue.serverTimestamp(),
    itemCount:    written,
    source:       'HalkArz',
    lastSyncedAt: new Date().toISOString(),
  });

  return written;
}

// ÔöÇÔöÇ Scheduled: Her 6 saatte bir (UTC 00, 06, 12, 18) ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
exports.syncIpoFeed = onSchedule({
  schedule:       '0 */6 * * *',
  timeZone:       'UTC',
  region:         'europe-west1',
  memory:         '512MiB',
  timeoutSeconds: 300,
}, async () => {
  console.log('IPO sync ba┼şlad─▒:', new Date().toISOString());
  try {
    // 1. BIST sembol k├╝mesini ├ğek (durum hesaplamalar─▒nda kullan─▒l─▒r)
    const bistSymbols = await loadBistSymbols();
    // 2. HalkArz'dan taze veriyi ├ğek (BIST kontrol├╝yle)
    const items = await fetchHalkArzItems(bistSymbols);
    if (!items.length) { console.warn('HalkArz: kay─▒t bulunamad─▒'); return; }
    // 3. Yaz (mevcut trading korumal─▒)
    const count = await writeIpoToFirestore(items, bistSymbols);
    // 4. Reconcile ÔÇö HalkArz'─▒n ├╝zerine yazmas─▒ndan sonra uygula (kal─▒c─▒ olur)
    const reconciled = await reconcileStaleIpoStatuses(bistSymbols);
    console.log(`IPO sync tamamland─▒: ${count} kay─▒t, ${reconciled} reconcile`);
  } catch (err) {
    console.error('IPO sync hatas─▒:', err.message);
    throw err;
  }
});

// ÔöÇÔöÇ Manuel tetikleme (admin korumal─▒) ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
exports.syncIpoManual = onRequest({
  region:         'europe-west1',
  memory:         '512MiB',
  timeoutSeconds: 300,
  secrets:        [ADMIN_SECRET],
}, async (req, res) => {
  const secret = ADMIN_SECRET.value().trim();
  const given  = (req.headers['x-admin-secret'] || req.query.secret || '').trim();
  if (!secret || given !== secret) { res.status(403).json({ error: 'Unauthorized' }); return; }
  try {
    // 1. BIST sembol k├╝mesini ├ğek
    const bistSymbols = await loadBistSymbols();
    // 2. HalkArz'dan veriyi ├ğek (BIST kontrol├╝yle)
    const items  = await fetchHalkArzItems(bistSymbols);
    // 3. Yaz (mevcut trading korumal─▒)
    const count  = await writeIpoToFirestore(items, bistSymbols);
    // 4. Reconcile ÔÇö yazmadan sonra uygula
    const reconciled = await reconcileStaleIpoStatuses(bistSymbols);
    res.json({ success: true, count, reconciled });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// TEKN─░K ANAL─░Z AI PROXY ÔÇö NVIDIA NIM (Nemotron-3.5-Lightning-30B)
//
// Flutter uygulamas─▒ bu endpoint'e hisse verilerini g├Ânderir.
// NVIDIA_API_KEY sadece burada ya┼şar ÔÇö uygulama bundle'─▒na girmez.
//
// G├╝venlik:
//   - CORS: sadece Firebase Hosting domain'ine izin verilir
//   - Rate limit: IP ba┼ş─▒na dakikada max 10 istek
//   - Input validation: zorunlu alanlar kontrol edilir
//   - Timeout: 25 saniye
//
// Fallback davran─▒┼ş─▒:
//   - Herhangi bir hatada HTTP 503 d├Âner ÔåÆ Flutter lokal fallback'e ge├ğer
// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

// Rate limiter (bellek i├ği, function instance ba┼ş─▒na)
const rateLimitMap = new Map(); // ip ÔåÆ { count, resetAt }

function isRateLimited(ip) {
  const now = Date.now();
  const entry = rateLimitMap.get(ip);
  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(ip, { count: 1, resetAt: now + 60_000 });
    return false;
  }
  if (entry.count >= 10) return true;
  entry.count++;
  return false;
}

// ÔöÇÔöÇ YAPAY ZEKA MODELLER─░ (NVIDIA NIM) ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// 1. Ana AI:    NVIDIA Nemotron 3 Super 120B (nvidia/nemotron-3-super-120b-a12b)
// 2. Yedek AI:  OpenAI GPT-OSS 20B (openai/gpt-oss-20b)
const MODEL_PRIMARY  = 'nvidia/nemotron-3-super-120b-a12b';
const MODEL_FALLBACK = 'openai/gpt-oss-20b';

/** NVIDIA NIM OpenAI-uyumlu API'ye tekil model iste─şi atar. */
async function callNvidiaModel(apiKey, modelId, prompt, timeoutMs = 15000) {
  const body = JSON.stringify({
    model: modelId,
    messages: [
      {
        role: 'system',
        content:
          'Sen deneyimli bir Turk borsa teknik analiz asistanisin.\n' +
          'SADECE Turkce yaz.\n' +
          'Ingilizce kelime, baslik veya aciklama kullanma.\n' +
          'Dusunme surecini, reasoning, thinking process veya taslak adimlarini gosterme.\n' +
          'Dogrudan analize basla.\n' +
          'Gonderilen teknik verilerden yararlan.\n' +
          'Her hisse icin ayni kalip analiz yazma.\n' +
          'Analizin icerigi mutlaka gonderilen hissenin gercek teknik verilerine dayanmali.\n' +
          'Mumkun oldugunda gercek sayisal degerleri kullan.\n' +
          'RSI 32 ise bunu analizde degerlendir; RSI 58 ise 32 gibi davranma.\n' +
          'Destek, direnc, fiyat degisimi, hacim, MACD, Supertrend ve formasyonlari yalnizca gonderilen verilere gore yorumla.\n' +
          'Bir veri gonderilmemisse o veri hakkinda tahmin yapma.\n' +
          'Olmayan bir sinyali varmis gibi gosterme.\n' +
          'Ayni cumleleri farkli hisselerde tekrar etme.\n' +
          'Analizi TAM OLARAK 3 paragrafa ayir.\n' +
          'Paragraflar arasina mutlaka BIR BOS SATIR birak.\n' +
          '1. Paragraf: Fiyat ve trend durumu.\n' +
          '2. Paragraf: Momentum (RSI), destek/direnc ve hacim.\n' +
          '3. Paragraf: Genel degerlendirme ve varsa temel carpanlar.\n' +
          'Her paragraf 2-3 kisa cumleden olusmali. Uzun cumle yazma.\n' +
          'Yatirim tavsiyesi verme.\n' +
          'Son cumle (son paragrafin sonuna ekle): Bu bir yatirim tavsiyesi degildir.',
      },
      { role: 'user', content: prompt },
    ],
    temperature: 0.6,
    top_p: 0.95,
    max_tokens: 800,  // 3 k─▒sa paragraf i├ğin yeterli; token bitince kesilmesini ├Ânler
    stream: false,
  });

  const result = await new Promise((resolve, reject) => {
    const options = {
      hostname: 'integrate.api.nvidia.com',
      path: '/v1/chat/completions',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
      timeout: timeoutMs,
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          try { resolve(JSON.parse(data)); }
          catch (e) { reject(new Error('NVIDIA yan─▒t parse hatas─▒: ' + e.message)); }
        } else {
          reject(new Error(`NVIDIA API HTTP ${res.statusCode}: ${data.substring(0, 200)}`));
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error(`NVIDIA API timeout (${modelId})`)); });
    req.write(body);
    req.end();
  });

  // finish_reason kontrol├╝: "length" ise yan─▒t token limitinde kesildi ÔåÆ hata f─▒rlat
  const finishReason = result?.choices?.[0]?.finish_reason;
  if (finishReason === 'length') {
    throw new Error(`NVIDIA yan─▒t─▒ token limitinde kesildi (${modelId}) ÔÇö yar─▒m analiz ├Ânlendi`);
  }

  let content = result?.choices?.[0]?.message?.content;
  if (!content) throw new Error(`NVIDIA yan─▒t─▒ bo┼ş (${modelId})`);
  content = content.replace(/<think>[\s\S]*?<\/think>/gi, '').trim();
  if (!content) throw new Error(`NVIDIA yan─▒t─▒ ay─▒kland─▒ktan sonra bo┼ş kald─▒ (${modelId})`);
  return content;
}

/**
 * ─░ki kademeli yapay zeka analizi:
 * 1. Ana AI (NVIDIA Nemotron 3 Super 120B) denenir.
 * 2. Ba┼şar─▒s─▒z olursa / zaman a┼ş─▒m─▒na u─şrarsa 2. AI (OpenAI GPT-OSS 20B) devreye girer.

 * 3. Her iki model de ba┼şar─▒s─▒z olursa hata f─▒rlat─▒l─▒r (Cloud Function 503 d├Âner, Flutter lokal analize ge├ğer).
 */
async function getDualAiAnalysis(apiKey, prompt) {
  // Minimum anlaml─▒ analiz uzunlu─şu: 3 paragraf ├ù 2 c├╝mle = en az ~200 karakter
  const MIN_ANALYSIS_LENGTH = 200;

  // 1. Kademe: Ana AI (Nemotron 3 Super 120B)
  try {
    console.log(`[AI] 1. Kademe (Ana AI) deneniyor: ${MODEL_PRIMARY}`);
    const analysis = await callNvidiaModel(apiKey, MODEL_PRIMARY, prompt, 14000);
    if (analysis && analysis.length >= MIN_ANALYSIS_LENGTH) {
      console.log(`[AI] Ana AI ba┼şar─▒l─▒ oldu (${MODEL_PRIMARY}), uzunluk: ${analysis.length}`);
      return { analysis, usedModel: MODEL_PRIMARY };
    }
    throw new Error(`Ana AI yan─▒t─▒ yetersiz (${analysis?.length ?? 0} karakter, min ${MIN_ANALYSIS_LENGTH})`);
  } catch (errPrimary) {
    console.warn(`[AI] Ana AI (${MODEL_PRIMARY}) ba┼şar─▒s─▒z oldu: ${errPrimary.message}. 2. Kademe (OpenAI GPT-OSS 20B) deneniyor...`);
  }

  // 2. Kademe: ─░kinci AI (OpenAI GPT-OSS 20B)
  try {
    console.log(`[AI] 2. Kademe (Yedek AI) deneniyor: ${MODEL_FALLBACK}`);
    const analysis = await callNvidiaModel(apiKey, MODEL_FALLBACK, prompt, 18000);
    if (analysis && analysis.length >= MIN_ANALYSIS_LENGTH) {
      console.log(`[AI] ─░kinci AI ba┼şar─▒l─▒ oldu (${MODEL_FALLBACK}), uzunluk: ${analysis.length}`);
      return { analysis, usedModel: MODEL_FALLBACK };
    }
    throw new Error(`─░kinci AI yan─▒t─▒ yetersiz (${analysis?.length ?? 0} karakter, min ${MIN_ANALYSIS_LENGTH})`);
  } catch (errSecondary) {
    console.error(`[AI] ─░kinci AI (${MODEL_FALLBACK}) de ba┼şar─▒s─▒z oldu: ${errSecondary.message}`);
    throw new Error(`Her iki AI modeli de ba┼şar─▒s─▒z oldu: ${errSecondary.message}`);
  }
}

/** Hisse verilerinden AI prompt'u olu┼şturur. */
function buildAnalysisPrompt(data) {
  const {
    symbol, name, price, changePercent,
    rsi, emaAboveCount,
    supportLevel, resistanceLevel,
    volumeIncreasing, periodChange,
    isBullishDivergence, isBearishDivergence,
    isGoldenCross, isDeathCross,
    isMacdBullish, isMacdBearish,
    isSupertrendBuy, isSupertrendSell,
    isHammer, isBullishEngulfing, isMorningStar,
    isBearishEngulfing, isDoji,
    periodLabel, fk, pdDd,
  } = data;

  // Boolean'lar─▒ T├╝rk├ğe okunabilir formata ├ğevir (AI modelin daha iyi anlamas─▒ i├ğin)
  const e = (v) => v === true ? 'Evet' : 'Hay─▒r';

  const ortalamaMetni =
    emaAboveCount === 3 ? 'Fiyat 20, 50 ve 200 g├╝nl├╝k hareketli ortalamalar─▒n hepsinin ├╝zerinde' :
    emaAboveCount === 2 ? 'Fiyat 20 ve 50 g├╝nl├╝k ortalamalar─▒n ├╝zerinde; 200 g├╝nl├╝k ortalama hen├╝z a┼ş─▒lmad─▒' :
    emaAboveCount === 1 ? 'Fiyat yaln─▒zca 20 g├╝nl├╝k ortalaman─▒n ├╝zerinde; 50 ve 200 g├╝nl├╝k ortalamalar bask─▒ yap─▒yor' :
    'Fiyat 20, 50 ve 200 g├╝nl├╝k hareketli ortalamalar─▒n hepsinin alt─▒nda';

  const rsiStr = (typeof rsi === 'number' && !isNaN(rsi)) ? rsi.toFixed(1) : '?';
  const priceStr = (typeof price === 'number') ? price.toFixed(2) : '?';
  const changeStr = (changePercent >= 0 ? '+' : '') + (changePercent || 0).toFixed(2);
  const periodChangeStr = (periodChange >= 0 ? '+' : '') + (periodChange || 0).toFixed(1);

  return (
    `H─░SSE:\n` +
    `Sembol: ${symbol}\n` +
    `┼Şirket: ${name}\n\n` +
    `F─░YAT:\n` +
    `G├╝ncel fiyat: ${priceStr} TL\n` +
    `G├╝nl├╝k de─şi┼şim: ${changeStr}%\n\n` +
    `TEKN─░K VER─░LER:\n` +
    `RSI (momentum g├Âstergesi): ${rsiStr}\n` +
    `Hareketli ortalama durumu: ${ortalamaMetni}\n` +
    (supportLevel  ? `Yak─▒n destek: ${supportLevel.toFixed(2)} TL\n`  : '') +
    (resistanceLevel ? `Yak─▒n diren├ğ: ${resistanceLevel.toFixed(2)} TL\n` : '') +
    `Hacim art─▒yor mu: ${e(volumeIncreasing)}\n` +
    `D├Ânem de─şi┼şimi (${periodLabel || 'G'}): ${periodChangeStr}%\n\n` +
    `S─░NYALLER:\n` +
    `Pozitif uyumsuzluk (Bullish Divergence): ${e(isBullishDivergence)}\n` +
    `Negatif uyumsuzluk (Bearish Divergence): ${e(isBearishDivergence)}\n` +
    `Golden Cross (Alt─▒n Kesi┼şim): ${e(isGoldenCross)}\n` +
    `Death Cross (├ûl├╝m Kesi┼şimi): ${e(isDeathCross)}\n` +
    `MACD y├╝kseli┼ş sinyali: ${e(isMacdBullish)}\n` +
    `MACD d├╝┼ş├╝┼ş sinyali: ${e(isMacdBearish)}\n` +
    `Supertrend AL sinyali: ${e(isSupertrendBuy)}\n` +
    `Supertrend SAT sinyali: ${e(isSupertrendSell)}\n\n` +
    `MUM FORMASYONLARI:\n` +
    `├çeki├ğ (Hammer): ${e(isHammer)}\n` +
    `Yutan Bo─şa (Bullish Engulfing): ${e(isBullishEngulfing)}\n` +
    `Sabah Y─▒ld─▒z─▒ (Morning Star): ${e(isMorningStar)}\n` +
    `Yutan Ay─▒ (Bearish Engulfing): ${e(isBearishEngulfing)}\n` +
    `Doji: ${e(isDoji)}\n\n` +
    ((fk > 0 || pdDd > 0)
      ? `DE─ŞERLEME (teknik analizden ba─ş─▒ms─▒z de─şerlendir):\n` +
        (fk   > 0 ? `F/K (Fiyat/Kazan├ğ): ${fk.toFixed(1)}\n`   : '') +
        (pdDd > 0 ? `PD/DD (Piyasa/Defter): ${pdDd.toFixed(2)}\n` : '') + '\n'
      : '') +
    `Yukar─▒daki verileri analiz et.\n` +
    `Analizde RSI ${rsiStr} ve fiyat ${priceStr} TL ger├ğek de─şerlerini kullan.\n` +
    `Ayn─▒ kal─▒p c├╝mleleri farkl─▒ hisseler i├ğin tekrar etme.\n` +
    `Veri yoksa o konuda tahmin yapma.\n` +
    `Analizi 3 paragrafa ayirarak yaz. Paragraflar arasina bos satir birak.\n` +
    `Son satir (bos satirdan sonra ayri paragraf): Bu bir yatirim tavsiyesi degildir.`
  );
}

// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// TEKN─░K ANAL─░Z ├ûNBELLEK ÔÇö Firestore
//
// Ayn─▒ hisse + periyot + g├╝n kombinasyonu i├ğin g├╝nde 1 kez NVIDIA'ya istek at─▒l─▒r.
// Kalan t├╝m kullan─▒c─▒lar ├Ânbellekten an─▒nda cevap al─▒r.
//
// Firestore yap─▒s─▒:
//   ai_cache/{symbol}_{period}_{YYYY-MM-DD}  ÔåÆ { analysis, createdAt, hitCount }
//
// ├ûnbellek ge├ğerlilik s├╝resi:
//   - Borsa g├╝nlerinde 4 saat (piyasa bilgisi de─şi┼şir)
//   - Hafta sonu 24 saat (piyasa kapal─▒, fiyat de─şi┼şmez)
// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

const CACHE_TTL_BORSAGUNU_MS = 4 * 60 * 60 * 1000;   // 4 saat
const CACHE_TTL_HAFTASONU_MS = 24 * 60 * 60 * 1000;  // 24 saat

function getCacheTtl() {
  const gun = new Date().getUTCDay(); // 0=Pazar, 6=Cumartesi
  return (gun === 0 || gun === 6) ? CACHE_TTL_HAFTASONU_MS : CACHE_TTL_BORSAGUNU_MS;
}

function buildCacheKey(symbol, periodLabel, rsi, changePercent, data) {
  const bugun = new Date().toISOString().slice(0, 10);
  const temiz = symbol.replace(/[^A-Z0-9]/gi, '').toUpperCase();
  const periyot = (periodLabel || 'G').replace(/\s/g, '_');

  // RSI'yi 5'in katlar─▒na yuvarla ÔÇö her hisse benzersiz cache anahtar─▒ al─▒r
  // ├ûrnek: THYAO RSI=32ÔåÆ30, ASELS RSI=57ÔåÆ55, TUPRS RSI=71ÔåÆ70 ÔåÆ tamam─▒ farkl─▒
  const rsiRound = Math.round((rsi || 50) / 5) * 5;

  // Fiyat de─şi┼şim y├Ân├╝ (geni┼ş bant)
  const yon = changePercent > 2 ? 'up2' : changePercent > 0.5 ? 'up1'
            : changePercent < -2 ? 'dn2' : changePercent < -0.5 ? 'dn1' : 'flat';

  // Aktif sinyal ├Âzeti ÔÇö farkl─▒ sinyal kombinasyonlar─▒ farkl─▒ cache anahtar─▒ ├╝retir
  const sd = data || {};
  const sinyalBits = [
    sd.isGoldenCross       ? 'gc'  : '',
    sd.isDeathCross        ? 'dc'  : '',
    sd.isMacdBullish       ? 'mb'  : '',
    sd.isMacdBearish       ? 'ms'  : '',
    sd.isSupertrendBuy     ? 'sb'  : '',
    sd.isSupertrendSell    ? 'ss'  : '',
    sd.isBullishDivergence ? 'bd'  : '',
    sd.isBearishDivergence ? 'bdn' : '',
  ].filter(Boolean).join('') || 'none';

  return `v5_${temiz}_${periyot}_${bugun}_rsi${rsiRound}_${yon}_${sinyalBits}`;
}

async function getCachedAnalysis(cacheKey) {
  try {
    const doc = await db.collection('ai_cache').doc(cacheKey).get();
    if (!doc.exists) return null;
    const data = doc.data();
    const now = Date.now();
    const olusturmaTarihi = data.createdAt?.toMillis?.() || 0;
    if (now - olusturmaTarihi > getCacheTtl()) return null; // s├╝resi dolmu┼ş
    // Eri┼şim sayac─▒n─▒ artt─▒r (analytics i├ğin)
    doc.ref.update({ hitCount: FieldValue.increment(1) }).catch(() => {});
    return data.analysis || null;
  } catch (err) {
    console.warn('├ûnbellek okuma hatas─▒:', err.message);
    return null;
  }
}

async function setCachedAnalysis(cacheKey, analysis, symbol, periodLabel) {
  try {
    await db.collection('ai_cache').doc(cacheKey).set({
      analysis,
      symbol:      symbol.toUpperCase(),
      periodLabel: periodLabel || '',
      createdAt:   FieldValue.serverTimestamp(),
      hitCount:    0,
    });
  } catch (err) {
    console.warn('├ûnbellek yazma hatas─▒:', err.message);
  }
}

exports.getTeknikAnaliz = onRequest({
  region: 'europe-west1',
  memory: '256MiB',
  timeoutSeconds: 50,
  secrets: [NVIDIA_API_KEY],
}, async (req, res) => {
  // CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Yaln─▒zca POST desteklenmektedir' });
    return;
  }

  // Rate limit
  const clientIp = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip || 'unknown';
  if (isRateLimited(clientIp)) {
    res.status(429).json({ error: '─░stek limiti a┼ş─▒ld─▒, l├╝tfen bekleyin' });
    return;
  }

  // Girdi do─şrulama
  const data = req.body;
  if (!data || !data.symbol || !data.name || typeof data.rsi !== 'number') {
    res.status(400).json({ error: 'Eksik veya ge├ğersiz parametre' });
    return;
  }

  const cacheKey = buildCacheKey(data.symbol, data.periodLabel, data.rsi || 50, data.changePercent || 0, data);

  // ÔöÇÔöÇ 1. ├ûnbellek kontrol├╝ ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  const cachedAnalysis = await getCachedAnalysis(cacheKey);
  if (cachedAnalysis) {
    console.log(`├ûnbellekten d├Ând├╝: ${cacheKey}`);
    res.json({ success: true, analysis: cachedAnalysis, fromCache: true });
    return;
  }

  // ÔöÇÔöÇ 2. NVIDIA'ya yeni istek (─░ki Kademeli Dual AI) ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  try {
    const apiKey  = NVIDIA_API_KEY.value();
    const prompt  = buildAnalysisPrompt(data);
    const { analysis, usedModel } = await getDualAiAnalysis(apiKey, prompt);

    // ├ûnbelle─şe yaz (hata olursa sessizce ge├ğ)
    await setCachedAnalysis(cacheKey, analysis, data.symbol, data.periodLabel);

    console.log(`AI'dan yeni yan─▒t al─▒nd─▒ (${usedModel}), ├Ânbelle─şe yaz─▒ld─▒: ${cacheKey}`);
    res.json({ success: true, analysis, usedModel, fromCache: false });
  } catch (err) {
    console.error('getTeknikAnaliz hatas─▒:', err.message);
    // 503 ÔåÆ Flutter lokal analize ge├ğer
    res.status(503).json({ error: 'Yapay zeka servisi ┼şu an kullan─▒lam─▒yor' });
  }
});

// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// ├ûNBELLEK TEM─░ZLEY─░C─░ ÔÇö Her gece 02:00 UTC ├ğal─▒┼ş─▒r
//


// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// ├ûNBELLEK TEM─░ZLEY─░C─░ ÔÇö Her gece 02:00 UTC ├ğal─▒┼ş─▒r
//
// 48 saatten eski ai_cache kay─▒tlar─▒n─▒ siler.
// Firestore'un ┼şi┼şmesini ├Ânler, maliyeti d├╝┼ş├╝k tutar.
// G├╝nde max ~500 BIST hissesi ├ù 6 periyot = 3000 kay─▒t ÔÇö temizlik y├Ânetilebilir.
// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

exports.cleanAiCache = onSchedule({
  schedule:       '0 2 * * *',   // Her gece saat 02:00 UTC
  timeZone:       'UTC',
  region:         'europe-west1',
  memory:         '256MiB',
  timeoutSeconds: 120,
}, async () => {
  const ESKIME_SURESI_MS = 48 * 60 * 60 * 1000; // 48 saat
  const sinirZamani = new Date(Date.now() - ESKIME_SURESI_MS);

  console.log(`├ûnbellek temizli─şi ba┼şlad─▒. ${sinirZamani.toISOString()} ├Âncesi kay─▒tlar silinecek.`);

  try {
    // Batch halinde sil (Firestore limit: 500/batch)
    let silinen = 0;
    let devam = true;

    while (devam) {
      const snapshot = await db.collection('ai_cache')
        .where('createdAt', '<', sinirZamani)
        .limit(400)
        .get();

      if (snapshot.empty) { devam = false; break; }

      const batch = db.batch();
      snapshot.docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();

      silinen += snapshot.size;
      console.log(`${silinen} kay─▒t silindi...`);

      // 400'den az geldiyse bitti
      if (snapshot.size < 400) devam = false;
    }

    console.log(`├ûnbellek temizli─şi tamamland─▒: toplam ${silinen} kay─▒t silindi.`);
  } catch (err) {
    console.error('├ûnbellek temizli─şi hatas─▒:', err.message);
  }
});

// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// GOOGLE PLAY SUBSCRIPTION VERIFICATION (Developer API)
// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
const { google } = require('googleapis');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');

const PLAY_SERVICE_ACCOUNT_KEY = defineSecret('PLAY_SERVICE_ACCOUNT_KEY');
const PACKAGE_NAME = 'com.teknikbakis.teknik_bakis';

/**
 * Google Play Developer API istemcisini auth ile ba┼şlat─▒r.
 * ├ûncelik 1: PLAY_SERVICE_ACCOUNT_KEY (Secret Manager JSON)
 * ├ûncelik 2: Application Default Credentials (GCP Service Account)
 */
async function getPlayAuthClient(secretJsonStr) {
  console.log(`[PlayAuth] secretJsonStr bo┼ş mu: ${!secretJsonStr}`);
  console.log(`[PlayAuth] startsWith('{') sonucu: ${!!(secretJsonStr && secretJsonStr.trim().startsWith('{'))}`);

  if (secretJsonStr && secretJsonStr.trim().startsWith('{')) {
    try {
      const creds = JSON.parse(secretJsonStr);

      console.log(`[PlayAuth] client_email: ${creds.client_email}`);
      console.log(`[PlayAuth] private_key mevcut mu: ${!!creds.private_key}`);
      console.log(`[PlayAuth] project_id: ${creds.project_id}`);

      return new google.auth.JWT({
        email: creds.client_email,
        key: creds.private_key,
        scopes: ['https://www.googleapis.com/auth/androidpublisher'],
      });
    } catch (e) {
      console.warn(`[PlayAuth] JSON parse hatas─▒: ${e.message}`);
      console.warn('[PlayAuth] ADC fallback kullan─▒l─▒yor');
    }
  }

  console.log('[PlayAuth] ADC fallback kullan─▒l─▒yor');
  const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  return await auth.getClient();
}

/**
 * purchaseToken'─▒ Google Play Subscriptions v2 API ├╝zerinden do─şrular
 * ve Firestore'daki `entitlements/{deviceId}` ve `subscription_tokens/{token}`
 * d├Âk├╝manlar─▒n─▒ sunucu taraf─▒nda g├╝nceller.
 */
async function verifyAndSaveSubscription({ purchaseToken, productId, deviceId, planHint, secretKeyStr }) {
  if (!purchaseToken) {
    throw new Error('purchaseToken parametresi zorunludur.');
  }

  let subscriptionData = null;
  let isApiVerified = false;

  try {
    const authClient = await getPlayAuthClient(secretKeyStr);
    const play = google.androidpublisher({ version: 'v3', auth: authClient });

    const res = await play.purchases.subscriptionsv2.get({
      packageName: PACKAGE_NAME,
      token: purchaseToken,
    });
    subscriptionData = res.data;
    isApiVerified = true;
  } catch (apiErr) {
    console.warn(`[verifySubscription] Google Play API sorgulama uyar─▒s─▒: ${apiErr.message}`);
  }

  let isActive = false;
  let subscriptionState = 'UNKNOWN';
  let expiryTime = null;
  let resolvedPlan = planHint || 'monthly';

  if (subscriptionData) {
    subscriptionState = subscriptionData.subscriptionState || 'UNKNOWN';

    if (Array.isArray(subscriptionData.lineItems) && subscriptionData.lineItems.length > 0) {
      const item = subscriptionData.lineItems[0];
      expiryTime = item.expiryTime; // ISO8601 string
      if (item.productId && item.productId.toLowerCase().includes('year')) {
        resolvedPlan = 'yearly';
      }
    }

    const now = new Date();
    const expiryDate = expiryTime ? new Date(expiryTime) : null;

    switch (subscriptionState) {
      case 'SUBSCRIPTION_STATE_ACTIVE':
        isActive = true;
        break;
      case 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD':
        // ├ûdeme aksakl─▒─ş─▒ durumunda kullan─▒c─▒ya tan─▒nan ek s├╝re (Grace Period)
        isActive = true;
        break;
      case 'SUBSCRIPTION_STATE_CANCELED':
        // ─░ptal edilmi┼ş fakat d├Ânem sonu hen├╝z gelmemi┼ş abonelikler s├╝resi bitene kadar aktiftir
        if (expiryDate && expiryDate > now) {
          isActive = true;
        } else {
          isActive = false;
        }
        break;
      case 'SUBSCRIPTION_STATE_ON_HOLD':
      case 'SUBSCRIPTION_STATE_PAUSED':
      case 'SUBSCRIPTION_STATE_EXPIRED':
      case 'SUBSCRIPTION_STATE_PENDING':
      default:
        isActive = false;
        break;
    }
  } else {
    // Google Play API ba┼şar─▒s─▒z oldu veya service account yap─▒land─▒r─▒lmam─▒┼ş
    // G├£VENL─░K: API do─şrulamas─▒ yap─▒lamad─▒─ş─▒nda Premium A├çILMAZ
    console.warn('[verifyAndSaveSubscription] Google Play API do─şrulamas─▒ ba┼şar─▒s─▒z ÔÇö isActive=false');
    subscriptionState = 'API_VERIFICATION_FAILED';
    isActive = false;
  }

  const entitlementPayload = {
    deviceId: deviceId || 'unknown',
    isActive,
    plan: resolvedPlan,
    productId: productId || 'teknik_bakis_premium',
    purchaseToken,
    subscriptionState,
    expiryTime: expiryTime || null,
    isApiVerified,
    updatedAt: FieldValue.serverTimestamp(),
  };

  const batch = db.batch();

  if (deviceId) {
    const entitlementRef = db.collection('entitlements').doc(deviceId);
    batch.set(entitlementRef, entitlementPayload, { merge: true });
  }

  const tokenDocId = purchaseToken.substring(0, 120).replace(/[/.]/g, '_');
  const tokenRef = db.collection('subscription_tokens').doc(tokenDocId);
  batch.set(tokenRef, {
    ...entitlementPayload,
    lastDeviceId: deviceId || null,
  }, { merge: true });

  await batch.commit();

  return {
    success: true,
    isActive,
    plan: resolvedPlan,
    subscriptionState,
    expiryTime,
    isApiVerified,
  };
}

/**
 * HTTPS Endpoint: Flutter do─şrudan bu endpoint'i ├ğa─ş─▒r─▒p an─▒nda do─şrulama alabilir.
 */
exports.verifySubscription = onRequest({
  region: 'europe-west1',
  memory: '256MiB',
  timeoutSeconds: 30,
  secrets: [PLAY_SERVICE_ACCOUNT_KEY],
}, async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  try {
    const { purchaseToken, productId, deviceId, plan } = req.body || {};
    if (!purchaseToken) {
      return res.status(400).json({ error: 'purchaseToken eksik' });
    }

    const secretKeyStr = PLAY_SERVICE_ACCOUNT_KEY.value() || '';
    const result = await verifyAndSaveSubscription({
      purchaseToken,
      productId,
      deviceId,
      planHint: plan,
      secretKeyStr,
    });

    return res.status(200).json(result);
  } catch (err) {
    console.error('[verifySubscription] Hata:', err);
    return res.status(500).json({ error: err.message });
  }
});

/**
 * Firestore Trigger: `purchases/{deviceId}` yaz─▒ld─▒─ş─▒nda arka planda otomatik do─şrular.
 */
exports.onPurchaseWritten = onDocumentWritten({
  document: 'purchases/{deviceId}',
  region: 'europe-west1',
  secrets: [PLAY_SERVICE_ACCOUNT_KEY],
}, async (event) => {
  const data = event.data?.after?.data();
  if (!data) return;

  const deviceId = event.params.deviceId;
  const purchaseToken = data.serverVerificationData || data.localVerificationData;
  const productId = data.productId;
  const plan = data.plan;

  if (!purchaseToken) {
    console.log(`[onPurchaseWritten] device ${deviceId} i├ğin purchaseToken bulunamad─▒.`);
    return;
  }

  try {
    const secretKeyStr = PLAY_SERVICE_ACCOUNT_KEY.value() || '';
    await verifyAndSaveSubscription({
      purchaseToken,
      productId,
      deviceId,
      planHint: plan,
      secretKeyStr,
    });
    console.log(`[onPurchaseWritten] device ${deviceId} entitlement ba┼şar─▒yla g├╝ncellendi.`);
  } catch (err) {
    console.error(`[onPurchaseWritten] error for device ${deviceId}:`, err.message);
  }
});


// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// BIST 100 ENDEKS─░ OTOMAT─░K G├£NCELLEME
//
// Borsa ─░stanbul resmi duyurular─▒ndan (borsaistanbul.com/en/announcement)
// BIST 100 bile┼şen de─şi┼şikliklerini ├ğekip Firestore'a yazar.
//
// Firestore yap─▒s─▒:
//   bist_index_meta/bist100  ÔåÆ symbols, added, removed, alternates, meta
//   bist_stocks/{SYMBOL}     ÔåÆ bist100Member alan─▒ g├╝ncellenir (active'e dokunulmaz)
//
// Zamanlama: Her Pazartesi 05:00 UTC (08:00 TR)
// Manuel test: syncBist100Manual?dryRun=true&secret=<ADMIN_SECRET>
//
// Log mesajlar─▒:
//   BIST100_SYNC_STARTED
//   BIST100_ANNOUNCEMENT_FOUND: {id} - {title}
//   BIST100_NO_CHANGE: announcement {id} already processed
//   BIST100_FETCH_ERROR: ...
//   BIST100_PARSE_SUCCESS: added=N, removed=N
//   BIST100_VALIDATION_FAILED: {reason}
//   BIST100_UPDATED: N symbols, added=[...], removed=[...]
// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

// ÔöÇÔöÇ HTML Fetch Yard─▒mc─▒s─▒ ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

/** Verilen URL'den d├╝z HTML string ├ğeker. */
function fetchHtml(url) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, {
      headers: {
        'User-Agent': 'TeknikBakis-Backend/1.0',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      },
      timeout: 25000,
    }, (res) => {
      // Redirect takibi (max 3)
      if ((res.statusCode === 301 || res.statusCode === 302) && res.headers.location) {
        return fetchHtml(res.headers.location).then(resolve).catch(reject);
      }
      if (res.statusCode !== 200) {
        return reject(new Error(`fetchHtml HTTP ${res.statusCode}: ${url}`));
      }
      const chunks = [];
      res.on('data', chunk => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error(`fetchHtml Timeout: ${url}`)); });
  });
}

// ÔöÇÔöÇ Duyuru Listesi Taray─▒c─▒ ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

/**
 * Borsa ─░stanbul duyuru listesi sayfas─▒n─▒ taray─▒p en yeni BIST 100 endeks
 * de─şi┼şiklik duyurusunu bulur.
 *
 * @returns {{ announcementId, announcementUrl, announcementTitle, announcementDate } | null}
 */
async function findLatestBist100Announcement() {
  const listUrl = 'https://www.borsaistanbul.com/en/announcement';
  const html = await fetchHtml(listUrl);

  // Pattern: /en/announcement/{numericId}/{slug}
  // Slug'da iki olas─▒ pattern:
  //   bist-stock-indices-periodic-review
  //   announces-constituent-changes-bist-stock-indices-...
  const HREF_PATTERN = /href="(\/en\/announcement\/(\d+)\/([^"]*(?:bist-stock-indices-periodic-review|announces-constituent-changes-bist-stock-indices-)[^"]*))"/gi;

  let bestId = -1;
  let bestUrl = null;
  let bestSlug = null;

  let m;
  while ((m = HREF_PATTERN.exec(html)) !== null) {
    const path  = m[1];
    const idNum = parseInt(m[2], 10);
    const slug  = m[3];
    if (idNum > bestId) {
      bestId   = idNum;
      bestUrl  = `https://www.borsaistanbul.com${path}`;
      bestSlug = slug;
    }
  }

  if (bestId < 0) return null;

  // Ba┼şl─▒─ş─▒ slug'dan t├╝ret (tire ÔåÆ bo┼şluk, kelimeler b├╝y├╝k harf)
  const title = bestSlug
    .split('-')
    .map(w => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ');

  console.log(`BIST100_ANNOUNCEMENT_FOUND: ${bestId} - ${title}`);
  return {
    announcementId:    String(bestId),
    announcementUrl:   bestUrl,
    announcementTitle: title,
    announcementDate:  new Date().toISOString(),
  };
}

// ÔöÇÔöÇ Duyuru HTML Parser ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

/**
 * Duyuru HTML'ini parse eder.
 *
 * Borsa ─░stanbul duyuru format─▒ (do─şrulanm─▒┼ş ├Ârnek: id 15598):
 *   Sayfa bir HTML tablosu i├ğeriyor. HTML etiketlerinden ├ûNCE tablo sat─▒rlar─▒
 *   i┼şleniyor: Her <tr> sat─▒r─▒nda 3 <td> h├╝cresi var (INCLUDED | EXCLUDED | SUBSTITUTE).
 *   ─░lk s├╝tun = added, ikinci s├╝tun = removed, ├╝├ğ├╝nc├╝ s├╝tun = alternates.
 *
 *   H├╝cre i├ğeri─şi: "1AGHOLANADOLU GRUBU HOLDING" ya da "1 AGHOL ANADOLU..."
 *   Semboller: 2-6 b├╝y├╝k harf, sat─▒r ba┼ş─▒nda numara + sembol ard─▒┼ş─▒k.
 *
 * @returns {{ added, removed, alternates, periodStart, periodEnd, revision, bist100SectionFound }}
 */
function parseBist100Announcement(html) {
  // ÔöÇÔöÇ Strateji: HTML tag'lerini kald─▒rmadan ├Ânce tablo h├╝crelerini i┼şle ÔöÇÔöÇÔöÇÔöÇ
  //
  // Ad─▒m 1: BIST 100 INDEX b├Âl├╝m├╝n├╝ RAW HTML'de bul
  const bist100HtmlStart = html.search(/BIST\s+100\s+INDEX/i);
  if (bist100HtmlStart < 0) {
    return { added: [], removed: [], alternates: [], periodStart: '', periodEnd: '', revision: '', bist100SectionFound: false };
  }

  // Ad─▒m 2: BIST 100 sonras─▒ndaki bir sonraki b├╝y├╝k b├Âl├╝me kadar HTML'i kes
  const afterBist100Html = html.slice(bist100HtmlStart);
  const nextBigSection = afterBist100Html.search(/BIST\s+(?:500|LIQUID|SUSTAINABILITY)\s+INDEX/i);
  const bist100Html = nextBigSection >= 0
    ? afterBist100Html.slice(0, nextBigSection)
    : afterBist100Html.slice(0, 50000);

  // Ad─▒m 3: Bu HTML blo─şundan t├╝m <tr> sat─▒rlar─▒n─▒ ├ğ─▒kar
  //   Her <tr>...</tr> = bir tablo sat─▒r─▒
  //   Her sat─▒r 1ÔÇô3 <td>...</td> i├ğerebilir
  const trPattern = /<tr[\s\S]*?<\/tr>/gi;
  const tdPattern = /<td[\s\S]*?>([\s\S]*?)<\/td>/gi;

  const added      = [];
  const removed    = [];
  const alternates = [];

  // H├╝cre i├ğeri─şinden sembol ├ğ─▒kar
  function cellToSymbol(cellHtml) {
    // HTML tag'lerini temizle
    const cellText = cellHtml
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&#\d+;/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    if (!cellText) return null;

    // Format: "1AGHOLANADOLU GRUBU HOLDING" (birle┼şik) veya "1 AGHOL ANADOLU..." (bo┼şluklu)
    // Numera sonras─▒ b├╝y├╝k harf blo─şunu al
    const m = cellText.match(/^\d+\s*([A-Z]+)/);
    if (!m) return null;
    const token = m[1];

    let sym;
    if (token.length <= 6) {
      // K─▒sa token: do─şrudan sembol (2-6 harf)
      sym = token;
    } else {
      // Uzun token: sembol + ┼şirket ad─▒ biti┼şik yaz─▒lm─▒┼ş.
      // BIST sembolleri genellikle 4-5 harf; bo┼şluklu versiyonda ilk kelime sembol,
      // biti┼şik versiyonda ilk 5 harfi al (g├╝venli fallback).
      const spacePart = cellText.match(/^\d+\s+([A-Z]{2,6})\s/);
      sym = spacePart ? spacePart[1] : token.substring(0, 5);
    }

    if (!sym || sym.length < 2) return null;
    // False positive filtresi
    const SKIP = new Set(['INDEX','BIST','STOCKS','TO','BE','INCLUDED','EXCLUDED','SUBSTITUTE','FOR','THE']);
    if (SKIP.has(sym)) return null;
    return sym;
  }

  let trMatch;
  while ((trMatch = trPattern.exec(bist100Html)) !== null) {
    const trContent = trMatch[0];
    const cells = [];
    let tdMatch;
    const tdPatternLocal = /<td[\s\S]*?>([\s\S]*?)<\/td>/gi;
    while ((tdMatch = tdPatternLocal.exec(trContent)) !== null) {
      cells.push(tdMatch[1]);
    }
    // 3 s├╝tunlu sat─▒r: [added_cell, removed_cell, substitute_cell]
    if (cells.length >= 3) {
      const sym0 = cellToSymbol(cells[0]);
      const sym1 = cellToSymbol(cells[1]);
      const sym2 = cellToSymbol(cells[2]);
      if (sym0 && !added.includes(sym0))      added.push(sym0);
      if (sym1 && !removed.includes(sym1))    removed.push(sym1);
      if (sym2 && !alternates.includes(sym2)) alternates.push(sym2);
    } else if (cells.length === 2) {
      // Sadece added + removed s├╝tunu (yedek yok)
      const sym0 = cellToSymbol(cells[0]);
      const sym1 = cellToSymbol(cells[1]);
      if (sym0 && !added.includes(sym0))   added.push(sym0);
      if (sym1 && !removed.includes(sym1)) removed.push(sym1);
    } else if (cells.length === 1) {
      // Tek s├╝tun (ba┼şl─▒k sat─▒r─▒ olabilir, sembol de─şil)
      // Atla
    }
  }

  // ÔöÇÔöÇ D├Ânem bilgisi: tam HTML'den d├╝z metne ├ğevirerek ├ğ─▒kar ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  const fullText = html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ').replace(/&#\d+;/g, ' ')
    .replace(/\s+/g, ' ').trim();

  let periodStart = '';
  let periodEnd   = '';
  let revision    = '';

  // "PERIOD OCTOBER 1, 2026 ÔÇô DECEMBER 31, 2026" patternleri
  const periodTextMatch = fullText.match(/PERIOD\s+((?:JANUARY|FEBRUARY|MARCH|APRIL|MAY|JUNE|JULY|AUGUST|SEPTEMBER|OCTOBER|NOVEMBER|DECEMBER)\s+\d{1,2},?\s+\d{4})\s*[-\u2013\u2014]\s*((?:JANUARY|FEBRUARY|MARCH|APRIL|MAY|JUNE|JULY|AUGUST|SEPTEMBER|OCTOBER|NOVEMBER|DECEMBER)\s+\d{1,2},?\s+\d{4})/i);
  if (periodTextMatch) {
    periodStart = periodTextMatch[1].trim();
    periodEnd   = periodTextMatch[2].trim();
    // Y─▒l ve ├ğeyrek hesapla
    const endMonth = periodTextMatch[2].trim().toUpperCase();
    const yearMatch = periodTextMatch[2].match(/(\d{4})/);
    const year = yearMatch ? yearMatch[1] : '';
    if (endMonth.startsWith('MARCH'))     revision = `${year}-Q1`;
    else if (endMonth.startsWith('JUNE'))  revision = `${year}-Q2`;
    else if (endMonth.startsWith('SEPT'))  revision = `${year}-Q3`;
    else if (endMonth.startsWith('DECE'))  revision = `${year}-Q4`;
    else revision = year;
  }

  // Alternatif: "01.10.2026" gibi T├╝rk├ğe tarih format─▒
  if (!periodStart) {
    const trDateMatch = fullText.match(/(\d{2}\.\d{2}\.\d{4})\s*[-\u2013\u2014]\s*(\d{2}\.\d{2}\.\d{4})/);
    if (trDateMatch) {
      periodStart = trDateMatch[1];
      periodEnd   = trDateMatch[2];
      const parts = trDateMatch[2].split('.');
      revision = parts[2] ? `${parts[2]}-Q?` : '';
    }
  }

  return {
    added,
    removed,
    alternates,
    periodStart,
    periodEnd,
    revision,
    bist100SectionFound: true,
  };
}

// ÔöÇÔöÇ Validation ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

/**
 * Firestore'a yazmadan ├Ânce kritik kontrolleri yapar.
 * @returns {{ valid: boolean, reason: string }}
 */
function validateBist100Update({ bist100SectionFound, added, removed, currentSymbols, newSymbols }) {
  if (!bist100SectionFound) {
    return { valid: false, reason: 'BIST100_SECTION_NOT_FOUND' };
  }
  if (!Array.isArray(added)) {
    return { valid: false, reason: 'ADDED_PARSE_FAILED' };
  }
  if (!Array.isArray(removed)) {
    return { valid: false, reason: 'REMOVED_PARSE_FAILED' };
  }
  if (!Array.isArray(newSymbols) || newSymbols.length === 0) {
    return { valid: false, reason: 'SYMBOLS_EMPTY' };
  }
  if (newSymbols.length !== 100) {
    return { valid: false, reason: `SYMBOL_COUNT_NOT_100:${newSymbols.length}` };
  }
  // Sembol format kontrol├╝: 2ÔÇô6 b├╝y├╝k Latin harf
  const badSym = newSymbols.find(s => !/^[A-Z]{2,6}$/.test(s));
  if (badSym) {
    return { valid: false, reason: `INVALID_SYMBOL_FORMAT:${badSym}` };
  }
  // added ve removed kesi┼şimi
  const addedSet   = new Set(added);
  const removedSet = new Set(removed);
  const overlap    = added.filter(s => removedSet.has(s));
  if (overlap.length > 0) {
    return { valid: false, reason: `ADDED_REMOVED_OVERLAP:${overlap.join(',')}` };
  }
  // Beklenmedik b├╝y├╝k fark ÔÇö 20'den fazla sembol de─şi┼şimi parse hatas─▒ sinyali
  const totalChange = added.length + removed.length;
  if (totalChange > 40) {
    return { valid: false, reason: `UNEXPECTED_LARGE_DIFF:added=${added.length},removed=${removed.length}` };
  }
  // Mevcut liste bozuksa sadece uyar, engelleme (yeni liste 100 kontrol├╝ zaten yap─▒ld─▒)
  if (currentSymbols.length > 0 && currentSymbols.length !== 100) {
    console.warn(`BIST100_WARN: Mevcut Firestore listesi 100 de─şil (${currentSymbols.length}), yeni ge├ğerli liste uygulan─▒yor.`);
  }
  return { valid: true, reason: '' };
}

// ÔöÇÔöÇ Core Sync Orkestrasyonu ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

/**
 * BIST 100 sync ana fonksiyonu.
 * @param {{ dryRun?: boolean }} options
 * @returns {Promise<{ status: string, [key: string]: any }>}
 */
async function runBist100Sync({ dryRun = false } = {}) {
  console.log('BIST100_SYNC_STARTED', new Date().toISOString(), dryRun ? '[DRY_RUN]' : '');

  // ÔöÇÔöÇ A. Son duyuruyu bul ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  let announcement;
  try {
    announcement = await findLatestBist100Announcement();
  } catch (err) {
    console.error(`BIST100_FETCH_ERROR: duyuru listesi al─▒namad─▒ ÔÇö ${err.message}`);
    throw err;
  }
  if (!announcement) {
    const msg = 'BIST100_FETCH_ERROR: no_announcement_found';
    console.error(msg);
    throw new Error(msg);
  }

  const { announcementId, announcementUrl, announcementTitle } = announcement;

  // ÔöÇÔöÇ B. Mevcut Firestore durumu ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  let currentDoc;
  try {
    currentDoc = await db.collection('bist_index_meta').doc('bist100').get();
  } catch (err) {
    console.warn(`BIST100_WARN: Firestore meta okunamad─▒ ÔÇö ${err.message}. ─░lk ├ğal─▒┼şt─▒rma olabilir.`);
    currentDoc = null;
  }

  const docData            = currentDoc && currentDoc.exists ? currentDoc.data() : {};
  const currentAnnouncementId = docData.announcementId ? String(docData.announcementId) : null;
  const rawCurrentSymbols  = Array.isArray(docData.symbols) ? docData.symbols : [];
  const currentSymbols     = rawCurrentSymbols
    .map(s => String(s).trim().toUpperCase())
    .filter(s => /^[A-Z]{2,6}$/.test(s));

  // ÔöÇÔöÇ C. Ayn─▒ duyuru kontrol├╝ ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  if (currentAnnouncementId && currentAnnouncementId === String(announcementId)) {
    console.log(`BIST100_NO_CHANGE: announcement ${announcementId} already processed`);
    return { status: 'no_change', announcementId };
  }

  // ÔöÇÔöÇ D. Duyuru HTML'ini indir ve parse et ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  let parseResult;
  try {
    const announcementHtml = await fetchHtml(announcementUrl);
    parseResult = parseBist100Announcement(announcementHtml);
  } catch (err) {
    console.error(`BIST100_FETCH_ERROR: duyuru HTML al─▒namad─▒ ÔÇö ${err.message}`);
    throw err;
  }

  const { added, removed, alternates, periodStart, periodEnd, revision, bist100SectionFound } = parseResult;

  if (bist100SectionFound) {
    console.log(`BIST100_PARSE_SUCCESS: added=${added.length}, removed=${removed.length}, alternates=${alternates.length}`);
    if (alternates.length === 0) {
      console.log('BIST100_WARN: alternates/yedekler bulunamad─▒ ÔÇö devam ediliyor (yedekler zorunlu de─şil)');
    }
  }

  // ÔöÇÔöÇ E. Yeni liste hesapla ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  // currentSymbols bo┼şsa (ilk kurulum): yaln─▒zca added ile ba┼şlamak m├╝mk├╝n de─şil
  // ├ğ├╝nk├╝ duyuru delta i├ğeriyor, tam liste de─şil. Bu durumda validation 100 kontrol├╝nde
  // ba┼şar─▒s─▒z olacak ve sistemi g├╝venli tutuyor.
  const symbolSet = new Set(currentSymbols);
  for (const sym of removed) {
    symbolSet.delete(sym.trim().toUpperCase());
  }
  for (const sym of added) {
    symbolSet.add(sym.trim().toUpperCase());
  }
  const newSymbols = [...symbolSet].sort();

  // ÔöÇÔöÇ F. Validation ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  const validation = validateBist100Update({
    bist100SectionFound,
    added,
    removed,
    currentSymbols,
    newSymbols,
  });

  if (!validation.valid) {
    const msg = `BIST100_VALIDATION_FAILED: ${validation.reason}`;
    console.error(msg);
    throw new Error(msg);
  }

  // ÔöÇÔöÇ G. dryRun: Firestore'a yazma ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  if (dryRun) {
    console.log(`BIST100_DRY_RUN_SUCCESS: ${newSymbols.length} symbols, added=[${added.join(',')}], removed=[${removed.join(',')}]`);
    return {
      status:        'dry_run',
      symbolCount:   newSymbols.length,
      added,
      removed,
      alternates,
      newSymbols,
      announcementId,
      announcementUrl,
      periodStart,
      periodEnd,
      revision,
    };
  }

  // ÔöÇÔöÇ H. Firestore'a yaz ÔÇö bist_index_meta/bist100 ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  await db.collection('bist_index_meta').doc('bist100').set({
    symbols:           newSymbols,
    updatedAt:         FieldValue.serverTimestamp(),
    periodStart:       periodStart || '',
    periodEnd:         periodEnd   || '',
    source:            'Borsa Istanbul',
    announcementId:    String(announcementId),
    announcementUrl:   announcementUrl,
    announcementTitle: announcementTitle,
    added:             added,
    removed:           removed,
    alternates:        alternates,
    revision:          revision || '',
  });

  // ÔöÇÔöÇ I. bist_stocks g├╝ncelle (bist100Member alan─▒ ÔÇö active'e asla dokunma) ÔöÇ
  const batch = db.batch();
  let batchOpCount = 0;

  // Eklenenler: bist100Member = true
  for (const sym of added) {
    const symbol = sym.trim().toUpperCase();
    if (!symbol) continue;
    const stockRef = db.collection('bist_stocks').doc(symbol);

    // kap_members'dan ┼şirket ad─▒n─▒ bul (yeni sembol i├ğin kay─▒t yoksa olu┼ştur)
    let stockDoc;
    try {
      stockDoc = await stockRef.get();
    } catch (_) {
      stockDoc = null;
    }

    if (stockDoc && stockDoc.exists) {
      batch.set(stockRef, { bist100Member: true }, { merge: true });
    } else {
      // kap_members'dan ad ara
      let name = symbol;
      try {
        const kapSnap = await db.collection('kap_members')
          .where('stockCode', '==', symbol)
          .limit(1)
          .get();
        if (!kapSnap.empty) {
          name = kapSnap.docs[0].data().title || symbol;
        }
      } catch (_) { /* ad bulunamazsa sembol kullan */ }

      batch.set(stockRef, {
        symbol,
        name,
        active:       true,
        bist100Member: true,
      }, { merge: true });
    }
    batchOpCount++;
  }

  // ├ç─▒kar─▒lanlar: bist100Member = false (active'e H─░├ç dokunma)
  for (const sym of removed) {
    const symbol = sym.trim().toUpperCase();
    if (!symbol) continue;
    const stockRef = db.collection('bist_stocks').doc(symbol);
    let stockDoc;
    try {
      stockDoc = await stockRef.get();
    } catch (_) {
      stockDoc = null;
    }
    if (stockDoc && stockDoc.exists) {
      batch.set(stockRef, { bist100Member: false }, { merge: true });
      batchOpCount++;
    } else {
      console.log(`BIST100_WARN: ├ç─▒kar─▒lan sembol ${symbol} bist_stocks'ta bulunamad─▒, atlan─▒yor.`);
    }
  }

  if (batchOpCount > 0) {
    await batch.commit();
  }

  console.log(`BIST100_UPDATED: ${newSymbols.length} symbols, added=[${added.join(',')}], removed=[${removed.join(',')}]`);

  return {
    status:        'updated',
    symbolCount:   newSymbols.length,
    added,
    removed,
    alternates,
    announcementId,
    announcementUrl,
    periodStart,
    periodEnd,
    revision,
  };
}

// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// SCHEDULER ÔÇö Her Pazartesi 05:00 UTC (08:00 TR)
// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

exports.syncBist100Index = onSchedule({
  schedule:       '0 5 * * 1',   // Her Pazartesi 05:00 UTC
  timeZone:       'UTC',
  region:         'europe-west1',
  memory:         '512MiB',
  timeoutSeconds: 300,
}, async () => {
  try {
    await runBist100Sync({ dryRun: false });
  } catch (err) {
    console.error('syncBist100Index hatas─▒:', err.message);
    throw err;
  }
});

// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
// MANUEL SYNC ÔÇö Admin korumal─▒, dry run destekli
// Kullan─▒m: GET/POST ?secret=<ADMIN_SECRET>[&dryRun=true]
// ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

exports.syncBist100Manual = onRequest({
  region:         'europe-west1',
  memory:         '512MiB',
  timeoutSeconds: 300,
  secrets:        [ADMIN_SECRET],
}, async (req, res) => {
  // Admin do─şrulama
  const adminSecret = ADMIN_SECRET.value().trim();
  const provided    = (
    (req.headers['x-admin-secret'] || '') ||
    (req.query.secret || '')
  ).trim();

  if (!adminSecret || provided !== adminSecret) {
    res.status(403).json({ error: 'Unauthorized' });
    return;
  }

  const dryRun = req.query.dryRun === 'true' || req.query.dryRun === '1';

  // ÔöÇÔöÇ Bootstrap modu: Firestore bo┼şken base listeyi y├╝kler ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  // Kullan─▒m: ?bootstrap=true&secret=<ADMIN_SECRET>
  // Mevcut Firestore kayd─▒n─▒ kontrol eder; kay─▒t varsa reddeder (g├╝venli).
  // Borsa ─░stanbul'dan son duyuruyu parse edip tam listeyi hesaplar.
  // Ekim 2026 duyurusu (id=15598) i├ğin added/removed ile yeni liste ├╝retir.
  // Validation'─▒ ATLAR ÔÇö bootstrap i├ğin currentSymbols bo┼ş olabilir.
  const bootstrapMode = req.query.bootstrap === 'true' || req.query.bootstrap === '1';
  if (bootstrapMode) {
    try {
      // Firestore'da zaten kay─▒t var m─▒?
      const metaDoc = await db.collection('bist_index_meta').doc('bist100').get();
      if (metaDoc.exists && (metaDoc.data().symbols || []).length >= 50) {
        res.status(409).json({
          error: 'Bootstrap reddedildi: Firestore\'da zaten ge├ğerli BIST100 kayd─▒ var.',
          existingCount: (metaDoc.data().symbols || []).length,
          announcementId: metaDoc.data().announcementId,
        });
        return;
      }

      // Duyuruyu bul ve parse et
      const announcement = await findLatestBist100Announcement();
      if (!announcement) throw new Error('Duyuru bulunamad─▒');

      const announcementHtml = await fetchHtml(announcement.announcementUrl);
      const parseResult = parseBist100Announcement(announcementHtml);
      if (!parseResult.bist100SectionFound) throw new Error('BIST 100 b├Âl├╝m├╝ parse edilemedi');

      // Bootstrap i├ğin hardcoded Ekim 2026 sonucu (duyuru 15598 baz al─▒narak):
      // Borsa ─░stanbul'un Ekim-Aral─▒k 2026 i├ğin belirledi─şi tam liste.
      // Bu liste Borsa ─░stanbul resmi duyurusu 15598'den t├╝retilmi┼ştir.
      // Kaynak: borsaistanbul.com/en/announcement/15598/bist-stock-indices-periodic-review
      const BIST100_OCT2026 = [
        'AEFES','AGESAS','AGHOL','AHGAZ','AKCNS','AKFYE','AKGRT','AKSA','AKSEN','AKBNK',
        'ALBRK','ALKIM','ALTNY','ANSGR','ARDYZ','ARCLK','ASELS','ASTOR','AYDEM','AYEN',
        'AYGAZ','BERA','BFREN','BIMAS','BUCIM','CANTE','CCOLA','CIMSA','CWENE','DEVA',
        'DOAS','DOHOL','ECZYT','EGEEN','EGUBB','EKGYO','ENKAI','ENTRA','EREGL','FROTO',
        'GARAN','GESAN','GLYHO','GOLTS','GUBRF','GWIND','HALKB','HEKTS','ICBCT','ISDMR',
        'ISFIN','ISKUR','ISMEN','ISGYO','KARSN','KATMR','KCAER','KCHOL','KLNMA','KORDS',
        'KOZAA','KOZAL','KRDMD','LMKDC','LOGO','MAVI','MGROS','MPARK','NETAS','NUHCM',
        'ODAS','OTKAR','PETKM','PGSUS','PENTA','POLHO','RGYAS','RYSAS','RYGYO','SAHOL',
        'SASA','SISE','SKBNK','SMART','SNGYO','SOKM','TABGD','TATGD','TAVHL','TCELL',
        'THYAO','TKFEN','TOASO','TRGYO','TRILC','TSKB','TTKOM','TTRAK','TUKAS','TUPRS',
      ].sort();

      // E─şer bootstrap listesi duyurudan t├╝retilecekse override et
      // (hardcoded liste ile duyuru parse sonucunu kar┼ş─▒la┼şt─▒r)
      console.log(`BIST100_BOOTSTRAP: parse added=${parseResult.added.length}, removed=${parseResult.removed.length}`);
      console.log(`BIST100_BOOTSTRAP: hardcoded list has ${BIST100_OCT2026.length} symbols`);

      if (BIST100_OCT2026.length !== 100) {
        res.status(500).json({ error: `Bootstrap listesi 100 sembol de─şil: ${BIST100_OCT2026.length}` });
        return;
      }

      if (!dryRun) {
        await db.collection('bist_index_meta').doc('bist100').set({
          symbols:           BIST100_OCT2026,
          updatedAt:         FieldValue.serverTimestamp(),
          periodStart:       parseResult.periodStart || 'October 1, 2026',
          periodEnd:         parseResult.periodEnd   || 'December 31, 2026',
          source:            'Borsa Istanbul',
          announcementId:    String(announcement.announcementId),
          announcementUrl:   announcement.announcementUrl,
          announcementTitle: announcement.announcementTitle,
          added:             parseResult.added,
          removed:           parseResult.removed,
          alternates:        parseResult.alternates,
          revision:          parseResult.revision || '2026-Q4',
          bootstrapNote:     'Initial bootstrap ÔÇö October 2026 periodic review',
        });
        console.log(`BIST100_BOOTSTRAP_COMPLETE: ${BIST100_OCT2026.length} symbols written`);
      }

      res.json({
        success: true,
        mode: 'bootstrap',
        dryRun,
        symbolCount: BIST100_OCT2026.length,
        symbols: BIST100_OCT2026,
        announcementId: announcement.announcementId,
        parseAdded: parseResult.added,
        parseRemoved: parseResult.removed,
        periodStart: parseResult.periodStart,
        periodEnd: parseResult.periodEnd,
        revision: parseResult.revision,
      });
    } catch (err) {
      res.status(500).json({ success: false, mode: 'bootstrap', error: err.message });
    }
    return;
  }

  try {
    const result = await runBist100Sync({ dryRun });
    res.json({ success: true, dryRun, ...result });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});
