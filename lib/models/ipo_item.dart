enum IpoStatus { upcoming, collecting, trading }

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

    return IpoItem(
      companyName: (json['companyName'] ?? '').toString().trim(),
      requestDates: _resolveRequestDatesLabel(
        explicitValue: json['requestDates']?.toString(),
        requestStart: requestStart,
        requestEnd: requestEnd,
      ),
      price: (json['price'] ?? '').toString().trim(),
      lot: (json['lot'] ?? '').toString().trim(),
      distributionType: (json['distributionType'] ?? '').toString().trim(),
      symbol: (json['symbol'] ?? '').toString().trim().toUpperCase(),
      status: _parseStatus(
        json['status']?.toString(),
        requestStart: requestStart,
        requestEnd: requestEnd,
        listingDate: listingDate,
      ),
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
      case IpoStatus.trading:
        return 'Borsada İşlem Görüyor';
    }
  }

  static IpoStatus _parseStatus(
    String? raw, {
    required DateTime? requestStart,
    required DateTime? requestEnd,
    required DateTime? listingDate,
  }) {
    final value = raw?.trim().toLowerCase() ?? '';
    final explicit = _parseRawStatus(value);
    if (explicit != null) {
      return explicit;
    }

    if (requestStart != null || requestEnd != null || listingDate != null) {
      return _deriveStatus(
        requestStart: requestStart,
        requestEnd: requestEnd,
        listingDate: listingDate,
        fallbackStatus: IpoStatus.upcoming,
      );
    }

    return IpoStatus.upcoming;
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
      case 'borsada_islem_goruyor':
      case 'borsada işlem görüyor':
      case 'trading':
      case 'completed':
        return IpoStatus.trading;
      default:
        return null;
    }
  }

  static IpoStatus _deriveStatus({
    required DateTime? requestStart,
    required DateTime? requestEnd,
    required DateTime? listingDate,
    required IpoStatus fallbackStatus,
  }) {
    final now = DateTime.now();
    if (listingDate != null && !listingDate.isAfter(now)) {
      return IpoStatus.trading;
    }

    if (requestEnd != null && now.isAfter(_endOfDay(requestEnd))) {
      if (listingDate == null || !listingDate.isAfter(now)) {
        return IpoStatus.trading;
      }
      return IpoStatus.collecting;
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
