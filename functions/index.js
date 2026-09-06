/**
 * Firebase Cloud Function — Temel Göstergeler Güncelleyici
 *
 * BilancoVeri.com'dan 587 BIST hissesinin temel verilerini çeker,
 * Firestore'daki fundamentals/{ticker} belgelerine yazar.
 *
 * Zamanlama: Her gün 08:00, 12:00 ve 18:00 (Türkiye saati = UTC+3)
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * KAP MKK BİLDİRİM SYNC SİSTEMİ
 *
 * MKK VYK API'sinden KAP bildirimlerini merkezi olarak çeker.
 * Flutter uygulaması KAP API'ye HİÇBİR ZAMAN direkt bağlanmaz.
 * API credentials sadece Cloud Function environment'ında tutulur.
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
const KAP_API_KEY = defineSecret('KAP_API_KEY');
const KAP_TOKEN   = defineSecret('KAP_TOKEN');
const ADMIN_SECRET = defineSecret('ADMIN_SECRET'); // Manuel sync koruması

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
// SCHEDULED FUNCTION — Günde 3x: 08:00, 14:00, 20:00 Türkiye (= 05, 11, 17 UTC)
// ─────────────────────────────────────────────────────────────────────────────

exports.syncKapDisclosures = onSchedule({
  schedule:       '0 5,11,17 * * *',
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
      headers: {
        'User-Agent': 'TeknikBakis-Backend/1.0',
        'Accept': 'application/json',
      },
      timeout: 10000,
    }, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(body));
        } catch (e) {
          reject(new Error('JSON parse hatası: ' + e.message));
        }
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('Timeout')); });
  });
}

// ── Tüm şirketlerin özet verilerini çek ─────────────────────────────────────
async function fetchAllFundamentals() {
  const url = 'https://bilancoveri.com/api/v1/sirketler.json';
  const data = await fetchJson(url);
  // API formatı: { companies: [...] } veya { items: [...] }
  return data.companies || data.items || [];
}

// ── Firestore'a toplu yaz (batch — 500 belge sınırı) ────────────────────────
async function writeBatch(items) {
  const BATCH_SIZE = 400;
  let written = 0;

  for (let i = 0; i < items.length; i += BATCH_SIZE) {
    const chunk  = items.slice(i, i + BATCH_SIZE);
    const batch  = db.batch();

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

// ─────────────────────────────────────────────────────────────────────────────
// HALKA ARZ (IPO) SYNC — HalkArz.com → Firestore
// Her 6 saatte bir çalışır. Uygulama artık GitHub'a değil Firestore'a bakar.
//
// Firestore yapısı:
//   ipo_items/{symbol}   — Her hisse bir belge (symbol key)
//   ipo_items/NO_SYMBOL_{hash} — Sembolü henüz bilinmeyen hisseler
//   ipo_meta/feed        — lastUpdated, itemCount, source
// ─────────────────────────────────────────────────────────────────────────────

const HALKARZ_USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36';
const TURKISH_MONTHS = {
  ocak: 0, subat: 1, mart: 2, nisan: 3, mayis: 4, haziran: 5,
  temmuz: 6, agustos: 7, eylul: 8, ekim: 9, kasim: 10, aralik: 11,
};

function cleanText(v) { return v == null ? '' : String(v).replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim(); }
function toIsoOrEmpty(date) { return (date instanceof Date && !isNaN(date)) ? date.toISOString() : ''; }

function parseTurkishDateRange(text) {
  const norm = cleanText(text).toLowerCase()
    .replace(/ğ/g, 'g').replace(/ç/g, 'c').replace(/ş/g, 's')
    .replace(/ü/g, 'u').replace(/ö/g, 'o').replace(/ı/g, 'i');

  // "9-10-11 eylul 2026"
  const m1 = norm.match(/^(\d{1,2})[-\s]+(?:\d{1,2}[-\s]+)*(\d{1,2})\s+([a-z]+)\s+(\d{4})/);
  if (m1) {
    const month = TURKISH_MONTHS[m1[3]];
    if (month !== undefined) {
      const year = parseInt(m1[4]);
      return {
        start: new Date(year, month, parseInt(m1[1]), 12, 0, 0),
        end:   new Date(year, month, parseInt(m1[2]), 12, 0, 0),
      };
    }
  }

  // "31 temmuz - 2 agustos 2026"
  const m2 = norm.match(/^(\d{1,2})\s+([a-z]+)\s*-\s*(\d{1,2})\s+([a-z]+)\s+(\d{4})/);
  if (m2) {
    const sm = TURKISH_MONTHS[m2[2]], em = TURKISH_MONTHS[m2[4]];
    if (sm !== undefined && em !== undefined) {
      const year = parseInt(m2[5]);
      return {
        start: new Date(year, sm, parseInt(m2[1]), 12, 0, 0),
        end:   new Date(year, em, parseInt(m2[3]), 12, 0, 0),
      };
    }
  }

  // "6 agustos 2026" (tek tarih)
  const m3 = norm.match(/^(\d{1,2})\s+([a-z]+)\s+(\d{4})/);
  if (m3) {
    const month = TURKISH_MONTHS[m3[2]];
    if (month !== undefined) {
      const d = new Date(parseInt(m3[3]), month, parseInt(m3[1]), 12, 0, 0);
      return { start: d, end: d };
    }
  }

  return { start: null, end: null };
}

function parseTurkishSingleDate(text) {
  return parseTurkishDateRange(text).start || null;
}

function deriveIpoStatus({ requestStart, requestEnd, listingDate }) {
  const now = new Date();
  if (listingDate && listingDate <= now) return 'trading';
  if (requestEnd && now > new Date(requestEnd.getFullYear(), requestEnd.getMonth(), requestEnd.getDate(), 23, 59, 59)) {
    if (listingDate && listingDate <= now) return 'trading';
    if (listingDate && listingDate > now) return 'pending_listing';
    return 'pending_listing';
  }
  if (requestStart) {
    const start = new Date(requestStart.getFullYear(), requestStart.getMonth(), requestStart.getDate());
    return now < start ? 'upcoming' : 'collecting';
  }
  if (listingDate) {
    const lStart = new Date(listingDate.getFullYear(), listingDate.getMonth(), listingDate.getDate());
    return now < lStart ? 'upcoming' : 'trading';
  }
  return 'upcoming';
}

async function fetchHalkArzItems() {
  const { default: nodeFetch } = await import('node-fetch');

  const homepageRes = await nodeFetch('https://halkarz.com/', {
    headers: { 'User-Agent': HALKARZ_USER_AGENT },
    timeout: 20000,
  });
  if (!homepageRes.ok) throw new Error(`HalkArz ana sayfa: HTTP ${homepageRes.status}`);

  const html = await homepageRes.text();
  const articles = html.split('<article class="index-list');
  const pageItems = [];

  for (let i = 1; i < Math.min(articles.length, 21); i++) {
    const chunk = articles[i].split('</article>')[0];
    const nameMatch = chunk.match(/class="il-halka-arz-sirket"[^>]*>.*?<a\s+href="([^"]+)"[^>]*>(.*?)<\/a>/s);
    if (!nameMatch) continue;
    const url = nameMatch[1];
    const name = cleanText(nameMatch[2]);
    const codeMatch = chunk.match(/class="il-bist-kod"\s*>([^<]+)/s);
    const symbol = codeMatch ? cleanText(codeMatch[1]).toUpperCase() : '';
    const dateMatch = chunk.match(/<time datetime="([^"]+)"/);
    const dateText = dateMatch ? cleanText(dateMatch[1]) : '';
    pageItems.push({ companyName: name, symbol, url, requestDates: dateText });
  }

  console.log(`HalkArz: ${pageItems.length} hisse listelendi, detaylar çekiliyor...`);

  const results = [];
  for (const item of pageItems) {
    try {
      await new Promise(r => setTimeout(r, 500));
      const detailRes = await nodeFetch(item.url, { headers: { 'User-Agent': HALKARZ_USER_AGENT }, timeout: 15000 });
      if (!detailRes.ok) continue;
      const detailHtml = await detailRes.text();

      const priceMatch = detailHtml.match(/Halka\s+Arz\s+Fiyat[^<]*<\/td>\s*<td[^>]*>(?:<strong[^>]*>)?(.*?)(?:<\/strong>)?<\/td>/is);
      const price = priceMatch ? cleanText(priceMatch[1]) : '-';

      const distMatch = detailHtml.match(/Da[gğ][iı]t[iı]m\s+Y[oö]ntemi[^<]*<\/td>\s*<td[^>]*>(?:<strong[^>]*>)?(.*?)(?:<\/strong>)?<\/td>/is);
      const distributionType = distMatch ? cleanText(distMatch[1]) : '-';

      const lotMatch = detailHtml.match(/Pay\s*:?[^<]*<\/td>\s*<td[^>]*>(?:<strong[^>]*>)?(.*?)(?:<\/strong>)?<\/td>/is);
      const lot = lotMatch ? cleanText(lotMatch[1]) : '-';

      const listingPatterns = [
        /Bist\s+[İI]lk\s+[İI]şlem\s+Tarihi[^<]*<\/td>\s*<td[^>]*>(?:<strong[^>]*>)?(.*?)(?:<\/strong>)?<\/td>/is,
        /[İI]lk\s+[İI]şlem\s+Tarihi[^<]*<\/td>\s*<td[^>]*>(?:<strong[^>]*>)?(.*?)(?:<\/strong>)?<\/td>/is,
        /Borsada\s+[İI]şlem[^<]*<\/td>\s*<td[^>]*>(?:<strong[^>]*>)?(.*?)(?:<\/strong>)?<\/td>/is,
      ];
      let listingDateText = '';
      for (const pat of listingPatterns) {
        const m = detailHtml.match(pat);
        if (m) { listingDateText = cleanText(m[1]); break; }
      }
      const listingDate = parseTurkishSingleDate(listingDateText);

      const kapUrlMatch = detailHtml.match(/https?:\/\/(?:www\.)?kap\.org\.tr\/[^\s"'>]+/i);
      const kapUrl = kapUrlMatch ? kapUrlMatch[0] : '';

      const dateRange = parseTurkishDateRange(item.requestDates);

      const status = deriveIpoStatus({
        requestStart: dateRange.start,
        requestEnd:   dateRange.end,
        listingDate,
      });

      results.push({
        companyName:      item.companyName,
        requestDates:     item.requestDates || '-',
        requestStart:     toIsoOrEmpty(dateRange.start),
        requestEnd:       toIsoOrEmpty(dateRange.end),
        price:            price || '-',
        lot:              lot || '-',
        distributionType: distributionType || '-',
        symbol:           item.symbol,
        status,
        listingDate:      toIsoOrEmpty(listingDate),
        kapUrl,
        source:           'HalkArz',
        publishedAt:      new Date().toISOString(),
      });
    } catch (err) {
      console.warn(`HalkArz detay hatası (${item.symbol || item.companyName}):`, err.message);
    }
  }

  return results;
}

async function writeIpoItemsToFirestore(items) {
  if (items.length === 0) return 0;

  // Deduplication: aynı sembol varsa status önceliğine göre en iyiyi tut
  const STATUS_PRIORITY = { trading: 4, pending_listing: 3, collecting: 2, upcoming: 1 };
  const deduped = new Map();

  for (const item of items) {
    const key = item.symbol ? item.symbol.toUpperCase() : `NO_SYMBOL_${item.companyName.replace(/\s+/g, '_').substring(0, 30)}`;
    const existing = deduped.get(key);
    if (!existing) {
      deduped.set(key, item);
    } else {
      const ep = STATUS_PRIORITY[existing.status] || 0;
      const np = STATUS_PRIORITY[item.status] || 0;
      if (np > ep) {
        deduped.set(key, item);
      } else if (np === ep) {
        // Eşit öncelikte: daha yeni publishedAt kazanır
        if ((item.publishedAt || '') > (existing.publishedAt || '')) {
          deduped.set(key, item);
        }
      }
    }
  }

  const BATCH_SIZE = 400;
  const entries = [...deduped.entries()];
  let written = 0;

  for (let i = 0; i < entries.length; i += BATCH_SIZE) {
    const chunk = entries.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const [docId, item] of chunk) {
      const ref = db.collection('ipo_items').doc(docId);
      batch.set(ref, {
        ...item,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    await batch.commit();
    written += chunk.length;
  }

  // Meta belge
  await db.collection('ipo_meta').doc('feed').set({
    lastUpdated:  FieldValue.serverTimestamp(),
    itemCount:    written,
    source:       'HalkArz',
    lastSyncedAt: new Date().toISOString(),
  });

  return written;
}

exports.syncIpoFeed = onSchedule({
  schedule:       '0 */6 * * *',   // Her 6 saatte bir: 00:00, 06:00, 12:00, 18:00 UTC
  timeZone:       'UTC',
  region:         'europe-west1',
  memory:         '512MiB',
  timeoutSeconds: 300,
}, async () => {
  console.log('IPO sync başladı:', new Date().toISOString());
  try {
    const items = await fetchHalkArzItems();
    if (items.length === 0) { console.warn('HalkArz: Hiç kayıt bulunamadı'); return; }
    const count = await writeIpoItemsToFirestore(items);
    console.log(`IPO sync tamamlandı: ${count} kayıt Firestore'a yazıldı`);
  } catch (err) {
    console.error('IPO sync hatası:', err.message);
    throw err;
  }
});

