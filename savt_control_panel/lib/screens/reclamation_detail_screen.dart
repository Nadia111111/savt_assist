import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import '../theme/app_spacing.dart';
import '../widgets/gradient_scaffold.dart';
import '../models/reclamations.dart';
import '../widgets/skeletons.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/auth_image.dart';
import '../services/file_save_helper.dart';
import '../utils/download_helper.dart';
import 'fullscreen_image_viewer.dart';
import '../main.dart'; // reclamationsService, uploadService

class ReclamationDetailScreen extends StatefulWidget {
  final int reclamationId;

  const ReclamationDetailScreen({
    super.key,
    required this.reclamationId,
  });

  @override
  State<ReclamationDetailScreen> createState() =>
      _ReclamationDetailScreenState();
}

class _ReclamationDetailScreenState extends State<ReclamationDetailScreen> {
  ReclamationsDetail? _detail;
  bool _isLoading = true;
  String? _error;
  final Set<int> _downloadingAttachmentIds = {};

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final json =
          await reclamationsService.getReclamationDetail(widget.reclamationId);
      if (mounted) {
        setState(() {
          _detail = ReclamationsDetail.fromJson(json);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Не удалось открыть звонок на номер $phoneNumber');
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Не удалось открыть почту для $email');
    }
  }

  Future<void> _openAttachment(ReclamationsAttachment attachment) async {
    if (attachment.isImage) {
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (context, animation, secondaryAnimation) => FullscreenImageViewer(
            imageUrl: attachment.fileUrl,
            fileName: attachment.fileName,
            onDownloadRequest: (url) => uploadService.downloadFile(url),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
      return;
    }

    // 1. Если файл уже скачан локально - сразу открываем без повторного скачивания
    final existingPath = await FileSaveHelper.getLocalFilePath(attachment.fileName);
    if (existingPath != null && await File(existingPath).exists()) {
      final result = await OpenFile.open(existingPath);
      if (result.type != ResultType.done && mounted) {
        _showSnackBar('Файл сохранен: $existingPath');
      }
      return;
    }

    if (!mounted) return;

    // Скачивание и открытие документа
    if (_downloadingAttachmentIds.contains(attachment.id)) return;

    setState(() {
      _downloadingAttachmentIds.add(attachment.id);
    });

    final progressController = StreamController<double>.broadcast();
    showDownloadProgressDialog(context, attachment.fileName, progressController.stream);

    try {
      final bytes = await uploadService.downloadFile(
        attachment.fileUrl,
        onProgress: (received, total) {
          if (total > 0) {
            progressController.add(received / total);
          }
        },
      );

      if (mounted) Navigator.pop(context); // закрываем диалог

      if (mounted) {
        final filePath = await FileSaveHelper.saveFile(
          context: context,
          bytes: bytes,
          fileName: attachment.fileName,
        );
        final result = await OpenFile.open(filePath);
        if (result.type != ResultType.done && mounted) {
          _showSnackBar('Файл сохранен: $filePath');
        }
      }
    } catch (e) {
      if (mounted) {
        try { Navigator.pop(context); } catch (_) {}
        _showSnackBar('Ошибка скачивания файла: $e');
      }
    } finally {
      progressController.close();
      if (mounted) {
        setState(() {
          _downloadingAttachmentIds.remove(attachment.id);
        });
      }
    }
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.$year в $hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GradientScaffold(
      appBarTitle: 'Рекламация',
      appBarAction: IconButton(
        icon: const Icon(Icons.refresh, color: Colors.white),
        tooltip: 'Обновить',
        onPressed: _loadDetail,
      ),
      body: ResponsiveContainer(
        maxWidth: 600,
        child: _isLoading
            ? const SkeletonDetail()
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: theme.colorScheme.error),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadDetail,
                            child: const Text('Попробовать снова'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadDetail,
                    color: const Color(0xFF0a7ac2),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.base),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusHeaderCard(),
                          const SizedBox(height: AppSpacing.base),
                          _buildStatusHighlightCard(),
                          _buildObjectCard(),
                          const SizedBox(height: AppSpacing.base),
                          _buildDescriptionCard(),
                          const SizedBox(height: AppSpacing.base),
                          if (_hasRequisites()) ...[
                            _buildRequisitesCard(),
                            const SizedBox(height: AppSpacing.base),
                          ],
                          _buildContactsCard(),
                          const SizedBox(height: AppSpacing.base),
                          if (_detail!.attachments.isNotEmpty) ...[
                            _buildAttachmentsCard(),
                            const SizedBox(height: AppSpacing.base),
                          ],
                          _buildDatesCard(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatusHeaderCard() {
    final theme = Theme.of(context);
    final detail = _detail!;
    final statusColor = detail.statusColor;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(detail.statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      detail.statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(detail.objectTypeIcon,
                        size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      detail.objectTypeLabel,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (detail.warrantyBadgeText != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: detail.warrantyBadgeColor!.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: detail.warrantyBadgeColor!.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    detail.warrantyClassification == true
                        ? Icons.verified
                        : (detail.warrantyClassification == false
                            ? Icons.monetization_on_outlined
                            : Icons.help_outline),
                    size: 14,
                    color: detail.warrantyBadgeColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    detail.warrantyBadgeText!,
                    style: TextStyle(
                      color: detail.warrantyBadgeColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusHighlightCard() {
    final detail = _detail!;
    final theme = Theme.of(context);

    // 1. in_progress -> ответственный и рабочий телефон
    if (detail.status == 'in_progress') {
      final hasResponsible = (detail.responsibleName != null &&
              detail.responsibleName!.isNotEmpty) ||
          (detail.responsiblePhone != null &&
              detail.responsiblePhone!.isNotEmpty);

      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.base),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: const Color(0xFF0a7ac2).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF0a7ac2).withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0a7ac2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.support_agent,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Заявка принята в работу',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0a7ac2),
                        ),
                      ),
                      if (hasResponsible)
                        Text(
                          'Назначен ответственный специалист',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasResponsible) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (detail.responsibleName != null &&
                  detail.responsibleName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        detail.responsibleName!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              if (detail.responsiblePhone != null &&
                  detail.responsiblePhone!.isNotEmpty)
                InkWell(
                  onTap: () => _makeCall(detail.responsiblePhone!),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.phone,
                            size: 16, color: Color(0xFF0a7ac2)),
                        const SizedBox(width: 8),
                        Text(
                          detail.responsiblePhone!,
                          style: const TextStyle(
                            color: Color(0xFF0a7ac2),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0a7ac2).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Позвонить',
                            style: TextStyle(
                              color: Color(0xFF0a7ac2),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    }

    // 2. rejected or invalid -> причина отклонения
    if (detail.status == 'rejected' || detail.status == 'invalid') {
      final isInvalid = detail.status == 'invalid';
      final color = isInvalid ? const Color(0xFFEA580C) : const Color(0xFFDC2626);
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.base),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isInvalid ? Icons.warning_amber_rounded : Icons.cancel_outlined,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  isInvalid ? 'Оформлена некорректно' : 'Рекламация отклонена',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              detail.rejectionReason != null &&
                      detail.rejectionReason!.isNotEmpty
                  ? detail.rejectionReason!
                  : (isInvalid
                      ? 'Заявка требует исправления или уточнения данных.'
                      : 'Причина отклонения не указана.'),
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
      );
    }

    // 3. resolved -> комментарий решения
    if (detail.status == 'resolved') {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.base),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF10B981), size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Рекламация исполнена',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
                if (detail.resolvedAt != null)
                  Text(
                    _formatDate(detail.resolvedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (detail.resolutionComment != null &&
                detail.resolutionComment!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                detail.resolutionComment!,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
            if (detail.rootCause != null && detail.rootCause!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Причина: ${detail.rootCause!}',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildObjectCard() {
    final detail = _detail!;
    final theme = Theme.of(context);

    Widget content;

    if (detail.objectType == 'cabinet') {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.cabinetObjectNumber != null &&
                          detail.cabinetObjectNumber!.isNotEmpty
                      ? 'Шкаф управления № ${detail.cabinetObjectNumber}'
                      : (detail.objectDetails != null &&
                              detail.objectDetails!['serial_number'] != null &&
                              detail.objectDetails!['serial_number']
                                  .toString()
                                  .isNotEmpty
                          ? 'Шкаф управления (зав. № ${detail.objectDetails!['serial_number']})'
                          : 'Шкаф управления'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (detail.cabinetId != null)
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                        context, '/shu-detail/${detail.cabinetId}');
                  },
                  child: const Text('Открыть ШУ'),
                ),
            ],
          ),
          if (detail.objectDetails != null &&
              detail.objectDetails!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...detail.objectDetails!.entries.map((e) {
              final label = _formatObjectDetailKey(e.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.projectName != null && detail.projectName!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.folder_outlined,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Проект: ${detail.projectName!}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),
          ],
          if (detail.objectDetails != null &&
              detail.objectDetails!.isNotEmpty)
            ...detail.objectDetails!.entries.map((e) {
              final label = _formatObjectDetailKey(e.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            })
          else
            Text(
              'Сведения об объекте отсутствуют',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      );
    }

    return _buildCard(
      title: 'Сведения об объекте (${detail.objectTypeLabel})',
      icon: detail.objectTypeIcon,
      child: content,
    );
  }

  String _formatObjectDetailKey(String key) {
    switch (key) {
      case 'serial_number':
        return 'Заводской номер:';
      case 'name':
        return 'Наименование:';
      case 'model':
        return 'Модель:';
      case 'article':
        return 'Артикул:';
      case 'version':
        return 'Версия:';
      case 'description':
        return 'Описание:';
      case 'document_name':
        return 'Название документа:';
      case 'code':
        return 'Шифр / Код:';
      case 'page_or_section':
        return 'Раздел / Страница:';
      default:
        return '$key:';
    }
  }

  Widget _buildDescriptionCard() {
    final detail = _detail!;
    final theme = Theme.of(context);

    return _buildCard(
      title: 'Описание неисправности',
      icon: Icons.report_problem_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.description,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          if (detail.occurrenceConditions != null &&
              detail.occurrenceConditions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(
              'Условия проявления:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail.occurrenceConditions!,
              style: const TextStyle(fontSize: 13),
            ),
          ],
          if (detail.errorCodes != null &&
              detail.errorCodes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(
              'Коды ошибок:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                detail.errorCodes!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasRequisites() {
    final detail = _detail!;
    return (detail.contractNumber != null &&
            detail.contractNumber!.isNotEmpty) ||
        (detail.orderNumber != null && detail.orderNumber!.isNotEmpty) ||
        (detail.ttnNumber != null && detail.ttnNumber!.isNotEmpty);
  }

  Widget _buildRequisitesCard() {
    final detail = _detail!;

    return _buildCard(
      title: 'Реквизиты документов',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          if (detail.contractNumber != null &&
              detail.contractNumber!.isNotEmpty)
            _buildInfoRow('Договор:', detail.contractNumber!),
          if (detail.orderNumber != null && detail.orderNumber!.isNotEmpty)
            _buildInfoRow('Заказ / счёт:', detail.orderNumber!),
          if (detail.ttnNumber != null && detail.ttnNumber!.isNotEmpty)
            _buildInfoRow('ТТН / накладная:', detail.ttnNumber!),
        ],
      ),
    );
  }

  Widget _buildContactsCard() {
    final detail = _detail!;

    return _buildCard(
      title: 'Контактные данные',
      icon: Icons.contact_phone_outlined,
      child: Column(
        children: [
          _buildInfoRow('Контактное лицо:', detail.contactName),
          InkWell(
            onTap: () => _makeCall(detail.contactPhone),
            child: _buildInfoRow(
              'Телефон:',
              detail.contactPhone,
              isAction: true,
              icon: Icons.phone,
            ),
          ),
          InkWell(
            onTap: () => _sendEmail(detail.contactEmail),
            child: _buildInfoRow(
              'Email:',
              detail.contactEmail,
              isAction: true,
              icon: Icons.email,
            ),
          ),
          if (detail.customerName != null && detail.customerName!.isNotEmpty)
            _buildInfoRow('Заказчик:', detail.customerName!),
        ],
      ),
    );
  }

  Widget _buildAttachmentsCard() {
    final detail = _detail!;

    return _buildCard(
      title: 'Вложения (${detail.attachments.length})',
      icon: Icons.attach_file,
      child: Column(
        children: detail.attachments.map((att) {
          final isDownloading = _downloadingAttachmentIds.contains(att.id);

          return InkWell(
            onTap: () => _openAttachment(att),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: att.isImage
                          ? AuthImage(
                              url: att.fileUrl,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1),
                              child: Icon(
                                att.fileName.toLowerCase().endsWith('.pdf')
                                    ? Icons.picture_as_pdf
                                    : Icons.insert_drive_file,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          att.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          att.fileSizeFormatted,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDownloading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      att.isImage
                          ? Icons.visibility_outlined
                          : Icons.download_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDatesCard() {
    final detail = _detail!;

    return _buildCard(
      title: 'Хронология',
      icon: Icons.calendar_today_outlined,
      child: Column(
        children: [
          _buildInfoRow('Подана:', _formatDate(detail.createdAt)),
          if (detail.resolvedAt != null)
            _buildInfoRow('Исполнена:', _formatDate(detail.resolvedAt)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isAction = false,
    IconData? icon,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isAction
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      decoration:
                          isAction ? TextDecoration.underline : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
