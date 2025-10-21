import 'package:intl/intl.dart';

/// Extensions for DateTime
extension DateTimeExtensions on DateTime {
  /// Format as ISO 8601 string
  String toIso8601() => toUtc().toIso8601String();

  /// Format as timestamp (seconds since epoch)
  int toTimestamp() => millisecondsSinceEpoch ~/ 1000;

  /// Format as human-readable string
  String toHumanReadable() => DateFormat('yyyy-MM-dd HH:mm:ss').format(this);

  /// Format as relative time (e.g., "2 hours ago")
  String toRelative() {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = difference.inDays ~/ 7;
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = difference.inDays ~/ 30;
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = difference.inDays ~/ 365;
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }
}

/// Extensions for int (timestamps)
extension TimestampExtensions on int {
  /// Convert timestamp to DateTime
  DateTime toDateTime() => DateTime.fromMillisecondsSinceEpoch(this * 1000);
}
