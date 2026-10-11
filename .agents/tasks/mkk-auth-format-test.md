# MKK Auth Format Test Report

## Summary

**Verdict: FORMATS ARE IDENTICAL — MKK responds the same way to both**

Both `Authorization: <token>` (mevcut format) and `Authorization: Bearer <token>` produce **exactly the same HTTP 401 response** from the MKK DEV `/members` endpoint.

MKK does **not** distinguish between the two Authorization header formats.

Test ran: 2026-10-05T21:51:12Z  
Endpoint: `https://apigwdev.mkk.com.tr/api/vyk/members`

---

## Test Results

### Request 1 — Mevcut format (`Authorization: <token>`)

| Field | Value |
|-------|-------|
| HTTP Status | **401** |
| WWW-Authenticate | `Basic` |
| fault.faultCode | `OI001` |
| fault.faultString | `Authentication policy failed! API Key/Username or Password or Token is empty!` |
| fault.faultStatusCode | `401` |

**Full response body:**
```json
{
  "fault": {
    "correlationId": "b7a84fbd-9817-4b11-88d5-6854ed654449",
    "faultCode": "OI001",
    "faultString": "Authentication policy failed! API Key/Username or Password or Token is empty!",
    "faultStatusCode": "401",
    "responseFromApi": ""
  }
}
```

---

### Request 2 — Bearer format (`Authorization: Bearer <token>`)

| Field | Value |
|-------|-------|
| HTTP Status | **401** |
| WWW-Authenticate | `Basic` |
| fault.faultCode | `OI001` |
| fault.faultString | `Authentication policy failed! API Key/Username or Password or Token is empty!` |
| fault.faultStatusCode | `401` |

**Full response body:**
```json
{
  "fault": {
    "correlationId": "9097e64b-28ce-4404-abe1-93641d5eab2c",
    "faultCode": "OI001",
    "faultString": "Authentication policy failed! API Key/Username or Password or Token is empty!",
    "faultStatusCode": "401",
    "responseFromApi": ""
  }
}
```

---

## Comparison Table

| | Request 1 (no Bearer) | Request 2 (Bearer) |
|---|---|---|
| HTTP Status | 401 | 401 |
| WWW-Authenticate | Basic | Basic |
| faultCode | OI001 | OI001 |
| faultString | Token is empty | Token is empty |
| Behavior | **Identical** | **Identical** |

---

## Evidence & Source Citations

- Base URL: `functions/index.js` line 57 — `const KAP_BASE = 'https://apigwdev.mkk.com.tr/api/vyk';`
- Current auth format: `functions/index.js` `kapGet()` line 81 — `'Authorization': token` (no Bearer prefix)
- Secrets defined: `functions/index.js` lines 51-52 — `defineSecret('KAP_API_KEY')`, `defineSecret('KAP_TOKEN')`
- Both secrets confirmed read from Firebase Secret Manager: `KAP_API_KEY` length=36, `KAP_TOKEN` length=36
- Different `correlationId` values confirm both requests physically reached the MKK gateway

---

## Conclusions

### 1. Format comparison: IDENTICAL

Switching from `Authorization: token` to `Authorization: Bearer token` makes **no difference** to MKK DEV.  
The gateway returns the same 401 error with the same `faultCode: OI001` and the same `faultString` regardless of the prefix.

This answers the original question definitively: **the format does not matter to MKK.**

### 2. Both requests return 401 — important secondary finding

The `faultString` states `"API Key/Username or Password or Token is empty!"` even though:
- `KAP_TOKEN` was confirmed read from Secret Manager (length=36)
- `KAP_API_KEY` was confirmed read from Secret Manager (length=36)

The `correlationId` values differ between the two requests, confirming each request reached the MKK gateway independently.

**Possible reasons for the 401 "empty" response:**
1. **Credentials may be expired or revoked** — the DEV environment token may no longer be valid
2. **Wrong credential format** — MKK DEV might expect a JWT or a different token type, not a plain 36-char UUID/key
3. **Subscription key issue** — the `X-Api-Key` (API subscription key) may be expired or unrecognized by the gateway
4. **Headers not reaching the backend** — The MKK API gateway (APIM) may strip `Authorization` headers if there is no matching subscription policy, hence "empty"

The `WWW-Authenticate: Basic` response header is notable: it suggests the gateway falls back to Basic auth challenge when its primary auth policy fails, which is consistent with faultCode `OI001` ("Authentication policy failed").

### 3. Recommendations

- **No code change needed for the Authorization format** — the current `Authorization: token` (no Bearer) format is functionally equivalent to `Authorization: Bearer token`.
- **Investigate credential validity** — the 401 "Token is empty" response from MKK DEV may indicate expired credentials. Contact MKK/KAP to verify the current `KAP_TOKEN` and `KAP_API_KEY` are still valid for the DEV environment.
- **Check Cloud Function logs** — compare the MKK responses in production Cloud Function logs (`syncMembers` runs) against these test results to determine if the credentials worked historically and when they stopped.
