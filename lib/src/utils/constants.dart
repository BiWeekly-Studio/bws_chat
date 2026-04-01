/// Firestore collection and field name constants for the bws_chat module.
/// Centralising these prevents typos and makes schema refactors easier.
class ChatCollections {
  ChatCollections._();

  // Top-level collections
  static const String users = 'chat_users';
  static const String rooms = 'chat_rooms';

  // Sub-collection inside each room document
  static const String messages = 'messages';
}

/// Field names used across Firestore documents.
class ChatFields {
  ChatFields._();

  // ChatUser
  static const String uid = 'uid';
  static const String displayName = 'displayName';
  static const String profileImageUrl = 'profileImageUrl';
  static const String isOnline = 'isOnline';
  static const String lastSeen = 'lastSeen';
  static const String typing = 'typing';

  // ChatRoom
  static const String type = 'type';
  static const String name = 'name';
  static const String imageUrl = 'imageUrl';
  static const String participantIds = 'participantIds';
  static const String participantProfiles = 'participantProfiles';
  static const String lastMessage = 'lastMessage';
  static const String lastMessageTime = 'lastMessageTime';
  static const String lastMessageSenderId = 'lastMessageSenderId';
  static const String unreadCount = 'unreadCount';
  static const String createdAt = 'createdAt';
  static const String createdBy = 'createdBy';

  // Message
  static const String roomId = 'roomId';
  static const String senderId = 'senderId';
  static const String senderName = 'senderName';
  static const String senderProfileUrl = 'senderProfileUrl';
  static const String content = 'content';
  static const String imageUrl2 = 'imageUrl';
  static const String imageThumbnailUrl = 'imageThumbnailUrl';
  static const String readBy = 'readBy';
  static const String isDeleted = 'isDeleted';
}

/// Firebase Realtime Database paths (used for presence / online status).
class PresencePaths {
  PresencePaths._();

  static const String root = 'presence';

  /// Full path for a single user's presence node.
  static String forUser(String uid) => '$root/$uid';
}

/// Firebase Storage path prefixes.
class StoragePaths {
  StoragePaths._();

  static const String chatImages = 'chat_images';

  /// Path for an image inside a specific room.
  static String roomImage(String roomId, String fileName) =>
      '$chatImages/$roomId/$fileName';
}

/// Pagination / query limits.
class ChatLimits {
  ChatLimits._();

  /// Number of messages loaded per page.
  static const int messagesPerPage = 30;

  /// Number of chat rooms loaded per page.
  static const int roomsPerPage = 20;
}

/// FCM topic and notification constants.
class ChatNotifications {
  ChatNotifications._();

  static const String channelId = 'bws_chat_messages';
  static const String channelName = '채팅 메시지';
  static const String channelDescription = '새 채팅 메시지 알림';

  /// FCM data payload keys.
  static const String payloadRoomId = 'roomId';
  static const String payloadSenderId = 'senderId';
  static const String payloadType = 'notificationType';
}
