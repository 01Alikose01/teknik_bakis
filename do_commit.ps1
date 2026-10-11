Set-Location "d:\k\wink\teknik_bakis"
$status = & git status --short 2>&1
$status | Out-File "d:\k\wink\teknik_bakis\git_status.txt"
& git add "lib\models\kap_news_item.dart" "lib\services\kap_disclosure_service.dart" "lib\screens\news_screen.dart" 2>&1 | Out-File -Append "d:\k\wink\teknik_bakis\git_status.txt"
$commit = & git commit -m "fix: integration fixes for KAP offline cache" 2>&1
$commit | Out-File "d:\k\wink\teknik_bakis\git_commit.txt"
