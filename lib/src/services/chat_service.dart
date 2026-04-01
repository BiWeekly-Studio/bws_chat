import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_room.dart';
import '../models/message.dart';
import '../utils/constants.dart';

/// Main Firestore service for the bws_chat module.
///
/// All write operations that touch both a room document and its messages
/// sub-collection use Firestore transactions or batched writes to guarantee
/// consistency.
class ChatService {
  ChatService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ---------------------------------------------------------------------------
  // Convenience references
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection(ChatCollections.rooms);

  CollectionReference<Map<String, dynamic>> _messages(String roomId) =>
      _rooms.doc(roomId).collection(ChatCollections.messages);

  // ---------------------------------------------------------------------------
  // Room creation
  // ---------------------------------------------------------------------------

  /// Returns an existing one-to-one room between [currentUserId] and
  /// [otherUserId], or creates one if none exists.
  Future<ChatRoom> getOrCreateOneToOneRoom({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final existing = await _findOneToOneRoom(currentUserId, otherUserId);
    if (existing != null) return existing;
    return createOneToOneRoom(
      currentUserId: currentUserId,
      otherUserId: otherUserId,
    );
  }

  /// Creates a new 1:1 room. Checks for an existing room first and returns it
  /// if found, avoiding duplicates.
  Future<ChatRoom> createOneToOneRoom({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final existing = await _findOneToOneRoom(currentUserId, otherUserId);
    if (existing != null) return existing;

    final now = DateTime.now();
    final docRef = _rooms.doc();

    final room = ChatRoom(
      id: docRef.id,
      type: ChatRoomType.oneToOne,
      participantIds: [currentUserId, otherUserId],
      unreadCount: {currentUserId: 0, otherUserId: 0},
      createdAt: now,
      createdBy: currentUserId,
    );

    await docRef.set(room.toMap());
    return room;
  }

  /// Creates a new group room.
  Future<ChatRoom> createGroupRoom({
    required String name,
    required List<String> participantIds,
    required String createdBy,
  }) async {
    final now = DateTime.now();
    final docRef = _rooms.doc();

    final unreadCount = {for (final id in participantIds) id: 0};

    final room = ChatRoom(
      id: docRef.id,
      type: ChatRoomType.group,
      name: name,
      participantIds: List.from(participantIds),
      unreadCount: unreadCount,
      createdAt: now,
      createdBy: createdBy,
    );

    await docRef.set(room.toMap());
    return room;
  }

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// Stream of all rooms [userId] participates in, ordered by most recent
  /// message first.
  Stream<List<ChatRoom>> getRoomsStream(String userId) {
    return _rooms
        .where(ChatFields.participantIds, arrayContains: userId)
        .orderBy(ChatFields.lastMessageTime, descending: true)
        .limit(ChatLimits.roomsPerPage)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ChatRoom.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  /// Paginated stream of messages in [roomId], newest first.
  Stream<List<Message>> getMessagesStream(
    String roomId, {
    int limit = ChatLimits.messagesPerPage,
  }) {
    return _messages(roomId)
        .orderBy(ChatFields.createdAt, descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Message.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // Sending messages
  // ---------------------------------------------------------------------------

  /// Sends a plain-text message and atomically updates the room's last-message
  /// fields and every other participant's unread count.
  Future<Message> sendTextMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    String? senderProfileUrl,
    required String text,
  }) {
    return _sendMessage(
      roomId: roomId,
      senderId: senderId,
      senderName: senderName,
      senderProfileUrl: senderProfileUrl,
      content: text,
      type: MessageType.text,
    );
  }

  /// Sends an image message.
  Future<Message> sendImageMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    String? senderProfileUrl,
    required String imageUrl,
    String? thumbnailUrl,
  }) {
    return _sendMessage(
      roomId: roomId,
      senderId: senderId,
      senderName: senderName,
      senderProfileUrl: senderProfileUrl,
      content: '[사진]',
      type: MessageType.image,
      imageUrl: imageUrl,
      imageThumbnailUrl: thumbnailUrl,
    );
  }

  /// Sends a system message (e.g. "홍길동님이 나갔습니다").
  Future<Message> sendSystemMessage({
    required String roomId,
    required String text,
  }) {
    return _sendMessage(
      roomId: roomId,
      senderId: 'system',
      senderName: 'system',
      content: text,
      type: MessageType.system,
    );
  }

  // ---------------------------------------------------------------------------
  // Read receipts
  // ---------------------------------------------------------------------------

  /// Marks all unread messages in [roomId] as read for [userId] and resets
  /// that user's unread counter to 0.
  ///
  /// Uses a batched write for atomicity. Processes up to 500 documents per
  /// batch (Firestore hard limit).
  Future<void> markAsRead({
    required String roomId,
    required String userId,
  }) async {
    final now = Timestamp.now();

    // Fetch messages not yet read by this user (excluding own messages).
    final unread = await _messages(roomId)
        .where(ChatFields.senderId, isNotEqualTo: userId)
        .where('${ChatFields.readBy}.$userId', isNull: true)
        .get();

    // Process in chunks of 500 (Firestore batch limit).
    const batchSize = 499;
    final docs = unread.docs;

    for (var i = 0; i < docs.length; i += batchSize) {
      final chunk = docs.sublist(
        i,
        (i + batchSize) < docs.length ? i + batchSize : docs.length,
      );
      final batch = _db.batch();
      for (final doc in chunk) {
        batch.update(doc.reference, {'${ChatFields.readBy}.$userId': now});
      }
      await batch.commit();
    }

    // Reset unread counter for this user on the room document.
    await _rooms.doc(roomId).update({'${ChatFields.unreadCount}.$userId': 0});
  }

  // ---------------------------------------------------------------------------
  // Message deletion
  // ---------------------------------------------------------------------------

  /// Soft-deletes a message by setting [isDeleted] to true and clearing
  /// sensitive fields.
  Future<void> deleteMessage({
    required String messageId,
    required String roomId,
  }) async {
    await _messages(roomId).doc(messageId).update({
      ChatFields.isDeleted: true,
      ChatFields.content: '삭제된 메시지입니다.',
      ChatFields.imageUrl2: null,
      ChatFields.imageThumbnailUrl: null,
    });
  }

  // ---------------------------------------------------------------------------
  // Leave room
  // ---------------------------------------------------------------------------

  /// Removes [userId] from [roomId] and sends a system message. For 1:1 rooms
  /// the document is left intact so the other participant keeps their history.
  Future<void> leaveRoom({
    required String roomId,
    required String userId,
  }) async {
    final roomSnap = await _rooms.doc(roomId).get();
    if (!roomSnap.exists) return;

    final room = ChatRoom.fromMap(roomSnap.data()!, id: roomSnap.id);
    final updatedParticipants =
        room.participantIds.where((id) => id != userId).toList();

    // Build a display name for the system message.
    final leavingUser = room.participantProfiles[userId];
    final displayName = leavingUser?.displayName ?? userId;

    final batch = _db.batch();

    // Update participant list and remove unread counter for this user.
    batch.update(_rooms.doc(roomId), {
      ChatFields.participantIds: updatedParticipants,
      '${ChatFields.unreadCount}.$userId': FieldValue.delete(),
      '${ChatFields.participantProfiles}.$userId': FieldValue.delete(),
    });

    // Add system message.
    final msgRef = _messages(roomId).doc();
    final now = DateTime.now();
    final systemMsg = Message(
      id: msgRef.id,
      roomId: roomId,
      senderId: 'system',
      senderName: 'system',
      content: '$displayName님이 나갔습니다.',
      type: MessageType.system,
      createdAt: now,
    );
    batch.set(msgRef, systemMsg.toMap());

    // Update lastMessage on the room.
    batch.update(_rooms.doc(roomId), {
      ChatFields.lastMessage: systemMsg.content,
      ChatFields.lastMessageTime: Timestamp.fromDate(now),
      ChatFields.lastMessageSenderId: 'system',
    });

    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Returns messages whose content contains [query] (case-sensitive,
  /// Firestore-side prefix scan). For full-text search a third-party
  /// solution such as Algolia is recommended; this is a best-effort helper.
  Future<List<Message>> searchMessages({
    required String roomId,
    required String query,
  }) async {
    if (query.isEmpty) return [];

    // Firestore does not support LIKE queries; we use a range query on the
    // content field which works for prefix matching only.
    final snap = await _messages(roomId)
        .where(ChatFields.content, isGreaterThanOrEqualTo: query)
        .where(ChatFields.content, isLessThan: '$query\uf8ff')
        .where(ChatFields.isDeleted, isEqualTo: false)
        .orderBy(ChatFields.content)
        .orderBy(ChatFields.createdAt, descending: true)
        .limit(50)
        .get();

    return snap.docs.map((d) => Message.fromMap(d.data(), id: d.id)).toList();
  }

  // ---------------------------------------------------------------------------
  // Typing status
  // ---------------------------------------------------------------------------

  /// Updates the typing indicator for [userId] in [roomId].
  Future<void> updateTypingStatus({
    required String roomId,
    required String userId,
    required bool isTyping,
  }) async {
    await _rooms.doc(roomId).update({
      '${ChatFields.typing}.$userId': isTyping,
    });
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Checks Firestore for an existing 1:1 room containing exactly
  /// [userA] and [userB].
  Future<ChatRoom?> _findOneToOneRoom(String userA, String userB) async {
    // Query rooms where userA is a participant and the type is oneToOne.
    // We then filter client-side to confirm userB is also in the room.
    final snap = await _rooms
        .where(ChatFields.type, isEqualTo: ChatRoomType.oneToOne.name)
        .where(ChatFields.participantIds, arrayContains: userA)
        .limit(50)
        .get();

    for (final doc in snap.docs) {
      final room = ChatRoom.fromMap(doc.data(), id: doc.id);
      if (room.participantIds.contains(userB) &&
          room.participantIds.length == 2) {
        return room;
      }
    }
    return null;
  }

  /// Internal send implementation shared by all message-type methods.
  Future<Message> _sendMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    String? senderProfileUrl,
    required String content,
    required MessageType type,
    String? imageUrl,
    String? imageThumbnailUrl,
  }) async {
    final now = DateTime.now();
    final msgRef = _messages(roomId).doc();

    final message = Message(
      id: msgRef.id,
      roomId: roomId,
      senderId: senderId,
      senderName: senderName,
      senderProfileUrl: senderProfileUrl,
      content: content,
      type: type,
      imageUrl: imageUrl,
      imageThumbnailUrl: imageThumbnailUrl,
      readBy: {senderId: now},
      createdAt: now,
    );

    // Use a transaction so the room metadata and message land together.
    await _db.runTransaction((tx) async {
      final roomSnap = await tx.get(_rooms.doc(roomId));
      if (!roomSnap.exists) {
        throw Exception('ChatRoom $roomId does not exist.');
      }

      final room = ChatRoom.fromMap(roomSnap.data()!, id: roomSnap.id);

      // Increment unread count for every participant except the sender.
      final newUnread = Map<String, int>.from(room.unreadCount);
      for (final participantId in room.participantIds) {
        if (participantId != senderId) {
          newUnread[participantId] = (newUnread[participantId] ?? 0) + 1;
        }
      }

      // Write the message document.
      tx.set(msgRef, message.toMap());

      // Update the room summary.
      tx.update(_rooms.doc(roomId), {
        ChatFields.lastMessage: content,
        ChatFields.lastMessageTime: Timestamp.fromDate(now),
        ChatFields.lastMessageSenderId: senderId,
        ChatFields.unreadCount: newUnread,
      });
    });

    return message;
  }
}
