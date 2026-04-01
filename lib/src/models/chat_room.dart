import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_user.dart';

enum ChatRoomType { oneToOne, group }

class ChatRoom {
  final String id;
  final ChatRoomType type;
  final String? name;
  final String? imageUrl;
  final List<String> participantIds;
  final Map<String, ChatUser> participantProfiles;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  // userId -> unread count
  final Map<String, int> unreadCount;
  final DateTime createdAt;
  final String createdBy;

  const ChatRoom({
    required this.id,
    required this.type,
    this.name,
    this.imageUrl,
    required this.participantIds,
    this.participantProfiles = const {},
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.unreadCount = const {},
    required this.createdAt,
    required this.createdBy,
  });

  factory ChatRoom.fromMap(Map<String, dynamic> map, {required String id}) {
    return ChatRoom(
      id: id,
      type: _parseType(map['type']),
      name: map['name'] as String?,
      imageUrl: map['imageUrl'] as String?,
      participantIds: _parseStringList(map['participantIds']),
      participantProfiles: _parseParticipantProfiles(map['participantProfiles']),
      lastMessage: map['lastMessage'] as String?,
      lastMessageTime: _timestampToDateTime(map['lastMessageTime']),
      lastMessageSenderId: map['lastMessageSenderId'] as String?,
      unreadCount: _parseIntMap(map['unreadCount']),
      createdAt: _timestampToDateTime(map['createdAt']) ?? DateTime.now(),
      createdBy: map['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'name': name,
      'imageUrl': imageUrl,
      'participantIds': participantIds,
      'participantProfiles': participantProfiles.map(
        (k, v) => MapEntry(k, v.toMap()),
      ),
      'lastMessage': lastMessage,
      'lastMessageTime':
          lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : null,
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  ChatRoom copyWith({
    String? id,
    ChatRoomType? type,
    String? name,
    String? imageUrl,
    List<String>? participantIds,
    Map<String, ChatUser>? participantProfiles,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    Map<String, int>? unreadCount,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      participantIds: participantIds ?? this.participantIds,
      participantProfiles: participantProfiles ?? this.participantProfiles,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// Returns a display name for this room from the perspective of [currentUserId].
  /// For 1:1 rooms without an explicit name, returns the other participant's displayName.
  String displayName(String currentUserId) {
    if (name != null && name!.isNotEmpty) return name!;
    if (type == ChatRoomType.oneToOne) {
      final otherId = participantIds.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      return participantProfiles[otherId]?.displayName ?? '알 수 없음';
    }
    return '그룹 채팅';
  }

  /// Returns the profile image URL for this room from the perspective of [currentUserId].
  String? displayImageUrl(String currentUserId) {
    if (imageUrl != null) return imageUrl;
    if (type == ChatRoomType.oneToOne) {
      final otherId = participantIds.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      return participantProfiles[otherId]?.profileImageUrl;
    }
    return null;
  }

  static ChatRoomType _parseType(dynamic value) {
    if (value == 'group') return ChatRoomType.group;
    return ChatRoomType.oneToOne;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  static Map<String, ChatUser> _parseParticipantProfiles(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      return value.map(
        (k, v) => MapEntry(
          k.toString(),
          ChatUser.fromMap(Map<String, dynamic>.from(v as Map), uid: k.toString()),
        ),
      );
    }
    return {};
  }

  static Map<String, int> _parseIntMap(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
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
      identical(this, other) || other is ChatRoom && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ChatRoom(id: $id, type: $type, name: $name)';
}
