import 'package:flutter/material.dart' show TimeOfDay;
import 'package:intl/intl.dart';

/// Shared date / time formatters used across screens.
///
/// All "format..." helpers take an ISO-8601 string (the shape returned
/// by the Laravel backend) and return a display string in the user's
/// local timezone. They tolerate null and unparseable input by
/// returning a sensible fallback so callers don't need extra guards.

/// "MMM d, yyyy h:mm a" — used for absolute timestamps in detail
/// screens (created at, last login, etc.). Returns "Never" for null
/// and the original string when it can't be parsed.
String formatFullDateTime(String? iso) {
  if (iso == null) return 'Never';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return DateFormat('MMM d, yyyy h:mm a').format(dt.toLocal());
}

/// "MMM d, yyyy" — date-only display (e.g., assignment day, deadlines
/// without a time).
String? formatDayDate(String? iso) {
  if (iso == null) return null;
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return DateFormat('MMM d, yyyy').format(dt.toLocal());
}

/// "Due MMM d" — short pill-style deadline label for task list rows.
String formatDeadlineLabel(String dateStr) {
  final date = DateTime.tryParse(dateStr);
  if (date == null) return dateStr;
  return 'Due ${DateFormat('MMM d').format(date)}';
}

/// "just now / 5m / 2h / 3d / MMM d" — relative timestamp used by
/// comment lists. Times older than 6 days fall back to a date label.
String formatRelativeTimestamp(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final local = dt.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return DateFormat('MMM d').format(local);
}

/// Chat-bubble timestamp: same-day messages show "h:mm a", older
/// messages show "MMM d, h:mm a".
String formatChatTimestamp(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final local = dt.toLocal();
  final now = DateTime.now();
  final sameDay = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  if (sameDay) return DateFormat('h:mm a').format(local);
  return DateFormat('MMM d, h:mm a').format(local);
}

/// "yyyy-MM-dd" — Laravel's `date_format:Y-m-d` shape for outgoing
/// payloads. Returns null when the input is null.
String? formatBackendDate(DateTime? date) {
  if (date == null) return null;
  final yyyy = date.year.toString().padLeft(4, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}

/// "HH:mm" — Laravel's `date_format:H:i` shape for outgoing payloads.
/// Returns null when the input is null.
String? formatBackendTime(TimeOfDay? time) {
  if (time == null) return null;
  final hh = time.hour.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
