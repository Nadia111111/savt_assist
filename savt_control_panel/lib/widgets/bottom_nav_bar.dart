// lib/widgets/bottom_nav_bar.dart
import 'package:flutter/material.dart';
import '../services/offline_service.dart';
import '../screens/navigation_container.dart';
import '../main.dart';

class BottomNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isGuestMode;
  final VoidCallback? onScannerTap;
  final bool isScannerActive;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isGuestMode = false,
    this.onScannerTap,
    this.isScannerActive = false,
  });

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  bool _isProcessingTap = false;

  void _handleTap(int index) {
    if (_isProcessingTap) return;
    if (widget.currentIndex == index) {
      widget.onTap(index);
      return;
    }

    setState(() {
      _isProcessingTap = true;
    });

    widget.onTap(index);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _isProcessingTap = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatUnreadCount = OfflineService.unreadChatCount.value;
    final items = widget.isGuestMode
        ? [
            _buildNavItem(context, Icons.menu_book_outlined, 0,
                selectedIcon: Icons.menu_book),
            _buildNavItem(context, Icons.info_outline_rounded, 1,
                selectedIcon: Icons.info_rounded),
          ]
        : [
            _buildNavItem(context, Icons.dashboard_outlined, 0,
                selectedIcon: Icons.dashboard),
            _buildNavItem(context, Icons.menu_book_outlined, 1,
                selectedIcon: Icons.menu_book),
            _buildCenterScannerButton(context),
            _buildNavItemWithBadge(
                context, Icons.chat_bubble_outline, 2, chatUnreadCount,
                selectedIcon: Icons.chat_bubble),
            _buildNavItem(context, Icons.person_outline, 3,
                selectedIcon: Icons.person),
          ];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, -8),
            spreadRadius: -10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    int index, {
    IconData? selectedIcon,
  }) {
    final theme = Theme.of(context);
    final isSelected = widget.currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTap(index),
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.2),
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  isSelected ? (selectedIcon ?? icon) : icon,
                  key: ValueKey('icon_${index}_$isSelected'),
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItemWithBadge(
    BuildContext context,
    IconData icon,
    int index,
    int count, {
    IconData? selectedIcon,
  }) {
    final theme = Theme.of(context);
    final isSelected = widget.currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTap(index),
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.2),
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      isSelected ? (selectedIcon ?? icon) : icon,
                      key: ValueKey('icon_${index}_$isSelected'),
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: -10,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF991B1B),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF991B1B).withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterScannerButton(BuildContext context) {
    final theme = Theme.of(context);
    final isScannerSelected = widget.isScannerActive;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            widget.onScannerTap?.call();
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 46,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isScannerSelected
                    ? [
                        theme.colorScheme.primary,
                        const Color(0xFF00B4D8),
                      ]
                    : [
                        theme.colorScheme.primary,
                        const Color(0xFF0A7AC2),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary
                      .withValues(alpha: isScannerSelected ? 0.6 : 0.35),
                  blurRadius: isScannerSelected ? 14 : 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.qr_code_scanner,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Состояние глобальной панели навигации
class AppNavState extends ChangeNotifier {
  static final AppNavState instance = AppNavState._internal();
  AppNavState._internal();

  bool _isVisible = true;
  int _currentIndex = 0;
  bool _isScannerActive = false;
  bool _isRouteExcluded = false;

  bool get isVisible => _isVisible && !_isRouteExcluded;
  int get currentIndex => _currentIndex;
  bool get isScannerActive => _isScannerActive;

  final List<AppNavConfig> _configStack = [];

  void setRouteExcluded(bool excluded) {
    if (_isRouteExcluded != excluded) {
      _isRouteExcluded = excluded;
      notifyListeners();
    }
  }

  void pushConfig({
    required Object id,
    required bool showBottomBar,
    int? currentIndex,
    bool isScannerActive = false,
  }) {
    _configStack.removeWhere((c) => c.id == id);
    _configStack.add(AppNavConfig(
      id: id,
      showBottomBar: showBottomBar,
      currentIndex: currentIndex,
      isScannerActive: isScannerActive,
    ));
    _applyCurrentConfig();
  }

  void updateConfig({
    required Object id,
    required bool showBottomBar,
    int? currentIndex,
    bool isScannerActive = false,
  }) {
    final idx = _configStack.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _configStack[idx] = AppNavConfig(
        id: id,
        showBottomBar: showBottomBar,
        currentIndex: currentIndex,
        isScannerActive: isScannerActive,
      );
      if (idx == _configStack.length - 1) {
        _applyCurrentConfig();
      }
    } else {
      pushConfig(
        id: id,
        showBottomBar: showBottomBar,
        currentIndex: currentIndex,
        isScannerActive: isScannerActive,
      );
    }
  }

  void removeConfig(Object id) {
    final removedIndex = _configStack.indexWhere((c) => c.id == id);
    if (removedIndex != -1) {
      final wasTop = removedIndex == _configStack.length - 1;
      _configStack.removeAt(removedIndex);
      if (wasTop) {
        _applyCurrentConfig();
      }
    }
  }

  void setTab(int index) {
    if (_currentIndex != index || _isScannerActive) {
      _currentIndex = index;
      _isScannerActive = false;
      notifyListeners();
    }
  }

  void setScannerActive(bool active) {
    if (_isScannerActive != active) {
      _isScannerActive = active;
      notifyListeners();
    }
  }

  void setVisible(bool visible) {
    if (_isVisible != visible) {
      _isVisible = visible;
      notifyListeners();
    }
  }

  void _applyCurrentConfig() {
    if (_configStack.isNotEmpty) {
      final top = _configStack.last;
      _isVisible = top.showBottomBar;
      _isScannerActive = top.isScannerActive;
      if (top.currentIndex != null && top.currentIndex! >= 0) {
        _currentIndex = top.currentIndex!;
      }
    }
    notifyListeners();
  }
}

class AppNavConfig {
  final Object id;
  final bool showBottomBar;
  final int? currentIndex;
  final bool isScannerActive;

  AppNavConfig({
    required this.id,
    required this.showBottomBar,
    this.currentIndex,
    this.isScannerActive = false,
  });
}

/// Наблюдатель роутов для переключения видимости нижней панели
class AppRouteObserver extends NavigatorObserver {
  static final AppRouteObserver instance = AppRouteObserver();

  static const Set<String> _excludedRoutes = {
    '/',
    '/onboarding',
    '/auth',
    '/forgot-password',
    '/register-request',
    '/password-reset-request',
  };

  void _handleRoute(Route<dynamic>? route) {
    if (route == null) return;
    final name = route.settings.name;
    if (name != null) {
      if (_excludedRoutes.contains(name)) {
        AppNavState.instance.setRouteExcluded(true);
        return;
      }
      AppNavState.instance.setRouteExcluded(false);

      if (name == '/qr-scanner' ||
          name.startsWith('/add/cabinet/') ||
          name.startsWith('/add/project/')) {
        AppNavState.instance.setScannerActive(true);
      } else {
        AppNavState.instance.setScannerActive(false);
        if (name == '/chats' ||
            name.startsWith('/chat/') ||
            name.startsWith('/chat-settings') ||
            name == '/search-messages' ||
            name == '/operator-panel') {
          AppNavState.instance.setTab(2);
        } else if (name == '/knowledge' || name == '/about-us') {
          AppNavState.instance.setTab(1);
        } else if (name == '/profile' ||
            name == '/edit-profile' ||
            name == '/change-password' ||
            name == '/change-phone' ||
            name == '/notifications') {
          AppNavState.instance.setTab(3);
        } else if (name == '/home' ||
            name == '/shu-list' ||
            name.startsWith('/shu-detail/') ||
            name == '/requests-hub' ||
            name == '/my-requests' ||
            name == '/reclamations' ||
            name.startsWith('/reclamation-detail/') ||
            name == '/create-reclamation' ||
            name.startsWith('/service-request') ||
            name == '/all-documents' ||
            name == '/notes' ||
            name == '/favorites') {
          AppNavState.instance.setTab(0);
        }
      }
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _handleRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _handleRoute(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _handleRoute(newRoute);
  }
}

/// Статичный виджет нижней навигации без анимаций перехода между экранами
class PersistentBottomNavBar extends StatelessWidget {
  const PersistentBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppNavState.instance,
      builder: (context, _) {
        final state = AppNavState.instance;
        final isGuest = tokenStorage.isGuestMode;
        final effectiveIndex =
            state.isScannerActive ? -1 : state.currentIndex;

        return ValueListenableBuilder<int>(
          valueListenable: OfflineService.unreadChatCount,
          builder: (context, _, __) {
            return BottomNavBar(
              currentIndex: effectiveIndex,
              isGuestMode: isGuest,
              isScannerActive: state.isScannerActive,
              onTap: (index) => AppBottomNavBar.navigateToTab(context, index),
              onScannerTap: () => AppBottomNavBar.navigateToScanner(
                context,
                isAlreadyOnScanner: state.isScannerActive,
              ),
            );
          },
        );
      },
    );
  }
}

/// Корневой контейнер-оболочка (App Shell), обеспечивающий статичное положение
/// панели навигации поверх всех переходов между экранами.
class PersistentAppShell extends StatelessWidget {
  final Widget child;

  const PersistentAppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppNavState.instance,
      builder: (context, _) {
        final state = AppNavState.instance;
        final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
        final showBar = state.isVisible && !isKeyboardOpen;

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
          body: child,
          bottomNavigationBar: showBar
              ? const PersistentBottomNavBar()
              : null,
        );
      },
    );
  }
}

/// Глобальная нижняя панель навигации для вторичных экранов приложения
class AppBottomNavBar extends StatelessWidget {
  final int? currentNavIndex;
  final bool isScannerActive;

  const AppBottomNavBar({
    super.key,
    this.currentNavIndex,
    this.isScannerActive = false,
  });

  static void navigateToTab(BuildContext context, int index) {
    AppNavState.instance.setTab(index);
    final state = MainNavigationContainer.globalKey.currentState;
    if (state != null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      state.setTab(index);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        MainNavigationContainer.globalKey.currentState?.setTab(index);
      });
    }
  }

  static Future<void> navigateToScanner(BuildContext context,
      {bool isAlreadyOnScanner = false}) async {
    if (isAlreadyOnScanner) return;

    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == '/qr-scanner') return;

    AppNavState.instance.setScannerActive(true);
    final state = MainNavigationContainer.globalKey.currentState;
    if (state != null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    await Navigator.of(context).pushNamed('/qr-scanner');
  }

  @override
  Widget build(BuildContext context) {
    // В новой архитектуре AppShell панель навигации вынесена на уровень MaterialApp.builder.
    // Если AppBottomNavBar вызван локально, скрываем его во избежание дублирования.
    return const SizedBox.shrink();
  }
}
