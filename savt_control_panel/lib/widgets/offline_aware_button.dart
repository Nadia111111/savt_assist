// lib/widgets/offline_aware_button.dart
import 'package:flutter/material.dart';
import '../services/network_service.dart';

class OfflineAwareButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final IconData? icon;
  final bool isLoading;
  final ButtonStyle? style;
  final bool isTextButton;

  const OfflineAwareButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.isLoading = false,
    this.style,
    this.isTextButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: NetworkService.isOnlineNotifier,
      builder: (context, isOnline, child) {
        final buttonOnPressed = isOnline && !isLoading && onPressed != null ? onPressed : null;
        final childWidget = isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) Icon(icon, size: 20),
                  if (icon != null) const SizedBox(width: 8),
                  Text(text),
                  if (!isOnline) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.wifi_off, size: 16),
                  ],
                ],
              );

        if (isTextButton) {
          return TextButton(
            style: style,
            onPressed: buttonOnPressed,
            child: childWidget,
          );
        }

        return ElevatedButton(
          style: style,
          onPressed: buttonOnPressed,
          child: childWidget,
        );
      },
    );
  }
}
