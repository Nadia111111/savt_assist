// lib/screens/create_reclamation_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_spacing.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/offline_aware_button.dart';
import '../main.dart'; // authService, uploadService, reclamationsService

class CreateReclamationScreen extends StatefulWidget {
  final int? initialCabinetId;
  final String? initialCabinetNumber;
  final int? initialProjectId;
  final String? initialProjectName;

  const CreateReclamationScreen({
    super.key,
    this.initialCabinetId,
    this.initialCabinetNumber,
    this.initialProjectId,
    this.initialProjectName,
  });

  @override
  State<CreateReclamationScreen> createState() =>
      _CreateReclamationScreenState();
}

class _AttachmentItem {
  final String localPath;
  final String fileName;
  final int fileSizeBytes;
  final String mimeType;
  String? fileUrl;
  bool isUploading;
  String? error;

  _AttachmentItem({
    required this.localPath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.mimeType,
    this.isUploading = false,
  });
}

class _CreateReclamationScreenState extends State<CreateReclamationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Object Type
  String _objectType = 'cabinet';

  // Object details controllers
  final TextEditingController _serialNumberController = TextEditingController();
  final TextEditingController _componentNameController =
      TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _articleController = TextEditingController();
  final TextEditingController _componentSerialController =
      TextEditingController();
  final TextEditingController _softwareNameController = TextEditingController();
  final TextEditingController _softwareVersionController =
      TextEditingController();
  final TextEditingController _softwareDescController = TextEditingController();
  final TextEditingController _docNameController = TextEditingController();
  final TextEditingController _docCodeController = TextEditingController();
  final TextEditingController _docSectionController = TextEditingController();

  // General reclamation fields
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _occurrenceConditionsController =
      TextEditingController();
  final TextEditingController _errorCodesController = TextEditingController();

  // Document requisites
  final TextEditingController _contractNumberController =
      TextEditingController();
  final TextEditingController _orderNumberController = TextEditingController();
  final TextEditingController _ttnNumberController = TextEditingController();

  // Contacts
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _contactEmailController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();

  bool _isSubmitting = false;

  final List<_AttachmentItem> _attachments = [];
  final ImagePicker _imagePicker = ImagePicker();

  final List<Map<String, dynamic>> _objectTypeOptions = [
    {'value': 'cabinet', 'label': 'ШУ', 'icon': Icons.devices_other},
    {'value': 'line', 'label': 'Автоматическая линия', 'icon': Icons.precision_manufacturing},
    {'value': 'component', 'label': 'ПКИ', 'icon': Icons.memory},
    {'value': 'software', 'label': 'ПО', 'icon': Icons.code},
    {'value': 'documentation', 'label': 'Документация', 'icon': Icons.description},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCabinetNumber != null &&
        widget.initialCabinetNumber!.isNotEmpty) {
      _serialNumberController.text = widget.initialCabinetNumber!;
    }
    _loadUserProfile();
  }

  @override
  void dispose() {
    _serialNumberController.dispose();
    _componentNameController.dispose();
    _modelController.dispose();
    _articleController.dispose();
    _componentSerialController.dispose();
    _softwareNameController.dispose();
    _softwareVersionController.dispose();
    _softwareDescController.dispose();
    _docNameController.dispose();
    _docCodeController.dispose();
    _docSectionController.dispose();

    _descriptionController.dispose();
    _occurrenceConditionsController.dispose();
    _errorCodesController.dispose();

    _contractNumberController.dispose();
    _orderNumberController.dispose();
    _ttnNumberController.dispose();

    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _customerNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await authService.getMe();
      if (mounted) {
        setState(() {
          _contactNameController.text = user['full_name']?.toString() ?? '';
          _contactPhoneController.text = (user['contact_phone'] ??
                  user['phone'] ??
                  '')
              .toString();
          _contactEmailController.text = user['email']?.toString() ?? '';
          _customerNameController.text = (user['organization_name'] ??
                  user['organization'] ??
                  '')
              .toString();
        });
      }
    } catch (_) {}
  }


  String _detectMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return 'application/vnd.ms-excel';
    }
    return 'application/octet-stream';
  }

  Future<void> _pickAttachment(ImageSource source) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (file == null) return;

      final ioFile = File(file.path);
      final size = await ioFile.length();
      final name = file.name.isNotEmpty ? file.name : file.path.split(Platform.pathSeparator).last;
      final mime = _detectMimeType(file.path);

      final item = _AttachmentItem(
        localPath: file.path,
        fileName: name,
        fileSizeBytes: size,
        mimeType: mime,
        isUploading: true,
      );

      setState(() {
        _attachments.add(item);
      });

      _uploadItem(item);
    } catch (e) {
      _showError('Не удалось выбрать изображение: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'png', 'jpg', 'jpeg'],
      );

      if (result == null || result.files.isEmpty) return;

      for (final f in result.files) {
        if (f.path == null) continue;
        final name = f.name;
        final size = f.size;
        final mime = _detectMimeType(f.path!);

        final item = _AttachmentItem(
          localPath: f.path!,
          fileName: name,
          fileSizeBytes: size,
          mimeType: mime,
          isUploading: true,
        );

        setState(() {
          _attachments.add(item);
        });

        _uploadItem(item);
      }
    } catch (e) {
      _showError('Не удалось выбрать файл: $e');
    }
  }

  Future<void> _uploadItem(_AttachmentItem item) async {
    try {
      final url = await uploadService.uploadAttachment(item.localPath);
      if (mounted) {
        setState(() {
          item.fileUrl = url;
          item.isUploading = false;
          item.error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          item.isUploading = false;
          item.error = e.toString();
        });
        _showError('Ошибка загрузки файла ${item.fileName}: $e');
      }
    }
  }

  void _showAttachmentPickerOptions() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Прикрепить файл',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.camera_alt_outlined,
                      color: theme.colorScheme.primary),
                ),
                title: const Text('Сделать фото на камеру'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAttachment(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.photo_library_outlined,
                      color: theme.colorScheme.primary),
                ),
                title: const Text('Выбрать из галереи'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAttachment(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.attach_file,
                      color: theme.colorScheme.primary),
                ),
                title: const Text('Выбрать документ (PDF, DOC, XLS)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDocument();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? _buildObjectDetails() {
    switch (_objectType) {
      case 'cabinet':
      case 'line':
        final serial = _serialNumberController.text.trim();
        return {'serial_number': serial};

      case 'component':
        return {
          'name': _componentNameController.text.trim(),
          'model': _modelController.text.trim(),
          'article': _articleController.text.trim(),
          'serial_number': _componentSerialController.text.trim(),
        };

      case 'software':
        final details = <String, dynamic>{};
        if (_softwareNameController.text.trim().isNotEmpty) {
          details['name'] = _softwareNameController.text.trim();
        }
        if (_softwareVersionController.text.trim().isNotEmpty) {
          details['version'] = _softwareVersionController.text.trim();
        }
        if (_softwareDescController.text.trim().isNotEmpty) {
          details['description'] = _softwareDescController.text.trim();
        }
        return details.isNotEmpty ? details : null;

      case 'documentation':
        final details = <String, dynamic>{};
        if (_docNameController.text.trim().isNotEmpty) {
          details['document_name'] = _docNameController.text.trim();
        }
        if (_docCodeController.text.trim().isNotEmpty) {
          details['code'] = _docCodeController.text.trim();
        }
        if (_docSectionController.text.trim().isNotEmpty) {
          details['page_or_section'] = _docSectionController.text.trim();
        }
        return details.isNotEmpty ? details : null;

      default:
        return null;
    }
  }

  Future<void> _submitReclamation() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) {
      _showError('Пожалуйста, заполните обязательные поля');
      return;
    }

    // Check if any attachments are still uploading
    if (_attachments.any((a) => a.isUploading)) {
      _showError('Подождите завершения загрузки файлов');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final attachmentsPayload = _attachments
          .where((a) => a.fileUrl != null && a.fileUrl!.isNotEmpty)
          .map((a) => {
                'file_url': a.fileUrl!,
                'file_name': a.fileName,
                'file_size_bytes': a.fileSizeBytes,
                'mime_type': a.mimeType,
              })
          .toList();

      final created = await reclamationsService.createReclamation(
        objectType: _objectType,
        objectDetails: _buildObjectDetails(),
        description: _descriptionController.text.trim(),
        occurrenceConditions: _occurrenceConditionsController.text.trim(),
        errorCodes: _errorCodesController.text.trim(),
        contractNumber: _contractNumberController.text.trim(),
        orderNumber: _orderNumberController.text.trim(),
        ttnNumber: _ttnNumberController.text.trim(),
        contactName: _contactNameController.text.trim(),
        contactPhone: _contactPhoneController.text.trim(),
        contactEmail: _contactEmailController.text.trim(),
        customerName: _customerNameController.text.trim(),
        attachments:
            attachmentsPayload.isNotEmpty ? attachmentsPayload : null,
      );

      if (!mounted) return;

      final newId = created['id'];

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Icon(Icons.check_circle,
              color: Color(0xFF10B981), size: 52),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8),
              Text(
                'Рекламация подана!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Рекламация успешно отправлена и передана на рассмотрение техническим специалистам.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // close dialog
                  Navigator.pop(context, true); // return to caller
                  if (newId != null) {
                    Navigator.pushNamed(context, '/reclamation-detail/$newId');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Просмотреть заявку'),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showError(e.toString());
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBarTitle: 'Подача рекламации',
      body: ResponsiveContainer(
        maxWidth: 600,
        child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Селектор типа объекта
              _buildSectionCard(
                title: 'Тип рекламационного объекта *',
                subtitle: 'Выберите объект, по которому обнаружен дефект',
                child: _buildObjectTypeSelector(),
              ),
              const SizedBox(height: AppSpacing.base),

              // 2. Спецификация объекта
              _buildSectionCard(
                title: 'Сведения об объекте *',
                subtitle: _getObjectSubtitle(),
                child: _buildObjectDetailsFields(),
              ),
              const SizedBox(height: AppSpacing.base),

              // 3. Описание дефекта
              _buildSectionCard(
                title: 'Описание проблемы *',
                subtitle: 'Подробно опишите выявленное несоответствие или отказ',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Обязательное поле: опишите проблему';
                        }
                        if (v.trim().length < 10) {
                          return 'Описание должно быть не менее 10 символов';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        hintText:
                            'Опишите дефект, поведение оборудования, при каких действиях возникает...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _occurrenceConditionsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Условия проявления (опционально)',
                        hintText:
                            'Например: Проявляется при включении после простоя больше суток',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _errorCodesController,
                      decoration: const InputDecoration(
                        labelText: 'Коды ошибок / индикация (опционально)',
                        hintText: 'Например: E-12, авария ПЧ F0002',
                        prefixIcon: Icon(Icons.error_outline),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.base),

              // 4. Реквизиты документов
              _buildSectionCard(
                title: 'Реквизиты документов',
                subtitle:
                    'Укажите номера документов поставки для ускорения идентификации',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _contractNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Номер договора',
                        hintText: 'Например: Д-45/2026',
                        prefixIcon: Icon(Icons.history_edu),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _orderNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Номер заказа / счёта',
                        hintText: 'Например: З-102',
                        prefixIcon: Icon(Icons.receipt_long),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ttnNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Номер ТТН / CMR',
                        hintText: 'Например: ТТН-778 или CMR-0091',
                        prefixIcon: Icon(Icons.local_shipping_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.base),

              // 5. Контактные данные
              _buildSectionCard(
                title: 'Контактные данные заявителя *',
                subtitle:
                    'Данные предзаполнены из профиля, но их можно изменить для этой заявки',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _contactNameController,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Укажите контактное лицо'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Контактное лицо (ФИО) *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactPhoneController,
                      keyboardType: TextInputType.phone,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Укажите контактный телефон'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Номер телефона *',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactEmailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Укажите email';
                        }
                        if (!v.contains('@') || !v.contains('.')) {
                          return 'Введите корректный email';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Организация / Заказчик (если подаёте от третьего лица)',
                        hintText: 'Например: ООО Ромашка',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.base),

              // 6. Вложения
              _buildSectionCard(
                title: 'Фотографии и документы',
                subtitle:
                    'Прикрепите фото шильдика, фото/видео проявления дефекта или сканы актов',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showAttachmentPickerOptions,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Прикрепить файл или фото'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (_attachments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ..._attachments.map((item) => _buildAttachmentTile(item)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 7. Кнопка отправки
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OfflineAwareButton(
                  onPressed: _submitReclamation,
                  text: 'Отправить рекламацию',
                  isLoading: _isSubmitting,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildObjectTypeSelector() {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _objectTypeOptions.map((opt) {
        final val = opt['value'] as String;
        final label = opt['label'] as String;
        final icon = opt['icon'] as IconData;
        final isSelected = _objectType == val;

        return ChoiceChip(
          avatar: Icon(
            icon,
            size: 16,
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.primary,
          ),
          label: Text(label),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() => _objectType = val);
            }
          },
          selectedColor: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.surfaceContainerLow,
          labelStyle: TextStyle(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.4),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getObjectSubtitle() {
    switch (_objectType) {
      case 'cabinet':
        return 'Укажите заводской номер шкафа управления';
      case 'line':
        return 'Укажите заводской номер автоматической линии';
      case 'component':
        return 'Укажите наименование, модель, артикул и серийный номер комплектующего';
      case 'software':
        return 'Укажите сведения о программном обеспечении (опционально)';
      case 'documentation':
        return 'Укажите сведения о документации (опционально)';
      default:
        return '';
    }
  }

  Widget _buildObjectDetailsFields() {
    if (_objectType == 'cabinet' || _objectType == 'line') {
      final label = _objectType == 'cabinet'
          ? 'Заводской номер ШУ *'
          : 'Заводской номер линии *';
      final hint = _objectType == 'cabinet'
          ? 'Например: 240105 или ШУ-012'
          : 'Например: AL-2026-014';
      return TextFormField(
        controller: _serialNumberController,
        validator: (v) => v == null || v.trim().isEmpty
            ? 'Укажите заводской номер'
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: const Icon(Icons.tag),
        ),
      );
    }

    if (_objectType == 'component') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _componentNameController,
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Укажите наименование детали'
                : null,
            decoration: const InputDecoration(
              labelText: 'Наименование ПКИ *',
              hintText: 'Например: Контактор, датчик давления',
              prefixIcon: Icon(Icons.memory),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _modelController,
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Укажите модель детали'
                : null,
            decoration: const InputDecoration(
              labelText: 'Модель *',
              hintText: 'Например: LC1D18',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _articleController,
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Укажите артикул детали'
                : null,
            decoration: const InputDecoration(
              labelText: 'Артикул *',
              hintText: 'Например: LC1D18M7',
              prefixIcon: Icon(Icons.qr_code),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _componentSerialController,
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Укажите серийный номер детали'
                : null,
            decoration: const InputDecoration(
              labelText: 'Серийный номер ПКИ *',
              hintText: 'Например: SN-4521',
              prefixIcon: Icon(Icons.numbers),
            ),
          ),
        ],
      );
    }

    if (_objectType == 'software') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _softwareNameController,
            decoration: const InputDecoration(
              labelText: 'Наименование ПО / Модуля (опционально)',
              hintText: 'Например: Прошивка контроллера PLC-10',
              prefixIcon: Icon(Icons.code),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _softwareVersionController,
            decoration: const InputDecoration(
              labelText: 'Версия ПО (опционально)',
              hintText: 'Например: v2.4.1-b12',
              prefixIcon: Icon(Icons.verified_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _softwareDescController,
            decoration: const InputDecoration(
              labelText: 'Окружение / Описание (опционально)',
              hintText: 'Например: Панель Weintek MT8071iE',
              prefixIcon: Icon(Icons.info_outline),
            ),
          ),
        ],
      );
    }

    if (_objectType == 'documentation') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _docNameController,
            decoration: const InputDecoration(
              labelText: 'Название документа (опционально)',
              hintText: 'Например: Руководство по эксплуатации, Эл. схема',
              prefixIcon: Icon(Icons.menu_book),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _docCodeController,
            decoration: const InputDecoration(
              labelText: 'Шифр / Обозначение документа (опционально)',
              hintText: 'Например: Э3.04.112-РЭ',
              prefixIcon: Icon(Icons.pin),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _docSectionController,
            decoration: const InputDecoration(
              labelText: 'Лист / Страница / Раздел (опционально)',
              hintText: 'Например: Стр. 14, Раздел 3.2',
              prefixIcon: Icon(Icons.find_in_page_outlined),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildAttachmentTile(_AttachmentItem item) {
    final theme = Theme.of(context);
    final isImage = item.mimeType.startsWith('image/');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.error != null
              ? AppColors.error
              : theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: isImage
                  ? Image.file(
                      File(item.localPath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.insert_drive_file,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : Icon(
                      item.mimeType.contains('pdf')
                          ? Icons.picture_as_pdf
                          : Icons.insert_drive_file,
                      color: theme.colorScheme.primary,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  item.isUploading
                      ? 'Загрузка на сервер...'
                      : (item.error != null
                          ? 'Ошибка загрузки'
                          : '${(item.fileSizeBytes / 1024).toStringAsFixed(1)} КБ • Загружено'),
                  style: TextStyle(
                    fontSize: 11,
                    color: item.error != null
                        ? AppColors.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (item.isUploading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              color: theme.colorScheme.error,
              onPressed: () {
                setState(() {
                  _attachments.remove(item);
                });
              },
            ),
        ],
      ),
    );
  }
}
