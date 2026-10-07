import 'package:flutter/widgets.dart';

class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const base = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

const gapH4 = SizedBox(height: AppSpacing.xs);
const gapH8 = SizedBox(height: AppSpacing.sm);
const gapH12 = SizedBox(height: AppSpacing.md);
const gapH16 = SizedBox(height: AppSpacing.base);
const gapH20 = SizedBox(height: AppSpacing.lg);
const gapH24 = SizedBox(height: AppSpacing.xl);
const gapH32 = SizedBox(height: AppSpacing.xxl);

const gapW4 = SizedBox(width: AppSpacing.xs);
const gapW8 = SizedBox(width: AppSpacing.sm);
const gapW12 = SizedBox(width: AppSpacing.md);
const gapW16 = SizedBox(width: AppSpacing.base);
const gapW20 = SizedBox(width: AppSpacing.lg);
const gapW24 = SizedBox(width: AppSpacing.xl);
const gapW32 = SizedBox(width: AppSpacing.xxl);
