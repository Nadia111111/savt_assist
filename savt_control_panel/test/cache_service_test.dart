import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:control_panel/services/cache_service.dart';
import 'package:control_panel/services/offline_service.dart';
import 'package:control_panel/widgets/auth_image.dart';
import 'package:control_panel/widgets/cache_clear_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppCacheService & OfflineService Data Cache', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AuthImage.clearDiskCache();
    });

    test('formatBytes formats properly across ranges', () {
      expect(AppCacheService.formatBytes(0), '0 КБ');
      expect(AppCacheService.formatBytes(-5), '0 КБ');
      expect(AppCacheService.formatBytes(500), '500 Б');
      expect(AppCacheService.formatBytes(1024), '1.0 КБ');
      expect(AppCacheService.formatBytes(1536), '1.5 КБ');
      expect(AppCacheService.formatBytes(1024 * 1024), '1.0 МБ');
      expect(AppCacheService.formatBytes((2.5 * 1024 * 1024).round()), '2.5 МБ');
    });

    test('OfflineService detects cache keys and preserves settings/tokens', () async {
      final prefs = await SharedPreferences.getInstance();

      // Put tokens and user settings
      await prefs.setString('access_token', 'my_secret_token');
      await prefs.setString('theme_mode', 'dark');
      await prefs.setDouble('chat_font_size', 16.0);

      // Put cache data
      const sampleCabinetData = '{"items":[{"id":1,"name":"Cabinet 1"}]}';
      await OfflineService().saveCache('cabinets_list', sampleCabinetData);
      await OfflineService().saveCache('kb_articles', '{"articles":[]}');

      // Check size calculation
      final cacheSize = await OfflineService().getDataCacheSizeBytes();
      expect(cacheSize, greaterThan(0));

      // Clear ONLY data cache
      await OfflineService().clearDataCache();

      // Verify data cache is cleared
      final newCacheSize = await OfflineService().getDataCacheSizeBytes();
      expect(newCacheSize, 0);

      // CRITICAL: verify tokens and settings were NOT touched!
      expect(prefs.getString('access_token'), 'my_secret_token');
      expect(prefs.getString('theme_mode'), 'dark');
      expect(prefs.getDouble('chat_font_size'), 16.0);
    });

    test('AppCacheService.getBreakdown aggregates all cache sources', () async {
      final prefs = await SharedPreferences.getInstance();
      const testJson = '{"test_data_string":"some value to occupy bytes"}';
      await prefs.setString('cabinets_list', testJson);

      final breakdown = await AppCacheService.instance.getBreakdown();
      expect(breakdown.offlineDataBytes, utf8.encode(testJson).length);
      expect(breakdown.totalBytes, greaterThanOrEqualTo(breakdown.offlineDataBytes));
    });
  });

  group('CacheClearDialog Widget Tests', () {
    testWidgets('Renders breakdown and allows selective clearing', (WidgetTester tester) async {
      const breakdown = AppCacheBreakdown(
        imageBytes: 1024 * 1024, // 1.0 МБ
        databaseBytes: 256 * 1024, // 256.0 КБ
        offlineDataBytes: 64 * 1024, // 64.0 КБ
      );

      int? clearedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  clearedResult = await showDialog<int>(
                    context: context,
                    builder: (_) => CacheClearDialog(initialBreakdown: breakdown),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Tap button to open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify title and categories
      expect(find.text('Очистка кэша'), findsOneWidget);
      expect(find.text('Изображения и медиа'), findsOneWidget);
      expect(find.text('База данных чатов'), findsOneWidget);
      expect(find.text('Оффлайн-копии данных'), findsOneWidget);

      // Check formatted sizes
      expect(find.text('1.0 МБ'), findsOneWidget);
      expect(find.text('256.0 КБ'), findsOneWidget);
      expect(find.text('64.0 КБ'), findsOneWidget);

      // Verify initial total
      expect(find.text('1.3 МБ'), findsNWidgets(2)); // Total and Selected

      // Deselect images (tap category tile)
      await tester.tap(find.text('Изображения и медиа'));
      await tester.pumpAndSettle();

      // Now selected size is 256 KB + 64 KB = 320 KB
      expect(find.text('320.0 КБ'), findsOneWidget);

      // Tap the action button to confirm clear
      await tester.tap(find.widgetWithText(TextButton, 'Очистить (320.0 КБ)'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed and return clearedBytes = 320 KB (327680 bytes)
      expect(clearedResult, 320 * 1024);
    });
  });
}
