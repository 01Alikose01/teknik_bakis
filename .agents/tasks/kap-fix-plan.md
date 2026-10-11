# Implementation Plan — KAP Bildirim Düzeltmeleri

## Context

**Files to change (only these two):**
- `lib/services/kap_news_service.dart`
- `functions/index.js`

**Do NOT touch:** halka arz / IPO files, `notification_service.dart`, `billing_service.dart`,
BIST100 files, `news_screen.dart`, `pubspec.yaml`, `firebase.json`, `google-services.json`,
any Cloud Function in `index.js` except `syncKapDisclosures` (and its shared helpers).

---

## Fix 1 & 3 — `lib/services/kap_news_service.dart`: strip relative-time prefix from dedup key

### What

`_buildDeduplicationKey()` reaches the fallback branch (branch 3) when a
`KapNewsItem` has no `disclosureIndex` and no `url`.  In that branch it builds:

```
'$company|$title|$type|$time'
```

`title` is taken from `item.cleanTitle`, which only strips `***THYAO***`-style
leading symbols.  It does **not** strip the dynamic relative-time prefix that
GitHub-sourced items carry (e.g. `"18 Saat Önce Marmaris..."`).  Because the
prefix changes with every JSON snapshot, the same article generates a different
key each time and is never recognised as a duplicate.

Additionally, `time` in the key records the full timestamp (including minutes),
so two fetches a few minutes apart also differ on the time segment.

### Changes

In `_buildDeduplicationKey()`, **fallback branch (branch 3) only**:

1. After computing `title` from `item.cleanTitle`, apply a second regex strip:

   ```dart
   static final _timePrefixRe = RegExp(
     r'^\d+\s+(Saat|Dakika|Gün|Hour|Minute|Day|Hours|Minutes|Days)'
     r'(\s+(Önce|önce|ago))?\s*',
     caseSensitive: false,
   );
   ```

   Strip with:
   ```dart
   final normalizedTitle = title.replaceFirst(_timePrefixRe, '').trim();
   ```

   Use `normalizedTitle` in the key (not `title`).  The displayed title is
   untouched — only `cleanTitle` inside this method is post-processed.

2. Remove `time` from the key (or keep only the date portion — date-only is
   acceptable, removing it entirely is simpler and also acceptable because
   `company + normalizedTitle + type` is already unique for KAP disclosures).
   Simplest correct form:

   ```dart
   return '$company|$normalizedTitle|$type';
   ```

   If the implementer prefers the date-only variant for extra safety:

   ```dart
   final date = _normalizeDate(item.time); // see below
   return '$company|$normalizedTitle|$type|$date';
   ```

   Add a helper if using the date-only variant:

   ```dart
   static String _normalizeDate(String value) {
     final parsed = _tryParseDate(value);
     if (parsed != null) {
       return '${parsed.year.toString().padLeft(4, '0')}-'
              '${parsed.month.toString().padLeft(2, '0')}-'
              '${parsed.day.toString().padLeft(2, '0')}';
     }
     // Return first 10 chars of raw value as best-effort date
     return value.length >= 10 ? value.substring(0, 10) : value;
   }
   ```

   **Preferred form: no `time` at all** — `'$company|$normalizedTitle|$type'`.

### Where exactly to edit

File: `lib/services/kap_news_service.dart`

Current code block to replace (inside `_buildDeduplicationKey`):

```dart
// 3. Fallback: şirket + temizlenmiş başlık + bildirim türü + zaman
final company = item.source.trim().toUpperCase();
final title = item.cleanTitle
    .toUpperCase()
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
final type = (item.disclosureType ?? '').toUpperCase();
final time = _normalizeTime(item.time);
return '$company|$title|$type|$time';
```

Replace with:

```dart
// 3. Fallback: şirket + normalleştirilmiş başlık + bildirim türü
//    Başlıktan dinamik zaman ön ekini sil: "18 Saat Önce ...", "13 Dakika Önce ..."
//    Bu ön ek her snapshot'ta değiştiğinden aynı haber farklı anahtar üretirdi.
final company = item.source.trim().toUpperCase();
final rawTitle = item.cleanTitle
    .toUpperCase()
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
final normalizedTitle = rawTitle
    .replaceFirst(
      RegExp(
        r'^\d+\s+(SAAT|DAKİKA|GÜN|HOUR|MINUTE|DAY|HOURS|MINUTES|DAYS)'
        r'(\s+(ÖNCE|AGO))?\s*',
        caseSensitive: false,
      ),
      '',
    )
    .trim();
final type = (item.disclosureType ?? '').toUpperCase();
return '$company|$normalizedTitle|$type';
```

> **Note:** `_normalizeTime` / `_normalizeDate` remain in the file for other
> potential callers — do not remove them.  If nothing else calls `_normalizeTime`
> after this change, the Dart analyser will warn about unused private method;
> suppress with `// ignore: unused_element` or leave as-is (it is harmless).

