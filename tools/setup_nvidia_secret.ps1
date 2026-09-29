# ─────────────────────────────────────────────────────────────────────────────
# NVIDIA API Key → Firebase Secret Manager
#
# Kullanım: .\tools\setup_nvidia_secret.ps1
# Gereksinim: Firebase CLI giriş yapılmış olmalı (firebase login)
# ─────────────────────────────────────────────────────────────────────────────

Write-Host "NVIDIA API Key'i Firebase Secret Manager'a ekleniyor..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Key degerini girin (ekranda gozukmez):" -ForegroundColor Yellow
$key = Read-Host -AsSecureString "NVIDIA_API_KEY"
$keyPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($key)
)

# Secret'i oluştur (zaten varsa yeni versiyon ekler)
$keyPlain | firebase functions:secrets:set NVIDIA_API_KEY --project teknik-bakis

Write-Host ""
Write-Host "Tamamlandi! Simdi functions klasorunu deploy edin:" -ForegroundColor Green
Write-Host "  firebase deploy --only functions:getTeknikAnaliz" -ForegroundColor White
Write-Host ""
Write-Host "Veya tum fonksiyonlari deploy etmek icin:" -ForegroundColor Yellow
Write-Host "  firebase deploy --only functions" -ForegroundColor White
