// lib/models/chat_message.dart
import 'package:intl/intl.dart';

class ChatAttachment {
  final String? fileUrl;
  final String? localPath;
  final String fileName;
  final int? fileSizeBytes;
  final String? mimeType;
  final String? attachmentType;
  final double? latitude;
  final double? longitude;

  ChatAttachment({
    this.fileUrl,
    this.localPath,
    required this.fileName,
    this.fileSizeBytes,
    this.mimeType,
    this.attachmentType,
    this.latitude,
    this.longitude,
  });

  bool get isLocation =>
      attachmentType == 'location' || (latitude != null && longitude != null);

  ChatAttachment copyWith({
    String? fileUrl,
    String? localPath,
    String? fileName,
    int? fileSizeBytes,
    String? mimeType,
    String? attachmentType,
    double? latitude,
    double? longitude,
  }) {
    return ChatAttachment(
      fileUrl: fileUrl ?? this.fileUrl,
      localPath: localPath ?? this.localPath,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      mimeType: mimeType ?? this.mimeType,
      attachmentType: attachmentType ?? this.attachmentType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    final rawSize = json['file_size_bytes'];
    final parsedSize = rawSize is num 
        ? rawSize.toInt() 
        : (int.tryParse(rawSize?.toString() ?? ''));

    final rawLat = json['latitude'];
    final parsedLat = rawLat is num
        ? rawLat.toDouble()
        : double.tryParse(rawLat?.toString() ?? '');

    final rawLon = json['longitude'];
    final parsedLon = rawLon is num
        ? rawLon.toDouble()
        : double.tryParse(rawLon?.toString() ?? '');

    final attType = json['attachment_type']?.toString();
    final fileName = json['file_name']?.toString() ??
        (attType == 'location' || (parsedLat != null && parsedLon != null)
            ? 'Геопозиция'
            : 'file');

    return ChatAttachment(
      fileUrl: json['file_url']?.toString(),
      fileName: fileName,
      fileSizeBytes: parsedSize,
      mimeType: json['mime_type']?.toString(),
      attachmentType: attType,
      latitude: parsedLat,
      longitude: parsedLon,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (fileUrl != null) 'file_url': fileUrl,
      'file_name': fileName,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (mimeType != null) 'mime_type': mimeType,
      if (attachmentType != null) 'attachment_type': attachmentType,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }
}

class ChatMessage {
  final String id;
  final String text;
  final bool isOwn;
  final String time;
  final bool isEdited;
  final ChatMessage? replyTo;
  final String? replyToId;
  final String? voiceUrl;
  final String? voicePath; // For local temporary recording
  final List<ChatAttachment> attachments;
  final Map<String, int> reactions;
  final int? senderId;
  final String? transcription;
  final bool isPending;
  final bool isRead;
  final bool isDeleted;

  ChatMessage({
    required this.id,
    this.text = '',
    required this.isOwn,
    required this.time,
    this.isEdited = false,
    this.replyTo,
    this.replyToId,
    this.voiceUrl,
    this.voicePath,
    this.attachments = const [],
    this.reactions = const {},
    this.senderId,
    this.transcription,
    this.isPending = false,
    this.isRead = false,
    this.isDeleted = false,
  });

  static String? _parseTranscription(dynamic transcription) {
    if (transcription == null) return null;
    if (transcription is String) return transcription;
    if (transcription is Map) {
      return (transcription['text'] ?? transcription['transcription'] ?? transcription.toString()).toString();
    }
    if (transcription is List) {
      return transcription.map((e) {
        if (e is Map) {
          return (e['text'] ?? e['transcription'] ?? e.toString()).toString();
        }
        return e.toString();
      }).join(' ');
    }
    return transcription.toString();
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, int myUserId) {
    String formattedTime = '';
    if (json['created_at'] != null) {
      try {
        String dateStr = json['created_at'].toString();
        if (!dateStr.contains('Z') && !RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(dateStr)) {
          dateStr = dateStr.replaceAll(' ', 'T');
          if (!dateStr.endsWith('Z')) {
            dateStr += 'Z';
          }
        }
        final dt = DateTime.parse(dateStr).toLocal();
        formattedTime = DateFormat('HH:mm').format(dt);
      } catch (_) {}
    }

    final replyToRaw = json['reply_to_message'];
    ChatMessage? replyToMsg;
    if (replyToRaw is Map) {
      replyToMsg = ChatMessage.fromJson(Map<String, dynamic>.from(replyToRaw), myUserId);
    }

    // Safely parse reactions supporting multiple JSON formats (Map, list of summaries, list of user reactions)
    final Map<String, int> parsedReactions = {};
    if (json['reactions'] is Map) {
      (json['reactions'] as Map).forEach((k, v) {
        final keyStr = k?.toString() ?? '';
        if (keyStr.isNotEmpty) {
          int count = 0;
          if (v is num) {
            count = v.toInt();
          } else if (v is String) {
            count = int.tryParse(v) ?? 0;
          }
          parsedReactions[keyStr] = count;
        }
      });
    } else if (json['reactions'] is List) {
      for (var item in (json['reactions'] as List)) {
        if (item is Map) {
          if (item.containsKey('emoji') && item.containsKey('count')) {
            final emoji = item['emoji']?.toString() ?? '';
            final countRaw = item['count'];
            final count = countRaw is num ? countRaw.toInt() : (int.tryParse(countRaw?.toString() ?? '') ?? 0);
            if (emoji.isNotEmpty) {
              parsedReactions[emoji] = count;
            }
          } else if (item.containsKey('emoji')) {
            final emoji = item['emoji']?.toString() ?? '';
            if (emoji.isNotEmpty) {
              parsedReactions[emoji] = (parsedReactions[emoji] ?? 0) + 1;
            }
          }
        } else if (item is String && item.isNotEmpty) {
          parsedReactions[item] = (parsedReactions[item] ?? 0) + 1;
        }
      }
    }

    // Safely parse attachments
    final List<ChatAttachment> parsedAttachments = [];
    if (json['attachments'] is List) {
      for (final e in (json['attachments'] as List)) {
        if (e is Map) {
          parsedAttachments.add(ChatAttachment.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }

    // Safely parse senderId
    final rawSenderId = json['sender_id'];
    final parsedSenderId = rawSenderId is num 
        ? rawSenderId.toInt() 
        : (int.tryParse(rawSenderId?.toString() ?? ''));

    // Check isOwn safely (compare sender_id against myUserId)
    final isOwnMsg = parsedSenderId != null && parsedSenderId == myUserId;
    final isReadMsg = json['is_read'] == true || json['is_read']?.toString() == '1' || json['is_read']?.toString().toLowerCase() == 'true';

    final isDeletedMsg = json['deleted_at'] != null;

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      isOwn: isOwnMsg,
      time: formattedTime,
      isEdited: json['is_edited'] == true || json['is_edited']?.toString() == '1' || json['is_edited']?.toString().toLowerCase() == 'true',
      voiceUrl: json['voice_url']?.toString(),
      replyTo: replyToMsg,
      replyToId: json['reply_to_message_id']?.toString(),
      attachments: parsedAttachments,
      reactions: parsedReactions,
      senderId: parsedSenderId,
      transcription: _parseTranscription(json['transcription']),
      isPending: json['is_pending'] == true || json['is_pending']?.toString() == '1' || json['is_pending']?.toString().toLowerCase() == 'true',
      isRead: isReadMsg,
      isDeleted: isDeletedMsg,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isOwn,
    String? time,
    bool? isEdited,
    ChatMessage? replyTo,
    String? replyToId,
    String? voiceUrl,
    String? voicePath,
    List<ChatAttachment>? attachments,
    Map<String, int>? reactions,
    int? senderId,
    String? transcription,
    bool? isPending,
    bool? isRead,
    bool? isDeleted,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isOwn: isOwn ?? this.isOwn,
      time: time ?? this.time,
      isEdited: isEdited ?? this.isEdited,
      replyTo: replyTo ?? this.replyTo,
      replyToId: replyToId ?? this.replyToId,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      voicePath: voicePath ?? this.voicePath,
      attachments: attachments ?? this.attachments,
      reactions: reactions ?? this.reactions,
      senderId: senderId ?? this.senderId,
      transcription: transcription ?? this.transcription,
      isPending: isPending ?? this.isPending,
      isRead: isRead ?? this.isRead,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
