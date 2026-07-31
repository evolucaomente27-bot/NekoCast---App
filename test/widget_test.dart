// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nekocast/main.dart';
import 'package:nekocast/services/download_service.dart';
import 'package:nekocast/services/locale_service.dart';
import 'package:nekocast/services/manga_service.dart';

void main() {
  testWidgets('renders NekoCast home screen', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleService()),
          ChangeNotifierProvider(create: (_) => MangaService()),
          ChangeNotifierProvider.value(value: DownloadService()),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.text('NekoCast'), findsOneWidget);
  });
}
