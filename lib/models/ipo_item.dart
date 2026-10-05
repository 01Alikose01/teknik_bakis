enum IpoStatus { upcoming, collecting, pendingListing, trading, postponed }

class IpoItem {
  final String companyName;
  final String requestDates;
  final String price;
  final String lot;
  final String distributionType;
  final String symbol;
  final IpoStatus _status;
  final DateTime? requestStart;
  final DateTime? requestEnd;
  final DateTime? listingDate;
  final String kapUrl;
  final String source;
  final DateTime? publishedAt;

  const IpoItem({
    required this.companyName,
    required this.requestDates,
    required this.price,
    required this.lot,
    required this.distributionType,
    required this.symbol,
    required IpoStatus status,
    this.requestStart,
    this.requestEnd,
    this.listingDate,
    this.kapUrl = '',
    this.source = 'KAP',
    this.publishedAt,
  }) : _status = status;

  factory IpoItem.fromJson(Map<String, dynamic> json) {
    final requestStart = _parseFlexibleDate(json['requestStart']);
    final requestEnd = _parseFlexibleDate(json['requestEnd']);
    final listingDate = _parseFlexibleDate(json['listingDate']);
    final publishedAt = _parseFlexibleDate(json['publishedAt']);

    // requestDates alanında "Ertelendi" yazıyorsa status'u postponed yap
    final requestDatesRaw = (json['requestDates'] ?? '').toString().trim();
    final isPostponedByLabel = requestDatesRaw.toLowerCase().contains('ertelendi') ||
        requestDatesRaw.toLowerCase().contains('postponed');

    final parsedStatus = isPostponedByLabel
        ? IpoStatus.postponed
        : _parseStatus(
            json['status']?.toString(),
            requestStart: requestStart,
            requestEnd: requestEnd,
            listingDate: listingDate,
          );

    return IpoItem(
      companyName: (json['companyName'] ?? '').toString().trim(),
      requestDates: _resolveRequestDatesLabel(
        explicitValue: requestDatesRaw.isNotEmpty ? requestDatesRaw : null,
        requestStart: requestStart,
        requestEnd: requestEnd,
      ),
      price: (json['price'] ?? '').toString().trim(),
      lot: (json['lot'] ?? '').toString().trim(),
      distributionType: (json['distributionType'] ?? '').toString().trim(),
      symbol: (json['symbol'] ?? '').toString().trim().toUpperCase(),
      status: parsedStatus,
      requestStart: requestStart,
      requestEnd: requestEnd,
      listingDate: listingDate,
      kapUrl: (json['kapUrl'] ?? '').toString().trim(),
      source: (json['source'] ?? 'KAP').toString().trim(),
      publishedAt: publishedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companyName': companyName,
      'requestDates': requestDates,
      'price': price,
      'lot': lot,
      'distributionType': distributionType,
      'symbol': symbol,
      'status': status.name,
      'requestStart': _toIsoString(requestStart),
      'requestEnd': _toIsoString(requestEnd),
      'listingDate': _toIsoString(listingDate),
      'kapUrl': kapUrl,
      'source': source,
      'publishedAt': _toIsoString(publishedAt),
    };
  }

  IpoItem copyWith({
    String? companyName,
    String? requestDates,
    String? price,
    String? lot,
    String? distributionType,
    String? symbol,
    IpoStatus? status,
    DateTime? requestStart,
    DateTime? requestEnd,
    DateTime? listingDate,
    String? kapUrl,
    String? source,
    DateTime? publishedAt,
  }) {
    return IpoItem(
      companyName: companyName ?? this.companyName,
      requestDates: requestDates ?? this.requestDates,
      price: price ?? this.price,
      lot: lot ?? this.lot,
      distributionType: distributionType ?? this.distributionType,
      symbol: symbol ?? this.symbol,
      status: status ?? this.status,
      requestStart: requestStart ?? this.requestStart,
      requestEnd: requestEnd ?? this.requestEnd,
      listingDate: listingDate ?? this.listingDate,
      kapUrl: kapUrl ?? this.kapUrl,
      source: source ?? this.source,
      publishedAt: publishedAt ?? this.publishedAt,
    );
  }

  DateTime? get sortDate {
    return listingDate ?? requestEnd ?? requestStart ?? publishedAt;
  }

  IpoStatus get status {
    // Ertelenmiş kayıtlar hiçbir zaman başka statüye geçmez
    if (_status == IpoStatus.postponed) return IpoStatus.postponed;

    if (_hasTimelineData) {
      return _deriveStatus(
        requestStart: requestStart,
        requestEnd: requestEnd,
        listingDate: listingDate,
        fallbackStatus: _status,
      );
    }
    return _status;
  }

  bool get _hasTimelineData {
    return requestStart != null || requestEnd != null || listingDate != null;
  }

