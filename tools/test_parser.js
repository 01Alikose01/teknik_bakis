/**
 * Local parse testi — Firebase bağlantısı gerektirmez.
 * Gerçek duyuru 15598'i fetch eder ve parseBist100Announcement çıktısını gösterir.
 */
const https = require('https');

function fetchHtml(url) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, {
      headers: {
        'User-Agent': 'TeknikBakis-Backend/1.0',
        'Accept': 'text/html,application/xhtml+xml',
      },
      timeout: 25000,
    }, (res) => {
      if ((res.statusCode === 301 || res.statusCode === 302) && res.headers.location) {
        return fetchHtml(res.headers.location).then(resolve).catch(reject);
      }
      if (res.statusCode !== 200) {
        return reject(new Error(`HTTP ${res.statusCode}: ${url}`));
      }
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('Timeout')); });
  });
}

function parseBist100Announcement(html) {
  const text = html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ').replace(/&#\d+;/g, ' ')
    .replace(/\s+/g, ' ').trim();

  const bist100Start = text.search(/BIST\s+100\s+INDEX/i);
  if (bist100Start < 0) {
    return { added: [], removed: [], alternates: [], bist100SectionFound: false };
  }

  const nextSectionPattern = /BIST\s+(?:500|LIQUID|SUSTAINABILITY|30\s+INDEX|50\s+INDEX)/i;
  const afterBist100 = text.slice(bist100Start + 15);
  const nextSectionMatch = afterBist100.search(nextSectionPattern);
  const bist100Section = nextSectionMatch >= 0
    ? afterBist100.slice(0, nextSectionMatch)
    : afterBist100.slice(0, 10000);

  const includedIdx   = bist100Section.search(/STOCKS\s+TO\s+BE\s+INCLUDED/i);
  const excludedIdx   = bist100Section.search(/STOCKS\s+TO\s+BE\s+EXCLUDED/i);
  const substituteIdx = bist100Section.search(/SUBSTITUTE\s+STOCKS/i);

  const includedBlock   = includedIdx  >= 0 ? bist100Section.slice(includedIdx  + 24, excludedIdx  >= 0 ? excludedIdx  : undefined) : '';
  const excludedBlock   = excludedIdx  >= 0 ? bist100Section.slice(excludedIdx  + 23, substituteIdx >= 0 ? substituteIdx : undefined) : '';
  const substituteBlock = substituteIdx >= 0 ? bist100Section.slice(substituteIdx + 17) : '';

  function extractSymbols(block) {
    if (!block) return [];
    const symbols = [];
    const SKIP = new Set(['INDEX','BIST','STOCKS','TO','BE','INCLUDED','EXCLUDED','SUBSTITUTE']);
    const symPattern = /\b(\d+)\s*([A-Z]{2,6})\b/g;
    let sm;
    while ((sm = symPattern.exec(block)) !== null) {
      const sym = sm[2];
      if (SKIP.has(sym)) continue;
      if (!symbols.includes(sym)) symbols.push(sym);
    }
    return symbols;
  }

  const added      = extractSymbols(includedBlock);
  const removed    = extractSymbols(excludedBlock);
  const alternates = extractSymbols(substituteBlock);

  // Dönem
  let periodStart = '', periodEnd = '', revision = '';
  const pm = text.match(/PERIOD\s+((?:JANUARY|FEBRUARY|MARCH|APRIL|MAY|JUNE|JULY|AUGUST|SEPTEMBER|OCTOBER|NOVEMBER|DECEMBER)\s+\d{1,2},?\s+\d{4})\s*[-\u2013\u2014]\s*((?:JANUARY|FEBRUARY|MARCH|APRIL|MAY|JUNE|JULY|AUGUST|SEPTEMBER|OCTOBER|NOVEMBER|DECEMBER)\s+\d{1,2},?\s+\d{4})/i);
  if (pm) {
    periodStart = pm[1].trim();
    periodEnd   = pm[2].trim();
    const endUpper = pm[2].trim().toUpperCase();
    const yr = (pm[2].match(/(\d{4})/) || [])[1] || '';
    if (endUpper.startsWith('MARCH'))     revision = `${yr}-Q1`;
    else if (endUpper.startsWith('JUNE'))  revision = `${yr}-Q2`;
    else if (endUpper.startsWith('SEPT'))  revision = `${yr}-Q3`;
    else if (endUpper.startsWith('DECE'))  revision = `${yr}-Q4`;
    else revision = yr;
  }

  return { added, removed, alternates, periodStart, periodEnd, revision, bist100SectionFound: true };
}

