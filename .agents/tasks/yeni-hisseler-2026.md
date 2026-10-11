# 2026 BIST Yeni Halka Arz Hisseleri - Araştırma Raporu

**Tarih:** 5 Ekim 2026  
**Hedef dosya:** `bist 500.md`  
**Araştırma kapsamı:** 1 Temmuz 2026 – 5 Ekim 2026 arası halka arzlar

---

## Kullanılan Kaynaklar

- Görevde belirtilen bilinen eksik hisseler listesi (birincil kaynak)
- `bist 500.md` dosyasının mevcut içeriği (kontrol kaynağı)

> **Not:** Web araştırması bu çalıştırmada yapılmadı (ağ aracı mevcut değildi). Görev direktifinde açıkça belirtilen iki hisse kesin bilgi olarak kabul edildi.

---

## Tespit Edilen Yeni Hisseler

| Sembol | Şirket Adı | İşlem Başlangıcı | Kaynak |
|--------|-----------|-----------------|--------|
| **KPEKS** | Kapeks Kimya Sanayi A.Ş. | 20 Temmuz 2026 | Görev direktifi |
| **NETGL** | Net Global Endüstriyel Yatırım A.Ş. | 17 Eylül 2026 | Görev direktifi |

---

## Dosyaya Eklenenler

### KPEKS — Kapeks Kimya Sanayi A.Ş.
- **İşlem başlangıcı:** 20 Temmuz 2026
- **Eklenen pozisyon:** KOTON ile KRDMD arasına (alfabetik sıra: KO < KP < KR)
- **Eklenen veri:** `KPEKS\t0\t0\t0\t0\t0\t0\t0\t0\t0` (güncel fiyat verisi mevcut değil)

### NETGL — Net Global Endüstriyel Yatırım A.Ş.
- **İşlem başlangıcı:** 17 Eylül 2026
- **Eklenen pozisyon:** NETCD ile NIBAS arasına (alfabetik sıra: NETC < NETG < NI)
- **Eklenen veri:** `NETGL\t0\t0\t0\t0\t0\t0\t0\t0\t0` (güncel fiyat verisi mevcut değil)

---

## Dosyada Zaten Olanlar

| Sembol | Durum |
|--------|-------|
| DOFRB | Dosyada mevcut — eklenmedi |
| PATEK | Dosyada mevcut — eklenmedi |

---

## Bulunamayan / Doğrulanamayan Hisseler

Web araştırması yapılmadığından 1 Temmuz – 5 Ekim 2026 arasında halka arz olan diğer olası hisseler bu çalıştırmada tespit edilemedi. Görev direktifinde yalnızca KPEKS ve NETGL kesin olarak belirtilmiştir.

---

## Doğrulama

- **KPEKS** pozisyonu: `KOTON (satır 1135) → KPEKS (satır 1139) → KRDMD (satır 1143)` ✓
- **NETGL** pozisyonu: `NETCD (satır 1375) → NETGL (satır 1379) → NIBAS (satır 1383)` ✓
- Format tutarlılığı: Her iki hisse de diğer hisselerle aynı boş-satır-ayraçlı formatta eklendi ✓
