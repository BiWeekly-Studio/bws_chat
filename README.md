# BWS Chat

A reusable Flutter chat module for dating apps with a Firebase backend and KakaoTalk-inspired UI. Built by BiWeekly Studio for seamless 1:1 and group messaging experiences.

> **English** | [한국어](README.ko.md)

## Features

- **1:1 and Group Chat**: Support for one-to-one conversations and multi-participant group chats
- **Photo/Image Sending**: Share images with automatic compression and thumbnail generation
- **Read Receipts**: Track which participants have read messages with unread message counts per user
- **Typing Indicators**: Real-time typing status display for active conversations
- **Online/Offline Presence**: Monitor participant availability with online presence indicators
- **Push Notifications**: Firebase Cloud Messaging (FCM) integration for message alerts
- **Message Search**: Search messages within a chat room (prefix matching via Firestore)
- **Chat Room Management**: Leave rooms with automatic system messages, maintain conversation history
- **KakaoTalk-Inspired UI**: Korean-style messaging interface with familiar interaction patterns
- **Customizable Theming**: Full control over colors, fonts, and behaviors via `ChatConfig`
- **Riverpod State Management**: Reactive state management with clean provider architecture

## Tech Stack

- **Flutter**: UI framework (requires Flutter 1.17.0+)
- **Firebase**: Firestore (messages), Firebase Storage (images), Firebase Auth, Realtime Database (presence), Cloud Messaging (notifications)
- **Riverpod**: State management and dependency injection
- **Dart SDK**: 3.11.4 or higher

## Getting Started

### Installation

Add `bws_chat` to your `pubspec.yaml`:

```yaml
dependencies:
  bws_chat:
    git:
      url: https://github.com/BiWeekly-Studio/bws_chat.git
      ref: main
```

Run `flutter pub get`.

### Firebase Setup

This package requires a Firebase project configured with the following services:

1. **Firestore Database**: Stores chat rooms and messages
2. **Firebase Storage**: Stores image files
3. **Firebase Authentication**: For user identity
4. **Realtime Database**: For presence tracking
5. **Cloud Messaging**: For push notifications

Ensure your Firebase project has these services enabled and security rules configured appropriately.

### Integration

Wrap your app with `ProviderScope` and override the required providers:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bws_chat/bws_chat.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        // REQUIRED: Override with the current user's ID from your auth system
        currentUserIdProvider.overrideWithValue('user_123'),

        // OPTIONAL: Customize chat appearance and behavior
        chatConfigProvider.overrideWithValue(
          ChatConfig(
            primaryColor: Color(0xFF4F86F7),
            bubbleColors: BubbleColors.kakao,
            dateLocale: 'ko',
            typingIndicatorsEnabled: true,
            readReceiptsEnabled: true,
            pushNotificationsEnabled: true,
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Chats')),
          body: const ChatListScreen(),
        ),
      ),
    );
  }
}
```

## Usage

### Displaying Chat List

```dart
import 'package:bws_chat/bws_chat.dart';

// In your widget:
ChatListScreen()
```

### Creating a 1:1 Chat Room Programmatically

```dart
final chatService = ref.watch(chatServiceProvider);

final room = await chatService.createOneToOneRoom(
  currentUserId: 'user_123',
  otherUserId: 'user_456',
);

// Navigate to chat room
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ChatDetailScreen(roomId: room.id),
  ),
);
```

### Sending Messages

Text messages, image messages, and system messages are sent automatically when users interact with the UI. You can also send messages programmatically:

```dart
final chatService = ref.watch(chatServiceProvider);

// Send text message
await chatService.sendTextMessage(
  roomId: 'room_123',
  senderId: 'user_123',
  senderName: 'John Doe',
  senderProfileUrl: 'https://example.com/avatar.jpg',
  text: 'Hello!',
);

// Send image message
await chatService.sendImageMessage(
  roomId: 'room_123',
  senderId: 'user_123',
  senderName: 'John Doe',
  imageUrl: 'https://firebase.example.com/image.jpg',
  thumbnailUrl: 'https://firebase.example.com/image_thumb.jpg',
);
```

### Marking Messages as Read

```dart
final chatService = ref.watch(chatServiceProvider);

