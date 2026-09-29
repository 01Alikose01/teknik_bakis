/**
 * Firebase Cloud Function — KAP Bildirim + Temel Göstergeler Güncelleyici
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * KAP MKK BİLDİRİM SYNC SİSTEMİ
 *
 * MKK VYK API'sinden KAP bildirimlerini merkezi olarak çeker.
 * Flutter uygulaması KAP API'ye HİÇBİR ZAMAN direkt bağlanmaz.
 * API credentials sadece Cloud Function environment'ında tutulur.
 * 1000+ kullanıcı Firestore'dan okur → KAP/MKK API'ye tek istek biz atarız.
 *
 * Zamanlama stratejisi (Türkiye saati = UTC+3):
 *
 *   syncKapOpeningWindow  — Her gün 06:55–07:30 UTC (09:55–10:30 TR)
 *                           Her 5 dakikada bir → borsa açılış verilerini hızlı yakalar
 *                           cron: 55 6 * * *        → 09:55 TR
 *                                 0,5,10,15,20,25,30 7 * * *  → 10:00–10:30 TR
 *
 *   syncKapDisclosures    — Her gün sürekli, 15 dakikada bir (tüm gün)
 *                           cron: '* /15 * * * *' → günde 96x çalışır
 *                           Açılış penceresi dışındaki saatleri kapsar.
 *                           openingWindow zaten 09:55–10:30 arası daha sık çalışır,
 *                           15dk'lık genel sync onları da kapsadığı için
 *                           ikisi birlikte çalışmak sorun değil (idempotent UPSERT).
 *
 * Firestore yapısı:
 *   kap_members/{id}         — Şirket listesi
 *   kap_disclosures/{index}  — Bildirimler (UPSERT)
 *   kap_sync_logs/{id}       — Sync logları
 *   meta/kap                 — Son sync zamanı, lastDisclosureIndex
 *
 * Environment Variables (Firebase Secret Manager'dan okunur):
 *   KAP_API_KEY  — MKK VYK API anahtarı
 *   KAP_TOKEN    — MKK VYK Bearer token
 *
 * KAP API base URL: https://apigwdev.mkk.com.tr/api/vyk/
 * ─────────────────────────────────────────────────────────────────────────────
 */

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest }  = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp }  = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const https = require('https');

initializeApp();
const db = getFirestore();

// ── KAP API Secrets (Firebase Secret Manager) ────────────────────────────────
const KAP_API_KEY  = defineSecret('KAP_API_KEY');
const KAP_TOKEN    = defineSecret('KAP_TOKEN');
const ADMIN_SECRET = defineSecret('ADMIN_SECRET'); // Manuel sync koruması
const NVIDIA_API_KEY = defineSecret('NVIDIA_API_KEY'); // NVIDIA NIM AI API

// ── KAP API base ─────────────────────────────────────────────────────────────
const KAP_BASE = 'https://apigwdev.mkk.com.tr/api/vyk';

// ── Retry yapılandırması ─────────────────────────────────────────────────────
const RETRY_DELAYS_MS = [0, 30_000, 120_000]; // anında, 30s, 2dk

// ─────────────────────────────────────────────────────────────────────────────
// YARDIMCI FONKSİYONLAR
// ─────────────────────────────────────────────────────────────────────────────

/** HTTPS GET ile JSON çeker. apiKey ve token parametrelerini header'a ekler. */
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
          catch (e) { reject(new Error(`JSON parse hatası (${path}): ${e.message}`)); }
        } else {
          reject(new Error(`HTTP ${res.statusCode} — ${path} — ${body.substring(0, 200)}`));
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error(`Timeout: ${path}`)); });
    req.end();
  });
}

/** BilancoVeri için genel JSON fetch (credentials gerektirmez). */
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
        catch (e) { reject(new Error('JSON parse hatası: ' + e.message)); }
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('Timeout')); });
  });
}

/** Retry wrapper — otomatik yeniden deneme. */
async function withRetry(fn, label) {
  let lastErr;
  for (let attempt = 0; attempt < RETRY_DELAYS_MS.length; attempt++) {
    if (attempt > 0) {
      console.log(`${label} — ${attempt}. yeniden deneme (${RETRY_DELAYS_MS[attempt] / 1000}s sonra)...`);
      await new Promise(r => setTimeout(r, RETRY_DELAYS_MS[attempt]));
    }
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      console.warn(`${label} — deneme ${attempt + 1} başarısız:`, err.message);
    }
  }
  throw lastErr;
}

