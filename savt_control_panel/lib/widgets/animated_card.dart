import 'package:flutter/material.dart';

class AnimatedCard extends StatelessWidget {
  final Widget child;
  final int index;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final bool isElevated;

  const AnimatedCard({
    super.key,
    required this.child,
    this.index = 0,
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.padding = const EdgeInsets.all(14),
    this.backgroundColor,
    this.isElevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        padding: padding,
        decoration: isElevated
            ? BoxDecoration(
                color: backgroundColor ??
                    theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                    spreadRadius: -4,
                  ),
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              )
            : BoxDecoration(
                color: backgroundColor ?? theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
                    blurRadius: 12,
                    offset: const Offset(-4, -4),
                  ),
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(4, 4),
                  ),
                ],
              ),
        child: child,
      ),
    );
  }
}
