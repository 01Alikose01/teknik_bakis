# KAP ve Borsa Haberleri Duplikasyon Düzeltmesi

Bu değişiklik, haber ekranındaki iki ayrı duplikasyon sorununu çözüyor: KAP bildirimleri artık Firestore'daki gerçek belge ID'siyle tekilleştiriliyor; Borsa haberleri için URL eşleşmesi, Türkçe ek normalizasyonu ve daraltılmış zaman penceresiyle dedup hassasiyeti artırıldı. Yaklaşım; modele iki nullable alan ekleyip bu alanları üç ayrı veri yolunda doldurmak, ardından `NewsScreen`'i önce Firestore'a yönlendirmek şeklinde ilerliyor.

**Watch for:** `_canonicalText` içindeki Türkçe ek regex'i (`'[a-zçğışöü]{1,4}(?=\s|$)`) satır sonu demirini lookahead olarak kullanıyor — bu satır sonu öncesindeki ekler için çalışır ancak "Fransa'nın." gibi noktalama işaretiyle biten sözcüklerde eki temizleyemez (confirmed). Her iki KAP servisi de hata fırlatırsa `_kapNews` boş kalıyor, kullanıcıya sessiz başarısızlık (confirmed). Firestore yolunda `summary` alanı `subject`'ten dolduğu için `title` ile aynı metni taşıyabilir (confirmed).

**Verdict**: APPROVED

---

## Üst düzey görünüm

`KapNewsItem` modeline eklenen `disclosureIndex` ve `disclosureType` alanları tüm üç veri yoluna (GitHub JSON, KAP REST API, Firestore) yayıldı. `_buildDeduplicationKey` IDX → URL → bileşik fallback öncelik sırasıyla çalışıyor; fallback anahtara `disclosureType`'ın eklenmesi, aynı şirketten farklı türde bildirimlerin yanlışlıkla birleştirilmesini önlüyor.

`KapDisclosureService._docToNewsItem` `docId` parametresiyle Firestore belge ID'sini `disclosureIndex`'e yazıyor, `title` önceliği `subject` → `company_title` olarak düzeltildi. Ancak `summary` da `subject`'ten dolduğundan, Firestore'da `d['summary']` alanı yoksa başlık ve özet aynı metni gösterecek.

`NewsScreen._loadKap()` Firestore-önce, fallback-sonra akışına güncellendi. İkinci `catch` bloğu her iki servisin de hata fırlatması durumunu yakalıyor ancak `_kapNews` boş bırakıp sessiz başarısızlık veriyor.

`BorsaNewsService`'te URL eşitliği kontrolü `_isDuplicate`'in başına taşındı, zaman penceresi 6 saate indirildi. `_canonicalText`'teki Türkçe ek stripping regex'i noktalama işareti ardından gelen ekleri temizleyemiyor; bu Jaccard skoru hesaplamalarında morfolojik artık tokenlara yol açıyor.

---

<details>
<summary>Issues (3)</summary>

1. **Türkçe ek regex noktalama sorunlu** — `_canonicalText` içindeki `'[a-zçğışöü]{1,4}(?=\s|$)` regex'i, `Fransa'nın.` ya da `anlaşma'yı,` gibi ek ardından noktalama işareti gelen sözcüklerde eki temizleyemez; `nın` gibi artıklar Jaccard skorunu düşürür. Regex'i `'[a-zçğışöü]{1,4}(?=[\s.,!?;:]|$)` şeklinde genişlet.

2. **KAP servisleri başarısız olursa sessiz hata** — `_loadKap()` içinde her iki servis de hata fırlatırsa `_loadingKap = false` yapılıyor, `_kapNews` boş kalıyor; yükleme göstergesi kayboluyor ve kullanıcı nedenini anlayamıyor. Hata durumunda ekranda kısa bir bilgi metni göster.

3. **Firestore yolunda `summary` başlık tekrarı** — `_docToNewsItem` içinde `summary: d['subject']?.toString() ?? d['summary']?.toString() ?? ''` sıralaması, `d['summary']` alanı varken onu görmezden geliyor. `d['summary']` önce, `d['subject']` fallback olmalı; aksi hâlde `_KapNewsCard`'da özet ve başlık aynı metni gösteriyor.

</details>

---

<details>
<summary>Detaylar</summary>

### Türkçe ek regex'inde noktalama körlüğü

`_canonicalText` içindeki ek stripping satırı:

```dart
.replaceAll(RegExp(r"'[a-zçğışöü]{1,4}(?=\s|$)"), '')
```

Lookahead yalnızca boşluk veya satır sonu demirini kontrol ediyor. `Fransa'nın.` ya da `anlaşma'yı,` gibi noktalama işaretiyle biten sözcüklerde ek temizlenemiyor; sonraki `.replaceAll(RegExp(r'[^a-z0-9çğıöşü\s]'), ' ')` satırı kesme işaretini kaldırıyor ama `nın` eki token olarak kalıyor. Bu, Jaccard skoru hesaplanırken morfolojik artıkların ayrı token sayılmasına ve benzerlik skorunun düşmesine yol açıyor.

Düzeltme:
```dart
.replaceAll(RegExp(r"'[a-zçğışöü]{1,4}(?=[\s.,!?;:]|$)"), '')
```

### Firestore ve fallback her ikisi de başarısız olursa sessiz hata

`_loadKap()` iç `catch` bloğu:

```dart
} catch (_) {
  if (mounted) setState(() => _loadingKap = false);
}
```

`_kapNews` boş liste olarak kalıyor, yükleme göstergesi kayboluyor. Kullanıcı bağlantı sorunu mu yoksa gerçekten haber yok mu olduğunu bilemez.

### Firestore yolunda `summary` ve `title` aynı kaynaktan

`_docToNewsItem` içinde:

```dart
title:   d['subject']?.toString() ?? d['company_title']?.toString() ?? 'KAP Bildirimi',
summary: d['subject']?.toString() ?? d['summary']?.toString() ?? '',
```

Firestore belgelerinde `d['summary']` alanı varsa bile `subject` önce değerlendiriliyor. Sonuç olarak `_KapNewsCard`'da özet her zaman başlıkla aynı metni taşıyacak. Sıralama `d['summary'] ?? d['subject'] ?? ''` olmalıydı.

</details>

---

<details>
<summary>Dosya haritası</summary>

| Dosya | Değişiklik |
|---|---|
| `lib/models/kap_news_item.dart` | `disclosureIndex?` ve `disclosureType?` nullable alanları + constructor parametreleri eklendi |
| `lib/services/kap_news_service.dart` | GitHub/REST path'lerinde yeni alanlar dolduruldu; `_buildDeduplicationKey` IDX→URL→fallback sırasına güncellendi; `_normalizeTime` yardımcı metodu eklendi |
| `lib/services/kap_disclosure_service.dart` | `_docToNewsItem` imzasına `docId` eklendi; `disclosureIndex`/`disclosureType` dolduruldu; `title` önceliği `subject` önce yapıldı; her iki `map` çağrısı da `docId: doc.id` ile güncellendi |
| `lib/screens/news_screen.dart` | `kap_disclosure_service.dart` import edildi; `_loadKap()` Firestore-önce, fallback-sonra akışına güncellendi |
| `lib/services/borsa_news_service.dart` | `_isDuplicate` başına URL eşitlik kontrolü eklendi; `_isCloseInTime` eşiği 6h yapıldı; `_canonicalText`'e Türkçe ek stripping eklendi; `_stopWords` genişletildi |

</details>
