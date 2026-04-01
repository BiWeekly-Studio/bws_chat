import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, system }

class Message {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderProfileUrl;
  final String content;
  final MessageType type;
  final String? imageUrl;
  final String? imageThumbnailUrl;
  // userId -> readAt datetime
  final Map<String, DateTime> readBy;
  final DateTime createdAt;
  final bool isDeleted;

  const Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderProfileUrl,
    required this.content,
    this.type = MessageType.text,
    this.imageUrl,
    this.imageThumbnailUrl,
    this.readBy = const {},
    required this.createdAt,
    this.isDeleted = false,
  });

  factory Message.fromMap(Map<String, dynamic> map, {required String id}) {
    return Message(
      id: id,
      roomId: map['roomId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      senderProfileUrl: map['senderProfileUrl'] as String?,
      content: map['content'] as String? ?? '',
      type: _parseType(map['type']),
      imageUrl: map['imageUrl'] as String?,
      imageThumbnailUrl: map['imageThumbnailUrl'] as String?,
      readBy: _parseReadBy(map['readBy']),
      createdAt: _timestampToDateTime(map['createdAt']) ?? DateTime.now(),
      isDeleted: map['isDeleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'senderId': senderId,
      'senderName': senderName,
      'senderProfileUrl': senderProfileUrl,
      'content': content,
      'type': type.name,
      'imageUrl': imageUrl,
      'imageThumbnailUrl': imageThumbnailUrl,
      'readBy': readBy.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
      'createdAt': Timestamp.fromDate(createdAt),
      'isDeleted': isDeleted,
    };
  }

  Message copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderName,
    String? senderProfileUrl,
    String? content,
    MessageType? type,
    String? imageUrl,
    String? imageThumbnailUrl,
    Map<String, DateTime>? readBy,
    DateTime? createdAt,
    bool? isDeleted,
  }) {
    return Message(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderProfileUrl: senderProfileUrl ?? this.senderProfileUrl,
      content: content ?? this.content,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      imageThumbnailUrl: imageThumbnailUrl ?? this.imageThumbnailUrl,
      readBy: readBy ?? this.readBy,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Whether [userId] has read this message.
  bool isReadBy(String userId) => readBy.containsKey(userId);

  /// Number of participants who have read this message (excluding sender).
  int readCount({String? excludeUserId}) {
    if (excludeUserId == null) return readBy.length;
    return readBy.keys.where((uid) => uid != excludeUserId).length;
  }

  static MessageType _parseType(dynamic value) {
    switch (value) {
      case 'image':
        return MessageType.image;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }

  static Map<String, DateTime> _parseReadBy(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      final result = <String, DateTime>{};
      for (final entry in value.entries) {
        final dt = _timestampToDateTime(entry.value);
        if (dt != null) result[entry.key.toString()] = dt;
      }
      return result;
    }
    return {};
  }

  static DateTime? _timestampToDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Message && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Message(id: $id, senderId: $senderId, type: $type, createdAt: $createdAt)';
}
