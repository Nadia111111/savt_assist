// lib/services/chat_service.dart - ПОЛНЫЙ КОД
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'api_client.dart';
import 'db_service.dart';
import 'offline_service.dart'; // Для кэширования через OfflineService

class ChatService {
  final ApiClient _apiClient;
  final OfflineService _offlineService = OfflineService();

  ChatService(this._apiClient);

  Future<List<Map<String, dynamic>>> getChats({
    String? chatType,
    bool? archived,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (chatType != null && chatType.isNotEmpty) query['chat_type'] = chatType;
      // Отправляем archived только если true, так как по умолчанию на бэкенде false
      if (archived == true) query['archived'] = true;

      print('🔵 [ChatService] GET /chats chatType=$chatType archived=$archived query=$query');

      Response response;
      try {
        response = await _apiClient.dio.get(
          '/chats',
          queryParameters: query.isEmpty ? null : query,
        );
      } on DioException catch (dioErr) {
        // Если 500 при наличии query-параметров, пробуем чистый GET /chats без параметров
        if (dioErr.response?.statusCode == 500 && query.isNotEmpty) {
          print('⚠️ [ChatService] /chats с параметрами вернул 500, пробуем без параметров...');
          try {
            response = await _apiClient.dio.get('/chats');
          } catch (_) {
            // Проверяем роль: оператор ли это
            bool isOperator = false;
            try {
              final authMe = await OfflineService().getCache('user_me');
              final role = authMe is Map ? authMe['role']?.toString() : null;
              isOperator = role == 'operator' || role == 'admin';
            } catch (_) {}

            if (isOperator) {
              try {
                response = await _apiClient.dio.get(
                  '/operator/chats',
                  queryParameters: query.isEmpty ? null : query,
                );
              } catch (_) {
                throw dioErr;
              }
            } else {
              throw dioErr;
            }
          }
        } else if (dioErr.response?.statusCode == 500 ||
                   dioErr.response?.statusCode == 404) {
          // Проверяем роль: для обычного пользователя НИКОГДА не дергаем /operator/chats,
          // чтобы сервер не возвращал 403 "Недостаточно прав"
          bool isOperator = false;
          try {
            final authMe = await OfflineService().getCache('user_me');
            final role = authMe is Map ? authMe['role']?.toString() : null;
            isOperator = role == 'operator' || role == 'admin';
          } catch (_) {}

          if (isOperator) {
            try {
              print('⚠️ [ChatService] пользователь оператор, пробуем fallback /operator/chats...');
              response = await _apiClient.dio.get(
                '/operator/chats',
                queryParameters: query.isEmpty ? null : query,
              );
            } catch (_) {
              throw dioErr;
            }
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      final data = response.data;
      print('🟢 [ChatService] GET /chats response type=${data.runtimeType}');

      List<Map<String, dynamic>> result = [];
      if (data is List) {
        result = data.map((e) {
          if (e is Map) return Map<String, dynamic>.from(e);
          return <String, dynamic>{};
        }).toList();
      } else if (data is Map) {
        final list = data['items'] ?? data['data'] ?? data['chats'];
        if (list is List) {
          result = list.map((e) {
            if (e is Map) return Map<String, dynamic>.from(e);
            return <String, dynamic>{};
          }).toList();
        }
      }

      // Если параметры не передавались на сервер или запрос был fallback-ом, фильтруем локально
      if (chatType != null && chatType.isNotEmpty) {
        result = result.where((c) => c['chat_type'] == chatType).toList();
      }
      if (archived == true) {
        result = result
            .where((c) => c['archived_at'] != null || c['is_archived'] == true)
            .toList();
      }

      print('🔵 [ChatService] getChats result count=${result.length}');
      // Кэшируем список чатов
      await _cacheChats(result);
      return result;
    } on DioException catch (e) {
      // Возвращаем кэш при ошибке сервера или сети
      final cached = await getCachedChatsFallback(chatType: chatType, archived: archived);
      if (cached.isNotEmpty) {
        print('🟡 [ChatService] Используем кэш чатов (${cached.length} чатов) из-за ошибки сети/сервера: ${e.response?.statusCode}');
        return cached;
      }
      throw _handleError(e);
    } catch (e) {
      final cached = await getCachedChatsFallback(chatType: chatType, archived: archived);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  /// Кэшировать список чатов
  Future<void> _cacheChats(List<Map<String, dynamic>> chats) async {
    try {
      await _offlineService.saveCache('user_chats', chats);

      if (kIsWeb) return;

      // Также кэшируем каждый чат по chatId в SQLite
      final db = await DbService.instance.database;
      final batch = db.batch();
      for (var chat in chats) {
        final chatId = chat['id']?.toString() ?? '';
        if (chatId.isNotEmpty) {
          batch.insert(
            'messages',
            {
              'message_id': 'chat_meta_$chatId',
              'chat_id': int.tryParse(chatId) ?? 0,
              'data': jsonEncode(chat),
              'created_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await batch.commit(noResult: true);
    } catch (e) {
      print('Ошибка кэширования чатов: $e');
    }
  }

  /// Получить кэшированный список чатов
  Future<List<Map<String, dynamic>>?> _getCachedChats() async {
    try {
      final cached = await _offlineService.getCache('user_chats');
      if (cached != null && cached is List && cached.isNotEmpty) {
        return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}

    try {
      final db = await DbService.instance.database;
      final rows = await db.query(
        'messages',
        where: "message_id LIKE 'chat_meta_%'",
        orderBy: 'created_at DESC',
      );
      if (rows.isNotEmpty) {
        final list = <Map<String, dynamic>>[];
        for (final r in rows) {
          try {
            final dataStr = r['data'] as String?;
            if (dataStr != null) {
              final parsed = jsonDecode(dataStr);
              if (parsed is Map) {
                list.add(Map<String, dynamic>.from(parsed));
              }
            }
          } catch (_) {}
        }
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    return null;
  }

  /// Получить кэшированный список чатов с локальной фильтрацией
  Future<List<Map<String, dynamic>>> getCachedChatsFallback({
    String? chatType,
    bool? archived,
  }) async {
    final cached = await _getCachedChats();
    if (cached == null || cached.isEmpty) return [];
    var result = List<Map<String, dynamic>>.from(cached);
    if (chatType != null && chatType.isNotEmpty) {
      result = result.where((c) => c['chat_type'] == chatType).toList();
    }
    if (archived == true) {
      result = result
          .where((c) => c['archived_at'] != null || c['is_archived'] == true)
          .toList();
    }
    return result;
  }

  /// Локально обновить статус закрепа в кэше
  Future<void> updateLocalChatPinned(int chatId, bool isPinned) async {
    try {
      final cached = await _getCachedChats();
      if (cached != null && cached.isNotEmpty) {
        final updated = cached.map((c) {
          final cId = c['id'] is num ? c['id'].toInt() : int.tryParse(c['id']?.toString() ?? '');
          if (cId == chatId) {
            final m = Map<String, dynamic>.from(c);
            m['is_pinned'] = isPinned;
            m['pinned'] = isPinned;
            return m;
          }
          return c;
        }).toList();
        await _offlineService.saveCache('user_chats', updated);
      }

      final db = await DbService.instance.database;
      final rows = await db.query(
        'messages',
        where: 'message_id = ?',
        whereArgs: ['chat_meta_$chatId'],
      );
      if (rows.isNotEmpty) {
        final dataStr = rows.first['data'] as String?;
        if (dataStr != null) {
          final data = jsonDecode(dataStr);
          if (data is Map) {
            final m = Map<String, dynamic>.from(data);
            m['is_pinned'] = isPinned;
            m['pinned'] = isPinned;
            await db.update(
              'messages',
              {'data': jsonEncode(m)},
              where: 'message_id = ?',
              whereArgs: ['chat_meta_$chatId'],
            );
          }
        }
      }
    } catch (e) {
      print('Ошибка локального обновления закрепа: $e');
    }
  }

  Future<Map<String, dynamic>> getCabinetChat(int cabinetId) async {
    try {
      final response = await _apiClient.dio.get('/cabinets/$cabinetId/chat');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>?> getMessages(
    int chatId, {
    int? beforeId,
    int? aroundId,
    int limit = 30,
  }) async {
    try {
      final query = <String, dynamic>{'limit': limit};
      if (beforeId != null) query['before_id'] = beforeId;
      if (aroundId != null) query['around_id'] = aroundId;

      final response = await _apiClient.dio.get(
        '/chats/$chatId/messages',
        queryParameters: query,
      );

      if (response.statusCode == 204) return null;
      if (response.data == null) return null;

      final data = response.data;
      List<Map<String, dynamic>> messages = [];

      if (data is List) {
        messages = data
            .where((e) => e is Map && e['deleted_at'] == null)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else if (data is Map) {
        final list = data['items'] ?? data['data'] ?? data['messages'];
        if (list is List) {
          messages = list
              .where((e) => e is Map && e['deleted_at'] == null)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }

      if (beforeId == null) {
        // Кэшируем только первую страницу
        await DbService.instance.cacheMessages(chatId, messages);
      }
      return messages;
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 204) return null;
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          if (beforeId == null) {
            return await DbService.instance.getCachedMessages(chatId);
          }
        }
        throw _handleError(e);
      }
      throw Exception('Ошибка формата: $e');
    }
  }

  Future<List<Map<String, dynamic>>?> getMessagesAround(
    int chatId,
    int messageId, {
    int limit = 30,
  }) async {
    return getMessages(chatId, aroundId: messageId, limit: limit);
  }

  Future<Map<String, dynamic>> sendTextMessage(
    int chatId,
    String text, {
    int? replyToId,
    String? clientToken,
  }) async {
    try {
      final data = <String, dynamic>{'text': text};
      if (replyToId != null) {
        data['reply_to_message_id'] = replyToId;
      }
      if (clientToken != null && clientToken.isNotEmpty) {
        data['client_token'] = clientToken;
      }
      final response = await _apiClient.dio.post(
        '/chats/$chatId/messages',
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> sendMessageWithAttachments(
    int chatId,
    String? text,
    List<Map<String, dynamic>> attachments, {
    int? replyToId,
    String? clientToken,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (text != null && text.isNotEmpty) data['text'] = text;
      if (attachments.isNotEmpty) data['attachments'] = attachments;
      if (replyToId != null) data['reply_to_message_id'] = replyToId;
      if (clientToken != null && clientToken.isNotEmpty) {
        data['client_token'] = clientToken;
      }

      final response = await _apiClient.dio.post(
        '/chats/$chatId/messages',
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> markAsRead(int chatId) async {
    try {
      print('🔵 [ChatService] markAsRead chatId=$chatId');
      await _apiClient.dio.post('/chats/$chatId/read');
      print('🟢 [ChatService] markAsRead success chatId=$chatId');
    } on DioException catch (e) {
      print('🔴 [ChatService] markAsRead error chatId=$chatId: $e');
      throw _handleError(e);
    }
  }

  Future<void> addReaction(int chatId, int messageId, String emoji) async {
    try {
      await _apiClient.dio
          .post('/chats/$chatId/messages/$messageId/reactions/$emoji');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> removeReaction(int chatId, int messageId, String emoji) async {
    try {
      await _apiClient.dio
          .delete('/chats/$chatId/messages/$messageId/reactions/$emoji');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> editMessage(int chatId, int messageId, String newText) async {
    try {
      await _apiClient.dio.patch(
        '/chats/$chatId/messages/$messageId',
        data: {'text': newText},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteMessage(int chatId, int messageId) async {
    // Delete from local cache immediately
    await DbService.instance.deleteCachedMessage(chatId, messageId.toString());
    try {
      if (chatId > 0) {
        try {
          final res = await _apiClient.dio.delete('/chats/$chatId/messages/$messageId');
          if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
            return;
          }
        } on DioException catch (e) {
          if (e.response?.statusCode != 404 && e.response?.statusCode != 405) {
            rethrow;
          }
        }

        // Fallback: try bulk delete endpoint with single ID
        try {
          final res = await _apiClient.dio.delete(
            '/chats/$chatId/messages',
            data: {'message_ids': [messageId]},
          );
          if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
            return;
          }
        } on DioException catch (e) {
          if (e.response?.statusCode != 404 && e.response?.statusCode != 405) {
            rethrow;
          }
        }
      }
      // Fallback endpoint if /chats/$chatId/... is not used
      await _apiClient.dio.delete('/messages/$messageId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteMessages(int chatId, List<int> messageIds) async {
    if (messageIds.isEmpty) return;
    // Delete from local cache immediately
    await DbService.instance.deleteCachedMessages(
        chatId, messageIds.map((id) => id.toString()).toList());
    try {
      if (chatId > 0) {
        try {
          final res = await _apiClient.dio.delete(
            '/chats/$chatId/messages',
            data: {'message_ids': messageIds},
          );
          if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
            return;
          }
        } on DioException catch (e) {
          if (e.response?.statusCode != 404 && e.response?.statusCode != 405) {
            rethrow;
          }
        }

        // Fallback: delete one by one via /chats/$chatId/messages/$id
        for (final id in messageIds) {
          try {
            await _apiClient.dio.delete('/chats/$chatId/messages/$id');
          } catch (_) {}
        }
        return;
      }
      // Fallback: delete one by one
      for (final id in messageIds) {
        try {
          await _apiClient.dio.delete('/messages/$id');
        } catch (_) {}
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getPinnedMessages(int chatId) async {
    try {
      final response = await _apiClient.dio.get('/chats/$chatId/pinned');
      final data = response.data;
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> pinMessage(
      int chatId, int messageId) async {
    try {
      Response response =
          await _apiClient.dio.put('/chats/$chatId/pin/$messageId');
      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await _apiClient.dio.put('/operator/chats/$chatId/pin/$messageId');
      }
      final data = response.data;
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
        try {
          final response = await _apiClient.dio.put('/operator/chats/$chatId/pin/$messageId');
          final data = response.data;
          if (data is List) {
            return data.map((e) => Map<String, dynamic>.from(e)).toList();
          }
          return [];
        } catch (_) {}
      }
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> unpinMessage(
      int chatId, int messageId) async {
    try {
      Response response =
          await _apiClient.dio.delete('/chats/$chatId/pin/$messageId');
      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await _apiClient.dio.delete('/operator/chats/$chatId/pin/$messageId');
      }
      final data = response.data;
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
        try {
          final response = await _apiClient.dio.delete('/operator/chats/$chatId/pin/$messageId');
          final data = response.data;
          if (data is List) {
            return data.map((e) => Map<String, dynamic>.from(e)).toList();
          }
          return [];
        } catch (_) {}
      }
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> unpinAllMessages(int chatId) async {
    try {
      final response = await _apiClient.dio.delete('/chats/$chatId/pin');
      final data = response.data;
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getGlobalChatSettings() async {
    try {
      final response = await _apiClient.dio.get('/chats/settings');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateGlobalChatSettings(
      Map<String, dynamic> settings) async {
    try {
      final response =
          await _apiClient.dio.patch('/chats/settings', data: settings);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getChatSettings(int chatId) async {
    try {
      final response = await _apiClient.dio.get('/chats/$chatId/settings');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateChatSettings(
      int chatId, Map<String, dynamic> settings) async {
    try {
      final response =
          await _apiClient.dio.patch('/chats/$chatId/settings', data: settings);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteChatSettings(int chatId) async {
    try {
      await _apiClient.dio.delete('/chats/$chatId/settings');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getGlobalSettings() async {
    return getGlobalChatSettings();
  }

  Future<Map<String, dynamic>> updateGlobalSettings(
      Map<String, dynamic> settings) async {
    return updateGlobalChatSettings(settings);
  }

  Future<void> resetChatSettings(int chatId) async {
    return deleteChatSettings(chatId);
  }

  Future<Map<String, dynamic>> updateChatWallpaper(
      int chatId, String? wallpaperUrl) async {
    try {
      final response = await _apiClient.dio.patch(
        '/chats/$chatId/wallpaper',
        data: {'wallpaper_url': wallpaperUrl},
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<int> getSupportChatId() async {
    final chats = await getChats();
    final supportChat = chats.firstWhere(
      (chat) => chat['chat_type'] == 'support',
      orElse: () => throw Exception('Чат поддержки не найден'),
    );
    final rawId = supportChat['id'];
    if (rawId is num) return rawId.toInt();
    return int.tryParse(rawId?.toString() ?? '') ?? 0;
  }

  /// Закрепить чат в своем списке
  /// PUT /chats/{chat_id}/pin-chat -> 204
  Future<void> pinChat(int chatId) async {
    try {
      await _apiClient.dio.put('/chats/$chatId/pin-chat');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Открепить чат в своем списке
  /// DELETE /chats/{chat_id}/pin-chat -> 204
  Future<void> unpinChat(int chatId) async {
    try {
      try {
        await _apiClient.dio.delete('/chats/$chatId/pin-chat');
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
          await _apiClient.dio.delete('/chats/$chatId/unpin-chat');
        } else {
          rethrow;
        }
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteChat(int chatId) async {
    try {
      await _apiClient.dio.delete('/chats/$chatId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getChatAttachments(
    int chatId, {
    String? type,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'size': size,
      };
      if (type != null) {
        query['type'] = type;
      }
      final response = await _apiClient.dio.get(
        '/chats/$chatId/attachments',
        queryParameters: query,
      );
      final data = response.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      if (data is List) {
        return {
          'items':
              data.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          'total': data.length,
          'page': page,
          'size': size,
          'pages': 1,
        };
      }
      return {
        'items': [],
        'total': 0,
        'page': page,
        'size': size,
        'pages': 0,
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response?.statusCode == 500) {
      String detail = '';
      if (e.response?.data != null) {
        if (e.response!.data is Map && e.response!.data['detail'] != null) {
          detail = ': ${e.response!.data['detail']}';
        } else if (e.response!.data is String) {
          final s = (e.response!.data as String).trim();
          if (s.isNotEmpty && !s.contains('<html') && s.length < 200) {
            detail = ': $s';
          }
        }
      }
      return 'Внутренняя ошибка сервера (500)$detail. На стороне сервера произошел сбой при получении чатов. Попробуйте обновить позже.';
    }
    if (e.response?.statusCode == 403) {
      final path = e.requestOptions.path;
      final serverDetail = (e.response?.data is Map && e.response?.data['detail'] != null)
          ? e.response!.data['detail'].toString()
          : '';
      final prefix = serverDetail.isNotEmpty ? '$serverDetail: ' : '';

      if (path.contains('/pin/')) {
        return '$prefixна сервере закреплять сообщения в этом чате разрешено только операторам.';
      }
      if (path.contains('/pin-chat')) {
        return '$prefixу вас нет прав для закрепления этого чата на сервере.';
      }
      if (path.contains('/messages') && e.requestOptions.method == 'DELETE') {
        return '$prefixна сервере разрешено удалять только свои сообщения.';
      }
      if (path.contains('/operator/')) {
        return '$prefixраздел или действие предназначены только для операторов SAVT.';
      }
      return serverDetail.isNotEmpty ? serverDetail : 'Недостаточно прав (403). Действие не разрешено для вашей учетной записи.';
    }
    if (e.response?.data is Map && e.response?.data['detail'] != null) {
      final detail = e.response!.data['detail'];
      if (detail is String) return detail;
      if (detail is List) {
        try {
          return detail
              .map((e) => e is Map ? (e['msg'] ?? e.toString()) : e.toString())
              .join('\n');
        } catch (_) {
          return detail.join('\n');
        }
      }
      return detail.toString();
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Таймаут соединения. Проверьте подключение к серверу.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Ошибка подключения. Проверьте интернет-соединение.';
    }
    if (e.response?.statusCode == 401) {
      return 'Сессия истекла. Войдите заново.';
    }
    if (e.response?.statusCode == 404) {
      return 'Чат или сообщение не найдены (404).';
    }
    return 'Ошибка загрузки данных: ${e.message}';
  }
}
