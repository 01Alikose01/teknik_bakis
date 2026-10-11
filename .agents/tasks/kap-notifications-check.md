# KAP Bildirimleri Durum Raporu

## Özet Cevap

**KAP bildirimleri kısmen çalışıyor.** Sistemdeki "1 adet bildirim" ifadesi, `NewsScreen`'deki "Son X bildirimi gösteriliyor (72 saat)" sayacına işaret ediyor. GitHub veri kaynağı aktif ve 150 kayıt döndürüyor, ancak deduplikasyon sonrasında çok sayıda yinelenen kayıt eleniyor ve görünen sayı düşük kalıyor. Firestore kanalı (Cloud Function `syncKapDisclosures`) ise **Authorization header hatası** nedeniyle tamamen devre dışı — tüm sync denemeleri `failed` durumunda.

---

## Veri Akışı

```
Flutter Uygulaması
    │
    ├─► KapDisclosureService.fetchLatest()   ← Firestore kap_disclosures (PRIMARY)
    │       │ Firestore boş / erişilemez → fallback ↓
    └─► KapNewsService.fetch()               ← GitHub JSON (FALLBACK)
              │
              ├─► https://raw.githubusercontent.com/Alikose010/teknik-bakis-kap/main/data/kap_news.json
              │       ✅ Aktif, 150 kayıt, lastUpdated: 2026-10-10T14:57:25 UTC
              │
              └─► kap.org.tr API (ek fallback, direkt istek)
```

---

## Bulgu 1: "1 Bildirim" Nereden Geliyor

`lib/screens/news_screen.dart` satır 244:
```dart
'Son ${_kapNews.length} bildirimi gösteriliyor (72 saat)'
```

Bu sayaç, `_kapNews` listesinin uzunluğunu doğrudan gösterir. Kullanıcı "1 adet bildirim var" diyorsa, deduplikasyon sonrası listede yalnızca 1 eleman kaldı demektir.

**Neden bu kadar az?**

GitHub kaynağından gelen 150 kayda bakıldığında ciddi bir sorun göze çarpıyor: kayıtların başlığı "X Saat Önce ..." şeklinde başlıyor ve _aynı KAP bildirimini farklı zamanlarda çekmiş gibi tekrarlıyor_:

```json
{ "title": "18 Saat Önce Marmaris Altınyunus...", "source": "TBC", "time": "10.10.2026 14:57" }
{ "title": "13 Saat Önce Marmaris Altınyunus...", "source": "TBC", "time": "10.10.2026 08:58" }
{ "title": "6 Saat Önce Marmaris Altınyunus...",  "source": "TBC", "time": "10.10.2026 02:40" }
{ "title": "3 Saat Önce Marmaris Altınyunus...",  "source": "TBC", "time": "09.10.2026 23:34" }
```

Bu kayıtlarda `disclosureIndex` alanı yok. Dedup key şu formüle geri düşüyor:

```
company|title|type|time   →  TBC|18 SAAT ÖNCE MARMARIS...|...|10.10.2026 14:57
```

Her kayıt farklı `title` + farklı `time` kombinasyonu taşıdığından deduplikasyon bunları **farklı bildirim** olarak işliyor. Sorun deduplikasyon kodu değil; **kaynak verinin kalitesi**. Her kayıt aslında aynı haberin farklı saatlerde snapshot'ı.

Öte yandan `within72h` kontrolü de azaltıcı bir etken: `rawDate` 72 saatten eski olan kayıtlar filtreleniyor.

---

## Bulgu 2: Firestore Kanalı Çalışmıyor

`meta/kap` dokümanı:
```json
{ "lastSyncStatus": "failed", "lastSyncError": "Invalid character in header content [\"Authorization\"]" }
```

