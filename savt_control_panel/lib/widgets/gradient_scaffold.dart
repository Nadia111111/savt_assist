// lib/widgets/gradient_scaffold.dart
import 'package:flutter/material.dart';
import '../services/network_service.dart';
import 'animated_background.dart';
import 'responsive_layout.dart';

class GradientScaffold extends StatelessWidget {
  final String? appBarTitle;
  final String? appBarSubtitle;
  final Widget? appBarAction;
  final Widget? appBarLeading;
  final Widget body;
  final Widget? bottomNavBar;
  final bool useAdaptive;
  final bool enableDesktopCentering;

  const GradientScaffold({
    super.key,
    this.appBarTitle,
    this.appBarSubtitle,
    this.appBarAction,
    this.appBarLeading,
    required this.body,
    this.bottomNavBar,
    this.useAdaptive = false,
    this.enableDesktopCentering = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Анимированный фон на весь экран
          Positioned.fill(
            child: AnimatedBackground(
              gradientColors: isDark
                  ? const [
                      Color(0xFF021A38),
                      Color(0xFF03254C),
                      Color(0xFF021A38),
                    ]
                  : const [
                      Color(0xFF054582),
                      Color(0xFF0a7ac2),
                      Color(0xFFe0f2fe),
                    ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: NetworkService.isOnlineNotifier,
            builder: (context, isOnline, child) {
              return Stack(
                children: [
                  Column(
                    children: [
                      SafeArea(
                        bottom: false,
                        child: _buildHeader(context),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(32),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(32),
                            ),
                            child: useAdaptive && isDesktop
                                ? Center(
                                    child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 480),
                                      child: body,
                                    ),
                                  )
                                : body,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isOnline)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.orange.shade100,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: const Text(
                          'Нет подключения к интернету',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: bottomNavBar,
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (appBarTitle == null) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return SizedBox(
      height: 56,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 24 : 8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Кнопка «назад» (если есть) — слева от логотипа
            if (appBarLeading != null) appBarLeading!,
            // Логотип
            Image.network(
              'https://savt.by/wp-content/uploads/2025/10/logo-small.png',
              height: 58,
              width: 58,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                height: 58,
                width: 58,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.business, size: 30, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            // Название страницы (займёт всё доступное пространство)
            Expanded(
              child: Text(
                appBarTitle!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Фиксированное место для кнопки поиска (48px)
            SizedBox(
              width: 48,
              child: appBarAction ?? const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
