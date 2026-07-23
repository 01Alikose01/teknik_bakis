import '../data/keyword_database.dart';
import 'kap_classifier.dart';

class KapRiskEngine {
  const KapRiskEngine();

  List<String> generate(
    String text,
    KapClassificationResult classification,
  ) {
    final normalized = text.toLowerCase();

    final risks = <String>[];

    //--------------------------------------------------
    // Kategori Bazlı Riskler
    //--------------------------------------------------

    switch (classification.category) {
      case KapCategory.newBusiness:
        risks.addAll([
          "Sözleşme şartlarında değişiklik yaşanabilir.",
          "Teslimat süreci planlanandan uzun sürebilir.",
        ]);
        break;

      case KapCategory.tender:
        risks.addAll([
          "Sözleşmenin resmileşme süreci tamamlanmayabilir.",
          "İhale iptal edilebilir veya gecikebilir.",
        ]);
        break;

      case KapCategory.export:
        risks.addAll([
          "Kur dalgalanmaları gelirleri etkileyebilir.",
          "İhracat izinleri veya teslimatlar gecikebilir.",
        ]);
        break;

      case KapCategory.shareBuyback:
        risks.addAll([
          "Geri alım programı planlanan büyüklüğe ulaşmayabilir.",
          "Şirket programı erken sonlandırabilir.",
        ]);
        break;

      case KapCategory.dividend:
        risks.addAll([
          "Temettü ödeme tarihi değişebilir.",
          "Vergisel düzenlemeler net getiriyi etkileyebilir.",
        ]);
        break;

      case KapCategory.rightsIssue:
        risks.addAll([
          "Mevcut ortakların payı seyrelme riski taşır.",
          "Sermaye artırımı hisse üzerinde kısa vadeli baskı oluşturabilir.",
        ]);
        break;

      case KapCategory.bonusIssue:
        risks.addAll([
          "Bedelsiz sermaye artırımı şirket değerini tek başına artırmaz.",
        ]);
        break;

      case KapCategory.penalty:
        risks.addAll([
          "İlave yaptırımlar uygulanabilir.",
          "Şirketin finansalları olumsuz etkilenebilir.",
        ]);
        break;

      case KapCategory.lawsuit:
        risks.addAll([
          "Dava süreci uzun sürebilir.",
          "Karar şirket aleyhine sonuçlanabilir.",
        ]);
        break;

      case KapCategory.bankruptcy:
        risks.addAll([
          "Şirket faaliyetlerinde ciddi belirsizlik oluşabilir.",
          "Pay sahipleri açısından yüksek risk taşır.",
        ]);
        break;

      case KapCategory.concordat:
        risks.addAll([
          "Borç yapılandırması beklenenden uzun sürebilir.",
          "Finansal belirsizlik devam edebilir.",
        ]);
        break;

      case KapCategory.productionStop:
        risks.addAll([
          "Üretim kaybı gelirleri azaltabilir.",
          "Normal faaliyetlere dönüş gecikebilir.",
        ]);
        break;

      case KapCategory.contractTermination:
        risks.addAll([
          "Gelir kaybı yaşanabilir.",
          "Yeni müşteri bulunması zaman alabilir.",
        ]);
        break;

      case KapCategory.executiveResignation:
        risks.addAll([
          "Yönetim değişikliği belirsizlik oluşturabilir.",
        ]);
        break;

      case KapCategory.financialReport:
        risks.addAll([
          "Finansal sonuçlar beklentilerin altında kalabilir.",
        ]);
        break;

      default:
        risks.add(
          "Haberin finansal etkisi zaman içerisinde netleşecektir.",
        );
    }

    //--------------------------------------------------
    // Metinden Gelen Riskler
    //--------------------------------------------------

    if (normalized.contains("iptal")) {
      risks.add("İptal riski bulunmaktadır.");
    }

    if (normalized.contains("fesih")) {
      risks.add("Sözleşmenin sona ermesi gelirleri etkileyebilir.");
    }

    if (normalized.contains("mahkeme")) {
      risks.add("Hukuki süreç belirsizlik oluşturabilir.");
    }

    if (normalized.contains("ceza")) {
      risks.add("Ek yaptırımlar uygulanabilir.");
    }

    if (normalized.contains("kur")) {
      risks.add("Kur dalgalanmaları finansalları etkileyebilir.");
    }

    if (normalized.contains("döviz")) {
      risks.add("Döviz hareketleri gelirlerde oynaklık oluşturabilir.");
    }

    //--------------------------------------------------
    // Büyük Sözleşmeler
    //--------------------------------------------------

    if (_containsLargeAmount(normalized)) {
      risks.add(
        "Büyük tutarlı projelerde operasyonel ve teslimat riski daha yüksektir.",
      );
    }

    //--------------------------------------------------
    // Tekrarları Temizle
    //--------------------------------------------------

    return risks.toSet().toList();
  }

  //--------------------------------------------------
  // Büyük Tutar Kontrolü
  //--------------------------------------------------

  bool _containsLargeAmount(String text) {
    final regex = RegExp(
      r'([\d.,]+)\s*milyar',
      caseSensitive: false,
    );

    return regex.hasMatch(text);
  }
}