import { promises as fs } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');
const dataDir = path.join(rootDir, 'data');
const outputPath = path.join(dataDir, 'ipo_feed.json');
const manualOverridesPath = path.join(dataDir, 'ipo_manual_overrides.json');

const TURKISH_MONTHS = {
  ocak: 0, subat: 1, mart: 2, nisan: 3, mayis: 4, haziran: 5,
  temmuz: 6, agustos: 7, eylul: 8, ekim: 9, kasim: 10, aralik: 11
};

const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function main() {
  await fs.mkdir(dataDir, { recursive: true });

  const [manualOverrides, existingFeed] = await Promise.all([
    readJsonArray(manualOverridesPath),
    readExistingFeed(outputPath),
  ]);

  const records = new Map();

  // Load existing feed items
  for (const item of existingFeed.items) {
    records.set(buildKey(item), normalizeItem(item));
  }

  // Fetch using MKK API if credentials are configured
  const mkkUsername = process.env.MKK_USERNAME || '';
  const mkkPassword = process.env.MKK_PASSWORD || '';
  const mkkApiUrl = process.env.MKK_API_URL || 'https://apigwdev.mkk.com.tr/api/vyk';

  let hasMkkSuccess = false;
  if (mkkUsername && mkkPassword) {
    console.log('MKK API kimlik bilgileri tespit edildi. Resmi MKK API üzerinden veri çekiliyor...');
    try {
      const mkkItems = await fetchFromMkkApi(mkkUsername, mkkPassword, mkkApiUrl);
      if (mkkItems.length > 0) {
        console.log(`MKK API'den ${mkkItems.length} adet bildirim işlendi.`);
        for (const item of mkkItems) {
          const key = buildKey(item);
          const previous = records.get(key);
          records.set(key, mergeItems(previous, item));
        }
        hasMkkSuccess = true;
      }
    } catch (error) {
      console.warn('MKK API hatası (HalkArz.com kazıyıcıya geçiş yapılıyor):', error.message || error);
    }
  } else {
    console.log('MKK API kimlik bilgileri ayarlanmamış. Kazıyıcı (Scraper) moduna geçiliyor...');
  }

  // Fetch from HalkArz.com as primary source/fallback
  console.log('HalkArz.com üzerinden halka arz listesi çekiliyor...');
  try {
    const scraperItems = await fetchFromHalkArzScraper();
    console.log(`HalkArz.com'dan ${scraperItems.length} adet halka arz güncel bilgisi çekildi.`);
    for (const item of scraperItems) {
      const key = buildKey(item);
      const previous = records.get(key);
      records.set(key, mergeItems(previous, item));
    }
  } catch (error) {
    console.error('HalkArz.com kazıyıcı hatası:', error.message || error);
    if (!hasMkkSuccess) {
      console.warn('Hem MKK hem de HalkArz.com başarısız oldu. Mevcut feed korunacak.');
    }
  }

  // Apply manual overrides (always have highest priority)
  for (const overrideItem of manualOverrides) {
    const key = buildKey(overrideItem);
    const previous = records.get(key);
    records.set(key, mergeItems(previous, overrideItem));
  }

  // Finalize, sort, and output
  const items = [...records.values()]
    .map((item) => finalizeItem(item))
    .sort(compareItemsDesc);

  const output = {
    lastUpdated: new Date().toISOString(),
    source: hasMkkSuccess ? 'MKK API & Fallback' : 'HalkArz Scraper',
    items,
  };

  await fs.writeFile(outputPath, `${JSON.stringify(output, null, 2)}\n`, 'utf8');
  console.log(`ipo_feed.json güncellendi. Kayıt sayısı: ${items.length}`);
}

/**
 * -------------------------------------------------------------
 * MKK API INTEGRATION
 * -------------------------------------------------------------
 */