exports.syncIpoManual = onRequest({
  region:         'europe-west1',
  memory:         '512MiB',
  timeoutSeconds: 300,
  secrets:        [ADMIN_SECRET],
}, async (req, res) => {
  const adminSecret = ADMIN_SECRET.value().trim();
  const provided    = (req.headers['x-admin-secret'] || req.query.secret || '').trim();
  if (!adminSecret || provided !== adminSecret) {
    res.status(403).json({ error: 'Unauthorized' });
    return;
  }
  try {
    const items = await fetchHalkArzItems();
    const count = await writeIpoItemsToFirestore(items);
    res.json({ success: true, count });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


  schedule: '0 5,9,15 * * *',   // cron: dakika saat gün ay haftaGünü
  timeZone: 'UTC',
  region:   'europe-west1',      // Firebase'e yakın bölge
  memory:   '256MiB',
  timeoutSeconds: 120,
}, async (event) => {
  console.log('Temel göstergeler güncelleme başladı:', new Date().toISOString());

  try {
    const items = await fetchAllFundamentals();
    console.log(`${items.length} hisse verisi alındı`);

    if (items.length === 0) {
      console.warn('Veri boş geldi, güncelleme yapılmadı');
      return;
    }

    await writeBatch(items);
    console.log('Güncelleme tamamlandı:', items.length, 'hisse');

    // Meta belge — son güncelleme zamanı (Flutter uygulaması okuyabilir)
    await db.collection('meta').doc('fundamentals').set({
      lastUpdatedAt:  FieldValue.serverTimestamp(),
      tickerCount:    items.length,
      source:         'BilancoVeri/KAP',
      attribution:    'Veri: KAP/Borsa İstanbul, derleyen BilancoVeri.com',
    });

  } catch (err) {
    console.error('Güncelleme hatası:', err);
    throw err;
  }
});

// ── Manuel tetikleme (test için HTTP endpoint) ───────────────────────────────
// Sadece geliştirme ortamında kullan — deploy sonrası isteğe göre silebilirsin
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
