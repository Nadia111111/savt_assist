// lib/screens/shared_media_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../services/file_save_helper.dart';
import '../services/api_client.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/download_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';
import '../models/chat_attachment.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/voice_message_player.dart';
import '../widgets/skeletons.dart';
import '../widgets/auth_image.dart';
import '../widgets/keep_alive_wrapper.dart';
import '../main.dart';
import 'fullscreen_image_viewer.dart';

class SharedMediaScreen extends StatefulWidget {
  final String chatId;
  final String chatTitle;
  final List<ChatMessage> messages;
  final Function(String) onSendEdited;
  final Function(Uint8List bytes, String fileName)? onSendEditedBytes;
  final Function(String) onNavigateToMessage;

  const SharedMediaScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
    required this.messages,
    required this.onSendEdited,
    this.onSendEditedBytes,
    required this.onNavigateToMessage,
  });

  @override
  State<SharedMediaScreen> createState() => _SharedMediaScreenState();
}

class _SharedMediaScreenState extends State<SharedMediaScreen> {
  int _activeTabIndex = 0;

  final List<ChatAttachmentModel> _images = [];
  final List<ChatAttachmentModel> _files = [];
  final List<ChatAttachmentModel> _voices = [];
  final List<ChatMessage> _linkMessages = [];

  // Scroll Controllers
  final ScrollController _photosScrollController = ScrollController();
  final ScrollController _filesScrollController = ScrollController();
  final ScrollController _voicesScrollController = ScrollController();
  late PageController _pageController;

  // Pagination states
  int _imagesPage = 1;
  bool _imagesHasMore = true;
  bool _isLoadingImages = false;

  int _filesPage = 1;
  bool _filesHasMore = true;
  bool _isLoadingFiles = false;

