/**
 * MKK Auth Format Test
 * Reads Firebase secrets via firebase CLI, then tests 2 Authorization formats
 * against MKK DEV /members endpoint.
 * Never prints secret values.
 */

import { execSync, spawnSync } from 'child_process';
import https from 'https';
import { writeFileSync } from 'fs';
import { resolve } from 'path';

const WORKSPACE = 'd:\\k\\wink\\teknik_bakis';
const ENDPOINT  = 'https://apigwdev.mkk.com.tr/api/vyk/members';
const REPORT    = resolve(WORKSPACE, '.agents', 'tasks', 'mkk-auth-format-test.md');
const RESULTS   = resolve(WORKSPACE, '.agents', 'tasks', 'mkk_test_results.json');

// ── Read a Firebase secret via firebase CLI ────────────────────────────────────
function readSecret(name) {
  // Use shell:true so .cmd files are resolved correctly on Windows
  const result = spawnSync(
    'firebase',
    ['functions:secrets:access', name],
    { cwd: WORKSPACE, encoding: 'utf8', timeout: 30000, shell: true }
  );
  if (result.error) throw new Error(`Failed to spawn firebase: ${result.error.message}`);
  if (result.status !== 0) {
    throw new Error(`firebase exited ${result.status} for ${name}: ${result.stderr}`);
  }
  const val = (result.stdout || '').trim();
  if (!val) throw new Error(`Secret ${name} is empty`);
  return val;
}

// ── HTTP GET helper ────────────────────────────────────────────────────────────
function httpGet(url, headers) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const options = {
      hostname: parsed.hostname,
      path:     parsed.pathname + parsed.search,
      method:   'GET',
      headers,
      timeout:  30000,
    };
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body }));
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('Request timed out')); });
    req.end();
  });
}

// ── Extract fault info from body ───────────────────────────────────────────────
function extractFaults(body) {
  let faultCode = null, faultString = null;
  try {
    const parsed = JSON.parse(body);
    faultCode   = parsed.faultCode   ?? parsed.fault?.code   ?? null;
    faultString = parsed.faultString ?? parsed.fault?.string ?? parsed.message ?? null;
  } catch {
    // Try regex
    const codeM = body.match(/"faultCode"\s*:\s*"?([^",}\s]+)"?/);
    const strM  = body.match(/"faultString"\s*:\s*"([^"]*)"/);
    if (codeM) faultCode   = codeM[1];
    if (strM)  faultString = strM[1];
  }
  return { faultCode, faultString };
}

