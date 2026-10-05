# Haberler Bölümü Duplikasyon Analizi

## Özet (Önce Cevap)

İki ayrı sorun tespit edildi:

1. **KAP Bildirimleri** — `KapDisclosureService` (Firestore tabanlı, `disclosureIndex` doküman ID'si kullanan güvenilir servis) **hiçbir yerde çağrılmıyor**. `NewsScreen._loadKap()` yalnızca `KapNewsService.fetch()` kullanıyor. Bu servis, dedup anahtarı olarak `company|title|time` üçlüsünü kullanıyor — doküman ID'sini (disclosureIndex) **asla** kullanmıyor. Aynı bildirim farklı title/time formatıyla gelirse veya GitHub JSON ile KAP API eş zamanlı çalışırsa aynı içerik iki kez gösterilebilir.

2. **Borsa Haberleri** — Dedup mantığı var ama `_isCloseInTime` eşiği 18 saat, bu yüzden aynı günün değil geniş zaman aralığının haberlerini eşleştiriyor. Daha önemli sorun: farklı başlıkla aynı olayı anlatan haberler (Jaccard ≥ 0.92 veya ≥ 0.82 + özet benzerliği) birleştirilmekte, ancak bu eşikler gerçek Türkçe haber başlıkları için yeterince ayarlanmamış olabilir.

---

## 1. KAP Bildirimleri — Detaylı Analiz

### 1.1 Veri Kaynakları

| Servis | Kaynak | Tekil ID | Kullanıldığı yer |
|---|---|---|---|
| `KapDisclosureService` | Firestore `kap_disclosures/{disclosureIndex}` | Firestore doküman ID = `disclosureIndex` | **Hiçbir yerde çağrılmıyor** |
| `KapNewsService.fetch()` | Önce GitHub JSON, sonra KAP REST API | Yok — URL veya başlıktan türetilen zayıf anahtar | `NewsScreen._loadKap()` |

### 1.2 `KapDisclosureService` Neden Tercih Edilmeli?

`lib/services/kap_disclosure_service.dart` başlığında açıkça yazıyor:

```
/// Koleksiyonlar:
///   kap_disclosures/{disclosureIndex}  — Bildirimler
```

Firestore'da her dokümanın ID'si `disclosureIndex`'tir — KAP'ın bildirim için atadığı benzersiz tam sayı. Bu ID, kesinlikle tekil bir anahtar sağlar. `_docToNewsItem()` fonksiyonu `detail_url` alanını `url` olarak dolduruyor. Dolayısıyla Firestore yoluyla gelen veriler hem `disclosureIndex` (doküman ID) hem de `detail_url` ile benzersiz kimliklenebilir.

**Ancak `KapDisclosureService.fetchLatest()` `NewsScreen`'de çağrılmıyor.** `news_screen.dart` dosyasında `kap_disclosure_service.dart` importu bile yok.

### 1.3 `KapNewsService.fetch()` Dedup Sorunu

**Dosya:** `lib/services/kap_news_service.dart`

`_buildDeduplicationKey(item)` şu anahtarı üretiyor:
```
COMPANY|TITLE|TIME
```

Bu anahtarın sorunları:

- **`COMPANY`** = `item.source` → GitHub JSON'da `companyCode` (ör. `"THYAO"`), KAP REST API'de de `companyCode` alanı kullanılıyor. Bunlar tutarlı.
- **`TITLE`** = `cleanTitle` sonrası büyük harf + normalize → `cleanTitle` getter'ı yalnızca `***THYAO***` gibi sembol öneklerini siliyor. Başlık metni farklıysa eşleşmiyor.
- **`TIME`** = `_normalizeTime()` ile normalize edilmiş zaman → `dd.MM.yyyy HH:mm` formatına getiriliyor.

**Somut başarısızlık senaryosu:**  
GitHub JSON'daki bir kayıt `"title": "***THYAO*** Özel Durum Açıklaması"` iken, KAP REST API aynı bildirimi `"subject": "Özel Durum Açıklaması"` + `"companyCode": "THYAO"` şeklinde döndürüyor. `cleanTitle` sonrası her ikisi de `"ÖZEL DURUM AÇIKLAMASI"` olacak, ama GitHub başarıyla döndüğünde REST API çağrılmıyor (`if (rawList != null && rawList.isNotEmpty) return ...`). Bu senaryoda tekrar yok — ama GitHub JSON ile Firestore sonuçları birleştirilirse anahtar `disclosure_type` içermediği için farklı disclosure türleri birleşebilir.

**`disclosure_type` sorunu:**  
`KapNewsItem` modelinde `disclosure_type` alanı **yok**. `_buildDeduplicationKey` içinde de kullanılmıyor. Kullanıcının isteğinde "disclosure_type farklıysa aynı haber kabul etme" deniyor — bu şu an uygulanmıyor.

### 1.4 KAP'ın `d['id']` Alanı vs. `disclosureIndex`

`KapNewsService.fetch()` içinde KAP REST API yanıtından şu şekilde URL oluşturuluyor:
```dart
url: d['id'] != null ? 'https://www.kap.org.tr/tr/Bildirim/${d['id']}' : '',
```

`d['id']` muhtemelen `disclosureIndex`'e karşılık gelen sayısal ID. Ancak bu ID `KapNewsItem` modeline **kaydedilmiyor** — yalnızca URL'e gömülüyor. Daha sonra dedup için geri çıkarılamıyor.

### 1.5 Firestore `_docToNewsItem()` Sorunu

`KapDisclosureService._docToNewsItem()` şu eşlemeyi yapıyor:

```dart
title: d['company_title']?.toString() ?? d['subject']?.toString() ?? 'KAP Bildirimi',
```

- `company_title` — şirket adı (ör. "Türk Hava Yolları")
- `subject` — bildirimin konusu

Bu iki değer birbirinden çok farklı. Eğer `company_title` boşsa `subject` devreye giriyor, title'ın içeriği kayıt bazında tutarsız olabilir.

---

## 2. Borsa Haberleri — Detaylı Analiz

### 2.1 Veri Kaynakları

**Dosya:** `lib/services/borsa_news_service.dart`

8 RSS kaynağı paralel olarak çekiliyor (`Future.wait`):
- Google News (borsa, iş, bilim/teknoloji aramaları)
- Investing.com RSS
- Bloomberg HT
- BigPara (Hürriyet)
- Habertürk Ekonomi
- BBC Türkçe Ekonomi

Çekilen veriler tarihine göre sıralanıp `_dedupe()` uygulanıyor, sonra 10 günden eski kayıtlar siliniyor.

### 2.2 Mevcut Dedup Mantığı

`_isDuplicate(a, b)` şu koşullarda `true` döndürüyor:

```
1. titleA == titleB AND (closeInTime OR summaryLooksSame)
2. closeInTime AND tokenSimilarity(title) >= 0.92
3. closeInTime AND tokenSimilarity(title) >= 0.82 AND summaryLooksSame
```

**`closeInTime`:** 18 saatlik pencere (`a.difference(b).inHours.abs() <= 18`)

**`tokenSimilarity`:** Jaccard benzerliği — stop word filtreli token setlerinde kesişim/birleşim

**`summaryLooksSame`:** özet benzerliği >= 0.78 veya biri diğerini 32+ karakter içeriyor

**`_canonicalTitle()`:** Küçük harf, Türkçe karakter normalize (`â→a`, `î→i`, `û→u`), tire sonrası kaynak etiketi kaldırma (ör. `" - Bloomberg HT"` kısmı), `son dakika / güncel` gibi jenerik kelimeler siliniyor.

### 2.3 Eksiklikler

**Türkçe ek problemi:**  
`_canonicalText()` Türkçe eklerini değiştirmiyor. "Türkiye" stop words listesinde var, ama "Fransa", "Fransa'nın", "Fransızların" gibi varyantlar ayrı tokenlar sayılıyor. Kullanıcının örneğindeki "Türkiye ile Fransa" / "Türkiye-Fransa" / "Türkiye ve Fransa" vakası için:

- "Türkiye" stop words listesinde → eleniyor ✓
- "Fransa" → ikisi de token olarak kalıyor
- "savunma" → kalıyor
- "anlaşması" / "iş birliği" / "yol haritası" → farklı tokenlar, Jaccard skoru düşüyor

Dolayısıyla bu üç başlık aynı haber olarak tanınmayabilir. Token benzerliği muhtemelen ~0.3-0.5 arasında kalıyor; 0.82 eşiğine ulaşmıyor.

**`disclosure_type` alanı yok:**  
`BorsaNewsItem`'da da `disclosure_type` bulunmuyor. Bu alan istenirse eklenmeli.

**Stop words listesi eksik:**  
"fransa", "almanya", "rusya" gibi yaygın ülke adları, "imzalandi", "anlaşma", "mutabakat" gibi yaygın eylemler stop words'te yok. Bunlar token kesişimini artırıp hem yanlış birleştirmeye hem de yanlış kaçırmaya yol açabilir.

**`_isCloseInTime` eşiği (18 saat) geniş:**  
"Borsa İstanbul'da haftalık toparlanma" haberi her gün benzer başlıkla çıkabilir, 18 saatlik pencere farklı günleri örtüştürüyor.

**URL/GUID kontrolü yok:**  
Birden fazla kaynak aynı wire story'yi farklı URL'lerle yayınlayabilir. `_isDuplicate` URL'i hiç kontrol etmiyor. Tersi yönden: aynı URL farklı başlıkla gelirse `titleA != titleB` olduğu için duplicate sayılmıyor.

---

## 3. State Management

**Dosya:** `lib/screens/news_screen.dart`

Herhangi bir Provider/Bloc/Riverpod yapısı yok. State doğrudan `_NewsScreenState` içinde tutuluyor:

```dart
List<KapNewsItem> _kapNews = [];
List<BorsaNewsItem> _borsaNews = [];
bool _loadingKap = false;
bool _loadingBorsa = false;
Timer? _refreshTimer;
DateTime? _lastUpdated;
```

`_refreshTimer` 90 saniyede bir `_loadAll()` çağırıyor. Her yüklemede servis sonuçları doğrudan `setState` ile yazılıyor — önceki listeyle birleştirme veya delta güncellemesi yok. Yani her 90 saniyede liste tamamen yenileniyor; bu dedup'ı ikinci kez uyguluyor ama yeni item'lar öncekilerle merge edilmiyor.

---

## 4. Bulgular Özeti

| # | Sorun | Etki | Dosya |
|---|---|---|---|
| 1 | `KapDisclosureService` hiç kullanılmıyor; `NewsScreen` hâlâ `KapNewsService.fetch()` kullanıyor | `disclosureIndex` tabanlı kesin dedup yapılamıyor | `news_screen.dart`, `kap_disclosure_service.dart` |
| 2 | `KapNewsItem`'da `disclosureIndex` veya `id` alanı yok | URL'den ID çıkarılamıyor, dedup anahtarı zayıf | `kap_news_item.dart`, `kap_news_service.dart` |
| 3 | `_buildDeduplicationKey` anahtar olarak `company|title|time` kullanıyor, `disclosure_type` yok | Farklı tipte bildirimler yanlışlıkla birleştirilebilir (veya aynı bildirim farklı formatla tekrar çıkabilir) | `kap_news_service.dart` |
| 4 | `KapDisclosureService._docToNewsItem()` title için `company_title` (şirket adı) önceliği veriyor, `subject` fallback; ayrıca `disclosure_type` kaydedilmiyor | Gösterilen title tutarsız, dedup'a giren title anlamsız olabilir | `kap_disclosure_service.dart`, `kap_news_item.dart` |
| 5 | `BorsaNewsService._isDuplicate` Jaccard eşiği (0.92/0.82) Türkçe ek morfolojisi için yeterince esnek değil | Aynı olay farklı başlıklarla (Türkçe ek varyasyonu) tekrar listelenebilir | `borsa_news_service.dart` |
| 6 | `_isCloseInTime` eşiği 18 saat — düzenli haftalık haber başlıkları yanlış birleştirilebilir | Farklı haberler birleşebilir | `borsa_news_service.dart` |
| 7 | `BorsaNewsService._isDuplicate` URL/GUID kontrolü yapmıyor | Kesin aynı kayıt farklı başlıkla gelirse tanınmıyor | `borsa_news_service.dart` |

---

## 5. Önerilen Düzeltmeler

### KAP Bildirimleri

**Fix 1 — `KapNewsItem`'a `disclosureIndex` alanı ekle**

```dart
class KapNewsItem {
  final String title;
  final String summary;
  final String source;
  final String time;
  final String url;
  final bool isWithin72h;
  final String? disclosureIndex;   // YENİ
  final String? disclosureType;    // YENİ — disclosure_type kontrolü için
  // ...
}
```

**Fix 2 — `KapNewsService.fetch()` içinde `d['id']` ve `disclosureClass`'ı kaydet**

KAP REST API'den:
```dart
KapNewsItem(
  title: ...,
  disclosureIndex: d['id']?.toString(),
  disclosureType: d['disclosureClass']?.toString(),
  url: d['id'] != null ? 'https://www.kap.org.tr/tr/Bildirim/${d['id']}' : '',
  ...
)
```

GitHub JSON'dan: eğer JSON yapısında varsa `d['disclosureIndex']` veya `d['id']` alanını map et.

**Fix 3 — `_buildDeduplicationKey` öncelik sırası: URL/ID → title+type → title+time**

```dart
static String _buildDeduplicationKey(KapNewsItem item) {
  // 1. Kesin ID varsa onu kullan
  if (item.disclosureIndex != null && item.disclosureIndex!.isNotEmpty) {
    return 'IDX:${item.disclosureIndex}';
  }
  // 2. URL varsa onu kullan
  if (item.url.isNotEmpty) {
    return 'URL:${item.url}';
  }
  // 3. Fallback: company + title + type + time
  final company = item.source.trim().toUpperCase();
  final title = item.cleanTitle.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  final type = (item.disclosureType ?? '').toUpperCase();
  final time = _normalizeTime(item.time);
  return '$company|$title|$type|$time';
}
```

**Fix 4 — `NewsScreen._loadKap()` içinde önce `KapDisclosureService.fetchLatest()` dene, başarısız olursa `KapNewsService.fetch()` fallback kullan**

```dart
Future<void> _loadKap() async {
  if (mounted) setState(() => _loadingKap = true);
  try {
    var items = await KapDisclosureService.fetchLatest();
    if (items.isEmpty) {
      items = await KapNewsService.fetch();
    }
    if (mounted) setState(() { _kapNews = items; _loadingKap = false; });
  } catch (_) {
    try {
      final items = await KapNewsService.fetch();
      if (mounted) setState(() { _kapNews = items; _loadingKap = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingKap = false);
    }
  }
}
```

**Fix 5 — `KapDisclosureService._docToNewsItem()` `disclosure_type` alanını `KapNewsItem.disclosureType`'a map et**

```dart
return KapNewsItem(
  title: d['subject']?.toString() ?? d['company_title']?.toString() ?? 'KAP Bildirimi',
  // subject önce gelsin — daha anlamlı başlık
  disclosureIndex: (doc.id), // doküman ID = disclosureIndex
  disclosureType: d['disclosure_type']?.toString(),
  ...
);
```

Not: `_docToNewsItem` şu an static olduğu için `doc.id`'ye erişemiyor. Ya `Map`'e `__id` alanı eklenmeli ya da metod imzası değiştirilmeli.

---

### Borsa Haberleri

**Fix 6 — URL/GUID kontrolünü `_isDuplicate`'e ekle (öncelikli kontrol)**

```dart
static bool _isDuplicate(BorsaNewsItem a, BorsaNewsItem b) {
  // 1. Kesin URL eşleşmesi
  if (a.url.isNotEmpty && b.url.isNotEmpty && a.url == b.url) return true;
  // ... mevcut mantık devam ediyor
}
```

**Fix 7 — Türkçe ek normalizasyonu için basit stemmer veya suffix stripping ekle**

`_canonicalText()` içinde en sık kullanılan Türkçe ekler (`'nın`, `'nın`, `'yla`, `'yla`, `'da`, `'de`, `'ta`, `'te`, `'in`, `'ın`, `'un`, `'ün`) çıkarılabilir. Regex tabanlı basit bir çözüm:

```dart
static String _stripTurkishSuffixes(String word) {
  // Kesme işaretinden sonraki ekleri kaldır
  return word.replaceAll(RegExp(r"'[a-zçğıöşü]{1,4}$"), '');
}
```

Ve `_tokenize` içinde her token'a uygula.

**Fix 8 — `_isCloseInTime` eşiğini 18 saatten 6 saate düşür**

Borsa haberleri için aynı olay genellikle aynı gün birkaç saat içinde farklı kaynaklarda çıkıyor. 18 saat eşiği günlük tekrarlayan haberleri de birleştirebiliyor.

**Fix 9 — Stop words listesine yaygın eylem kelimelerini ekle**

"imzalandi", "imzalandi", "aciklandi", "duyuruldu", "onaylandi", "yapildi" gibi fiiller ikincil derecede anlam taşıdığından stop words'e eklenmeli (şu an "açiklandi/aciklandi", "edildi", "etti" var — bunları genişlet).

---

## 6. Değiştirilecek Dosyalar

| Dosya | Değişiklik |
|---|---|
| `lib/models/kap_news_item.dart` | `disclosureIndex` ve `disclosureType` nullable alanları ekle |
| `lib/services/kap_news_service.dart` | `fetch()` KAP REST path'inde `disclosureIndex` ve `disclosureType` doldur; `_buildDeduplicationKey` URL/ID öncelikli hale getir |
| `lib/services/kap_disclosure_service.dart` | `_docToNewsItem` doküman ID'sini `disclosureIndex`'e map et; `disclosure_type` alanını `disclosureType`'a map et; `fetchLatest` method imzası `doc.id` kullanabilmesi için refactor |
| `lib/screens/news_screen.dart` | `_loadKap()` içinde `KapDisclosureService.fetchLatest()` önce denensin, fallback `KapNewsService.fetch()` |
| `lib/services/borsa_news_service.dart` | `_isDuplicate` URL kontrolü ekle; `_isCloseInTime` 18h→6h; `_canonicalText` Türkçe ek stripping; stop words genişlet |

**Dokunulmaması gereken dosyalar** (kullanıcı isteği): trial sistemi, Premium, Google Play Billing, geri tuşu, zorunlu güncelleme, AI sistemleri.

---

## 7. Test Komutu

```bash
flutter test test/kap_news_service_test.dart
flutter analyze
```

Borsa haberleri için mevcut test dosyası yok (`borsa_news_service_test.dart` yok); yeni dedup mantığı için birim test eklenmeli.
