import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_spacing.dart';
import '../services/service_request_service.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/animated_card.dart';
import '../widgets/skeletons.dart';
import '../widgets/responsive_layout.dart';
import '../main.dart';

class ServiceRequestDetailScreen extends StatefulWidget {
  final String requestId;
  const ServiceRequestDetailScreen({super.key, required this.requestId});

  @override
  State<ServiceRequestDetailScreen> createState() => _ServiceRequestDetailScreenState();
}

class _ServiceRequestDetailScreenState extends State<ServiceRequestDetailScreen> {
  final ServiceRequestService _service = ServiceRequestService(apiClient);

  Map<String, dynamic>? _detail;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _sendingComment = false;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _loadCommentsSilent();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final reqId = int.tryParse(widget.requestId) ?? 0;
      final detailData = await _service.getServiceRequestDetail(reqId);
      final commentsData = await _service.getServiceRequestComments(reqId);
      
      setState(() {
        _detail = detailData;
        _comments = commentsData;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Ошибка загрузки деталей: $e');
    }
  }

  Future<void> _loadCommentsSilent() async {
    try {
      final reqId = int.tryParse(widget.requestId) ?? 0;
      final commentsData = await _service.getServiceRequestComments(reqId);
      final detailData = await _service.getServiceRequestDetail(reqId);
      if (mounted) {
        setState(() {
          _comments = commentsData;
          _detail = detailData;
        });
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sendingComment = true);
    try {
      final reqId = int.parse(widget.requestId);
      await _service.createServiceRequestComment(reqId, text);
      _commentController.clear();
      await _loadCommentsSilent();
      _scrollToBottom();
    } catch (e) {
      _showError('Ошибка отправки: $e');
    } finally {
      setState(() => _sendingComment = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _statusText(String status) {
    switch (status) {
      case 'open':
        return 'Открыта';
      case 'in_progress':
        return 'В работе';
      case 'closed':
        return 'Закрыта';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'in_progress':
        return const Color(0xFF054582);
      case 'closed':
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  String _requestTypeText(String type) {
    switch (type) {
      case 'repair':
        return 'Ремонт';
      case 'diagnostics':
        return 'Диагностика';
      case 'remote_adjustment':
        return 'Наладка удалённо';
      case 'onsite_adjustment':
        return 'Наладка с выездом';
      case 'maintenance':
        return 'Техническое обслуживание';
      case 'inspection':
        return 'Осмотр / Диагностика';
      default:
        return 'Другое';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GradientScaffold(
      appBarTitle: 'Детали заявки',
      appBarLeading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      body: ResponsiveContainer(
        maxWidth: 600,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.base),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: _isLoading
                    ? const SkeletonDetail()
                    : _buildContent(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_detail == null) {
      return const Center(child: Text('Данные отсутствуют'));
    }

    final status = _detail!['status'] as String;
    final statusColor = _statusColor(status);

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatusHeader(status, statusColor),
              const SizedBox(height: 16),
              _buildInfoSection(theme),
              const SizedBox(height: 20),
              _buildTimelineSection(theme),
              const SizedBox(height: 20),
              _buildCommentsHeader(theme),
              const SizedBox(height: 8),
              _buildCommentsList(theme),
            ],
          ),
        ),
        _buildInputArea(theme),
      ],
    );
  }

  Widget _buildStatusHeader(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Статус выполнения', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(
                _statusText(status).toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(ThemeData theme) {
    final chatId = _detail!['chat_id'];
    return AnimatedCard(
      index: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Информация о заявке', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _buildInfoRow('Тип заявки', _requestTypeText(_detail!['request_type'] ?? '')),
          _buildInfoRow('Шкаф управления', _detail!['cabinet_object_number'] ?? 'Н/Д'),
          _buildInfoRow('Описание проблемы', _detail!['description'] ?? '', isMultiline: true),
          _buildInfoRow('Дата подачи', _formatDateTime(_detail!['created_at'])),
          if (chatId != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/chat/$chatId');
                },
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Перейти в чат заявки'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(ThemeData theme) {
    final status = _detail!['status'] as String;
    
    // Construct statuses list for the timeline
    final steps = [
      {'title': 'Заявка зарегистрирована', 'done': true, 'time': _detail!['created_at']},
      {
        'title': 'Принято в работу', 
        'done': status == 'in_progress' || status == 'closed', 
        'time': status == 'in_progress' || status == 'closed' ? _detail!['updated_at'] : null
      },
      {'title': 'Выполнено', 'done': status == 'closed', 'time': status == 'closed' ? _detail!['updated_at'] : null},
    ];

    return AnimatedCard(
      index: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('История обработки', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (idx) {
            final step = steps[idx];
            final done = step['done'] as bool;
            final isLast = idx == steps.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: done ? theme.colorScheme.primary : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        done ? Icons.check : Icons.radio_button_unchecked,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 36,
                        color: done ? theme.colorScheme.primary : Colors.grey.shade300,
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step['title'] as String,
                        style: TextStyle(
                          fontWeight: done ? FontWeight.bold : FontWeight.normal,
                          color: done ? theme.colorScheme.onSurface : Colors.grey,
                        ),
                      ),
                      if (step['time'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatDateTime(step['time'] as String),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCommentsHeader(ThemeData theme) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'Сообщения и комментарии',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildCommentsList(ThemeData theme) {
    if (_comments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Здесь пока нет сообщений по заявке', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      );
    }

    return Column(
      children: _comments.map((comment) {
        final isOwn = comment['user_id'] != null; // if sender has user_id, it is client (own), else operator (support)
        final senderName = isOwn ? 'Вы' : (comment['operator_name'] ?? 'Поддержка');
        
        return Align(
          alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isOwn 
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isOwn ? 16 : 4),
                bottomRight: Radius.circular(isOwn ? 4 : 16),
              ),
              border: Border.all(
                color: isOwn ? theme.colorScheme.primary.withValues(alpha: 0.2) : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      senderName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isOwn ? theme.colorScheme.primary : Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDateTime(comment['created_at']),
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment['text'] ?? '',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    final showSend = _commentController.text.trim().isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _commentController,
                  maxLines: null,
                  onChanged: (text) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Написать сообщение...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _sendingComment
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: Icon(
                      Icons.send,
                      color: showSend ? theme.colorScheme.primary : Colors.grey,
                    ),
                    onPressed: showSend ? _sendComment : null,
                  ),
          ],
        ),
      ),
    );
  }
}
