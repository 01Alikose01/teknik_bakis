@echo off
cd /d d:\k\wink\teknik_bakis
git status --short > d:\k\wink\teknik_bakis\git_status.txt 2>&1
git add lib\models\kap_news_item.dart lib\services\kap_disclosure_service.dart lib\screens\news_screen.dart >> d:\k\wink\teknik_bakis\git_status.txt 2>&1
git commit -m "fix: integration fixes for KAP offline cache" >> d:\k\wink\teknik_bakis\git_commit.txt 2>&1
echo EXIT_CODE=%ERRORLEVEL% >> d:\k\wink\teknik_bakis\git_commit.txt
