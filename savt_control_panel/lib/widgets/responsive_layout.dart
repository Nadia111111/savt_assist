// lib/widgets/responsive_layout.dart
import 'package:flutter/material.dart';

/// Хелпер для определения типа экрана
class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 900;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  static double getContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 900 ? 480 : width;
  }

  static EdgeInsets getHorizontalPadding(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    return EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16);
  }

  static int getGridCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 3;
    if (width >= 900) return 2;
    return 1;
  }

  static double getCardMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 900) return 480;
    return width - 32;
  }
}

/// Адаптивный обёрточный виджет для ограничения ширины контента на десктопе.
/// На мобильных экранах (< 900px) контент занимает всю ширину.
/// На десктопе контент центрируется с максимальной шириной 480px.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool fullHeight;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 480,
    this.padding,
    this.fullHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    Widget content = child;

    // Добавляем отступы если указаны
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    if (isDesktop) {
      // На десктопе центрируем с ограничением ширины
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: content,
        ),
      );
    }

    // На мобильных просто возвращаем контент
    return content;
  }
}

/// Адаптивный отступ, который может отличаться на десктопе
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry mobilePadding;
  final EdgeInsetsGeometry? desktopPadding;

  const ResponsivePadding({
    super.key,
    required this.child,
    required this.mobilePadding,
    this.desktopPadding,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final padding = isDesktop ? (desktopPadding ?? mobilePadding) : mobilePadding;

    return Padding(padding: padding, child: child);
  }
}
