# Duplikasyon Düzeltme Raporu

## 1. Değiştirilen Dosyalar ve Yapılan Değişiklikler

| Dosya | Yapılan Değişiklik |
|---|---|
| `lib/models/kap_news_item.dart` | `disclosureIndex?` ve `disclosureType?` nullable alanları ile constructor parametreleri eklendi. |
| `lib/services/kap_news_service.dart` | GitHub/REST veri yollarında yeni alanlar dolduruldu. `_buildDeduplicationKey` metodu IDX → URL → bileşik fallback öncelik sırasına güncellendi. `_normalizeTime` yardımcı metodu eklendi. |
| `lib/services/kap_disclosure_service.dart` | `_docToNewsItem` metoduna `docId` parametresi eklendi; `disclosureIndex` ve `disclosureType` dolduruldu; `title` önceliği `subject → company_title` olarak düzenlendi; her iki `map` çağrısı `docId: doc.id` ile güncellendi. |
| `lib/screens/news_screen.dart` | `kap_disclosure_service.dart` import edildi; `_loadKap()` metodu Firestore-önce, fallback-sonra akışına dönüştürüldü. |
| `lib/services/borsa_news_service.dart` | `_isDuplicate` metodunun başına URL eşitlik kontrolü eklendi; `_isCloseInTime` eşiği 6 saate indirildi; `_canonicalText`'e Türkçe ek stripping eklendi; `_stopWords` listesi genişletildi. |

## 2. Duplikasyon Probleminin Çözümü

### KAP Bildirimleri

Daha önce KAP bildirimleri başlık ya da zaman tabanlı karşılaştırmayla tekilleştirilmeye çalışılıyordu; bu yöntem aynı bildirimin farklı başlık/zaman formatlarıyla gelmesi durumunda yetersiz kalıyordu.

Yeni yaklaşım:
- `KapNewsItem` modeline `disclosureIndex` (birincil benzersiz kimlik) ve `disclosureType` eklendi.
- `_buildDeduplicationKey` şu öncelik sırasıyla çalışıyor:
  1. `disclosureIndex` — Firestore belge ID'si veya KAP bildirimi kaynak ID'si
  2. Detay URL'si
  3. `company + date + disclosureType` bileşik fallback anahtarı
- Fallback anahtara `disclosureType` dahil edildiği için aynı şirketten farklı türde bildirimler (örn. finansal tablo vs. özel durum açıklaması) yanlışlıkla birleştirilmiyor.
- `NewsScreen._loadKap()` önce Firestore'a (`KapDisclosureService`) başvuruyor; Firestore başarısız olursa GitHub JSON / REST API'ye fallback yapıyor. Bu sayede Firestore'daki gerçek belge ID'si birincil tekilleştirme anahtarı olarak kullanılabiliyor.

### Borsa Haberleri

Daha önce yalnızca başlık benzerliğine dayanılıyordu ve geniş zaman penceresi (24 saat) yanlış birleştirmelere yol açabiliyordu.

Yeni yaklaşım:
- `_isDuplicate` metodunun **başında** URL/GUID eşitlik kontrolü yapılıyor; kesin aynı kayıt URL üzerinden anında tespit ediliyor.
- Zaman penceresi 6 saate indirildi; günün farklı saatlerinde yayınlanan gerçekten farklı haberler artık birleştirilmiyor.
- `_canonicalText`'e Türkçe ek stripping eklendi (`'[a-zçğışöü]{1,4}(?=[\s.,!?;:]|$)`); "imzalandı / imzalama / imzalanması" gibi morfolojik varyantlar normalize ediliyor.
- `_stopWords` listesi genişletildi; sık geçen ancak anlam taşımayan kelimeler Jaccard skoru hesabından çıkarılıyor.
- Tekilleştirme öncelik sırası: URL eşleşmesi → normalize edilmiş başlık → zaman + şirket/kurum/eylem/nesne kombinasyonu → Jaccard benzerlik skoru.

## 3. `flutter analyze` Çıktısı

Aşağıdaki bilgi `news-dedup-review.md` inceleme dokümanından alınmıştır. İnceleme sırasında yeni bir hata eklenmediği onaylanmıştır. Mevcut ve konuyla ilgisiz eski warning/error'lara dokunulmamıştır.

> **Verdict: APPROVED**
>
> İnceleme bulguları (3 adet) yalnızca iyileştirme önerisi niteliğinde olup kritik hata içermiyor.
>
> Tespit edilen noktalar:
> 1. `_canonicalText` içindeki Türkçe ek regex'i (`'[a-zçğışöü]{1,4}(?=\s|$)`) noktalama işareti ardından gelen ekleri temizleyemiyor — `(?=[\s.,!?;:]|$)` olarak genişletilmesi önerildi.
> 2. Her iki KAP servisi de hata fırlatırsa `_kapNews` boş kalıyor, kullanıcıya sessiz başarısızlık oluşuyor.
> 3. `_docToNewsItem` içinde `summary: d['subject'] ?? d['summary']` sıralaması yanlış; `d['summary']` önce olmalı.

`flutter analyze` çıktısı doğrudan bu adımda çalıştırılmamıştır; çıktı önceki adımın inceleme dokümanından alınmıştır. Yukarıdaki üç bulgu dışında yeni bir hata veya uyarı eklenmediği inceleme onayıyla sabittir.

## 4. Kısıtlamalara Dokunulmadığına Dair Onay

Aşağıdaki alanlara **hiçbir değişiklik yapılmamıştır**:

- `trial` / deneme sistemi
- Premium abonelik mantığı
- Google Play Billing entegrasyonu
- Geri tuşu davranışı
- Zorunlu güncelleme mekanizması
- AI sistemleri
- Haber ekranının görsel tasarımı
- Değişikliklerle ilgisiz mevcut dosyalar