// ─────────────────────────────────────────────────────────────────────────────
// KAP ŞİRKET LİSTESİ SYNC
// ─────────────────────────────────────────────────────────────────────────────

async function syncMembers(apiKey, token) {
  console.log('Şirket listesi senkronizasyonu başladı...');
  const data = await kapGet('/members', apiKey, token);

  // API dizi döndürebilir veya { data: [...] } formatında olabilir
  const members = Array.isArray(data) ? data : (data.data || data.items || data.members || []);
  if (members.length === 0) throw new Error('Şirket listesi boş geldi');

  console.log(`${members.length} şirket alındı`);

  // Duplicate temizleme: aynı id için kfifUrl olan kaydı tercih et
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

  console.log(`Şirket listesi tamamlandı: ${written} kayıt`);
  return written;
}

// ─────────────────────────────────────────────────────────────────────────────
// KAP BİLDİRİMLER SYNC
// ─────────────────────────────────────────────────────────────────────────────

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

  // Önce mevcut son index'i KAP'tan öğren
  let currentMaxIndex;
  try {
    const latestData = await kapGet('/lastDisclosureIndex', apiKey, token);
    currentMaxIndex = latestData.lastDisclosureIndex || latestData.index || latestData;
    console.log(`Son bildirim index: ${currentMaxIndex}, son sync index: ${lastIndex}`);
  } catch (err) {
    console.warn('lastDisclosureIndex alınamadı, tüm yeni bildirimleri çekmeye devam:', err.message);
    currentMaxIndex = null;
  }

  // Eğer değişiklik yoksa atla
  if (currentMaxIndex && Number(currentMaxIndex) <= Number(lastIndex)) {
    console.log('Yeni bildirim yok, sync atlandı');
    return { added: 0, updated: 0 };
  }

  // Yeni bildirimleri çek — lastIndex'ten sonrasını al
  const queryParams = {
    disclosureIndex: lastIndex > 0 ? lastIndex : undefined,
  };

  const data = await kapGet('/disclosures', apiKey, token, queryParams);
  const disclosures = Array.isArray(data) ? data : (data.data || data.items || data.disclosures || []);

  if (disclosures.length === 0) {
    console.log('Yeni bildirim bulunamadı');
    return { added: 0, updated: 0 };
  }

  console.log(`${disclosures.length} bildirim alındı`);

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

  console.log(`Bildirim sync tamamlandı: ${added} yeni, ${updated} güncellendi`);
  return { added, updated };
}

// ─────────────────────────────────────────────────────────────────────────────
// SYNC LOG
// ─────────────────────────────────────────────────────────────────────────────

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
    console.error('Sync log yazılamadı:', err.message);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANA SYNC FONKSİYONU
// ─────────────────────────────────────────────────────────────────────────────

