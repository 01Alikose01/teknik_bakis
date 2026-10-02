/**
 * Static parser testi — ağ bağlantısı gerektirmez.
 * Duyuru 15598'den alınan gerçek metin kullanılır (web_fetch ile doğrulandı).
 */

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

// Gerçek duyuru 15598 içeriği (web_fetch ile alındı — tüm endeks bilgileri dahil)
const REAL_CONTENT = `BIST Stock Indices Periodic Review 09/21/2026 The periodic review for determining the stocks to be included in the BIST 30, BIST 50, BIST 100, BIST 500, BIST Liquid Banks, BIST Liquid 10 Ex Banks, BIST Sustainability and BIST Sustainability 25 indices has been completed in accordance with the BIST Market Cap Weighted Stock Indices Methodology. It has been decided to make the changes listed in the below table for the period October 1, 2026 – December 31, 2026. PERIODIC INDEX CHANGES FOR THE PERIOD OCTOBER 1, 2026-DECEMBER 31, 2026 BIST 30 INDEX STOCKS TO BE INCLUDED STOCKS TO BE EXCLUDED SUBSTITUTE STOCKS 1 TRMET TR ANADOLU METAL MADENCILIK 1 DSTKF DESTEK FINANS FAKTORING 1 BTCIM BATICIM BATI ANADOLU 2 TURSG TURKIYE SIGORTA 3 OYAKC OYAK CIMENTO BIST 50 INDEX STOCKS TO BE INCLUDED STOCKS TO BE EXCLUDED SUBSTITUTE STOCKS 1 CVKMD CVK MADEN 1 DSTKF DESTEK FINANS FAKTORING 1 OTKAR OTOKAR 2 CWENE CW ENERJI 2 EFOR EFOR YATIRIM 2 SOKM SOK MARKETLER TICARET 3 DOAS DOGUS OTOMOTIV 3 KTLEV KATILIMEVIM TAS FIN 3 ARCLK ARCELIK 4 ENERY ENERYA ENERJI 4 KUYAS KUYAS YATIRIM 5 MAVI MAVI GIYIM 5 MIATK MIA TEKNOLOJI 6 TSKB TSKB 6 PASEU PASIFIK EURASIA LOJISTIK BIST 100 INDEX STOCKS TO BE INCLUDED STOCKS TO BE EXCLUDED SUBSTITUTE STOCKS 1 AGHOL ANADOLU GRUBU HOLDING 1 BALSU BALSU GIDA 1 KLGYO KILER GMYO 2 AHGAZ AHLATCI DOGALGAZ 2 BSOKE BATICIM CIMENTO 2 RYGYO REYSAS GMYO 3 AKCNS AKCANSA 3 DAPGM DAP GAYRIMENKUL 3 TMSN TUMOSAN MOTOR VE TRAKTOR 4 AKFYE AKFEN YEN ENERJI 4 DSTKF DESTEK FINANS FAKTORING 5 ALBRK ALBARAKA TURK 5 EFOR EFOR YATIRIM 6 ANHY TANADOLU HAYAT EMEK 6 ESEN ESENBOĞA ELEKTRIK 7 AYGAZ AYGAZ 7 EUPWR EUROPOWER ENERJI 8 BINH 1000 YATIRIMLAR HOL 8 GENIL GEN ILAC 9 ECZYT ECZACIBASI YATIRIM 9 GESAN GIRISIM ELEKTRIK SANAYI 10 EGEEN EGE ENDUSTRI 10 GRTHO GRAINTURK HOLDING 11 EGUBB EGE GUBRE 11 GSRAY GALATASARAY SPORTIF 12 ENTRA IC ENTERRA YEN ENERJI 12 IEYHO ISIKLAR ENERJI YAPI HOL 13 GLYHO GLOBAL YAT HOLDING 13 IZENR IZDEMIR ENERJI 14 GWIND GALATA WIND ENERJI 14 KLRHO KILER HOLDING 15 ISDMR ISKENDERUN DEMIR CELIK 15 KTLEV KATILIMEVIM TAS FIN 16 KARSN KARSAN OTOMOTIV 16 KUYAS KUYAS YATIRIM 17 KATMR KATMERCILER EKIPMAN 17 MAGEN MARGUN ENERJI 18 KCAER KOCAER CELIK 18 MIATK MIA TEKNOLOJI 19 KORDS KORDSA TEKNIK TEKSTIL 19 ODINE ODINE TEKNOLOJI 20 LMKDC LIMAK DOGU ANADOLU 20 PASEU PASIFIK EURASIA LOJISTIK 21 RGYAS RONESANS GAYRIMENKUL YAT 21 PATEK PASIFIK TEKNOLOJI 22 RYSAS REYSAS LOJISTIK 22 PSGYO PASIFIK GMYO 23 SNGYO SINPAS GMYO 23 QUAGR QUA GRANITE HAYAL YAPI 24 TABGD TAB GIDA 24 RALYH RAL YATIRIM HOLDING 25 TCKRC KIRAS GALVANIZ 25 REEDR REEDER TEKNOLOJI 26 TRGYO TORUNLAR GMYO 26 SARKY SARKUYSAN 27 TTRAK TURK TRAKTOR 27 SKBNK SEKERBANK BIST 500 INDEX STOCKS TO BE INCLUDED STOCKS TO BE EXCLUDED`;

