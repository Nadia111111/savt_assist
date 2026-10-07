// lib/models/chat_attachment.dart
import 'chat_message.dart';

class ChatAttachmentModel {
  final ChatAttachment attachment;
  final String messageId;
  final String messageText;
  final int? senderId;
  final String createdAt;

  ChatAttachmentModel({
    required this.attachment,
    required this.messageId,
    required this.messageText,
    this.senderId,
    required this.createdAt,
  });

  factory ChatAttachmentModel.fromJson(Map<String, dynamic> json) {
    return ChatAttachmentModel(
      attachment: ChatAttachment.fromJson(json),
      messageId: (json['message_id'] ?? '0').toString(),
      messageText: json['message_text']?.toString() ?? '',
      senderId: json['sender_id'] is num ? (json['sender_id'] as num).toInt() : int.tryParse(json['sender_id']?.toString() ?? ''),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
