# BWS Chat

소개팅 앱을 위한 재사용 가능한 Flutter 채팅 모듈. Firebase 백엔드와 카카오톡 스타일 UI를 제공합니다. BiWeekly Studio에서 제작.

> [English](README.md) | **한국어**

## 기능

- **1:1 및 그룹 채팅**: 일대일 대화와 다자간 그룹 채팅 지원
- **사진 전송**: 자동 압축 및 썸네일 생성을 포함한 이미지 공유
- **읽음 표시**: 메시지를 읽은 참여자 추적 및 안 읽은 메시지 수 표시
- **타이핑 표시**: 상대방이 입력 중일 때 실시간 표시
- **온라인/오프라인 상태**: 참여자의 접속 상태 표시
- **푸시 알림**: Firebase Cloud Messaging(FCM) 연동
- **메시지 검색**: 채팅방 내 메시지 검색
- **채팅방 관리**: 나가기 시 시스템 메시지 자동 전송, 대화 기록 유지
- **카카오톡 스타일 UI**: 익숙한 한국식 메시징 인터페이스
- **커스터마이징**: `ChatConfig`를 통한 색상, 폰트, 동작 제어
- **Riverpod 상태관리**: 깔끔한 프로바이더 아키텍처

## 기술 스택

- **Flutter**: UI 프레임워크 (1.17.0 이상)
- **Firebase**: Firestore(메시지), Storage(이미지), Auth(인증), Realtime Database(접속 상태), Cloud Messaging(알림)
- **Riverpod**: 상태관리 및 의존성 주입
- **Dart SDK**: 3.11.4 이상

## 시작하기

### 설치

`pubspec.yaml`에 추가:

```yaml
dependencies:
  bws_chat:
    git:
      url: https://github.com/BiWeekly-Studio/bws_chat.git
      ref: main
```

`flutter pub get` 실행.

### Firebase 설정

다음 Firebase 서비스가 활성화된 프로젝트가 필요합니다:

1. **Firestore Database**: 채팅방 및 메시지 저장
2. **Firebase Storage**: 이미지 파일 저장
3. **Firebase Authentication**: 사용자 인증
4. **Realtime Database**: 접속 상태 추적
5. **Cloud Messaging**: 푸시 알림

### 연동

앱을 `ProviderScope`로 감싸고 필수 프로바이더를 오버라이드하세요:

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
        // 필수: 현재 로그인한 사용자의 ID
        currentUserIdProvider.overrideWithValue('user_123'),

        // 선택: 채팅 UI 커스터마이징
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
          appBar: AppBar(title: const Text('채팅')),
          body: const ChatListScreen(),
        ),
      ),
    );
  }
}
```

## 사용법

### 채팅 목록 표시

```dart
import 'package:bws_chat/bws_chat.dart';

// 위젯에서:
ChatListScreen()
```

### 1:1 채팅방 생성

```dart
final chatService = ref.watch(chatServiceProvider);

final room = await chatService.createOneToOneRoom(
  currentUserId: 'user_123',
  otherUserId: 'user_456',
);

// 채팅방으로 이동
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ChatDetailScreen(roomId: room.id),
  ),
);
```

### 메시지 전송

UI를 통해 자동으로 전송되지만, 코드에서 직접 전송할 수도 있습니다:

```dart
final chatService = ref.watch(chatServiceProvider);

// 텍스트 메시지 전송
await chatService.sendTextMessage(
  roomId: 'room_123',
  senderId: 'user_123',
  senderName: '홍길동',
  senderProfileUrl: 'https://example.com/avatar.jpg',
  text: '안녕하세요!',
);

// 이미지 메시지 전송
await chatService.sendImageMessage(
  roomId: 'room_123',
  senderId: 'user_123',
  senderName: '홍길동',
  imageUrl: 'https://firebase.example.com/image.jpg',
  thumbnailUrl: 'https://firebase.example.com/image_thumb.jpg',
);
```

### 메시지 읽음 처리

```dart
final chatService = ref.watch(chatServiceProvider);

