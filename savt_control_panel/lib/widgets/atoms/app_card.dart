import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? customShadows;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.borderRadius,
    this.customShadows,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final radius = borderRadius ?? BorderRadius.circular(20);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? (isLight ? AppColors.lightCard : AppColors.darkCard),
          borderRadius: radius,
          boxShadow: customShadows ??
              [
                BoxShadow(
                  color: (isLight ? Colors.black : AppColors.darkText)
                      .withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
              ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          child: child,
        ),
      ),
    );
  }
}
