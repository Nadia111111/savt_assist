// lib/services/offline_service.dart
import 'dart:async';
import 'dart:math';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  final List<Map<String, dynamic>> _messageQueue = [];
  final List<Map<String, dynamic>> _downloadQueue =
      []; // очередь загрузок документов
  bool _isOnline = true;
  Timer? _connectionTimer;

  // Кэш для ранее загруженных данных (мок-хранилище)
  static final Map<String, dynamic> _cache = {};

  void start() {
    _connectionTimer?.cancel();
    _connectionTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final newStatus = Random().nextDouble() > 0.1;
      if (newStatus != _isOnline) {
        _isOnline = newStatus;
        // При восстановлении сети обрабатываем очереди
        if (_isOnline) {
          _processQueues();
        }
      }
    });
  }

  void stop() {
    _connectionTimer?.cancel();
  }

  bool get isOnline => _isOnline;

  void addToQueue(String chatId, String text, String time) {
    _messageQueue.add({
      'chatId': chatId,
      'text': text,
      'time': time,
    });
  }

  // Добавление документа в очередь загрузок
  void addDownloadToQueue(String docId, String docName, String shuId) {
    _downloadQueue.add({
      'docId': docId,
      'docName': docName,
      'shuId': shuId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  List<Map<String, dynamic>> get pendingMessages =>
      List.unmodifiable(_messageQueue);

  List<Map<String, dynamic>> get pendingDownloads =>
      List.unmodifiable(_downloadQueue);

  void _processQueues() {
    if (_messageQueue.isEmpty && _downloadQueue.isEmpty) return;

    // Обработка очереди сообщений (заглушка)
    _messageQueue.clear();

    // Обработка очереди загрузок (заглушка)
    _downloadQueue.clear();

    print('Очереди обработаны');
  }

  // Кэширование данных
  void cacheData(String key, dynamic data) {
    _cache[key] = data;
  }

  dynamic getCachedData(String key) {
    return _cache[key];
  }

  bool hasCachedData(String key) {
    return _cache.containsKey(key);
  }
}
