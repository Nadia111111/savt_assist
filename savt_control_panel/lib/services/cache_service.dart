// lib/services/cache_service.dart
import 'package:flutter/foundation.dart';
import '../widgets/auth_image.dart';
import 'db_service.dart';
import 'offline_service.dart';

/// Детализация размеров кэша по категориям
class AppCacheBreakdown {
  final int imageBytes;
  final int databaseBytes;
  final int offlineDataBytes;

  const AppCacheBreakdown({
    required this.imageBytes,
    required this.databaseBytes,
    required this.offlineDataBytes,
  });

  int get totalBytes => imageBytes + databaseBytes + offlineDataBytes;

  static const AppCacheBreakdown empty = AppCacheBreakdown(
    imageBytes: 0,
    databaseBytes: 0,
    offlineDataBytes: 0,
  );
}

/// Сервис комплексного управления кэшем приложения
class AppCacheService {
  static final AppCacheService instance = AppCacheService._();
  AppCacheService._();

  /// Форматирование байтов в читаемый вид (Б, КБ, МБ)
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 КБ';
    if (bytes < 1024) {
      return '$bytes Б';
    } else if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(1)} КБ';
    } else {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} МБ';
    }
  }

  /// Получить детальную информацию по всем видам кэша
  Future<AppCacheBreakdown> getBreakdown() async {
    try {
      final results = await Future.wait([
        AuthImage.getDiskCacheSizeBytes()
            .timeout(const Duration(seconds: 2), onTimeout: () => 0),
        DbService.instance
            .getDatabaseSizeBytes()
            .timeout(const Duration(seconds: 2), onTimeout: () => 0),
        OfflineService()
            .getDataCacheSizeBytes()
            .timeout(const Duration(seconds: 2), onTimeout: () => 0),
      ]);

      return AppCacheBreakdown(
        imageBytes: results[0],
        databaseBytes: results[1],
        offlineDataBytes: results[2],
      );
    } catch (e) {
      debugPrint('Error calculating cache breakdown: $e');
      return AppCacheBreakdown.empty;
    }
  }

  /// Очистить выбранные категории кэша
  Future<void> clearSelected({
    bool clearImages = true,
    bool clearDatabase = true,
    bool clearOfflineData = true,
  }) async {
    final futures = <Future<void>>[];
    if (clearImages) {
      futures.add(AuthImage.clearDiskCache()
          .timeout(const Duration(seconds: 3), onTimeout: () {}));
    }
    if (clearDatabase) {
      futures.add(DbService.instance
          .clearAllCache()
          .timeout(const Duration(seconds: 3), onTimeout: () {}));
    }
    if (clearOfflineData) {
      futures.add(OfflineService()
          .clearDataCache()
          .timeout(const Duration(seconds: 3), onTimeout: () {}));
    }
    await Future.wait(futures);
  }
}
