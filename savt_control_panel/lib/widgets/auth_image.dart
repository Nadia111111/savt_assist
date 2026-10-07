// lib/widgets/auth_image.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import '../main.dart'; // uploadService

class AuthImage extends StatefulWidget {
  final String url;
  final BoxFit fit;

  static final Map<String, Uint8List> _imageCache = {};

  const AuthImage({super.key, required this.url, this.fit = BoxFit.cover});

  static String _cleanUrl(String url) {
    return url.split('?').first;
  }

  static void cacheBytes(String url, Uint8List bytes) {
    final clean = _cleanUrl(url);
    _imageCache[clean] = bytes;
  }

  static Uint8List? getCachedBytes(String url) {
    final clean = _cleanUrl(url);
    return _imageCache[clean];
  }

  static Future<String> _getCachePath(String url) async {
    final dir = await getApplicationDocumentsDirectory();
    final clean = _cleanUrl(url);
    final hash = md5.convert(utf8.encode(clean)).toString();
    return '${dir.path}/image_cache/$hash';
  }

  static Future<void> _saveToDisk(String url, Uint8List bytes) async {
    try {
      final path = await _getCachePath(url);
      final file = File(path);
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      await _checkAndEvictCache();
    } catch (e) {
      debugPrint('Error saving image to disk cache: $e');
    }
  }

  static Future<Uint8List?> _loadFromDisk(String url) async {
    try {
      final path = await _getCachePath(url);
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('Error loading image from disk cache: $e');
    }
    return null;
  }

  static Future<void> clearDiskCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/image_cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      _imageCache.clear();
    } catch (e) {
      debugPrint('Error clearing disk cache: $e');
    }
  }

  static Future<String> getCacheSize() async {
    final mb = await getDiskCacheSizeMB();
    return '${mb.toStringAsFixed(1)} МБ';
  }

  static Future<double> getDiskCacheSizeMB() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/image_cache');
      if (!await cacheDir.exists()) return 0.0;

      final files = await cacheDir.list().toList();
      int totalSize = 0;
      for (final entity in files) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize / (1024 * 1024);
    } catch (_) {
      return 0.0;
    }
  }

  static Future<void> _checkAndEvictCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/image_cache');
      if (!await cacheDir.exists()) return;

      final files = await cacheDir.list().toList();
      int totalSize = 0;
      final List<File> fileList = [];

      for (final entity in files) {
        if (entity is File) {
          totalSize += await entity.length();
          fileList.add(entity);
        }
      }

      const int maxCacheSize = 50 * 1024 * 1024; // 50 MB
      if (totalSize > maxCacheSize) {
        final List<MapEntry<File, DateTime>> filesWithTime = [];
        for (final file in fileList) {
          final stat = await file.stat();
          filesWithTime.add(MapEntry(file, stat.modified));
        }
        filesWithTime.sort((a, b) => a.value.compareTo(b.value));

        int currentSize = totalSize;
        for (final entry in filesWithTime) {
          if (currentSize <= maxCacheSize) break;
          final size = await entry.key.length();
          await entry.key.delete();
          currentSize -= size;
        }
      }
    } catch (e) {
      debugPrint('Error evicting image cache: $e');
    }
  }

  @override
  State<AuthImage> createState() => _AuthImageState();
}

class _AuthImageState extends State<AuthImage> {
  late Future<Uint8List> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _loadImage();
  }

  Future<Uint8List> _loadImage() async {
    final cleanUrl = AuthImage._cleanUrl(widget.url);
    // 1. Check memory cache first
    if (AuthImage._imageCache.containsKey(cleanUrl)) {
      return AuthImage._imageCache[cleanUrl]!;
    }

    // 2. Check disk cache
    final cachedBytes = await AuthImage._loadFromDisk(widget.url);
    if (cachedBytes != null) {
      AuthImage._imageCache[cleanUrl] = cachedBytes;
      return cachedBytes;
    }

    // 3. Load from network
    try {
      final bytes = await uploadService.downloadFile(widget.url);
      final uint8list = Uint8List.fromList(bytes);

      // Save to disk and memory caches
      await AuthImage._saveToDisk(widget.url, uint8list);
      AuthImage._imageCache[cleanUrl] = uint8list;

      return uint8list;
    } catch (e) {
      debugPrint('Error downloading auth image: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = AuthImage._cleanUrl(widget.url);
    if (AuthImage._imageCache.containsKey(cleanUrl)) {
      return Image.memory(AuthImage._imageCache[cleanUrl]!, fit: widget.fit);
    }

    return FutureBuilder<Uint8List>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snapshot.hasError) {
          return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
        }
        if (snapshot.hasData) {
          return Image.memory(snapshot.data!, fit: widget.fit);
        }
        return const SizedBox();
      },
    );
  }
}
