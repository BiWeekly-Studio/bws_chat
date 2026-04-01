import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/chat_config.dart';
import '../models/chat_room.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../services/presence_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

/// Overridable config provider. The host app must override this in
/// ProviderScope to supply its own ChatConfig.
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     chatConfigProvider.overrideWithValue(ChatConfig(primaryColor: ...)),
///   ],
///   child: MyApp(),
/// )
/// ```
final chatConfigProvider = Provider<ChatConfig>(
  (ref) => const ChatConfig(),
  name: 'chatConfigProvider',
);

// ---------------------------------------------------------------------------
// Current user
// ---------------------------------------------------------------------------

/// Overridable provider for the currently authenticated user's ID.
/// The host app MUST override this in ProviderScope before using any chat UI.
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     currentUserIdProvider.overrideWithValue('uid_123'),
///   ],
///   child: MyApp(),
/// )
/// ```
final currentUserIdProvider = Provider<String>(
  (ref) => '',
  name: 'currentUserIdProvider',
);

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

/// Provides a singleton [ChatService] backed by Firestore.
final chatServiceProvider = Provider<ChatService>(
  (ref) => ChatService(),
  name: 'chatServiceProvider',
);

/// Provides a singleton [StorageService] backed by Firebase Storage.
/// Respects image settings from [chatConfigProvider].
final storageServiceProvider = Provider<StorageService>((ref) {
  final config = ref.watch(chatConfigProvider);
  return StorageService(imageSettings: config.imageSettings);
}, name: 'storageServiceProvider');

/// Provides a singleton [PresenceService] backed by Firebase Realtime Database.
final presenceServiceProvider = Provider<PresenceService>(
  (ref) => PresenceService(),
  name: 'presenceServiceProvider',
);

/// Provides a singleton [NotificationService] backed by Firebase Messaging.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
  name: 'notificationServiceProvider',
);

// ---------------------------------------------------------------------------
// Room streams
// ---------------------------------------------------------------------------

/// Stream of [ChatRoom] objects the current user participates in, ordered by
/// most recent message. Emits an empty list while [currentUserIdProvider] is
/// not yet overridden.
final chatRoomsProvider = StreamProvider<List<ChatRoom>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId.isEmpty) return const Stream.empty();

  final service = ref.watch(chatServiceProvider);
  return service.getRoomsStream(userId);
}, name: 'chatRoomsProvider');

// ---------------------------------------------------------------------------
// Message streams (family)
// ---------------------------------------------------------------------------

/// Stream of [Message] objects for [roomId], newest first.
/// Loads [ChatLimits.messagesPerPage] messages per page.
final messagesProvider =
    StreamProvider.family<List<Message>, String>((ref, roomId) {
  final service = ref.watch(chatServiceProvider);
  return service.getMessagesStream(
    roomId,
    limit: ChatLimits.messagesPerPage,
  );
}, name: 'messagesProvider');

// ---------------------------------------------------------------------------
// Presence streams (family)
// ---------------------------------------------------------------------------

/// Stream that emits `true` when [userId] is online, `false` otherwise.
final userPresenceProvider =
    StreamProvider.family<bool, String>((ref, userId) {
  final service = ref.watch(presenceServiceProvider);
  return service.getUserPresenceStream(userId);
}, name: 'userPresenceProvider');

// ---------------------------------------------------------------------------
// Computed: total unread count
// ---------------------------------------------------------------------------

/// Computed total unread message count across all rooms for the current user.
/// Returns 0 while rooms are loading or the user ID is not set.
final unreadTotalCountProvider = Provider<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId.isEmpty) return 0;

  final roomsAsync = ref.watch(chatRoomsProvider);
  return roomsAsync.when(
    data: (rooms) => rooms.fold<int>(
      0,
      (sum, room) => sum + (room.unreadCount[userId] ?? 0),
    ),
    loading: () => 0,
    error: (_, __) => 0,
  );
}, name: 'unreadTotalCountProvider');

// ---------------------------------------------------------------------------
// Typing status: per-room notifier
// ---------------------------------------------------------------------------

/// StateNotifier that manages message pagination limit for a room.
/// Starts at [ChatLimits.messagesPerPage] and increments on load-more.
class MessageLimitNotifier extends StateNotifier<int> {
  MessageLimitNotifier() : super(ChatLimits.messagesPerPage);

  void loadMore() => state = state + ChatLimits.messagesPerPage;

  void reset() => state = ChatLimits.messagesPerPage;
}

/// Per-room message limit provider (for pagination).
final messageLimitProvider =
    StateNotifierProvider.family<MessageLimitNotifier, int, String>(
  (ref, roomId) => MessageLimitNotifier(),
  name: 'messageLimitProvider',
);

/// Paginated messages stream that respects [messageLimitProvider].
final paginatedMessagesProvider =
    StreamProvider.family<List<Message>, String>((ref, roomId) {
  final limit = ref.watch(messageLimitProvider(roomId));
  final service = ref.watch(chatServiceProvider);
  return service.getMessagesStream(roomId, limit: limit);
}, name: 'paginatedMessagesProvider');
