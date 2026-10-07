// lib/screens/main_navigation_container.dart
import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../main.dart';
import 'shu_list_screen.dart';
import 'knowledge_screen.dart';
import 'chats_screen.dart';
import 'profile_screen.dart';
import 'about_us_screen.dart';

class MainNavigationContainer extends StatefulWidget {
  final int initialTab;
  const MainNavigationContainer({super.key, this.initialTab = 0});

  static final GlobalKey<MainNavigationContainerState> globalKey =
      GlobalKey<MainNavigationContainerState>();

  @override
  State<MainNavigationContainer> createState() =>
      MainNavigationContainerState();
}

class MainNavigationContainerState extends State<MainNavigationContainer>
    with WidgetsBindingObserver {
  late int _currentIndex;
  late final PageController _pageController;
  final bool _isPageAnimating = false;

  final GlobalKey<ShuListScreenState> _shuListKey =
      GlobalKey<ShuListScreenState>();
  final GlobalKey<KnowledgeScreenState> _knowledgeKey =
      GlobalKey<KnowledgeScreenState>();
  final GlobalKey<ChatsScreenState> _chatsKey = GlobalKey<ChatsScreenState>();
  final GlobalKey<ProfileScreenState> _profileKey =
      GlobalKey<ProfileScreenState>();
  final GlobalKey<AboutUsScreenState> _aboutUsKey =
      GlobalKey<AboutUsScreenState>();

  bool get _isGuestMode => tokenStorage.isGuestMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = _isGuestMode ? 0 : widget.initialTab;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _chatsKey.currentState?.loadChats();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  void setTab(int index) {
    if (mounted && index != _currentIndex && !_isPageAnimating) {
      _pageController
          .jumpToPage(index); // Используем jumpToPage вместо animateToPage
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void refreshChatsList() {
    _chatsKey.currentState?.loadChats();
  }

  void _onTabTapped(int index) {
    if (_isPageAnimating) return;

    // Если нажимаем на уже активную вкладку - скроллим наверх
    if (_currentIndex == index) {
      if (_isGuestMode) {
        if (index == 0) _knowledgeKey.currentState?.resetState();
        if (index == 1) _aboutUsKey.currentState?.resetState();
      } else {
        switch (index) {
          case 0:
            _shuListKey.currentState?.scrollToTop();
            break;
          case 1:
            _knowledgeKey.currentState?.resetState();
            break;
          case 2:
            _chatsKey.currentState?.resetState();
            break;
          case 3:
            _profileKey.currentState?.resetState();
            break;
        }
      }
      return;
    }

    // Мгновенное переключение без анимации
    _pageController.jumpToPage(index);
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          if (!_isPageAnimating) {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        children: _buildPages(),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        isGuestMode: _isGuestMode,
        onScannerTap: () async {
          await Navigator.pushNamed(context, '/qr-scanner');
          _shuListKey.currentState?.refreshCabinets();
        },
      ),
    );
  }

  List<Widget> _buildPages() {
    if (_isGuestMode) {
      return [
        KnowledgeScreen(key: _knowledgeKey, isTab: true),
        AboutUsScreen(key: _aboutUsKey, isTab: true),
      ];
    } else {
      return [
        ShuListScreen(key: _shuListKey, isTab: true),
        KnowledgeScreen(key: _knowledgeKey, isTab: true),
        ChatsScreen(key: _chatsKey, isTab: true),
        ProfileScreen(key: _profileKey, isTab: true),
      ];
    }
  }
}
