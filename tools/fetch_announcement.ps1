$url = "https://www.borsaistanbul.com/en/announcement/15598/bist-stock-indices-periodic-review"
$resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30
$html = $resp.Content
$html | Out-File -FilePath ".\tools\announcement_15598.html" -Encoding utf8
Write-Host "Saved. Size: $($html.Length) chars"

# BIST 100 bolumunu bul
$idx = $html.IndexOf("BIST 100")
if ($idx -ge 0) {
    Write-Host "=== BIST 100 SECTION (chars $idx to $($idx+3000)) ==="
    Write-Host $html.Substring($idx, [Math]::Min(3000, $html.Length - $idx))
} else {
    Write-Host "BIST 100 string not found!"
    Write-Host "=== First 2000 chars of body ==="
    $bodyIdx = $html.IndexOf("<body")
    Write-Host $html.Substring($bodyIdx, [Math]::Min(2000, $html.Length - $bodyIdx))
}
