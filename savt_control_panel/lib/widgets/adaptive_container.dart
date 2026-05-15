// lib/widgets/adaptive_container.dart
import 'package:flutter/material.dart';

/// Адаптивный контейнер для ограничения ширины контента на десктопе.
/// На мобильных экранах (< 900px) работает как проходной контейнер.
/// На десктопе центрирует контент с максимальной шириной 480px.
class AdaptiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const AdaptiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 480,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900; // меняем порог с 600 на 900

    if (isMobile) {
      // На мобильных/планшетах не ограничиваем
      if (padding != null) {
        return Padding(padding: padding!, child: child);
      }
      return child;
    }

    // На больших десктопах центрируем
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child:
            padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );
  }
}

/// Адаптивный виджет для отступов, который на десктопе может уменьшать
/// горизонтальные отступы.
class AdaptivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry mobilePadding;
  final EdgeInsetsGeometry? desktopPadding;

  const AdaptivePadding({
    super.key,
    required this.child,
    required this.mobilePadding,
    this.desktopPadding,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900; // тоже меняем

    return Padding(
      padding: isMobile ? mobilePadding : (desktopPadding ?? mobilePadding),
      child: child,
    );
  }
}
