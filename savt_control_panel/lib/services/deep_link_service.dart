import 'package:flutter/material.dart';
import '../main.dart';

class ParsedDeepLink {
  final String type;
  final String code;
  final String rawData;

  const ParsedDeepLink({
    required this.type,
    required this.code,
    required this.rawData,
  });
}

ParsedDeepLink? parseDeepLink(Uri uri) {
  final raw = uri.toString().trim();
  final lower = raw.toLowerCase();

  String? type;
  if (lower.startsWith('savt://project') ||
      lower.startsWith('savt:///project') ||
      lower.contains('/project/')) {
    type = 'project';
  } else if (lower.startsWith('savt://cabinet') ||
      lower.startsWith('savt:///cabinet') ||
      lower.contains('/cabinet/')) {
    type = 'cabinet';
  } else if (lower.startsWith('savt://chat') || lower.contains('/chat/')) {
    type = 'chat';
  } else if (lower.startsWith('savt://request') || lower.contains('/request/') || lower.contains('/service-request/')) {
    type = 'request';
  } else if (lower.startsWith('savt://reclamation') || lower.contains('/reclamation/')) {
    type = 'reclamation';
  }

  if (type == null) return null;

  final clean = raw.split('?').first;
  final parts = clean.split('/').where((s) => s.isNotEmpty).toList();
  final code = parts.isNotEmpty ? parts.last : '';

  return ParsedDeepLink(type: type, code: code, rawData: raw);
}

class DeepLinkService {
  static bool _isProcessing = false;

  /// Основная точка входа для обработки любых ссылок (Uri или String)
  static Future<void> handleDeepLink(dynamic link) async {
    final rawLink = link is Uri ? link.toString() : link?.toString() ?? '';
    await handleDeepLinkString(rawLink);
  }

  /// Обработка ссылки из сырой строки
  static Future<void> handleDeepLinkString(String rawLink) async {
    final link = rawLink.trim();
    print('🔗 [DeepLink] ==================== НАЧАЛО ОБРАБОТКИ ССЫЛКИ ====================');
    print('🔗 [DeepLink] Шаг 1: Получена ссылка: "$link"');

    if (link.isEmpty) {
      print('⚠️ [DeepLink] Ошибка: ссылка пустая');
      return;
    }

    final lower = link.toLowerCase();

    // 1. Проверяем добавление проекта
    final bool isProject = lower.startsWith('savt://project') ||
        lower.startsWith('savt:///project') ||
        lower.contains('/add/project/') ||
        lower.contains('/project/');

    // 2. Проверяем добавление шкафа управления
    final bool isCabinet = lower.startsWith('savt://cabinet') ||
        lower.startsWith('savt:///cabinet') ||
        lower.contains('/add/cabinet/') ||
        lower.contains('/cabinet/');

    // 3. Другие сущности
    final bool isChat = lower.startsWith('savt://chat') || lower.contains('/chat/');
    final bool isRequest = lower.startsWith('savt://request') || lower.contains('/request/') || lower.contains('/service-request/');
    final bool isReclamation = lower.startsWith('savt://reclamation') || lower.contains('/reclamation/');

    print('🔗 [DeepLink] Тип ссылки: isProject=$isProject, isCabinet=$isCabinet, isChat=$isChat, isRequest=$isRequest, isReclamation=$isReclamation');

    if (isProject) {
      await _handleAddEntity(type: 'project', rawLink: link);
    } else if (isCabinet) {
      await _handleAddEntity(type: 'cabinet', rawLink: link);
    } else if (isChat) {
      final id = _extractLastSegment(link);
      print('🔗 [DeepLink] Переход в чат: id=$id');
      ControlPanelApp.navigatorKey.currentState?.pushNamed('/chat/$id');
    } else if (isRequest) {
      final id = _extractLastSegment(link);
      print('🔗 [DeepLink] Переход в заявку: id=$id');
      ControlPanelApp.navigatorKey.currentState?.pushNamed('/service-request-detail/$id');
    } else if (isReclamation) {
      final id = _extractLastSegment(link);
      print('🔗 [DeepLink] Переход в рекламацию: id=$id');
      ControlPanelApp.navigatorKey.currentState?.pushNamed('/reclamation-detail/$id');
    } else {
      print('⚠️ [DeepLink] Неизвестный формат ссылки: "$link"');
    }

    print('🔗 [DeepLink] ==================== КОНЕЦ ОБРАБОТКИ ССЫЛКИ ====================');
  }

