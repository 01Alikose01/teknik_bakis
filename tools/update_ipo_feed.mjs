import { promises as fs } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');
const dataDir = path.join(rootDir, 'data');
const outputPath = path.join(dataDir, 'ipo_feed.json');
const manualOverridesPath = path.join(dataDir, 'ipo_manual_overrides.json');

const KAP_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
  Accept: 'application/json, text/plain, */*',
  'Accept-Language': 'tr-TR,tr;q=0.9',
  Referer: 'https://www.kap.org.tr/',
};

const KAP_ENDPOINTS = [
  'https://www.kap.org.tr/tr/api/disclosures?type=ozel&orderBy=publishDate&orderDir=desc&pageSize=100&pageIndex=0',
  'https://www.kap.org.tr/tr/api/disclosures?orderBy=publishDate&orderDir=desc&pageSize=100&pageIndex=0',
];

const IPO_KEYWORDS = [
  'halka arz',
  'talep toplama',
  'fiyat tespit',
  'izahname',
  'paylarinin halka arzi',
  'paylarinin halka arzı',
  'islem gormeye baslamasi',
  'işlem görmeye başlaması',
  'borsada islem gormeye baslayacak',
  'borsada işlem görmeye başlayacak',
];

async function main() {
  await fs.mkdir(dataDir, { recursive: true });

  const [manualOverrides, existingFeed, disclosures] = await Promise.all([
    readJsonArray(manualOverridesPath),
    readExistingFeed(outputPath),
    fetchKapDisclosures(),
  ]);

  const records = new Map();

  for (const item of existingFeed.items) {
    records.set(buildKey(item), normalizeItem(item));
  }

  for (const disclosure of disclosures) {
    const derived = mapDisclosureToItem(disclosure);
    if (!derived) continue;

    const key = buildKey(derived);
    const previous = records.get(key);
    records.set(key, mergeItems(previous, derived));
  }

  for (const overrideItem of manualOverrides) {
    const key = buildKey(overrideItem);
    const previous = records.get(key);
    records.set(key, mergeItems(previous, overrideItem));
  }

  const items = [...records.values()]
    .map((item) => finalizeItem(item))
    .sort(compareItemsDesc);

  const output = {
    lastUpdated: new Date().toISOString(),
    source: 'KAP cron job',
    items,
  };

  await fs.writeFile(outputPath, `${JSON.stringify(output, null, 2)}\n`, 'utf8');

  console.log(`ipo_feed.json guncellendi. Kayit sayisi: ${items.length}`);
}

async function fetchKapDisclosures() {
  const all = [];

  for (const url of KAP_ENDPOINTS) {
    try {
      const response = await fetch(url, { headers: KAP_HEADERS });
      if (!response.ok) continue;

      const payload = await response.json();
      const list = Array.isArray(payload)
        ? payload
        : Array.isArray(payload?.data)
        ? payload.data
        : Array.isArray(payload?.items)
        ? payload.items
        : [];

      all.push(...list);
      if (all.length > 0) break;
    } catch (error) {
      console.warn(`KAP endpoint hatasi: ${url}`, error);
    }
  }

  if (all.length === 0) {
    console.warn('KAP tarafindan disclosure verisi alinamadi. Mevcut feed korunacak.');
  }
  return all;
}

function mapDisclosureToItem(disclosure) {
  const textParts = [
    disclosure?.title,
    disclosure?.subject,
    disclosure?.summary,
    disclosure?.disclosureClass,
  ].filter(Boolean);

  const combinedText = textParts.join(' | ');
  const normalized = normalizeText(combinedText);
  const isIpoRelated = IPO_KEYWORDS.some((keyword) =>
    normalized.includes(normalizeText(keyword)),
  );

  if (!isIpoRelated) {
    return null;
  }

  const publishDate = parseDate(
    disclosure?.publishDate ?? disclosure?.releaseDate ?? '',
  );

  const item = {
    companyName:
      safeString(disclosure?.companyTitle) ||
      safeString(disclosure?.companyName) ||
      safeString(disclosure?.title),
    requestDates: '',
    requestStart: null,
    requestEnd: null,
    price: parsePrice(combinedText),
    lot: parseLot(combinedText),
    distributionType: parseDistributionType(combinedText),
    symbol: (
      safeString(disclosure?.companyCode) ||
      safeString(disclosure?.stockCode)
    ).toUpperCase(),
    status: '',
    listingDate: parseListingDate(combinedText, publishDate),
    kapUrl: disclosure?.id
        ? `https://www.kap.org.tr/tr/Bildirim/${disclosure.id}`
        : '',
    source: 'KAP',
    publishedAt: toIso(publishDate),
  };

  const range = parseDateRange(combinedText);
  if (range.start) item.requestStart = toIso(range.start);
  if (range.end) item.requestEnd = toIso(range.end);
  item.requestDates = buildRequestDatesLabel(range.start, range.end);

  if (!item.companyName && !item.symbol) {
    return null;
  }

  return item;
}

function finalizeItem(item) {
  const requestStart = parseDate(item.requestStart);
  const requestEnd = parseDate(item.requestEnd);
  const listingDate = parseDate(item.listingDate);

  const normalized = {
    companyName: safeString(item.companyName),
    requestDates:
      safeString(item.requestDates) ||
      buildRequestDatesLabel(requestStart, requestEnd) ||
      '-',
    requestStart: toIso(requestStart),
    requestEnd: toIso(requestEnd),
    price: safeString(item.price),
    lot: safeString(item.lot),
    distributionType: safeString(item.distributionType),
    symbol: safeString(item.symbol).toUpperCase(),
    status:
      safeString(item.status) ||
      deriveStatus({ requestStart, requestEnd, listingDate }),
    listingDate: toIso(listingDate),
    kapUrl: safeString(item.kapUrl),
    source: safeString(item.source) || 'KAP',
    publishedAt: toIso(parseDate(item.publishedAt)),
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
      merged[key] = value;
    }
  }

  return merged;
}

function normalizeItem(item) {
  return {
    companyName: safeString(item.companyName),
    requestDates: safeString(item.requestDates),
    requestStart: toIso(parseDate(item.requestStart)),
    requestEnd: toIso(parseDate(item.requestEnd)),
    price: safeString(item.price),
    lot: safeString(item.lot),
    distributionType: safeString(item.distributionType),
    symbol: safeString(item.symbol).toUpperCase(),
    status: safeString(item.status),
    listingDate: toIso(parseDate(item.listingDate)),
    kapUrl: safeString(item.kapUrl),
    source: safeString(item.source),
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
  const symbol = safeString(item.symbol).toUpperCase();
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

function parseListingDate(text, publishDate) {
  const normalized = normalizeText(text);
  const mentionsTrading =
    normalized.includes('islem gormeye baslamasi') ||
    normalized.includes('borsada islem gormeye baslayacak');

  if (!mentionsTrading) return null;
  return publishDate;
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

  const raw = safeString(value);
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

function safeString(value) {
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
  return safeString(value)
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