await chatService.markAsRead(
  roomId: 'room_123',
  userId: 'user_123',
);
```

## 아키텍처

### 디렉토리 구조

```
lib/
├── src/
│   ├── models/          # 데이터 모델 (ChatRoom, Message, ChatUser)
│   ├── services/        # Firebase 서비스 (Chat, Storage, Presence, Notification)
│   ├── providers/       # Riverpod 프로바이더
│   ├── config/          # ChatConfig 커스터마이징
│   ├── screens/         # UI 화면 (채팅 목록, 채팅방, 채팅방 정보)
│   ├── widgets/         # 재사용 UI 컴포넌트 (말풍선, 입력창 등)
│   └── utils/           # 상수 및 유틸리티
└── bws_chat.dart        # 메인 export 파일
```

### 핵심 프로바이더

- **`currentUserIdProvider`**: 인증된 사용자 ID (필수 오버라이드)
- **`chatConfigProvider`**: 전역 채팅 설정 (선택 오버라이드)
- **`chatServiceProvider`**: Firestore 기반 채팅 서비스
- **`chatRoomsProvider`**: 사용자의 채팅방 스트림
- **`messagesProvider`**: 채팅방 내 메시지 스트림
- **`userPresenceProvider`**: 사용자 온/오프라인 상태
- **`unreadTotalCountProvider`**: 전체 안 읽은 메시지 수

## 커스터마이징

### ChatConfig 예시

```dart
ChatConfig(
  // 색상
  primaryColor: Color(0xFF4F86F7),
  backgroundColor: Color(0xFFF5F5F5),
  inputBackgroundColor: Color(0xFFFFFFFF),
  bubbleColors: BubbleColors.dark,  // 또는 BubbleColors.kakao
  onlineIndicatorColor: Color(0xFF4CAF50),
  unreadBadgeColor: Color(0xFFFF3B30),
  unreadBadgeTextColor: Color(0xFFFFFFFF),

  // 텍스트
  dateLocale: 'ko',
  showSecondsInTimestamp: true,

  // 미디어
  imageSettings: ImageSettings(
    maxDimension: 1920,
    compressionQuality: 80,
    maxFileSizeBytes: 10 * 1024 * 1024,  // 10 MB
  ),
  showInlineImageThumbnails: true,

  // 동작
  maxMessageLength: 1000,
  typingIndicatorsEnabled: true,
  readReceiptsEnabled: true,
  pushNotificationsEnabled: true,
)
```

### 말풍선 프리셋

- **`BubbleColors.kakao`**: 노란색 전송 말풍선, 흰색 수신 (카카오톡 스타일)
- **`BubbleColors.dark`**: 파란색 전송 말풍선, 진회색 수신 (다크 테마)

`BubbleColors`에 원하는 색상을 지정하여 커스텀 스타일도 만들 수 있습니다.

## Firebase 상세 설정

### Firestore 컬렉션

이 패키지는 두 개의 주요 컬렉션을 사용합니다:

- **`chat_rooms`**: 채팅방 메타데이터 저장
  - 필드: `type`, `name`, `imageUrl`, `participantIds`, `participantProfiles`, `lastMessage`, `lastMessageTime`, `lastMessageSenderId`, `unreadCount`, `createdAt`, `createdBy`

- **`chat_rooms/{roomId}/messages`**: 각 채팅방의 메시지 저장
  - 필드: `roomId`, `senderId`, `senderName`, `senderProfileUrl`, `content`, `type`, `imageUrl`, `imageThumbnailUrl`, `readBy`, `createdAt`, `isDeleted`

### 보안 규칙

Firestore 보안 규칙을 적절히 설정하세요. 최소 요구사항:
- 사용자는 자신이 참여한 채팅방의 메시지만 읽고 쓸 수 있어야 합니다
- 시스템 메시지는 신뢰할 수 있는 백엔드 서비스만 작성할 수 있어야 합니다
- 읽음 표시는 해당 사용자만 업데이트할 수 있어야 합니다

보안 규칙 예시:
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

## 문제 해결

### 프로바이더 오버라이드 문제

채팅 UI가 마운트되기 전에 `ProviderScope`에서 `currentUserIdProvider`가 오버라이드되어야 합니다. 값이 비어있으면 채팅 화면이 정상적으로 로드되지 않습니다.

### Firebase 설정

`google-services.json`(Android)과 `GoogleService-Info.plist`(iOS)가 올바르게 설정되었는지 확인하세요.

### 이미지 업로드 실패

Firebase Storage 규칙에서 인증된 사용자의 쓰기 권한을 확인하세요. `ChatConfig.imageSettings`의 압축 설정이 적절한지도 점검하세요.

## 라이선스

MIT

BiWeekly Studio에서 제작했습니다.