  int _voicesPage = 1;
  bool _voicesHasMore = true;
  bool _isLoadingVoices = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _activeTabIndex);
    _processLinks();
    
    // Set up scroll listeners
    _photosScrollController.addListener(() {
      if (_photosScrollController.position.pixels >= _photosScrollController.position.maxScrollExtent - 200) {
        _loadImages();
      }
    });
    _filesScrollController.addListener(() {
      if (_filesScrollController.position.pixels >= _filesScrollController.position.maxScrollExtent - 200) {
        _loadFiles();
      }
    });
    _voicesScrollController.addListener(() {
      if (_voicesScrollController.position.pixels >= _voicesScrollController.position.maxScrollExtent - 200) {
        _loadVoices();
      }
    });

    // Initial load for active tab (0 - Photos)
    _loadImages();
  }

  @override
  void dispose() {
    _photosScrollController.dispose();
    _filesScrollController.dispose();
    _voicesScrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _processLinks() {
    _linkMessages.clear();
    for (final msg in widget.messages) {
      if (msg.text.contains(RegExp(r'https?://[^\s]+'))) {
        _linkMessages.add(msg);
      }
    }
  }

  Future<void> _onRefresh() async {
    try {
      final chatIdInt = int.tryParse(widget.chatId) ?? 0;
      if (chatIdInt == 0) return;

      if (_activeTabIndex == 0) {
        // Refresh Images
        final res = await chatService.getChatAttachments(chatIdInt, type: 'image', page: 1, size: 20);
        final items = res['items'] as List? ?? [];
        final list = items.map((item) => ChatAttachmentModel.fromJson(Map<String, dynamic>.from(item))).toList();
        setState(() {
          _images.clear();
          _images.addAll(list);
          _imagesPage = 2;
          _imagesHasMore = list.length >= 20;
        });
      } else if (_activeTabIndex == 1) {
        // Refresh Files
        final res = await chatService.getChatAttachments(chatIdInt, type: 'document', page: 1, size: 20);
        final items = res['items'] as List? ?? [];
        final list = items.map((item) => ChatAttachmentModel.fromJson(Map<String, dynamic>.from(item))).toList();
        setState(() {
          _files.clear();
          _files.addAll(list);
          _filesPage = 2;
          _filesHasMore = list.length >= 20;
        });
      } else if (_activeTabIndex == 3) {
        // Refresh Voices
        final res = await chatService.getChatAttachments(chatIdInt, type: 'voice', page: 1, size: 20);
        final items = res['items'] as List? ?? [];
        final list = items.map((item) => ChatAttachmentModel.fromJson(Map<String, dynamic>.from(item))).toList();
        setState(() {
          _voices.clear();
          _voices.addAll(list);
          _voicesPage = 2;
          _voicesHasMore = list.length >= 20;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка обновления: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadImages() async {
    if (_isLoadingImages || !_imagesHasMore) return;
    setState(() => _isLoadingImages = true);

    try {
      final chatIdInt = int.tryParse(widget.chatId) ?? 0;
      if (chatIdInt == 0) return;

      final res = await chatService.getChatAttachments(
        chatIdInt,
        type: 'image',
        page: _imagesPage,
        size: 20,
      );
      final items = res['items'] as List? ?? [];
      final list = items.map((item) => ChatAttachmentModel.fromJson(Map<String, dynamic>.from(item))).toList();

      setState(() {
        _images.addAll(list);
        _imagesPage++;
        _imagesHasMore = list.length >= 20;
      });
    } catch (e) {
      debugPrint('Error loading images attachments: $e');
      _showError('Ошибка загрузки изображений: $e');
    } finally {
      setState(() => _isLoadingImages = false);
    }
  }

  Future<void> _loadFiles() async {
    if (_isLoadingFiles || !_filesHasMore) return;
    setState(() => _isLoadingFiles = true);

    try {
      final chatIdInt = int.tryParse(widget.chatId) ?? 0;
      if (chatIdInt == 0) return;

      final res = await chatService.getChatAttachments(
        chatIdInt,
        type: 'document',
        page: _filesPage,
        size: 20,
      );
      final items = res['items'] as List? ?? [];
      final list = items.map((item) => ChatAttachmentModel.fromJson(Map<String, dynamic>.from(item))).toList();

      setState(() {
        _files.addAll(list);
        _filesPage++;
        _filesHasMore = list.length >= 20;
      });
    } catch (e) {
      debugPrint('Error loading files attachments: $e');
      _showError('Ошибка загрузки файлов: $e');
    } finally {
      setState(() => _isLoadingFiles = false);
    }
  }

  Future<void> _loadVoices() async {
    if (_isLoadingVoices || !_voicesHasMore) return;
    setState(() => _isLoadingVoices = true);

    try {
      final chatIdInt = int.tryParse(widget.chatId) ?? 0;
      if (chatIdInt == 0) return;

      final res = await chatService.getChatAttachments(
        chatIdInt,
        type: 'voice',
        page: _voicesPage,
        size: 20,
      );
      final items = res['items'] as List? ?? [];
      final list = items.map((item) => ChatAttachmentModel.fromJson(Map<String, dynamic>.from(item))).toList();

      setState(() {
        _voices.addAll(list);
        _voicesPage++;
        _voicesHasMore = list.length >= 20;
      });
    } catch (e) {
      debugPrint('Error loading voices attachments: $e');
      _showError('Ошибка загрузки голосовых: $e');
    } finally {
      setState(() => _isLoadingVoices = false);
    }
  }

  void _onTabChanged(int index) {
    setState(() {
      _activeTabIndex = index;
    });
    _pageController.jumpToPage(index);
    if (index == 0 && _images.isEmpty) {
      _loadImages();
    } else if (index == 1 && _files.isEmpty) {
      _loadFiles();
    } else if (index == 3 && _voices.isEmpty) {
      _loadVoices();
    }
  }

  String _formatTimeFromIso(String iso) {
    try {
      final date = DateTime.parse(iso);
      return DateFormat('HH:mm').format(date);
    } catch (_) {
      return '';
    }
  }

  Future<void> _downloadFile(ChatAttachment attachment) async {
    if (attachment.fileUrl == null) return;
    final progressController = StreamController<double>();
    try {
      showDownloadProgressDialog(context, attachment.fileName, progressController.stream);
      List<int>? bytes;
      try {
        bytes = await uploadService.downloadFile(
          attachment.fileUrl!,
          onProgress: (sent, total) {
            if (total > 0) {
              progressController.add(sent / total);
            }
          },
        );
      } catch (downloadErr) {
        debugPrint('Failed to download media bytes: $downloadErr');
        if (kIsWeb) {
          if (mounted) Navigator.pop(context); // Close progress dialog
          final fullUrl = attachment.fileUrl!.startsWith('http')
              ? attachment.fileUrl!
              : '${ApiClient.baseUrl}${attachment.fileUrl!.startsWith('/') ? '' : '/'}${attachment.fileUrl!}';
          await FileSaveHelper.saveUrl(
            context: context,
            url: fullUrl,
            fileName: attachment.fileName,
          );
          return;
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      await FileSaveHelper.saveFile(
        context: context,
        bytes: bytes,
        fileName: attachment.fileName,
      );
    } catch (e) {
      if (mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {}
      }
      _showError('Ошибка скачивания: $e');
    } finally {
      progressController.close();
    }
  }

  void _showError(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          width: kIsWeb ? 420 : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _launchURL(String urlString) async {
    String targetUrl = urlString;
    if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
      targetUrl = 'https://$targetUrl';
    }
    final uri = Uri.parse(targetUrl);
    try {
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success) {
        final fallbackSuccess = await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (!fallbackSuccess) {
          _showError('Не удалось открыть ссылку: $targetUrl');
        }
      }
    } catch (e) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (ex) {
        _showError('Ошибка при открытии ссылки: $ex');
      }
    }
  }

  Widget _buildTabChip(String label, int index) {
    final theme = Theme.of(context);
    final isSelected = _activeTabIndex == index;
    final accentColor = theme.colorScheme.primary;

    return GestureDetector(
      onTap: () => _onTabChanged(index),
      child: Container(
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? accentColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentColor : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotosTab() {
    if (_images.isEmpty && _isLoadingImages) {
      return const SkeletonGrid();
    }
    if (_images.isEmpty) {
      return const Center(child: Text('Здесь пока нет фотографий', style: TextStyle(color: Colors.grey)));
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: _photosScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _images.length,
            itemBuilder: (context, idx) {
              final attModel = _images[idx];
              final att = attModel.attachment;
              final heroTag = 'shared_media_${attModel.messageId}_${att.fileName}_$idx';
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: heroTag,
                        child: (!kIsWeb && att.localPath != null && File(att.localPath!).existsSync())
                            ? Image.file(File(att.localPath!), fit: BoxFit.cover)
                            : AuthImage(url: att.fileUrl ?? '', fit: BoxFit.cover),
                      ),
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              final sent = await Navigator.push<bool>(
                                context,
                                PageRouteBuilder(
                                  opaque: false,
                                  barrierColor: Colors.transparent,
                                  transitionDuration: const Duration(milliseconds: 260),
                                  reverseTransitionDuration: const Duration(milliseconds: 220),
                                  pageBuilder: (context, animation, secondaryAnimation) => FullscreenImageViewer(
                                    imageUrl: att.fileUrl,
                                    localPath: kIsWeb ? null : att.localPath,
                                    fileName: att.fileName,
                                    heroTag: heroTag,
                                    onDownloadRequest: (url) => uploadService.downloadFile(url),
                                    onSendEdited: widget.onSendEdited,
                                    onSendEditedBytes: widget.onSendEditedBytes,
                                    onShowInChat: () {
                                      Navigator.pop(context); // Close FullscreenImageViewer
                                      widget.onNavigateToMessage(attModel.messageId);
                                    },
                                  ),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return FadeTransition(opacity: animation, child: child);
                                  },
                                ),
                              );

                              // If edited photo was sent to chat from the viewer, close gallery so user returns to chat
                              if (sent == true && mounted) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_isLoadingImages)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: Center(child: ShimmerBlock(height: 40, borderRadius: 12)),
          ),
      ],
    );
  }

  Widget _buildFilesTab() {
    if (_files.isEmpty && _isLoadingFiles) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_files.isEmpty) {
      return const Center(child: Text('Здесь пока нет файлов', style: TextStyle(color: Colors.grey)));
    }

    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _filesScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
            itemCount: _files.length,
            itemBuilder: (context, idx) {
              final attModel = _files[idx];
              final att = attModel.attachment;
              final sizeText = att.fileSizeBytes != null
                  ? '${(att.fileSizeBytes! / 1024).toStringAsFixed(1)} KB'
                  : '';

              return GestureDetector(
                onTap: () => widget.onNavigateToMessage(attModel.messageId),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.insert_drive_file, color: accentColor, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              att.fileName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (sizeText.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(sizeText, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download_rounded, color: Colors.blue),
                        onPressed: () => _downloadFile(att),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_isLoadingFiles)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: Center(child: ShimmerBlock(height: 40, borderRadius: 12)),
          ),
      ],
    );
  }

  Widget _buildLinksTab() {
    if (_linkMessages.isEmpty) {
      return const Center(child: Text('Здесь пока нет ссылок', style: TextStyle(color: Colors.grey)));
    }

    final theme = Theme.of(context);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
      itemCount: _linkMessages.length,
      itemBuilder: (context, idx) {
        final msg = _linkMessages[idx];
        final senderText = msg.isOwn ? 'Вы' : 'Собеседник';

        // Extract all URLs
        final matches = RegExp(r'https?://[^\s]+').allMatches(msg.text);
        final urls = matches.map((m) => m.group(0)!).toList();

        return GestureDetector(
          onTap: () => widget.onNavigateToMessage(msg.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      senderText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: msg.isOwn ? Colors.blue : Colors.deepOrange,
                      ),
                    ),
                    const Spacer(),
                    Text(msg.time, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
                gapH8,
                ...urls.map((url) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        const Icon(Icons.link, color: Colors.blue, size: 18),
                        gapW8,
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _launchURL(url),
                            child: Text(
                              url,
                              style: const TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: url));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Ссылка скопирована в буфер обмена'), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVoiceTab() {
    if (_voices.isEmpty && _isLoadingVoices) {
      return const SkeletonGrid();
    }
    if (_voices.isEmpty) {
      return const Center(child: Text('Здесь пока нет голосовых сообщений', style: TextStyle(color: Colors.grey)));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final voiceColor = isDark ? Colors.lightBlueAccent : Colors.blue.shade700;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _voicesScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
            itemCount: _voices.length,
            itemBuilder: (context, idx) {
              final attModel = _voices[idx];
              final att = attModel.attachment;
              final senderText = attModel.senderId == null 
                  ? 'Собеседник'
                  : 'Пользователь';

              return GestureDetector(
                onTap: () => widget.onNavigateToMessage(attModel.messageId),
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.blue.withValues(alpha: 0.12) 
                        : Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark 
                          ? Colors.blue.withValues(alpha: 0.25) 
                          : Colors.blue.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$senderText • ${_formatTimeFromIso(attModel.createdAt)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: isDark ? Colors.lightBlueAccent : Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                      gapH8,
                      GestureDetector(
                        onTap: () {}, // Prevent navigating when tapping voice player controls
                        child: VoiceMessagePlayer(
                          voiceUrl: att.fileUrl,
                          voicePath: att.localPath,
                          isOwn: false, // Force false so it renders with visible blue/grey colors instead of white
                          initialTranscription: attModel.messageText,
                          activeColor: voiceColor,
                          transparentBackground: true,
                          onGetLocalAudio: () async {
                            if (att.fileUrl == null) return null;
                            try {
                              final bytes = await uploadService.downloadFile(att.fileUrl!);
                              final dir = await getTemporaryDirectory();
                              final file = File('${dir.path}/temp_voice_${attModel.messageId}.m4a');
                              await file.writeAsBytes(bytes);
                              return file.path;
                            } catch (e) {
                              _showError('Ошибка загрузки аудио: $e');
                              return null;
                            }
                          },
                          onTranscribe: () async {
                            await Future.delayed(const Duration(seconds: 2));
                            return "Эта функция будет доступна, когда бэкенд настроит API для перевода голоса в текст. Пока что это тестовая заглушка.";
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_isLoadingVoices)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: Center(child: ShimmerBlock(height: 40, borderRadius: 12)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      currentNavIndex: 2,
      appBarTitle: 'Материалы чата',
      appBarLeading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Горизонтальные вкладки
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: AppSpacing.base),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabChip('Фото', 0),
                      _buildTabChip('Файлы', 1),
                      _buildTabChip('Ссылки', 2),
                      _buildTabChip('Голосовые', 3),
                    ],
                  ),
                ),
              ),
              // Контент вкладки
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: AppColors.primaryLight,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      KeepAliveWrapper(child: _buildPhotosTab()),
                      KeepAliveWrapper(child: _buildFilesTab()),
                      KeepAliveWrapper(child: _buildLinksTab()),
                      KeepAliveWrapper(child: _buildVoiceTab()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
