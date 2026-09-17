// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nekocast/main.dart';
import 'package:nekocast/screens/main_navigation_screen.dart';
import 'package:nekocast/services/download_service.dart';
import 'package:nekocast/services/locale_service.dart';
import 'package:nekocast/services/manga_service.dart';
import 'package:nekocast/services/player_service.dart';
import 'package:nekocast/services/watch_history_service.dart';
import 'package:nekocast/services/doh_service.dart';
import 'package:nekocast/services/tv_mode_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    try {
      MediaKit.ensureInitialized();
    } catch (_) {}
  });

  testWidgets('renders NekoCast home screen', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleService()),
          ChangeNotifierProvider(create: (_) => MangaService()),
          ChangeNotifierProvider(create: (_) => PlayerService()),
          ChangeNotifierProvider(create: (_) => WatchHistoryService()),
          ChangeNotifierProvider(create: (_) => DohService()),
          ChangeNotifierProvider(create: (_) => TvModeService()),
          ChangeNotifierProvider.value(value: DownloadService()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MainNavigationScreen), findsOneWidget);
  });
}
