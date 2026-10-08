// lib/screens/qr_scanner_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/responsive_layout.dart';
import '../main.dart';

enum ScannerTarget { project, cabinet }

class QRScannerScreen extends StatefulWidget {
  final ScannerTarget initialTarget;
  final String? initialCode;

  const QRScannerScreen({
    super.key,
    this.initialTarget = ScannerTarget.project,
    this.initialCode,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController scannerController = MobileScannerController();
  final TextEditingController _manualCodeController = TextEditingController();
  late ScannerTarget _target;

  String _error = '';
  bool _isProcessing = false;
  bool _hasCameraPermission = false;
  String? _lastProcessedCode;
  DateTime? _lastProcessedAt;

  @override
  void initState() {
    super.initState();
    _target = widget.initialTarget;
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _manualCodeController.text = widget.initialCode!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processQrCode(widget.initialCode!);
      });
    }
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    // В вебе permission_handler не поддерживается и всегда возвращает denied.
    // Браузер сам запрашивает доступ к камере через getUserMedia при запуске стрима.
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _hasCameraPermission = true;
        });
      }
      return;
    }

    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (mounted) {
        setState(() {
          _hasCameraPermission = true;
        });
      }
    } else {
      final result = await Permission.camera.request();
      if (mounted) {
        setState(() {
          _hasCameraPermission = result.isGranted;
        });
      }
    }
  }

  @override
  void dispose() {
    scannerController.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }

  void _onQRDetected(BarcodeCapture capture) {
    if (_isProcessing) return;
    final String? code = capture.barcodes.first.rawValue;
    if (code != null && code.isNotEmpty) {
      if (_lastProcessedCode == code &&
          _lastProcessedAt != null &&
          DateTime.now().difference(_lastProcessedAt!) <
              const Duration(seconds: 5)) {
        return;
      }
      HapticFeedback.vibrate();
      _isProcessing = true;
      _lastProcessedCode = code;
      _lastProcessedAt = DateTime.now();
      _processQrCode(code);
    }
  }

  Future<void> _processQrCode(String qrData) async {

    // Автоопределение цели по URL/строке
    final lower = qrData.toLowerCase();
    ScannerTarget effectiveTarget = _target;
    if (lower.contains('/add/cabinet/') ||
        lower.contains('/cabinet/') ||
        lower.startsWith('savt://cabinet')) {
      effectiveTarget = ScannerTarget.cabinet;
    } else if (lower.contains('/add/project/') ||
        lower.contains('/project/') ||
        lower.startsWith('savt://project')) {
      effectiveTarget = ScannerTarget.project;
    }

    if (mounted && effectiveTarget != _target) {
      setState(() {
        _target = effectiveTarget;
      });
    }

    setState(() => _isProcessing = true);

    try {
      if (effectiveTarget == ScannerTarget.project) {
        // Добавление проекта
        final result = await cabinetService.addProjectByQr(qrData);
        final isLinked = result['status'] == 'linked';

        if (isLinked) {
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Icon(Icons.check_circle,
                    color: Colors.green, size: 48),
                content: const Text(
                    'Проект успешно добавлен! Мы также обновили список ваших шкафов.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context, true);
                    },
                    child: const Text('ОК'),
                  ),
                ],
              ),
            );
          }
        } else if (result['status'] == 'already_linked' ||
            result['status'] == 'conflict') {
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Icon(Icons.info_outline,
                    color: Colors.orange, size: 48),
                content: Text(result['message'] ??
                    'Этот проект уже привязан к вашему аккаунту.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Text('ОК'),
                  ),
                ],
              ),
            );
          }
        } else if (result['status'] == 'not_found') {
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Icon(Icons.error_outline,
                    color: Colors.red, size: 48),
                content: Text(
                    result['message'] ?? 'Проект с таким кодом не найден.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Text('ОК'),
                  ),
                ],
              ),
            );
          }
        } else {
          _showError(result['message'] ?? 'Неизвестная ошибка');
        }
      } else {
        // Добавление ШУ отдельно (POST /cabinets/add-by-qr)
        final result = await cabinetService.addCabinetByQr(qrData);
        final isLinked = result['status'] == 'linked' ||
            result['status'] == 'success' ||
            result['status'] == 'ok' ||
            result['cabinet'] != null ||
            result['cabinet_id'] != null;

        if (isLinked) {
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Icon(Icons.check_circle,
                    color: Colors.green, size: 48),
                content: const Text(
                    'Шкаф управления успешно добавлен в ваш список!'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context, true);
                    },
                    child: const Text('ОК'),
                  ),
                ],
              ),
            );
          }
        } else if (result['status'] == 'already_linked' ||
            result['status'] == 'conflict') {
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Icon(Icons.info_outline,
                    color: Colors.orange, size: 48),
                content: Text(result['message'] ??
                    'Этот шкаф управления уже добавлен в ваш список (напрямую или через проект).'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context, true);
                    },
                    child: const Text('ОК'),
                  ),
                ],
              ),
            );
          }
        } else if (result['status'] == 'not_found') {
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Icon(Icons.error_outline,
                    color: Colors.red, size: 48),
                content: Text(result['message'] ??
                    'Шкаф управления с таким кодом не найден.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Text('ОК'),
                  ),
                ],
              ),
            );
          }
        } else {
          _showError(result['message'] ?? 'Неизвестная ошибка');
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickImageAndScan() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isProcessing = true);
      final found = await scannerController.analyzeImage(image.path);
      if (!found) {
        _showError('QR-код на выбранном изображении не найден');
      }
    } catch (e) {
      _showError('Не удалось обработать изображение: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _handleManualSubmit() async {
    final code = _manualCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = _target == ScannerTarget.project
          ? 'Введите код проекта'
          : 'Введите код шкафа управления');
      return;
    }
    setState(() => _error = '');
    await _processQrCode(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const cutoutSize = 280.0;
    final isProject = _target == ScannerTarget.project;

    return GradientScaffold(
      appBarTitle: isProject ? 'Добавить проект' : 'Добавить шкаф (ШУ)',
      appBarAction: IconButton(
        icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
        tooltip: 'Выбрать фото из галереи',
        onPressed: _isProcessing ? null : _pickImageAndScan,
      ),
      body: ResponsiveContainer(
        maxWidth: 600,
        child: Column(
        children: [
          // Переключатель режимов: Проект / ШУ
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _target = ScannerTarget.project;
                        _error = '';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isProject
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Проект',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isProject
                              ? Colors.white
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _target = ScannerTarget.cabinet;
                        _error = '';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !isProject
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Шкаф управления',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !isProject
                              ? Colors.white
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Поле видоискателя камеры
          Expanded(
            child: Stack(
              children: [
                if (_hasCameraPermission)
                  MobileScanner(
                    controller: scannerController,
                    onDetect: _onQRDetected,
                    errorBuilder: (context, error, child) {
                      return Container(
                        color: Colors.black87,
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.videocam_off_outlined,
                                  color: Colors.orangeAccent, size: 56),
                              const SizedBox(height: 16),
                              const Text(
                                'Камера недоступна',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                kIsWeb
                                    ? 'Браузер заблокировал доступ к камере или соединение не по HTTPS. Разрешите камеру в настройках браузера или выберите фото с QR-кодом.'
                                    : 'Не удалось запустить камеру: ${error.errorCode.name}',
                                style: const TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: _pickImageAndScan,
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Загрузить фото из галереи'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                else
                  Container(
                    color: Colors.black87,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.camera_alt,
                                color: Colors.white70, size: 64),
                            const SizedBox(height: 16),
                            const Text(
                              'Требуется доступ к камере',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Пожалуйста, разрешите доступ к камере для сканирования QR-кода.',
                              style: TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            if (!kIsWeb)
                              ElevatedButton.icon(
                                onPressed: openAppSettings,
                                icon: const Icon(Icons.settings),
                                label: const Text('Открыть настройки'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const Positioned.fill(
                  child: CustomPaint(
                    painter: ScannerOverlayPainter(cutoutSize: cutoutSize),
                  ),
                ),
                Center(
                  child: Container(
                    width: cutoutSize,
                    height: cutoutSize,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF0a7ac2),
                        width: 3.5,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          // Нижняя панель для ручного ввода
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Или введите код вручную',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _manualCodeController,
                    decoration: InputDecoration(
                      hintText: isProject
                          ? 'Введите код проекта'
                          : 'Введите код шкафа управления',
                      prefixIcon:
                          const Icon(Icons.qr_code, color: Color(0xFF0a7ac2)),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handleManualSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0a7ac2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isProject
                              ? 'Добавить проект по коду'
                              : 'Добавить ШУ по коду',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final double cutoutSize;
  const ScannerOverlayPainter({this.cutoutSize = 280.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final outerPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final left = (size.width - cutoutSize) / 2;
    final top = (size.height - cutoutSize) / 2;
    final innerPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, cutoutSize, cutoutSize),
          const Radius.circular(24),
        ),
      );

    final path = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) =>
      oldDelegate.cutoutSize != cutoutSize;
}