console.log('=== BIST100 Parser Static Test ===\n');

const result = parseBist100Announcement(REAL_CONTENT);

console.log(`bist100SectionFound: ${result.bist100SectionFound}`);
console.log(`added    (${result.added.length}): [${result.added.join(', ')}]`);
console.log(`removed  (${result.removed.length}): [${result.removed.join(', ')}]`);
console.log(`alternates (${result.alternates.length}): [${result.alternates.join(', ')}]`);
console.log(`periodStart: "${result.periodStart}"`);
console.log(`periodEnd:   "${result.periodEnd}"`);
console.log(`revision:    "${result.revision}"`);

// Mevcut 100 sembol (kBist100Symbols — Eylül 2026 revizyonu)
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

console.log(`\nMevcut sembol sayısı: ${kBist100Symbols.length}`);

const symbolSet = new Set(kBist100Symbols);
for (const s of result.removed) symbolSet.delete(s.trim().toUpperCase());
for (const s of result.added)   symbolSet.add(s.trim().toUpperCase());
const newSymbols = [...symbolSet].sort();

console.log(`\nYeni sembol sayısı: ${newSymbols.length} ${newSymbols.length === 100 ? '✓' : '✗ HATA'}`);

// Validation
console.log('\n=== Validation ===');
const badSym = newSymbols.find(s => !/^[A-Z]{2,6}$/.test(s));
console.log(`Sembol sayısı 100: ${newSymbols.length === 100 ? 'PASS ✓' : 'FAIL ✗ (' + newSymbols.length + ')'}`);
console.log(`Geçersiz format:   ${badSym ? 'FAIL ✗ (' + badSym + ')' : 'PASS ✓'}`);
const overlap = result.added.filter(s => result.removed.includes(s));
console.log(`Added/Removed kesişim: ${overlap.length === 0 ? 'PASS ✓' : 'FAIL ✗ ' + overlap.join(',')}`);
console.log(`Parse başarısı:    ${result.bist100SectionFound ? 'PASS ✓' : 'FAIL ✗'}`);
console.log(`Added parse:       ${result.added.length > 0 ? 'PASS ✓' : 'WARN (0 eklendi)'}`);
console.log(`Removed parse:     ${result.removed.length > 0 ? 'PASS ✓' : 'WARN (0 çıkarıldı)'}`);

const allPass = newSymbols.length === 100 && !badSym && overlap.length === 0 && result.bist100SectionFound;
console.log(`\n${allPass ? '✅ TÜM KONTROLLER GEÇTİ' : '❌ BAZI KONTROLLER BAŞARISIZ'}`);

if (allPass) {
  console.log('\nYeni liste (ilk 15):', newSymbols.slice(0, 15).join(', '));
  console.log('Yeni liste (son 5):', newSymbols.slice(-5).join(', '));
}
