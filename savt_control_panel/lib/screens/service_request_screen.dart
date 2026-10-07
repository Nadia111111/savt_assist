// lib/screens/service_request_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/responsive_layout.dart';
import '../models/cabinet.dart';
import '../services/offline_service.dart';
import '../widgets/offline_aware_button.dart';
import '../main.dart'; // serviceRequestService, cabinetService

class ServiceRequestScreen extends StatefulWidget {
  final String? shuId;
  final String? requestType;
  const ServiceRequestScreen({super.key, this.shuId, this.requestType});

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  String _requestType = 'repair';
  bool _isLoading = false;
  Map<String, dynamic>? _cabinetDetail;

  int? _selectedCabinetId;
  String? _selectedCabinetNumber;
  String? _selectedCabinetName;
  List<Cabinet> _userCabinets = [];
  bool _isLoadingCabinets = false;

  // Типы заявок
  final List<Map<String, dynamic>> _requestTypes = [
    {'value': 'repair', 'label': 'Ремонт', 'icon': Icons.build_outlined},
    {'value': 'diagnostics', 'label': 'Диагностика', 'icon': Icons.analytics_outlined},
    {'value': 'remote_adjustment', 'label': 'Наладка удалённо', 'icon': Icons.settings_remote_outlined},
    {'value': 'onsite_adjustment', 'label': 'Наладка с выездом', 'icon': Icons.commute_outlined},
    {'value': 'other', 'label': 'Другое', 'icon': Icons.more_horiz},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.shuId != null) {
      _selectedCabinetId = int.tryParse(widget.shuId!);
    }
    _loadUserCabinets();
    if (_selectedCabinetId != null) {
      _loadCabinetInfo(_selectedCabinetId!);
    }
  }

  Future<void> _loadUserCabinets() async {
    setState(() => _isLoadingCabinets = true);
    try {
      final cabs = await cabinetService.getUserCabinets();
      if (mounted) {
        setState(() {
          _userCabinets = cabs;
          _isLoadingCabinets = false;
          if (_selectedCabinetId != null) {
            final match = cabs.where((c) => c.cabinetId == _selectedCabinetId).toList();
            if (match.isNotEmpty) {
              _selectedCabinetNumber = match.first.objectNumber;
              _selectedCabinetName = match.first.customName.isNotEmpty
                  ? match.first.customName
                  : match.first.type;
            }
          } else if (cabs.isNotEmpty) {
            _selectedCabinetId = cabs.first.cabinetId;
            _selectedCabinetNumber = cabs.first.objectNumber;
            _selectedCabinetName = cabs.first.customName.isNotEmpty
                ? cabs.first.customName
                : cabs.first.type;
            _loadCabinetInfo(_selectedCabinetId!);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCabinets = false);
      }
    }
  }

  Future<void> _loadCabinetInfo(int cabinetId) async {
    try {
      final detail = await cabinetService.getCabinetDetail(cabinetId);
      if (mounted) {
        setState(() {
          _cabinetDetail = detail;
          _selectedCabinetName = (detail['custom_name'] != null && detail['custom_name'].toString().isNotEmpty)
              ? detail['custom_name']
              : detail['type'];
          _selectedCabinetNumber = detail['object_number']?.toString();

          if (widget.requestType == 'non_warranty') {
            _requestType = 'diagnostics';
          } else if (widget.requestType == 'warranty') {
            _requestType = 'repair';
          } else {
            _requestType =
                detail['warranty_status'] == 'active' ? 'repair' : 'diagnostics';
          }
        });
      }
    } catch (e) {
      // игнорируем, работаем дальше
    }
  }

  Future<void> _submitRequest() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_selectedCabinetId == null) {
      _showError('Выберите шкаф управления');
      return;
    }

    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _showError('Опишите проблему перед отправкой');
      return;
    }
    if (description.length < 10) {
      _showError('Описание должно быть не менее 10 символов');
      return;
    }

    final isOnline = OfflineService().isOnline;
    if (!isOnline) {
      OfflineService().addServiceRequestToQueue(
        _selectedCabinetId!,
        _requestType,
        description,
      );
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Icon(Icons.offline_pin, color: Colors.orange, size: 48),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 8),
                Text('Сохранено оффлайн!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                  'Вы находитесь оффлайн. Ваша заявка сохранена локально и будет отправлена автоматически при подключении к интернету.',
                  textAlign: TextAlign.start,
                ),
              ],
            ),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ОК', style: TextStyle(color: Color(0xFF054582))),
                ),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context);
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final responseData = await serviceRequestService.createServiceRequest(
        cabinetId: _selectedCabinetId!,
        requestType: _requestType,
        description: description,
      );

      if (mounted) {
        final chatId = responseData['chat_id'];
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Icon(Icons.check_circle,
                color: Color(0xFF10B981), size: 48),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 8),
                Text('Заявка отправлена!',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Мы свяжемся с вами в течение 24 часов',
                    textAlign: TextAlign.center),
              ],
            ),
            actions: [
              if (chatId != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // close dialog
                    Navigator.pop(context); // close request form
                    Navigator.pushNamed(context, '/chat/$chatId');
                  },
                  child: const Text('Открыть чат заявки',
                      style: TextStyle(color: Color(0xFF054582), fontWeight: FontWeight.bold)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Хорошо',
                    style: TextStyle(color: Color(0xFF054582))),
              ),
            ],
          ),
        );
        if (mounted && chatId == null) Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
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

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  IconData _getSelectedRequestTypeIcon() {
    final type = _requestTypes.firstWhere((t) => t['value'] == _requestType,
        orElse: () => _requestTypes[0]);
    return type['icon'] as IconData;
  }

  String _getSelectedRequestTypeLabel() {
    final type = _requestTypes.firstWhere((t) => t['value'] == _requestType,
        orElse: () => _requestTypes[0]);
    return type['label'] as String;
  }

  void _showRequestTypeSelector() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Выберите тип заявки',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _requestTypes.length,
                  itemBuilder: (context, index) {
                    final type = _requestTypes[index];
                    final isSelected = type['value'] == _requestType;
                    return ListTile(
                      leading: Icon(
                        type['icon'] as IconData,
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        type['label'] as String,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _requestType = type['value'] as String;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showCabinetPicker() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Выберите шкаф управления',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            if (_userCabinets.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _isLoadingCabinets
                      ? 'Загрузка шкафов...'
                      : 'Нет доступных шкафов',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _userCabinets.length,
                  itemBuilder: (context, index) {
                    final cab = _userCabinets[index];
                    final id = cab.cabinetId;
                    final num = cab.objectNumber;
                    final name =
                        cab.customName.isNotEmpty ? cab.customName : cab.type;
                    final isSelected = _selectedCabinetId == id;

                    return ListTile(
                      leading: Icon(
                        Icons.devices_other,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        num.isNotEmpty ? 'ШУ № $num' : name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: num.isNotEmpty && name.isNotEmpty
                          ? Text(name)
                          : null,
                      trailing: isSelected
                          ? Icon(Icons.check, color: theme.colorScheme.primary)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedCabinetId = id;
                          _selectedCabinetNumber = num;
                          _selectedCabinetName = name;
                        });
                        _loadCabinetInfo(id);
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GradientScaffold(
      appBarTitle: 'Заявка на обслуживание',
      body: ResponsiveContainer(
        maxWidth: 600,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          children: [
            InkWell(
              onTap: _showCabinetPicker,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.base),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.devices_other,
                          color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Оборудование (нажмите для выбора)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                          Text(
                            _selectedCabinetName ??
                                (_isLoadingCabinets ? 'Загрузка...' : 'Выберите шкаф'),
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (_selectedCabinetNumber != null &&
                              _selectedCabinetNumber!.isNotEmpty)
                            Text(
                              'ШУ № $_selectedCabinetNumber',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (_cabinetDetail?['warranty_status'] != null)
                            Text(
                              _cabinetDetail!['warranty_status'] == 'active'
                                  ? 'На гарантии'
                                  : 'Гарантия истекла',
                              style: TextStyle(
                                color: _cabinetDetail!['warranty_status'] == 'active'
                                    ? AppColors.success
                                    : AppColors.error,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.unfold_more,
                        color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Тип заявки',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _showRequestTypeSelector,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getSelectedRequestTypeIcon(),
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _getSelectedRequestTypeLabel(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getRequestTypeDescription(),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.start,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Описание проблемы',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText:
                          'Опишите подробно проблему, с которой вы столкнулись...',
                      hintMaxLines: 3,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Чем подробнее описание, тем быстрее мы сможем помочь',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.start),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OfflineAwareButton(
                onPressed: _submitRequest,
                text: 'Отправить заявку',
                isLoading: _isLoading,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text('Что дальше?',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildStep(1, 'Специалист рассмотрит вашу заявку'),
                  const SizedBox(height: 8),
                  _buildStep(2, 'Мы свяжемся с вами для уточнения деталей',
                      textAlign: TextAlign.start),
                  const SizedBox(height: 8),
                  _buildStep(3, 'Согласуем дату и время визита мастера',
                      textAlign: TextAlign.start),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _getRequestTypeDescription() {
    switch (_requestType) {
      case 'repair':
        return 'Заявка на ремонт оборудования. Будет рассмотрена в приоритетном порядке.';
      case 'diagnostics':
        return 'Заявка на диагностику оборудования. Выявление неисправностей.';
      case 'remote_adjustment':
        return 'Заявка на пусконаладку или настройку оборудования в удаленном режиме.';
      case 'onsite_adjustment':
        return 'Заявка на пусконаладку или настройку оборудования с выездом специалиста на объект.';
      case 'other':
        return 'Другой тип заявки. Опишите детали в описании.';
      default:
        return '';
    }
  }

  Widget _buildStep(int number, String text, {TextAlign? textAlign}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
              color: theme.colorScheme.primary, shape: BoxShape.circle),
          child: Center(
              child: Text('$number',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                textAlign: textAlign ?? TextAlign.start)),
      ],
    );
  }
}
