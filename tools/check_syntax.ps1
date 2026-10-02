$result = node --check "d:\k\wink\teknik_bakis\functions\index.js" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "SYNTAX OK: index.js gecerli JavaScript"
} else {
    Write-Host "SYNTAX ERROR:"
    Write-Host $result
}
exit $LASTEXITCODE
