// lib/widgets/gradient_scaffold.dart
import 'package:flutter/material.dart';
import '../services/network_service.dart';
import 'animated_background.dart';

class GradientScaffold extends StatefulWidget {
  final String? appBarTitle;
  final String? appBarSubtitle;
  final Widget? appBarAction;
  final Widget? appBarLeading;
  final Widget? appBarCustomHeader;
  final Widget body;
  final Widget? bottomNavBar;
  final bool useAdaptive;
  final bool enableDesktopCentering;
  final bool useTransparentBody;
  final Widget? floatingActionButton;
  final bool showBackButton;

  const GradientScaffold({
    super.key,
    this.appBarTitle,
    this.appBarSubtitle,
    this.appBarAction,
    this.appBarLeading,
    this.appBarCustomHeader,
    required this.body,
    this.bottomNavBar,
    this.useAdaptive = false,
    this.enableDesktopCentering = false,
    this.useTransparentBody = false,
    this.floatingActionButton,
    this.showBackButton = true,
  });

  @override
  State<GradientScaffold> createState() => _GradientScaffoldState();
}

class _GradientScaffoldState extends State<GradientScaffold> {
  bool _isTitleExpanded = false;
  final GlobalKey _titleKey = GlobalKey();

  void _handlePointerDown(PointerDownEvent event) {
    if (!_isTitleExpanded) return;
    final renderBox =
        _titleKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final bounds = position & size;
      if (bounds.contains(event.position)) {
        return;
      }
    }
    setState(() {
      _isTitleExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return Listener(
      onPointerDown: _handlePointerDown,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Анимированный фон на весь экран (пузырьки)
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
            Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: _buildHeader(context),
                ),
                // Единая плашка отсутствия интернета
                ValueListenableBuilder<bool>(
                  valueListenable: NetworkService.isOnlineNotifier,
                  builder: (context, isOnline, _) {
                    if (isOnline) return const SizedBox.shrink();
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      color: Colors.orange.shade800,
                      child: const Row(
                        children: [
                          Icon(Icons.wifi_off, color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Нет подключения к интернету. Просмотр кэшированных данных.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.useTransparentBody
                          ? Colors.transparent
                          : theme.colorScheme.surface,
                      borderRadius: widget.useTransparentBody
                          ? BorderRadius.zero
                          : const BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(32),
                            ),
                    ),
                    child: ClipRRect(
                      borderRadius: widget.useTransparentBody
                          ? BorderRadius.zero
                          : const BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(32),
                            ),
                      child: widget.useAdaptive && isDesktop
                          ? Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 480),
                                child: widget.body,
                              ),
                            )
                          : widget.body,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: widget.bottomNavBar,
        floatingActionButton: widget.floatingActionButton,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (widget.appBarCustomHeader != null) {
      final isDesktop = MediaQuery.of(context).size.width >= 900;
      return SizedBox(
        height: 56,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24 : 8,
          ),
          child: widget.appBarCustomHeader!,
        ),
      );
    }
    if (widget.appBarTitle == null) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 24 : 8,
          vertical: _isTitleExpanded ? 6 : 0,
        ),
        child: Row(
          crossAxisAlignment: _isTitleExpanded
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            // Кнопка «назад» (если есть) — слева от логотипа
            if (widget.appBarLeading != null)
              widget.appBarLeading!
            else if (widget.showBackButton && Navigator.canPop(context))
              IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            // Логотип
            Padding(
              padding: EdgeInsets.only(top: _isTitleExpanded ? 2.0 : 0.0),
              child: Image.network(
                'https://savt.by/wp-content/uploads/2025/10/logo-small.png',
                height: 48,
                width: 48,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  height: 48,
                  width: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.business, size: 26, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Название страницы (займёт всё доступное пространство)
            Expanded(
              child: GestureDetector(
                key: _titleKey,
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _isTitleExpanded = !_isTitleExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    widget.appBarTitle!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: _isTitleExpanded ? null : 1,
                    overflow: _isTitleExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            if (widget.appBarAction != null)
              Padding(
                padding: EdgeInsets.only(top: _isTitleExpanded ? 2.0 : 0.0),
                child: widget.appBarAction!,
              ),
          ],
        ),
      ),
    );
  }
}
