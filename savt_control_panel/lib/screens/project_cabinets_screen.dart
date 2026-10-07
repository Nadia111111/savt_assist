// lib/screens/project_cabinets_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/animated_card.dart';
import '../widgets/skeletons.dart';
import '../models/cabinet.dart';
import '../models/project.dart';
import '../widgets/responsive_layout.dart';
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

class _ProjectCabinetsScreenState extends State<ProjectCabinetsScreen> {
  ProjectDetails? _projectDetails;
  List<Cabinet> _userCabinets = [];
  bool _isLoading = true;
  String _error = '';
  bool _isSubmitting = false;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProjectDetails();
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

  Future<void> _loadProjectDetails() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final details = await cabinetService.getProjectDetails(widget.projectId);
      final userCabs = await cabinetService.getUserCabinets(forceRefresh: true);

    if (mounted) {
      setState(() {
        _projectDetails = details;
        _userCabinets = userCabs;
        _isLoading = false;
      });
      debugPrint('📊 [ProjectCabinets] projectCabinets=${details.cabinets.length}, userCabinets=${userCabs.length}');
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
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
        enrichedCabinets.add(
          userCab ??
              Cabinet(
                cabinetId: pcab.id,
                type: pcab.type,
                objectNumber: pcab.objectNumber,
                customName: pcab.adminInternalName ?? '',
                unreadCount: 0,
                warrantyStatus: 'unknown',
                isPinned: pcab.isPinned,
              ),
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
    debugPrint(
        '📊 [ProjectCabinets] projectCabinets=${_projectDetails?.cabinets.length ?? 0} enriched=${enrichedCabinets.length} userCabinets=${_userCabinets.length}');

    return GradientScaffold(
      appBarTitle: widget.projectName,
      body: ResponsiveContainer(
        maxWidth: 600,
        child: _isLoading
            ? const SkeletonList()
            : RefreshIndicator(
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
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(AppSpacing.base),
                            itemCount: enrichedCabinets.length,
                            itemBuilder: (context, index) {
                              final cabinet = enrichedCabinets[index];
                              return _buildCabinetCard(cabinet, index);
                            },
                          ),
              ),
      ),
      floatingActionButton: _isSubmitting
          ? null
          : FloatingActionButton.extended(
              heroTag: 'scanner_to_add_shu',
              onPressed: _addCabinetByPhoto,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.camera_alt, size: 20),
              label: const Text('Добавить ШУ', style: TextStyle(fontWeight: FontWeight.w600)),
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
      onTap: () {
        Navigator.pushNamed(context, '/shu-detail/${cabinet.cabinetId}');
      },
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
              child: Transform.rotate(
                angle: 0.4,
                child: Icon(
                  Icons.push_pin,
                  size: 18,
                  color: theme.colorScheme.primary,
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
