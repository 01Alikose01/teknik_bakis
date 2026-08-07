import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:teknik_bakis/services/portfolio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('teknik_bakis_hive_test');
    Hive.init(tempDir.path);
    await PortfolioService.init();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  test('favorite list storage keeps a stable copy after the source list is mutated', () async {
    await PortfolioService.favoriteBox.clear();

    final listA = ['THYAO', 'GARAN'];
    final listB = ['AKBNK'];

    await PortfolioService.saveFavoriteLists(listA, listB);

    listA.remove('THYAO');

    expect(PortfolioService.getFavoriteList('listA'), ['THYAO', 'GARAN']);
    expect(PortfolioService.getFavoriteList('listB'), ['AKBNK']);
  });
}
