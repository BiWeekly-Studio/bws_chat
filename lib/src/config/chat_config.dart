import 'package:flutter/material.dart';

/// Bubble color pair for sent / received messages.
class BubbleColors {
  final Color sent;
  final Color sentText;
  final Color received;
  final Color receivedText;

  const BubbleColors({
    required this.sent,
    required this.sentText,
    required this.received,
    required this.receivedText,
  });

  /// KakaoTalk-inspired defaults: yellow sent, white received.
  static const BubbleColors kakao = BubbleColors(
    sent: Color(0xFFFFE812),
    sentText: Color(0xFF1A1A1A),
    received: Color(0xFFFFFFFF),
    receivedText: Color(0xFF1A1A1A),
  );

  /// Modern dark-theme defaults.
  static const BubbleColors dark = BubbleColors(
    sent: Color(0xFF4F86F7),
    sentText: Color(0xFFFFFFFF),
    received: Color(0xFF2C2C2E),
    receivedText: Color(0xFFFFFFFF),
  );
}

/// Image compression / size settings.
class ImageSettings {
  /// Maximum width/height in pixels before compression is applied.
  final int maxDimension;

  /// JPEG quality 0–100 used when compressing images before upload.
  final int compressionQuality;

  /// Maximum file size in bytes allowed for upload (default 10 MB).
  final int maxFileSizeBytes;

  const ImageSettings({
    this.maxDimension = 1920,
    this.compressionQuality = 80,
    this.maxFileSizeBytes = 10 * 1024 * 1024,
  });
}

/// Top-level configuration object passed to the chat module at initialisation.
///
/// All fields have sensible defaults so callers only need to override
/// what they actually want to customise.
///
/// Example:
/// ```dart
/// ChatConfig(
///   primaryColor: Color(0xFF4F86F7),
///   bubbleColors: BubbleColors.dark,
///   imageSettings: ImageSettings(compressionQuality: 70),
/// )
/// ```
class ChatConfig {
  // ---------------------------------------------------------------------------
  // Colours
  // ---------------------------------------------------------------------------

  /// Accent / brand colour (app bar, send button, active states).
  final Color primaryColor;

  /// Overall background colour of the chat room screen.
  final Color backgroundColor;

  /// Background colour for the message input area.
  final Color inputBackgroundColor;

  /// Chat bubble colours for sent and received messages.
  final BubbleColors bubbleColors;

  /// Colour shown for "online" presence indicator dot.
  final Color onlineIndicatorColor;

  /// Colour shown for unread badge backgrounds.
  final Color unreadBadgeColor;

  /// Text colour used on unread badges.
  final Color unreadBadgeTextColor;

  // ---------------------------------------------------------------------------
  // Typography / date formatting
  // ---------------------------------------------------------------------------

  /// Locale string forwarded to `intl` for date formatting (default: 'ko').
  final String dateLocale;

  /// Whether to show seconds in message timestamps (default: false).
  final bool showSecondsInTimestamp;

  // ---------------------------------------------------------------------------
  // Media
  // ---------------------------------------------------------------------------

  /// Image upload / compression settings.
  final ImageSettings imageSettings;

  /// Whether to show image thumbnails inline in the message list (default: true).
  final bool showInlineImageThumbnails;

  // ---------------------------------------------------------------------------
  // Behaviour
  // ---------------------------------------------------------------------------

  /// Maximum number of characters allowed in a single text message.
  final int maxMessageLength;

  /// Whether typing indicators are enabled (default: true).
  final bool typingIndicatorsEnabled;

  /// Whether read receipts are shown (default: true).
  final bool readReceiptsEnabled;

  /// Whether push notifications are enabled (default: true).
  final bool pushNotificationsEnabled;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  const ChatConfig({
    this.primaryColor = const Color(0xFF4F86F7),
    this.backgroundColor = const Color(0xFFF5F5F5),
    this.inputBackgroundColor = const Color(0xFFFFFFFF),
    this.bubbleColors = BubbleColors.kakao,
    this.onlineIndicatorColor = const Color(0xFF4CAF50),
    this.unreadBadgeColor = const Color(0xFFFF3B30),
    this.unreadBadgeTextColor = const Color(0xFFFFFFFF),
    this.dateLocale = 'ko',
    this.showSecondsInTimestamp = false,
    this.imageSettings = const ImageSettings(),
    this.showInlineImageThumbnails = true,
    this.maxMessageLength = 1000,
    this.typingIndicatorsEnabled = true,
    this.readReceiptsEnabled = true,
    this.pushNotificationsEnabled = true,
  });

  /// Returns a copy of this config with the given fields replaced.
  ChatConfig copyWith({
    Color? primaryColor,
    Color? backgroundColor,
    Color? inputBackgroundColor,
    BubbleColors? bubbleColors,
    Color? onlineIndicatorColor,
    Color? unreadBadgeColor,
    Color? unreadBadgeTextColor,
    String? dateLocale,
    bool? showSecondsInTimestamp,
    ImageSettings? imageSettings,
    bool? showInlineImageThumbnails,
    int? maxMessageLength,
    bool? typingIndicatorsEnabled,
    bool? readReceiptsEnabled,
    bool? pushNotificationsEnabled,
  }) {
    return ChatConfig(
      primaryColor: primaryColor ?? this.primaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      inputBackgroundColor: inputBackgroundColor ?? this.inputBackgroundColor,
      bubbleColors: bubbleColors ?? this.bubbleColors,
      onlineIndicatorColor: onlineIndicatorColor ?? this.onlineIndicatorColor,
      unreadBadgeColor: unreadBadgeColor ?? this.unreadBadgeColor,
      unreadBadgeTextColor: unreadBadgeTextColor ?? this.unreadBadgeTextColor,
      dateLocale: dateLocale ?? this.dateLocale,
      showSecondsInTimestamp:
          showSecondsInTimestamp ?? this.showSecondsInTimestamp,
      imageSettings: imageSettings ?? this.imageSettings,
      showInlineImageThumbnails:
          showInlineImageThumbnails ?? this.showInlineImageThumbnails,
      maxMessageLength: maxMessageLength ?? this.maxMessageLength,
      typingIndicatorsEnabled:
          typingIndicatorsEnabled ?? this.typingIndicatorsEnabled,
      readReceiptsEnabled: readReceiptsEnabled ?? this.readReceiptsEnabled,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
    );
  }

  @override
  String toString() => 'ChatConfig('
      'primaryColor: $primaryColor, '
      'dateLocale: $dateLocale, '
      'typingIndicators: $typingIndicatorsEnabled, '
      'readReceipts: $readReceiptsEnabled'
      ')';
}
