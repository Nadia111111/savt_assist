import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import '../theme/app_spacing.dart';
import '../services/cabinet_service.dart';
import '../services/file_save_helper.dart';
import '../utils/download_helper.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/skeletons.dart';
import '../main.dart';

class AllDocumentsScreen extends StatefulWidget {
  const AllDocumentsScreen({super.key});

  @override
  State<AllDocumentsScreen> createState() => _AllDocumentsScreenState();
}

class _AllDocumentsScreenState extends State<AllDocumentsScreen> {
  final CabinetService _cabinetService = CabinetService(apiClient);
  
  List<Map<String, dynamic>> _cabinets = [];
  List<Map<String, dynamic>> _allDocuments = [];
  List<Map<String, dynamic>> _filteredDocuments = [];
  final Set<String> _downloadedFileNames = {};
  
  bool _isLoading = true;
  bool _downloadingDoc = false;

  int? _selectedCabinetId;
  String _selectedDocType = 'all';
  final TextEditingController _searchController = TextEditingController();

  final Map<String, String> _docTypes = {
    'all': 'Все',
    'passport': 'Паспорт',
    'manual': 'Инструкция',
    'wiring_diagram': 'Схема подключения',
    'electrical_schema': 'Эл. схема',
    'registers_map': 'Карта регистров',
  };

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final cabinetList = await _cabinetService.getUserCabinets();
      _cabinets = cabinetList.map((c) => {
        'id': c.cabinetId,
        'name': c.customName.isNotEmpty ? c.customName : c.type,
      }).toList();

      List<Map<String, dynamic>> docsTemp = [];
      for (final cab in cabinetList) {
        try {
          final docs = await _cabinetService.getDocuments(cab.cabinetId);
          for (final d in docs) {
            docsTemp.add({
              ...d,
              'cabinet_id': cab.cabinetId,
              'cabinet_name': cab.customName.isNotEmpty ? cab.customName : cab.type,
            });
          }
        } catch (_) {}
      }

      setState(() {
        _allDocuments = docsTemp;
        _isLoading = false;
      });
      _applyFilters();
      _checkDownloadedFiles();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Ошибка загрузки данных: $e');
    }
  }

  Future<void> _checkDownloadedFiles() async {
    final downloaded = <String>{};
    for (final doc in _allDocuments) {
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
      final result = await OpenFile.open(localPath);
      if (result.type != ResultType.done && mounted) {
        _showError('Не удалось открыть файл: ${result.message}');
      }
    } else {
      _showError('Файл не найден на устройстве');
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDocuments = _allDocuments.where((doc) {
        final matchesCabinet = _selectedCabinetId == null || doc['cabinet_id'] == _selectedCabinetId;
        final matchesType = _selectedDocType == 'all' || doc['doc_type'] == _selectedDocType;
        final matchesSearch = doc['title']?.toString().toLowerCase().contains(query) ?? true;
        return matchesCabinet && matchesType && matchesSearch;
      }).toList();
    });
  }

  Future<void> _downloadDocument(Map<String, dynamic> doc) async {
    final docId = doc['id'];
    final fileUrl = doc['file_url'] ?? doc['url'];
    final fileName = FileSaveHelper.ensureExtension(doc['title'] ?? 'document', fileUrl);

    if (doc['has_access'] == false) {
      _showError('Нет доступа. Запросите разрешение у администратора.');
      return;
    }

    // Если файл уже скачан, открываем его без повторного скачивания
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

    setState(() {
      _downloadingDoc = true;
    });

    final progressController = StreamController<double>.broadcast();

    // Показываем единый диалог с анимированным прогрессом
    showDownloadProgressDialog(context, fileName, progressController.stream);

    try {
      final bytes = await _cabinetService.downloadDocumentWithProgress(
        docId,
        onProgress: (received, total) {
          if (total > 0) {
            progressController.add(received / total);
          }
        },
      );

      // Закрываем диалог прогресса
      if (!mounted) return;
      Navigator.pop(context);

      final savePath = await FileSaveHelper.saveFile(
        context: context,
        bytes: bytes,
        fileName: fileName,
      );

      if (mounted) {
        setState(() {
          _downloadingDoc = false;
          _downloadedFileNames.add(fileName);
        });
      }

      // On web, browser handles download automatically, no need to open
      if (!kIsWeb) {
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
    try {
      final docId = doc['id'];
      await _cabinetService.requestDocumentAccess(docId);
      _showSuccess('Запрос на доступ отправлен администратору');
      _loadAllData();
    } catch (e) {
      _showError('Ошибка: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GradientScaffold(
      appBarTitle: 'Все документы',
      appBarLeading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          const SizedBox(height: AppSpacing.base),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: _isLoading
                  ? const SkeletonList()
                  : Column(
                      children: [
                        _buildFiltersPanel(theme),
                        Expanded(
                          child: _filteredDocuments.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
                                  itemCount: _filteredDocuments.length,
                                  itemBuilder: (context, index) {
                                    final doc = _filteredDocuments[index];
                                    return _buildDocumentCard(doc);
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => _applyFilters(),
            decoration: InputDecoration(
              hintText: 'Поиск документов...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedCabinetId,
                      hint: const Text('Все шкафы ШУ'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Все шкафы ШУ'),
                        ),
                        ..._cabinets.map((c) {
                          return DropdownMenuItem<int?>(
                            value: c['id'] as int,
                            child: Text(c['name'] as String),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedCabinetId = val;
                        });
                        _applyFilters();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _docTypes.entries.map((entry) {
                final isSelected = _selectedDocType == entry.key;
                return Padding(
                   padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _selectedDocType = entry.key;
                      });
                      _applyFilters();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          const Text('Документы не найдены', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc) {
    final theme = Theme.of(context);
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
    final fileName = FileSaveHelper.ensureExtension(doc['title'] ?? 'document', fileUrl);
    final isDownloaded = _downloadedFileNames.contains(fileName);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: hasAccess
            ? () => isDownloaded
                ? _openDownloadedDocument(fileName)
                : _downloadDocument(doc)
            : null,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        title: Text(doc['title'] ?? 'Документ', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ШУ: ${doc['cabinet_name']}'),
            if (doc['file_size_bytes'] != null)
              Text('${(doc['file_size_bytes'] / 1024).round()} KB', style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: hasAccess
            ? (isDownloaded && !kIsWeb
                ? OutlinedButton.icon(
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Просмотр'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                    child: const Text('Доступ'),
                  ),
      ),
    );
  }
}
