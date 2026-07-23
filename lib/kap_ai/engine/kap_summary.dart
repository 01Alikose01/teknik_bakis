import '../data/keyword_database.dart';
import 'kap_classifier.dart';

class KapSummary {
  const KapSummary();

  String generate(
    String company,
    String text,
    KapClassificationResult classification,
  ) {
    final normalized = _clean(text);

    final money = _extractMoney(normalized);

    switch (classification.category) {
      case KapCategory.newBusiness:
        return _newBusiness(company, normalized, money);

      case KapCategory.tender:
        return _tender(company, normalized, money);

      case KapCategory.shareBuyback:
        return "$company pay geri alım programına ilişkin açıklama yaptı.";

      case KapCategory.dividend:
        return "$company yatırımcılarına temettü dağıtımı hakkında açıklama yaptı.";

      case KapCategory.rightsIssue:
        return "$company bedelli sermaye artırımı kararı açıkladı.";

      case KapCategory.bonusIssue:
        return "$company bedelsiz sermaye artırımı açıkladı.";

      case KapCategory.penalty:
        return "$company hakkında idari yaptırım açıklaması yapıldı.";

      case KapCategory.productionStop:
        return "$company üretim faaliyetlerinde geçici durdurma açıkladı.";

      case KapCategory.contractTermination:
        return "$company mevcut sözleşmenin sona erdiğini duyurdu.";

      case KapCategory.executiveResignation:
        return "$company üst yönetiminde görev değişikliği açıkladı.";

      case KapCategory.financialReport:
        return "$company finansal sonuçlarını kamuoyu ile paylaştı.";

      default:
        return _fallback(company, normalized);
    }
  }

  //----------------------------------------------------
  // Yeni İş İlişkisi
  //----------------------------------------------------

  String _newBusiness(
      String company,
      String text,
      String? money,
      ) {

    final institution = _extractInstitution(text);

    if (institution != null && money != null) {
      return "$company, $institution ile $money tutarında yeni iş ilişkisi kapsamında sözleşme imzaladı.";
    }

    if (institution != null) {
      return "$company, $institution ile yeni iş ilişkisi kapsamında sözleşme imzaladı.";
    }

    if (money != null) {
      return "$company $money tutarında yeni iş ilişkisi açıkladı.";
    }

    return "$company yeni iş ilişkisi açıkladı.";
  }

  //----------------------------------------------------
  // İhale
  //----------------------------------------------------

  String _tender(
      String company,
      String text,
      String? money,
      ) {

    if (money != null) {
      return "$company $money tutarında ihaleyi kazandığını açıkladı.";
    }

    return "$company yeni bir ihale kazandığını duyurdu.";
  }

  //----------------------------------------------------
  // Fallback
  //----------------------------------------------------

  String _fallback(String company, String text) {

    final firstSentence = text.split(".").first;

    if (firstSentence.length > 160) {
      return "${firstSentence.substring(0,160)}...";
    }

    return "$company: $firstSentence";
  }

  //----------------------------------------------------
  // Kurum adı bulma
  //----------------------------------------------------

  String? _extractInstitution(String text) {

    const institutions = [

      "Savunma Sanayii Başkanlığı",

      "ASELSAN",

      "TUSAŞ",

      "TEİAŞ",

      "TCDD",

      "Enerji ve Tabii Kaynaklar Bakanlığı",

      "Milli Savunma Bakanlığı",

      "Sağlık Bakanlığı",

      "Tarım ve Orman Bakanlığı",

      "BOTAŞ",

      "TOKİ",

      "DSİ",

      "Türk Silahlı Kuvvetleri"

    ];

    for (final item in institutions) {

      if (text.toLowerCase().contains(item.toLowerCase())) {

        return item;

      }

    }

    return null;
  }

  //----------------------------------------------------
  // Para Bul
  //----------------------------------------------------

  String? _extractMoney(String text) {

    final regex = RegExp(

      r'([\d.,]+)\s*(milyar|milyon|bin)?\s*(tl|₺)',

      caseSensitive: false,

    );

    final match = regex.firstMatch(text);

    if (match == null) return null;

    return match.group(0);
  }

  //----------------------------------------------------
  // Temizle
  //----------------------------------------------------

  String _clean(String text) {

    return text

        .replaceAll("\n", " ")

        .replaceAll(RegExp(r'\s+'), ' ')

        .trim();
  }
}