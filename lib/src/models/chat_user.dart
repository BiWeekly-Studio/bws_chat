import 'package:cloud_firestore/cloud_firestore.dart';

class ChatUser {
  final String uid;
  final String displayName;
  final String? profileImageUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  // roomId -> isTyping
  final Map<String, bool> typing;

  const ChatUser({
    required this.uid,
    required this.displayName,
    this.profileImageUrl,
    this.isOnline = false,
    this.lastSeen,
    this.typing = const {},
  });

  factory ChatUser.fromMap(Map<String, dynamic> map, {String? uid}) {
    return ChatUser(
      uid: uid ?? map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      profileImageUrl: map['profileImageUrl'] as String?,
      isOnline: map['isOnline'] as bool? ?? false,
      lastSeen: _timestampToDateTime(map['lastSeen']),
      typing: _parseTypingMap(map['typing']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'profileImageUrl': profileImageUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'typing': typing,
    };
  }

  ChatUser copyWith({
    String? uid,
    String? displayName,
    String? profileImageUrl,
    bool? isOnline,
    DateTime? lastSeen,
    Map<String, bool>? typing,
  }) {
    return ChatUser(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      typing: typing ?? this.typing,
    );
  }

  static DateTime? _timestampToDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static Map<String, bool> _parseTypingMap(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v as bool? ?? false));
    }
    return {};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChatUser && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() =>
      'ChatUser(uid: $uid, displayName: $displayName, isOnline: $isOnline)';
}
