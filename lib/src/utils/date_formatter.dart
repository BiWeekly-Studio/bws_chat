import 'package:intl/intl.dart';

/// KakaoTalk-style date/time formatting utilities in Korean.
///
/// Rules:
/// - Same day            → 오전/오후 h:mm  (e.g. 오후 3:05)
/// - Yesterday           → 어제
/// - Same year, not today/yesterday → M월 d일 (e.g. 3월 15일)
/// - Different year      → yyyy년 M월 d일 (e.g. 2024년 3월 15일)
///
/// Message list divider (날짜 구분선):
/// - Same year           → yyyy년 M월 d일 EEEE (e.g. 2025년 3월 15일 토요일)
/// - Used as a section header between messages on different dates.
class ChatDateFormatter {
  ChatDateFormatter._();

  static final DateFormat _timeFormat = DateFormat('a h:mm', 'ko');
  static final DateFormat _monthDayFormat = DateFormat('M월 d일', 'ko');
  static final DateFormat _yearMonthDayFormat = DateFormat('yyyy년 M월 d일', 'ko');
  static final DateFormat _dividerFormat =
      DateFormat('yyyy년 M월 d일 EEEE', 'ko');

  /// Format used in the chat room list (last message timestamp).
  ///
  /// - Today    → 오전/오후 h:mm
  /// - Yesterday → 어제
  /// - Same year → M월 d일
  /// - Older    → yyyy년 M월 d일
  static String formatRoomListTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = _dateOnly(dateTime);

    if (target == today) {
      return _timeFormat.format(dateTime);
    } else if (target == yesterday) {
      return '어제';
    } else if (target.year == today.year) {
      return _monthDayFormat.format(dateTime);
    } else {
      return _yearMonthDayFormat.format(dateTime);
    }
  }

  /// Format used inside a chat room for individual message timestamps.
  ///
  /// Always shows time (오전/오후 h:mm).
  static String formatMessageTime(DateTime dateTime) {
    return _timeFormat.format(dateTime);
  }

  /// Format used for the date divider line between groups of messages.
  ///
  /// e.g. "2025년 3월 15일 토요일"
  static String formatDivider(DateTime dateTime) {
    return _dividerFormat.format(dateTime);
  }

  /// Format used in notification banners / push payloads (brief absolute time).
  ///
  /// - Today    → 오전/오후 h:mm
  /// - Otherwise → M월 d일 오전/오후 h:mm
  static String formatNotification(DateTime dateTime) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final target = _dateOnly(dateTime);

    if (target == today) {
      return _timeFormat.format(dateTime);
    }
    return '${_monthDayFormat.format(dateTime)} ${_timeFormat.format(dateTime)}';
  }

  /// Returns a human-readable "last seen" string for a user's presence.
  ///
  /// - Within 1 minute  → 방금 전
  /// - Within 1 hour    → N분 전
  /// - Today            → 오늘 오전/오후 h:mm
  /// - Yesterday        → 어제 오전/오후 h:mm
  /// - Same year        → M월 d일 오전/오후 h:mm
  /// - Older            → yyyy년 M월 d일 오전/오후 h:mm
  static String formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);

    if (diff.inSeconds < 60) {
      return '방금 전';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}분 전';
    }

    final today = _dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = _dateOnly(lastSeen);
    final timeStr = _timeFormat.format(lastSeen);

    if (target == today) {
      return '오늘 $timeStr';
    } else if (target == yesterday) {
      return '어제 $timeStr';
    } else if (target.year == today.year) {
      return '${_monthDayFormat.format(lastSeen)} $timeStr';
    } else {
      return '${_yearMonthDayFormat.format(lastSeen)} $timeStr';
    }
  }

  /// Returns true if [a] and [b] fall on different calendar days.
  /// Useful for deciding whether to render a date divider between two messages.
  static bool isDifferentDay(DateTime a, DateTime b) {
    return _dateOnly(a) != _dateOnly(b);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}
