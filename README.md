# teknik_bakis

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Halka Arz Feed

Uygulamadaki `Halka Arzlar` ekrani uzaktaki bir JSON feed'i okur.

Varsayilan feed yolu:

```text
https://raw.githubusercontent.com/01Alikose01/teknik_bakis/main/data/ipo_feed.json
```

Bu adres uygulamanin icine gomuludur. Magazadan yuklenen surumde son kullanicinin GitHub hesabi eklemesi, `dart-define` vermesi veya ekstra ayar yapmasi gerekmez.

Normal derleme komutu:

```bash
flutter build apk
```

Isterseniz feed kaynagini baska bir adrese yonlendirmek icin opsiyonel override kullanabilirsiniz:

```bash
flutter build apk --dart-define=IPO_FEED_URL=https://raw.githubusercontent.com/<GITHUB_KULLANICI>/<REPO_ADI>/main/data/ipo_feed.json
```

Repo icinde otomatik guncelleme icin:

- Zamanlanmis job: `.github/workflows/update_ipo_feed.yml`
- Feed ureten script: `tools/update_ipo_feed.mjs`
- Manuel alan tamamlama dosyasi: `data/ipo_manual_overrides.json`
- Uygulamanin okudugu ciktı: `data/ipo_feed.json`

Workflow her 6 saatte bir `data/ipo_feed.json` dosyasini gunceller. Uygulama acilista ve 45 dakikada bir bu feed'i otomatik cekmeye calisir; uzaga erisemezse cache ve seed veri ile calismaya devam eder.
