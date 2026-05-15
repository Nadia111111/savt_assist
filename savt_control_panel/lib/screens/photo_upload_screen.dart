// lib/screens/photo_upload_screen.dart
import 'package:flutter/material.dart';
import '../models/shu_model.dart';
import '../services/mock_data.dart';
import '../services/network_service.dart';

class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({super.key});

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  final TextEditingController _objectNumberController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  String? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        _objectNumberController.text = args;
      }
    });
  }

  void _takePhoto() {
    setState(() {
      _selectedImage = 'https://picsum.photos/seed/uploaded/400/400';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Фото сделано (демо-режим)'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _selectFromGallery() {
    setState(() {
      _selectedImage = 'https://picsum.photos/seed/gallery/400/400';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Фото выбрано из галереи (демо-режим)'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _submitForReview() async {
    final objectNumber = _objectNumberController.text.trim();

    if (objectNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите номер объекта'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сделайте фото наклейки'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 2));

    setState(() => _isLoading = false);

    final newShu = ShuModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'Новый ШУ',
      objectNumber: objectNumber,
      customName: '',
      comment: _commentController.text.trim(),
      warrantyStatus: 'active',
      warrantyDaysRemaining: 0,
      warrantyStart: '',
      warrantyEnd: '',
      moderationStatus: 'moderation',
      unreadMessages: 0,
      addedDate: DateTime.now(),
    );

    MockData.allShuList.add(newShu);

    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Icon(Icons.check_circle,
                color: Color(0xFF10B981), size: 48),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Text('Фото отправлено на проверку!',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            theme.colorScheme.onSurface)),
                const SizedBox(height: 8),
                Text('Обработка заявки занимает 1-2 рабочих дня',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: theme.brightness == Brightness.dark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B))),
              ],
            ),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Хорошо',
                      style: TextStyle(color: Color(0xFF054582))),
                ),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _objectNumberController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: NetworkService.isOnlineNotifier,
      builder: (context, isOnline, child) {
        return Scaffold(
          backgroundColor:
              theme.brightness == Brightness.dark ? const Color(0xFF0B1120) : const Color(0xFFF1F4F8),
          appBar: AppBar(
            backgroundColor:
                theme.colorScheme.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Отправка фото наклейки',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF054582).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFF054582).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Color(0xFF054582), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Для старых моделей ШУ без QR-кода отправьте фото заводской наклейки. Мы добавим ваше устройство вручную.',
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: theme.brightness == Brightness.dark
                                  ? Colors.white
                                  : const Color(0xFF1F2937)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: theme.brightness == Brightness.dark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Номер объекта',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: theme.brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _objectNumberController,
                        style: TextStyle(
                            color: theme.brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF1F2937)),
                        decoration: InputDecoration(
                          hintText: 'Например: ОБ-2024-001',
                          hintStyle: TextStyle(
                              color: theme.brightness == Brightness.dark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: theme.brightness == Brightness.dark
                              ? const Color(0xFF151F2E)
                              : const Color(0xFFF1F4F8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Указан на наклейке или в документах',
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Фото наклейки',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: theme.brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedImage == null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _takePhoto,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Сделать фото'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF054582),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _selectFromGallery,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Выбрать из галереи'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: theme.brightness == Brightness.dark
                                      ? const Color(0xFF2A3A4D)
                                      : const Color(0xFF054582)),
                              foregroundColor: theme.brightness == Brightness.dark
                                  ? Colors.white
                                  : const Color(0xFF054582),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: theme.brightness == Brightness.dark
                                    ? const Color(0xFF2A3A4D)
                                    : const Color(0xFFE3EEFF),
                                width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              children: [
                                Image.network(
                                  _selectedImage!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 200,
                                    color: theme.brightness == Brightness.dark
                                        ? const Color(0xFF151F2E)
                                        : const Color(0xFFF1F4F8),
                                    child: Center(
                                      child: Icon(Icons.broken_image,
                                          size: 48,
                                          color: theme.brightness == Brightness.dark
                                              ? const Color(0xFF64748B)
                                              : const Color(0xFF6B7280)),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: _removeImage,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF991B1B),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          size: 18, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Фото должно быть четким, все данные должны читаться',
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.brightness == Brightness.dark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF6B7280)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Комментарий (необязательно)',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: theme.brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _commentController,
                        maxLines: 4,
                        style: TextStyle(
                            color: theme.brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF1F2937)),
                        decoration: InputDecoration(
                          hintText: 'Дополнительная информация...',
                          hintStyle: TextStyle(
                              color: theme.brightness == Brightness.dark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: theme.brightness == Brightness.dark
                              ? const Color(0xFF151F2E)
                              : const Color(0xFFF1F4F8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_isLoading || !isOnline)
                              ? null
                              : _submitForReview,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF054582),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.upload_file, size: 20),
                                    SizedBox(width: 8),
                                    Text('Отправить на проверку',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Обработка заявки занимает 1-2 рабочих дня',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF6B7280)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