// ── Main ───────────────────────────────────────────────────────────────────────
async function main() {
  const log = [];
  const say = (...args) => { const m = args.join(' '); log.push(m); console.log(m); };

  say('=== MKK Auth Format Test ===');
  say(`Timestamp: ${new Date().toISOString()}`);
  say(`Endpoint:  ${ENDPOINT}`);
  say('');

  // Read secrets
  say('Reading KAP_API_KEY from Firebase Secret Manager...');
  const apiKey = readSecret('KAP_API_KEY');
  say(`KAP_API_KEY: OK (length=${apiKey.length})`);

  say('Reading KAP_TOKEN from Firebase Secret Manager...');
  const token = readSecret('KAP_TOKEN');
  say(`KAP_TOKEN: OK (length=${token.length})`);

  say('');

  const baseHeaders = {
    'X-Api-Key':     apiKey,
    'Accept':        'application/json',
    'Content-Type':  'application/json',
  };

  const tests = [
    { label: 'REQUEST 1 - Mevcut format (Authorization: TOKEN)',        auth: token           },
    { label: 'REQUEST 2 - Bearer format (Authorization: Bearer TOKEN)', auth: `Bearer ${token}` },
  ];

  const results = [];

  for (const t of tests) {
    say(`=== ${t.label} ===`);
    const headers = { ...baseHeaders, Authorization: t.auth };

    let result;
    try {
      result = await httpGet(ENDPOINT, headers);
    } catch (err) {
      say(`ERROR: ${err.message}`);
      results.push({ label: t.label, error: err.message });
      continue;
    }

    const { faultCode, faultString } = extractFaults(result.body);
    const wwwAuth = result.headers['www-authenticate'] ?? null;

    say(`HTTP Status:      ${result.status}`);
    say(`WWW-Authenticate: ${wwwAuth ?? '(not present)'}`);
    say(`faultCode:        ${faultCode ?? '(not present)'}`);
    say(`faultString:      ${faultString ?? '(not present)'}`);
    say(`Body snippet:     ${result.body.substring(0, 400)}`);
    say('');

    results.push({
      label:           t.label,
      httpStatus:      result.status,
      wwwAuthenticate: wwwAuth,
      faultCode,
      faultString,
      bodySnippet:     result.body.substring(0, 400),
    });
  }

  // ── Comparison ──────────────────────────────────────────────────────────────
  say('=== COMPARISON SUMMARY ===');
  if (results.length === 2 && !results[0].error && !results[1].error) {
    const r1 = results[0], r2 = results[1];
    say(`Request 1 (no Bearer):  HTTP ${r1.httpStatus} | faultCode=${r1.faultCode ?? 'none'}`);
    say(`Request 2 (Bearer):     HTTP ${r2.httpStatus} | faultCode=${r2.faultCode ?? 'none'}`);
    const same = r1.httpStatus === r2.httpStatus && r1.faultCode === r2.faultCode && r1.faultString === r2.faultString;
    say('');
    if (same) {
      say('VERDICT: IDENTICAL - MKK returns the same response for both Authorization formats.');
    } else {
      say('VERDICT: DIFFERENT - MKK behavior changes between the two formats.');
      say(`  Status:      ${r1.httpStatus} vs ${r2.httpStatus}`);
      say(`  faultCode:   ${r1.faultCode} vs ${r2.faultCode}`);
      say(`  faultString: ${r1.faultString} vs ${r2.faultString}`);
      say(`  WWW-Auth:    ${r1.wwwAuthenticate} vs ${r2.wwwAuthenticate}`);
    }

    // Write JSON results
    const jsonOut = {
      testedAt: new Date().toISOString(),
      endpoint: ENDPOINT,
      request1: { format: 'Authorization: TOKEN (no prefix)', ...r1 },
      request2: { format: 'Authorization: Bearer TOKEN', ...r2 },
      behaviorIdentical: same,
    };
    writeFileSync(RESULTS, JSON.stringify(jsonOut, null, 2), 'utf8');
    say(`\nResults JSON: ${RESULTS}`);

    // ── Write markdown report ──────────────────────────────────────────────────
    const verdict = same ? 'IDENTICAL' : 'DIFFERENT';
    const md = `# MKK Auth Format Test Report

## Summary

**Verdict: ${verdict}**

${same
  ? 'Both `Authorization: <token>` and `Authorization: Bearer <token>` produce the exact same HTTP response from the MKK DEV `/members` endpoint. MKK does not distinguish between the two formats.'
  : 'The two Authorization formats produce **different** responses from the MKK DEV `/members` endpoint. See details below.'
}

Test ran: ${new Date().toISOString()}
Endpoint: \`${ENDPOINT}\`

---

## Request 1 — Mevcut format (\`Authorization: <token>\`)

| Field | Value |
|-------|-------|
| HTTP Status | ${r1.httpStatus} |
| WWW-Authenticate | ${r1.wwwAuthenticate ?? '*(not present)*'} |
| faultCode | ${r1.faultCode ?? '*(not present)*'} |
| faultString | ${r1.faultString ?? '*(not present)*'} |

**Body snippet:**
\`\`\`
${r1.bodySnippet}
\`\`\`

---

## Request 2 — Bearer format (\`Authorization: Bearer <token>\`)

| Field | Value |
|-------|-------|
| HTTP Status | ${r2.httpStatus} |
| WWW-Authenticate | ${r2.wwwAuthenticate ?? '*(not present)*'} |
| faultCode | ${r2.faultCode ?? '*(not present)*'} |
| faultString | ${r2.faultString ?? '*(not present)*'} |

**Body snippet:**
\`\`\`
${r2.bodySnippet}
\`\`\`

---

## Evidence & Source Citations

- Base URL found in \`functions/index.js\` line 57: \`const KAP_BASE = 'https://apigwdev.mkk.com.tr/api/vyk';\`
- Current auth format in \`functions/index.js\` \`kapGet()\` function (line 81): \`'Authorization': token\` (no Bearer prefix)
- Secrets defined via \`defineSecret('KAP_API_KEY')\` and \`defineSecret('KAP_TOKEN')\` in \`functions/index.js\` lines 51-52

---

## Conclusions & Recommendations

${same
  ? `### Both formats are equivalent — MKK accepts either

MKK DEV does not validate whether the Authorization header includes the \`Bearer\` prefix or not.
Both requests return HTTP ${r1.httpStatus} with the same fault information.

**Current code behavior is correct.** The \`kapGet()\` function in \`functions/index.js\` sends
\`Authorization: token\` (no Bearer prefix), which works identically to \`Authorization: Bearer token\`.

No code change is required for authorization format.`
  : `### Formats produce different results

The two formats differ:
- \`Authorization: TOKEN\`        → HTTP ${r1.httpStatus}, faultCode=${r1.faultCode ?? 'none'}
- \`Authorization: Bearer TOKEN\` → HTTP ${r2.httpStatus}, faultCode=${r2.faultCode ?? 'none'}

**Recommendation:** ${r2.httpStatus < r1.httpStatus || (r2.faultCode === null && r1.faultCode !== null)
  ? 'Switch to `Authorization: Bearer <token>` format in `kapGet()` in `functions/index.js` (line 81).'
  : 'The current format (no Bearer prefix) produces a better or equal result. No change needed.'
}`
}
`;
    writeFileSync(REPORT, md, 'utf8');
    say(`\nReport written to: ${REPORT}`);
  }
}

main().catch(err => {
  console.error('FATAL:', err.message);
  process.exit(1);
});
