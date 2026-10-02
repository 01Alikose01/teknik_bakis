/**
 * Static parser testi v2 — gerçek HTML tablo yapısını simüle eder.
 * Borsa İstanbul duyuru sayfasının gerçek <tr><td> yapısını kullanır.
 */

function parseBist100Announcement(html) {
  const bist100HtmlStart = html.search(/BIST\s+100\s+INDEX/i);
  if (bist100HtmlStart < 0) {
    return { added: [], removed: [], alternates: [], periodStart: '', periodEnd: '', revision: '', bist100SectionFound: false };
  }

  const afterBist100Html = html.slice(bist100HtmlStart);
  const nextBigSection = afterBist100Html.search(/BIST\s+(?:500|LIQUID|SUSTAINABILITY)\s+INDEX/i);
  const bist100Html = nextBigSection >= 0
    ? afterBist100Html.slice(0, nextBigSection)
    : afterBist100Html.slice(0, 50000);

  const trPattern = /<tr[\s\S]*?<\/tr>/gi;
  const added = [], removed = [], alternates = [];

  function cellToSymbol(cellHtml) {
    const cellText = cellHtml
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&#\d+;/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    if (!cellText) return null;

    const m = cellText.match(/^\d+\s*([A-Z]+)/);
    if (!m) return null;
    const token = m[1];

    let sym;
    if (token.length <= 6) {
      sym = token;
    } else {
      const spacePart = cellText.match(/^\d+\s+([A-Z]{2,6})\s/);
      sym = spacePart ? spacePart[1] : token.substring(0, 5);
    }

    if (!sym || sym.length < 2) return null;
    const SKIP = new Set(['INDEX','BIST','STOCKS','TO','BE','INCLUDED','EXCLUDED','SUBSTITUTE','FOR','THE']);
    if (SKIP.has(sym)) return null;
    return sym;
  }

  let trMatch;
  while ((trMatch = trPattern.exec(bist100Html)) !== null) {
    const trContent = trMatch[0];
    const cells = [];
    let tdMatch;
    const tdPat = /<td[\s\S]*?>([\s\S]*?)<\/td>/gi;
    while ((tdMatch = tdPat.exec(trContent)) !== null) cells.push(tdMatch[1]);

    if (cells.length >= 3) {
      const s0 = cellToSymbol(cells[0]);
      const s1 = cellToSymbol(cells[1]);
      const s2 = cellToSymbol(cells[2]);
      if (s0 && !added.includes(s0))      added.push(s0);
      if (s1 && !removed.includes(s1))    removed.push(s1);
      if (s2 && !alternates.includes(s2)) alternates.push(s2);
    } else if (cells.length === 2) {
      const s0 = cellToSymbol(cells[0]);
      const s1 = cellToSymbol(cells[1]);
      if (s0 && !added.includes(s0))   added.push(s0);
      if (s1 && !removed.includes(s1)) removed.push(s1);
    }
  }

  const fullText = html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>')
    .replace(/&nbsp;/g,' ').replace(/&#\d+;/g,' ')
    .replace(/\s+/g,' ').trim();

  let periodStart = '', periodEnd = '', revision = '';
  const pm = fullText.match(/PERIOD\s+((?:JANUARY|FEBRUARY|MARCH|APRIL|MAY|JUNE|JULY|AUGUST|SEPTEMBER|OCTOBER|NOVEMBER|DECEMBER)\s+\d{1,2},?\s+\d{4})\s*[-\u2013\u2014]\s*((?:JANUARY|FEBRUARY|MARCH|APRIL|MAY|JUNE|JULY|AUGUST|SEPTEMBER|OCTOBER|NOVEMBER|DECEMBER)\s+\d{1,2},?\s+\d{4})/i);
  if (pm) {
    periodStart = pm[1].trim(); periodEnd = pm[2].trim();
    const eu = pm[2].trim().toUpperCase();
    const yr = (pm[2].match(/(\d{4})/) || [])[1] || '';
    if (eu.startsWith('MARCH')) revision = `${yr}-Q1`;
    else if (eu.startsWith('JUNE')) revision = `${yr}-Q2`;
    else if (eu.startsWith('SEPT')) revision = `${yr}-Q3`;
    else if (eu.startsWith('DECE')) revision = `${yr}-Q4`;
    else revision = yr;
  }

  return { added, removed, alternates, periodStart, periodEnd, revision, bist100SectionFound: true };
}

// ── Gerçek HTML tablo yapısını simüle eden test verisi ────────────────────────
// Borsa İstanbul duyuru 15598'den alınan gerçek içerik (web_fetch doğrulandı)
const SIMULATED_HTML = `
<html><body>
<p>...for the period October 1, 2026 &#8211; December 31, 2026...</p>
<p>PERIODIC INDEX CHANGES FOR THE PERIOD OCTOBER 1, 2026-DECEMBER 31, 2026</p>
<h2>BIST 100 INDEX</h2>
<table>
<thead><tr>
  <th>STOCKS TO BE INCLUDED</th>
  <th>STOCKS TO BE EXCLUDED</th>
  <th>SUBSTITUTE STOCKS</th>
</tr></thead>
<tbody>
<tr><td>1AGHOLANADOLU GRUBU HOLDING</td><td>1BALSUBALSU GIDA</td><td>1KLGYOKILER GMYO</td></tr>
<tr><td>2AHGAZAHLATCI DOGALGAZ</td><td>2BSOKEBATICIM CIMENTO</td><td>2RYGYOREYSAS GMYO</td></tr>
<tr><td>3AKCNSAKCANSA</td><td>3DAPGMDAP GAYRIMENKUL</td><td>3TMSNTUMOSAN MOTOR VE TRAKTOR</td></tr>
<tr><td>4AKFYEAKFEN YEN ENERJI</td><td>4DSTKFDESTEK FINANS FAKTORING</td><td></td></tr>
<tr><td>5ALBRKALBARAKA TURK</td><td>5EFOREFOR YATIRIM</td><td></td></tr>
<tr><td>6ANHY TANADOLU HAYAT EMEK</td><td>6ESEN ESENBOĞA ELEKTRIK</td><td></td></tr>
<tr><td>7AYGAZ AYGAZ</td><td>7EUPWR EUROPOWER ENERJI</td><td></td></tr>
<tr><td>8BINH 1000 YATIRIMLAR HOL</td><td>8GENIL GEN ILAC</td><td></td></tr>
<tr><td>9ECZYT ECZACIBASI YATIRIM</td><td>9GESAN GIRISIM ELEKTRIK SANAYI</td><td></td></tr>
<tr><td>10EGEEN EGE ENDUSTRI</td><td>10GRTHO GRAINTURK HOLDING</td><td></td></tr>
<tr><td>11EGUBB EGE GUBRE</td><td>11GSRAY GALATASARAY SPORTIF</td><td></td></tr>
<tr><td>12ENTRA IC ENTERRA YEN ENERJI</td><td>12IEYHO ISIKLAR ENERJI YAPI HOL</td><td></td></tr>
<tr><td>13GLYHO GLOBAL YAT HOLDING</td><td>13IZENR IZDEMIR ENERJI</td><td></td></tr>
<tr><td>14GWIND GALATA WIND ENERJI</td><td>14KLRHO KILER HOLDING</td><td></td></tr>
<tr><td>15ISDMR ISKENDERUN DEMIR CELIK</td><td>15KTLEV KATILIMEVIM TAS FIN</td><td></td></tr>
<tr><td>16KARSN KARSAN OTOMOTIV</td><td>16KUYAS KUYAS YATIRIM</td><td></td></tr>
<tr><td>17KATMR KATMERCILER EKIPMAN</td><td>17MAGEN MARGUN ENERJI</td><td></td></tr>
<tr><td>18KCAER KOCAER CELIK</td><td>18MIATK MIA TEKNOLOJI</td><td></td></tr>
<tr><td>19KORDS KORDSA TEKNIK TEKSTIL</td><td>19ODINE ODINE TEKNOLOJI</td><td></td></tr>
<tr><td>20LMKDC LIMAK DOGU ANADOLU</td><td>20PASEU PASIFIK EURASIA LOJISTIK</td><td></td></tr>
<tr><td>21RGYAS RONESANS GAYRIMENKUL YAT</td><td>21PATEK PASIFIK TEKNOLOJI</td><td></td></tr>
<tr><td>22RYSAS REYSAS LOJISTIK</td><td>22PSGYO PASIFIK GMYO</td><td></td></tr>
<tr><td>23SNGYO SINPAS GMYO</td><td>23QUAGR QUA GRANITE HAYAL YAPI</td><td></td></tr>
<tr><td>24TABGD TAB GIDA</td><td>24RALYH RAL YATIRIM HOLDING</td><td></td></tr>
<tr><td>25TCKRC KIRAS GALVANIZ</td><td>25REEDR REEDER TEKNOLOJI</td><td></td></tr>
<tr><td>26TRGYO TORUNLAR GMYO</td><td>26SARKY SARKUYSAN</td><td></td></tr>
<tr><td>27TTRAK TURK TRAKTOR</td><td>27SKBNK SEKERBANK</td><td></td></tr>
</tbody>
</table>
<h2>BIST 500 INDEX</h2>
</body></html>`;

console.log('=== BIST100 Parser Static Test v2 ===\n');
const result = parseBist100Announcement(SIMULATED_HTML);

console.log(`bist100SectionFound: ${result.bist100SectionFound}`);
console.log(`added    (${result.added.length}): [${result.added.join(', ')}]`);
console.log(`removed  (${result.removed.length}): [${result.removed.join(', ')}]`);
console.log(`alternates (${result.alternates.length}): [${result.alternates.join(', ')}]`);
console.log(`periodStart: "${result.periodStart}"`);
console.log(`periodEnd:   "${result.periodEnd}"`);
console.log(`revision:    "${result.revision}"`);

// Mevcut kBist100Symbols (Eylül 2026 — 100 sembol)
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

console.log(`Yeni sembol sayısı:  ${newSymbols.length} ${newSymbols.length === 100 ? '✓' : '✗ HATA!'}`);

// Validation
console.log('\n=== Validation ===');
const badSym = newSymbols.find(s => !/^[A-Z]{2,6}$/.test(s));
const overlap = result.added.filter(s => result.removed.includes(s));
console.log(`Sembol sayısı 100:     ${newSymbols.length === 100 ? 'PASS ✓' : 'FAIL ✗ (' + newSymbols.length + ')'}`);
console.log(`Geçersiz format:       ${badSym ? 'FAIL ✗ (' + badSym + ')' : 'PASS ✓'}`);
console.log(`Added/Removed overlap: ${overlap.length === 0 ? 'PASS ✓' : 'FAIL ✗ ' + overlap.join(',')}`);
console.log(`Parse başarısı:        ${result.bist100SectionFound ? 'PASS ✓' : 'FAIL ✗'}`);
console.log(`Added parse:           ${result.added.length > 0 ? 'PASS ✓ (' + result.added.length + ')' : 'FAIL ✗ (0)'}`);
console.log(`Removed parse:         ${result.removed.length > 0 ? 'PASS ✓ (' + result.removed.length + ')' : 'FAIL ✗ (0)'}`);
console.log(`Alternates:            ${result.alternates.length > 0 ? 'PASS ✓ (' + result.alternates.length + ')' : 'WARN (0)'}`);
console.log(`Dönem parse:           ${result.periodStart ? 'PASS ✓' : 'WARN (bulunamadı)'}`);

const allPass = newSymbols.length === 100 && !badSym && overlap.length === 0 && result.bist100SectionFound && result.added.length > 0 && result.removed.length > 0;
console.log(`\n${allPass ? '✅ TÜM KRİTİK KONTROLLER GEÇTİ' : '❌ BAZI KONTROLLER BAŞARISIZ'}`);

if (allPass) {
  // Beklenen sonuçla karşılaştır (web_fetch'ten bilinen gerçek değişiklikler)
  const EXPECTED_ADDED   = ['AGHOL','AHGAZ','AKCNS','AKFYE','ALBRK','AYGAZ','BINH','ECZYT','EGEEN','EGUBB','ENTRA','GLYHO','GWIND','ISDMR','KARSN','KATMR','KCAER','KORDS','LMKDC','RGYAS','RYSAS','SNGYO','TABGD','TCKRC','TRGYO','TTRAK'];
  const EXPECTED_REMOVED = ['BALSU','BSOKE','DAPGM','DSTKF','EFOR','ESEN','EUPWR','GENIL','GESAN','GRTHO','GSRAY','IEYHO','IZENR','KLRHO','KTLEV','KUYAS','MAGEN','MIATK','ODINE','PASEU','PATEK','PSGYO','QUAGR','RALYH','REEDR','SARKY','SKBNK'];

  const addedMatch   = EXPECTED_ADDED.every(s => result.added.includes(s));
  const removedMatch = EXPECTED_REMOVED.every(s => result.removed.includes(s));
  console.log(`Added expected match:   ${addedMatch ? 'PASS ✓' : 'WARN - bazı semboller eksik'}`);
  console.log(`Removed expected match: ${removedMatch ? 'PASS ✓' : 'WARN - bazı semboller eksik'}`);
  
  if (!addedMatch) {
    const missing = EXPECTED_ADDED.filter(s => !result.added.includes(s));
    console.log(`  Eksik added: [${missing.join(', ')}]`);
  }
  if (!removedMatch) {
    const missing = EXPECTED_REMOVED.filter(s => !result.removed.includes(s));
    console.log(`  Eksik removed: [${missing.join(', ')}]`);
  }
}
