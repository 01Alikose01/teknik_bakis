import '../data/keyword_database.dart';
import '../models/kap_entities.dart';
import 'kap_classifier.dart';

class KapCommentaryResult {
  final String summary;
  final String executiveSummary;
  final String financialImpact;
  final String marketOutlook;
  final String retailInvestorGuidance;
  final List<String> keyHighlights;
  final List<String> watchItems;

  const KapCommentaryResult({
    required this.summary,
    required this.executiveSummary,
    required this.financialImpact,
    required this.marketOutlook,
    required this.retailInvestorGuidance,
    required this.keyHighlights,
    required this.watchItems,
  });
}

class KapSummary {
  const KapSummary();

  /// Geriye dönük uyumluluk için tek satır özet
  String generate(
    String company,
    String text,
    KapClassificationResult classification, {
    KapEntities? entities,
  }) {
    final commentary = generateCommentary(
      company: company,
      text: text,
      classification: classification,
      entities: entities ?? const KapEntities(),
    );
    return commentary.summary;
  }

  /// Tam kapsamlı, gerçekçi finansal araştırma analizi üretir
  KapCommentaryResult generateCommentary({
    required String company,
    required String text,
    required KapClassificationResult classification,
    required KapEntities entities,
  }) {
    final cleanText = _clean(text);
    final money = entities.amount;
    final institution = entities.institution;
    final dates = entities.dates;
    final percentages = entities.percentages;
    final shareCount = entities.shareCount;
    final dividendPerShare = entities.dividendPerShare;
    final projectScope = entities.projectScope;

    switch (classification.category) {
      case KapCategory.newBusiness:
        return _buildNewBusiness(
          company: company,
          cleanText: cleanText,
          money: money,
          institution: institution,
          dates: dates,
          projectScope: projectScope,
        );

      case KapCategory.tender:
        return _buildTender(
          company: company,
          cleanText: cleanText,
          money: money,
          institution: institution,
          dates: dates,
        );

      case KapCategory.export:
        return _buildExport(
          company: company,
          cleanText: cleanText,
          money: money,
          institution: institution,
          dates: dates,
        );

      case KapCategory.shareBuyback:
        return _buildShareBuyback(
          company: company,
          cleanText: cleanText,
          money: money,
          shareCount: shareCount,
          dates: dates,
        );

      case KapCategory.dividend:
        return _buildDividend(
          company: company,
          cleanText: cleanText,
          dividendPerShare: dividendPerShare,
          dates: dates,
          percentages: percentages,
        );

      case KapCategory.bonusIssue:
        return _buildBonusIssue(
          company: company,
          cleanText: cleanText,
          percentages: percentages,
          dates: dates,
        );

      case KapCategory.rightsIssue:
        return _buildRightsIssue(
          company: company,
          cleanText: cleanText,
          percentages: percentages,
          money: money,
          dates: dates,
        );

      case KapCategory.capitalIncrease:
        return _buildCapitalIncrease(
          company: company,
          cleanText: cleanText,
          percentages: percentages,
          money: money,
        );

      case KapCategory.solarEnergyGES:
        return _buildSolarEnergy(
          company: company,
          cleanText: cleanText,
          money: money,
          projectScope: projectScope,
          dates: dates,
        );

      case KapCategory.investment:
      case KapCategory.capacityIncrease:
        return _buildInvestment(
          company: company,
          cleanText: cleanText,
          money: money,
          projectScope: projectScope,
          isCapacity: classification.category == KapCategory.capacityIncrease,
        );

      case KapCategory.partnership:
        return _buildPartnership(
          company: company,
          cleanText: cleanText,
          institution: institution,
          money: money,
        );

      case KapCategory.debtReduction:
        return _buildDebtReduction(
          company: company,
          cleanText: cleanText,
          money: money,
        );

      case KapCategory.debtIssuance:
        return _buildDebtIssuance(
          company: company,
          cleanText: cleanText,
          money: money,
          dates: dates,
        );

      case KapCategory.shareTransaction:
        return _buildShareTransaction(
          company: company,
          cleanText: cleanText,
          shareCount: shareCount,
          money: money,
        );

      case KapCategory.penalty:
        return _buildPenalty(
          company: company,
          cleanText: cleanText,
          money: money,
          institution: institution,
        );

      case KapCategory.lawsuit:
        return _buildLawsuit(
          company: company,
          cleanText: cleanText,
          money: money,
          institution: institution,
        );

      case KapCategory.contractTermination:
        return _buildContractTermination(
          company: company,
          cleanText: cleanText,
          institution: institution,
          money: money,
        );

      case KapCategory.productionStop:
        return _buildProductionStop(
          company: company,
          cleanText: cleanText,
          dates: dates,
        );

      case KapCategory.executiveResignation:
        return _buildExecutiveResignation(
          company: company,
          cleanText: cleanText,
        );

      case KapCategory.financialReport:
        return _buildFinancialReport(
          company: company,
          cleanText: cleanText,
          money: money,
        );

      case KapCategory.ratingUpdate:
        return _buildRatingUpdate(
          company: company,
          cleanText: cleanText,
        );

      case KapCategory.generalAssembly:
        return _buildGeneralAssembly(
          company: company,
          cleanText: cleanText,
          dates: dates,
        );

      default:
        return _buildGeneric(
          company: company,
          cleanText: cleanText,
          classification: classification,
          money: money,
          dates: dates,
        );
    }
  }

