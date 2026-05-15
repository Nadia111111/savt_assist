import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/mock_data.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final TextEditingController _manualCodeController = TextEditingController();
  String _error = '';
  bool _isScanning = false;

  // Мок-список уже зарегистрированных кодов
  final Set<String> _registeredCodes = {
    'ШУ-24М-2024-001',
    'ШУ-18К-2024-002',
  };

  @override
  void dispose() {
    _manualCodeController.dispose();
    super.dispose();
  }

  void _startScanner() {
    setState(() {
      _isScanning = true;
    });

    // Имитация сканирования через 2 секунды
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        _onCodeScanned('ШУ-24М-2024-001');
      }
    });
  }

  void _onCodeScanned(String code) {
    // Проверяем, зарегистрирован ли уже этот ШУ
    if (_registeredCodes.contains(code)) {
      // Показываем диалог о уже зарегистрированном ШУ
      _showAlreadyRegisteredDialog(code);
      return;
    }

    setState(() {
      _error = '';
    });

    // Показываем диалог успеха для нового ШУ
    showDialog(
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
              Text('ШУ успешно добавлен!',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface)),
              const SizedBox(height: 8),
              Text(
                'Код: $code',
                style: TextStyle(
                    fontSize: 14,
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF9CA3AF)),
              ),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context); // закрыть диалог
                  Navigator.pop(context); // вернуться на главный экран
                },
                child: const Text('Хорошо',
                    style: TextStyle(color: Color(0xFF054582))),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAlreadyRegisteredDialog(String code) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Icon(Icons.info_outline,
              color: Color(0xFFF59E0B), size: 48),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('Это ШУ уже зарегистрировано',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface)),
              const SizedBox(height: 8),
              Text(
                'Код: $code',
                style: TextStyle(
                    fontSize: 14,
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 12),
              Text('Хотите отправить запрос на присоединение к этому ШУ?',
                  style: TextStyle(
                      fontSize: 14,
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B))),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context); // закрыть диалог
                    },
                    child: const Text('Отмена',
                        style: TextStyle(color: Color(0xFF64748B))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Имитация отправки запроса на присоединение
                      Navigator.pop(context); // закрыть диалог
                      _showJoinRequestSuccessDialog(code);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF054582),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Отправить запрос'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showJoinRequestSuccessDialog(String code) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
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
              Text('Запрос отправлен!',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface)),
              const SizedBox(height: 8),
              Text(
                'Запрос на присоединение к $code отправлен на модерацию.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
              ),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context); // закрыть диалог
                  Navigator.pop(context); // вернуться назад
                },
                child: const Text('Хорошо',
                    style: TextStyle(color: Color(0xFF054582))),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleManualSubmit() {
    final code = _manualCodeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _error = 'Введите код ШУ';
      });
      return;
    }

    setState(() {
      _error = '';
    });

    _onCodeScanned(code);
  }

  void _selectFromGallery() {
    // Имитация выбора фото из галереи
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Выбор фото из галереи (демо-режим)'),
        backgroundColor: Color(0xFF054582),
        duration: Duration(seconds: 1),
      ),
    );
    // Имитация сканирования из фото
    Future.delayed(const Duration(seconds: 1), () {
      _onCodeScanned('ШУ-18К-2024-002');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // Красивый градиентный хедер
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: theme.brightness == Brightness.dark
                    ? const [Color(0xFF021A38), Color(0xFF03254C)]
                    : const [Color(0xFF054582), Color(0xFF0a7ac2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Добавить ШУ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // QR-сканер (симуляция)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    height: 320,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.brightness == Brightness.dark
                              ? Colors.black.withOpacity(0.3)
                              : const Color(0xFF054582).withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Имитация камеры с сеткой
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            image: const DecorationImage(
                              image: NetworkImage(
                                  'https://picsum.photos/seed/camera/400/400'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Затемнение по краям
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.6),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withOpacity(0.6),
                              ],
                              stops: const [0, 0.2, 0.8, 1],
                            ),
                          ),
                        ),
                        // Рамка сканирования
                        Center(
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFF054582), width: 3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Stack(
                              children: [
                                // Уголки рамки
                                Positioned(
                                  top: -2,
                                  left: -2,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                            color: const Color(0xFF054582),
                                            width: 4),
                                        left: BorderSide(
                                            color: const Color(0xFF054582),
                                            width: 4),
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                            color: const Color(0xFF054582),
                                            width: 4),
                                        right: BorderSide(
                                            color: const Color(0xFF054582),
                                            width: 4),
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -2,
                                  left: -2,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                            color: const Color(0xFF054582),
                                            width: 4),
                                        left: BorderSide(
                                            color: const Color(0xFF054582),
                                            width: 4),
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -2,
                                  right: -2,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                            color: const Color(0xFF054582),
                                            width: 4),
                                        right: BorderSide(
                                            color: const Color(0xFF054582),
                                            width: 4),
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        bottomRight: Radius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Анимация сканирования
                        if (_isScanning)
                          Positioned(
                            left: 0,
                            right: 0,
                            child: TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 1500),
                              builder: (context, value, child) {
                                return Positioned(
                                  top: (220 * value) +
                                      (MediaQuery.of(context).size.height *
                                          0.15),
                                  left: (MediaQuery.of(context).size.width -
                                          220) /
                                      2,
                                  child: Container(
                                    width: 220,
                                    height: 2,
                                    color: const Color(0xFF054582),
                                  ),
                                );
                              },
                            ),
                          ),

                        // Текст поверх
                        const Center(
                          child: Text(
                            'Наведите камеру на QR-код',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4)
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: const Duration(milliseconds: 600))
                      .scale(begin: const Offset(0.95, 0.95)),

                  const SizedBox(height: 20),

                  // Кнопка сканирования
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _isScanning ? null : _startScanner,
                        icon: Icon(_isScanning
                            ? Icons.hourglass_empty
                            : Icons.qr_code_scanner),
                        label: Text(_isScanning
                            ? 'Сканирование...'
                            : 'Начать сканирование'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF054582),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: const Duration(milliseconds: 100))
                      .slideY(begin: 0.2),

                  const SizedBox(height: 16),

                  // Кнопка выбора из галереи
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _selectFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Выбрать фото из галереи'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF054582)),
                          foregroundColor: const Color(0xFF054582),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: const Duration(milliseconds: 200))
                      .slideY(begin: 0.2),

                  const SizedBox(height: 24),

                  // Разделитель
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: theme.brightness == Brightness.dark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('или',
                            style: TextStyle(
                                color: theme.brightness == Brightness.dark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade600)),
                      ),
                      Expanded(
                          child: Divider(
                              color: theme.brightness == Brightness.dark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Ручной ввод
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.brightness == Brightness.dark
                              ? Colors.black.withOpacity(0.3)
                              : const Color(0xFF054582).withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ввести код вручную',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.brightness == Brightness.dark
                                  ? Colors.white
                                  : const Color(0xFF1F2937)),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _manualCodeController,
                          style: TextStyle(
                              color: theme.brightness == Brightness.dark
                                  ? Colors.white
                                  : const Color(0xFF1F2937)),
                          decoration: InputDecoration(
                            hintText: 'Введите уникальный код ШУ...',
                            hintStyle:
                                const TextStyle(color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: theme.brightness == Brightness.dark
                                ? const Color(0xFF151F2E)
                                : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                        if (_error.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 16, color: Color(0xFF991B1B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error,
                                    style: const TextStyle(
                                        fontSize: 12, color: Color(0xFF991B1B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _handleManualSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF054582),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: const Text('Добавить ШУ'),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: const Duration(milliseconds: 300))
                      .slideY(begin: 0.2),

                  const SizedBox(height: 24),

                  // Помощь
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Text(
                          'QR-код находится на корпусе ШУ',
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.brightness == Brightness.dark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade500),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, '/photo-upload'),
                          child: const Text(
                            'Нет QR-кода? Отправьте фото наклейки →',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF0a7ac2)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