async function fetchFromMkkApi(username, password, apiUrl) {
  const authHeader = 'Basic ' + Buffer.from(`${username}:${password}`).toString('base64');
  const headers = {
    'Authorization': authHeader,
    'Accept': 'application/json',
    'User-Agent': USER_AGENT
  };

  // 1. Get last index
  console.log('MKK: Son bildirim indexi alınıyor...');
  const lastIndexRes = await fetch(`${apiUrl}/lastDisclosureIndex`, { headers });
  if (!lastIndexRes.ok) {
    throw new Error(`lastDisclosureIndex başarısız: HTTP ${lastIndexRes.status}`);
  }
  const lastIndexJson = await lastIndexRes.json();
  const lastIndexStr = lastIndexJson?.lastDisclosureIndex || '';
  if (!lastIndexStr) {
    throw new Error('lastDisclosureIndex değeri boş döndü.');
  }
  const lastIndex = parseInt(lastIndexStr, 10);
  console.log(`MKK: Son bildirim indexi: ${lastIndex}`);

  // 2. Fetch disclosures from lastIndex - 300
  const startIndex = Math.max(1, lastIndex - 300);
  const disclosuresUrl = `${apiUrl}/disclosures?disclosureIndex=${startIndex}`;
  console.log(`MKK: Bildirimler listeleniyor (${startIndex} indexinden itibaren)...`);
  
  const discRes = await fetch(disclosuresUrl, { headers });
  if (!discRes.ok) {
    throw new Error(`disclosures listeleme başarısız: HTTP ${discRes.status}`);
  }
  
  const discPayload = await discRes.json();
  // Handle if it returns array directly, or items wrapped in object
  const rawList = Array.isArray(discPayload) 
    ? discPayload 
    : Array.isArray(discPayload?.items) 
    ? discPayload.items 
    : Array.isArray(discPayload?.data)
    ? discPayload.data
    : [discPayload].filter(Boolean);

  console.log(`MKK: Toplam ${rawList.length} adet ham bildirim alındı. Halka arz ile ilgili olanlar taranıyor...`);

  const results = [];
  const ipoKeywords = ['halka arz', 'talep toplama', 'fiyat tespit', 'izahname', 'borsada islem', 'paylarinin halka arzi'];

  for (const disc of rawList) {
    const title = String(disc.title || disc.companyName || '').toLowerCase();
    const sub = String(disc.disclosureClass || disc.disclosureType || '').toLowerCase();
    
    const isPotentiallyIpo = ipoKeywords.some(kw => title.includes(kw) || sub.includes(kw)) ||
      disc.disclosureClass === 'ODA' || disc.disclosureType === 'FR';

    if (!isPotentiallyIpo) continue;

    const id = disc.disclosureIndex || '';
    if (!id) continue;

    // Fetch details for matches
    try {
      await sleep(200); // polite rate limit
      const detailRes = await fetch(`${apiUrl}/disclosureDetail/${id}`, { headers });
      if (!detailRes.ok) continue;

      const detail = await detailRes.json();
      const subject = String(detail?.subject?.tr || '').toLowerCase();
      const summary = String(detail?.summary?.tr || '').toLowerCase();
      const combinedText = `${subject} | ${summary}`;

      const isIpoRelated = ipoKeywords.some(kw => combinedText.includes(kw));
      if (!isIpoRelated) continue;

      console.log(`MKK: Halka arz bildirimi bulundu: ${detail.senderTitle || id}`);

      const publishDate = parseDate(detail.time);
      const derivedSymbol = (detail.senderExchCodes && detail.senderExchCodes[0]) || '';
      
      const item = {
        companyName: cleanText(detail.senderTitle),
        requestDates: '',
        requestStart: null,
        requestEnd: null,
        price: parsePrice(combinedText),
        lot: parseLot(combinedText),
        distributionType: parseDistributionType(combinedText),
        symbol: String(derivedSymbol).toUpperCase(),
        status: '',
        listingDate: null,
        kapUrl: detail.link || `https://www.kap.org.tr/tr/Bildirim/${id}`,
        source: 'KAP',
        publishedAt: toIso(publishDate)
      };

      const range = parseDateRange(combinedText);
      if (range.start) item.requestStart = toIso(range.start);
      if (range.end) item.requestEnd = toIso(range.end);
      item.requestDates = buildRequestDatesLabel(range.start, range.end);

      results.push(item);
    } catch (err) {
      console.warn(`MKK: Bildirim detay hatası (${id}):`, err.message || err);
    }
  }

  return results;
}

/**
 * -------------------------------------------------------------
 * HALKARZ.COM SCRAPER INTEGRATION
 * -------------------------------------------------------------
 */