  // ─────────────────────────────────────────────────────────
  // 1. Yeni İş İlişkisi
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildNewBusiness({
    required String company,
    required String cleanText,
    String? money,
    String? institution,
    List<String> dates = const [],
    String? projectScope,
  }) {
    final moneyClause = money != null ? '$money tutarında ' : '';
    final partyClause = institution != null ? '$institution ile ' : '';
    final scopeClause = projectScope ?? 'yeni iş sözleşmesi';

    final summary =
        '$company, $partyClause${moneyClause}$scopeClause imzaladı. Şirketin ciro ve operasyonel nakit akışına güçlü katkı sağlayacak pozitif bir anlaşma.';

    final executiveSummary =
        '$company tarafından KAP\'a yapılan özel durum açıklamasında, ${partyClause.isNotEmpty ? partyClause : 'ilgili taraf ile '}${moneyClause.isNotEmpty ? moneyClause : ''}kapsamında $scopeClause imzalandığı bildirilmiştir. '
        '${dates.isNotEmpty ? 'Teslimat ve uygulama sürecinin ${dates.first} döneminde tamamlanması öngörülmektedir. ' : ''}'
        'Sözleşme şirketin mevcut sipariş defterini (backlog) genişleterek operasyonel görünürlüğünü pekiştirmektedir.';

    final financialImpact =
        'Açıklanan ${money != null ? money : 'yeni iş ilişkisi'}, şirketin gelecek dönem hasılatına ve operasyonel kârlılığına doğrudan yansıyacaktır. '
        'Birim kâr marjının korunması ve kapasite kullanım oranının yükselmesiyle FAVÖK performansına çarpan etkisi yapması beklenir. '
        'Düzenli hakedişler şirketin işletme sermayesi ihtiyacını hafifletecektir.';

    final marketOutlook =
        'Yeni iş anlaşmaları Borsa İstanbul\'da alıcı iştahını tetikleyen en güçlü katalizörlerdendir. '
        'Seans açılışında yukarı yönlü pozitif bir fiyat tepkisi (gap-up) beklenebilir. '
        'Yükselişin devamı için 10 günlük ortalama hacmin aşılması ve ilk açılış coşkusu sonrası kâr realizasyonunun karşılanması önem taşır.';

    final retailInvestorGuidance =
        '• Hissesi Olanlar: Ani açılış sıçramalarında aceleci satış yapmak yerine, iz süren stop (trailing-stop) ile trendin gücünü takip etmek rasyoneldir.\n'
        '• Yeni Alım Düşünenler: Seansın ilk dakikalarında tavana yakın fiyatlardan veya yüksek spread ile kovalamak yerine, gün içi hacimli geri çekilmeleri ve destek testlerini beklemek risk-getiri dengesini korur.';

    final keyHighlights = [
      if (money != null) 'Sözleşme Tutarı: $money',
      if (institution != null) 'Karşı Taraf: $institution',
      'Etki Alanı: Hasılat artışı ve sipariş defteri genişlemesi',
      'Piyasa İntibası: Pozitif fiyatlama ve hacim beklentisi',
    ];

    final watchItems = [
      'Proje teslim ve faturalandırma takvimi',
      'İlgili çeyrek bilançosundaki hasılat ve brüt kâr marjı yansıması',
      'Tedarik maliyetleri ve hammadde fiyatlarının kârlılığa etkisi',
    ];

    return KapCommentaryResult(
      summary: summary,
      executiveSummary: executiveSummary,
      financialImpact: financialImpact,
      marketOutlook: marketOutlook,
      retailInvestorGuidance: retailInvestorGuidance,
      keyHighlights: keyHighlights,
      watchItems: watchItems,
    );
  }

  // ─────────────────────────────────────────────────────────
  // 2. İhale Kazanımı
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildTender({
    required String company,
    required String cleanText,
    String? money,
    String? institution,
    List<String> dates = const [],
  }) {
    final moneyClause = money != null ? '$money tutarındaki ' : '';
    final partyClause = institution != null ? '$institution tarafından açılan ' : '';

    final summary =
        '$company, $partyClause${moneyClause}ihaleyi en avantajlı teklifi vererek kazandığını duyurdu. Şirketin sektörel pazar payını güçlendiren yüksek etkili kazanım.';

    final executiveSummary =
        '$company, $partyClause${moneyClause}kamu/özel sektör ihalesinde en avantajlı teklifi vererek ihalenin lehine sonuçlandığını ve sözleşme daveti aldığını açıklamıştır. '
        '${dates.isNotEmpty ? 'Süreç ${dates.first} itibarıyla kesinleşme aşamasındadır. ' : ''}'
        'İhale şirketin kurumsal güvenilirliğini ve iş hacmini teyit etmektedir.';

    final financialImpact =
        'Kazanılan ihale, şirketin yıllık hasılat hedeflerine güçlü bir ivme kazandıracaktır. '
        'Garantili kamu/kurumsal nakit akışı şirketin finansal dengesini korurken, ölçek ekonomisi sayesinde operasyonel kâr marjını destekleyecektir.';

    final marketOutlook =
        'İhale kazanımları hissede güçlü momentum yaratır. İlk seanslarda belirgin alıcılı seyir görülebilir; ancak ihalenin kesinleşmesi ve sözleşmenin fiilen imzalanması süreci de takip edilmelidir.';

    final retailInvestorGuidance =
        '• Hissesi Olanlar: Pozisyonu koruyup sözleşme imza aşamasını izlemek avantajlıdır.\n'
        '• Yeni Alım Düşünenler: Tavandan alım risklidir; seans içi konsolidasyon seviyeleri alım için daha sağlıklı zemin sunar.';

    final keyHighlights = [
      if (money != null) 'İhale Tutarı: $money',
      if (institution != null) 'İhale Makamı: $institution',
      'Kazanım Niteliği: En avantajlı teklif ve sözleşme daveti',
      'Bilanço Etkisi: Garantili hasılat ve güçlü nakit akışı',
    ];

    final watchItems = [
      'İtiraz süresinin tamamlanması ve kesin sözleşme imza tarihi',
      'İşin avans ve hakediş ödeme periyotları',
    ];

    return KapCommentaryResult(
      summary: summary,
      executiveSummary: executiveSummary,
      financialImpact: financialImpact,
      marketOutlook: marketOutlook,
      retailInvestorGuidance: retailInvestorGuidance,
      keyHighlights: keyHighlights,
      watchItems: watchItems,
    );
  }

