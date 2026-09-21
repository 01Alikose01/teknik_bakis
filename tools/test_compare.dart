import 'package:teknik_bakis/services/stock_service.dart';

Future<void> main() async {
  print('Fetching THYAO via fetchStock (3mo)...');
  final asset3mo = await StockService.fetchStock('THYAO', period: '3mo');
  print('3mo - Price: ${asset3mo?.price}, Change: ${asset3mo?.changePercent}');
  
  print('Fetching THYAO via fetchMultiple (5d)...');
  final assets = await StockService.fetchMultiple(['THYAO'], period: '5d');
  final asset5d = assets.isNotEmpty ? assets.first : null;
  print('5d - Price: ${asset5d?.price}, Change: ${asset5d?.changePercent}');
}
