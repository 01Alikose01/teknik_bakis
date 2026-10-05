# Hisse Ekleme Raporu

**Tarih:** 2026-08-xx  
**Görev:** 19 yeni BIST hissesini 3 dosyaya alfabetik sıraya göre ekleme

---

## DOSYA 1: bist 500.md

### Atlanılan Hisseler (Zaten Vardı)
| Sembol | Açıklama |
|--------|----------|
| KPEKS | Kapeks Kimya Sanayi A.Ş. — zaten dosyada mevcuttu |
| NETGL | Net Global Endüstriyel Yatırım A.Ş. — zaten dosyada mevcuttu |

### Eklenen Hisseler (19 adet)
| Sembol | Şirket Adı | Eklendiği Konum |
|--------|-----------|-----------------|
| ALBTN | Albayrak Hazır Beton Sanayi | ALBRK → **ALBTN** → ALCAR |
| BETAE | Beta Enerji ve Teknoloji A.Ş. | BESTE → **BETAE** → BEWEN → BEYAZ |
| BEWEN | Bewen Enerji | BETAE → **BEWEN** → BEYAZ |
| BKRGY | Bakırcı Gayrimenkul Yatırım Ortaklığı | BJKAS → **BKRGY** → BLCYT |
| CITAS | Çitlekçi Mağazacılık Gıda A.Ş. | CIMSA → **CITAS** → CLEBI |
| EKIM | Ekim Turizm Ticaret ve Sanayi | EKGYO → **EKIM** → EKOS |
| GOLDA | Golda Gıda | GOKNR → **GOLDA** → GOLTS |
| INTET | İntetra Teknoloji ve Bilişim Hizmetleri | INTEM → **INTET** → INVEO |
| ISVEA | İsvea Seramik ve Banyo Ürünleri | ISMEN → **ISVEA** → IZENR |
| KARCL | Karçelik Çelik Sanayi (Kardemir bağlı) | KARSN → **KARCL** → KARTN |
| MASFN | Masfen Enerji | MARTI → **MASFN** → MAVI |
| METEN | Metgün Enerji Yatırımları | MERKO → **METEN** → METRO |
| ORZAX | Orzaks İlaç ve Kimya | ORGE → **ORZAX** → OSMEN |
| QUICK | Quick Sigorta | QUAGR → **QUICK** → RALYH |
| SARAE | Sa-Ra Enerji İnşaat | SANFM → **SARAE** → SARKY |
| SOHOE | Soho Giyim ve Enerji | SNICA → **SOHOE** → SOKE |
| SSAAT | Saat ve Saat | SRVGY → **SSAAT** → SUNTK |
| TKNKA | Teknika Plast | TKNSA → **TKNKA** → TLMAN |
| VEYAS | Vangölü Enerji Yatırım (Türker) | VERUS → **VEYAS** → VESBE |

**Veri formatı:** Veri olmadığı için tüm sütunlar 0 olarak girildi: `0	0	0	0	0	0	0	0	0`

---

## DOSYA 2: bistguncel.md

### Atlanılan Hisseler (Zaten Vardı)
| Sembol | Kayıt |
|--------|-------|
| BETAE | `BETAE	 	91.45	-0.60	11:57:40` |
| EKIM | `EKIM	 	21.66	-2.52	11:56:37` |
| GOLDA | `GOLDA	  	16.39	-4.21	11:57:40` |
| ISVEA | `ISVEA	  	39.86	-9.98	11:56:12` |
| ORZAX | `ORZAX	  	101.70	-0.29	11:57:35` |
| SARAE | `SARAE	 	111.50	-9.94	11:56:55` |
| SOHOE | `SOHOE	 	12.07	-2.50	11:57:36` |
| SSAAT | `SSAAT	 	42.42	-8.10	11:57:36` |

### Eklenen Hisseler (11 adet)
| Sembol | Eklendiği Konum | Değer |
|--------|-----------------|-------|
| ALBTN | ALBRK → **ALBTN** → ALCAR | `0	0	00:00:00` |
| BEWEN | BETAE → **BEWEN** → BEYAZ | `0	0	00:00:00` |
| BKRGY | BJKAS → **BKRGY** → BLCYT | `0	0	00:00:00` |
| CITAS | CIMSA → **CITAS** → CLEBI | `0	0	00:00:00` |
| INTET | INTEM → **INTET** → INVEO | `0	0	00:00:00` |
| KARCL | KARSN → **KARCL** → KARTN | `0	0	00:00:00` |
| MASFN | MARTI → **MASFN** → MAVI | `0	0	00:00:00` |
| METEN | MERKO → **METEN** → METRO | `0	0	00:00:00` |
| QUICK | QUAGR → **QUICK** → RALYH | `0	0	00:00:00` |
| TKNKA | TKNSA → **TKNKA** → TLMAN | `0	0	00:00:00` |
| VEYAS | VERUS → **VEYAS** → VESBE | `0	0	00:00:00` |

---

## DOSYA 3: lib/services/bist_stocks.dart

