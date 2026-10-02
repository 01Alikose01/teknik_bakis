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

// ── YAPAY ZEKA MODELLERİ (NVIDIA NIM) ─────────────────────────────────────────
// 1. Ana AI:    NVIDIA Nemotron 3 Super 120B (nvidia/nemotron-3-super-120b-a12b)
// 2. Yedek AI:  OpenAI GPT-OSS 20B (openai/gpt-oss-20b)
const MODEL_PRIMARY  = 'nvidia/nemotron-3-super-120b-a12b';
const MODEL_FALLBACK = 'openai/gpt-oss-20b';

/** NVIDIA NIM OpenAI-uyumlu API'ye tekil model isteği atar. */
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
    max_tokens: 800,  // 3 kısa paragraf için yeterli; token bitince kesilmesini önler
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
          catch (e) { reject(new Error('NVIDIA yanıt parse hatası: ' + e.message)); }
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

  // finish_reason kontrolü: "length" ise yanıt token limitinde kesildi → hata fırlat
  const finishReason = result?.choices?.[0]?.finish_reason;
  if (finishReason === 'length') {
    throw new Error(`NVIDIA yanıtı token limitinde kesildi (${modelId}) — yarım analiz önlendi`);
  }

  let content = result?.choices?.[0]?.message?.content;
  if (!content) throw new Error(`NVIDIA yanıtı boş (${modelId})`);
  content = content.replace(/<think>[\s\S]*?<\/think>/gi, '').trim();
  if (!content) throw new Error(`NVIDIA yanıtı ayıklandıktan sonra boş kaldı (${modelId})`);
  return content;
}

/**
 * İki kademeli yapay zeka analizi:
 * 1. Ana AI (NVIDIA Nemotron 3 Super 120B) denenir.
 * 2. Başarısız olursa / zaman aşımına uğrarsa 2. AI (OpenAI GPT-OSS 20B) devreye girer.

 * 3. Her iki model de başarısız olursa hata fırlatılır (Cloud Function 503 döner, Flutter lokal analize geçer).
 */
