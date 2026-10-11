# KAP dedup key and token sanitization fixes

Three targeted fixes were committed to stop duplicate KAP notifications: stripping the dynamic relative-time prefix from the dedup key title, dropping the timestamp from the dedup key entirely, and sanitizing `KAP_TOKEN` before it reaches the `Authorization` header. All three fixes are correctly implemented and behave as specified. However, the commit bundled substantial IPO/halka arz Cloud Function rewrites into the same diff, in direct violation of the scoping constraint.

Watch for: **confirmed** — the commit modified and added IPO Cloud Functions (`computeIpoStatus`, `loadBistSymbols`, `reconcileStaleIpoStatuses`, `writeIpoToFirestore`, `archiveIpoItemsNotInFeed`, `syncBistStocksFull`, `syncIpoFeed`, `syncIpoManual`) that were explicitly off-limits. This is the only blocking issue; the three KAP fixes themselves are correct.

**Verdict**: NEEDS_CHANGES

---

## High-level view

All three KAP-specific fixes are correctly implemented. The Dart regex in `_buildDeduplicationKey()` strips Turkish and English time prefixes case-insensitively before forming the fallback key, and the displayed title is untouched because the stripping is applied only to the local `rawTitle` variable inside that method. The `time` segment is removed from the key entirely, which is the simpler and correct approach. The `sanitizeToken()` helper in `index.js` strips non-printable characters, trims whitespace, and adds `Bearer ` only when absent — matching the spec exactly — and it is applied consistently at the one call site inside `kapGet()` where the `Authorization` header is set.

The IPO section of `index.js` is a different matter. The commit introduced `archiveIpoItemsNotInFeed` (a new export-adjacent function) and `syncBistStocksFull` (a new exported Cloud Function), and rewrote `computeIpoStatus`, `loadBistSymbols`, `reconcileStaleIpoStatuses`, and `writeIpoToFirestore`. These were not in HEAD~1 in their current form. The scoping constraint was explicit: "Any Cloud Function in `index.js` other than `syncKapDisclosures` and its shared helpers" must not be touched.

No flutter analyze evidence was recorded by the coder (the impl note file does not exist at `.agents/tasks/kap-fix-impl-note.md`). The Dart change is syntactically straightforward — a `replaceFirst` call with a compile-time regex — so the risk of a silent analysis error is low, but the absence of recorded evidence means it cannot be confirmed here.

---

<details>
<summary>Issues (2)</summary>

1. **Forbidden IPO functions modified and added** — The commit rewrote `computeIpoStatus`, `loadBistSymbols`, `reconcileStaleIpoStatuses`, `writeIpoToFirestore`, `syncIpoFeed`, and `syncIpoManual`, and added `archiveIpoItemsNotInFeed` and `syncBistStocksFull` to `functions/index.js`. None of these were permitted by the fix plan. These changes must be reverted or separated into a distinct commit that goes through its own review; they must not ship bundled with the KAP fix.

2. **No flutter analyze evidence** — The impl note file (`.agents/tasks/kap-fix-impl-note.md`) does not exist. The Dart change is low-risk but the absence of recorded analyze output means no confirmation that `_normalizeTime` being unused did not produce a new error. Run `flutter analyze lib/services/kap_news_service.dart` and confirm clean output (unused-element warnings are acceptable; errors are not).

</details>

---

<details>
<summary>Details</summary>

## Regex — one non-obvious correctness dependency

`DAKİKA` contains the Turkish dotted `İ` (U+0130). Dart's `String.toUpperCase()` converts `dakika` → `DAKİKA` correctly on all platforms, so the strategy of uppercasing `rawTitle` first and then matching against the uppercase word list in the pattern is sound. The `caseSensitive: false` flag on the `RegExp` is redundant given the pre-upcase but harmless.

The displayed title is sourced from `item.cleanTitle` (or `item.title` in the UI at `news_screen.dart:369`), neither of which is touched by `_buildDeduplicationKey()`. The stripping is local to `rawTitle`/`normalizedTitle` inside that private method. Confirmed: displayed title is unchanged.

## Token sanitization — call-site coverage

`sanitizeToken()` is called exactly once, at the `Authorization` header assignment inside `kapGet()`. The call sites in `syncKapOpeningPre`, `syncKapOpeningWindow`, `syncKapDisclosures`, and `syncKapManual` were also updated to `.trim()` the raw secret before passing to `runKapSync`. This is redundant (since `sanitizeToken` already handles non-printables) but not harmful, and it closes the gap for `KAP_API_KEY` which does not go through `sanitizeToken` at all.

## Forbidden IPO functions in the commit

HEAD~1 (`a79b0be`, the settings-screen version bump) did not touch `index.js`. HEAD (`d1bd92e`, the KAP fix) grew `index.js` from 2,224 to 2,450 lines — a net addition of 226 lines. The diff accounts for:

- ~11 lines: `sanitizeToken` helper — permitted
- ~8 lines: `sanitizeToken(token)` call + `.trim()` additions at call sites — permitted
- ~207 lines: IPO/halka arz rewrites and additions — **not permitted**

New function added: `archiveIpoItemsNotInFeed` (~40 lines, new logic that prunes Firestore `ipo_items` records not present in the latest feed).

New Cloud Function export added: `syncBistStocksFull` (~177 lines, syncs `kap_members` → `bist_stocks` collection).

Modified functions: `computeIpoStatus` (added 14-day archive window), `loadBistSymbols` (changed from `listDocuments` to full `get()` with `active` field filtering), `reconcileStaleIpoStatuses` (full rewrite using `computeIpoStatus`), `writeIpoToFirestore` (removed trading-protection logic, added `feedSeenAt` field).

These changes may be correct in isolation — the `computeIpoStatus` archive-window logic and the `loadBistSymbols` active-filter fix look reasonable — but they are out of scope for a KAP notification fix and introduce behavioral changes to `syncIpoFeed` and `syncIpoManual` that have not been reviewed against the halka arz feature requirements.

## Flutter analyze evidence

The impl note at `.agents/tasks/kap-fix-impl-note.md` does not exist. The Dart change is a single `replaceFirst` call added inside an existing private method, with no new imports. The only potential analyzer issue is that `_normalizeTime` is now unreferenced after `time` was removed from the dedup key return statement — the plan explicitly anticipated this and said "suppress with `// ignore: unused_element` or leave as-is (it is harmless)." Whether it produces a warning or info-level hint depends on the project's `analysis_options.yaml`, but it would not be an error. No other new analysis surface was introduced by the Dart change.

</details>

---

<details>
<summary>File map</summary>

| File | Change |
|---|---|
| `lib/services/kap_news_service.dart` | `_buildDeduplicationKey()` fallback branch: strip relative-time prefix from title, drop `time` from key |
| `functions/index.js` | Add `sanitizeToken()` helper; apply to `Authorization` header in `kapGet()`; add `.trim()` at all `KAP_TOKEN.value()` call sites; rewrite IPO functions (out of scope) |

Full diff: `git diff a79b0be d1bd92e`

</details>
