$headers = @{
    "User-Agent"="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Accept"="application/json, text/plain, */*"
    "Accept-Language"="tr-TR,tr;q=0.9"
    "Referer"="https://www.kap.org.tr/tr/Bildirim/Ozel"
    "Origin"="https://www.kap.org.tr"
    "sec-fetch-mode"="cors"
}
try {
    $r = Invoke-WebRequest -Uri "https://www.kap.org.tr/tr/api/disclosures" -Headers $headers -UseBasicParsing -TimeoutSec 15
    Write-Host "KAP STATUS: $($r.StatusCode)"
    Write-Host $r.Content.Substring(0, [Math]::Min(1500,$r.Content.Length))
} catch {
    Write-Host "KAP HATA: $($_.Exception.Message)"
}