async function fetchFromHalkArzScraper() {
  const homepageUrl = 'https://halkarz.com/';
  const res = await fetch(homepageUrl, {
    headers: { 'User-Agent': USER_AGENT }
  });
  if (!res.ok) {
    throw new Error(`HalkArz.com ana sayfasına erişilemedi: HTTP ${res.status}`);
  }

  const html = await res.text();
  const articles = html.split('<article class="index-list');
  const items = [];

  // Parse up to the top 20 items on the homepage
  const maxItems = Math.min(articles.length, 21);
  for (let i = 1; i < maxItems; i++) {
    const chunk = articles[i].split('</article>')[0];

    const nameMatch = chunk.match(/class="il-halka-arz-sirket"[^>]*>.*?<a\s+href="([^"]+)"[^>]*>(.*?)<\/a>/s);
    if (!nameMatch) continue;

    const url = nameMatch[1];
    const name = cleanText(nameMatch[2]);

    const codeMatch = chunk.match(/class="il-bist-kod"\s*>([^<]+)/s);
    const symbol = codeMatch ? cleanText(codeMatch[1]).toUpperCase() : '';

    const dateMatch = chunk.match(/<time datetime="([^"]+)"/);
    const dateText = dateMatch ? cleanText(dateMatch[1]) : '';

    items.push({
      companyName: name,
      symbol,
      url,
      requestDates: dateText
    });
  }

  console.log(`HalkArz.com: Ana sayfadan ${items.length} şirket listelendi. Detay sayfaları çekiliyor...`);

  const scraperResults = [];
  for (const item of items) {
    try {
      await sleep(400); // Be polite to the server
      console.log(`HalkArz.com: Detay çekiliyor -> ${item.symbol || item.companyName}`);
      const detailRes = await fetch(item.url, {
        headers: { 'User-Agent': USER_AGENT }
      });
      if (!detailRes.ok) continue;

      const detailHtml = await detailRes.text();

      // Parse Price
      const priceMatch = detailHtml.match(/Halka\s+Arz\s+Fiyatı.*?<\/td>\s*<td[^>]*>(?:<strong[^>]*>)?(.*?)(?:<\/strong>)?<\/td>/i);
      const price = priceMatch ? cleanText(priceMatch[1]) : '';

      // Parse Distribution Type
      const distMatch = detailHtml.match(/Dağıtım\s+Yöntemi.*?<\/td>\s*<td[^>]*>(?:<strong[^>]*>)?(.*?)(?:<\/strong>)?<\/td>/i);
      const distributionType = distMatch ? cleanText(distMatch[1]) : '';

      // Parse Lot
      const payMatch = detailHtml.match(/Pay\s*:.*?<\/td>\s*<td[^>]*>(?:<strong[^>]*>)?(.*?)(?:<\/strong>)?<\/td>/i);
      const lot = payMatch ? cleanText(payMatch[1]) : '';

      // Parse Listing Date
      const listingMatch = detailHtml.match(/Bist\s+İlk\s+İşlem\s+Tarihi.*?<\/td>\s*<td[^>]*>(?:<strong[^>]*>)?(.*?)(?:<\/strong>)?<\/td>/i);
      const listingDateText = listingMatch ? cleanText(listingMatch[1]) : '';
      const listingDate = parseTurkishSingleDate(listingDateText);

      // Parse KAP Link
      const kapUrlMatch = detailHtml.match(/https?:\/\/(?:www\.)?kap\.org\.tr\/[^\s"'>]+/i);
      const kapUrl = kapUrlMatch ? kapUrlMatch[0] : '';

      // Parse request dates and calculate boundaries
      const dateRange = parseTurkishDateRange(item.requestDates);

      scraperResults.push({
        companyName: item.companyName,
        requestDates: item.requestDates,
        requestStart: toIso(dateRange.start),
        requestEnd: toIso(dateRange.end),
        price: price || '-',
        lot: lot || '-',
        distributionType: distributionType || '-',
        symbol: item.symbol,
        status: '', // Derived automatically in finalize
        listingDate: toIso(listingDate),
        kapUrl: kapUrl || '',
        source: 'HalkArz',
        publishedAt: new Date().toISOString()
      });
    } catch (err) {
      console.warn(`HalkArz.com: Detay çekme hatası (${item.symbol}):`, err.message || err);
    }
  }

  return scraperResults;
}

/**
 * -------------------------------------------------------------
 * CORE LOGIC & PARSING HELPERS
 * -------------------------------------------------------------
 */
function finalizeItem(item) {
  const requestStart = parseDate(item.requestStart);
  const requestEnd = parseDate(item.requestEnd);
  const listingDate = parseDate(item.listingDate);

  const normalized = {
    companyName: cleanText(item.companyName),
    requestDates:
      cleanText(item.requestDates) ||
      buildRequestDatesLabel(requestStart, requestEnd) ||
      '-',
    requestStart: toIso(requestStart),
    requestEnd: toIso(requestEnd),
    price: cleanText(item.price),
    lot: cleanText(item.lot),
    distributionType: cleanText(item.distributionType),
    symbol: cleanText(item.symbol).toUpperCase(),
    status:
      cleanText(item.status) ||
      deriveStatus({ requestStart, requestEnd, listingDate }),
    listingDate: toIso(listingDate),
    kapUrl: cleanText(item.kapUrl),
    source: cleanText(item.source) || 'KAP',
    publishedAt: toIso(parseDate(item.publishedAt)) || new Date().toISOString(),
  };

  if (!normalized.price) normalized.price = '-';
  if (!normalized.lot) normalized.lot = '-';
  if (!normalized.distributionType) normalized.distributionType = '-';

  return normalized;
}

function mergeItems(previous, next) {
  if (!previous) return normalizeItem(next);

  const merged = { ...previous };

  for (const [key, value] of Object.entries(normalizeItem(next))) {
    if (hasMeaningfulValue(value)) {
      // Manual Override source has priority, only override if next source is not manual overrides OR if next source is also manual override
      if (previous.source === 'Manual Override' && next.source !== 'Manual Override') {
        continue;
      }
      merged[key] = value;
    }
  }

  return merged;
}

function normalizeItem(item) {
  return {
    companyName: cleanText(item.companyName),
    requestDates: cleanText(item.requestDates),
    requestStart: toIso(parseDate(item.requestStart)),
    requestEnd: toIso(parseDate(item.requestEnd)),
    price: cleanText(item.price),
    lot: cleanText(item.lot),
    distributionType: cleanText(item.distributionType),
    symbol: cleanText(item.symbol).toUpperCase(),
    status: cleanText(item.status),
    listingDate: toIso(parseDate(item.listingDate)),
    kapUrl: cleanText(item.kapUrl),
    source: cleanText(item.source),
    publishedAt: toIso(parseDate(item.publishedAt)),
  };
}

function compareItemsDesc(a, b) {
  const aDate = sortDate(a);
  const bDate = sortDate(b);
  return bDate - aDate;
}

function sortDate(item) {
  return (
    parseDate(item.listingDate)?.getTime() ||
    parseDate(item.requestEnd)?.getTime() ||
    parseDate(item.requestStart)?.getTime() ||
    parseDate(item.publishedAt)?.getTime() ||
    0
  );
}

function buildKey(item) {
  const symbol = cleanText(item.symbol).toUpperCase();
  if (symbol) return symbol;
  return normalizeText(item.companyName || 'bilinmeyen');
}

function deriveStatus({ requestStart, requestEnd, listingDate }) {
  const now = new Date();

  if (listingDate && listingDate <= now) {
    return 'trading';
  }

  if (requestStart && requestEnd) {
    if (now < startOfDay(requestStart)) return 'upcoming';
    if (now <= endOfDay(requestEnd)) return 'collecting';
    return 'trading';
  }

  if (requestStart) {
    return now < startOfDay(requestStart) ? 'upcoming' : 'collecting';
  }

  return 'upcoming';
}

function parseDateRange(text) {
  const match = text.match(
    /(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})\s*(?:-|–|—|ve|ile|to)\s*(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})/i,
  );

  if (!match) {
    return { start: null, end: null };
  }

  return {
    start: parseDate(match[1]),
    end: parseDate(match[2]),
  };
}