  String get statusLabel {
    switch (status) {
      case IpoStatus.upcoming:
        return 'Yaklaşan';
      case IpoStatus.collecting:
        return 'Talep Topluyor';
      case IpoStatus.pendingListing:
        return 'Listeleme Bekliyor';
      case IpoStatus.trading:
        return 'Borsada İşlem Görüyor';
      case IpoStatus.postponed:
        return 'Ertelendi';
    }
  }

  static IpoStatus _parseStatus(
    String? raw, {
    required DateTime? requestStart,
    required DateTime? requestEnd,
    required DateTime? listingDate,
  }) {
    final hasTimeline =
        requestStart != null || requestEnd != null || listingDate != null;

    if (hasTimeline) {
      // Tarih alanları mevcutsa her zaman gerçek tarihlerden türet.
      // Firestore status değeri sadece fallback olarak kullanılır.
      final fallback = _parseRawStatus(raw?.trim().toLowerCase() ?? '') ??
          IpoStatus.upcoming;
      return _deriveStatus(
        requestStart: requestStart,
        requestEnd: requestEnd,
        listingDate: listingDate,
        fallbackStatus: fallback,
      );
    }

    // Tarih alanı hiç yoksa Firestore status değerini son çare olarak kullan.
    final explicit = _parseRawStatus(raw?.trim().toLowerCase() ?? '');
    return explicit ?? IpoStatus.upcoming;
  }

  static IpoStatus? _parseRawStatus(String value) {
    switch (value) {
      case 'yaklasan':
      case 'yaklaşan':
      case 'upcoming':
        return IpoStatus.upcoming;
      case 'talep_topluyor':
      case 'talep topluyor':
      case 'collecting':
      case 'active':
        return IpoStatus.collecting;
      case 'listeleme_bekliyor':
      case 'listeleme bekliyor':
      case 'pending_listing':
      case 'pendinglisting':
        return IpoStatus.pendingListing;
      case 'borsada_islem_goruyor':
      case 'borsada işlem görüyor':
      case 'trading':
      case 'completed':
        return IpoStatus.trading;
      case 'ertelendi':
      case 'postponed':
      case 'ertelenmiş':
        return IpoStatus.postponed;
      default:
        return null;
    }
  }

  /// Türkiye saat dilimi (UTC+3) ile şimdiki zamanı döndürür.
  static DateTime _nowInTurkey() {
    return DateTime.now().toUtc().add(const Duration(hours: 3));
  }

  static IpoStatus _deriveStatus({
    required DateTime? requestStart,
    required DateTime? requestEnd,
    required DateTime? listingDate,
    required IpoStatus fallbackStatus,
  }) {
    final now = _nowInTurkey();

    // listingDate geldi veya bugün → borsada işlem görüyor
    if (listingDate != null && !listingDate.isAfter(now)) {
      return IpoStatus.trading;
    }

    if (requestEnd != null && now.isAfter(_endOfDay(requestEnd))) {
      // Talep toplama bitti
      if (listingDate != null && !listingDate.isAfter(now)) {
        return IpoStatus.trading;
      }
      if (listingDate != null && listingDate.isAfter(now)) {
        // Listeleme tarihi belli, henüz gelmedi
        return IpoStatus.pendingListing;
      }
      // Listeleme tarihi bilinmiyor:
      // JSON'da açıkça "trading" yazılıysa trading döndür,
      // aksi hâlde listeleme bekliyor
      if (fallbackStatus == IpoStatus.trading) {
        return IpoStatus.trading;
      }
      return IpoStatus.pendingListing;
    }

    if (requestStart != null) {
      final start = _startOfDay(requestStart);
      return now.isBefore(start) ? IpoStatus.upcoming : IpoStatus.collecting;
    }

    if (listingDate != null) {
      return now.isBefore(_startOfDay(listingDate))
          ? IpoStatus.upcoming
          : IpoStatus.trading;
    }

    return fallbackStatus;
  }

  static String _resolveRequestDatesLabel({
    required String? explicitValue,
    required DateTime? requestStart,
    required DateTime? requestEnd,
  }) {
    final raw = explicitValue?.trim() ?? '';
    if (raw.isNotEmpty) return raw;
    if (requestStart == null && requestEnd == null) return '-';
    if (requestStart != null && requestEnd != null) {
      return '${_formatDate(requestStart)} - ${_formatDate(requestEnd)}';
    }
    return _formatDate(requestStart ?? requestEnd!);
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  static DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  static DateTime? _parseFlexibleDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;

    try {
      return DateTime.parse(raw);
    } catch (_) {}

    final normalized = raw.replaceAll('/', '.').replaceAll('-', '.');
    final parts = normalized.split('.');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        final safeYear = year < 100 ? 2000 + year : year;
        return DateTime(safeYear, month, day);
      }
    }

    return null;
  }

  static String? _toIsoString(DateTime? value) => value?.toIso8601String();
}