async function runKapSync(apiKey, token, trigger = 'scheduled') {
  const startedAt = new Date();
  console.log(`KAP sync başladı [${trigger}]:`, startedAt.toISOString());

  let syncResult = { added: 0, updated: 0 };
  let syncError  = null;

  try {
    // Şirket listesi (günde 1 kez yeterli, sabah sync'te yapılır)
    if (trigger === 'scheduled' || trigger === 'manual') {
      await withRetry(() => syncMembers(apiKey, token), 'syncMembers');
    }

    // Bildirimler
    syncResult = await withRetry(() => syncDisclosures(apiKey, token), 'syncDisclosures');

    // Meta güncelle
    await db.collection('meta').doc('kap').set({
      lastSuccessfulSync: FieldValue.serverTimestamp(),
      lastSyncStatus:     'success',
    }, { merge: true });

  } catch (err) {
    syncError = err.message;
    console.error('KAP sync hatası:', err.message);

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

// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULED FUNCTION 1 — Açılış Penceresi: 09:55–10:30 Türkiye (UTC+3)
//
//   Her 5 dakikada bir çalışır, borsa açılışında bildirimleri hızlı yakalar.
//   Türkiye 09:55 = UTC 06:55  →  cron: 55 6 * * *
//   Türkiye 10:00–10:30        →  cron: 0,5,10,15,20,25,30 7 * * *
//
//   1000+ kullanıcı varken bile KAP/MKK API'ye tek istek biz atarız,
//   kullanıcılar Firestore'dan okur → rate-limit veya block riski sıfır.
// ─────────────────────────────────────────────────────────────────────────────

// 09:55 TR (UTC 06:55) — açılış öncesi son hazırlık
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

// 10:00, 10:05, 10:10, 10:15, 10:20, 10:25, 10:30 TR (UTC 07:xx) — açılış penceresi
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

// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULED FUNCTION 2 — Sürekli Sync: Her 15 dakikada bir (tüm gün)
//
//   Açılış penceresi dışındaki tüm seansı ve gün içi bildirimleri yakalar.
//   Açılış penceresiyle çakışsa da UPSERT idempotent olduğu için sorun yok.
//   Günde 96 çalışır; Firestore yazma maliyeti ihmal edilebilir seviyede.
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// MANUEL SYNC — Sadece admin yetkisiyle
// ─────────────────────────────────────────────────────────────────────────────

exports.syncKapManual = onRequest({
  region:  'europe-west1',
  memory:  '512MiB',
  timeoutSeconds: 300,
  secrets: [KAP_API_KEY, KAP_TOKEN, ADMIN_SECRET],
}, async (req, res) => {
  // Admin doğrulama — secret değerini trim et (echo'dan gelen \n)
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

// ─────────────────────────────────────────────────────────────────────────────
// BilancoVeri — Temel Göstergeler (mevcut, değişmedi)
// ─────────────────────────────────────────────────────────────────────────────

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
    console.log(`Yazıldı: ${written}/${items.length}`);
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
    if (items.length === 0) { console.warn('Veri boş geldi'); return; }
    await writeBatch(items);
    await db.collection('meta').doc('fundamentals').set({
      lastUpdatedAt: FieldValue.serverTimestamp(),
      tickerCount:   items.length,
      source:        'BilancoVeri/KAP',
    });
  } catch (err) { console.error('Güncelleme hatası:', err); throw err; }
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

// ── Yardımcı: HTTPS GET → JSON ──────────────────────────────────────────────
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
        catch (e) { reject(new Error('JSON parse hatası: ' + e.message)); }
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('Timeout')); });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// HALKA ARZ (IPO) SYNC — HalkArz.com → Firestore
// Her 6 saatte bir çalışır. Uygulama artık GitHub yerine Firestore'a bakar.
//
// Firestore yapısı:
//   ipo_items/{symbol}        — Her hisse bir belge
//   ipo_meta/feed             — lastUpdated, itemCount, source
// ─────────────────────────────────────────────────────────────────────────────

const HALKARZ_UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36';
const TR_MONTHS = {
  ocak:0, subat:1, mart:2, nisan:3, mayis:4, haziran:5,
  temmuz:6, agustos:7, eylul:8, ekim:9, kasim:10, aralik:11,
};

function cleanTxt(v) {
  return v == null ? '' : String(v).replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
}
function toIso(date) {
  return (date instanceof Date && !isNaN(date)) ? date.toISOString() : '';
}

function parseTrDateRange(text) {
  const norm = cleanTxt(text).toLowerCase()
    .replace(/ğ/g,'g').replace(/ç/g,'c').replace(/ş/g,'s')
    .replace(/ü/g,'u').replace(/ö/g,'o').replace(/ı/g,'i');

  // "9-10-11 eylul 2026"
  const m1 = norm.match(/^(\d{1,2})[-\s]+(?:\d{1,2}[-\s]+)*(\d{1,2})\s+([a-z]+)\s+(\d{4})/);
  if (m1) {
    const mo = TR_MONTHS[m1[3]];
    if (mo !== undefined) {
      const yr = parseInt(m1[4]);
      return { start: new Date(yr, mo, parseInt(m1[1]), 12, 0, 0),
               end:   new Date(yr, mo, parseInt(m1[2]), 12, 0, 0) };
    }
  }
  // "31 temmuz - 2 agustos 2026"
  const m2 = norm.match(/^(\d{1,2})\s+([a-z]+)\s*-\s*(\d{1,2})\s+([a-z]+)\s+(\d{4})/);
  if (m2) {
    const sm = TR_MONTHS[m2[2]], em = TR_MONTHS[m2[4]];
    if (sm !== undefined && em !== undefined) {
      const yr = parseInt(m2[5]);
      return { start: new Date(yr, sm, parseInt(m2[1]), 12, 0, 0),
               end:   new Date(yr, em, parseInt(m2[3]), 12, 0, 0) };
    }
  }
  // "6 agustos 2026"
  const m3 = norm.match(/^(\d{1,2})\s+([a-z]+)\s+(\d{4})/);
  if (m3) {
    const mo = TR_MONTHS[m3[2]];
    if (mo !== undefined) {
      const d = new Date(parseInt(m3[3]), mo, parseInt(m3[1]), 12, 0, 0);
      return { start: d, end: d };
    }
  }
  return { start: null, end: null };
}