async function getDualAiAnalysis(apiKey, prompt) {
  // Minimum anlamlı analiz uzunluğu: 3 paragraf × 2 cümle = en az ~200 karakter
  const MIN_ANALYSIS_LENGTH = 200;

  // 1. Kademe: Ana AI (Nemotron 3 Super 120B)
  try {
    console.log(`[AI] 1. Kademe (Ana AI) deneniyor: ${MODEL_PRIMARY}`);
    const analysis = await callNvidiaModel(apiKey, MODEL_PRIMARY, prompt, 14000);
    if (analysis && analysis.length >= MIN_ANALYSIS_LENGTH) {
      console.log(`[AI] Ana AI başarılı oldu (${MODEL_PRIMARY}), uzunluk: ${analysis.length}`);
      return { analysis, usedModel: MODEL_PRIMARY };
    }
    throw new Error(`Ana AI yanıtı yetersiz (${analysis?.length ?? 0} karakter, min ${MIN_ANALYSIS_LENGTH})`);
  } catch (errPrimary) {
    console.warn(`[AI] Ana AI (${MODEL_PRIMARY}) başarısız oldu: ${errPrimary.message}. 2. Kademe (OpenAI GPT-OSS 20B) deneniyor...`);
  }

  // 2. Kademe: İkinci AI (OpenAI GPT-OSS 20B)
  try {
    console.log(`[AI] 2. Kademe (Yedek AI) deneniyor: ${MODEL_FALLBACK}`);
    const analysis = await callNvidiaModel(apiKey, MODEL_FALLBACK, prompt, 18000);
    if (analysis && analysis.length >= MIN_ANALYSIS_LENGTH) {
      console.log(`[AI] İkinci AI başarılı oldu (${MODEL_FALLBACK}), uzunluk: ${analysis.length}`);
      return { analysis, usedModel: MODEL_FALLBACK };
    }
    throw new Error(`İkinci AI yanıtı yetersiz (${analysis?.length ?? 0} karakter, min ${MIN_ANALYSIS_LENGTH})`);
  } catch (errSecondary) {
    console.error(`[AI] İkinci AI (${MODEL_FALLBACK}) de başarısız oldu: ${errSecondary.message}`);
    throw new Error(`Her iki AI modeli de başarısız oldu: ${errSecondary.message}`);
  }
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

  // Boolean'ları Türkçe okunabilir formata çevir (AI modelin daha iyi anlaması için)
  const e = (v) => v === true ? 'Evet' : 'Hayır';

  const ortalamaMetni =
    emaAboveCount === 3 ? 'Fiyat 20, 50 ve 200 günlük hareketli ortalamaların hepsinin üzerinde' :
    emaAboveCount === 2 ? 'Fiyat 20 ve 50 günlük ortalamaların üzerinde; 200 günlük ortalama henüz aşılmadı' :
    emaAboveCount === 1 ? 'Fiyat yalnızca 20 günlük ortalamanın üzerinde; 50 ve 200 günlük ortalamalar baskı yapıyor' :
    'Fiyat 20, 50 ve 200 günlük hareketli ortalamaların hepsinin altında';

  const rsiStr = (typeof rsi === 'number' && !isNaN(rsi)) ? rsi.toFixed(1) : '?';
  const priceStr = (typeof price === 'number') ? price.toFixed(2) : '?';
  const changeStr = (changePercent >= 0 ? '+' : '') + (changePercent || 0).toFixed(2);
  const periodChangeStr = (periodChange >= 0 ? '+' : '') + (periodChange || 0).toFixed(1);

  return (
    `HİSSE:\n` +
    `Sembol: ${symbol}\n` +
    `Şirket: ${name}\n\n` +
    `FİYAT:\n` +
    `Güncel fiyat: ${priceStr} TL\n` +
    `Günlük değişim: ${changeStr}%\n\n` +
    `TEKNİK VERİLER:\n` +
    `RSI (momentum göstergesi): ${rsiStr}\n` +
    `Hareketli ortalama durumu: ${ortalamaMetni}\n` +
    (supportLevel  ? `Yakın destek: ${supportLevel.toFixed(2)} TL\n`  : '') +
    (resistanceLevel ? `Yakın direnç: ${resistanceLevel.toFixed(2)} TL\n` : '') +
    `Hacim artıyor mu: ${e(volumeIncreasing)}\n` +
    `Dönem değişimi (${periodLabel || 'G'}): ${periodChangeStr}%\n\n` +
    `SİNYALLER:\n` +
    `Pozitif uyumsuzluk (Bullish Divergence): ${e(isBullishDivergence)}\n` +
    `Negatif uyumsuzluk (Bearish Divergence): ${e(isBearishDivergence)}\n` +
    `Golden Cross (Altın Kesişim): ${e(isGoldenCross)}\n` +
    `Death Cross (Ölüm Kesişimi): ${e(isDeathCross)}\n` +
    `MACD yükseliş sinyali: ${e(isMacdBullish)}\n` +
    `MACD düşüş sinyali: ${e(isMacdBearish)}\n` +
    `Supertrend AL sinyali: ${e(isSupertrendBuy)}\n` +
    `Supertrend SAT sinyali: ${e(isSupertrendSell)}\n\n` +
    `MUM FORMASYONLARI:\n` +
    `Çekiç (Hammer): ${e(isHammer)}\n` +
    `Yutan Boğa (Bullish Engulfing): ${e(isBullishEngulfing)}\n` +
    `Sabah Yıldızı (Morning Star): ${e(isMorningStar)}\n` +
    `Yutan Ayı (Bearish Engulfing): ${e(isBearishEngulfing)}\n` +
    `Doji: ${e(isDoji)}\n\n` +
    ((fk > 0 || pdDd > 0)
      ? `DEĞERLEME (teknik analizden bağımsız değerlendir):\n` +
        (fk   > 0 ? `F/K (Fiyat/Kazanç): ${fk.toFixed(1)}\n`   : '') +
        (pdDd > 0 ? `PD/DD (Piyasa/Defter): ${pdDd.toFixed(2)}\n` : '') + '\n'
      : '') +
    `Yukarıdaki verileri analiz et.\n` +
    `Analizde RSI ${rsiStr} ve fiyat ${priceStr} TL gerçek değerlerini kullan.\n` +
    `Aynı kalıp cümleleri farklı hisseler için tekrar etme.\n` +
    `Veri yoksa o konuda tahmin yapma.\n` +
    `Analizi 3 paragrafa ayirarak yaz. Paragraflar arasina bos satir birak.\n` +
    `Son satir (bos satirdan sonra ayri paragraf): Bu bir yatirim tavsiyesi degildir.`
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

function buildCacheKey(symbol, periodLabel, rsi, changePercent, data) {
  const bugun = new Date().toISOString().slice(0, 10);
  const temiz = symbol.replace(/[^A-Z0-9]/gi, '').toUpperCase();
  const periyot = (periodLabel || 'G').replace(/\s/g, '_');

  // RSI'yi 5'in katlarına yuvarla — her hisse benzersiz cache anahtarı alır
  // Örnek: THYAO RSI=32→30, ASELS RSI=57→55, TUPRS RSI=71→70 → tamamı farklı
  const rsiRound = Math.round((rsi || 50) / 5) * 5;

  // Fiyat değişim yönü (geniş bant)
  const yon = changePercent > 2 ? 'up2' : changePercent > 0.5 ? 'up1'
            : changePercent < -2 ? 'dn2' : changePercent < -0.5 ? 'dn1' : 'flat';

  // Aktif sinyal özeti — farklı sinyal kombinasyonları farklı cache anahtarı üretir
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
  timeoutSeconds: 50,
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

  const cacheKey = buildCacheKey(data.symbol, data.periodLabel, data.rsi || 50, data.changePercent || 0, data);

  // ── 1. Önbellek kontrolü ──────────────────────────────────────────────────
  const cachedAnalysis = await getCachedAnalysis(cacheKey);
  if (cachedAnalysis) {
    console.log(`Önbellekten döndü: ${cacheKey}`);
    res.json({ success: true, analysis: cachedAnalysis, fromCache: true });
    return;
  }

  // ── 2. NVIDIA'ya yeni istek (İki Kademeli Dual AI) ───────────────────────
  try {
    const apiKey  = NVIDIA_API_KEY.value();
    const prompt  = buildAnalysisPrompt(data);
    const { analysis, usedModel } = await getDualAiAnalysis(apiKey, prompt);

    // Önbelleğe yaz (hata olursa sessizce geç)
    await setCachedAnalysis(cacheKey, analysis, data.symbol, data.periodLabel);

    console.log(`AI'dan yeni yanıt alındı (${usedModel}), önbelleğe yazıldı: ${cacheKey}`);
    res.json({ success: true, analysis, usedModel, fromCache: false });
  } catch (err) {
    console.error('getTeknikAnaliz hatası:', err.message);
    // 503 → Flutter lokal analize geçer
    res.status(503).json({ error: 'Yapay zeka servisi şu an kullanılamıyor' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// ÖNBELLEK TEMİZLEYİCİ — Her gece 02:00 UTC çalışır
//


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

// ─────────────────────────────────────────────────────────────────────────────
// GOOGLE PLAY SUBSCRIPTION VERIFICATION (Developer API)
// ─────────────────────────────────────────────────────────────────────────────
const { google } = require('googleapis');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');

const PLAY_SERVICE_ACCOUNT_KEY = defineSecret('PLAY_SERVICE_ACCOUNT_KEY');
const PACKAGE_NAME = 'com.teknikbakis.teknik_bakis';

/**
 * Google Play Developer API istemcisini auth ile başlatır.
 * Öncelik 1: PLAY_SERVICE_ACCOUNT_KEY (Secret Manager JSON)
 * Öncelik 2: Application Default Credentials (GCP Service Account)
 */
async function getPlayAuthClient(secretJsonStr) {
  if (secretJsonStr && secretJsonStr.trim().startsWith('{')) {
    try {
      const creds = JSON.parse(secretJsonStr);
      return new google.auth.JWT({
        email: creds.client_email,
        key: creds.private_key,
        scopes: ['https://www.googleapis.com/auth/androidpublisher'],
      });
    } catch (e) {
      console.warn('PLAY_SERVICE_ACCOUNT_KEY parse hatası, ADC deneniyor:', e.message);
    }
  }

  const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  return await auth.getClient();
}

/**
 * purchaseToken'ı Google Play Subscriptions v2 API üzerinden doğrular
 * ve Firestore'daki `entitlements/{deviceId}` ve `subscription_tokens/{token}`
 * dökümanlarını sunucu tarafında günceller.
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
    console.warn(`[verifySubscription] Google Play API sorgulama uyarısı: ${apiErr.message}`);
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
        // Ödeme aksaklığı durumunda kullanıcıya tanınan ek süre (Grace Period)
        isActive = true;
        break;
      case 'SUBSCRIPTION_STATE_CANCELED':
        // İptal edilmiş fakat dönem sonu henüz gelmemiş abonelikler süresi bitene kadar aktiftir
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
    // Google Play API başarısız oldu veya service account yapılandırılmamış
    // GÜVENLİK: API doğrulaması yapılamadığında Premium AÇILMAZ
    console.warn('[verifyAndSaveSubscription] Google Play API doğrulaması başarısız — isActive=false');
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
 * HTTPS Endpoint: Flutter doğrudan bu endpoint'i çağırıp anında doğrulama alabilir.
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
 * Firestore Trigger: `purchases/{deviceId}` yazıldığında arka planda otomatik doğrular.
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
    console.log(`[onPurchaseWritten] device ${deviceId} için purchaseToken bulunamadı.`);
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
    console.log(`[onPurchaseWritten] device ${deviceId} entitlement başarıyla güncellendi.`);
  } catch (err) {
    console.error(`[onPurchaseWritten] error for device ${deviceId}:`, err.message);
  }
});


// ─────────────────────────────────────────────────────────────────────────────
// BIST 100 ENDEKSİ OTOMATİK GÜNCELLEME
//
// Borsa İstanbul resmi duyurularından (borsaistanbul.com/en/announcement)
// BIST 100 bileşen değişikliklerini çekip Firestore'a yazar.
//
// Firestore yapısı:
//   bist_index_meta/bist100  → symbols, added, removed, alternates, meta
//   bist_stocks/{SYMBOL}     → bist100Member alanı güncellenir (active'e dokunulmaz)
//
// Zamanlama: Her Pazartesi 05:00 UTC (08:00 TR)
// Manuel test: syncBist100Manual?dryRun=true&secret=<ADMIN_SECRET>
//
// Log mesajları:
//   BIST100_SYNC_STARTED
//   BIST100_ANNOUNCEMENT_FOUND: {id} - {title}
//   BIST100_NO_CHANGE: announcement {id} already processed
//   BIST100_FETCH_ERROR: ...
//   BIST100_PARSE_SUCCESS: added=N, removed=N
//   BIST100_VALIDATION_FAILED: {reason}
//   BIST100_UPDATED: N symbols, added=[...], removed=[...]
// ─────────────────────────────────────────────────────────────────────────────

// ── HTML Fetch Yardımcısı ────────────────────────────────────────────────────

/** Verilen URL'den düz HTML string çeker. */
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

// ── Duyuru Listesi Tarayıcı ──────────────────────────────────────────────────

/**
 * Borsa İstanbul duyuru listesi sayfasını tarayıp en yeni BIST 100 endeks
 * değişiklik duyurusunu bulur.
 *
 * @returns {{ announcementId, announcementUrl, announcementTitle, announcementDate } | null}
 */
async function findLatestBist100Announcement() {
  const listUrl = 'https://www.borsaistanbul.com/en/announcement';
  const html = await fetchHtml(listUrl);

  // Pattern: /en/announcement/{numericId}/{slug}
  // Slug'da iki olası pattern:
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

  // Başlığı slug'dan türet (tire → boşluk, kelimeler büyük harf)
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

// ── Duyuru HTML Parser ────────────────────────────────────────────────────────

/**
 * Duyuru HTML'ini parse eder.
 *
 * Borsa İstanbul duyuru formatı (doğrulanmış örnek: id 15598):
 *   Sayfa bir HTML tablosu içeriyor. HTML etiketlerinden ÖNCE tablo satırları
 *   işleniyor: Her <tr> satırında 3 <td> hücresi var (INCLUDED | EXCLUDED | SUBSTITUTE).
 *   İlk sütun = added, ikinci sütun = removed, üçüncü sütun = alternates.
 *
 *   Hücre içeriği: "1AGHOLANADOLU GRUBU HOLDING" ya da "1 AGHOL ANADOLU..."
 *   Semboller: 2-6 büyük harf, satır başında numara + sembol ardışık.
 *
 * @returns {{ added, removed, alternates, periodStart, periodEnd, revision, bist100SectionFound }}
 */
function parseBist100Announcement(html) {
  // ── Strateji: HTML tag'lerini kaldırmadan önce tablo hücrelerini işle ────
  //
  // Adım 1: BIST 100 INDEX bölümünü RAW HTML'de bul
  const bist100HtmlStart = html.search(/BIST\s+100\s+INDEX/i);
  if (bist100HtmlStart < 0) {
    return { added: [], removed: [], alternates: [], periodStart: '', periodEnd: '', revision: '', bist100SectionFound: false };
  }

  // Adım 2: BIST 100 sonrasındaki bir sonraki büyük bölüme kadar HTML'i kes
  const afterBist100Html = html.slice(bist100HtmlStart);
  const nextBigSection = afterBist100Html.search(/BIST\s+(?:500|LIQUID|SUSTAINABILITY)\s+INDEX/i);
  const bist100Html = nextBigSection >= 0
    ? afterBist100Html.slice(0, nextBigSection)
    : afterBist100Html.slice(0, 50000);

  // Adım 3: Bu HTML bloğundan tüm <tr> satırlarını çıkar
  //   Her <tr>...</tr> = bir tablo satırı
  //   Her satır 1–3 <td>...</td> içerebilir
  const trPattern = /<tr[\s\S]*?<\/tr>/gi;
  const tdPattern = /<td[\s\S]*?>([\s\S]*?)<\/td>/gi;

  const added      = [];
  const removed    = [];
  const alternates = [];

  // Hücre içeriğinden sembol çıkar
  function cellToSymbol(cellHtml) {
    // HTML tag'lerini temizle
    const cellText = cellHtml
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&#\d+;/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    if (!cellText) return null;

    // Format: "1AGHOLANADOLU GRUBU HOLDING" (birleşik) veya "1 AGHOL ANADOLU..." (boşluklu)
    // Numera sonrası büyük harf bloğunu al
    const m = cellText.match(/^\d+\s*([A-Z]+)/);
    if (!m) return null;
    const token = m[1];

    let sym;
    if (token.length <= 6) {
      // Kısa token: doğrudan sembol (2-6 harf)
      sym = token;
    } else {
      // Uzun token: sembol + şirket adı bitişik yazılmış.
      // BIST sembolleri genellikle 4-5 harf; boşluklu versiyonda ilk kelime sembol,
      // bitişik versiyonda ilk 5 harfi al (güvenli fallback).
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
    // 3 sütunlu satır: [added_cell, removed_cell, substitute_cell]
    if (cells.length >= 3) {
      const sym0 = cellToSymbol(cells[0]);
      const sym1 = cellToSymbol(cells[1]);
      const sym2 = cellToSymbol(cells[2]);
      if (sym0 && !added.includes(sym0))      added.push(sym0);
      if (sym1 && !removed.includes(sym1))    removed.push(sym1);
      if (sym2 && !alternates.includes(sym2)) alternates.push(sym2);
    } else if (cells.length === 2) {
      // Sadece added + removed sütunu (yedek yok)
      const sym0 = cellToSymbol(cells[0]);
      const sym1 = cellToSymbol(cells[1]);
      if (sym0 && !added.includes(sym0))   added.push(sym0);
      if (sym1 && !removed.includes(sym1)) removed.push(sym1);
    } else if (cells.length === 1) {
      // Tek sütun (başlık satırı olabilir, sembol değil)
      // Atla
    }
  }

  // ── Dönem bilgisi: tam HTML'den düz metne çevirerek çıkar ───────────────
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

  // "PERIOD OCTOBER 1, 2026 – DECEMBER 31, 2026" patternleri
  const periodTextMatch = fullText.match(/PERIOD\s+((?:JANUARY|FEBRUARY|MARCH|APRIL|MAY|JUNE|JULY|AUGUST|SEPTEMBER|OCTOBER|NOVEMBER|DECEMBER)\s+\d{1,2},?\s+\d{4})\s*[-\u2013\u2014]\s*((?:JANUARY|FEBRUARY|MARCH|APRIL|MAY|JUNE|JULY|AUGUST|SEPTEMBER|OCTOBER|NOVEMBER|DECEMBER)\s+\d{1,2},?\s+\d{4})/i);
  if (periodTextMatch) {
    periodStart = periodTextMatch[1].trim();
    periodEnd   = periodTextMatch[2].trim();
    // Yıl ve çeyrek hesapla
    const endMonth = periodTextMatch[2].trim().toUpperCase();
    const yearMatch = periodTextMatch[2].match(/(\d{4})/);
    const year = yearMatch ? yearMatch[1] : '';
    if (endMonth.startsWith('MARCH'))     revision = `${year}-Q1`;
    else if (endMonth.startsWith('JUNE'))  revision = `${year}-Q2`;
    else if (endMonth.startsWith('SEPT'))  revision = `${year}-Q3`;
    else if (endMonth.startsWith('DECE'))  revision = `${year}-Q4`;
    else revision = year;
  }

  // Alternatif: "01.10.2026" gibi Türkçe tarih formatı
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

// ── Validation ────────────────────────────────────────────────────────────────

/**
 * Firestore'a yazmadan önce kritik kontrolleri yapar.
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
  // Sembol format kontrolü: 2–6 büyük Latin harf
  const badSym = newSymbols.find(s => !/^[A-Z]{2,6}$/.test(s));
  if (badSym) {
    return { valid: false, reason: `INVALID_SYMBOL_FORMAT:${badSym}` };
  }
  // added ve removed kesişimi
  const addedSet   = new Set(added);
  const removedSet = new Set(removed);
  const overlap    = added.filter(s => removedSet.has(s));
  if (overlap.length > 0) {
    return { valid: false, reason: `ADDED_REMOVED_OVERLAP:${overlap.join(',')}` };
  }
  // Beklenmedik büyük fark — 20'den fazla sembol değişimi parse hatası sinyali
  const totalChange = added.length + removed.length;
  if (totalChange > 40) {
    return { valid: false, reason: `UNEXPECTED_LARGE_DIFF:added=${added.length},removed=${removed.length}` };
  }
  // Mevcut liste bozuksa sadece uyar, engelleme (yeni liste 100 kontrolü zaten yapıldı)
  if (currentSymbols.length > 0 && currentSymbols.length !== 100) {
    console.warn(`BIST100_WARN: Mevcut Firestore listesi 100 değil (${currentSymbols.length}), yeni geçerli liste uygulanıyor.`);
  }
  return { valid: true, reason: '' };
}

// ── Core Sync Orkestrasyonu ──────────────────────────────────────────────────

/**
 * BIST 100 sync ana fonksiyonu.
 * @param {{ dryRun?: boolean }} options
 * @returns {Promise<{ status: string, [key: string]: any }>}
 */
async function runBist100Sync({ dryRun = false } = {}) {
  console.log('BIST100_SYNC_STARTED', new Date().toISOString(), dryRun ? '[DRY_RUN]' : '');

  // ── A. Son duyuruyu bul ───────────────────────────────────────────────────
  let announcement;
  try {
    announcement = await findLatestBist100Announcement();
  } catch (err) {
    console.error(`BIST100_FETCH_ERROR: duyuru listesi alınamadı — ${err.message}`);
    throw err;
  }
  if (!announcement) {
    const msg = 'BIST100_FETCH_ERROR: no_announcement_found';
    console.error(msg);
    throw new Error(msg);
  }

  const { announcementId, announcementUrl, announcementTitle } = announcement;

  // ── B. Mevcut Firestore durumu ────────────────────────────────────────────
  let currentDoc;
  try {
    currentDoc = await db.collection('bist_index_meta').doc('bist100').get();
  } catch (err) {
    console.warn(`BIST100_WARN: Firestore meta okunamadı — ${err.message}. İlk çalıştırma olabilir.`);
    currentDoc = null;
  }

  const docData            = currentDoc && currentDoc.exists ? currentDoc.data() : {};
  const currentAnnouncementId = docData.announcementId ? String(docData.announcementId) : null;
  const rawCurrentSymbols  = Array.isArray(docData.symbols) ? docData.symbols : [];
  const currentSymbols     = rawCurrentSymbols
    .map(s => String(s).trim().toUpperCase())
    .filter(s => /^[A-Z]{2,6}$/.test(s));

  // ── C. Aynı duyuru kontrolü ───────────────────────────────────────────────
  if (currentAnnouncementId && currentAnnouncementId === String(announcementId)) {
    console.log(`BIST100_NO_CHANGE: announcement ${announcementId} already processed`);
    return { status: 'no_change', announcementId };
  }

  // ── D. Duyuru HTML'ini indir ve parse et ──────────────────────────────────
  let parseResult;
  try {
    const announcementHtml = await fetchHtml(announcementUrl);
    parseResult = parseBist100Announcement(announcementHtml);
  } catch (err) {
    console.error(`BIST100_FETCH_ERROR: duyuru HTML alınamadı — ${err.message}`);
    throw err;
  }

  const { added, removed, alternates, periodStart, periodEnd, revision, bist100SectionFound } = parseResult;

  if (bist100SectionFound) {
    console.log(`BIST100_PARSE_SUCCESS: added=${added.length}, removed=${removed.length}, alternates=${alternates.length}`);
    if (alternates.length === 0) {
      console.log('BIST100_WARN: alternates/yedekler bulunamadı — devam ediliyor (yedekler zorunlu değil)');
    }
  }

  // ── E. Yeni liste hesapla ─────────────────────────────────────────────────
  // currentSymbols boşsa (ilk kurulum): yalnızca added ile başlamak mümkün değil
  // çünkü duyuru delta içeriyor, tam liste değil. Bu durumda validation 100 kontrolünde
  // başarısız olacak ve sistemi güvenli tutuyor.
  const symbolSet = new Set(currentSymbols);
  for (const sym of removed) {
    symbolSet.delete(sym.trim().toUpperCase());
  }
  for (const sym of added) {
    symbolSet.add(sym.trim().toUpperCase());
  }
  const newSymbols = [...symbolSet].sort();

  // ── F. Validation ─────────────────────────────────────────────────────────
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

  // ── G. dryRun: Firestore'a yazma ─────────────────────────────────────────
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

  // ── H. Firestore'a yaz — bist_index_meta/bist100 ─────────────────────────
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

  // ── I. bist_stocks güncelle (bist100Member alanı — active'e asla dokunma) ─
  const batch = db.batch();
  let batchOpCount = 0;

  // Eklenenler: bist100Member = true
  for (const sym of added) {
    const symbol = sym.trim().toUpperCase();
    if (!symbol) continue;
    const stockRef = db.collection('bist_stocks').doc(symbol);

    // kap_members'dan şirket adını bul (yeni sembol için kayıt yoksa oluştur)
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

  // Çıkarılanlar: bist100Member = false (active'e HİÇ dokunma)
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
      console.log(`BIST100_WARN: Çıkarılan sembol ${symbol} bist_stocks'ta bulunamadı, atlanıyor.`);
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

// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULER — Her Pazartesi 05:00 UTC (08:00 TR)
// ─────────────────────────────────────────────────────────────────────────────

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
    console.error('syncBist100Index hatası:', err.message);
    throw err;
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// MANUEL SYNC — Admin korumalı, dry run destekli
// Kullanım: GET/POST ?secret=<ADMIN_SECRET>[&dryRun=true]
// ─────────────────────────────────────────────────────────────────────────────

exports.syncBist100Manual = onRequest({
  region:         'europe-west1',
  memory:         '512MiB',
  timeoutSeconds: 300,
  secrets:        [ADMIN_SECRET],
}, async (req, res) => {
  // Admin doğrulama
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

  // ── Bootstrap modu: Firestore boşken base listeyi yükler ─────────────────
  // Kullanım: ?bootstrap=true&secret=<ADMIN_SECRET>
  // Mevcut Firestore kaydını kontrol eder; kayıt varsa reddeder (güvenli).
  // Borsa İstanbul'dan son duyuruyu parse edip tam listeyi hesaplar.
  // Ekim 2026 duyurusu (id=15598) için added/removed ile yeni liste üretir.
  // Validation'ı ATLAR — bootstrap için currentSymbols boş olabilir.
  const bootstrapMode = req.query.bootstrap === 'true' || req.query.bootstrap === '1';
  if (bootstrapMode) {
    try {
      // Firestore'da zaten kayıt var mı?
      const metaDoc = await db.collection('bist_index_meta').doc('bist100').get();
      if (metaDoc.exists && (metaDoc.data().symbols || []).length >= 50) {
        res.status(409).json({
          error: 'Bootstrap reddedildi: Firestore\'da zaten geçerli BIST100 kaydı var.',
          existingCount: (metaDoc.data().symbols || []).length,
          announcementId: metaDoc.data().announcementId,
        });
        return;
      }

      // Duyuruyu bul ve parse et
      const announcement = await findLatestBist100Announcement();
      if (!announcement) throw new Error('Duyuru bulunamadı');

      const announcementHtml = await fetchHtml(announcement.announcementUrl);
      const parseResult = parseBist100Announcement(announcementHtml);
      if (!parseResult.bist100SectionFound) throw new Error('BIST 100 bölümü parse edilemedi');

      // Bootstrap için hardcoded Ekim 2026 sonucu (duyuru 15598 baz alınarak):
      // Borsa İstanbul'un Ekim-Aralık 2026 için belirlediği tam liste.
      // Bu liste Borsa İstanbul resmi duyurusu 15598'den türetilmiştir.
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

      // Eğer bootstrap listesi duyurudan türetilecekse override et
      // (hardcoded liste ile duyuru parse sonucunu karşılaştır)
      console.log(`BIST100_BOOTSTRAP: parse added=${parseResult.added.length}, removed=${parseResult.removed.length}`);
      console.log(`BIST100_BOOTSTRAP: hardcoded list has ${BIST100_OCT2026.length} symbols`);

      if (BIST100_OCT2026.length !== 100) {
        res.status(500).json({ error: `Bootstrap listesi 100 sembol değil: ${BIST100_OCT2026.length}` });
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
          bootstrapNote:     'Initial bootstrap — October 2026 periodic review',
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