### File

`lib/services/kap_news_service.dart`

### Verify

```
flutter analyze lib/services/kap_news_service.dart
```

Expected: no errors.  (Warnings about unused `_normalizeTime` are acceptable.)

```
flutter test
```

Expected: all tests pass (or no tests exist for this file, which is also fine —
confirm with `No tests found` message rather than a failure).

---

## Fix 2 — `functions/index.js`: sanitize `KAP_TOKEN` before setting `Authorization` header

### What

`kapGet()` sets the `Authorization` header directly from `token` (line 81):

```js
'Authorization': token,
```

The token is already `.trim()`-ed at each call site, but `.trim()` only removes
leading/trailing whitespace.  It does **not** remove embedded `\n` / `\r` /
other non-printable characters that Secret Manager sometimes appends, nor does
it handle a stored token that already includes the `Bearer ` prefix.  Any of
these causes Node.js's `http` module to throw
`Invalid character in header content ["Authorization"]`.

### Changes

**Only inside `kapGet()`** — do not touch any other function.

1. Add a `sanitizeToken()` helper at the top of the file, near the other
   helpers (after the `withRetry` function, before `syncMembers`):

   ```js
   /**
    * KAP_TOKEN'ı Authorization header'ı için hazırlar:
    *  1. Yazdırılamayan karakterleri siler (Secret Manager bazen \n ekler)
    *  2. Baştaki/sondaki boşlukları kırpar
    *  3. Zaten "Bearer " ile başlıyorsa prefix'i tekrar eklemez
    */
   function sanitizeToken(raw) {
     const cleaned = raw.replace(/[^\x20-\x7E]/g, '').trim();
     return cleaned.startsWith('Bearer ') ? cleaned : `Bearer ${cleaned}`;
   }
   ```

2. In `kapGet()`, replace:

   ```js
   'Authorization': token,
   ```

   with:

   ```js
   'Authorization': sanitizeToken(token),
   ```

   That is the **only line changed** inside `kapGet()`.

### Where exactly to edit

File: `functions/index.js`

The `kapGet` function starts at approximately line 61.  The `headers` block is:

```js
headers: {
  'Authorization': token,
  'X-Api-Key':     apiKey,
  'Accept':        'application/json',
  'Content-Type':  'application/json',
},
```

Change only `'Authorization': token` → `'Authorization': sanitizeToken(token)`.

### File

`functions/index.js`

### Verify

```
cd functions && node -e "
const { sanitizeToken } = (() => {
  // inline minimal test — does not need Firebase
  function sanitizeToken(raw) {
    const cleaned = raw.replace(/[^\x20-\x7E]/g, '').trim();
    return cleaned.startsWith('Bearer ') ? cleaned : \`Bearer \${cleaned}\`;
  }
  return { sanitizeToken };
})();

console.assert(sanitizeToken('abc123') === 'Bearer abc123', 'plain token');
console.assert(sanitizeToken('abc123\n') === 'Bearer abc123', 'trailing newline');
console.assert(sanitizeToken('Bearer abc123') === 'Bearer abc123', 'already prefixed');
console.assert(sanitizeToken(' Bearer abc123 ') === 'Bearer abc123', 'spaces + prefix');
console.assert(sanitizeToken('abc\x00123') === 'Bearer abc123', 'non-printable');
console.log('sanitizeToken: tüm testler geçti');
"
```

Expected output: `sanitizeToken: tüm testler geçti`

---

## Checklist

- [ ] 1. **`kap_news_service.dart` — Fix 1 & 3**: Replace fallback branch in
         `_buildDeduplicationKey()` to strip the relative-time prefix from
         `cleanTitle` before using it in the key, and remove `time` from the key.
         Files: `lib/services/kap_news_service.dart`
         Verify: `flutter analyze lib/services/kap_news_service.dart` — no errors;
                 `flutter test` — passes or no tests.

- [ ] 2. **`functions/index.js` — Fix 2**: Add `sanitizeToken()` helper and use
         it in `kapGet()` for the `Authorization` header.
         Files: `functions/index.js`
         Verify: inline Node.js assertion script above passes with all-OK output.

---

## Constraints reminder (do NOT touch)

- `lib/services/notification_service.dart`
- `lib/services/billing_service.dart`
- Any file containing `ipo`, `halka_arz`, or `ipo_items` in its name or path
- `lib/screens/news_screen.dart`
- `pubspec.yaml`, `firebase.json`, `google-services.json`
- Any Cloud Function in `index.js` other than `syncKapDisclosures` and its
  shared helper `kapGet` (the `sanitizeToken` addition is a new helper, safe)
- BIST100 files (`bist100_*`, etc.)
