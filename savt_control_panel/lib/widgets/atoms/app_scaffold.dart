import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool centerTitle;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final PreferredSizeWidget? appBar;
  final bool resizeToAvoidBottomInset;

  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.centerTitle = true,
    this.showBackButton = false,
    this.onBackPressed,
    this.backgroundColor,
    this.padding,
    this.appBar,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final effectiveAppBar = appBar ??
        (title != null || actions != null || showBackButton
            ? AppBar(
                title: title != null ? Text(title!) : null,
                centerTitle: centerTitle,
                actions: actions,
                leading: showBackButton
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: onBackPressed ??
                            () => Navigator.of(context).maybePop(),
                      )
                    : null,
                elevation: 0,
                backgroundColor: cs.surface,
                foregroundColor: cs.onSurface,
              )
            : null);

    return Scaffold(
      appBar: effectiveAppBar,
      backgroundColor: backgroundColor ?? cs.surface,
      body: SafeArea(
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpacing.base),
          child: body,
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}
