import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:control_panel/main.dart';
import 'package:control_panel/screens/navigation_container.dart';
import 'package:control_panel/widgets/bottom_nav_bar.dart';
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
import 'package:control_panel/screens/my_requests_screen.dart';

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

  testWidgets('Tap profile nav button switches to ProfileScreen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: ControlPanelApp.navigatorKey,
        navigatorObservers: [AppRouteObserver.instance],
        builder: (context, child) => PersistentAppShell(child: child!),
        initialRoute: '/home',
        onGenerateInitialRoutes: (initialRoute) {
          return [
            MaterialPageRoute(
              settings: const RouteSettings(name: '/home'),
              builder: (_) => MainNavigationContainer(
                key: MainNavigationContainer.globalKey,
                initialTab: 0,
              ),
            ),
          ];
        },
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const SizedBox(),
          );
        },
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify initial tab is ShuListScreen or at least bottom nav exists
    expect(find.byType(BottomNavBar), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);

    // Tap Profile button (Icons.person_outline)
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Check if ProfileScreen or "Профиль" title is shown
    expect(find.text('Профиль'), findsWidgets);

    // Drain the 8-second getMe() timeout timer so flutter_test doesn't complain about pending timers
    await tester.pump(const Duration(seconds: 9));
    // Dispose the widget tree to cancel periodic timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Tap profile nav button from Favorites pops to ProfileScreen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: ControlPanelApp.navigatorKey,
        navigatorObservers: [AppRouteObserver.instance],
        builder: (context, child) => PersistentAppShell(child: child!),
        initialRoute: '/home',
        onGenerateInitialRoutes: (initialRoute) {
          return [
            MaterialPageRoute(
              settings: const RouteSettings(name: '/home'),
              builder: (_) => MainNavigationContainer(
                key: MainNavigationContainer.globalKey,
                initialTab: 0,
              ),
            ),
          ];
        },
        routes: {
          '/favorites': (_) => const FavoritesScreen(),
          '/my-requests': (_) => const MyRequestsScreen(),
        },
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Push favorites screen
    ControlPanelApp.navigatorKey.currentState!.pushNamed('/favorites');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Избранное'), findsWidgets);

    // Profile tab is selected because Favorites has currentNavIndex: 3, so icon is Icons.person
    expect(find.byIcon(Icons.person), findsOneWidget);

    // Tap Profile button (Icons.person)
    await tester.tap(find.byIcon(Icons.person));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify Profile screen is shown and Favorites is popped
    expect(find.text('Профиль'), findsWidgets);
    expect(find.text('Избранное'), findsNothing);

    // Drain timer
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Tap profile nav button from MyRequests pops to ProfileScreen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: ControlPanelApp.navigatorKey,
        navigatorObservers: [AppRouteObserver.instance],
        builder: (context, child) => PersistentAppShell(child: child!),
        initialRoute: '/home',
        onGenerateInitialRoutes: (initialRoute) {
          return [
            MaterialPageRoute(
              settings: const RouteSettings(name: '/home'),
              builder: (_) => MainNavigationContainer(
                key: MainNavigationContainer.globalKey,
                initialTab: 0,
              ),
            ),
          ];
        },
        routes: {
          '/favorites': (_) => const FavoritesScreen(),
          '/my-requests': (_) => const MyRequestsScreen(),
        },
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Push my requests screen
    ControlPanelApp.navigatorKey.currentState!.pushNamed('/my-requests');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Мои заявки'), findsWidgets);

    // My Requests has currentNavIndex: 0, so profile icon is unselected Icons.person_outline
    expect(find.byIcon(Icons.person_outline), findsOneWidget);

    // Tap Profile button (Icons.person_outline)
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify Profile screen is shown and MyRequests is popped
    expect(find.text('Профиль'), findsWidgets);
    expect(find.text('Мои заявки'), findsNothing);

    // Drain timer
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
