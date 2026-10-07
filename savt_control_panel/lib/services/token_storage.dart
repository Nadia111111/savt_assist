// lib/services/token_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class TokenStorage {
  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  String? _memoryAccessToken;
  String? _memoryRefreshToken;
  bool _isGuestMode = false;

  bool get useSecureStorage => true;

  bool get isGuestMode => _isGuestMode;

  Future<void> saveTokens(String access, String refresh, {bool rememberMe = true}) async {
    try {
      _memoryAccessToken = access;
      _memoryRefreshToken = refresh;
      _isGuestMode = false;

      // 1. Write to secure storage
      try {
        await _secureStorage.write(key: _accessKey, value: access);
        await _secureStorage.write(key: _refreshKey, value: refresh);
      } catch (ex) {
        debugPrint('⚠️ Secure storage write error: $ex');
      }

      // 2. Also persist to SharedPreferences as a reliable fallback against Android Keystore issues
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_accessKey, access);
        await prefs.setString(_refreshKey, refresh);
      } catch (ex) {
        debugPrint('⚠️ SharedPreferences write error: $ex');
      }

      debugPrint('✅ Tokens saved successfully');
    } catch (ex) {
      debugPrint('❌ TokenStorage write error: $ex');
      rethrow;
    }
  }

  Future<void> saveGuestToken(String accessToken) async {
    _memoryAccessToken = accessToken;
    _memoryRefreshToken = null;
    _isGuestMode = true;
    debugPrint('✅ Guest token saved in memory');
  }

  Future<void> clearGuestToken() async {
    _memoryAccessToken = null;
    _memoryRefreshToken = null;
    _isGuestMode = false;
    debugPrint('✅ Guest token cleared');
  }

  Future<String?> getAccessToken() async {
    if (_memoryAccessToken != null && _memoryAccessToken!.isNotEmpty) {
      return _memoryAccessToken;
    }
    String? token;
    try {
      token = await _secureStorage.read(key: _accessKey);
    } catch (e) {
      debugPrint('❌ TokenStorage read access error: $e');
    }
    if (token == null || token.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString(_accessKey);
      } catch (_) {}
    }
    if (token != null && token.isNotEmpty) {
      _memoryAccessToken = token;
    }
    return token;
  }

  Future<String?> getRefreshToken() async {
    if (_memoryRefreshToken != null && _memoryRefreshToken!.isNotEmpty) {
      return _memoryRefreshToken;
    }
    String? token;
    try {
      token = await _secureStorage.read(key: _refreshKey);
    } catch (e) {
      debugPrint('❌ TokenStorage read refresh error: $e');
    }
    if (token == null || token.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString(_refreshKey);
      } catch (_) {}
    }
    if (token != null && token.isNotEmpty) {
      _memoryRefreshToken = token;
    }
    return token;
  }

  Future<String?> getGuestToken() async {
    return _memoryAccessToken;
  }

  Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: _accessKey);
      await _secureStorage.delete(key: _refreshKey);
    } catch (e) {
      debugPrint('❌ TokenStorage delete error: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessKey);
      await prefs.remove(_refreshKey);
    } catch (_) {}
    _memoryAccessToken = null;
    _memoryRefreshToken = null;
    _isGuestMode = false;
    debugPrint('✅ Tokens cleared');
  }
}