import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../kap_ai/kap_ai_service.dart';
import '../kap_ai/data/keyword_database.dart';

class NewsDetailScreen extends StatefulWidget {
  final String title;
  final String summary;
  final String source;
  final String time;
  final String url;

  const NewsDetailScreen({
    super.key,
    required this.title,
    required this.summary,
    required this.source,
    required this.time,
    required this.url,
  });

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  String _fullContent = '';
  bool _loading = false;

  bool get _isKap =>
      widget.url.isEmpty ||
      widget.url.contains('kap.org.tr') ||
      RegExp(r'^[A-Z]{3,6}$').hasMatch(widget.source);

  @override
  void initState() {
    super.initState();
    if (widget.url.isNotEmpty) _fetchContent();
  }

  Future<void> _fetchContent() async {
    setState(() => _loading = true);
    try {
      final resp = await http
          .get(Uri.parse(widget.url), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        String text = resp.body;
        final m = RegExp(r'<article[^>]*>([\s\S]*?)<\/article>',
                caseSensitive: false)
            .firstMatch(text);
        if (m != null) text = m.group(1) ?? text;
        text = text
            .replaceAll(RegExp(r'<script[\s\S]*?<\/script>', caseSensitive: false), '')
            .replaceAll(RegExp(r'<style[\s\S]*?<\/style>', caseSensitive: false), '')
            .replaceAll(RegExp(r'<[^>]+>'), ' ')
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (text.length > 200) {
          if (mounted) setState(() { _fullContent = text; _loading = false; });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.source,
            style: const TextStyle(
                color: Color(0xFF34C759),
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _isKap
            ? _KapDetailBody(
                title: widget.title,
                summary: widget.summary,
                source: widget.source,
                time: widget.time,
                fetchedContent: _fullContent,
                loading: _loading,
              )
            : _BorsaDetailBody(
                title: widget.title,
                summary: widget.summary,
                source: widget.source,
                time: widget.time,
                fetchedContent: _fullContent,
                loading: _loading,
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// KAP Bildirimi Detay
// ─────────────────────────────────────────────────────────────

class _KapDetailBody extends StatelessWidget {
  final String title, summary, source, time, fetchedContent;
  final bool loading;

  const _KapDetailBody({
    required this.title,
    required this.summary,
    required this.source,
    required this.time,
    required this.fetchedContent,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final service = KapAiService();
    final rawText = '$title\n$summary';
    final analysis = service.analyze(rawText, symbol: source);
    final effect = analysis.effect;
    final effectColor = effect == KapEffect.positive
        ? const Color(0xFF34C759)
        : effect == KapEffect.negative
            ? const Color(0xFFFF3B30)
            : const Color(0xFFFF9500);
    final effectEmoji = effect == KapEffect.positive
        ? '🟢'
        : effect == KapEffect.negative
            ? '🔴'
            : '🟠';
    final effectLabel = effect == KapEffect.positive
        ? 'Pozitif'
        : effect == KapEffect.negative
            ? 'Negatif'
            : 'Nötr';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kaynak + etki + zaman
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFF1C3A5E),
                borderRadius: BorderRadius.circular(6)),
            child: Text(source,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: effectColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6)),
            child: Text('$effectEmoji $effectLabel',
                style: TextStyle(
                    color: effectColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          const Icon(Icons.access_time, size: 12, color: Colors.grey),
          const SizedBox(width: 3),
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),

        const SizedBox(height: 14),

        Text(title,
            style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.4)),

        const SizedBox(height: 16),

        // Bildiri Hakkında
        _InfoCard(
          icon: '📋',
          title: 'Bildiri Hakkında',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1C3A5E).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(source,
                      style: const TextStyle(
                          color: Color(0xFF1C3A5E),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text('KAP Özel Bildirim',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ]),
              const SizedBox(height: 10),
              Text(_buildBildirimContent(title, summary),
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87, height: 1.7)),
              if (fetchedContent.isNotEmpty &&
                  fetchedContent.length >
                      (summary.isEmpty ? title.length : summary.length) + 50) ...[
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 6),
                const Text('Tam Metin:',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(fetchedContent,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54, height: 1.6)),
              ],
            ],
          ),
        ),

        // Bildirim Türü
        _InfoCard(
          icon: '🏷',
          title: 'Bildirim Türü',
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: effectColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: effectColor.withValues(alpha: 0.3)),
            ),
            child: Text(analysis.categoryName,
                style: TextStyle(
                    color: effectColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ),

        // AI Analizi
        _InfoCard(
          icon: '🤖',
          title: 'AI Analizi',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(analysis.summary,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87, height: 1.6)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Etki Skoru',
                            style: TextStyle(color: Colors.grey, fontSize: 11)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Text(analysis.effectScore,
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: effectColor)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: analysis.score / 100,
                                backgroundColor: Colors.grey[200],
                                valueColor:
                                    AlwaysStoppedAnimation(effectColor),
                                minHeight: 6,
                              ),
                            ),
                          ),
                        ]),
                      ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Önem',
                            style: TextStyle(color: Colors.grey, fontSize: 11)),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < analysis.stars
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: i < analysis.stars
                                  ? const Color(0xFFFFCC00)
                                  : Colors.grey[300],
                              size: 20,
                            ),
                          ),
                        ),
                      ]),
                ),
              ]),
            ],
          ),
        ),

        // Yatırımcı Yorumu
        _InfoCard(
          icon: '👤',
          title: 'Yatırımcı Yorumu',
          child: Text(_investorComment(analysis.effect, analysis.categoryName),
              style: const TextStyle(
                  fontSize: 14, color: Colors.black87, height: 1.6)),
        ),

        // Riskler
        if (analysis.risks.isNotEmpty)
          _InfoCard(
            icon: '⚠️',
            title: 'Dikkat Edilmesi Gerekenler',
            child: Column(
              children: analysis.risks
                  .map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('•  ',
                                  style: TextStyle(
                                      color: Color(0xFFFF9500),
                                      fontSize: 16)),
                              Expanded(
                                  child: Text(r,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                          height: 1.4))),
                            ]),
                      ))
                  .toList(),
            ),
          ),

        // Piyasa Etkisi
        _InfoCard(
          icon: '📌',
          title: 'Piyasa Etkisi',
          child: Text(_marketImpact(analysis.effect),
              style: const TextStyle(
                  fontSize: 14, color: Colors.black87, height: 1.6)),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // İçerik üretici
  String _buildBildirimContent(String title, String summary) {
    final parts = <String>[];
    if (summary.isNotEmpty && summary.length > 15 && summary != title) {
      parts.add(summary);
    }
    final t = title.toLowerCase();
    if (t.contains('borçlanma') || t.contains('tahvil') ||
        t.contains('ihraç') || t.contains('bono')) {
      if (parts.isEmpty) parts.add(title);
      parts.add('Şirket, sermaye piyasası mevzuatı kapsamında borçlanma aracı '
          'ihraç etme kararı almıştır. İhraç işlemi Sermaye Piyasası Kurulu '
          'onayına tabidir ve belirlenen limitler dahilinde gerçekleştirilecektir.');
    } else if (t.contains('temettü') || t.contains('kâr payı') ||
        t.contains('kar payı') || t.contains('dağıtım')) {
      if (parts.isEmpty) parts.add(title);
      parts.add('Şirket yönetim kurulu, genel kurul onayına sunulmak üzere kâr '
          'payı dağıtım teklifini hazırlamıştır. Temettü ödemesi belirtilen '
          'tarihlerde hak sahiplerine yapılacaktır.');
    } else if (t.contains('sermaye artırımı') || t.contains('bedelli') ||
        t.contains('bedelsiz') || t.contains('rüçhan')) {
      if (parts.isEmpty) parts.add(title);
      parts.add('Sermaye artırımına ilişkin belgeler SPK\'ya iletilmiştir. '
          'Süreç tamamlandığında mevcut ortaklar rüçhan haklarını kullanarak '
          'yeni hisseleri belirlenen fiyattan satın alabileceklerdir.');
    } else if (t.contains('istifa') || t.contains('yönetim kurulu') ||
        t.contains('genel müdür') || t.contains('atama')) {
      if (parts.isEmpty) parts.add(title);
      parts.add('Şirket üst yönetiminde gerçekleşen değişiklik, KAP aracılığıyla '
          'kamuoyuyla paylaşılmıştır. Yeni atamalar TTK ve SPK mevzuatı '
          'çerçevesinde gerçekleştirilmiştir.');
    } else if (t.contains('finansal') || t.contains('bilanço') ||
        t.contains('faaliyet') || t.contains('gelir tablosu')) {
      if (parts.isEmpty) parts.add(title);
      parts.add('Şirket dönemsel finansal tablolarını TFRS çerçevesinde '
          'hazırlayarak KAP\'ta ilan etmiştir. Bağımsız denetim görüşü ve '
          'dipnotların tamamına kap.org.tr üzerinden erişilebilir.');
    } else if (t.contains('genel kurul')) {
      if (parts.isEmpty) parts.add(title);
      parts.add('Genel Kurul toplantısına ilişkin gündem ve katılım esasları '
          'SPK düzenlemeleri çerçevesinde belirlenmiştir. Pay sahipleri '
          'fiziki veya elektronik ortamda toplantıya katılabilirler.');
    } else if (t.contains('sözleşme') || t.contains('ihale') ||
        t.contains('iş ilişkisi') || t.contains('anlaşma')) {
      if (parts.isEmpty) parts.add(title);
      parts.add('Söz konusu anlaşma şirketin ticari faaliyetleri kapsamında '
          'gerçekleştirilmiş olup maddi önemi nedeniyle kamuoyuyla '
          'paylaşılmıştır.');
    } else if (t.contains('ceza') || t.contains('yaptırım') ||
        t.contains('spk') || t.contains('bddk')) {
      if (parts.isEmpty) parts.add(title);
      parts.add('Yetkili kurum tarafından uygulanan idari yaptırım ilgili mevzuat '
          'kapsamında değerlendirilmektedir. Şirket karara itiraz hakkını '
          'saklı tutmaktadır.');
    } else {
      if (parts.isEmpty) parts.add(title);
      if (summary.isEmpty || summary == title) {
        parts.add('Şirket tarafından yapılan bu özel durum açıklaması, '
            'SPK\'nın sürekli bilgilendirme yükümlülükleri kapsamında '
            'kamuoyuyla paylaşılmıştır. Bildirimin tam metnine '
            'kap.org.tr adresinden ulaşabilirsiniz.');
      }
    }
    return parts.join('\n\n');
  }

  String _investorComment(KapEffect effect, String category) {
    switch (effect) {
      case KapEffect.positive:
        return '$category haberi, şirket için olumlu bir gelişmeye işaret '
            'etmektedir. Bu tür haberler hisse senedinde kısa vadeli yukarı '
            'yönlü baskı oluşturabilir. Teknik seviyeleri ve genel piyasa '
            'koşullarını inceleyerek karar vermek önerilir.';
      case KapEffect.negative:
        return '$category haberi, hisse üzerinde satış baskısı '
            'oluşturabilecek bir gelişmedir. Kısa vadeli pozisyon taşıyanların '
            'stop-loss seviyelerini gözden geçirmesi önerilir. Uzun vadeli '
            'yatırımcılar temel analiz çerçevesinde değerlendirmelidir.';
      case KapEffect.neutral:
        return '$category haberi, hisse fiyatı üzerinde doğrudan belirgin '
            'bir etki oluşturması beklenmiyor. Şirketi yakından takip eden '
            'yatırımcılar için bilgilendirici niteliktedir.';
    }
  }

  String _marketImpact(KapEffect effect) {
    switch (effect) {
      case KapEffect.positive:
        return 'Olumlu KAP bildirimleri genellikle açılış seansında fiyata yansır.\n\n'
            '• Piyasa saatlerinde yayınlandıysa anında tepki görülebilir.\n'
            '• Piyasa kapalıyken gelen haberler ertesi gün açılışa yansır; '
            'gap-up (boşluklu açılış) oluşabilir.\n'
            '• Normalin 3-5 katı hacim, kurumsal ilginin işaretidir.\n'
            '• İlk tepki sonrası destek seviyesini koruması, trendin devamını '
            'işaret eder.';
      case KapEffect.negative:
        return 'Olumsuz KAP bildirimleri sert satış dalgalarına yol açabilir.\n\n'
            '• Açılışta devre kesici (taban) devreye girebilir.\n'
            '• İlk tepki genellikle aşırı olur; birkaç seans sonra kısmi '
            'toparlanma görülebilir.\n'
            '• Stop-loss seviyelerinizi gözden geçirin.\n'
            '• Temel hasar mı yoksa geçici baskı mı olduğunu analiz edin.';
      case KapEffect.neutral:
        return 'Nötr bildirimler fiyat üzerinde belirgin baskı oluşturmaz.\n\n'
            '• Rutin finansal tablolar ve faaliyet raporları genellikle '
            'fiyatı hareket ettirmez.\n'
            '• İçerdiği veriler beklentilerden önemli ölçüde sapıyorsa '
            'sürpriz etki yaratabilir.\n'
            '• Genel kurul ve ana sözleşme değişikliklerinin doğrudan '
            'fiyat etkisi sınırlıdır.';
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Borsa Haberleri Detay
// ─────────────────────────────────────────────────────────────

class _BorsaDetailBody extends StatelessWidget {
  final String title, summary, source, time, fetchedContent;
  final bool loading;

  const _BorsaDetailBody({
    required this.title,
    required this.summary,
    required this.source,
    required this.time,
    required this.fetchedContent,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFF34C759).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6)),
            child: Text(source,
                style: const TextStyle(
                    color: Color(0xFF34C759),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          const Icon(Icons.access_time, size: 12, color: Colors.grey),
          const SizedBox(width: 3),
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),

        const SizedBox(height: 14),

        Text(title,
            style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.4)),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),

        if (loading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                      color: Color(0xFF34C759))))
        else ...[
          if (summary.isNotEmpty)
            _InfoCard(
              icon: '📰',
              title: 'Haber Özeti',
              child: Text(summary,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87, height: 1.7)),
            ),
          if (fetchedContent.isNotEmpty && fetchedContent != summary)
            _InfoCard(
              icon: '📄',
              title: 'Haberin Tamamı',
              child: Text(fetchedContent,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87, height: 1.7)),
            ),
          _InfoCard(
            icon: '📊',
            title: 'Piyasa Bağlamı',
            child: Text(_marketContext(title, summary),
                style: const TextStyle(
                    fontSize: 14, color: Colors.black87, height: 1.6)),
          ),
          _InfoCard(
            icon: '💡',
            title: 'Yatırımcı Notu',
            child: Text(_investorNote(title, summary),
                style: const TextStyle(
                    fontSize: 14, color: Colors.black87, height: 1.6)),
          ),
          _InfoCard(
            icon: '🔍',
            title: 'Takip Edilecek Göstergeler',
            child: Column(
              children: _watchItems(title, summary)
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('→  ',
                                  style: TextStyle(
                                      color: Color(0xFF34C759),
                                      fontSize: 14)),
                              Expanded(
                                  child: Text(item,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                          height: 1.4))),
                            ]),
                      ))
                  .toList(),
            ),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  String _marketContext(String title, String summary) {
    final t = '$title $summary'.toLowerCase();
    if (t.contains('faiz') || t.contains('tcmb')) {
      return 'Faiz kararları borsada özellikle banka hisselerini ve sabit getirili '
          'varlıkları doğrudan etkiler. Faiz artışında mevduat cazip hale '
          'gelerek hisse senedinden çıkış hızlanabilir; indirimde ise borsa '
          'için olumlu ortam oluşur.';
    }
    if (t.contains('dolar') || t.contains('kur') || t.contains('döviz')) {
      return 'Döviz kurundaki hareketler ihracatçı şirketleri olumlu, ithalatçıları '
          'olumsuz etkiler. Yüksek dolar savunma, havacılık ve hammadde '
          'ihracatçısı firmalara fayda sağlarken; ithalata bağımlı sektörlerde '
          'maliyet baskısı oluşturur.';
    }
    if (t.contains('altın')) {
      return 'Altın fiyatları küresel risk iştahı ve enflasyon beklentileriyle '
          'ilişkilidir. Türkiye\'de gram altın hem ONS altın hem de USD/TRY '
          'paritesinden etkilenir.';
    }
    if (t.contains('bist') || t.contains('endeks') || t.contains('borsa')) {
      return 'BIST 100 endeksi; yabancı sermaye akışları, döviz kuru, enflasyon '
          've küresel risk iştahıyla bağlantılıdır. Güçlü hareketler genellikle '
          'bankacılık ve holding hisselerinin öncülüğünde gerçekleşir.';
    }
    return 'Bu gelişme genel piyasa koşulları ve makroekonomik göstergelerle '
        'birlikte değerlendirilmelidir. Teknik analiz desteği riski yönetmek '
        'açısından önemlidir.';
  }

  String _investorNote(String title, String summary) {
    final t = '$title $summary'.toLowerCase();
    if (t.contains('yüksel') || t.contains('artı') || t.contains('pozitif')) {
      return 'Yükseliş döneminde momentum stratejileri ön plana çıkar. Ancak '
          'aşırı alım bölgesindeki hisseler için kâr realizasyonu riski '
          'göz ardı edilmemelidir. RSI ve hacim göstergelerini birlikte takip edin.';
    }
    if (t.contains('düş') || t.contains('geril') || t.contains('satış')) {
      return 'Düşüş dönemlerinde aceleci davranmak zararlı olabilir. Güçlü '
          'temel değerlere sahip hisselerde fiyat gerilemeler orta vadeli '
          'alım fırsatı sunabilir.';
    }
    return 'Piyasalar kısa vadede haber akışına duyarlı olsa da uzun vadede '
        'şirket temelleri belirleyicidir. Portföy çeşitlendirmesi ve disiplinli '
        'risk yönetimi önemini korur.';
  }

  List<String> _watchItems(String title, String summary) {
    final t = '$title $summary'.toLowerCase();
    final items = <String>[];
    if (t.contains('faiz') || t.contains('tcmb')) {
      items.addAll(['TCMB PPK toplantı tarihleri', 'Enflasyon (TÜFE/ÜFE)', 'Tahvil getirileri']);
    }
    if (t.contains('dolar') || t.contains('kur')) {
      items.addAll(['USD/TRY hareketi', 'TCMB rezervleri', 'Cari açık']);
    }
    if (t.contains('bist') || t.contains('endeks')) {
      items.addAll(['BIST 100 kapanış', 'Yabancı yatırımcı verileri', 'XBANK performansı']);
    }
    if (t.contains('altın')) {
      items.addAll(['ONS altın USD', 'USD/TRY kuru', 'Gram altın TL']);
    }
    if (items.isEmpty) {
      items.addAll(['Sektör endeksi performansı', 'Yabancı sermaye akışları', 'Hacim/volatilite']);
    }
    return items;
  }
}

// ─────────────────────────────────────────────
// Ortak kart widget
// ─────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String icon;
  final String title;
  final Widget child;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black87)),
          ]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
