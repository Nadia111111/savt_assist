import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

/// Базовый шиммер-блок для построения скелетонов.
class ShimmerBlock extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const ShimmerBlock({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ).shimmer(context);
  }
}

extension ShimmerExtension on Widget {
  Widget shimmer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1A2332) : const Color(0xFFE2E8F0),
      highlightColor: isDark ? const Color(0xFF243247) : const Color(0xFFF1F5F9),
      period: const Duration(milliseconds: 1200),
      child: this,
    );
  }
}

/// Скелетон карточки списка (чаты, ШУ, документы, заявки).
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          ShimmerBlock(
            width: 52,
            height: 52,
            borderRadius: 16,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBlock(
                  width: 160,
                  height: 14,
                  borderRadius: 7,
                ),
                SizedBox(height: 10),
                ShimmerBlock(
                  width: 240,
                  height: 12,
                  borderRadius: 6,
                ),
                SizedBox(height: 10),
                ShimmerBlock(
                  width: 100,
                  height: 10,
                  borderRadius: 5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Скелетон списка карточек.
class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (context, index) => const SkeletonCard(),
    );
  }
}

/// Скелетон страницы деталей (заголовок + блоки).
class SkeletonDetail extends StatelessWidget {
  const SkeletonDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ShimmerBlock(height: 200, borderRadius: 20),
        SizedBox(height: 16),
        ShimmerBlock(height: 24, width: 200, borderRadius: 8),
        SizedBox(height: 16),
        ShimmerBlock(height: 80, borderRadius: 16),
        SizedBox(height: 12),
        ShimmerBlock(height: 80, borderRadius: 16),
        SizedBox(height: 12),
        ShimmerBlock(height: 80, borderRadius: 16),
      ],
    ).shimmer(context);
  }
}

/// Скелетон сетки плиток (документы, медиа).
class SkeletonGrid extends StatelessWidget {
  final int count;
  const SkeletonGrid({super.key, this.count = 8});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: count,
      itemBuilder: (context, index) =>
          const ShimmerBlock(borderRadius: 16),
    );
  }
}
