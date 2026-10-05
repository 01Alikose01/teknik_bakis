@echo off
cd /d "d:\k\wink\teknik_bakis"
flutter build appbundle --release > aab_out.txt 2>&1
echo ExitCode: %ERRORLEVEL% >> aab_out.txt