  // ─────────────────────────────────────────────────────────
  // 3. İhracat
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildExport({
    required String company,
    required String cleanText,
    String? money,
    String? institution,
    List<String> dates = const [],
  }) {
    final moneyClause = money != null ? '$money değerinde ' : '';

    final summary =
        '$company, yurt dışı müşterileriyle ${moneyClause}yeni ihracat bağlantısı kurduğunu açıkladı. Döviz bazlı gelir yaratan güçlü operasyonel gelişme.';

    final executiveSummary =
        '$company, yurt dışı pazarlardaki operasyonlarını genişleterek ${moneyClause}ihracat siparişi / sözleşmesi imzaladığını açıklamıştır. '
        'Şirketin döviz pozisyonunu güçlendirecek ve uluslararası rekabet gücünü artıracaktır.';

    final financialImpact =
        'Döviz cinsi gelirler kur dalgalanmalarına karşı doğal bir koruma (hedge) sağlar. '
        'Yurt dışı satışların toplam ciro içerisindeki payının artması kâr marjlarını genel olarak yükseltir.';

    final marketOutlook =
        'İhracat odaklı şirketler Borsa İstanbul\'da enflasyonist ve kur oynaklığı dönemlerinde primli fiyatlanır. Haberin hissede pozitif ivme oluşturması beklenir.';

    final retailInvestorGuidance =
        'Döviz getirili iş modelleri uzun vadeli portföyler için koruyucu niteliktedir. Kısa vadeli teknik dirençler takip edilerek kademeli hareket edilebilir.';

    return KapCommentaryResult(
      summary: summary,
      executiveSummary: executiveSummary,
      financialImpact: financialImpact,
      marketOutlook: marketOutlook,
      retailInvestorGuidance: retailInvestorGuidance,
      keyHighlights: [
        if (money != null) 'İhracat Tutarı: $money',
        'Gelir Niteliği: Yabancı para (döviz) bazlı hasılat',
        'Stratejik Katkı: Kur riskine karşı doğal korunma ve pazar çeşitlendirmesi',
      ],
      watchItems: [
        'Yurt dışı teslimat takvimi ve gümrük süreçleri',
        'Döviz kuru parite hareketlerinin net kâra yansıması',
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 4. Pay Geri Alımı (Share Buyback)
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildShareBuyback({
    required String company,
    required String cleanText,
    String? money,
    String? shareCount,
    List<String> dates = const [],
  }) {
    final amountClause = money != null ? '$money fon büyüklüğünde ' : '';
    final countClause = shareCount != null ? '$shareCount pay için ' : '';

    final summary =
        '$company, hisse fiyatının gerçek değerini yansıtmadığı gerekçesiyle ${amountClause}${countClause}pay geri alım programı başlattığını/sürdürdüğünü bildirdi. Yönetimin güvenini teyit eden güçlü bir sinyal.';

    final executiveSummary =
        '$company yönetim kurulu, şirket paylarının borsadaki fiyat seyrinin operasyonel performans ve varlık değerini yansıtmadığı değerlendirmesiyle ${amountClause}${countClause}pay geri alım işlemi yapıldığını / program açıldığını açıklamıştır. '
        'Bu adım kurumsal yönetimin şirketin geleceğine olan tam inancını simgelemektedir.';

    final financialImpact =
        'Geri alınan paylar dolaşımdaki hisse adedini azaltarak hisse başına kârı (HBK) matematiksel olarak artırır ve özsermaye kârlılığını yukarı çeker. '
        'Şirketin nakit varlıklarının kendi hissesine yatırılması güçlü bilanço yapısını gösterir.';

    final marketOutlook =
        'Geri alım programları hisse fiyatı altında çok sağlam bir "taban desteği" oluşturur. Olası piyasa geri çekilmelerinde hissenin endekse göre daha güçlü ve defansif durmasını sağlar.';

    final retailInvestorGuidance =
        '• Hissesi Olanlar: Şirketin kendisinin alım yaptığı bir ortamda güvenle pozisyon taşınabilir.\n'
        '• Yeni Alım Düşünenler: Şirketin geri alım yaptığı ortalama fiyat seviyeleri çok güçlü bir destek ve güvenlik marjı olarak referans alınabilir.';

    return KapCommentaryResult(
      summary: summary,
      executiveSummary: executiveSummary,
      financialImpact: financialImpact,
      marketOutlook: marketOutlook,
      retailInvestorGuidance: retailInvestorGuidance,
      keyHighlights: [
        if (money != null) 'Geri Alım Fonu: $money',
        if (shareCount != null) 'İşleme Konu Pay: $shareCount',
        'Finansal Anlamı: Hisse Başı Kârı (HBK) artırıcı etki',
        'Piyasa Fonksiyonu: Güçlü taban fiyat desteği ve güven teyidi',
      ],
      watchItems: [
        'Geri alım programının kalan kullanım oranı ve tavan fiyat limiti',
        'Geri alınan payların sermayeye oranı',
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 5. Temettü (Dividend)
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildDividend({
    required String company,
    required String cleanText,
    String? dividendPerShare,
    List<String> dates = const [],
    List<String> percentages = const [],
  }) {
    final divClause = dividendPerShare != null ? '$dividendPerShare ' : '';
    final dateClause = dates.isNotEmpty ? '${dates.first} tarihinde ' : '';

    final summary =
        '$company, pay sahiplerine hisse başına ${divClause}nakit kâr payı dağıtılmasına ilişkin karar / teklif açıkladı. Şirketin nakit yaratma gücünü teyit eden temettü bildirimi.';

    final executiveSummary =
        '$company yönetim kurulu, genel kurul onayına sunulmak veya kesinleşmek üzere ${dateClause}hisse başına ${divClause}nakit kâr payı dağıtımı yapılacağını duyurmuştur. '
        'Düzenli temettü ödemesi şirketin hissedar dostu kurumsal yaklaşımını ve kârının nakit karşılığını olduğunu ortaya koymaktadır.';

    final financialImpact =
        'Temettü ödemesi şirketin kasasından nakit çıkışı yaratacak olsa da, sürdürülebilir kârlılık ve güçlü serbest nakit akışı (FCF) sayesinde bilanço dengesi bozulmadan karşılanacaktır.';

    final marketOutlook =
        'Yüksek temettü verimi sunan hisseler kurumsal fonlar ve uzun vadeli bireysel yatırımcılar tarafından talep görür. '
        'Temettü hak kullanım gününde hisse fiyatının dağıtılan brüt temettü kadar teknik olarak düşeceği (fiyat düzeltmesi) göz önünde bulundurulmalıdır.';

    final retailInvestorGuidance =
        'Temettü verimi hesaplanarak mevcut hisse fiyatıyla karşılaştırılmalıdır. Dağıtılan nakit kâr payı ile tekrar aynı hisseden alım yapmak uzun vadeli bileşik getiri gücünü maksimize eder.';

    return KapCommentaryResult(
      summary: summary,
      executiveSummary: executiveSummary,
      financialImpact: financialImpact,
      marketOutlook: marketOutlook,
      retailInvestorGuidance: retailInvestorGuidance,
      keyHighlights: [
        if (dividendPerShare != null) 'Hisse Başı Temettü: $dividendPerShare',
        if (dates.isNotEmpty) 'Ödeme / Hak Kullanım Tarihi: ${dates.first}',
        'Nitelik: Nakit kâr payı dağıtımı',
        'Yatırımcı Değeri: Düzenli nakit akışı ve bileşik getiri',
      ],
      watchItems: [
        'Genel kurul onay süreci ve kesinleşen temettü ödeme takvimi',
        'Temettü veriminin mevduat/tahvil faizleriyle kıyaslaması',
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 6. Bedelsiz Sermaye Artırımı (Bonus Issue)
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildBonusIssue({
    required String company,
    required String cleanText,
    List<String> percentages = const [],
    List<String> dates = const [],
  }) {
    final ratioClause = percentages.isNotEmpty ? '${percentages.first} oranında ' : '';

    final summary =
        '$company, iç kaynaklar ve kâr yedeklerinden karşılanmak üzere sermayesini ${ratioClause}bedelsiz artırma kararı aldığını açıkladı. Likiditeyi ve yatırımcı ilgisini artıran önemli gelişme.';

    final executiveSummary =
        '$company, mevcut ödenmiş sermayesini iç kaynaklar, emisyon primleri veya geçmiş yıl kârlarından karşılanmak üzere ${ratioClause}bedelsiz artırma kararı alarak SPK onayına sunmuştur. '
        'İşlem tamamlandığında hissedarlara herhangi bir bedel ödemeksizin ilave hisse dağıtılacaktır.';

    final financialImpact =
        'Bedelsiz sermaye artırımı şirkete yeni bir taze nakit girişi sağlamaz; özkaynaklar altındaki yedeklerin ödenmiş sermaye hesabına aktarılması muhasebesel işlemidir. '
        'Ancak şirketin ödenmiş sermayesini reel büyüklüğe yaklaştırır ve sermaye tavanını güçlendirir.';

    final marketOutlook =
        'Borsa İstanbul dinamiklerinde bedelsiz sermaye artırımları bireysel yatırımcılar arasında en yüksek coşku ve psikolojik alım yaratan gelişmelerdendir. '
        'Bölünme sonrası hisse fiyatının nominal olarak ucuzlaması işlem likiditesini ve piyasa ilgisini katlayacaktır.';

    final retailInvestorGuidance =
        'Bedelsiz bölünmenin şirket değerini bir gecede ikiye katlamayacağı bilinmelidir. '
        'İlk spekülatif tavan hareketlerinde aşırı değerlenmiş çarpanlara (F/K, PD/DD) karşı temkinli olunmalı, kademeli kâr realizasyonu stratejisi hazır tutulmalıdır.';

    return KapCommentaryResult(
      summary: summary,
      executiveSummary: executiveSummary,
      financialImpact: financialImpact,
      marketOutlook: marketOutlook,
      retailInvestorGuidance: retailInvestorGuidance,
      keyHighlights: [
        if (percentages.isNotEmpty) 'Bedelsiz Oranı: ${percentages.first}',
        'Kaynak: İç kaynaklar, kâr yedekleri ve emisyon primi',
        'Piyasa Etkisi: Yüksek likidite artışı ve işlem hacmi genişlemesi',
      ],
      watchItems: [
        'SPK onay süreci ve ihraç belgesi onayı',
        'Bedelsiz pay alma hakkı kullanım başlangıç tarihi',
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 7. Bedelli Sermaye Artırımı (Rights Issue)
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildRightsIssue({
    required String company,
    required String cleanText,
    List<String> percentages = const [],
    String? money,
    List<String> dates = const [],
  }) {
    final ratioClause = percentages.isNotEmpty ? '${percentages.first} oranında ' : '';

    final summary =
        '$company, sermayesini nakden (bedelli) ${ratioClause}artırma kararı aldı. Şirket özkaynaklarını güçlendirmeyi hedeflerken rüçhan hakkı süreci yakından takip edilmelidir.';

    final executiveSummary =
        '$company yönetim kurulu, şirketin finansal yapısını güçlendirmek ve fon temin etmek amacıyla ${ratioClause}nakden (bedelli) sermaye artırımı kararı almıştır. '
        'Mevcut ortaklar rüçhan haklarını kullanarak belirlenen nominal bedel üzerinden sermaye artırımına katılabilecektir.';

    final financialImpact =
        'Ortaklardan toplanacak nakit, şirketin borç kapatmasında, finansman giderlerini düşürmesinde veya yeni yatırımların finansmanında kullanılacaktır. '
        'Orta vadede bilançoyu rahatlatabilecek bir adım olsa da kısa vadede ortaklara nakit koyma yükümlülüğü getirir.';

    final marketOutlook =
        'Piyasa bedelli kararlarını genellikle ilk etapta negatif satış baskısıyla karşılar. '
        'Rüçhan hakkı kullanmak istemeyen veya ek nakdi bulunmayan yatırımcıların hisse satışına yönelmesi kısa vadeli baskı yaratabilir.';

    final retailInvestorGuidance =
        'Yatırımcılar rüçhan haklarını (kuponlarını) ya nakit ödeyerek yeni hisseye dönüştürmeli ya da rüçhan pazarında son kullanım tarihine kadar satmalıdır. '
        'İşlem yapılmazsa haklar yanar ve ciddi sermaye kaybı (sulanma) oluşur.';

    return KapCommentaryResult(
      summary: summary,
      executiveSummary: executiveSummary,
      financialImpact: financialImpact,
      marketOutlook: marketOutlook,
      retailInvestorGuidance: retailInvestorGuidance,
      keyHighlights: [
        if (percentages.isNotEmpty) 'Bedelli Oranı: ${percentages.first}',
        if (money != null) 'Hedeflenen Fon Tutarı: $money',
        'Risk Unsuru: Sermaye sulanması (dilution) ve nakit ihtiyacı',
        'Kısa Vadeli Yön: Satış baskısı ve rüçhan kuponu oynaklığı',
      ],
      watchItems: [
        'SPK onay süreci ve izahname onayı',
        'Rüçhan hakkı kullanım başlangıç ve bitiş tarihleri',
        'Satılamayan payların taahhüt güvencesi',
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 8. Sermaye Artırımı (Genel)
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildCapitalIncrease({
    required String company,
    required String cleanText,
    List<String> percentages = const [],
    String? money,
  }) {
    final ratioClause = percentages.isNotEmpty ? '${percentages.first} ' : '';

    return KapCommentaryResult(
      summary:
          '$company sermaye tavanı / sermaye artırımı hakkında açıklama yaptı. Şirketin büyüme planları ve özkaynak yapısı güncelleniyor.',
      executiveSummary:
          '$company sermaye tavanını artırmak veya sermaye yapısını yeniden düzenlemek amacıyla resmi süreç başlattığını açıklamıştır. Şirketin kurumsal ölçeğini genişletme adımıdır.',
      financialImpact:
          'Sermaye tavanı artırımı ileride yapılacak bedelli/bedelsiz artırımlara zemin hazırlar. Şirketin finansman esnekliğini artırır.',
      marketOutlook:
          'Sermaye tavanı artırımları genellikle orta vadeli büyüme planlarının habercisi olarak nötr-pozitif değerlendirilir.',
      retailInvestorGuidance:
          'Şirketin ilerleyen dönemde bedelli mi yoksa bedelsiz mi sermaye artırımı yapacağı yönündeki duyurular takip edilmelidir.',
      keyHighlights: [
        if (ratioClause.isNotEmpty) 'Oran / Tutar: $ratioClause',
        'Konu: Sermaye yapısı ve tavan güncellemesi',
      ],
      watchItems: ['SPK onay süreci ve genel kurul kararı'],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 9. Güneş Enerjisi / Yenilenebilir Enerji (GES)
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildSolarEnergy({
    required String company,
    required String cleanText,
    String? money,
    String? projectScope,
    List<String> dates = const [],
  }) {
    final moneyClause = money != null ? '$money yatırım tutarında ' : '';

    final summary =
        '$company, öz tüketim elektrik maliyetlerini düşürmek ve sürdürülebilirlik amacıyla ${moneyClause}Güneş Enerjisi Santrali (GES) yatırımı kararı aldı. Kâr marjlarını kalıcı yükseltecek stratejik adım.';

    final executiveSummary =
        '$company, üretim tesislerinin enerji ihtiyacını karşılamak ve enerji maliyetlerini minimize etmek üzere ${moneyClause}Güneş Enerjisi Santrali (GES) projesine başladığını bildirmiştir. '
        'Tesis faaliyete geçtiğinde şirketin enerji faturası giderlerinde ciddi tasarruf sağlanacaktır.';

    final financialImpact =
        'Yatırım tamamlandığında şirketin faaliyet giderleri azalacak ve elektrik maliyetlerinde kalıcı tasarruf sağlanarak brüt kâr marjı güçlenecektir. '
        'Ayrıca üretilen ihtiyaç fazlası elektriğin şebekeye satışı ek nakit akışı yaratabilir.';

    final marketOutlook =
        'Yeşil enerji ve ESG uyumlu yatırımlar kurumsal yatırımcılar tarafından oldukça primli karşılanır. Hisse üzerinde orta-uzun vadeli pozitif fiyatlama desteği oluşturur.';

    final retailInvestorGuidance =
        'Enerji maliyetlerini düşüren şirketler kârlılıklarını enflasyona karşı korurlar. Değer odaklı uzun vadeli portföyler için olumlu bir katalizördür.';

    return KapCommentaryResult(
      summary: summary,
      executiveSummary: executiveSummary,
      financialImpact: financialImpact,
      marketOutlook: marketOutlook,
      retailInvestorGuidance: retailInvestorGuidance,
      keyHighlights: [
        if (money != null) 'Yatırım Büyüklüğü: $money',
        'Yatırım Türü: Güneş Enerjisi Santrali (GES)',
        'Temel Fayda: Elektrik giderlerinde kalıcı tasarruf ve marj artışı',
      ],
      watchItems: [
        'Santralin montaj ve geçici kabul tarihi',
        'Yıllık megavat (MW) kurulu güç kapasitesi ve elektrik üretim tahmini',
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 10. Yatırım & Kapasite Artışı
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildInvestment({
    required String company,
    required String cleanText,
    String? money,
    String? projectScope,
    required bool isCapacity,
  }) {
    final moneyClause = money != null ? '$money tutarında ' : '';
    final title = isCapacity ? 'kapasite artırımı' : 'yeni yatırım kararı';

    final summary =
        '$company, üretim hacmini ve pazar payını genişletmek amacıyla ${moneyClause}$title açıkladı. Gelecek dönem büyümesini hızlandıracak pozitif hamle.';

    final executiveSummary =
        '$company, artan talebi karşılamak ve yeni pazarlara açılmak hedefiyle ${moneyClause}$title aldığını ve proje takvimini başlattığını bildirmiştir. '
        'Şirketin ölçek ekonomisi avantajını artıracaktır.';

    final financialImpact =
        'Kısa vadede yatırım harcaması (CapEx) gerektirse de, devreye girdiğinde şirketin üretim hacmini, hasılatını ve ölçek ekonomisi sayesinde FAVÖK marjını yukarı taşıyacaktır.';

    final marketOutlook =
        'Piyasa büyüme odaklı yatırımları olumlu karşılar. Yatırımın finansman modeli (özkaynak / teşvik / kredi) dengeli olduğu sürece hisse trendini destekler.';

    final retailInvestorGuidance =
        'Yatırımın devreye giriş tarihi ve yaratacağı ilave ciro potansiyeli analiz edilerek orta vadeli pozisyonlar korunabilir.';

    return KapCommentaryResult(
      summary: summary,
      executiveSummary: executiveSummary,
      financialImpact: financialImpact,
      marketOutlook: marketOutlook,
      retailInvestorGuidance: retailInvestorGuidance,
      keyHighlights: [
        if (money != null) 'Yatırım Büyüklüğü: $money',
        'Amaç: Kapasite genişletme ve pazar payı artırımı',
        'Finansal Etki: Gelecek dönem ciro potansiyelinde sıçrama',
      ],
      watchItems: [
        'Yatırım teşvik belgesi durumu ve vergi avantajları',
        'Tesisin faaliyete geçeceği planlanan çeyrek',
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 11. Ortaklık / Satın Alma (Partnership / M&A)
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildPartnership({
    required String company,
    required String cleanText,
    String? institution,
    String? money,
  }) {
    final partyClause = institution != null ? '$institution ile ' : '';
    final moneyClause = money != null ? '$money değerinde ' : '';

    return KapCommentaryResult(
      summary:
          '$company, $partyClause${moneyClause}stratejik ortaklık / pay devri anlaşması açıkladı. Şirketin inorganik büyümesini ve pazar erişimini güçlendirecek adım.',
      executiveSummary:
          '$company, stratejik hedefleri doğrultusunda $partyClause${moneyClause}ortaklık / hisse devir protokolü imzaladığını bildirmiştir. Sinerji ve teknoloji transferi sağlaması hedeflenmektedir.',
      financialImpact:
          'Satın alınan veya ortak olunan şirketin bilançosu konsolide edilecek, toplam varlıklar ve ciro genişleyecektir. Yeni pazar kanalları kârlılığı destekler.',
      marketOutlook:
          'Stratejik ortaklıklar çarpan büyümesi beklentisiyle piyasada alıcılı karşılanır.',
      retailInvestorGuidance:
          'Ortaklığın şirketin borç yükünü aşırı artırıp artırmadığı ve yaratacağı sinerji yakından incelenmelidir.',
      keyHighlights: [
        if (institution != null) 'Ortak / Karşı Taraf: $institution',
        if (money != null) 'İşlem Değeri: $money',
        'Stratejik Nitelik: Pazar payı ve teknoloji sinerjisi',
      ],
      watchItems: [
        'Rekabet Kurumu ve resmi onay süreçleri',
        'Kapanış tarihi ve konsolidasyon başlangıcı',
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 12. Borç Azaltımı
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildDebtReduction({
    required String company,
    required String cleanText,
    String? money,
  }) {
    final moneyClause = money != null ? '$money tutarında ' : '';

    return KapCommentaryResult(
      summary:
          '$company, ${moneyClause}finansal borç kapaması gerçekleştirdiğini açıkladı. Finansman giderlerini azaltacak bilanço dostu pozitif bildirim.',
      executiveSummary:
          '$company, finansal borçlarını ${moneyClause}erken kapatarak veya yapılandırarak faiz yükünü hafiflettiğini açıklamıştır.',
      financialImpact:
          'Yüksek faiz ortamında borç kapatmak, şirketin net finansman giderlerini düşürür ve net kâr marjına doğrudan pozitif katkı sağlar.',
      marketOutlook:
          'Borçluluğu azalan şirketlerin risk primi düşer, değerleme çarpanları iyileşir.',
      retailInvestorGuidance:
          'Şirketin net borç/FAVÖK çarpanındaki iyileşme orta vadeli temel analizi güçlendirir.',
      keyHighlights: [
        if (money != null) 'Kapatılan Borç Tutarı: $money',
        'Finansal Fayda: Faiz yükü ve finansman giderlerinde düşüş',
      ],
      watchItems: ['Sonraki çeyrek bilançosunda net borç seviyesi'],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 13. Borçlanma Aracı İhracı (Tahvil / Bono)
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildDebtIssuance({
    required String company,
    required String cleanText,
    String? money,
    List<String> dates = const [],
  }) {
    final moneyClause = money != null ? '$money büyüklüğe kadar ' : '';

    return KapCommentaryResult(
      summary:
          '$company, ${moneyClause}borçlanma aracı (tahvil/bono) ihracı için onay / ihraç tavanı aldığını duyurdu. Likidite ve fonlama kaynaklarını çeşitlendiren adım.',
      executiveSummary:
          '$company, yurt içinde veya yurt dışında nitelikli yatırımcılara satılmak üzere ${moneyClause}borçlanma aracı ihracı için SPK onay belgesi veya yetki alındığını açıklamıştır.',
      financialImpact:
          'Banka kredilerine kıyasla daha uygun vade ve faiz ile sermaye piyasalarından fon temin edilmesini sağlar. İşletme sermayesini destekler.',
      marketOutlook:
          'Hisse fiyatı üzerinde genellikle nötr etki gösterir. Şirketin borçlanma faiz oranı ve maliyeti yakından takip edilmelidir.',
      retailInvestorGuidance:
          'Şirketin borç vadelerini uzatması nakit akışı açısından pozitif olsa da borç/özsermaye dengesi izlenmelidir.',
      keyHighlights: [
        if (money != null) 'İhraç Tavanı: $money',
        'Araç Türü: Tahvil / Finansman Bonosu / Sukuk',
      ],
      watchItems: ['İhracın faiz oranı ve vadesi'],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 14. Pay Alım / Satım Bildirimi (Ortak/Yönetici)
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildShareTransaction({
    required String company,
    required String cleanText,
    String? shareCount,
    String? money,
  }) {
    final lower = cleanText.toLowerCase();
    final isAlim = lower.contains('alım') || lower.contains('aldı');
    final isSatim = lower.contains('satım') || lower.contains('satış') || lower.contains('sattı');
    final countClause = shareCount != null ? '$shareCount ' : '';

    final yon = isAlim
        ? 'ortak/yönetici tarafından pay alımı yapıldığını'
        : isSatim
            ? 'ortak tarafından pay satışı yapıldığını'
            : 'pay alım-satım işlemi gerçekleştiğini';

    final summary =
        '$company paylarında $yon duyurdu. ${isAlim ? 'Yönetimin hisseye güvenini gösteren olumlu işlem.' : isSatim ? 'Kısa vadeli arz baskısı yaratabilecek satış bildirimi.' : 'Hissedar pay hareketliliği.'}';

    final executiveSummary =
        '$company sermayesinde doğrudan veya dolaylı pay sahibi olan kişiler/yöneticiler tarafından borsada ${countClause}pay işlemi gerçekleştirildiği bildirilmiştir. '
        '${isAlim ? 'İçeriden öğrenenlerin (insiders) hisse alımları piyasaya güçlü güven mesajı verir.' : isSatim ? 'Büyük ortak satışları piyasada ek hisse arzı yarattığı için yakından takip edilmelidir.' : ''}';

    final financialImpact =
        'İşlem doğrudan şirket bilançosunu etkilemez; ortakların şahsi portföy tasarrufudur. Ancak kurumsal ortaklık yapısını ve dolaşımdaki pay oranını değiştirebilir.';

    final marketOutlook = isAlim
        ? 'Ortak alımları hissede yukarı yönlü destek ve alıcı güveni oluşturur.'
        : isSatim
            ? 'Ortak satışları hissede kısa vadeli baskı ve kâr realizasyonuna neden olabilir.'
            : 'Nötr piyasa etkisi beklenir.';

    final retailInvestorGuidance = isAlim
        ? 'Ortakların alım yaptığı fiyat aralıkları destek seviyeleri olarak değerlendirilebilir.'
        : 'Satışın tamamlanıp tamamlanmadığı ve kalan pay oranı izlenmelidir.';

    return KapCommentaryResult(
      summary: summary,
      executiveSummary: executiveSummary,
      financialImpact: financialImpact,
      marketOutlook: marketOutlook,
      retailInvestorGuidance: retailInvestorGuidance,
      keyHighlights: [
        if (shareCount != null) 'İşlem Adedi: $shareCount',
        if (money != null) 'İşlem Tutarı: $money',
        'İşlem Yönü: ${isAlim ? "Pay Alımı (Pozitif)" : isSatim ? "Pay Satışı (Negatif)" : "İşlem Bildirimi"}',
      ],
      watchItems: ['Ortaklık payının sermayedeki yeni yüzdesi'],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 15. Ceza / İdari Yaptırım
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildPenalty({
    required String company,
    required String cleanText,
    String? money,
    String? institution,
  }) {
    final partyClause = institution != null ? '$institution tarafından ' : '';
    final moneyClause = money != null ? '$money tutarında ' : '';

    return KapCommentaryResult(
      summary:
          '$company hakkında $partyClause${moneyClause}idari para cezası / yaptırım bildirildi. Hissede kısa vadeli baskı yaratabilecek gelişme.',
      executiveSummary:
          '$company hakkında yetkili kurum tarafından ${moneyClause}idari para cezası uygulandığı açıklanmıştır. Şirket yasal haklarını kullanarak uzlaşma veya itiraz yoluna gidebilecektir.',
      financialImpact:
          'Nakit çıkışı yaratır ve ilgili çeyrekte diğer faaliyet giderlerine yansır. Cezanın büyüklüğünün şirketin özkaynaklarına oranı önemlidir.',
      marketOutlook:
          'Hissede kısa vadeli satış baskısı ve volatilite artışı görülebilir. Piyasa genellikle ceza tutarını hızla fiyatlar.',
      retailInvestorGuidance:
          'Panik satışından önce cezanın şirket kârlılığına oranı değerlendirilmeli; şirketin itiraz süreci beklenmelidir.',
      keyHighlights: [
        if (money != null) 'Ceza Tutarı: $money',
        if (institution != null) 'Ceza Veren Kurum: $institution',
      ],
      watchItems: ['Şirketin iptal davası açma veya erken indirimli ödeme kararı'],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 16. Dava / Hukuki Süreç
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildLawsuit({
    required String company,
    required String cleanText,
    String? money,
    String? institution,
  }) {
    final moneyClause = money != null ? '$money değerinde ' : '';

    return KapCommentaryResult(
      summary:
          '$company devam eden hukuki dava süreci hakkında bilgilendirme yaptı. Mahkeme takvimi ve olası mali sonuçlar takip ediliyor.',
      executiveSummary:
          '$company taraf olduğu ${moneyClause}dava / arabuluculuk süreci ile ilgili mahkeme kararı veya ara karar hakkında açıklamada bulunmuştur.',
      financialImpact:
          'Aleyhe sonuçlanma durumunda tazminat veya karşılık ayrılması riski bulunur. Lehe kararlar ise bilançoda risk primi düşüşü sağlar.',
      marketOutlook:
          'Hukuki süreçlerin uzaması hissede belirsizlik baskısı yaratır.',
      retailInvestorGuidance:
          'Kararın nihai (kesinleşmiş) olup olmadığı veya temyiz aşaması kontrol edilmelidir.',
      keyHighlights: [
        if (money != null) 'Dava Konusu Tutar: $money',
        'Durum: Hukuki yargılama süreci',
      ],
      watchItems: ['Bilirkişi raporları ve üst mahkeme (İstinaf/Yargıtay) takvimi'],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 17. Sözleşme Feshi
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildContractTermination({
    required String company,
    required String cleanText,
    String? institution,
    String? money,
  }) {
    final partyClause = institution != null ? '$institution ile olan ' : '';
    final moneyClause = money != null ? '$money tutarındaki ' : '';

    return KapCommentaryResult(
      summary:
          '$company, $partyClause${moneyClause}sözleşmenin feshedildiğini veya sona erdiğini duyurdu. Gelir projeksiyonlarında aşağı yönlü revizyon gerektirebilecek olumsuz gelişme.',
      executiveSummary:
          '$company, mevcut iş ilişkisinin tarafların mutabakatıyla veya tek taraflı olarak feshedildiğini açıklamıştır. İlgili ciro katkısının sona ermesi anlamına gelmektedir.',
      financialImpact:
          'Hasılat kaybı oluşturur. Şirketin bu kapasiteyi yeni müşterilerle telafi etme hızı kârlılığı belirleyecektir.',
      marketOutlook:
          'Hissede satıcılı açılış ve kısa vadeli değer kaybı riski yüksektir.',
      retailInvestorGuidance:
          'Stop-loss seviyeleri kontrol edilmeli, şirketin yeni müşteri anlaşmaları açıklayıp açıklamayacağı beklenmelidir.',
      keyHighlights: [
        if (money != null) 'Feshedilen Tutar: $money',
        'Risk: Gelir kaybı ve kapasite boşluğu',
      ],
      watchItems: ['Feshin mali tazminat hükümleri ve yeni iş arayışları'],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 18. Üretim Durdurma
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildProductionStop({
    required String company,
    required String cleanText,
    List<String> dates = const [],
  }) {
    final dateClause = dates.isNotEmpty ? '${dates.first} tarihine kadar ' : '';

    return KapCommentaryResult(
      summary:
          '$company tesislerinde ${dateClause}üretim faaliyetlerine geçici ara verildiğini bildirdi. Faaliyet ve ciro kaybı riski taşıyan bildirim.',
      executiveSummary:
          '$company, bakım-onarım, talep daralması veya tedarik sıkıntısı nedeniyle tesislerinde ${dateClause}üretimi geçici durdurma kararı almıştır.',
      financialImpact:
          'Sabit maliyetlerin devam ettiği bir dönemde üretim kaybı operasyonel kâr marjını baskılar.',
      marketOutlook:
          'Hissede kısa vadeli negatif fiyatlama ve satış baskısı oluşturabilir.',
      retailInvestorGuidance:
          'Durdurmanın planlı periyodik bakım mı yoksa arızi bir kriz mi olduğu netleştirilmelidir.',
      keyHighlights: ['Durum: Üretime geçici ara verilmesi'],
      watchItems: ['Yeniden tam kapasite üretime geçiş tarihi'],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 19. Yönetici Değişikliği (CEO / Yönetim Kurulu)
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildExecutiveResignation({
    required String company,
    required String cleanText,
  }) {
    return KapCommentaryResult(
      summary:
          '$company üst yönetiminde (CEO / Genel Müdür / Yönetim Kurulu) görev değişikliği açıkladı. Yeni strateji ve liderlik dönemi.',
      executiveSummary:
          '$company tepe yönetiminde görev değişikliği veya istifa gerçekleştiğini kamuoyu ile paylaşmıştır. Yeni atanan yöneticinin vizyonu şirketin geleceğini şekillendirecektir.',
      financialImpact:
          'Doğrudan finansal bilanço etkisi oluşturmaz; ancak yönetsel verimlilik ve stratejik dönüşüm üzerinde etkilidir.',
      marketOutlook:
          'Piyasa yeni gelen yöneticinin piyasa repütasyonuna göre temkinli veya iyimser fiyatlama yapar.',
      retailInvestorGuidance:
          'Şirketin kurumsal devamlılığı ve yeni yönetimin büyüme hedefleri izlenmelidir.',
      keyHighlights: ['Konu: Üst düzey yönetim değişikliği ve atamalar'],
      watchItems: ['Yeni yönetimin açıklayacağı stratejik hedefler'],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 20. Finansal Rapor (Bilanço)
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildFinancialReport({
    required String company,
    required String cleanText,
    String? money,
  }) {
    return KapCommentaryResult(
      summary:
          '$company dönemsel finansal sonuçlarını (bilanço ve kâr-zarar tablosu) açıkladı. Şirketin kârlılık, ciro ve borçluluk göstergeleri netleşti.',
      executiveSummary:
          '$company ilgili döneme ait finansal tablolarını ve bağımsız denetim raporunu kamuoyuyla paylaşmıştır. Şirketin operasyonel performansı piyasa beklentileriyle test edilecektir.',
      financialImpact:
          'Net kâr, FAVÖK ve hasılat büyümesi hissenin piyasa çarpanlarını (F/K, PD/DD, FD/FAVÖK) yeniden kalibre edecektir.',
      marketOutlook:
          'Beklentileri aşan net kâr güçlü ralli başlatabilirken, beklenti altında kalan sonuçlar kâr realizasyonunu tetikleyebilir.',
      retailInvestorGuidance:
          'Sadece net kâra değil, esas faaliyet kârının kalitesine ve borç yapısındaki değişime de bakılmalıdır.',
      keyHighlights: ['Konu: Çeyreklik Finansal Tablolar ve Bilanço'],
      watchItems: ['Yatırımcı sunumu ve faaliyet raporu dipnotları'],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 21. Kredi Notu / Derecelendirme
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildRatingUpdate({
    required String company,
    required String cleanText,
  }) {
    final isPositive = cleanText.toLowerCase().contains('yüksel') ||
        cleanText.toLowerCase().contains('pozitif');

    return KapCommentaryResult(
      summary:
          '$company hakkında kredi derecelendirme notu ve görünüm güncellemesi açıklandı. ${isPositive ? 'Şirketin kredi itibarını güçlendiren pozitif gelişme.' : 'Kurumsal borçlanma güvenirliğini teyit eden bildirim.'}',
      executiveSummary:
          '$company hakkında uluslararası/ulusal derecelendirme kuruluşu tarafından kredi notu ve görünüm değerlendirmesi yapılmıştır.',
      financialImpact:
          'Yüksek kredi notu şirketin borçlanma maliyetlerini düşürür ve uluslararası fonlara erişimini kolaylaştırır.',
      marketOutlook:
          'Not artışı veya görünümün pozitife çekilmesi hissede kurumsal alıcı ilgisini pekiştirir.',
      retailInvestorGuidance:
          'Finansal sağlığı tescillenen şirketler dalgalı piyasalarda daha güvenli liman sunar.',
      keyHighlights: ['Konu: Kredi Notu ve Görünüm Değerlendirmesi'],
      watchItems: ['Finansman maliyetlerindeki olası indirimler'],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 22. Genel Kurul
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildGeneralAssembly({
    required String company,
    required String cleanText,
    List<String> dates = const [],
  }) {
    final dateClause = dates.isNotEmpty ? '${dates.first} tarihinde ' : '';

    return KapCommentaryResult(
      summary:
          '$company ${dateClause}yapılacak Genel Kurul toplantısına ilişkin gündem ve katılım duyurusu yaptı.',
      executiveSummary:
          '$company olağan/olağanüstü genel kurul toplantısının yer, tarih ve gündem maddelerini açıklamıştır. Temettü ve yönetim kurulu seçimleri gibi kritik kararlar onaylanacaktır.',
      financialImpact:
          'Genel kurulda onaylanacak kâr dağıtımı (temettü) veya sermaye artırımı kararları doğrudan bilanço etkisi yaratacaktır.',
      marketOutlook:
          'Rutin genel kurul çağrısı piyasa üzerinde nötr etki gösterir; gündemdeki sürpriz maddeler fiyatlamayı etkileyebilir.',
      retailInvestorGuidance:
          'Gündemde temettü veya sermaye artırımı olup olmadığı kontrol edilmelidir.',
      keyHighlights: [
        if (dates.isNotEmpty) 'Toplantı Tarihi: ${dates.first}',
        'Tür: Genel Kurul Toplantısı',
      ],
      watchItems: ['Genel kurul toplantı tutanağı ve onaylanan kararlar'],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 23. Genel / Fallback Bildirimler
  // ─────────────────────────────────────────────────────────

  KapCommentaryResult _buildGeneric({
    required String company,
    required String cleanText,
    required KapClassificationResult classification,
    String? money,
    List<String> dates = const [],
  }) {
    final categoryName = classification.categoryName;
    final firstSentence = cleanText.split('.').first;
    final trimmedSentence = firstSentence.length > 120
        ? '${firstSentence.substring(0, 120)}...'
        : firstSentence;

    final summary =
        '$company, $categoryName kapsamında özel durum açıklaması yaptı. ($trimmedSentence)';

    final executiveSummary =
        '$company tarafından Sermaye Piyasası Kurulu düzenlemeleri kapsamında $categoryName bildiriminde bulunulmuştur. '
        'Bildirimin içeriğinde: $trimmedSentence '
        '${money != null ? 'Açıklamada $money tutarında parasal büyüklük belirtilmiştir. ' : ''}'
        '${dates.isNotEmpty ? 'Sürecin ${dates.first} tarihiyle ilişkili olduğu ifade edilmektedir. ' : ''}';

    final financialImpact =
        'Açıklanan gelişmenin şirketin bilanço ve kârlılık göstergelerine olası etkisi takip eden dönem finansal tablolarında somutlaşacaktır.';

    final marketOutlook = classification.effect == KapEffect.positive
        ? 'Bildirim hisse üzerinde genel olarak pozitif beklenti oluşturabilir.'
        : classification.effect == KapEffect.negative
            ? 'Bildirim hisse üzerinde kısa süreli satış baskısı yaratabilir.'
            : 'Hisse fiyatı üzerinde doğrudan belirgin bir dalgalanma beklenmemektedir.';

    final retailInvestorGuidance =
        'Yatırımcıların bildirimin tam metnini ve şirketin ana faaliyet alanıyla ilişkisini göz önünde bulundurarak teknik seviyeler eşliğinde karar vermesi önerilir.';

    return KapCommentaryResult(
      summary: summary,
      executiveSummary: executiveSummary,
      financialImpact: financialImpact,
      marketOutlook: marketOutlook,
      retailInvestorGuidance: retailInvestorGuidance,
      keyHighlights: [
        'Bildirim Türü: $categoryName',
        if (money != null) 'İlgili Tutar: $money',
        if (dates.isNotEmpty) 'Tarih: ${dates.first}',
      ],
      watchItems: ['Gelişmeye ilişkin olası tamamlayıcı açıklamalar'],
    );
  }

  String _clean(String text) {
    return text.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}