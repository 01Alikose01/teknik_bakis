Set-Location "d:\k\wink\teknik_bakis"
$result = git add lib/models/ipo_item.dart lib/screens/ipo_screen.dart lib/screens/home_screen.dart test/ipo_logic_test.dart 2>&1
Write-Output "ADD: $result"
$result2 = git commit -m "fix: halka arz tarih bazli siniflandirma ve QuickCard Expanded hatasi" 2>&1
Write-Output "COMMIT: $result2"