await chatService.markAsRead(
  roomId: 'room_123',
  userId: 'user_123',
);
```

## Architecture

### Directory Structure

```
lib/
├── src/
│   ├── models/          # Data models (ChatRoom, Message, ChatUser)
│   ├── services/        # Firebase services (ChatService, StorageService, PresenceService, NotificationService)
│   ├── providers/       # Riverpod providers for state management
│   ├── config/          # ChatConfig for customization
│   ├── screens/         # UI screens (ChatListScreen, ChatDetailScreen)
│   ├── widgets/         # Reusable UI components (MessageBubble, InputField, etc.)
│   └── utils/           # Constants and utilities
└── bws_chat.dart        # Main export file
```

### Core Providers

- **`currentUserIdProvider`**: The authenticated user's ID (must be overridden)
- **`chatConfigProvider`**: Global chat configuration (optional override)
- **`chatServiceProvider`**: Firestore-backed chat service
- **`chatRoomsProvider`**: Stream of user's chat rooms
- **`messagesProvider`**: Stream of messages in a room
- **`userPresenceProvider`**: Online/offline status for a user
- **`unreadTotalCountProvider`**: Total unread message count across all rooms

## Customization

### ChatConfig Example

```dart
ChatConfig(
  // Colors
  primaryColor: Color(0xFF4F86F7),
  backgroundColor: Color(0xFFF5F5F5),
  inputBackgroundColor: Color(0xFFFFFFFF),
  bubbleColors: BubbleColors.dark,  // or BubbleColors.kakao
  onlineIndicatorColor: Color(0xFF4CAF50),
  unreadBadgeColor: Color(0xFFFF3B30),
  unreadBadgeTextColor: Color(0xFFFFFFFF),

  // Typography
  dateLocale: 'en',  // Default: 'ko'
  showSecondsInTimestamp: true,

  // Media
  imageSettings: ImageSettings(
    maxDimension: 1920,
    compressionQuality: 80,
    maxFileSizeBytes: 10 * 1024 * 1024,  // 10 MB
  ),
  showInlineImageThumbnails: true,

  // Behavior
  maxMessageLength: 1000,
  typingIndicatorsEnabled: true,
  readReceiptsEnabled: true,
  pushNotificationsEnabled: true,
)
```

### Preset Bubble Styles

The package includes two preset bubble color schemes:

- **`BubbleColors.kakao`**: Yellow sent bubbles, white received (KakaoTalk style)
- **`BubbleColors.dark`**: Blue sent bubbles, dark gray received (modern dark theme)

Create custom bubble styles by instantiating `BubbleColors` with your own colors.

## Firebase Setup Details

### Firestore Collections

The package uses two main collections:

- **`chat_rooms`**: Stores chat room metadata
  - Fields: `type`, `name`, `imageUrl`, `participantIds`, `participantProfiles`, `lastMessage`, `lastMessageTime`, `lastMessageSenderId`, `unreadCount`, `createdAt`, `createdBy`

- **`chat_rooms/{roomId}/messages`**: Stores messages within each room
  - Fields: `roomId`, `senderId`, `senderName`, `senderProfileUrl`, `content`, `type`, `imageUrl`, `imageThumbnailUrl`, `readBy`, `createdAt`, `isDeleted`

### Security Rules

Implement appropriate Firestore security rules to restrict access. At minimum:
- Users can only read/write messages and rooms they participate in
- System messages can only be written by trusted backend services
- Read receipts are updated only by the reading user

Example security rule structure:
```
match /chat_rooms/{roomId} {
  allow read: if request.auth.uid in resource.data.participantIds;
  allow update: if request.auth.uid in resource.data.participantIds;

  match /messages/{messageId} {
    allow read: if request.auth.uid in get(/databases/$(database)/documents/chat_rooms/$(roomId)).data.participantIds;
    allow create: if request.auth.uid == request.resource.data.senderId;
  }
}
```

## Troubleshooting

### Provider Override Issues

Ensure `currentUserIdProvider` is overridden in `ProviderScope` before any chat UI is mounted. If the value is empty, chat screens will not load correctly.

### Firebase Configuration

Verify your Firebase project credentials are properly configured in your Flutter app via `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).

### Image Upload Failures

Check Firebase Storage rules allow authenticated users to write to the storage bucket. Ensure image compression settings in `ChatConfig.imageSettings` are appropriate for your use case.

## License

MIT

Built with care by BiWeekly Studio.
