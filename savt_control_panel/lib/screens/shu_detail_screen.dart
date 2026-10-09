// lib/screens/shu_detail_screen.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import '../models/telemetry.dart';
import '../services/file_save_helper.dart';
import '../utils/download_helper.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/animated_card.dart';
import '../widgets/skeletons.dart';
import '../widgets/responsive_layout.dart';
import 'navigation_container.dart';
import '../main.dart';

class ShuDetailScreen extends StatefulWidget {
  final String shuId;
  final int initialTab;
  const ShuDetailScreen({super.key, required this.shuId, this.initialTab = 0});

  @override
  State<ShuDetailScreen> createState() => _ShuDetailScreenState();
}

class _ShuDetailScreenState extends State<ShuDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic>? _cabinetDetail;
  List<Map<String, dynamic>> _documents = [];
  final Set<String> _downloadedFileNames = {};
  bool _isLoading = true;
  bool _loadingDocs = false;
  bool _downloadingDoc = false;

  List<TelemetryAlarm> _telemetryAlarms = [];
  bool _loadingTelemetry = false;
  bool _hasTelemetryAccess = true;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _loadDetail();
    _loadTelemetry();
    userEventsService.onTelemetryCreated = _onTelemetryCreated;
    userEventsService.startTelemetry(int.parse(widget.shuId));
    _tabController.addListener(() {
      if (_tabController.index == 2 && !_tabController.indexIsChanging) {
        if (_telemetryAlarms.isEmpty &&
            !_loadingTelemetry &&
            _hasTelemetryAccess) {
          _loadTelemetry();
        }
      }
    });
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final detail =
          await cabinetService.getCabinetDetail(int.parse(widget.shuId));
      if (mounted) {
        setState(() {
          _cabinetDetail = detail;
          _isLoading = false;
        });
        _loadDocuments();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('403') ||
            errStr.contains('404') ||
            errStr.contains('не найден') ||
            errStr.contains('недоступен')) {
          _showError('Проект или шкаф больше недоступен');
          Navigator.pop(context, true);
          return;
        }
        _showError('Ошибка загрузки: $e');
      }
    }
  }

  Future<void> _loadDocuments() async {
    setState(() => _loadingDocs = true);
    try {
      final docs = await cabinetService.getDocuments(int.parse(widget.shuId));
      debugPrint('🟢 [DEBUG DOCUMENTS] Loaded cabinet documents: $docs');
      if (mounted) {
        setState(() {
          _documents = docs;
          _loadingDocs = false;
        });
        _checkDownloadedFiles();
      }
    } catch (e) {
      debugPrint('🔴 [DEBUG DOCUMENTS ERROR] Error: $e');
      if (mounted) {
        setState(() => _loadingDocs = false);
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('403') ||
            errStr.contains('404') ||
            errStr.contains('не найден') ||
            errStr.contains('недоступен')) {
          _showError('Проект больше недоступен');
        } else {
          _showError('Ошибка загрузки документов: $e');
        }
      }
    }
  }

  Future<void> _checkDownloadedFiles() async {
    final downloaded = <String>{};
    for (final doc in _documents) {
      final fileUrl = doc['file_url'] ?? doc['url'];
      final fileName = FileSaveHelper.ensureExtension(doc['title'] ?? 'document', fileUrl);
      if (await FileSaveHelper.isFileDownloaded(fileName)) {
        downloaded.add(fileName);
      }
    }
    if (mounted) {
      setState(() {
        _downloadedFileNames.addAll(downloaded);
      });
    }
  }

  Future<void> _openDownloadedDocument(String fileName) async {
    final localPath = await FileSaveHelper.getLocalFilePath(fileName);
    if (localPath != null) {
      if (!kIsWeb) {
        final result = await OpenFile.open(localPath);
        if (result.type != ResultType.done && mounted) {
          _showError('Не удалось открыть файл: ${result.message}');
        }
      }
    } else {
      _showError('Файл не найден на устройстве');
    }
  }

  Future<void> _loadTelemetry() async {
    if (!_hasTelemetryAccess) return;
    setState(() => _loadingTelemetry = true);
    try {
      final response = await cabinetService.getTelemetry(
        int.parse(widget.shuId),
      );
      setState(() {
        _telemetryAlarms = response.registers;
        _loadingTelemetry = false;
        _hasTelemetryAccess = true;
      });
    } on DioException catch (e) {
      setState(() => _loadingTelemetry = false);
      if (e.response?.statusCode == 403) {
        setState(() => _hasTelemetryAccess = false);
      } else {
        _showError('Ошибка загрузки телеметрии: $e');
      }
    } catch (e) {
      setState(() => _loadingTelemetry = false);
      _showError('Ошибка загрузки телеметрии: $e');
    }
  }

  void _onTelemetryCreated(int cabinetId) {
    if (cabinetId == int.parse(widget.shuId)) {
      _loadTelemetry();
    }
  }

  Future<void> _downloadDocument(Map<String, dynamic> doc) async {
    final docId = doc['id'];
    final fileUrl = doc['file_url'] ?? doc['url'];
    final fileName =
        FileSaveHelper.ensureExtension(doc['title'] ?? 'document', fileUrl);

    // Проверяем, есть ли доступ
    if (doc['has_access'] == false) {
      _showError(
          'Нет доступа к документу. Запросите разрешение у администратора.');
      return;
    }

    // Если файл уже скачан, открываем без повторного скачивания
    if (await FileSaveHelper.isFileDownloaded(fileName)) {
      if (mounted) {
        setState(() {
          _downloadedFileNames.add(fileName);
        });
      }
      await _openDownloadedDocument(fileName);
      return;
    }

    if (!mounted) return;
    if (_downloadingDoc) return;
    setState(() => _downloadingDoc = true);

    final progressController = StreamController<double>.broadcast();

    // Показываем диалог прогресса
    showDownloadProgressDialog(context, fileName, progressController.stream);

    try {
      // Скачиваем файл с отслеживанием прогресса
      final bytes = await cabinetService.downloadDocumentWithProgress(
        docId,
        onProgress: (sent, total) {
          if (total > 0) {
            progressController.add(sent / total);
          }
        },
      );

      if (!mounted) return;
      Navigator.pop(context); // Закрываем диалог прогресса

      // Сохраняем на устройство
      final savePath = await FileSaveHelper.saveFile(
        context: context,
        bytes: bytes,
        fileName: fileName,
      );

      if (!mounted) return;
      setState(() {
        _downloadingDoc = false;
        _downloadedFileNames.add(fileName);
      });

      // On web, browser handles download automatically, no need to open
      if (savePath != 'Галерея' && !kIsWeb) {
        final result = await OpenFile.open(savePath);
        if (result.type != ResultType.done && mounted) {
          _showError('Не удалось открыть файл: ${result.message}');
        }
      }
    } catch (e) {
      if (mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {}
      }
      setState(() => _downloadingDoc = false);
      _showError('Ошибка загрузки: $e');
    } finally {
      progressController.close();
    }
  }

  Future<void> _requestDocumentAccess(Map<String, dynamic> doc) async {
    final commentController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final comment = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Запрос доступа'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Пожалуйста, укажите причину запроса доступа к документу:',
                    textAlign: TextAlign.start,
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Причина запроса (минимум 5 символов)...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 5) {
                      return 'Введите не менее 5 символов';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, commentController.text.trim());
                }
              },
              child: const Text('Отправить'),
            ),
          ],
        );
      },
    );

    if (comment == null || comment.isEmpty) return;

    try {
      final docId = doc['id'];
      await cabinetService.requestDocumentAccess(docId, userMessage: comment);
      _showSuccess('Запрос на доступ отправлен администратору');

      // Обновляем статус документа локально
      setState(() {
        final index = _documents.indexWhere((d) => d['id'] == docId);
        if (index != -1) {
          _documents[index]['access_requested'] = true;
        }
      });
    } catch (e) {
      _showError('Ошибка: $e');
    }
  }


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _togglePinCabinet() async {
    if (_cabinetDetail == null) return;
    final isPinned = _cabinetDetail!['is_pinned'] == true ||
        _cabinetDetail!['isPinned'] == true;
    final newPinned = !isPinned;
    final cabId = int.parse(widget.shuId);

    setState(() {
      _cabinetDetail!['is_pinned'] = newPinned;
    });

    try {
      if (newPinned) {
        await cabinetService.pinCabinet(cabId);
      } else {
        await cabinetService.unpinCabinet(cabId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newPinned ? 'Шкаф закреплен' : 'Шкаф откреплен'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cabinetDetail!['is_pinned'] = isPinned;
        });
        _showError('Ошибка изменения закрепления: $e');
      }
    }
  }

  Future<void> _openCabinetChat() async {
    try {
      final chatData = await cabinetService
          .getCabinetChat(_cabinetDetail!['cabinet_id'] ?? int.parse(widget.shuId));
      final chatId = chatData['id'];
      if (!mounted) return;
      if (chatId != null) {
        Navigator.pushNamed(context, '/chat/$chatId');
        MainNavigationContainer.globalKey.currentState
            ?.refreshChatsList();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 403 ||
          (e.response?.statusCode == 404 &&
              _cabinetDetail?['project_id'] != null)) {
        _showError('Проект больше недоступен');
      } else {
        _showError('Ошибка открытия чата: $e');
      }
    }
  }

  Future<void> _confirmDeleteCabinet() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Убрать шкаф?'),
        content: const Text(
          'Вы уверены, что хотите убрать этот шкаф? Чаты по этому ШУ уйдут в архив.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Убрать'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final cabId = int.parse(widget.shuId);
      await cabinetService.deleteCabinet(cabId);
      if (mounted) {
        MainNavigationContainer.globalKey.currentState?.refreshChatsList();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Шкаф убран'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showError('Не удалось убрать шкаф: $e');
      }
    }
  }

  Future<void> _confirmLeaveProject() async {
    final projectName = _cabinetDetail?['project_name'] ?? 'этого проекта';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из проекта?'),
        content: Text(
          'Вы потеряете доступ ко всем шкафам проекта "$projectName". Чаты по проекту уйдут в архив.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final pId = _cabinetDetail?['project_id'];
      if (pId != null) {
        final parsedPid = pId is int ? pId : int.parse(pId.toString());
        await cabinetService.leaveProject(parsedPid);
      }
      if (mounted) {
        MainNavigationContainer.globalKey.currentState?.refreshChatsList();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Вы вышли из проекта'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showError('Не удалось выйти из проекта: $e');
      }
    }
  }

  String get _warrantyText {
    final status = _cabinetDetail?['warranty_status'];
    if (status == 'active') return 'Активна';
    if (status == 'expiring_soon') return 'Истекает';
    if (status == 'expired') return 'Истекла';
    return 'Н/Д';
  }

  Color get _warrantyColor {
    final status = _cabinetDetail?['warranty_status'];
    switch (status) {
      case 'active':
        return const Color(0xFF10B981);
      case 'expiring_soon':
        return const Color(0xFFF59E0B);
      case 'expired':
        return const Color(0xFF991B1B);
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    userEventsService.stopTelemetry();
    userEventsService.onTelemetryCreated = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return const GradientScaffold(
        appBarTitle: 'Шкаф управления',
        body: SkeletonDetail(),
      );
    }
    if (_cabinetDetail == null) {
      return const GradientScaffold(
        appBarTitle: 'Ошибка',
        body: Center(child: Text('Не удалось загрузить данные')),
      );
    }

    return GradientScaffold(
      appBarTitle: _cabinetDetail!['custom_name']?.isNotEmpty == true
          ? _cabinetDetail!['custom_name']
          : _cabinetDetail!['type'],
      appBarLeading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: Colors.white),
      ),
      appBarAction: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              (_cabinetDetail?['is_pinned'] == true ||
                      _cabinetDetail?['isPinned'] == true)
                  ? Icons.push_pin
                  : Icons.push_pin_outlined,
              color: Colors.white,
            ),
            tooltip: (_cabinetDetail?['is_pinned'] == true ||
                    _cabinetDetail?['isPinned'] == true)
                ? 'Открепить'
                : 'Закрепить',
            onPressed: _togglePinCabinet,
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            tooltip: 'Открыть чат',
            onPressed: _openCabinetChat,
          ),
          if (_cabinetDetail?['project_id'] == null ||
              _cabinetDetail?['project_id'] == 0)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Убрать шкаф',
              onPressed: _confirmDeleteCabinet,
            ),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: 600,
        child: Column(
          children: [
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                      indicatorColor: theme.colorScheme.primary,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Инфо'),
                        Tab(text: 'Документы'),
                        Tab(text: 'Телеметрия'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildInfoTab(),
                          _buildDocumentsTab(),
                          _buildTelemetryTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavBar: null,
    );
  }

  Widget _buildWarrantyExpiringBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade600, Colors.red.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Срок гарантии истекает!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Рекомендуем провести плановое ТО. Оформить заявку можно в разделе «Заявки».',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.start,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    final theme = Theme.of(context);
    final isExpiring = _cabinetDetail?['warranty_status'] == 'expiring_soon';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (isExpiring) ...[
            _buildWarrantyExpiringBanner(theme),
            const SizedBox(height: 16),
          ],
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final theme = Theme.of(context);
    return AnimatedCard(
      index: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Тип станции', _cabinetDetail?['type'] ?? 'Н/Д'),
          const SizedBox(height: 16),
          _buildInfoRow('Предназначение', _cabinetDetail?['purpose'] ?? 'Н/Д'),
          const SizedBox(height: 16),
          _buildInfoRow(
              'Проект', _cabinetDetail?['project_name'] ?? 'Без проекта'),
          Divider(height: 32, color: theme.colorScheme.outline),
          _buildInfoRow('Дата начала гарантии',
              _formatDate(_cabinetDetail?['warranty_starts_at'])),
          const SizedBox(height: 16),
          _buildInfoRow('Дата окончания гарантии',
              _formatDate(_cabinetDetail?['warranty_ends_at'])),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _warrantyColor.withValues(alpha: 0.15),
                  _warrantyColor.withValues(alpha: 0.05)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _warrantyColor.withValues(alpha: 0.2)),
            ),
            child: Center(
                child: Text(_warrantyText,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _warrantyColor))),
          ),
          if (_cabinetDetail?['project_id'] == null ||
              _cabinetDetail?['project_id'] == 0) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Убрать шкаф',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _confirmDeleteCabinet,
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.exit_to_app, color: Colors.red),
                label: const Text('Выйти из проекта',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _confirmLeaveProject,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: 140,
            child: Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 14))),
        Expanded(
            child: Text(value,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600, fontSize: 14))),
      ],
    );
  }

  // ========== Документы ==========
  Widget _buildDocumentsTab() {
    if (_loadingDocs) {
      return const SkeletonList();
    }
    if (_documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Нет документов',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
        final hasAccess = doc['has_access'] ?? false;
        final accessRequested = doc['access_requested'] ?? false;
        final docType = doc['doc_type'] ?? 'document';

        IconData icon;
        switch (docType) {
          case 'passport':
            icon = Icons.description;
          case 'manual':
            icon = Icons.menu_book;
          case 'wiring_diagram':
            icon = Icons.timeline;
          case 'electrical_schema':
            icon = Icons.electric_bolt;
          case 'registers_map':
            icon = Icons.map;
          default:
            icon = Icons.insert_drive_file;
        }

        final fileUrl = doc['file_url'] ?? doc['url'];
        final fileName =
            FileSaveHelper.ensureExtension(doc['title'] ?? 'document', fileUrl);
        final isDownloaded = _downloadedFileNames.contains(fileName);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: hasAccess
                ? () => (isDownloaded && !kIsWeb)
                    ? _openDownloadedDocument(fileName)
                    : _downloadDocument(doc)
                : null,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(doc['title'] ?? 'Документ',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (!hasAccess) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.lock, size: 16, color: Colors.orange),
                ],
              ],
            ),
            subtitle: Text(doc['file_size_bytes'] != null
                ? '${(doc['file_size_bytes'] / 1024).round()} KB'
                : ''),
            trailing: _downloadingDoc
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : hasAccess
                    ? (isDownloaded && !kIsWeb
                        ? OutlinedButton.icon(
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text('Просмотр'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.primary,
                              side: BorderSide(
                                  color: Theme.of(context).colorScheme.primary),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                            ),
                            onPressed: () => _openDownloadedDocument(fileName),
                          )
                        : ElevatedButton(
                            onPressed: () => _downloadDocument(doc),
                            child: const Text('Скачать'),
                          ))
                    : accessRequested
                        ? const OutlinedButton(
                            onPressed: null,
                            child: Text('Запрос отправлен'),
                          )
                        : OutlinedButton(
                            onPressed: () => _requestDocumentAccess(doc),
                            child: const Text('Запросить доступ'),
                          ),
          ),
        );
      },
    );
  }

  Widget _buildTelemetryTab() {
    if (!_hasTelemetryAccess) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Нет доступа к телеметрии',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    if (_loadingTelemetry && _telemetryAlarms.isEmpty) {
      return const SkeletonList();
    }

    if (_telemetryAlarms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sensors_off,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Активных аварий нет',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTelemetry(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _telemetryAlarms.length,
        itemBuilder: (context, index) {
          final alarm = _telemetryAlarms[index];
          return _TelemetryAlarmCard(alarm: alarm);
        },
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr == '—' || dateStr.trim().isEmpty) return '—';
    try {
      final parsed = DateTime.parse(dateStr);
      return DateFormat('dd.MM.yyyy').format(parsed);
    } catch (_) {
      return dateStr;
    }
  }
}

class _TelemetryAlarmCard extends StatelessWidget {
  final TelemetryAlarm alarm;

  const _TelemetryAlarmCard({required this.alarm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('dd.MM.yyyy HH:mm').format(alarm.updatedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.warning_amber_rounded,
                  size: 22, color: theme.colorScheme.error),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alarm.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Регистр ${alarm.address}, бит ${alarm.bit}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${alarm.value}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

