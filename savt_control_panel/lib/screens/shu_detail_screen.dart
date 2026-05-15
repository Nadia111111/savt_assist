// lib/screens/shu_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/shu_model.dart';
import '../services/network_service.dart';
import '../services/offline_service.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/animated_card.dart';

class ShuDetailScreen extends StatefulWidget {
  final String shuId;

  const ShuDetailScreen({super.key, required this.shuId});

  @override
  State<ShuDetailScreen> createState() => _ShuDetailScreenState();
}

class _ShuDetailScreenState extends State<ShuDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _customNameController;
  late TextEditingController _commentController;

  ShuModel? _shu;

  // Кэш для загруженных документов (мок-хранилище по docId)
  final Set<String> _downloadedDocIds = {};

  final Map<String, ShuModel> _mockShuData = {
    '1': ShuModel(
      id: '1',
      type: 'ШУ-24М',
      objectNumber: 'ОБ-2024-001',
      customName: '',
      comment: '',
      stationType: 'Насосная станция',
      purpose: 'Водоснабжение',
      warrantyStatus: 'active',
      warrantyDaysRemaining: 245,
      warrantyStart: '15.01.2024',
      warrantyEnd: '15.01.2027',
      moderationStatus: 'active',
      unreadMessages: 2,
      addedDate: DateTime(2024, 1, 15),
    ),
    '2': ShuModel(
      id: '2',
      type: 'ШУ-18К',
      objectNumber: 'ОБ-2024-002',
      customName: '',
      comment: '',
      stationType: 'Вентиляционная установка',
      purpose: 'Вентиляция',
      warrantyStatus: 'expiring',
      warrantyDaysRemaining: 28,
      warrantyStart: '20.02.2024',
      warrantyEnd: '20.02.2025',
      moderationStatus: 'active',
      unreadMessages: 0,
      addedDate: DateTime(2024, 2, 20),
    ),
    '3': ShuModel(
      id: '3',
      type: 'ШУ-36П',
      objectNumber: 'ОБ-2023-045',
      customName: '',
      comment: '',
      stationType: 'Насосная станция',
      purpose: 'Канализация',
      warrantyStatus: 'expired',
      warrantyDaysRemaining: -30,
      warrantyStart: '05.12.2023',
      warrantyEnd: '05.12.2024',
      moderationStatus: 'active',
      unreadMessages: 1,
      addedDate: DateTime(2023, 12, 5),
    ),
  };

  List<Map<String, dynamic>> _documents = [
    {
      'id': '1',
      'name': 'Руководство по эксплуатации',
      'icon': '📘',
      'size': '5.8 МБ',
      'downloaded': false,
      'requiresPermission': false,
      'permissionRequested': false,
      'permissionGranted': false,
      'loading': false,
    },
    {
      'id': '2',
      'name': 'Схема электрическая принципиальная',
      'icon': '⚡',
      'size': '3.1 МБ',
      'downloaded': false,
      'requiresPermission': true,
      'permissionRequested': false,
      'permissionGranted': false,
      'loading': false,
    },
    {
      'id': '3',
      'name': 'Карта регистров',
      'icon': '🏷️',
      'size': '0.8 МБ',
      'downloaded': false,
      'requiresPermission': true,
      'permissionRequested': false,
      'permissionGranted': false,
      'loading': false,
    },
  ];

  final List<String> _photos =
      List.generate(8, (i) => 'https://picsum.photos/seed/shu${i + 1}/400/400');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _shu = _mockShuData[widget.shuId];
    _customNameController = TextEditingController(text: _shu?.customName ?? '');
    _commentController = TextEditingController(text: _shu?.comment ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customNameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _saveLocalChanges() {
    if (_shu == null) return;
    setState(() {
      _shu!.customName = _customNameController.text;
      _shu!.comment = _commentController.text;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Изменения сохранены локально'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _warrantyText {
    if (_shu == null) return '';
    final days = _shu!.warrantyDaysRemaining;
    if (days > 0) return 'Осталось $days дней';
    if (days < 0) return 'Истекла ${days.abs()} дн. назад';
    return 'Н/Д';
  }

  Color get _warrantyColor {
    if (_shu == null) return Colors.grey;
    switch (_shu!.warrantyStatus) {
      case 'active':
        return const Color(0xFF10B981);
      case 'expiring':
        return const Color(0xFFF59E0B);
      case 'expired':
        return const Color(0xFF991B1B);
      default:
        return Colors.grey;
    }
  }

  void _downloadDocument(int index) async {
    final isOnline = NetworkService.isOnline;
    if (!isOnline) {
      // Добавляем в очередь загрузок
      OfflineService().addDownloadToQueue(
        _documents[index]['id'],
        _documents[index]['name'],
        widget.shuId,
      );
      _showSnack('Нет сети. Документ будет загружен при подключении.');
      return;
    }

    setState(() => _documents[index]['loading'] = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _documents[index]['loading'] = false;
      _documents[index]['downloaded'] = true;
      _downloadedDocIds.add(_documents[index]['id']);
      // Сохраняем в кэш
      OfflineService().cacheData(
        'doc_${_documents[index]['id']}',
        _documents[index],
      );
    });
    _showSnack('Документ загружен');
  }

  void _openDocument(int index) {
    // Проверяем, был ли документ загружен ранее
    final docId = _documents[index]['id'] as String;
    if (!_downloadedDocIds.contains(docId) &&
        !OfflineService().hasCachedData('doc_$docId')) {
      // Если не загружен, предлагаем загрузить
      _showSnack('Сначала загрузите документ');
      return;
    }

    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? const Color(0xFF0B1120)
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_documents[index]['icon'] as String,
                      style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _documents[index]['name'] as String,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
              Divider(height: 24, color: theme.colorScheme.outline),
              Text(
                'Содержимое документа (демо-режим)\n\n'
                'Здесь будет встроенный просмотрщик или открытие в стороннем приложении.',
                style: TextStyle(
                    height: 1.5,
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _requestPermission(int index) {
    setState(() => _documents[index]['permissionRequested'] = true);
    _showSnack('Запрос отправлен администратору');
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _documents[index]['permissionGranted'] = true;
        _documents[index]['permissionRequested'] = false;
      });
      _showSnack('Доступ разрешён! Теперь документ можно загрузить');
    });
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: const Color(0xFF054582),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_shu == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: const Center(child: Text('ШУ не найдено')),
      );
    }

    final shu = _shu!;
    final moderation = shu.moderationStatus;

    return ValueListenableBuilder<bool>(
      valueListenable: NetworkService.isOnlineNotifier,
      builder: (context, isOnline, child) {
        return GradientScaffold(
          appBarTitle: shu.customName.isNotEmpty ? shu.customName : shu.type,
          appBarLeading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          body: Column(
            children: [
              if (moderation == 'active')
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, '/chat/${widget.shuId}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.chat,
                                color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Чат техподдержки',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.primary,
                                        fontSize: 13)),
                                Text(
                                    shu.unreadMessages > 0
                                        ? '${shu.unreadMessages} новых сообщений'
                                        : 'Нажмите, чтобы написать',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: theme
                                            .colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: theme.colorScheme.primary, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              if (moderation != 'active')
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: moderation == 'moderation'
                          ? const Color(0xFF3D2F1F)
                          : const Color(0xFF3D1F1F),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      moderation == 'moderation'
                          ? 'Заявка на модерации. Ожидайте подтверждения.'
                          : 'Заявка отклонена. Вы можете отправить повторно.',
                      style: TextStyle(
                        color: moderation == 'moderation'
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32)),
                  ),
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        labelColor: theme.colorScheme.primary,
                        unselectedLabelColor:
                            theme.colorScheme.onSurfaceVariant,
                        indicatorColor: theme.colorScheme.primary,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(text: 'Инфо'),
                          Tab(text: 'Документы'),
                          Tab(text: 'Фото'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildInfoTab(moderation, isOnline),
                            _buildDocumentsTab(isOnline),
                            _buildPhotosTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavBar: null,
        );
      },
    );
  }

  Widget _buildInfoTab(String moderation, bool isOnline) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          if (moderation == 'active') _buildServiceButton(isOnline),
          const SizedBox(height: 16),
          AnimatedCard(
            index: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Произвольное название',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _customNameController,
                  decoration: InputDecoration(
                    hintText: 'Введите название...',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: theme.colorScheme.primary, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Комментарий',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Введите комментарий...',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: theme.colorScheme.primary, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveLocalChanges,
                    child: const Text('Сохранить изменения'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final theme = Theme.of(context);
    final shu = _shu!;
    return AnimatedCard(
      index: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Тип станции', shu.stationType ?? 'Н/Д'),
          const SizedBox(height: 16),
          _buildInfoRow('Предназначение', shu.purpose ?? 'Н/Д'),
          Divider(height: 32, color: theme.colorScheme.outline),
          if (shu.warrantyStart != null && shu.warrantyStart!.isNotEmpty) ...[
            _buildInfoRow('Дата начала гарантии', shu.warrantyStart!),
            const SizedBox(height: 16),
            _buildInfoRow('Дата окончания гарантии', shu.warrantyEnd!),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _warrantyColor.withOpacity(0.15),
                    _warrantyColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _warrantyColor.withOpacity(0.2)),
              ),
              child: Center(
                  child: Text(_warrantyText,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _warrantyColor))),
            ),
          ] else
            Center(
              child: Text(
                'Информация о гарантии отсутствует',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
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

  Widget _buildServiceButton(bool isOnline) {
    final shu = _shu!;
    final isWarranty = shu.warrantyStatus == 'active';
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: isOnline
            ? () =>
                Navigator.pushNamed(context, '/service-request/${widget.shuId}')
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isWarranty ? const Color(0xFF059669) : const Color(0xFF054582),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          isWarranty
              ? 'Гарантийное обслуживание'
              : 'Негарантийное обслуживание',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildDocumentsTab(bool isOnline) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
        final bool loading = doc['loading'] as bool;
        final bool downloaded = doc['downloaded'] as bool;
        final bool requiresPerm = doc['requiresPermission'] as bool;
        final bool requested = doc['permissionRequested'] as bool;
        final bool granted = doc['permissionGranted'] as bool;
        final docId = doc['id'] as String;

        // Проверяем, был ли документ ранее загружен (из кэша)
        final bool wasDownloaded = _downloadedDocIds.contains(docId) ||
            OfflineService().hasCachedData('doc_$docId');

        return AnimatedCard(
          index: index,
          child: Row(
            children: [
              Text(doc['icon'] as String, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc['name'] as String,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(doc['size'] as String,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    if (requiresPerm && !granted && !requested)
                      const SizedBox(height: 6),
                    if (requiresPerm && !granted && !requested)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFF59E0B).withOpacity(0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline,
                                size: 10, color: Color(0xFFF59E0B)),
                            SizedBox(width: 4),
                            Text('Требуется разрешение',
                                style: TextStyle(
                                    fontSize: 10, color: Color(0xFFF59E0B))),
                          ],
                        ),
                      )
                    else if (requested)
                      const Text('Ожидает одобрения...',
                          style: TextStyle(fontSize: 12, color: Colors.blue)),
                    if (!isOnline)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Офлайн',
                            style:
                                TextStyle(fontSize: 10, color: Colors.orange)),
                      ),
                  ],
                ),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (downloaded || wasDownloaded)
                ElevatedButton(
                  onPressed: () => _openDocument(index),
                  child: const Text('Открыть', style: TextStyle(fontSize: 13)),
                )
              else if (requiresPerm && !granted && !requested)
                OutlinedButton(
                  onPressed: isOnline ? () => _requestPermission(index) : null,
                  child:
                      const Text('Запросить', style: TextStyle(fontSize: 13)),
                )
              else if (requiresPerm &&
                  granted &&
                  !(downloaded || wasDownloaded))
                OutlinedButton(
                  onPressed: isOnline ? () => _downloadDocument(index) : null,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.download_outlined, size: 14),
                    const SizedBox(width: 4),
                    const Text('Загрузить', style: TextStyle(fontSize: 13))
                  ]),
                )
              else if (!requiresPerm && !(downloaded || wasDownloaded))
                OutlinedButton(
                  onPressed: isOnline ? () => _downloadDocument(index) : null,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.download_outlined, size: 14),
                    const SizedBox(width: 4),
                    const Text('Загрузить', style: TextStyle(fontSize: 13))
                  ]),
                )
              else
                const SizedBox(width: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotosTab() {
    final theme = Theme.of(context);
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            _photos[index],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(Icons.image_outlined,
                    size: 32, color: theme.colorScheme.onSurfaceVariant)),
          ),
        );
      },
    );
  }
}
