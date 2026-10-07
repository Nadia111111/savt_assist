// lib/screens/my_documents_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../theme/app_spacing.dart';
import '../services/file_save_helper.dart';
import '../utils/download_helper.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/skeletons.dart';
import '../widgets/animated_card.dart';
import '../main.dart'; // cabinetService
import '../utils/error_handler.dart';
import 'shu_detail_screen.dart';

class MyDocumentsScreen extends StatefulWidget {
  const MyDocumentsScreen({super.key});

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _documents = [];
  final Set<String> _downloadedFileNames = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _selectedDocType = 'Все';
  String _searchQuery = '';
  bool _downloadingDoc = false;
  bool _isSearchExpanded = false;

  final List<String> _docTypes = ['Все', 'pdf', 'doc', 'xls', 'other'];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMoreDocuments();
    }
  }

  Future<void> _loadDocuments({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _isLoading = true;
      });
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final docTypeParam = _selectedDocType == 'Все' ? null : _selectedDocType;
      final searchParam =
          _searchQuery.trim().isEmpty ? null : _searchQuery.trim();

      final items = await cabinetService.getAllUserDocuments(
        docType: docTypeParam,
        search: searchParam,
        page: _currentPage,
        size: 20,
      );

      debugPrint('🟢 [DEBUG MY DOCUMENTS] Loaded all documents: $items');

      setState(() {
        if (refresh) {
          _documents = items;
        } else {
          _documents = [..._documents, ...items];
        }
        _hasMore = items.length == 20;
        _isLoading = false;
      });
      _checkDownloadedFiles();
    } catch (e) {
      debugPrint('🔴 [DEBUG MY DOCUMENTS ERROR] Error: $e');
      setState(() => _isLoading = false);
      _showError(ErrorHandler.getUserFriendlyMessage(e));
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
      final result = await OpenFile.open(localPath);
      if (result.type != ResultType.done && mounted) {
        _showError('Не удалось открыть файл: ${result.message}');
      }
    } else {
      _showError('Файл не найден на устройстве');
    }
  }

  Future<void> _loadMoreDocuments() async {
    setState(() => _isLoadingMore = true);
    try {
      _currentPage++;
      final docTypeParam = _selectedDocType == 'Все' ? null : _selectedDocType;
      final searchParam =
          _searchQuery.trim().isEmpty ? null : _searchQuery.trim();

      final items = await cabinetService.getAllUserDocuments(
        docType: docTypeParam,
        search: searchParam,
        page: _currentPage,
        size: 20,
      );

      setState(() {
        _documents = [..._documents, ...items];
        _hasMore = items.length == 20;
        _isLoadingMore = false;
      });
      _checkDownloadedFiles();
    } catch (e) {
      setState(() {
        _currentPage--;
        _isLoadingMore = false;
      });
      _showError(ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  Future<void> _downloadDocument(Map<String, dynamic> doc) async {
    final docId = doc['id'];
    final fileUrl = doc['file_url'] ?? doc['url'];
    final fileName =
        FileSaveHelper.ensureExtension(doc['title'] ?? 'document', fileUrl);

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

    // Показываем анимированный диалог прогресса
    showDownloadProgressDialog(context, fileName, progressController.stream);

    try {
      final bytes = await cabinetService.downloadDocumentWithProgress(
        docId,
        onProgress: (sent, total) {
          if (total > 0) {
            progressController.add(sent / total);
          }
        },
      );

      if (!mounted) return;
      Navigator.pop(context); // закрываем диалог

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

      if (savePath != 'Галерея') {
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
      _showError('Ошибка загрузки: ${ErrorHandler.getUserFriendlyMessage(e)}');
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
                    'Пожалуйста, укажите причину запроса доступа к документу:'),
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
      setState(() {
        final idx = _documents.indexWhere((d) => d['id'] == docId);
        if (idx != -1) {
          _documents[idx]['access_requested'] = true;
        }
      });
    } catch (e) {
      _showError(
          'Ошибка запроса доступа: ${ErrorHandler.getUserFriendlyMessage(e)}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  IconData _getFileIcon(String? ext) {
    if (ext == null) return Icons.insert_drive_file;
    final cleanExt = ext.toLowerCase().replaceAll('.', '');
    if (cleanExt == 'pdf') return Icons.picture_as_pdf;
    if (['doc', 'docx', 'rtf', 'txt'].contains(cleanExt)) {
      return Icons.description;
    }
    if (['xls', 'xlsx', 'csv'].contains(cleanExt)) return Icons.table_chart;
    return Icons.insert_drive_file;
  }

  Color _getFileIconColor(String? ext) {
    if (ext == null) return Colors.grey;
    final cleanExt = ext.toLowerCase().replaceAll('.', '');
    if (cleanExt == 'pdf') return Colors.redAccent;
    if (['doc', 'docx', 'rtf', 'txt'].contains(cleanExt)) return Colors.blue;
    if (['xls', 'xlsx', 'csv'].contains(cleanExt)) return Colors.green;
    return Colors.grey;
  }

  String _formatFileSize(dynamic sizeInBytes) {
    if (sizeInBytes == null) return '';
    try {
      final bytes = sizeInBytes is num
          ? sizeInBytes.toDouble()
          : double.parse(sizeInBytes.toString());
      if (bytes < 1024) return '$bytes Б';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GradientScaffold(
      appBarTitle: 'Мои документы',
      appBarLeading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      appBarAction: IconButton(
        icon: Icon(_isSearchExpanded ? Icons.close : Icons.search,
            color: Colors.white),
        onPressed: () {
          setState(() {
            _isSearchExpanded = !_isSearchExpanded;
            if (!_isSearchExpanded) {
              _searchController.clear();
              _searchQuery = '';
              _loadDocuments(refresh: true);
            }
          });
          if (_isSearchExpanded) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                FocusScope.of(this.context).requestFocus(_searchFocusNode);
              }
            });
          } else {
            FocusScope.of(context).unfocus();
          }
        },
      ),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding:
                _isSearchExpanded ? const EdgeInsets.all(16) : EdgeInsets.zero,
            child: _isSearchExpanded
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Поиск по названию...',
                        hintStyle: const TextStyle(color: Colors.white70),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.white70),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: Colors.white70),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                  _loadDocuments(refresh: true);
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onSubmitted: (value) {
                        setState(() => _searchQuery = value);
                        _loadDocuments(refresh: true);
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          _buildSearchAndFilters(theme),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: RefreshIndicator(
                onRefresh: () => _loadDocuments(refresh: true),
                child: _isLoading && _documents.isEmpty
                    ? const SkeletonList()
                    : _documents.isEmpty
                        ? _buildEmptyState(theme)
                        : _buildDocumentsList(theme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, 0, AppSpacing.base, AppSpacing.base),
      child: Column(
        children: [
          // Type Filter Chips
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _docTypes.length,
              itemBuilder: (context, idx) {
                final type = _docTypes[idx];
                final isSelected = _selectedDocType == type;
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type.toUpperCase()),
                    selected: isSelected,
                    selectedColor: theme.colorScheme.primary,
                    backgroundColor: Colors.white24,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedDocType = type);
                        _loadDocuments(refresh: true);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      itemCount: _documents.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, idx) {
        if (idx == _documents.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.base),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final doc = _documents[idx];
        final ext =
            doc['extension'] ?? doc['file_type']?.toString().split('.').last;
        final sizeStr = _formatFileSize(doc['file_size'] ?? doc['size']);
        final hasAccess = doc['has_access'] ?? true;
        final accessRequested = doc['access_requested'] ?? false;
        final cabinetId = doc['cabinet_id'];
        final cabinetName =
            doc['cabinet_object_number'] ?? doc['cabinet_name'] ?? 'ШУ';

        final fileUrl = doc['file_url'] ?? doc['url'];
        final fileName =
            FileSaveHelper.ensureExtension(doc['title'] ?? 'document', fileUrl);
        final isDownloaded = _downloadedFileNames.contains(fileName);

        return AnimatedCard(
          index: idx,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Row(
              children: [
                // File Type Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getFileIconColor(ext).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getFileIcon(ext),
                    color: _getFileIconColor(ext),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Doc Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (hasAccess) {
                            if (isDownloaded) {
                              _openDownloadedDocument(fileName);
                            } else {
                              _downloadDocument(doc);
                            }
                          } else if (!accessRequested) {
                            _requestDocumentAccess(doc);
                          }
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                doc['title'] ?? 'Без названия',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  decoration: hasAccess
                                      ? TextDecoration.underline
                                      : null,
                                ),
                              ),
                            ),
                            if (!hasAccess) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.lock,
                                  size: 16, color: Colors.orange),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (sizeStr.isNotEmpty) ...[
                            Text(sizeStr,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey)),
                            const SizedBox(width: 8),
                            const Text('•',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 10)),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: GestureDetector(
                              onTap: () {
                                if (cabinetId != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ShuDetailScreen(
                                        shuId: cabinetId.toString(),
                                        initialTab: 1, // Documents tab
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                cabinetName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Access Actions
                if (!hasAccess)
                  ElevatedButton(
                    onPressed: accessRequested
                        ? null
                        : () => _requestDocumentAccess(doc),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      accessRequested ? 'Ждем' : 'Доступ',
                      style: const TextStyle(fontSize: 11),
                    ),
                  )
                else
                  IconButton(
                    icon: _downloadingDoc
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : (isDownloaded
                            ? Icon(Icons.visibility,
                                color: theme.colorScheme.primary)
                            : Icon(Icons.download,
                                color: theme.colorScheme.primary)),
                    tooltip: isDownloaded ? 'Просмотреть' : 'Скачать',
                    onPressed: isDownloaded
                        ? () => _openDownloadedDocument(fileName)
                        : () => _downloadDocument(doc),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open,
              size: 64, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Документы не найдены',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Попробуйте изменить параметры фильтрации',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.start,
          ),
        ],
      ),
    );
  }
}

