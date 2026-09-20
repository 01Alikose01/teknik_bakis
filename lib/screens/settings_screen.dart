import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/settings_service.dart';
import '../services/subscription_service.dart';
import 'payment_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onUpgrade;
  const SettingsScreen({super.key, this.onUpgrade});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceSecondary = onSurface.withValues(alpha: 0.75);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık + profil görseli
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ayarlar',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: onSurface)),
                  const SizedBox(height: 16),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image.asset(
                        'assets/tek.png',
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text('Teknik Bakış',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: onSurface)),
                  ),
                  Center(
                    child: Text('v1.0.0',
                        style: TextStyle(color: onSurfaceSecondary, fontSize: 13)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // ── Premium Durum Kartı ──────────────────────────────
                  _PremiumStatusCard(onUpgrade: widget.onUpgrade),
                  const SizedBox(height: 20),

                  _SectionLabel('Görünüm'),
                  ValueListenableBuilder<bool>(
                    valueListenable: SettingsService.darkMode,
                    builder: (context, isDark, _) {
                      return _SettingsGroup(items: [
                        _SettingsItem(
                          title: isDark ? 'Gece Modu' : 'Gündüz Modu',
                          leadingIcon: Icons.brightness_6_outlined,
                          leadingColor: const Color(0xFF34C759),
                          trailing: Switch(
                            value: isDark,
                            activeThumbColor: const Color(0xFF34C759),
                            onChanged: (value) async {
                              await SettingsService.setDarkMode(value);
                              setState(() {});
                            },
                          ),
                          onTap: () async {
                            await SettingsService.setDarkMode(!isDark);
                            setState(() {});
                          },
                        ),
                      ]);
                    },
                  ),

                  const SizedBox(height: 20),
                  _SectionLabel('Hakkında'),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      title: 'Uygulama Hakkında',
                      onTap: () => _showAbout(context),
                    ),
                    _SettingsItem(
                      title: 'Sürüm',
                      trailing: const Text('1.0.0', style: TextStyle(color: Colors.grey)),
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _SectionLabel('Bildirimler'),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      title: 'Bildirim İzinlerini Yönet',
                      leadingIcon: Icons.notifications_outlined,
                      leadingColor: const Color(0xFF34C759),
                      trailingIcon: Icons.open_in_new,
                      onTap: () async {
                        try {
                          if (Platform.isAndroid) {
                            const channel = MethodChannel('com.teknikbakis/settings');
                            await channel.invokeMethod('openNotificationSettings');
                          } else if (Platform.isIOS) {
                            // iOS: uygulama ayarlarına yönlendir
                            const channel = MethodChannel('com.teknikbakis/settings');
                            await channel.invokeMethod('openNotificationSettings');
                          }
                        } catch (_) {
                          // Hata durumunda sessizce devam et
                        }
                      },
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _SectionLabel('Yardım & Destek'),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      title: 'SSS',
                      onTap: () => _showSss(context),
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _SectionLabel('Teknik Bakış Partneri'),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      title: 'Partnerlik Programı',
                      onTap: () {},
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _SectionLabel('Abonelik'),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      title: 'Planları Görüntüle',
                      onTap: () => _showPlansSheet(context),
                    ),
                    _SettingsItem(
                      title: 'Yasal Uyarı',
                      onTap: () => _showLegal(context),
                    ),
                  ]),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Teknik Bakış Hakkında'),
        content: const Text(
            'Teknik Bakış, BIST hisselerini teknik analiz göstergeleriyle tarayan ve yatırım kararlarınızı destekleyen bir mobil uygulamadır.\n\n'
            'Sürüm: 1.0.0\n'
            'Bu uygulama yatırım tavsiyesi niteliği taşımaz.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))],
      ),
    );
  }

  void _showSss(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Column(
          children: [
            // Tutamaç çubuğu
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Sık Sorulan Sorular',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: const [

                  // ── Veriler & Fiyatlar ──────────────────────────────
                  _FaqSection(title: '📊 Veriler & Fiyatlar'),
                  _FaqItem(
                    q: 'Fiyat verileri ne kadar güncel?',
                    a: 'Veriler Yahoo Finance üzerinden çekilmektedir. Borsa saatleri içinde yaklaşık 15 dakika gecikme söz konusudur. Bu standart bir borsa veri gecikmesidir; anlık (0 gecikme) veri için borsa ekranları kullanılmalıdır.',
                  ),
                  _FaqItem(
                    q: 'Sayfa açıldığında fiyatlar neden bazen gelmez?',
                    a: 'İnternet bağlantınız yavaş veya kararsız olduğunda veri yüklenemeyebilir. Sayfayı aşağı kaydırarak yenilemeyi deneyin. Sorun devam ederse Wi-Fi bağlantısını kontrol edin.',
                  ),
                  _FaqItem(
                    q: 'Veriler doğru mu? Farklı platformlarla uyuşmuyor.',
                    a: 'Veriler Yahoo Finance kaynağından gelir. Küçük farklar veri sağlayıcısının güncelleme sıklığına ve kullandığı hesaplama yöntemine bağlıdır. Kesin işlemler için aracı kurumunuzu esas alın.',
                  ),
                  _FaqItem(
                    q: 'Hafta sonu ve tatil günlerinde veri neden gelmiyor?',
                    a: 'Borsa işlem günlerinde (Pazartesi–Cuma, 10:00–18:00) veri güncellenir. Tatil ve hafta sonu günlerinde en son kapanış fiyatı görünür.',
                  ),
                  _FaqItem(
                    q: 'Altın, dolar ve euro verileri nereden geliyor?',
                    a: 'Gram altın, dolar/TL ve euro/TL verileri de Yahoo Finance üzerinden anlık kur bilgisiyle hesaplanarak sunulmaktadır.',
                  ),

                  // ── Radar & Tarama ──────────────────────────────────
                  _FaqSection(title: '🔍 Radar & Tarama'),
                  _FaqItem(
                    q: 'Tarama (Radar) nasıl çalışır?',
                    a: 'Tarama ekranı BIST hisselerini seçtiğiniz teknik gösterge kriterine göre filtreler. Örneğin "RSI Aşırı Satım" filtresi RSI değeri 30\'un altına düşmüş hisseleri listeler. Sonuçlar anlık değil, en son kapanış verisine göre hesaplanır.',
                  ),
                  _FaqItem(
                    q: 'Ücretsiz planda kaç tarama filtresi kullanabilirim?',
                    a: 'Ücretsiz planda temel filtreler açıktır. RSI, hacim ve EMA gibi gelişmiş filtreler Premium\'a özeldir. Planlar ekranından hangi filtrelerin Premium olduğunu görebilirsiniz.',
                  ),
                  _FaqItem(
                    q: 'Tarama sonuçları otomatik güncelleniyor mu?',
                    a: 'Hayır. Sayfayı açtığınızda ya da sayfayı aşağı sürükleyerek yenilediğinizde en güncel veriye göre hesaplanır.',
                  ),

                  // ── Analiz & Grafikler ──────────────────────────────
                  _FaqSection(title: '📈 Analiz & Grafikler'),
                  _FaqItem(
                    q: 'RSI nasıl hesaplanır?',
                    a: 'Wilder\'ın Smoothed RSI yöntemi kullanılır (14 periyot). RSI 30\'un altı aşırı satım, 70\'in üstü aşırı alım bölgesi olarak kabul edilir.',
                  ),
                  _FaqItem(
                    q: 'EMA 20 ve EMA 50 ne anlama gelir?',
                    a: 'EMA (Üssel Hareketli Ortalama), son fiyatlara daha fazla ağırlık veren bir ortalamadır. EMA 20 kısa vadeli, EMA 50 orta vadeli trendi gösterir. Fiyatın bu ortalamaların üzerinde olması yükseliş eğilimine işaret eder.',
                  ),
                  _FaqItem(
                    q: 'Supertrend göstergesi nedir?',
                    a: 'Supertrend, ATR tabanlı bir trend takip göstergesidir. Yeşil çizgi al sinyali (yükseliş trendi), kırmızı çizgi sat sinyali (düşüş trendi) anlamına gelir. Trend dönüşlerini işaret eder.',
                  ),
                  _FaqItem(
                    q: 'MACD ne işe yarar?',
                    a: 'MACD (12, 26, 9 parametreli) momentum ve trend değişimlerini ölçer. MACD çizgisi sinyal çizgisini yukarı keserse alım, aşağı keserse satım sinyali olarak yorumlanabilir.',
                  ),
                  _FaqItem(
                    q: 'TradingView grafiğini nasıl açabilirim?',
                    a: 'Analiz ekranında bir hisseyi seçtikten sonra grafik alanının hemen altındaki "TradingView\'da Aç" butonuna tıklayın. TradingView\'ın tam özellikli grafiği açılır; yatay moda geçerek daha geniş görünüm elde edebilirsiniz.',
                  ),
                  _FaqItem(
                    q: 'Grafik verileri neden gecikmeli görünüyor?',
                    a: 'Uygulama içindeki fl_chart grafikleri, Yahoo Finance\'dan çekilen günlük kapanış verilerini kullanır. Gün içi anlık (tick) grafik için TradingView\'da Aç özelliğini kullanın.',
                  ),

                  // ── Portföy ─────────────────────────────────────────
                  _FaqSection(title: '💼 Portföy'),
                  _FaqItem(
                    q: 'Portföye hisse nasıl eklerim?',
                    a: 'Portföy ekranında sağ alttaki + butonuna basın. Hisse adını veya kodunu aratın, alış fiyatı ve adeti girin, ardından "Portföye Ekle"ye dokunun.',
                  ),
                  _FaqItem(
                    q: 'Portföy verileri nerede saklanıyor? Telefonu değiştirirsem silinir mi?',
                    a: 'Portföy verileri şu an cihazınızda yerel olarak saklanmaktadır. Telefon değişikliği veya uygulamanın silinmesi durumunda veriler kaybolabilir. Düzenli olarak not almanızı öneririz.',
                  ),
                  _FaqItem(
                    q: 'Kar/zarar hesabı nasıl yapılıyor?',
                    a: 'Kar/Zarar = (Anlık Fiyat − Alış Fiyatı) × Adet olarak hesaplanır. Komisyon ve vergiler dahil edilmez; yalnızca fiyat farkı esas alınır.',
                  ),
                  _FaqItem(
                    q: 'Aynı hisseyi farklı fiyatlardan birden fazla kez ekleyebilir miyim?',
                    a: 'Evet. Her alımı ayrı ayrı ekleyebilirsiniz. Uygulama, tüm alımlarınızı gruplayarak ortalama maliyet ve toplam kar/zarar hesaplar.',
                  ),

                  // ── Takip Listesi & Alarmlar ─────────────────────────
                  _FaqSection(title: '🔔 Takip Listesi & Alarmlar'),
                  _FaqItem(
                    q: 'Takip listesi ile portföy arasındaki fark nedir?',
                    a: 'Takip listesi (Watchlist) sadece fiyat izlemek için kullanılır; alım/satım bilgisi girmezsiniz. Portföy ise gerçek pozisyonlarınızı, alış maliyetinizi ve kar/zararınızı takip eder.',
                  ),
                  _FaqItem(
                    q: 'Fiyat alarmı nasıl kurarım?',
                    a: 'Takip Listesi ekranında bir hissenin üzerine tıklayın ve zil ikonuna basın. Hedef fiyatı ve alarm türünü (alış / satış) seçip kaydedin. Fiyat bu seviyeye geldiğinde bildirim alırsınız.',
                  ),
                  _FaqItem(
                    q: 'Alarm bildirimi almak için ne yapmalıyım?',
                    a: 'Telefonunuzun bildirim ayarlarından "Teknik Bakış" uygulamasına izin vermeniz gerekir. Ayarlar > Bildirim İzinlerini Yönet yolunu izleyerek kontrol edebilirsiniz.',
                  ),
                  _FaqItem(
                    q: 'Ücretsiz planda kaç alarm kurabilirim?',
                    a: 'Ücretsiz planda en fazla 3 aktif fiyat alarmı kurabilirsiniz. Sınırsız alarm için Premium\'a geçebilirsiniz.',
                  ),
                  _FaqItem(
                    q: 'Alarm kurdum ama bildirim gelmiyor.',
                    a: 'Şu kontrolleri yapın: 1) Telefonun bildirim izinlerinde uygulama izinli mi? 2) Güç tasarrufu modu arka plan uygulamalarını kısıtlıyor mu? 3) Telefon "Rahatsız Etme" modunda mı? 4) Uygulama tamamen kapatılmışsa arka planda çalışmıyor olabilir.',
                  ),

                  // ── Haberler & KAP ──────────────────────────────────
                  _FaqSection(title: '📰 Haberler & KAP'),
                  _FaqItem(
                    q: 'Haberler nereden geliyor?',
                    a: 'Haberler KAP (Kamuyu Aydınlatma Platformu) ve çeşitli finans haber kaynaklarından otomatik olarak derlenmektedir.',
                  ),
                  _FaqItem(
                    q: 'KAP AI analizi nedir?',
                    a: 'KAP bildirimleri; sermaye artırımı, temettü, yönetim değişikliği gibi kategorilere ayrılarak otomatik olarak yorumlanır. Bu yorum yatırım tavsiyesi değildir, sadece haberin ne hakkında olduğunu özetler.',
                  ),
                  _FaqItem(
                    q: 'Belirli bir hissenin haberlerini nasıl görebilirim?',
                    a: 'Analiz ekranında hisseyi seçtikten sonra "Haberler" sekmesine geçin. O hisseye ait son haberler listelenir.',
                  ),

                  // ── Halka Arz ────────────────────────────────────────
                  _FaqSection(title: '🚀 Halka Arz'),
                  _FaqItem(
                    q: 'Halka arz takip ekranı ne işe yarar?',
                    a: 'Yaklaşan ve güncel BIST halka arzlarını listeler. Talep tarihi, tahmini fiyat aralığı ve şirket bilgisi gibi detayları görebilirsiniz.',
                  ),
                  _FaqItem(
                    q: 'Halka arz bildirimi alabilir miyim?',
                    a: 'Evet, Premium planda halka arz alarmı kurabilirsiniz. Yeni bir halka arz duyurulduğunda veya talep tarihi yaklaştığında bildirim gelir.',
                  ),

                  // ── Premium & Abonelik ────────────────────────────────
                  _FaqSection(title: '👑 Premium & Abonelik'),
                  _FaqItem(
                    q: '10 günlük deneme süresi nasıl başlar?',
                    a: 'Uygulamayı ilk açışınızda onboarding ekranında "Ücretsiz Dene" seçeneğini seçtiğinizde 10 günlük deneme otomatik başlar. Bu sürede tüm Premium özelliklere erişebilirsiniz.',
                  ),
                  _FaqItem(
                    q: 'Deneme süresinde kart bilgisi isteniyor mu?',
                    a: 'Hayır. 10 günlük deneme süresinde herhangi bir kart bilgisi alınmaz ve 1 kuruş bile çekilmez.',
                  ),
                  _FaqItem(
                    q: 'Premium aboneliği nasıl iptal edebilirim?',
                    a: 'Aboneliğinizi Google Play Store üzerinden "Aboneliklerim" bölümünden istediğiniz zaman iptal edebilirsiniz. İptal sonrası mevcut dönemin sonuna kadar Premium erişiminiz devam eder.',
                  ),
                  _FaqItem(
                    q: 'Aylık ve yıllık plan arasındaki fark nedir?',
                    a: 'Yıllık plan aylık plana göre yaklaşık %30 daha ucuzdur (aylık yaklaşık ₺208\'e denk gelir). Her iki plan da aynı Premium özellikleri sunar; fark yalnızca fiyat ve ödeme sıklığındadır.',
                  ),
                  _FaqItem(
                    q: 'Deneme sürem bitti, ücretsiz kullanmaya devam edebilir miyim?',
                    a: 'Evet. Ücretsiz planda temel ekranlar, sınırlı tarama ve portföy özellikleri kullanılabilir. Premium özellikler (sınırsız alarm, gelişmiş tarama filtreleri, KAP AI vb.) kilitli kalır.',
                  ),

                  // ── Teknik & Diğer ──────────────────────────────────
                  _FaqSection(title: '⚙️ Teknik & Diğer'),
                  _FaqItem(
                    q: 'Uygulama hangi platformlarda çalışıyor?',
                    a: 'Teknik Bakış Android ve iOS platformlarında kullanılabilir.',
                  ),
                  _FaqItem(
                    q: 'Gece modunu nasıl açabilirim?',
                    a: 'Ayarlar ekranından "Gece Modu" anahtarını açabilirsiniz. Değişiklik anında uygulanır.',
                  ),
                  _FaqItem(
                    q: 'Uygulamayı yeniden yüklersem verilerim silinir mi?',
                    a: 'Portföy ve takip listesi gibi yerel veriler, uygulamayı kaldırırsanız silinir. Uygulama güncellemelerinde veriler korunur.',
                  ),
                  _FaqItem(
                    q: 'Bu uygulama yatırım tavsiyesi veriyor mu?',
                    a: 'Hayır. Teknik Bakış yalnızca bilgi ve analiz aracıdır. Gösterilen sinyaller, grafikler ve haberler yatırım tavsiyesi niteliği taşımaz. Tüm yatırım kararlarınızın sorumluluğu size aittir.',
                  ),
                  _FaqItem(
                    q: 'Bir hata veya öneri bildirmek istiyorum.',
                    a: 'Google Play Store\'daki değerlendirme bölümünden veya uygulama içi geri bildirim yoluyla bize ulaşabilirsiniz. Her türlü geri bildiriminiz uygulamamızı geliştirmemize yardımcı olur.',
                  ),

                  SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlansSheet(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Planlar & Özellikler',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Hangi plan size uygun?',
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13),
                ),
              ),
                const SizedBox(height: 24),

                // ── Aylık Plan ──────────────────────────────────────────
                _PlanDetailCard(
                  emoji: '📅',
                  title: 'Aylık Plan',
                  price: '₺299',
                  period: '/ay',
                  badge: SubscriptionService.plan == 'monthly' ? 'SEÇİLİ' : null,
                  badgeColor: SubscriptionService.plan == 'monthly' ? const Color(0xFF34C759) : null,
                  note: 'Taahhütsüz • İstediğin zaman iptal',
                  trialNote: '🎁 İlk 10 gün ücretsiz',
                  trialUsed: SubscriptionService.isExpiredGuest,
                  accent: const Color(0xFF34C759),
                  features: const [
                    '✅ Sınırsız Radar Taraması',
                    '✅ SAT SİNYAL ve AL SİNYAL Özelliği',
                    '✅ AI KAP Analizi',
                    '✅ Sınırsız Fiyat Alarmı',
                    '✅ Tüm Teknik Formasyonlar',
                    '✅ Halka Arz Takibi & Alarmı',
                    '✅ Haberler & KAP Bildirimleri',
                    '✅ Anlık Push Bildirimleri',
                    '✅ Backtesting Test Et',
                  ],
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PaymentScreen(
                          plan: 'monthly',
                          nextScreen: MainNavigation(),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // ── Yıllık Plan ──────────────────────────────────────────
                _PlanDetailCard(
                  emoji: '🏆',
                  title: 'Yıllık Plan',
                  price: '₺2499',
                  period: '/yıl',
                  badge: SubscriptionService.plan == 'yearly' ? 'SEÇİLİ' : '%30 İNDİRİM',
                  badgeColor: SubscriptionService.plan == 'yearly' ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                  note: 'Ayda sadece ₺208 • En avantajlı',
                  trialNote: '🎁 İlk 10 gün ücretsiz',
                  trialUsed: SubscriptionService.isExpiredGuest,
                  accent: const Color(0xFFFF9500),
                  features: const [
                    '✅ Aylık plandaki her şey',
                    '✅ %30 daha ucuz',
                    '✅ Yıllık öncelikli destek',
                  ],
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PaymentScreen(
                          plan: 'yearly',
                          nextScreen: MainNavigation(),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // ── Ücretsiz Kullanım ─────────────────────────────────────
                Builder(builder: (context) {
                  final isCurrentlyFree = SubscriptionService.isFreePlanSelected ||
                      SubscriptionService.isExpiredGuest;
                  return Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrentlyFree
                            ? const Color(0xFF007AFF)
                            : const Color(0xFF007AFF).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.08),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                          ),
                          child: Row(
                            children: [
                              const Text('🆓', style: TextStyle(fontSize: 22)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ücretsiz Plan',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF007AFF),
                                      ),
                                    ),
                                    Text(
                                      'Temel kullanım • Premium olmayan alanlar',
                                      style: TextStyle(
                                        color: const Color(0xFF007AFF).withValues(alpha: 0.75),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // "Kullanımda" rozeti
                              if (isCurrentlyFree)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF007AFF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Kullanımda',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _FreePlanListItem(text: '✅ Temel ekran ve pano erişimi'),
                              const _FreePlanListItem(text: '✅ Sınırlı radar ve analiz özelliği'),
                              const _FreePlanListItem(text: '✅ Halka arz listesi ve temel takibi'),
                              const _FreePlanListItem(text: '⚠️ Premium özellikler kilitli kalır'),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              // Zaten ücretsiz plandaysa buton devre dışı
                              onPressed: isCurrentlyFree ? null : () async {
                                await SubscriptionService.selectFreePlan();
                                setState(() {});
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Ücretsiz plana geçildi.'),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007AFF),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.35),
                                disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Ücretsiz Plan Keşfet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),

                // Yasal not
                const Text(
                  '* 10 günlük deneme süresinde kart bilgisi alınmaz, 1₺ bile çekilmez. '
                  'Deneme bitmeden iptal ederseniz hiçbir ücret ödenmez.',
                  style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

  void _showLegal(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yasal Uyarı'),
        content: const Text(
            'Bu uygulama yalnızca bilgilendirme amaçlıdır. Yatırım tavsiyesi niteliği taşımaz. '
            'Yatırım kararlarınızdan doğan her türlü sonuç kullanıcıya aittir.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anladım'))],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final onSurfaceSecondary = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(color: onSurfaceSecondary, fontSize: 13)),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<_SettingsItem> items;
  const _SettingsGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: theme.brightness == Brightness.light ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return Column(
            children: [
              item,
              if (i < items.length - 1)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final IconData? leadingIcon;
  final Color? leadingColor;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.title,
    this.trailing,
    this.leadingIcon,
    this.leadingColor,
    this.trailingIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: leadingIcon != null
          ? Icon(leadingIcon, color: leadingColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.65), size: 20)
          : null,
      title: Text(title, style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface)),
      trailing: trailing ??
          (onTap != null
              ? Icon(trailingIcon ?? Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.65), size: 20)
              : null),
    );
  }
}

class _FaqSection extends StatelessWidget {
  final String title;
  const _FaqSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String q, a;
  const _FaqItem({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceSecondary = onSurface.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Q  ', style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                )),
                Expanded(
                  child: Text(q, style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: onSurface,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('A  ', style: TextStyle(
                  color: onSurfaceSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                )),
                Expanded(
                  child: Text(a, style: TextStyle(
                    color: onSurfaceSecondary,
                    fontSize: 12,
                    height: 1.5,
                  )),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Durum Kartı
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumStatusCard extends StatelessWidget {
  final VoidCallback? onUpgrade;
  const _PremiumStatusCard({this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPaid       = SubscriptionService.isPaidSubscriber;
    final isInTrial    = SubscriptionService.isInFreeTrial;
    final isExpired    = SubscriptionService.isExpiredGuest;
    final daysLeft     = SubscriptionService.trialDaysLeft;
    final plan         = SubscriptionService.plan;

    // Renk & ikon & mesaj
    final Color bgColor;
    final Color borderColor;
    final String emoji;
    final String title;
    final String subtitle;
    final bool showButton;

    if (isPaid) {
      bgColor     = const Color(0xFF34C759).withValues(alpha: 0.08);
      borderColor = const Color(0xFF34C759).withValues(alpha: 0.3);
      emoji       = '👑';
      title       = plan == 'yearly' ? 'Premium · Yıllık Plan' : 'Premium · Aylık Plan';
      subtitle    = 'Tüm özelliklere tam erişiminiz var.';
      showButton  = false;
    } else if (isInTrial) {
      bgColor     = const Color(0xFF007AFF).withValues(alpha: 0.07);
      borderColor = const Color(0xFF007AFF).withValues(alpha: 0.25);
      emoji       = '🎁';
      title       = 'Ücretsiz Deneme';
      subtitle    = '$daysLeft gün kaldı — Tüm özelliklere erişebilirsiniz.';
      showButton  = true;
    } else if (isExpired) {
      bgColor     = const Color(0xFFFF9500).withValues(alpha: 0.08);
      borderColor = const Color(0xFFFF9500).withValues(alpha: 0.3);
      emoji       = '⚠️';
      title       = 'Deneme Süreniz Doldu';
      subtitle    = '10 günlük deneme süresi bitmiştir. Premium\'a geçerek tüm özellikleri kullanmaya devam edin.';
      showButton  = true;
    } else {
      bgColor     = theme.colorScheme.surface;
      borderColor = theme.dividerColor;
      emoji       = '🔒';
      title       = 'Ücretsiz Kullanıcı';
      subtitle    = 'Premium\'a geçerek tüm özelliklerin kilidini açın.';
      showButton  = true;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: theme.colorScheme.onSurface)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          if (showButton && onUpgrade != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onUpgrade,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Yükselt',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan Detay Kartı (Aylık / Yıllık)
// ─────────────────────────────────────────────────────────────────────────────

class _PlanDetailCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String price;
  final String period;
  final String? badge;
  final Color? badgeColor;
  final String note;
  final String trialNote;
  final bool trialUsed;
  final Color accent;
  final List<String> features;
  final VoidCallback? onTap;

  const _PlanDetailCard({
    required this.emoji,
    required this.title,
    required this.price,
    required this.period,
    required this.badge,
    required this.badgeColor,
    required this.note,
    required this.trialNote,
    this.trialUsed = false,
    required this.accent,
    required this.features,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst şerit
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: accent)),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(badge!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    Text(note,
                        style: TextStyle(
                            color: accent.withValues(alpha: 0.75),
                            fontSize: 11)),
                  ],
                ),
                const Spacer(),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                          text: price,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: accent)),
                      TextSpan(
                          text: period,
                          style: TextStyle(
                              fontSize: 12,
                              color: accent.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Deneme notu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: trialUsed
                ? Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: trialNote,
                          style: TextStyle(
                              color: accent.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: accent.withValues(alpha: 0.5)),
                        ),
                        TextSpan(
                          text: '  (Kullanıldı)',
                          style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                              fontSize: 11,
                              fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                  )
                : Text(trialNote,
                    style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
          ),

          // Özellik listesi
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: features
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(f,
                            style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface,
                                height: 1.3)),
                      ))
                  .toList(),
            ),
          ),

          // Buton
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    trialUsed
                        ? 'Premium $price$period'
                        : 'Ücretsiz Dene · $price$period',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ücretsiz Plan Kartı — 10 günlük deneme içeriği
// ─────────────────────────────────────────────────────────────────────────────

class _FreePlanListItem extends StatelessWidget {
  final String text;
  const _FreePlanListItem({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface, height: 1.3),
      ),
    );
  }
}