function deriveIpoStatus({ requestStart, requestEnd, listingDate }) {
  const now = new Date();
  if (listingDate && listingDate <= now) return 'trading';
  if (requestEnd) {
    const endOfDay = new Date(requestEnd.getFullYear(), requestEnd.getMonth(), requestEnd.getDate(), 23, 59, 59);
    if (now > endOfDay) {
      if (listingDate && listingDate <= now) return 'trading';
      if (listingDate && listingDate > now) return 'pending_listing';
      return 'pending_listing';
    }
  }
  if (requestStart) {
    const startOfDay = new Date(requestStart.getFullYear(), requestStart.getMonth(), requestStart.getDate());
    return now < startOfDay ? 'upcoming' : 'collecting';
  }
  if (listingDate) {
    const lStart = new Date(listingDate.getFullYear(), listingDate.getMonth(), listingDate.getDate());
    return now < lStart ? 'upcoming' : 'trading';
  }
  return 'upcoming';
}

async function fetchHalkArzItems() {
  const homeRes = await fetch('https://halkarz.com/', {
    headers: { 'User-Agent': HALKARZ_UA },
    signal: AbortSignal.timeout(20000),
  });
  if (!homeRes.ok) throw new Error(`HalkArz ana sayfa: HTTP ${homeRes.status}`);

  const html = await homeRes.text();
  const articles = html.split('<article class="index-list');
  const pageItems = [];

  for (let i = 1; i < Math.min(articles.length, 21); i++) {
    const chunk = articles[i].split('</article>')[0];
    const nm = chunk.match(/class="il-halka-arz-sirket"[^>]*>.*?<a\s+href="([^"]+)"[^>]*>(.*?)<\/a>/s);
    if (!nm) continue;
    const cm = chunk.match(/class="il-bist-kod"\s*>([^<]+)/s);
    const dm = chunk.match(/<time datetime="([^"]+)"/);
    pageItems.push({
      companyName: cleanTxt(nm[2]),
      symbol: cm ? cleanTxt(cm[1]).toUpperCase() : '',
      url: nm[1],
      requestDates: dm ? cleanTxt(dm[1]) : '',
    });
  }

  console.log(`HalkArz: ${pageItems.length} hisse, detaylar çekiliyor...`);
  const results = [];

  for (const item of pageItems) {
    try {
      await new Promise(r => setTimeout(r, 500));
      const dRes = await fetch(item.url, {
        headers: { 'User-Agent': HALKARZ_UA },
        signal: AbortSignal.timeout(15000),
      });
      if (!dRes.ok) continue;
      const dHtml = await dRes.text();

      const priceM = dHtml.match(/Halka\s+Arz\s+Fiyat[^<]*<\/td>\s*<td[^>]*>(?:<strong[^>]*>)?(.*?)(?:<\/strong>)?<\/td>/is);
      const distM  = dHtml.match(/Da[gğ][iı]t[iı]m\s+Y[oö]ntemi[^<]*<\/td>\s*<td[^>]*>(?:<strong[^>]*>)?(.*?)(?:<\/strong>)?<\/td>/is);
      const lotM   = dHtml.match(/Pay\s*:?[^<]*<\/td>\s*<td[^>]*>(?:<strong[^>]*>)?(.*?)(?:<\/strong>)?<\/td>/is);

      let listingDateText = '';
      for (const pat of [
        /Bist\s+[İI]lk\s+[İI]şlem\s+Tarihi[^<]*<\/td>\s*<td[^>]*>(?:<strong[^>]*>)?(.*?)(?:<\/strong>)?<\/td>/is,
        /[İI]lk\s+[İI]şlem\s+Tarihi[^<]*<\/td>\s*<td[^>]*>(?:<strong[^>]*>)?(.*?)(?:<\/strong>)?<\/td>/is,
        /Borsada\s+[İI]şlem[^<]*<\/td>\s*<td[^>]*>(?:<strong[^>]*>)?(.*?)(?:<\/strong>)?<\/td>/is,
      ]) {
        const m = dHtml.match(pat);
        if (m) { listingDateText = cleanTxt(m[1]); break; }
      }

      const listingDate = parseTrDateRange(listingDateText).start || null;
      const kapM = dHtml.match(/https?:\/\/(?:www\.)?kap\.org\.tr\/[^\s"'>]+/i);
      const range = parseTrDateRange(item.requestDates);
      const status = deriveIpoStatus({ requestStart: range.start, requestEnd: range.end, listingDate });

      results.push({
        companyName:      item.companyName,
        requestDates:     item.requestDates || '-',
        requestStart:     toIso(range.start),
        requestEnd:       toIso(range.end),
        price:            priceM ? cleanTxt(priceM[1]) : '-',
        lot:              lotM   ? cleanTxt(lotM[1])   : '-',
        distributionType: distM  ? cleanTxt(distM[1])  : '-',
        symbol:           item.symbol,
        status,
        listingDate:      toIso(listingDate),
        kapUrl:           kapM ? kapM[0] : '',
        source:           'HalkArz',
        publishedAt:      new Date().toISOString(),
      });
    } catch (err) {
      console.warn(`HalkArz detay hatası (${item.symbol || item.companyName}):`, err.message);
    }
  }
  return results;
}

async function writeIpoToFirestore(items) {
  if (!items.length) return 0;
  const PRI = { trading:4, pending_listing:3, collecting:2, upcoming:1 };
  const deduped = new Map();

  for (const item of items) {
    const key = item.symbol
      ? item.symbol.toUpperCase()
      : `NO_SYMBOL_${item.companyName.replace(/\s+/g,'_').substring(0,30)}`;
    const ex = deduped.get(key);
    if (!ex) { deduped.set(key, item); continue; }
    const ep = PRI[ex.status] || 0, np = PRI[item.status] || 0;
    if (np > ep || (np === ep && (item.publishedAt||'') > (ex.publishedAt||''))) {
      deduped.set(key, item);
    }
  }

  const entries = [...deduped.entries()];
  let written = 0;
  for (let i = 0; i < entries.length; i += 400) {
    const batch = db.batch();
    for (const [docId, item] of entries.slice(i, i + 400)) {
      batch.set(db.collection('ipo_items').doc(docId),
        { ...item, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
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

// ── Scheduled: Her 6 saatte bir (UTC 00, 06, 12, 18) ────────────────────────
exports.syncIpoFeed = onSchedule({
  schedule:       '0 */6 * * *',
  timeZone:       'UTC',
  region:         'europe-west1',
  memory:         '512MiB',
  timeoutSeconds: 300,
}, async () => {
  console.log('IPO sync başladı:', new Date().toISOString());
  try {
    const items = await fetchHalkArzItems();
    if (!items.length) { console.warn('HalkArz: kayıt bulunamadı'); return; }
    const count = await writeIpoToFirestore(items);
    console.log(`IPO sync tamamlandı: ${count} kayıt`);
  } catch (err) {
    console.error('IPO sync hatası:', err.message);
    throw err;
  }
});

// ── Manuel tetikleme (admin korumalı) ───────────────────────────────────────
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
    const items = await fetchHalkArzItems();
    const count = await writeIpoToFirestore(items);
    res.json({ success: true, count });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// TEKNİK ANALİZ AI PROXY — NVIDIA NIM (Nemotron-3.5-Lightning-30B)
//
// Flutter uygulaması bu endpoint'e hisse verilerini gönderir.
// NVIDIA_API_KEY sadece burada yaşar — uygulama bundle'ına girmez.
//
// Güvenlik:
//   - CORS: sadece Firebase Hosting domain'ine izin verilir
//   - Rate limit: IP başına dakikada max 10 istek
//   - Input validation: zorunlu alanlar kontrol edilir
//   - Timeout: 25 saniye
//
// Fallback davranışı:
//   - Herhangi bir hatada HTTP 503 döner → Flutter lokal fallback'e geçer
// ─────────────────────────────────────────────────────────────────────────────

// Rate limiter (bellek içi, function instance başına)
const rateLimitMap = new Map(); // ip → { count, resetAt }

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

/** NVIDIA NIM OpenAI-uyumlu API'ye istek atar. */
async function callNvidiaAI(apiKey, prompt) {
  const body = JSON.stringify({
    model: 'nvidia/nemotron-3.5-lightning-30b-a3b',
    messages: [
      {
        role: 'system',
        content:
          'Sen deneyimli bir Türk borsa analistinin sesini taklit eden teknik analiz asistanısın.\n' +
          'KURALLAR:\n' +
          '1. SADECE Türkçe yaz. İngilizce kelime, başlık veya cümle YASAKTIR.\n' +
          '2. Düşünme sürecini, taslak adımları, kural listelerini, madde işaretlerini ASLA yazma.\n' +
          '3. Doğrudan analize başla. "İşte analiz:", "Merhaba" gibi girişler yok.\n' +
          '4. Maksimum 4-6 kısa, akıcı cümle. Düz paragraf yaz.\n' +
          '5. Gerçek bir analist gibi konuş — doğal, sade, abartısız.\n' +
          '6. Teknik terimler Türkçe olacak: EMA yerine "hareketli ortalama", RSI aşırı alım/satım bölgesi vb.\n' +
          '7. Son cümle mutlaka: "Bu bir yatırım tavsiyesi değildir."\n' +
          '8. Başka hiçbir şey yazma — sadece analiz paragrafı.',
      },
      { role: 'user', content: prompt },
    ],
    temperature: 0.7,
    top_p: 0.9,
    max_tokens: 400,
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
      timeout: 25000,
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          try { resolve(JSON.parse(data)); }
          catch (e) { reject(new Error('NVIDIA yanıt parse hatası: ' + e.message)); }
        } else {
          reject(new Error(`NVIDIA API HTTP ${res.statusCode}: ${data.substring(0, 200)}`));
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('NVIDIA API timeout')); });
    req.write(body);
    req.end();
  });

  const content = result?.choices?.[0]?.message?.content;
  if (!content) throw new Error('NVIDIA yanıtı boş');
  return content.trim();
}

/** Hisse verilerinden AI prompt'u oluşturur. */
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

  const sinyaller = [];
  if (isGoldenCross)      sinyaller.push('Altın Kesişim (kısa ortalama uzun ortalamanın üstüne çıktı)');
  if (isDeathCross)       sinyaller.push('Ölüm Kesişimi (kısa ortalama uzun ortalamanın altına düştü)');
  if (isMacdBullish)      sinyaller.push('MACD histogramı yükseliş yönüne döndü');
  if (isMacdBearish)      sinyaller.push('MACD histogramı düşüş yönüne döndü');
  if (isSupertrendBuy)    sinyaller.push('Süper Trend göstergesi alım sinyali verdi');
  if (isSupertrendSell)   sinyaller.push('Süper Trend göstergesi satım sinyali verdi');
  if (isBullishDivergence) sinyaller.push('Pozitif uyuşmazlık: fiyat düşerken momentum güçleniyor');
  if (isBearishDivergence) sinyaller.push('Negatif uyuşmazlık: fiyat yükselirken momentum zayıflıyor');
  if (isHammer)           sinyaller.push('Çekiç mumu oluştu — potansiyel dönüş sinyali');
  if (isBullishEngulfing) sinyaller.push('Yutan boğa mumu oluştu');
  if (isMorningStar)      sinyaller.push('Sabah yıldızı formasyonu oluştu');
  if (isBearishEngulfing) sinyaller.push('Yutan ayı mumu oluştu');
  if (isDoji)             sinyaller.push('Doji mumu var — kararsızlık sinyali');

  const ortalamaMetni =
    emaAboveCount === 3 ? 'üç hareketli ortalamanın (20, 50, 200) hepsinin üzerinde' :
    emaAboveCount === 2 ? '20 ve 50 günlük ortalamaların üzerinde, 200 günlük ortalama hâlâ baskı yapıyor' :
    emaAboveCount === 1 ? 'yalnızca 20 günlük ortalamanın üzerinde' :
    'üç hareketli ortalamanın hepsinin altında';

  const momentumMetni =
    rsi >= 70 ? `momentum göstergesi ${rsi.toFixed(0)} ile aşırı alım bölgesinde` :
    rsi >= 60 ? `momentum göstergesi ${rsi.toFixed(0)} ile güçlü bölgede` :
    rsi >= 45 ? `momentum göstergesi ${rsi.toFixed(0)} ile dengeli bölgede` :
    rsi >= 30 ? `momentum göstergesi ${rsi.toFixed(0)} ile zayıf bölgede` :
    `momentum göstergesi ${rsi.toFixed(0)} ile aşırı satım bölgesinde`;

  const destekDirenc = supportLevel && resistanceLevel
    ? `Yakın destek ${supportLevel.toFixed(2)} ₺, yakın direnç ${resistanceLevel.toFixed(2)} ₺.`
    : supportLevel
    ? `Yakın destek seviyesi ${supportLevel.toFixed(2)} ₺.`
    : resistanceLevel
    ? `Yakın direnç seviyesi ${resistanceLevel.toFixed(2)} ₺.`
    : '';

  const temelMetni = (fk > 0 || pdDd > 0)
    ? `Fiyat/Kazanç oranı ${fk > 0 ? fk.toFixed(1) : '-'}, Piyasa Değeri/Defter Değeri ${pdDd > 0 ? pdDd.toFixed(2) : '-'}.`
    : '';

  return (
    `${name} (${symbol}) hissesinin ${periodLabel} teknik görünümünü değerlendir.\n\n` +
    `Güncel fiyat ${price.toFixed(2)} ₺, dönemsel değişim ${changePercent >= 0 ? '+' : ''}${changePercent.toFixed(2)}%.\n` +
    `Fiyat ${ortalamaMetni}.\n` +
    `${momentumMetni.charAt(0).toUpperCase() + momentumMetni.slice(1)}.\n` +
    (destekDirenc ? `${destekDirenc}\n` : '') +
    `İşlem hacmi ${volumeIncreasing ? 'artıyor' : 'azalıyor'}.\n` +
    `Görüntülenen dönemde toplam değişim ${periodChange >= 0 ? '+' : ''}${periodChange.toFixed(1)}%.\n` +
    (sinyaller.length > 0 ? `Öne çıkan sinyaller: ${sinyaller.join('; ')}.\n` : '') +
    (temelMetni ? `${temelMetni}\n` : '') +
    `\nSadece düz paragraf hâlinde, Türkçe, doğal ve kısa bir teknik görünüm yaz.`
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TEKNİK ANALİZ ÖNBELLEK — Firestore
//
// Aynı hisse + periyot + gün kombinasyonu için günde 1 kez NVIDIA'ya istek atılır.
// Kalan tüm kullanıcılar önbellekten anında cevap alır.
//
// Firestore yapısı:
//   ai_cache/{symbol}_{period}_{YYYY-MM-DD}  → { analysis, createdAt, hitCount }
//
// Önbellek geçerlilik süresi:
//   - Borsa günlerinde 4 saat (piyasa bilgisi değişir)
//   - Hafta sonu 24 saat (piyasa kapalı, fiyat değişmez)
// ─────────────────────────────────────────────────────────────────────────────

const CACHE_TTL_BORSAGUNU_MS = 4 * 60 * 60 * 1000;   // 4 saat
const CACHE_TTL_HAFTASONU_MS = 24 * 60 * 60 * 1000;  // 24 saat

function getCacheTtl() {
  const gun = new Date().getUTCDay(); // 0=Pazar, 6=Cumartesi
  return (gun === 0 || gun === 6) ? CACHE_TTL_HAFTASONU_MS : CACHE_TTL_BORSAGUNU_MS;
}

function buildCacheKey(symbol, periodLabel) {
  const bugun = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
  const temiz = symbol.replace(/[^A-Z0-9]/gi, '').toUpperCase();
  const periyot = (periodLabel || 'G').replace(/\s/g, '_');
  return `${temiz}_${periyot}_${bugun}`;
}

async function getCachedAnalysis(cacheKey) {
  try {
    const doc = await db.collection('ai_cache').doc(cacheKey).get();
    if (!doc.exists) return null;
    const data = doc.data();
    const now = Date.now();
    const olusturmaTarihi = data.createdAt?.toMillis?.() || 0;
    if (now - olusturmaTarihi > getCacheTtl()) return null; // süresi dolmuş
    // Erişim sayacını arttır (analytics için)
    doc.ref.update({ hitCount: FieldValue.increment(1) }).catch(() => {});
    return data.analysis || null;
  } catch (err) {
    console.warn('Önbellek okuma hatası:', err.message);
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
    console.warn('Önbellek yazma hatası:', err.message);
  }
}

exports.getTeknikAnaliz = onRequest({
  region: 'europe-west1',
  memory: '256MiB',
  timeoutSeconds: 35,
  secrets: [NVIDIA_API_KEY],
}, async (req, res) => {
  // CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Yalnızca POST desteklenmektedir' });
    return;
  }

  // Rate limit
  const clientIp = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip || 'unknown';
  if (isRateLimited(clientIp)) {
    res.status(429).json({ error: 'İstek limiti aşıldı, lütfen bekleyin' });
    return;
  }

  // Girdi doğrulama
  const data = req.body;
  if (!data || !data.symbol || !data.name || typeof data.rsi !== 'number') {
    res.status(400).json({ error: 'Eksik veya geçersiz parametre' });
    return;
  }

  const cacheKey = buildCacheKey(data.symbol, data.periodLabel);

  // ── 1. Önbellek kontrolü ──────────────────────────────────────────────────
  const cachedAnalysis = await getCachedAnalysis(cacheKey);
  if (cachedAnalysis) {
    console.log(`Önbellekten döndü: ${cacheKey}`);
    res.json({ success: true, analysis: cachedAnalysis, fromCache: true });
    return;
  }

  // ── 2. NVIDIA'ya yeni istek ───────────────────────────────────────────────
  try {
    const apiKey  = NVIDIA_API_KEY.value();
    const prompt  = buildAnalysisPrompt(data);
    const analysis = await callNvidiaAI(apiKey, prompt);

    // Önbelleğe yaz (hata olursa sessizce geç)
    await setCachedAnalysis(cacheKey, analysis, data.symbol, data.periodLabel);

    console.log(`NVIDIA'dan yeni yanıt alındı, önbelleğe yazıldı: ${cacheKey}`);
    res.json({ success: true, analysis, fromCache: false });
  } catch (err) {
    console.error('getTeknikAnaliz hatası:', err.message);
    // 503 → Flutter lokal analize geçer
    res.status(503).json({ error: 'Yapay zeka servisi şu an kullanılamıyor' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// ÖNBELLEK TEMİZLEYİCİ — Her gece 02:00 UTC çalışır
//
// 48 saatten eski ai_cache kayıtlarını siler.
// Firestore'un şişmesini önler, maliyeti düşük tutar.
// Günde max ~500 BIST hissesi × 6 periyot = 3000 kayıt — temizlik yönetilebilir.
// ─────────────────────────────────────────────────────────────────────────────

exports.cleanAiCache = onSchedule({
  schedule:       '0 2 * * *',   // Her gece saat 02:00 UTC
  timeZone:       'UTC',
  region:         'europe-west1',
  memory:         '256MiB',
  timeoutSeconds: 120,
}, async () => {
  const ESKIME_SURESI_MS = 48 * 60 * 60 * 1000; // 48 saat
  const sinirZamani = new Date(Date.now() - ESKIME_SURESI_MS);

  console.log(`Önbellek temizliği başladı. ${sinirZamani.toISOString()} öncesi kayıtlar silinecek.`);

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
      console.log(`${silinen} kayıt silindi...`);

      // 400'den az geldiyse bitti
      if (snapshot.size < 400) devam = false;
    }

    console.log(`Önbellek temizliği tamamlandı: toplam ${silinen} kayıt silindi.`);
  } catch (err) {
    console.error('Önbellek temizliği hatası:', err.message);
  }
});
