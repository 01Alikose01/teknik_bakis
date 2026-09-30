// KAP Analiz Motoru — Keyword Database

enum KapCategory {
  newBusiness,
  tender,
  export,
  partnership,
  investment,
  capacityIncrease,
  solarEnergyGES,
  incentive,
  debtReduction,
  debtIssuance,
  shareBuyback,
  shareTransaction,
  dividend,

  capitalIncrease,
  rightsIssue,
  bonusIssue,
  penalty,
  lawsuit,
  bankruptcy,
  concordat,
  contractTermination,
  productionStop,
  executiveResignation,

  financialReport,
  ratingUpdate,
  generalAssembly,
  articlesOfAssociation,
  independentAudit,
  activityReport,

  unknown,
}

enum KapEffect {
  positive,
  negative,
  neutral,
}

class KeywordDatabase {
  /// ------------------------------------------------------------
  /// CATEGORY KEYWORDS
  /// ------------------------------------------------------------

  static const Map<KapCategory, List<String>> categoryKeywords = {
    KapCategory.newBusiness: [
      "yeni iş ilişkisi",
      "iş ilişkisi",
      "sözleşme imzalanması",
      "sözleşme imzalandı",
      "satış sözleşmesi",
      "hizmet sözleşmesi",
      "sipariş alındı",
      "yeni sipariş",
      "sipariş",
      "protokol",
      "iş birliği",
      "işbirliği",
      "müşteri",
      "anlaşma",
      "mutabakat zaptı",
    ],

    KapCategory.tender: [
      "ihale",
      "ihale sonucu",
      "ihale kazanıldı",
      "ihalenin kazanılması",
      "en avantajlı teklif",
      "teklif verildi",
      "kamu ihalesi",
      "kazanılan ihale",
      "sözleşmeye davet",
      "ihale komisyonu",
    ],

    KapCategory.export: [
      "ihracat",
      "yurtdışı satış",
      "yurt dışı satış",
      "yurtdışı sipariş",
      "export",
      "foreign customer",
      "yurt dışı müşteri",
      "küresel pazarlar",
    ],

    KapCategory.partnership: [
      "ortaklık",
      "joint venture",
      "iş ortaklığı",
      "stratejik ortak",
      "ortak girişim",
      "hisse devir sözleşmesi",
      "bağlı ortaklık",
      "iştirak edinimi",
    ],

    KapCategory.investment: [
      "yatırım",
      "yatırım kararı",
      "tesis",
      "fabrika",
      "üretim tesisi",
      "yeni yatırım",
      "makine alımı",
      "modernizasyon",
      "arsa alımı",
      "gayrimenkul yatırımı",
    ],

    KapCategory.solarEnergyGES: [
      "güneş enerjisi",
      "ges yatırımı",
      "ges projesi",
      "res projesi",
      "rüzgar enerjisi",
      "yenilenebilir enerji",
      "öz tüketim ges",
      "çatı ges",
      "lisanssız elektrik",
      "epdk çağrı mektubu",
    ],

    KapCategory.capacityIncrease: [
      "kapasite artışı",
      "kapasite artırımı",
      "üretim kapasitesi",
      "ek kapasite",
      "verimlilik artışı",
      "hat genişletme",
    ],

    KapCategory.incentive: [
      "teşvik",
      "yatırım teşvik",
      "teşvik belgesi",
      "vergi indirimi",
      "kalkınma ajansı",
      "devlet desteği",
    ],

    KapCategory.debtReduction: [
      "borç kapatma",
      "borç azaltımı",
      "kredi kapatma",
      "borcun ödenmesi",
      "erken kapama",
      "finansal borçların kapatılması",
    ],

    KapCategory.debtIssuance: [
      "borçlanma aracı",
      "tahvil ihracı",
      "finansman bonosu",
      "kira sertifikası",
      "sukuk",
      "eurobond",
      "tahvil",
      "bono ihracı",
      "ihraç tavanı",
      "nitelikli yatırımcıya ihraç",
    ],

    KapCategory.shareBuyback: [
      "geri alım",
      "pay geri alım",
      "pay geri alımı",
      "hisse geri alımı",
      "share buyback",
      "geri alınan paylar",
      "payların geri alınması",
    ],

    KapCategory.shareTransaction: [
      "pay alım satım bildirimi",
      "pay alımı",
      "pay satışı",
      "hisse alımı",
      "hisse satışı",
      "mkk pay devri",
      "ortaklık payı",
      "yönetim kurulu başkanı pay",
    ],

    KapCategory.dividend: [
      "temettü",
      "nakit temettü",
      "temettü dağıtımı",
      "temettü dağıtım",
      "temettü ödemesi",
      "temettü teklifi",
      "kar payı",
      "kâr payı",
      "kar payı dağıtımı",
      "kâr payı dağıtımı",
      "kar payı dağıtım",
      "kâr payı dağıtım",
      "nakit kar payı",
      "nakit kâr payı",
      "kar payı avansı",
      "kâr payı avansı",
      "hisse başına temettü",
      "hisse başına kar payı",
      "kar payı dağıtım işlemlerine ilişkin bildirim",
      "kâr payı dağıtım işlemlerine ilişkin bildirim",
    ],

    KapCategory.capitalIncrease: [
      "sermaye artırımı",
      "sermaye tavanı",
      "kayıtlı sermaye",
      "sermaye artırımı kararı",
      "ödenmiş sermaye",
    ],

    KapCategory.rightsIssue: [
      "bedelli",
      "bedelli sermaye artırımı",
      "rüçhan hakkı",
      "rüçhan",
      "rüçhan hakkı kullanım",
      "nakden sermaye artırımı",
    ],

    KapCategory.bonusIssue: [
      "bedelsiz",
      "bedelsiz sermaye artırımı",
      "iç kaynaklardan",
      "kar yedeklerinden",
      "emisyon primi",
      "bedelsiz pay",
    ],

    KapCategory.penalty: [
      "ceza",
      "idari para cezası",
      "spk cezası",
      "vergi cezası",
      "rekabet kurumu",
      "para cezası",
      "yaptırım",
    ],

    KapCategory.lawsuit: [
      "dava",
      "mahkeme",
      "hukuki süreç",
      "yargılama",
      "tazminat davası",
      "arabuluculuk",
      "icra takibi",
      "ihtilaf",
    ],

    KapCategory.bankruptcy: [
      "iflas",
      "tasfiye",
      "iflas erteleme",
    ],

    KapCategory.concordat: [
      "konkordato",
      "konkordato projesi",
      "geçici mühlet",
      "kesin mühlet",
    ],

    KapCategory.contractTermination: [
      "fesih",
      "iptal edildi",
      "sözleşme feshi",
      "anlaşma sona erdi",
      "sözleşmeden dönme",
      "tasfiye edildi",
    ],

    KapCategory.productionStop: [
      "üretim durdu",
      "üretime ara",
      "faaliyet durdu",
      "üretimin durdurulması",
      "faaliyetlerin geçici durdurulması",
      "bakım onarım çalışması",
    ],

    KapCategory.executiveResignation: [
      "istifa",
      "görevden ayrıldı",
      "genel müdür",
      "yönetim kurulu üyesi",
      "ceo",
      "atama",
      "görev dağılımı",
    ],

    KapCategory.financialReport: [
      "finansal tablo",
      "bilanço",
      "gelir tablosu",
      "faaliyet sonucu",
      "finansal rapor",
      "dönem kârı",
      "net kâr",
      "çeyrek sonuçları",
    ],

    KapCategory.ratingUpdate: [
      "kredi notu",
      "kredi derecelendirme",
      "derecelendirme notu",
      "görünüm pozitif",
      "görünüm durağan",
      "jcr",
      "fitch",
      "moody",
      "s&p",
    ],

    KapCategory.generalAssembly: [
      "genel kurul",
      "olağan genel kurul",
      "olağanüstü genel kurul",
      "genel kurul toplantısı",
      "genel kurul kararları",
    ],

    KapCategory.articlesOfAssociation: [
      "esas sözleşme",
      "ana sözleşme",
      "esas sözleşme tadili",
    ],

    KapCategory.independentAudit: [
      "bağımsız denetim",
      "denetim kuruluşu",
      "bağımsız denetçi raporu",
    ],

    KapCategory.activityReport: [
      "faaliyet raporu",
      "yıllık faaliyet raporu",
      "sürdürülebilirlik raporu",
    ],
  };