### Atlanılan Hisseler (Zaten Vardı)
ALBTN, BETAE, BEWEN, EKIM, GOLDA, ISVEA, KARCL, MASFN, METEN, ORZAX, QUICK, SARAE, SOHOE, SSAAT (14 adet)

### Eklenen Hisseler (7 adet — 5 yeni + 2 önceki eksik)
| Sembol | Şirket Adı | Eklendiği Konum |
|--------|-----------|-----------------|
| BKRGY | Bakırcı Gayrimenkul Yatırım Ortaklığı | BJKAS → **BKRGY** → BLCYT |
| CITAS | Çitlekçi Mağazacılık Gıda A.Ş. | CIMSA → **CITAS** → CLEBI |
| INTET | İntetra Teknoloji ve Bilişim Hizmetleri | INTEM → **INTET** → INVEO |
| KPEKS | Kapeks Kimya Sanayi A.Ş. | KOTON → **KPEKS** → KRDMA |
| NETGL | Net Global Endüstriyel Yatırım A.Ş. | NETCD → **NETGL** → NIBAS |
| TKNKA | Teknika Plast | TKNSA → **TKNKA** → TLMAN |
| VEYAS | Vangölü Enerji Yatırım (Türker) | VERUS → **VEYAS** → VESBE |

---

## Doğrulama Sonuçları

### bist 500.md — Tüm 19 hisse bulundu ✅
| Sembol | Satır No |
|--------|----------|
| ALBTN | 111 |
| BETAE | 311 |
| BEWEN | 315 |
| BKRGY | 363 |
| CITAS | 483 |
| EKIM | 667 |
| GOLDA | 859 |
| INTET | 1007 |
| ISVEA | 1047 |
| KARCL | 1079 |
| MASFN | 1315 |
| METEN | 1351 |
| ORZAX | 1479 |
| QUICK | 1631 |
| SARAE | 1683 |
| SOHOE | 1759 |
| SSAAT | 1775 |
| TKNKA | 1859 |
| VEYAS | 2003 |

### bistguncel.md — Tüm 19 hisse bulundu ✅
| Sembol | Satır No | Kaynak |
|--------|----------|--------|
| ALBTN | 65 | Yeni eklendi |
| BETAE | 193 | Zaten vardı |
| BEWEN | 195 | Yeni eklendi |
| BKRGY | 221 | Yeni eklendi |
| CITAS | 293 | Yeni eklendi |
| EKIM | 407 | Zaten vardı |
| GOLDA | 533 | Zaten vardı |
| INTET | 623 | Yeni eklendi |
| ISVEA | 655 | Zaten vardı |
| KARCL | 675 | Yeni eklendi |
| MASFN | 811 | Yeni eklendi |
| METEN | 835 | Yeni eklendi |
| ORZAX | 921 | Zaten vardı |
| QUICK | 1019 | Yeni eklendi |
| SARAE | 1055 | Zaten vardı |
| SOHOE | 1107 | Zaten vardı |
| SSAAT | 1117 | Zaten vardı |
| TKNKA | 1163 | Yeni eklendi |
| VEYAS | 1247 | Yeni eklendi |

### bist_stocks.dart — Tüm 21 hisse bulundu (19 + KPEKS + NETGL) ✅
| Sembol | Satır No | Kaynak |
|--------|----------|--------|
| ALBTN | 41 | Zaten vardı |
| BETAE | 113 | Zaten vardı |
| BEWEN | 114 | Zaten vardı |
| BKRGY | 127 | Yeni eklendi |
| CITAS | 163 | Yeni eklendi |
| EKIM | 220 | Zaten vardı |
| GOLDA | 282 | Zaten vardı |
| INTET | 327 | Yeni eklendi |
| ISVEA | 342 | Zaten vardı |
| KARCL | 350 | Zaten vardı |
| KPEKS | 381 | Yeni eklendi |
| MASFN | 420 | Zaten vardı |
| METEN | 431 | Zaten vardı |
| NETGL | 453 | Yeni eklendi |
| ORZAX | 475 | Zaten vardı |
| QUICK | 522 | Zaten vardı |
| SARAE | 540 | Zaten vardı |
| SOHOE | 568 | Zaten vardı |
| SSAAT | 573 | Zaten vardı |
| TKNKA | 596 | Yeni eklendi |
| VEYAS | 638 | Yeni eklendi |

---

## Özet

| Dosya | Eklenen | Atlanılan (Zaten Vardı) |
|-------|---------|------------------------|
| bist 500.md | 19 hisse | KPEKS, NETGL (2 adet) |
| bistguncel.md | 11 hisse | BETAE, EKIM, GOLDA, ISVEA, ORZAX, SARAE, SOHOE, SSAAT (8 adet) |
| bist_stocks.dart | 7 hisse (5 yeni + KPEKS + NETGL) | 14 hisse |

**Toplam:** 19 yeni hisse + 2 önceki eksik (KPEKS, NETGL), 3 dosya güncellendi.
