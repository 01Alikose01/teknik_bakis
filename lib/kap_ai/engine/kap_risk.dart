import '../data/keyword_database.dart';
import '../models/kap_entities.dart';
import 'kap_classifier.dart';

class KapRiskEngine {
  const KapRiskEngine();

  List<String> generate(
    String text,
    KapClassificationResult classification, {
    KapEntities? entities,
  }) {
    final normalized = text.toLowerCase();
    final risks = <String>[];

    //--------------------------------------------------
    // 1. Kategori Bazlı Riskler
    //--------------------------------------------------

    switch (classification.category) {
      case KapCategory.newBusiness:
        risks.addAll([
          'Hammadde maliyetleri veya tedarik aksaklıkları proje kâr marjını baskılayabilir.',
          'Müşteri onay ve teslimat süreçlerinde takvimsel gecikmeler yaşanabilir.',
        ]);
        break;

      case KapCategory.tender:
        risks.addAll([
          'İhale kararına rakip firmalar tarafından Kamu İhale Kurumu veya yargı nezdinde itiraz edilebilir.',
          'Sözleşmenin resmi imza aşamasına kadar süreçte gecikme riski bulunmaktadır.',
        ]);
        break;

      case KapCategory.export:
        risks.addAll([
          'Hedef pazardaki gümrük tarifeleri, ithalat kotaları ve jeopolitik gelişmeler teslimatları etkileyebilir.',
          'Kur oynaklıkları ve parite değişimleri kâr marjı üzerinde dalgalanma yaratabilir.',
        ]);
        break;

      case KapCategory.solarEnergyGES:
        risks.addAll([
          'Şebeke (TEİAŞ/TEDAŞ) bağlantı ve kabul onay süreçlerinde gecikme yaşanabilir.',
          'Güneşlenme süreleri ve mevsimsel hava koşulları dönemsel elektrik üretimini dalgalandırabilir.',
        ]);
        break;

      case KapCategory.shareBuyback:
        risks.addAll([
          'Geri alım programı piyasa koşullarına bağlı olarak planlanan azami tutara ulaşmadan sonlandırılabilir.',
          'Şirketin alım yapmadığı günlerde hissede kâr realizasyonu görülebilir.',
        ]);
        break;

      case KapCategory.dividend:
        risks.addAll([
          'Temettü hak kullanım gününde hisse fiyatı brüt temettü kadar teknik olarak düşüş gösterir.',
          'Genel kurulda temettü teklifinde veya dağıtım tarihlerinde değişiklik yapılabilir.',
        ]);
        break;

      case KapCategory.rightsIssue:
        risks.addAll([
          'Rüçhan hakkı kullanmayan yatırımcıların şirket sermayesindeki ortaklık payı sulanma (seyrelme) riski taşır.',
          'Rüçhan hakkı kullanım süresince hisse fiyatı üzerinde nakit çıkışı kaynaklı satış baskısı oluşabilir.',
        ]);
        break;

      case KapCategory.bonusIssue:
        risks.addAll([
          'Bedelsiz sermaye artırımı şirkete yeni nakit girişi sağlamaz; tek başına şirket değerini artırmaz.',
          'Haberin yarattığı ilk spekülatif tavan coşkusunun ardından sert kâr satışları görülebilir.',
        ]);
        break;

      case KapCategory.debtIssuance:
        risks.addAll([
          'Mevcut yüksek faiz ortamında tahvilin kupon faiz maliyeti şirketin finansman giderlerini artırabilir.',
          'Vade sonunda anapara geri ödemesi veya refinansman gereksinimi nakit dengesini zorlayabilir.',
        ]);
        break;

      case KapCategory.shareTransaction:
        risks.addAll([
          'Büyük ortakların piyasada pay satışı hisse üzerinde ek arz ve kısa vadeli fiyat baskısı yaratabilir.',
          'Ortaklık payındaki değişimler yönetim kontrol dengelerini etkileyebilir.',
        ]);
        break;

      case KapCategory.penalty:
        risks.addAll([
          'Cezanın nakit ödenmesi dönemsel net kârı ve serbest nakit akışını olumsuz etkiler.',
          'Denetleyici kurum tarafından ilave idari yaptırımlar veya tedbirler getirilebilir.',
        ]);
        break;

      case KapCategory.lawsuit:
        risks.addAll([
          'Yargılama ve istinaf/temyiz süreçleri uzun yıllara yayılabilir ve belirsizlik oluşturabilir.',
          'Aleyhe sonuçlanma ihtimaline binaen bilançoda karşılık ayrılması kârlılığı törpüleyebilir.',
        ]);
        break;

      case KapCategory.bankruptcy:
        risks.addAll([
          'Şirket faaliyetlerinde ve varlık tasfiyesinde kritik belirsizlik bulunmaktadır.',
          'Pay sahipleri açısından sermaye kaybı riski en üst düzeydedir.',
        ]);
        break;

      case KapCategory.concordat:
        risks.addAll([
          'Borç yapılandırması ve alacaklılarla anlaşma süreci planlanandan uzun sürebilir.',
          'Operasyonel nakit akışında ve ticari itibarda daralma devam edebilir.',
        ]);
        break;

      case KapCategory.productionStop:
        risks.addAll([
          'Üretim durdurma süresi uzarsa müşteri ve sipariş kaybı riski doğabilir.',
          'Sabit tesis maliyetleri devam ettiği için çeyreklik brüt kâr marjı zedelenebilir.',
        ]);
        break;

      case KapCategory.contractTermination:
        risks.addAll([
          'Kaybedilen iş hacminin yeni sözleşmelerle telafi edilmesi zaman alabilir.',
          'Feshe bağlı olası tazminat veya cezai şart ihtilafları doğabilir.',
        ]);
        break;

      case KapCategory.executiveResignation:
        risks.addAll([
          'Tepe yönetim değişikliği şirket içi kurumsal geçiş sürecinde kısa süreli belirsizlik yaratabilir.',
        ]);
        break;

      case KapCategory.financialReport:
        risks.addAll([
          'Açıklanan kârlılık veya hasılat piyasa konsensüs beklentilerinin altında kalmış olabilir.',
          'Net borç veya finansman giderlerindeki artış kâr kalitesini gölgeleyebilir.',
        ]);
        break;

      default:
        risks.add(
          'Bildirimin şirket operasyonlarına ve bilançoya nihai yansıması ilerleyen dönemlerde netleşecektir.',
        );
    }

    //--------------------------------------------------
    // 2. Metinden & Verilerden Çıkarılan Dinamik Riskler
    //--------------------------------------------------

    if (entities?.currency != null && entities!.currency != 'TL') {
      risks.add(
        'İşlemin ${entities.currency} bazlı olması sebebiyle kur paritesi ve kur dalgalanması riski taşımaktadır.',
      );
    }

    if (entities?.amountTl != null && entities!.amountTl! >= 500000000) {
      risks.add(
        'Yüksek tutarlı projelerde hakediş tahsilatı, tedarik zinciri ve taahhüt tamamlama riski daha yüksektir.',
      );
    }

    if (normalized.contains('spk') &&
        (normalized.contains('başvuru') || normalized.contains('onayına'))) {
      risks.add(
        'Süreç Sermaye Piyasası Kurulu (SPK) onayına tabidir; onay takviminde gecikmeler yaşanabilir.',
      );
    }

    if (normalized.contains('iptal')) {
      risks.add('Sözleşme veya sürecin tek taraflı iptal edilme riski mevcuttur.');
    }

    if (normalized.contains('fesih')) {
      risks.add('Sözleşmenin sona ermesi ilgili ciro kalemini sonlandırabilir.');
    }

    if (normalized.contains('mahkeme') || normalized.contains('arabuluculuk')) {
      risks.add('Hukuki ihtilaf süreci nihai karar çıkana kadar risk primi oluşturabilir.');
    }

    if (normalized.contains('ceza')) {
      risks.add('İlgili otoritenin idari yaptırımına karşı yasal itiraz süreci takip edilmelidir.');
    }

    // Tekrarları temizle
    return risks.toSet().toList();
  }
}