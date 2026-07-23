// KAP Analiz Motoru — Keyword Database

enum KapCategory {
  newBusiness,
  tender,
  export,
  partnership,
  investment,
  capacityIncrease,
  incentive,
  debtReduction,
  shareBuyback,
  dividend,

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
      "sözleşme",
      "anlaşma",
      "protokol",
      "iş birliği",
      "işbirliği",
      "müşteri",
      "sipariş",
      "satış sözleşmesi",
      "hizmet sözleşmesi",
    ],

    KapCategory.tender: [
      "ihale",
      "ihale sonucu",
      "ihale kazanıldı",
      "teklif",
      "kamu ihalesi",
      "kazanılan ihale",
    ],

    KapCategory.export: [
      "ihracat",
      "yurtdışı satış",
      "yurt dışı satış",
      "export",
      "foreign customer",
    ],

    KapCategory.partnership: [
      "ortaklık",
      "joint venture",
      "iş ortaklığı",
      "stratejik ortak",
    ],

    KapCategory.investment: [
      "yatırım",
      "yatırım kararı",
      "tesis",
      "fabrika",
      "üretim tesisi",
    ],

    KapCategory.capacityIncrease: [
      "kapasite artışı",
      "kapasite artırımı",
      "üretim kapasitesi",
      "ek kapasite",
    ],

    KapCategory.incentive: [
      "teşvik",
      "yatırım teşvik",
      "teşvik belgesi",
    ],

    KapCategory.debtReduction: [
      "borç kapatma",
      "borç azaltımı",
      "kredi kapatma",
      "borcun ödenmesi",
    ],

    KapCategory.shareBuyback: [
      "geri alım",
      "pay geri alım",
      "pay geri alımı",
      "hisse geri alımı",
      "share buyback",
    ],

    KapCategory.dividend: [
      "temettü",
      "kar payı",
      "nakit kar payı",
      "kar dağıtımı",
    ],

    KapCategory.rightsIssue: [
      "bedelli",
      "bedelli sermaye artırımı",
      "rüçhan",
    ],

    KapCategory.bonusIssue: [
      "bedelsiz",
      "bedelsiz sermaye artırımı",
      "iç kaynaklardan",
    ],

    KapCategory.penalty: [
      "ceza",
      "idari para cezası",
      "spk cezası",
      "vergi cezası",
    ],

    KapCategory.lawsuit: [
      "dava",
      "mahkeme",
      "hukuki süreç",
      "yargılama",
    ],

    KapCategory.bankruptcy: [
      "iflas",
      "tasfiye",
    ],

    KapCategory.concordat: [
      "konkordato",
    ],

    KapCategory.contractTermination: [
      "fesih",
      "iptal edildi",
      "sözleşme feshi",
      "anlaşma sona erdi",
    ],

    KapCategory.productionStop: [
      "üretim durdu",
      "üretime ara",
      "faaliyet durdu",
      "üretimin durdurulması",
    ],

    KapCategory.executiveResignation: [
      "istifa",
      "görevden ayrıldı",
      "genel müdür",
      "yönetim kurulu üyesi",
      "ceo",
    ],

    KapCategory.financialReport: [
      "finansal tablo",
      "bilanço",
      "gelir tablosu",
      "faaliyet sonucu",
    ],

    KapCategory.generalAssembly: [
      "genel kurul",
      "olağan genel kurul",
      "olağanüstü genel kurul",
    ],

    KapCategory.articlesOfAssociation: [
      "esas sözleşme",
      "ana sözleşme",
    ],

    KapCategory.independentAudit: [
      "bağımsız denetim",
      "denetim kuruluşu",
    ],

    KapCategory.activityReport: [
      "faaliyet raporu",
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
    KapCategory.capacityIncrease: KapEffect.positive,
    KapCategory.incentive: KapEffect.positive,
    KapCategory.debtReduction: KapEffect.positive,
    KapCategory.shareBuyback: KapEffect.positive,
    KapCategory.dividend: KapEffect.positive,

    KapCategory.rightsIssue: KapEffect.negative,
    KapCategory.penalty: KapEffect.negative,
    KapCategory.lawsuit: KapEffect.negative,
    KapCategory.bankruptcy: KapEffect.negative,
    KapCategory.concordat: KapEffect.negative,
    KapCategory.contractTermination: KapEffect.negative,
    KapCategory.productionStop: KapEffect.negative,
    KapCategory.executiveResignation: KapEffect.negative,

    KapCategory.financialReport: KapEffect.neutral,
    KapCategory.generalAssembly: KapEffect.neutral,
    KapCategory.articlesOfAssociation: KapEffect.neutral,
    KapCategory.independentAudit: KapEffect.neutral,
    KapCategory.activityReport: KapEffect.neutral,

    KapCategory.bonusIssue: KapEffect.positive,
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
    KapCategory.capacityIncrease: "Kapasite Artışı",
    KapCategory.incentive: "Yatırım Teşviki",
    KapCategory.debtReduction: "Borç Azaltımı",
    KapCategory.shareBuyback: "Pay Geri Alımı",
    KapCategory.dividend: "Temettü",

    KapCategory.rightsIssue: "Bedelli Sermaye Artırımı",
    KapCategory.bonusIssue: "Bedelsiz Sermaye Artırımı",
    KapCategory.penalty: "Ceza",
    KapCategory.lawsuit: "Dava",
    KapCategory.bankruptcy: "İflas",
    KapCategory.concordat: "Konkordato",
    KapCategory.contractTermination: "Sözleşme Feshi",
    KapCategory.productionStop: "Üretim Durdurma",
    KapCategory.executiveResignation: "Yönetici İstifası",

    KapCategory.financialReport: "Finansal Rapor",
    KapCategory.generalAssembly: "Genel Kurul",
    KapCategory.articlesOfAssociation: "Esas Sözleşme",
    KapCategory.independentAudit: "Bağımsız Denetim",
    KapCategory.activityReport: "Faaliyet Raporu",

    KapCategory.unknown: "Belirsiz",
  };
}