`kap_sync_logs` koleksiyonundaki **tüm kayıtlar** (en az Eylül 2026'dan bu yana) `failed` durumunda, hepsi aynı hata mesajıyla:

```
Invalid character in header content ["Authorization"]
```

Bu hata, `functions/index.js`'deki `kapGet()` fonksiyonunun `Authorization` header'ına geçersiz bir token değeri gönderdiği anlamına geliyor. Firebase Secret Manager'daki `KAP_TOKEN` değeri ya geçersiz karakter içeriyor (örneğin yeni satır `\n`, boşluk, veya ASCII dışı karakter) ya da süresi dolmuş.

**Sonuç:** Firestore'daki `kap_disclosures` koleksiyonu mevcut kolleksiyon listesinde bile görünmüyor — Firestore REST sonuçlarında `kap_disclosures` yok, yani koleksiyon hiç oluşturulmamış veya tamamen boş. Flutter uygulaması `fetchLatest()` ile Firestore'a bağlanıyor, boş sonuç alıyor ve fallback olarak GitHub JSON'a geçiyor.

---

## Bulgu 3: GitHub Kaynağının Kalite Sorunu

`KapNewsService.fetch()` → `_kapGithubUrl`:
```
https://raw.githubusercontent.com/Alikose010/teknik-bakis-kap/main/data/kap_news.json
```

Veri incelemesinde:
- `count: 150` kayıt, `lastUpdated: 2026-10-10T14:57:25`
- `disclosureIndex` / `id` alanı **hiçbir kayıtta yok**
- Başlıklar "X Saat Önce ..." formatında — aynı haberi farklı saatlerde defalarca içeriyor
- URL: hepsi `https://www.getmidas.com/kap-haberleri/` (Midas agregasyon sayfası) — bireysel KAP bildirim URL'i yok

Dedup key fallback devreye giriyor: `company|title|type|time`. "X Saat Önce" ifadesini başlığa dahil ettiği için her farklı saat → farklı dedup key → 150 farklı kayıt gibi değerlendiriliyor. Gerçekte ise çok daha az benzersiz bildirim var.

72 saat filtresi uygulandığında ve dedup sonrasında göründüğü kadar az (1-3 arası) benzersiz, yeni bildirim kalıyor.

---

## Bulgu 4: Kod Yapısı Doğru, UI Mantığı Çalışıyor

`lib/screens/news_screen.dart` → `_loadKap()`:
```dart
var items = await KapDisclosureService.fetchLatest();  // Firestore
if (items.isEmpty) {
  items = await KapNewsService.fetch();                 // GitHub fallback
}
final deduped = KapNewsService.dedupe(items);           // Deduplikasyon
setState(() { _kapNews = deduped; });
```

Bu akış doğru. Dedup kodu (`kap-dedup-fix` commit: `17dec4d`) uygulanmış ve çalışıyor. Sorun kodda değil, **veri kaynağının kalitesinde**.

`lib/services/kap_disclosure_service.dart` → `_docToNewsItem()`:
```dart
final disclosureId = d['disclosure_id']?.toString();
final effectiveDisclosureIndex =
    (disclosureId != null && disclosureId.isNotEmpty) ? disclosureId : null;
```
Bu da doğru — `disclosure_id` öncelikli, dedup fix uygulanmış.

---

## Bulgu 5: Bildirim Sayacı UI Bileşeni

Sayacı gösteren yer:

```
lib/screens/news_screen.dart → _buildKapList() → Padding → Row → Text
"Son ${_kapNews.length} bildirimi gösteriliyor (72 saat)"
```

"1 adet bildirim" kullanıcının gördüğü şey bu. 72 saatlik pencerede deduplikasyon sonrası geriye 1 benzersiz kayıt kalıyor.

---

## Bulgu 6: Ana Bildirim Sistemi (Push) Ayrı

`lib/services/notification_service.dart` → fiyat alarmları ve IPO uyarıları için. KAP bildirimleri ile ilişkisi yok. KAP bildirimi push notification ile kullanıcıya gönderilmiyor; yalnızca "Haberler" ekranında liste olarak gösteriliyor.

---

## Sonuçlar ve Öneriler

### Mevcut Durum
| Bileşen | Durum | Not |
|---------|-------|-----|
| Flutter UI (`news_screen.dart`) | ✅ Çalışıyor | Veriyi gösteriyor |
| KapNewsService.fetch() (GitHub) | ✅ Çalışıyor | 150 kayıt geliyor |
| KapDisclosureService.fetchLatest() | ⚠️ Boş dönüyor | Firestore koleksiyonu yok |
| Cloud Function syncKapDisclosures | ❌ Çalışmıyor | Authorization hatası |
| Dedup mantığı | ✅ Çalışıyor | FEAT-001 fix uygulandı |
| GitHub veri kalitesi | ⚠️ Sorunlu | disclosureIndex yok, başlık "X Saat Önce" |

### Önerilen Düzeltmeler (Öncelik Sırasıyla)

1. **[Yüksek] Firebase Secret Manager'daki `KAP_TOKEN` değerini güncelle.**
   Cloud Function'daki hata `Invalid character in header content ["Authorization"]` — token değeri temiz ASCII olmak zorunda, `Bearer ` prefix'i veya gizli karakter içermesin. Firebase Console → Secret Manager → `KAP_TOKEN` sırrının güncel ve geçerli bir değer içerdiğini doğrula.

2. **[Yüksek] GitHub kap_news.json verisinin `disclosureIndex`/`id` alanı içermesi gerekiyor.**
   `https://raw.githubusercontent.com/Alikose010/teknik-bakis-kap/main/data/kap_news.json` kaynağındaki her kayıt benzersiz bir `disclosureIndex` veya `id` alanı taşımalı. Bu alan olmadan dedup key title+time kombinasyonuna düşüyor ve "X Saat Önce..." başlıkları her güncellemeyi yeni bildirim gibi gösteriyor.

3. **[Orta] GitHub kaynağındaki başlıkları "X Saat Önce..." formatından temizle.**
   Başlıklardaki göreli zaman ifadesi (`18 Saat Önce`, `6 Saat Önce`) her snapshot'ta değişiyor. Dedup için başlıktan bu prefix'in soyulması gerekiyor ya da kaynak veri bunu yapmamalı.

4. **[Düşük] `KapNewsService._buildDeduplicationKey()` geliştirmesi.**
   Başlıktaki "X Saat Önce" / "X Dakika Önce" pattern'ini regex ile temizleyerek normalizasyon adımına eklenebilir. Bu, kaynak düzeltilmeden önce geçici bir iyileştirme sağlar.

---

*Rapor tarihi: inceleme anı. Hiçbir kod değişikliği yapılmadı (read-only inceleme).*
