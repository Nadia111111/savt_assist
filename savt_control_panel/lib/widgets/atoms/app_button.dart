import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum AppButtonVariant { filled, outlined, text }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? icon;
  final bool fullWidth;
  final bool isLoading;
  final Color? color;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.icon,
    this.fullWidth = true,
    this.isLoading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primary = color ?? AppColors.primary;

    Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == AppButtonVariant.filled
                    ? Colors.white
                    : primary,
              ),
            ),
          )
        else if (icon != null)
          icon!,
        if (!isLoading && icon != null) const SizedBox(width: 8),
        Text(text),
      ],
    );

    if (variant == AppButtonVariant.filled) {
      return AnimatedScale(
        scale: onPressed == null ? 1.0 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: fullWidth ? const Size(double.infinity, 48) : null,
          ),
          child: child,
        ),
      );
    }

    if (variant == AppButtonVariant.outlined) {
      return AnimatedScale(
        scale: onPressed == null ? 1.0 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: BorderSide(color: primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: fullWidth ? const Size(double.infinity, 48) : null,
          ),
          child: child,
        ),
      );
    }

    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: primary,
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: child,
    );
  }
}
