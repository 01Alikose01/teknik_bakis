$listResp = Invoke-WebRequest -Uri "https://www.borsaistanbul.com/en/announcement" -UseBasicParsing -TimeoutSec 30
$html = $listResp.Content
$html | Out-File -FilePath ".\tools\bist_list_page.html" -Encoding utf8

# BIST100 ile ilgili href linklerini bul
$matches = [regex]::Matches($html, 'href="(/en/announcement/\d+/[^"]*(?:bist-stock-indices|announces-constituent-changes-bist)[^"]*)"')
Write-Host "=== BIST100 LINKS ==="
foreach ($m in $matches) { Write-Host $m.Groups[1].Value }
Write-Host "=== TOP 500 chars of page ==="
Write-Host $html.Substring(0, [Math]::Min(500, $html.Length))
