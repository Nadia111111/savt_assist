// lib/services/offline_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'network_service.dart';
import 'db_service.dart';
import '../main.dart'; // Для глобального chatService

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  final List<Map<String, dynamic>> _messageQueue = [];
  final List<Map<String, dynamic>> _downloadQueue = [];
  final List<Map<String, dynamic>> _serviceRequestQueue = [];
  bool _isOnline = true;
  Timer? _connectionTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Кэш для ранее загруженных данных
  static final Map<String, dynamic> _cache = {};

  // Счетчик непрочитанных уведомлений
  static final ValueNotifier<int> unreadNotificationCount = ValueNotifier(0);

  // Счетчик непрочитанных сообщений в чатах
  static final ValueNotifier<int> unreadChatCount = ValueNotifier(0);

  // Оповещение об успешной синхронизации сообщения (передает tempId)
  final ValueNotifier<String?> syncCompletedNotifier = ValueNotifier(null);

  // Счетчик отложенных действий в очереди
  static final ValueNotifier<int> pendingActionCount = ValueNotifier(0);

  // Оповещение о конфликте синхронизации
  static final ValueNotifier<String?> syncConflictNotifier = ValueNotifier(null);

  // Оповещение о превышении лимита очереди
  static final ValueNotifier<String?> queueLimitNotifier = ValueNotifier(null);

  // Максимальный размер очереди
  static const int maxQueueSize = 100;

  // Количество отправленных действий после синхронизации (для toast)
  static final ValueNotifier<int> syncedCountNotifier = ValueNotifier(0);

  void start() {
    _connectionTimer?.cancel();
    _startConnectivityListener();
    _connectionTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      bool newStatus = false;
      if (kIsWeb) {
        newStatus = true;
      } else {
        try {
          final socket = await Socket.connect('helper.savt.by', 443, timeout: const Duration(seconds: 3));
          socket.destroy();
          newStatus = true;
        } catch (_) {
          newStatus = false;
        }
      }
      
      if (newStatus != _isOnline) {
        _isOnline = newStatus;
        NetworkService.setOnline(newStatus);
        if (_isOnline) {
          _processQueues();
        }
      }
    });
    _loadMessageQueue();
    _loadServiceRequestQueue();
    // Пересчитать счетчик pending-действий после загрузки очередей
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pendingActionCount.value = totalQueueSize;
    });
  }

  /// Слушатель изменений подключения через connectivity_plus
  void _startConnectivityListener() {
    if (kIsWeb) return;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.none) {
        // Мгновенно переводим в offline
        if (_isOnline) {
          _isOnline = false;
          NetworkService.setOnline(false);
        }
      } else {
        // Интернет есть — проверим доступность хоста через socket
        _checkSocketConnection();
      }
    });
  }

  /// Проверка подключения через socket к серверу
  Future<void> _checkSocketConnection() async {
    if (kIsWeb) {
      if (!_isOnline) {
        _isOnline = true;
        NetworkService.setOnline(true);
        _processQueues();
      }
      return;
    }
    try {
      final socket = await Socket.connect('helper.savt.by', 443, timeout: const Duration(seconds: 3));
      socket.destroy();
      if (!_isOnline) {
        _isOnline = true;
        NetworkService.setOnline(true);
        _processQueues();
      }
    } catch (_) {
      if (_isOnline) {
        _isOnline = false;
        NetworkService.setOnline(false);
      }
    }
  }

  void stop() {
    _connectionTimer?.cancel();
    _connectivitySubscription?.cancel();
  }

  bool get isOnline => _isOnline;

  // Оффлайн-очередь сообщений
  void addMessageToQueue(String chatId, String tempId, String text, String time, {int? replyToId}) {
    if (totalQueueSize >= maxQueueSize) {
      queueLimitNotifier.value = 'Очередь действий переполнена ($maxQueueSize). Очистите очередь или дождитесь синхронизации.';
      return;
    }
    _messageQueue.add({
      'chatId': chatId,
      'tempId': tempId,
      'text': text,
      'time': time,
      if (replyToId != null) 'replyToId': replyToId,
      'timestamp': DateTime.now().toIso8601String(),
    });
    _saveMessageQueue();
    pendingActionCount.value = totalQueueSize;
  }

  bool removeMessageFromQueue(String chatId, String tempId) {
    final beforeLength = _messageQueue.length;
    _messageQueue.removeWhere((m) => m['chatId'] == chatId && m['tempId'] == tempId);
    _saveMessageQueue();
    if (_messageQueue.length < beforeLength) {
      pendingActionCount.value = totalQueueSize;
      return true;
    }
    return false;
  }

  List<Map<String, dynamic>> getPendingMessagesForChat(String chatId) {
    return _messageQueue.where((m) => m['chatId'] == chatId).toList();
  }

  void addDownloadToQueue(String docId, String docName, String shuId) {
    _downloadQueue.add({
      'docId': docId,
      'docName': docName,
      'shuId': shuId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  int get totalQueueSize =>
      _messageQueue.length +
      _downloadQueue.length +
      _serviceRequestQueue.length;

  List<Map<String, dynamic>> get pendingMessages =>
      List.unmodifiable(_messageQueue);

  List<Map<String, dynamic>> get pendingDownloads =>
      List.unmodifiable(_downloadQueue);

  List<Map<String, dynamic>> get pendingServiceRequests =>
      List.unmodifiable(_serviceRequestQueue);

  /// Проверить конфликт синхронизации между кэшом и сервером
  /// Использует серверные данные как приоритетные
  Future<bool> checkSyncConflicts(
    Map<String, dynamic> local,
    Map<String, dynamic> server,
  ) async {
    final localUpdatedAt = local['updated_at'] ?? local['last_updated'];
    final serverUpdatedAt = server['updated_at'] ?? server['last_updated'];

    if (localUpdatedAt != null && serverUpdatedAt != null) {
      final localTime = DateTime.tryParse(localUpdatedAt.toString());
      final serverTime = DateTime.tryParse(serverUpdatedAt.toString());

      if (localTime != null && serverTime != null) {
        if (serverTime.isAfter(localTime)) {
          syncConflictNotifier.value =
              'Данные на сервере изменены. Обновлены серверные данные.';
          return true;
        }
      }
    }
    return false;
  }

  Future<bool> hasAnyCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCategories = prefs.getString('kb_categories') != null;
      final hasFaq = prefs.getString('faq_categories') != null;
      final hasCabinets = prefs.getString('cabinets_list') != null;
      final hasDocuments = prefs.getString('cabinet_documents_') != null ||
          prefs.getString('all_user_documents') != null;
      
      final db = await DbService.instance.database;
      final msgMaps = await db.query('messages', limit: 1);
      final hasMessages = msgMaps.isNotEmpty;
      final cabMaps = await db.query('cabinets', limit: 1);
      final hasCabinetCache = cabMaps.isNotEmpty;
      final docMaps = await db.query('documents', limit: 1);
      final hasDocumentCache = docMaps.isNotEmpty;
      
      return hasCategories || hasFaq || hasCabinets || hasDocuments ||
             hasMessages || hasCabinetCache || hasDocumentCache;
    } catch (_) {
      return false;
    }
  }

  Future<void> _processQueues() async {
    if (_messageQueue.isEmpty &&
        _downloadQueue.isEmpty &&
        _serviceRequestQueue.isEmpty) {
      return;
    }

    int syncedCount = 0;

    if (_messageQueue.isNotEmpty) {
      final List<Map<String, dynamic>> queueCopy = List.from(_messageQueue);
      for (var msg in queueCopy) {
        final chatIdStr = msg['chatId'] ?? '';
        final chatId = int.tryParse(chatIdStr);
        if (chatId == null) continue;
        
        try {
          final text = msg['text'] ?? '';
          final replyToId = msg['replyToId'];
          final tempId = msg['tempId'] ?? '';
          
          final res = await chatService.sendTextMessage(
            chatId,
            text,
            replyToId: replyToId,
            clientToken: tempId.isNotEmpty ? tempId : null,
          );
          
          removeMessageFromQueue(chatIdStr, msg['tempId']);
          
          final cachedMsgs = await DbService.instance.getCachedMessages(chatId) ?? [];
          cachedMsgs.insert(0, res);
          await DbService.instance.cacheMessages(chatId, cachedMsgs);
          
          syncCompletedNotifier.value = msg['tempId'];
          syncedCount++;
        } catch (e) {
          print('Ошибка отправки сообщения из оффлайн-очереди: $e');
        }
      }
    }

    if (_serviceRequestQueue.isNotEmpty) {
      final List<Map<String, dynamic>> reqQueueCopy = List.from(_serviceRequestQueue);
      for (var item in reqQueueCopy) {
        try {
          final cabinetId = item['cabinet_id'];
          final type = item['request_type'] ?? '';
          final desc = item['description'] ?? '';
          final tempId = item['tempId'] ?? '';
          
          await serviceRequestService.createServiceRequest(
            cabinetId: cabinetId,
            requestType: type,
            description: desc,
            clientToken: tempId.isNotEmpty ? tempId : null,
          );
          
          _serviceRequestQueue.removeWhere((x) => 
            x['cabinet_id'] == cabinetId && 
            x['request_type'] == type && 
            x['description'] == desc
          );
          _saveServiceRequestQueue();
          syncedCount++;
        } catch (e) {
          print('Ошибка отправки сервисной заявки из оффлайн-очереди: $e');
        }
      }
    }

    _downloadQueue.clear();
    
    pendingActionCount.value = totalQueueSize;
    if (syncedCount > 0) {
      syncedCountNotifier.value = syncedCount;
    }
    print('Очереди обработаны. Синхронизировано: $syncedCount');
  }

  // Кэширование данных с использованием SharedPreferences
  Future<void> saveCache(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String jsonString;

      if (data is String) {
        jsonString = data;
      } else {
        jsonString = jsonEncode(data);
      }

      await prefs.setString(key, jsonString);
      _cache[key] = data;
    } catch (e) {
      print('Ошибка сохранения кэша: $e');
    }
  }

  Future<dynamic> getCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(key);

      if (jsonString == null) {
        return _cache[key];
      }

      try {
        final parsed = jsonDecode(jsonString);
        _cache[key] = parsed;
        return parsed;
      } catch (_) {
        _cache[key] = jsonString;
        return jsonString;
      }
    } catch (e) {
      print('Ошибка чтения кэша: $e');
      return _cache[key];
    }
  }

  bool hasCachedData(String key) {
    return _cache.containsKey(key);
  }

  // Сохранение очереди сообщений в локальное хранилище
  Future<void> _saveMessageQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueString = jsonEncode(_messageQueue);
      await prefs.setString('message_queue', queueString);
    } catch (e) {
      print('Ошибка сохранения очереди: $e');
    }
  }

  // Загрузка очереди сообщений из локального хранилища
  Future<void> _loadMessageQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueString = prefs.getString('message_queue');

      if (queueString != null) {
        final List<dynamic> parsed = jsonDecode(queueString);
        _messageQueue.clear();
        _messageQueue.addAll(parsed.map((e) => e as Map<String, dynamic>));
      }
    } catch (e) {
      print('Ошибка загрузки очереди: $e');
    }
  }

  // Обновление счетчика непрочитанных уведомлений
  void updateUnreadNotificationCount(int count) {
    unreadNotificationCount.value = count;
  }

  // Обновление счетчика непрочитанных сообщений в чатах
  void updateUnreadChatCount(int count) {
    print('🔵 [OfflineService] updateUnreadChatCount: $count');
    unreadChatCount.value = count;
  }

  // Очистка кэша
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _cache.clear();
    } catch (e) {
      print('Ошибка очистки кэша: $e');
    }
  }

  /// Полное очищение всех очередей
  Future<void> clearAllQueues() async {
    _messageQueue.clear();
    _downloadQueue.clear();
    _serviceRequestQueue.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('message_queue', '[]');
    await prefs.setString('service_request_queue', '[]');
    
    pendingActionCount.value = 0;
  }

  // Удаление конкретного ключа из кэша
  Future<void> removeCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      _cache.remove(key);
    } catch (e) {
      print('Ошибка удаления кэша: $e');
    }
  }

  // Service Request Queue
  void addServiceRequestToQueue(int cabinetId, String requestType, String description) {
    if (totalQueueSize >= maxQueueSize) {
      queueLimitNotifier.value = 'Очередь действий переполнена ($maxQueueSize). Очистите очередь или дождитесь синхронизации.';
      return;
    }
    _serviceRequestQueue.add({
      'cabinet_id': cabinetId,
      'request_type': requestType,
      'description': description,
    });
    _saveServiceRequestQueue();
    pendingActionCount.value = totalQueueSize;
  }

  Future<void> _saveServiceRequestQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('service_request_queue', jsonEncode(_serviceRequestQueue));
    } catch (e) {
      print('Ошибка сохранения очереди заявок: $e');
    }
  }

  Future<void> _loadServiceRequestQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final qStr = prefs.getString('service_request_queue');
      if (qStr != null) {
        final List<dynamic> parsed = jsonDecode(qStr);
        _serviceRequestQueue.clear();
        _serviceRequestQueue.addAll(parsed.map((e) => e as Map<String, dynamic>));
      }
    } catch (_) {}
  }
}
