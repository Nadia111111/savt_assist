import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:control_panel/screens/chat_settings_screen.dart';
import 'package:control_panel/services/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  testWidgets('ChatSettingsScreen renders per-chat settings properly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: ChatSettingsScreen(chatId: '48'),
      ),
    );

    await tester.pumpAndSettle();

    // Verify AppBar
    expect(find.text('Настройки этого чата'), findsOneWidget);

    // Verify Live Preview Card is present and rendered
    expect(find.text('SAVT помощник'), findsOneWidget);

    // Verify Wallpaper & Name color card
    expect(find.text('Изменить обои'), findsOneWidget);
    expect(find.text('Изменить цвет имени'), findsOneWidget);

    // Verify Theme presets card
    expect(find.text('Цветовая тема'), findsOneWidget);

    // Verify Font size slider card
    expect(find.text('Размер текста сообщений'), findsOneWidget);

    // Verify Bubble radius card
    expect(find.text('Углы блоков с сообщениями'), findsOneWidget);

    // Verify "Список чатов" is HIDDEN for per-chat
    expect(find.text('Список чатов'), findsNothing);

    // Verify Save Button
    expect(find.text('Сохранить для этого чата'), findsOneWidget);
  });

  testWidgets('ChatSettingsScreen renders global settings with chat list mode', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: ChatSettingsScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify AppBar
    expect(find.text('Настройки всех чатов'), findsOneWidget);

    // Verify "Список чатов" IS SHOWN for global settings
    expect(find.text('Список чатов'), findsOneWidget);

    // Verify Save Button for all chats
    expect(find.text('Сохранить для всех чатов'), findsOneWidget);
  });
}
