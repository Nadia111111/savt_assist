import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:control_panel/main.dart';
import 'package:control_panel/services/preferences_service.dart';
import 'package:control_panel/services/token_storage.dart';
import 'package:control_panel/services/api_client.dart';
import 'package:control_panel/services/auth_service.dart';
import 'package:control_panel/services/cabinet_service.dart';
import 'package:control_panel/services/chat_service.dart';
import 'package:control_panel/services/upload_service.dart';
import 'package:control_panel/services/knowledge_service.dart';
import 'package:control_panel/services/favorites_service.dart';
import 'package:control_panel/services/service_request_service.dart';
import 'package:control_panel/services/reclamations_service.dart';
import 'package:control_panel/services/user_events_service.dart';
import 'package:control_panel/screens/favorites_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();

    tokenStorage = TokenStorage();
    apiClient = ApiClient(tokenStorage);
    authService = AuthService(apiClient, tokenStorage);
    cabinetService = CabinetService(apiClient);
    chatService = ChatService(apiClient);
    uploadService = UploadService(apiClient);
    knowledgeService = KnowledgeService(apiClient);
    favoritesService = FavoritesService(apiClient);
    serviceRequestService = ServiceRequestService(apiClient);
    reclamationsService = ReclamationsService(apiClient);
    userEventsService = UserEventsService(apiClient, tokenStorage);
  });

  testWidgets('FavoritesScreen displays tabs and does not have old ExpansionTile or Перейти в чат', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: FavoritesScreen(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Check title and tabs
    expect(find.text('Избранное'), findsOneWidget);
    expect(find.text('Статьи'), findsOneWidget);
    expect(find.text('Вопросы'), findsOneWidget);

    // Initial tab is Articles -> empty state
    expect(find.text('Нет сохранённых статей'), findsOneWidget);

    // Switch to Questions tab
    await tester.tap(find.text('Вопросы'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Check Questions empty state
    expect(find.text('Нет сохранённых вопросов'), findsOneWidget);

    // Verify no ExpansionTile and no 'Перейти в чат'
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('Перейти в чат'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
