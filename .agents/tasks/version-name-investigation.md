# VersionName Araştırma Raporu

**Tarih:** 3 Ekim 2026  
**Durum:** Salt-okunur analiz — hiçbir dosya değiştirilmedi.

---

## Özet Yanıt (Önce Sonuç)

**versionCode 36432 için önerilen versionName: `1.0.0`**

Neden: Projenin başından bugüne tüm git geçmişinde tek bir versionName kullanılmış: `1.0.0`. Hiçbir commit'te `3.x.x` formatı yoktur. Play Console'da da versionName `1.0.0` olarak görünüyor. Dolayısıyla `3.6.432` için projede hiçbir gerçek geçmiş ya da dayanak yoktur.

Tutarlı seçim:
```
pubspec.yaml → version: 1.0.0+36432
```
Bu; `versionName = 1.0.0`, `versionCode = 36432` üretir.

---

## Kanıtlar

### 1. pubspec.yaml — Mevcut Değer

**Dosya:** `d:\k\wink\teknik_bakis\pubspec.yaml`, satır 4

```yaml
version: 1.0.0+1
```

- `versionName` → `1.0.0`
- `versionCode` (build number) → `1`

Bu değer **İlk commit'ten (23 Temmuz 2026) bugüne hiç değişmemiş.**

---

### 2. android/app/build.gradle.kts — Gradle Kaynak Yönlendirmesi

**Dosya:** `d:\k\wink\teknik_bakis\android\app\build.gradle.kts`

```kotlin
defaultConfig {
    versionCode = flutter.versionCode   // pubspec.yaml build number → 1
    versionName = flutter.versionName   // pubspec.yaml version → "1.0.0"
}
```

Gradle'da sabit bir değer **yok**; tüm kaynak `pubspec.yaml`'dan geliyor.  
CI/CD, fastlane, veya özel bir versiyonlama scripti mevcut değil.

---

### 3. Git Geçmişi — 3.x.x Hiç Kullanılmamış

`git log --all -- pubspec.yaml` ile her commit'teki pubspec.yaml `version:` alanı tek tek okundu:

| Commit | Tarih | version değeri |
|--------|-------|----------------|
| d04d372 (HEAD) | 2 Eki 2026 | `1.0.0+1` |
| 56145db | 30 Eyl 2026 | `1.0.0+1` |
| 4549fbc | 29 Eyl 2026 | `1.0.0+1` |
| 72fac67 | 29 Eyl 2026 | `1.0.0+1` |
| acfc5c6 | 21 Eyl 2026 | `1.0.0+1` |
| 6f6ccd5 | 8 Eyl 2026 | `1.0.0+1` |
| 3eafc37 | 6 Eyl 2026 | `1.0.0+1` |
| d62937f | 15 Ağu 2026 | `1.0.0+1` |
| 4f9c347 | 12 Ağu 2026 | `1.0.0+1` |
| f538d28 | 12 Ağu 2026 | `1.0.0+1` |
| 64c5fa7 | 7 Ağu 2026 | `1.0.0+1` |
| 0ff8041 | 26 Tem 2026 | `1.0.0+1` |
| 11ae803 | 23 Tem 2026 (initial) | `1.0.0+1` |

**Sonuç: 3.x.x formatı hiçbir commit'te kullanılmamış. versionCode 36432 de git geçmişinde yok.**

---

### 4. Git Tag'leri

Proje genelinde **hiçbir tag** bulunmuyor. `git tag` çıktısı boş.

Sürüm takibi tag'lerle yapılmamış; sadece commit mesajlarıyla.

---

### 5. version-backbutton-analysis.md — Önceki Araştırma Bulgusu

**Dosya:** `d:\k\wink\teknik_bakis\.agents\tasks\version-backbutton-analysis.md`

Bir önceki araştırma raporunda şu tablo yer alıyor:

| Kaynak | version | versionCode |
|--------|---------|-------------|
| **Play Console Alpha** | `1.0.0` | `24+36431` (alışılmadık notasyon) |
| **pubspec.yaml** | `1.0.0` | `1` |

Rapor notu: *"Play Console'daki `24+36431` ifadesi standart değil; kontrol edin, gerçek `versionCode` 36432 veya benzeri olabilir."*

**Kullanıcının teyidi:** versionCode **36432** kesin (kullanıcı mesajı). Bu, önceki araştırmanın tahminiyle örtüşüyor — Play Console'da görülen `24+36431` notasyonu olası olarak `36431` (son yüklenen) ve `36432` (bir sonraki) anlamındaydı. Dolayısıyla kullanıcının `36432` bilgisi Play Console'dan bizzat edindiği kesin değerdir.

---

### 6. 3.6.432 Formatının Geçmişi Var mı?

**Hayır.** Tüm git geçmişinde, tüm agent raporlarında, CHANGELOG, CI/CD veya fastlane dosyalarında `3.x.x` formatına dair hiçbir iz yoktur.

`3.6.432` tahminine bakış:
- `versionCode = 36432` → "bu 3.6.432 olabilir mi?" sorusu muhtemelen şu mantıktan kaynaklanıyor: `36432` sayısını `major=3, minor=6, patch=432` şeklinde parse etme girişimi.
- Bu formülasyon projenin herhangi bir yerinde **referans alınmamış** ve geçmişte hiç kullanılmamış.

---

### 7. CHANGELOG / RELEASE_NOTES

Proje kök dizininde CHANGELOG veya RELEASE_NOTES dosyası **bulunmuyor.**  
`functions/node_modules/` altındaki paket CHANGELOG'ları proje sürümüyle ilgisizdir.

---

### 8. CI/CD ve Fastlane

- **`.github/workflows/update_ipo_feed.yml`**: Sadece IPO feed güncelleme otomasyonu. versionName/versionCode ile ilgisi yok.
- **fastlane/**: Proje kök dizininde fastlane dizini **bulunmuyor.**
- CI/CD kaynaklı otomatik versiyonlama altyapısı mevcut değil.

---

## Sonuç ve Öneri

### Kesin Bulgular

| Soru | Cevap |
|------|-------|
| 1.0.0 dışında daha önce 3.x.x kullanılmış mı? | **Hayır** — git geçmişinde başından bugüne sadece `1.0.0` |
| 3.6.432 formatının projede gerçek bir geçmişi var mı? | **Hayır** — hiçbir dosyada bu format yok |
| versionCode 36432 hangi commit'le ilişkili? | **Git'te yok** — yalnızca Play Console'da, pubspec'te hâlâ `+1` |
| Play Console'daki versionName | `1.0.0` |
| En tutarlı versionName tercihi | **`1.0.0`** |

### Önerilen pubspec.yaml Değeri

```yaml
version: 1.0.0+36432
```

Bu değer üretir:
- `versionName = 1.0.0` → Play Console'daki mevcut `1.0.0` ile tutarlı
- `versionCode = 36432` → Play Console'daki mevcut en yüksek değerden (`36431`) bir fazla ✓

> **Not:** Bu rapor yalnızca öneri içerir. Hiçbir dosya değiştirilmedi.

---

*Rapor sonu. Salt-okunur araştırma.*
