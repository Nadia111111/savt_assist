// lib/screens/project_cabinets_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/animated_card.dart';
import '../widgets/skeletons.dart';
import '../models/cabinet.dart';
import '../models/project.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/draggable_floating_pill_overlay.dart';
import '../widgets/document_action_button.dart';
import '../services/file_save_helper.dart';
import '../services/download_manager.dart';
import '../main.dart';

class ProjectCabinetsScreen extends StatefulWidget {
  final int projectId;
  final String projectName;

  const ProjectCabinetsScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ProjectCabinetsScreen> createState() => _ProjectCabinetsScreenState();
}

class _ProjectCabinetsScreenState extends State<ProjectCabinetsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  ProjectDetails? _projectDetails;
  List<Cabinet> _userCabinets = [];
  List<Map<String, dynamic>> _projectDocuments = [];
  final Set<String> _downloadedFileNames = {};
  bool _loadingDocs = false;

  bool _isLoading = true;
  String _error = '';
  bool _isSubmitting = false;
  final TextEditingController _commentController = TextEditingController();

  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(canRequestFocus: false);
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted && _selectedTabIndex != _tabController.index) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
    _loadProjectDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _addCabinetByPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    setState(() => _isSubmitting = true);

    try {
      final photoUrl = await uploadService.uploadAttachment(pickedFile.path);
      await cabinetService.addCabinetByPhoto(
        projectId: widget.projectId,
        photoUrl: photoUrl,
        userComment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заявка на добавление шкафа отправлена'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _commentController.clear();
        _loadProjectDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _loadProjectDetails({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }

    _loadProjectDocuments();

    try {
      final cachedCabs = await cabinetService.getUserCabinets(forceRefresh: false);
      if (mounted && cachedCabs.isNotEmpty) {
        setState(() {
          _userCabinets = cachedCabs;
          if (_isLoading && cachedCabs.any((c) => c.projectId == widget.projectId)) {
            _isLoading = false;
          }
        });
      }
    } catch (_) {}

    try {
      final details = await cabinetService.getProjectDetails(widget.projectId);
      final userCabs = await cabinetService.getUserCabinets(forceRefresh: true);

      if (mounted) {
        setState(() {
          _projectDetails = details;
          _userCabinets = userCabs;
          _isLoading = false;
        });
        debugPrint(
            '📊 [ProjectCabinets] projectCabinets=${details.cabinets.length}, userCabinets=${userCabs.length}');
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('403') ||
            errStr.contains('404') ||
            errStr.contains('не найден') ||
            errStr.contains('недоступен')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Проект больше недоступен'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
          return;
        }
        if (showLoading) {
          setState(() {
            _error = e.toString();
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _loadProjectDocuments() async {
    setState(() => _loadingDocs = true);
    try {
      final docs = await cabinetService.getProjectDocuments(widget.projectId);
      if (mounted) {
        setState(() {
          _projectDocuments = docs;
          _loadingDocs = false;
        });
        _checkDownloadedFiles();
      }
    } catch (e) {
      debugPrint('🔴 [ProjectDocuments] Error loading: $e');
      if (mounted) {
        setState(() => _loadingDocs = false);
      }
    }
  }

  Future<void> _checkDownloadedFiles() async {
    final downloaded = <String>{};
    for (final doc in _projectDocuments) {
      final fileUrl = doc['file_url'] ?? doc['url'];
      final fileName =
          FileSaveHelper.ensureExtension(doc['title'] ?? 'document', fileUrl);
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Не удалось открыть файл: ${result.message}'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Файл не найден. Пожалуйста, скачайте его заново.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadDocument(Map<String, dynamic> doc) async {
    final docId = doc['id'];
    final fileUrl = doc['file_url'] ?? doc['url'];
    final fileName =
        FileSaveHelper.ensureExtension(doc['title'] ?? 'document', fileUrl);

    if (doc['has_access'] == false) {
      _requestDocumentAccess(doc);
      return;
    }

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
    if (DownloadManager.instance.isDocDownloading(docId)) return;

    await DownloadManager.instance.startDownload(
      context: context,
      docId: docId,
      fileName: fileName,
      downloadAction: (cancelToken, onProgress) {
        return cabinetService.downloadDocumentWithProgress(
          docId,
          cancelToken: cancelToken,
          onProgress: onProgress,
        );
      },
      onCompleted: (savePath) async {
        if (mounted && !kIsWeb) {
          setState(() {
            _downloadedFileNames.add(fileName);
          });
        }
      },
    );
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

    if (comment != null && comment.isNotEmpty) {
      try {
        final docId = doc['id'];
        await cabinetService.requestDocumentAccess(docId, userMessage: comment);
        if (mounted) {
          setState(() {
            doc['access_requested'] = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Запрос на доступ успешно отправлен'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка отправки запроса: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _togglePinCabinet(Cabinet cabinet) async {
    final newPinned = !cabinet.isPinned;
    final cabId = cabinet.cabinetId;

    setState(() {
      _userCabinets = _userCabinets.map((c) {
        if (c.cabinetId == cabId) {
          return c.copyWith(isPinned: newPinned);
        }
        return c;
      }).toList();

      if (_projectDetails != null) {
        final updatedProjectCabs = _projectDetails!.cabinets.map((pc) {
          if (pc.id == cabId) {
            return ProjectCabinetInfo(
              id: pc.id,
              type: pc.type,
              objectNumber: pc.objectNumber,
              adminInternalName: pc.adminInternalName,
              isPinned: newPinned,
            );
          }
          return pc;
        }).toList();

        _projectDetails =
            _projectDetails!.copyWith(cabinets: updatedProjectCabs);
      }
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
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userCabinets = _userCabinets.map((c) {
            if (c.cabinetId == cabId) {
              return c.copyWith(isPinned: !newPinned);
            }
            return c;
          }).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка изменения закрепления: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    // Формируем список ШУ для проекта.
    // Сначала добавляем ШУ из projectDetails, затем дополняем любыми ШУ из _userCabinets с этим projectId.
    final List<Cabinet> enrichedCabinets = [];
    final Map<int, Cabinet> userCabinetMap = {
      for (final c in _userCabinets) c.cabinetId: c
    };
    final Set<int> addedCabinetIds = {};

    if (_projectDetails != null) {
      for (final pcab in _projectDetails!.cabinets) {
        addedCabinetIds.add(pcab.id);
        final userCab = userCabinetMap[pcab.id];
        final isPinned = (userCab?.isPinned ?? false) || pcab.isPinned;
        enrichedCabinets.add(
          (userCab ??
              Cabinet(
                cabinetId: pcab.id,
                type: pcab.type,
                objectNumber: pcab.objectNumber,
                customName: pcab.adminInternalName ?? '',
                unreadCount: 0,
                warrantyStatus: 'unknown',
                isPinned: isPinned,
              )).copyWith(isPinned: isPinned),
        );
      }
    }

    // Добавляем любые ШУ из списка пользователя, которые привязаны к этому проекту,
    // но ещё не попали в enrichedCabinets
    for (final cab in _userCabinets) {
      if (cab.projectId == widget.projectId &&
          !addedCabinetIds.contains(cab.cabinetId)) {
        enrichedCabinets.add(cab);
        addedCabinetIds.add(cab.cabinetId);
      }
    }

    // Закрепленные шкафы ВСЕГДА идут первыми в списке
    enrichedCabinets.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      final aName = a.displayName;
      final bName = b.displayName;
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });
    debugPrint(
        '📊 [ProjectCabinets] projectCabinets=${_projectDetails?.cabinets.length ?? 0} enriched=${enrichedCabinets.length} userCabinets=${_userCabinets.length}');

    final filteredCabinets = _searchQuery.trim().isEmpty
        ? enrichedCabinets
        : enrichedCabinets.where((c) {
            final q = _searchQuery.toLowerCase().trim();
            final matchesName = c.displayName.toLowerCase().contains(q);
            final matchesObjectNumber =
                c.objectNumber.toLowerCase().contains(q);
            final matchesType = c.type.toLowerCase().contains(q);
            return matchesName || matchesObjectNumber || matchesType;
          }).toList();

    return GradientScaffold(
      appBarTitle: widget.projectName,
      showBackButton: true,
      appBarAction: IconButton(
        icon: Icon(_isSearchExpanded ? Icons.close : Icons.search,
            color: Colors.white),
        onPressed: () {
          if (_isSearchExpanded) {
            _searchFocusNode.canRequestFocus = false;
            _searchFocusNode.unfocus(
                disposition: UnfocusDisposition.previouslyFocusedChild);
            FocusManager.instance.primaryFocus?.unfocus();
            setState(() {
              _isSearchExpanded = false;
              _searchQuery = '';
              _searchController.clear();
            });
          } else {
            _searchFocusNode.canRequestFocus = true;
            setState(() {
              _isSearchExpanded = true;
            });
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted && _isSearchExpanded) {
                _searchFocusNode.requestFocus();
              }
            });
          }
        },
      ),
      body: DraggableFloatingPillOverlay(
        storageKey: 'fab_pos_add_shu',
        heroTag: 'scanner_to_add_shu',
        icon: Icons.camera_alt,
        label: 'Добавить ШУ',
        estimatedWidth: 160.0,
        isVisible: _selectedTabIndex == 0 && !_isSubmitting,
        onTap: _addCabinetByPhoto,
        child: ResponsiveContainer(
          maxWidth: 600,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOutCubic,
                height: _isSearchExpanded ? 68 : 0,
                padding: EdgeInsets.symmetric(
                  horizontal: _isSearchExpanded ? 16 : 0,
                  vertical: _isSearchExpanded ? 6 : 0,
                ),
                child: ClipRect(
                  child: OverflowBox(
                    minHeight: 0,
                    maxHeight: 68,
                    alignment: Alignment.topCenter,
                    child: AnimatedOpacity(
                      opacity: _isSearchExpanded ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: ExcludeFocus(
                        excluding: !_isSearchExpanded,
                        child: IgnorePointer(
                          ignoring: !_isSearchExpanded,
                          child: _buildSearchField(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor:
                    Theme.of(context).colorScheme.onSurfaceVariant,
                indicatorColor: Theme.of(context).colorScheme.primary,
                indicatorWeight: 3,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Шкафы'),
                  Tab(text: 'Документы'),
                ],
              ),

              // Содержимое вкладок
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCabinetsTab(enrichedCabinets, filteredCabinets),
                    _buildDocumentsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildCabinetsTab(
      List<Cabinet> enrichedCabinets, List<Cabinet> filteredCabinets) {
    if (_isLoading) {
      return const SkeletonList();
    }

    return RefreshIndicator(
      onRefresh: _loadProjectDetails,
      color: AppColors.primaryLight,
      child: _error.isNotEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: _buildErrorState(),
                ),
              ],
            )
          : enrichedCabinets.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: _buildEmptyState(),
                    ),
                  ],
                )
              : filteredCabinets.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: _buildSearchEmptyState(),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.base),
                      itemCount: filteredCabinets.length,
                      itemBuilder: (context, index) {
                        final cabinet = filteredCabinets[index];
                        return _buildCabinetCard(cabinet, index);
                      },
                    ),
    );
  }

  Widget _buildDocumentsTab() {
    if (_loadingDocs && _projectDocuments.isEmpty) {
      return const SkeletonList();
    }

    final query = _searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _projectDocuments
        : _projectDocuments.where((doc) {
            final title = (doc['title'] ?? '').toString().toLowerCase();
            final docType = (doc['doc_type'] ?? '').toString().toLowerCase();
            final tags = (doc['tags'] as List?)
                    ?.map((t) => (t['name'] ?? '').toString().toLowerCase())
                    .join(' ') ??
                '';
            return title.contains(query) ||
                docType.contains(query) ||
                tags.contains(query);
          }).toList();

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadProjectDocuments,
        color: AppColors.primaryLight,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      query.isNotEmpty
                          ? Icons.search_off
                          : Icons.folder_open_outlined,
                      size: 56,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      query.isNotEmpty
                          ? 'Документы не найдены'
                          : 'В проекте пока нет документов',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (query.isEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Общая документация проекта появится здесь',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProjectDocuments,
      color: AppColors.primaryLight,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.base),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final doc = filtered[index];
          return _buildProjectDocumentCard(doc);
        },
      ),
    );
  }

  Widget _buildProjectDocumentCard(Map<String, dynamic> doc) {
    final theme = Theme.of(context);
    final hasAccess = doc['has_access'] != false;
    final accessRequested = doc['access_requested'] == true;
    final docType = (doc['doc_type'] ?? '').toString().toLowerCase();

    IconData icon;
    Color iconColor;
    switch (docType) {
      case 'pdf':
        icon = Icons.picture_as_pdf_rounded;
        iconColor = Colors.red.shade700;
        break;
      case 'doc':
      case 'docx':
      case 'word':
        icon = Icons.description_rounded;
        iconColor = Colors.blue.shade700;
        break;
      case 'xls':
      case 'xlsx':
      case 'excel':
        icon = Icons.table_chart_rounded;
        iconColor = Colors.green.shade700;
        break;
      case 'dwg':
      case 'dxf':
      case 'schema':
      case 'drawing':
        icon = Icons.architecture_rounded;
        iconColor = Colors.teal.shade700;
        break;
      default:
        icon = Icons.insert_drive_file_rounded;
        iconColor = theme.colorScheme.primary;
    }

    final fileUrl = doc['file_url'] ?? doc['url'];
    final fileName =
        FileSaveHelper.ensureExtension(doc['title'] ?? 'document', fileUrl);
    final isDownloaded = _downloadedFileNames.contains(fileName);
    final docId = doc['id'] ?? 0;

    final tags = (doc['tags'] as List?)
            ?.map((t) => t['name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toList() ??
        [];

    final sizeBytes = doc['file_size_bytes'];
    final sizeText = sizeBytes != null
        ? '${(sizeBytes / 1024).round()} KB'
        : (doc['doc_type'] ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: hasAccess
            ? () => (isDownloaded && !kIsWeb)
                ? _openDownloadedDocument(fileName)
                : (DownloadManager.instance.isDocDownloading(docId) ||
                        DownloadManager.instance.isDocQueued(docId))
                    ? DownloadManager.instance.expand()
                    : _downloadDocument(doc)
            : () => _requestDocumentAccess(doc),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                doc['title'] ?? 'Документ проекта',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            if (!hasAccess) ...[
              const SizedBox(width: 8),
              const Icon(Icons.lock_rounded, size: 16, color: Colors.orange),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 2),
            Text(
              sizeText,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: tags.map((t) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#$t',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        trailing: ValueListenableBuilder<List<DownloadTask>>(
          valueListenable: DownloadManager.instance.tasksNotifier,
          builder: (context, _, __) {
            final isDownloading = DownloadManager.instance.isDocDownloading(docId);
            final isQueued = DownloadManager.instance.isDocQueued(docId);
            final currentTask = DownloadManager.instance.currentTaskNotifier.value;
            final taskProgress = (isDownloading && currentTask != null && currentTask.docId == docId)
                ? currentTask.progress
                : null;

            return DocumentActionButton(
              hasAccess: hasAccess,
              isDownloaded: isDownloaded && !kIsWeb,
              isDownloading: isDownloading,
              isQueued: isQueued,
              accessRequested: accessRequested,
              progress: taskProgress,
              onDownload: () => _downloadDocument(doc),
              onOpen: () => _openDownloadedDocument(fileName),
              onRequestAccess: () => _requestDocumentAccess(doc),
              onShowQueue: () => DownloadManager.instance.expand(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCabinetCard(Cabinet cabinet, int index) {
    final theme = Theme.of(context);
    final statusColor = _getWarrantyColor(cabinet.warrantyStatus);
    final displayName =
        cabinet.customName.isNotEmpty ? cabinet.customName : cabinet.type;

    return AnimatedCard(
      index: index,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.base),
      onTap: () async {
        await Navigator.pushNamed(context, '/shu-detail/${cabinet.cabinetId}');
        if (mounted) {
          _loadProjectDetails(showLoading: false);
        }
      },
      onLongPress: () => _togglePinCabinet(cabinet),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.memory, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  cabinet.objectNumber,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getWarrantyIcon(cabinet.warrantyStatus),
                        size: 12,
                        color: statusColor,
                      ),
                      gapW4,
                      Text(
                        _getWarrantyText(cabinet.warrantyStatus),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (cabinet.isPinned)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkResponse(
                onTap: () => _togglePinCabinet(cabinet),
                radius: 18,
                child: Transform.rotate(
                  angle: 0.4,
                  child: Icon(
                    Icons.push_pin,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
            gapH16,
            const Text(
              'Не удалось загрузить шкафы проекта',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            gapH8,
            Text(
              _error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            gapH24,
            ElevatedButton(
              onPressed: _loadProjectDetails,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.memory_outlined,
                  size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            ),
            gapH20,
            Text('В этом проекте пока нет доступных шкафов управления.',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            gapH8,
            Text('Вы можете добавить его в проект с помощью фото',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                     ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded,
                  size: 40, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
            ),
            gapH16,
            Text('Ничего не найдено',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            gapH8,
            Text(
              'По запросу "$_searchQuery" шкафы не найдены',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        enabled: _isSearchExpanded,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: _selectedTabIndex == 0
              ? 'Поиск шкафов в проекте...'
              : 'Поиск документов проекта...',
          prefixIcon: Icon(Icons.search,
              color: theme.colorScheme.onSurfaceVariant, size: 24),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear,
                      size: 20, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Color _getWarrantyColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'expiring_soon':
        return AppColors.warning;
      case 'expired':
        return AppColors.error;
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getWarrantyText(String status) {
    switch (status) {
      case 'active':
        return 'На гарантии';
      case 'expiring_soon':
        return 'Скоро истекает';
      case 'expired':
        return 'Гарантия истекла';
      default:
        return 'Статус неизвестен';
    }
  }

  IconData _getWarrantyIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.verified_user_outlined;
      case 'expiring_soon':
        return Icons.gpp_maybe_outlined;
      case 'expired':
        return Icons.gpp_bad_outlined;
      default:
        return Icons.help_outline;
    }
  }
}