function parseTurkishDateRange(text) {
  const normalized = normalizeText(text);
  
  // Format: "29-30-31 temmuz 2026"
  const matchSingleMonth = normalized.match(/^(\d{1,2})[-./\s]+(?:\d{1,2}[-./\s]+)*(\d{1,2})\s+([a-zıüşöğç]+)\s+(\d{4})/);
  if (matchSingleMonth) {
    const startDay = parseInt(matchSingleMonth[1], 10);
    const endDay = parseInt(matchSingleMonth[2], 10);
    const monthName = matchSingleMonth[3];
    const year = parseInt(matchSingleMonth[4], 10);
    
    const month = TURKISH_MONTHS[monthName];
    if (month !== undefined) {
      return {
        start: new Date(year, month, startDay, 12, 0, 0),
        end: new Date(year, month, endDay, 12, 0, 0)
      };
    }
  }
  
  // Format: "31 temmuz - 2 agustos 2026"
  const matchMultiMonth = normalized.match(/^(\d{1,2})\s+([a-zıüşöğç]+)\s*-\s*(\d{1,2})\s+([a-zıüşöğç]+)\s+(\d{4})/);
  if (matchMultiMonth) {
    const startDay = parseInt(matchMultiMonth[1], 10);
    const startMonthName = matchMultiMonth[2];
    const endDay = parseInt(matchMultiMonth[3], 10);
    const endMonthName = matchMultiMonth[4];
    const year = parseInt(matchMultiMonth[5], 10);
    
    const startMonth = TURKISH_MONTHS[startMonthName];
    const endMonth = TURKISH_MONTHS[endMonthName];
    if (startMonth !== undefined && endMonth !== undefined) {
      return {
        start: new Date(year, startMonth, startDay, 12, 0, 0),
        end: new Date(year, endMonth, endDay, 12, 0, 0)
      };
    }
  }
  
  // Single date: "6 agustos 2026"
  const matchSingleDate = normalized.match(/^(\d{1,2})\s+([a-zıüşöğç]+)\s+(\d{4})/);
  if (matchSingleDate) {
    const day = parseInt(matchSingleDate[1], 10);
    const monthName = matchSingleDate[2];
    const year = parseInt(matchSingleDate[3], 10);
    const month = TURKISH_MONTHS[monthName];
    if (month !== undefined) {
      const d = new Date(year, month, day, 12, 0, 0);
      return { start: d, end: d };
    }
  }

  return { start: null, end: null };
}