  /// ------------------------------------------------------------
  /// EFFECT MAP
  /// ------------------------------------------------------------

  static const Map<KapCategory, KapEffect> effects = {
    KapCategory.newBusiness: KapEffect.positive,
    KapCategory.tender: KapEffect.positive,
    KapCategory.export: KapEffect.positive,
    KapCategory.partnership: KapEffect.positive,
    KapCategory.investment: KapEffect.positive,
    KapCategory.solarEnergyGES: KapEffect.positive,
    KapCategory.capacityIncrease: KapEffect.positive,
    KapCategory.incentive: KapEffect.positive,
    KapCategory.debtReduction: KapEffect.positive,
    KapCategory.shareBuyback: KapEffect.positive,
    KapCategory.dividend: KapEffect.positive,
    KapCategory.bonusIssue: KapEffect.positive,

    KapCategory.rightsIssue: KapEffect.negative,
    KapCategory.penalty: KapEffect.negative,
    KapCategory.lawsuit: KapEffect.negative,
    KapCategory.bankruptcy: KapEffect.negative,
    KapCategory.concordat: KapEffect.negative,
    KapCategory.contractTermination: KapEffect.negative,
    KapCategory.productionStop: KapEffect.negative,
    KapCategory.executiveResignation: KapEffect.negative,

    KapCategory.debtIssuance: KapEffect.neutral,
    KapCategory.shareTransaction: KapEffect.neutral,
    KapCategory.capitalIncrease: KapEffect.neutral,
    KapCategory.financialReport: KapEffect.neutral,
    KapCategory.ratingUpdate: KapEffect.neutral,
    KapCategory.generalAssembly: KapEffect.neutral,
    KapCategory.articlesOfAssociation: KapEffect.neutral,
    KapCategory.independentAudit: KapEffect.neutral,
    KapCategory.activityReport: KapEffect.neutral,

    KapCategory.unknown: KapEffect.neutral,
  };