// ── Kısa validation ──────────────────────────────────────────────────────────
// Mevcut kBist100Symbols (100 sembol) + delta = yeni liste
const kBist100Symbols = [
  'AKBNK','ALBRK','GARAN','HALKB','ICBCT','ISCTR','ISFIN','ISKUR','KLNMA','SKBNK',
  'TSKB','VAKBN','YKBNK','DOHOL','GLYHO','KCHOL','KOZAA','MPARK','SAHOL','TKFEN',
  'ARCLK','ASELS','ASTOR','CCOLA','CIMSA','DEVA','EREGL','FROTO','GUBRF','KRDMD',
  'OTKAR','PETKM','PGSUS','SASA','THYAO','TOASO','TTRAK','TUPRS','VESTL',
  'AKFYE','AKSEN','AYDEM','AYEN','CWENE','ENKAI','EUPWR','GWIND','IZENR','ODAS',
  'ZOREN','ESEN','BIMAS','LOGO','MAVI','MGROS','SOKM','ULKER','EKGYO','ISGYO',
  'RYGYO','TRGYO','ARDYZ','NETAS','SMART','TCELL','TTKOM','ODINE','AKGRT','ANSGR',
  'ISMEN','DOAS','KARSN','AKSA','BRISA','ECZYT','HEKTS','AEFES','AYGAZ','TATGD',
  'TUKAS','IEYHO','BUCIM','NUHCM','ALKIM','ALTNY','BERA','BFREN','CANTE','EGEEN',
  'GENIL','GESAN','GOLTS','KORDS','KOZAL','MIATK','PENTA','POLHO','SISE','TAVHL',
  'TMSN','TRILC','ULUUN',
];

(async () => {
  try {
    console.log('\n=== BIST100 Parser Test ===\n');

    // 1. Duyuru listesi sayfasından en son duyuruyu bul
    console.log('1. Duyuru listesi taranıyor...');
    const listHtml = await fetchHtml('https://www.borsaistanbul.com/en/announcement');
    const HREF_PATTERN = /href="(\/en\/announcement\/(\d+)\/([^"]*(?:bist-stock-indices-periodic-review|announces-constituent-changes-bist-stock-indices-)[^"]*))"/gi;
    let bestId = -1, bestUrl = null;
    let m;
    while ((m = HREF_PATTERN.exec(listHtml)) !== null) {
      const idNum = parseInt(m[2], 10);
      if (idNum > bestId) { bestId = idNum; bestUrl = `https://www.borsaistanbul.com${m[1]}`; }
    }
    console.log(`   Bulunan duyuru: id=${bestId}, url=${bestUrl}`);

    // 2. Duyuru HTML'ini parse et
    console.log('\n2. Duyuru parse ediliyor...');
    const annHtml = await fetchHtml(bestUrl);
    const result = parseBist100Announcement(annHtml);

    console.log(`   bist100SectionFound: ${result.bist100SectionFound}`);
    console.log(`   added (${result.added.length}):      [${result.added.join(', ')}]`);
    console.log(`   removed (${result.removed.length}):    [${result.removed.join(', ')}]`);
    console.log(`   alternates (${result.alternates.length}): [${result.alternates.join(', ')}]`);
    console.log(`   periodStart: ${result.periodStart}`);
    console.log(`   periodEnd:   ${result.periodEnd}`);
    console.log(`   revision:    ${result.revision}`);

    // 3. Yeni liste hesapla
    console.log('\n3. Yeni liste hesaplanıyor...');
    const symbolSet = new Set(kBist100Symbols);
    for (const s of result.removed) symbolSet.delete(s.trim().toUpperCase());
    for (const s of result.added)   symbolSet.add(s.trim().toUpperCase());
    const newSymbols = [...symbolSet].sort();
    console.log(`   Mevcut: ${kBist100Symbols.length} sembol`);
    console.log(`   Yeni:   ${newSymbols.length} sembol`);

    // 4. Validation
    console.log('\n4. Validation...');
    const valid100 = newSymbols.length === 100;
    const badSym = newSymbols.find(s => !/^[A-Z]{2,6}$/.test(s));
    const overlap = result.added.filter(s => result.removed.includes(s));
    console.log(`   Sembol sayısı 100 mu? ${valid100 ? 'EVET ✓' : 'HAYIR ✗ (' + newSymbols.length + ')'}`);
    console.log(`   Geçersiz sembol: ${badSym || 'yok ✓'}`);
    console.log(`   Added/Removed kesişimi: ${overlap.length > 0 ? overlap.join(',') + ' ✗' : 'yok ✓'}`);

    if (valid100 && !badSym && overlap.length === 0) {
      console.log('\n✅ VALIDATION PASSED — Firestore\'a yazılmaya hazır');
      console.log(`   Yeni semboller (ilk 10): [${newSymbols.slice(0,10).join(', ')}...]`);
    } else {
      console.log('\n❌ VALIDATION FAILED');
    }
  } catch (err) {
    console.error('HATA:', err.message);
    process.exit(1);
  }
})();