function parseTurkishSingleDate(text) {
  if (!text) return null;
  const dateRange = parseTurkishDateRange(text);
  return dateRange.start || null;
}

function parsePrice(text) {
  const match = text.match(
    /(\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})|\d+(?:,\d{2}))\s*(?:tl|try)/i,
  );
  return match ? `${match[1].replace(/\s+/g, '')} TL` : '';
}

function parseLot(text) {
  const match = text.match(
    /(\d{1,3}(?:[.\s]\d{3})+|\d+)\s*(?:lot|adet|nominal)/i,
  );
  return match ? `${match[1].replace(/\s+/g, '')} lot` : '';
}

function parseDistributionType(text) {
  const normalized = normalizeText(text);
  if (normalized.includes('esit dagitim') || normalized.includes('eşit dağıtım')) {
    return 'Esit Dagitim';
  }
  if (
    normalized.includes('oransal dagitim') ||
    normalized.includes('oransal dağıtım')
  ) {
    return 'Oransal Dagitim';
  }
  if (normalized.includes('borsada satis') || normalized.includes('borsada satış')) {
    return 'Borsada Satis';
  }
  return '';
}

function buildRequestDatesLabel(start, end) {
  if (!start && !end) return '';
  if (start && end) return `${formatDate(start)} - ${formatDate(end)}`;
  return formatDate(start || end);
}

function formatDate(date) {
  return `${String(date.getDate()).padStart(2, '0')}.${String(
    date.getMonth() + 1,
  ).padStart(2, '0')}.${date.getFullYear()}`;
}

function parseDate(value) {
  if (!value) return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;

  const raw = cleanText(value);
  if (!raw) return null;

  const isoDate = new Date(raw);
  if (!Number.isNaN(isoDate.getTime())) return isoDate;

  const normalized = raw.replaceAll('/', '.').replaceAll('-', '.');
  const parts = normalized.split('.');
  if (parts.length === 3) {
    const [dayRaw, monthRaw, yearRaw] = parts;
    const day = Number(dayRaw);
    const month = Number(monthRaw);
    const year = Number(yearRaw.length === 2 ? `20${yearRaw}` : yearRaw);
    const date = new Date(year, month - 1, day);
    if (!Number.isNaN(date.getTime())) return date;
  }

  return null;
}

function cleanText(value) {
  return value == null ? '' : String(value).trim();
}

function hasMeaningfulValue(value) {
  return value !== null && value !== undefined && String(value).trim() !== '';
}

function toIso(value) {
  return value instanceof Date && !Number.isNaN(value.getTime())
    ? value.toISOString()
    : '';
}

function normalizeText(value) {
  return cleanText(value)
    .toLowerCase()
    .replaceAll('ç', 'c')
    .replaceAll('ğ', 'g')
    .replaceAll('ı', 'i')
    .replaceAll('ö', 'o')
    .replaceAll('ş', 's')
    .replaceAll('ü', 'u');
}

function startOfDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate(), 0, 0, 0);
}

function endOfDay(date) {
  return new Date(
    date.getFullYear(),
    date.getMonth(),
    date.getDate(),
    23,
    59,
    59,
  );
}

async function readJsonArray(filePath) {
  try {
    const raw = await fs.readFile(filePath, 'utf8');
    const data = JSON.parse(raw);
    return Array.isArray(data) ? data : [];
  } catch {
    return [];
  }
}

async function readExistingFeed(filePath) {
  try {
    const raw = await fs.readFile(filePath, 'utf8');
    const data = JSON.parse(raw);
    return {
      lastUpdated: data?.lastUpdated ?? '',
      source: data?.source ?? '',
      items: Array.isArray(data?.items) ? data.items : [],
    };
  } catch {
    return { lastUpdated: '', source: '', items: [] };
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