  /// ------------------------------------------------------------
  /// TÜRKÇE İSİMLER
  /// ------------------------------------------------------------

  static const Map<KapCategory, String> categoryNames = {
    KapCategory.newBusiness: "Yeni İş İlişkisi",
    KapCategory.tender: "İhale Kazanımı",
    KapCategory.export: "İhracat",
    KapCategory.partnership: "Ortaklık",
    KapCategory.investment: "Yatırım",
    KapCategory.solarEnergyGES: "Güneş / Yenilenebilir Enerji",
    KapCategory.capacityIncrease: "Kapasite Artışı",
    KapCategory.incentive: "Yatırım Teşviki",
    KapCategory.debtReduction: "Borç Azaltımı",
    KapCategory.debtIssuance: "Borçlanma Aracı İhracı",
    KapCategory.shareBuyback: "Pay Geri Alımı",
    KapCategory.shareTransaction: "Pay Alım/Satım Bildirimi",
    KapCategory.dividend: "Temettü (Kâr Payı)",

    KapCategory.capitalIncrease: "Sermaye Artırımı",
    KapCategory.rightsIssue: "Bedelli Sermaye Artırımı",
    KapCategory.bonusIssue: "Bedelsiz Sermaye Artırımı",
    KapCategory.penalty: "İdari Yaptırım / Ceza",
    KapCategory.lawsuit: "Dava / Hukuki Süreç",
    KapCategory.bankruptcy: "İflas",
    KapCategory.concordat: "Konkordato",
    KapCategory.contractTermination: "Sözleşme Feshi",
    KapCategory.productionStop: "Üretim Durdurma",
    KapCategory.executiveResignation: "Yönetici Değişikliği",

    KapCategory.financialReport: "Finansal Rapor",
    KapCategory.ratingUpdate: "Kredi Notu / Derecelendirme",
    KapCategory.generalAssembly: "Genel Kurul",
    KapCategory.articlesOfAssociation: "Esas Sözleşme",
    KapCategory.independentAudit: "Bağımsız Denetim",
    KapCategory.activityReport: "Faaliyet Raporu",

    KapCategory.unknown: "Özel Durum Bildirimi",
  };
}