  static String _extractLastSegment(String link) {
    final clean = link.split('?').first;
    final parts = clean.split('/').where((s) => s.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.last : '';
  }

  static Future<void> _handleAddEntity({
    required String type,
    required String rawLink,
  }) async {
    if (_isProcessing) {
      print('⚠️ [DeepLink] Добавление уже в процессе, пропускаем повторный вызов');
      return;
    }
    _isProcessing = true;

    try {
      final context = ControlPanelApp.navigatorKey.currentContext;
      if (context == null) {
        print('⚠️ [DeepLink] Контекст навигатора пока недоступен, повторим через frame');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isProcessing = false;
          _handleAddEntity(type: type, rawLink: rawLink);
        });
        return;
      }

      print('🔗 [DeepLink] Шаг 2: Проверка авторизации пользователя...');
      String? token;
      bool isGuest = false;
      try {
        token = await tokenStorage.getAccessToken();
        isGuest = tokenStorage.isGuestMode;
      } catch (e) {
        print('⚠️ [DeepLink] Ошибка чтения токена: $e');
      }

      print('🔗 [DeepLink] Токен: ${token != null && token.isNotEmpty ? "присутствует (символов: ${token.length})" : "ОТСУТСТВУЕТ"}, гостевой режим: $isGuest');

      if (token == null || token.isEmpty || isGuest) {
        print('⚠️ [DeepLink] Пользователь не авторизован или в гостевом режиме! Показываем диалог авторизации.');
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Требуется авторизация'),
              content: Text(type == 'project'
                  ? 'Чтобы добавить проект в ваш аккаунт, необходимо войти в приложение.'
                  : 'Чтобы добавить шкаф управления, необходимо войти в приложение.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ControlPanelApp.navigatorKey.currentState?.pushNamed('/auth');
                  },
                  child: const Text('Войти'),
                ),
              ],
            ),
          );
        }
        return;
      }

      print('🔗 [DeepLink] Шаг 3: Отображение индикатора загрузки');
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(type == 'project'
                        ? 'Добавление проекта...'
                        : 'Добавление шкафа...'),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      print('🔗 [DeepLink] Шаг 4: Отправка запроса на бэкенд...');
      print('🔗 [DeepLink] Эндпоинт: ${type == "project" ? "/projects/add-by-qr" : "/cabinets/add-by-qr"}');
      print('🔗 [DeepLink] Тело: {"qr_data": "$rawLink"}');

      Map<String, dynamic> result;
      try {
        if (type == 'project') {
          result = await cabinetService.addProjectByQr(rawLink);
        } else {
          result = await cabinetService.addCabinetByQr(rawLink);
        }
        print('🔗 [DeepLink] Шаг 5: Ответ получен: $result');
      } catch (e, stack) {
        print('🔴 [DeepLink] Шаг 5: Ошибка запроса: $e\n$stack');
        result = {
          'status': 'error',
          'message': 'Ошибка запроса: $e',
        };
      }

      // Закрываем индикатор загрузки
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!context.mounted) {
        print('⚠️ [DeepLink] Контекст не mounted, завершаем');
        return;
      }

      print('🔗 [DeepLink] Шаг 6: Анализ результата и показ диалога');
      final status = result['status']?.toString().toLowerCase();

      final isLinked = status == 'linked' ||
          status == 'success' ||
          status == 'ok' ||
          result['cabinet'] != null ||
          result['cabinet_id'] != null;

      final isAlready = status == 'already_linked' ||
          status == 'conflict';

      final isNotFound = status == 'not_found' || status == '404';

      if (isLinked) {
        print('🟢 [DeepLink] Результат: УСПЕШНО ДОБАВЛЕНО');
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Icon(Icons.check_circle, color: Colors.green, size: 48),
            content: Text(type == 'project'
                ? 'Проект успешно добавлен! Мы также обновили список ваших шкафов.'
                : 'Шкаф управления успешно добавлен в ваш список!'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ControlPanelApp.navigatorKey.currentState
                      ?.pushNamedAndRemoveUntil('/shu-list', (route) => false);
                },
                child: const Text('ОК'),
              ),
            ],
          ),
        );
      } else if (isAlready) {
        print('🟡 [DeepLink] Результат: УЖЕ ПРИВЯЗАНО');
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Icon(Icons.info_outline, color: Colors.orange, size: 48),
            content: Text(result['message']?.toString() ??
                (type == 'project'
                    ? 'Этот проект уже привязан к вашему аккаунту.'
                    : 'Этот шкаф управления уже добавлен в ваш список (напрямую или через проект).')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ОК'),
              ),
            ],
          ),
        );
      } else if (isNotFound) {
        print('🔴 [DeepLink] Результат: НЕ НАЙДЕНО (404)');
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Icon(Icons.error_outline, color: Colors.red, size: 48),
            content: Text(result['message']?.toString() ??
                (type == 'project'
                    ? 'Проект с таким кодом не найден.'
                    : 'Шкаф управления с таким кодом не найден.')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ОК'),
              ),
            ],
          ),
        );
      } else {
        final rawError = result['message']?.toString() ??
            result['error']?.toString() ??
            result['detail']?.toString() ??
            '';
        print('🔴 [DeepLink] Ошибка сервера/сети: $result');

        String userFriendlyMessage;
        if (rawError.contains('Сетевая ошибка') ||
            rawError.contains('SocketException') ||
            rawError.contains('connection error')) {
          userFriendlyMessage =
              'Не удалось связаться с сервером. Пожалуйста, проверьте интернет-соединение.';
        } else if (type == 'project') {
          userFriendlyMessage =
              'Не удалось добавить проект. Пожалуйста, проверьте ссылку или повторите попытку позже.';
        } else {
          userFriendlyMessage =
              'Не удалось добавить шкаф управления. Пожалуйста, проверьте ссылку или повторите попытку позже.';
        }

        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Icon(Icons.error_outline, color: Colors.red, size: 48),
            content: Text(
              userFriendlyMessage,
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ОК'),
              ),
            ],
          ),
        );
      }
    } finally {
      _isProcessing = false;
    }
  }
}
