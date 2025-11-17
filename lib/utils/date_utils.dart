// lib/utils/date_utils.dart
import 'package:intl/intl.dart';

/// Parse many common date string formats used in this app.
/// Returns DateTime(0) when parsing fails (safe sentinel).
DateTime parseFlexibleDate(String? s) {
  if (s == null) return DateTime.fromMillisecondsSinceEpoch(0);
  final raw = s.trim();
  if (raw.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);

  // 1) ISO fast-path

  // normalize spaces & NBSP
  final normalized = raw
      .replaceAll(RegExp(r'\u00A0'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // 2) Regex for "MM/DD/YYYY, hh:mm AM/PM" (your exact format)
  try {
    final r = RegExp(
      r'^\s*(\d{1,2})/(\d{1,2})/(\d{4})\s*,\s*(\d{1,2}):(\d{2})\s*([AaPp][Mm])\s*$',
    );
    final m = r.firstMatch(normalized);
    if (m != null) {
      final mo = int.parse(m.group(1)!);
      final d = int.parse(m.group(2)!);
      final y = int.parse(m.group(3)!);
      var hour = int.parse(m.group(4)!);
      final minute = int.parse(m.group(5)!);
      final ampm = m.group(6)!.toUpperCase();
      if (ampm == 'PM' && hour < 12) hour += 12;
      if (ampm == 'AM' && hour == 12) hour = 0;
      return DateTime(y, mo, d, hour, minute);
    }
  } catch (_) {}

  // 3) Try "MM/DD/YYYY hh:mm" 24h
  try {
    final r2 = RegExp(
      r'^\s*(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2})\s*$',
    );
    final m2 = r2.firstMatch(normalized);
    if (m2 != null) {
      final mo = int.parse(m2.group(1)!);
      final d = int.parse(m2.group(2)!);
      final y = int.parse(m2.group(3)!);
      final hour = int.parse(m2.group(4)!);
      final minute = int.parse(m2.group(5)!);
      return DateTime(y, mo, d, hour, minute);
    }
  } catch (_) {}

  try {
    return DateTime.parse(raw);
  } catch (_) {}
  // 4) Try a few DateFormat patterns as last attempt
  final patterns = [
    'MM/dd/yyyy, hh:mm a',
    'M/d/yyyy, h:mm a',
    'MM/d/yyyy, h:mm a',
    'M/dd/yyyy, hh:mm a',
    'MM/dd/yyyy h:mm a',
    'M/d/yyyy h:mm a',
    "yyyy-MM-dd'T'HH:mm:ss", // ISO-ish
  ];
  for (final p in patterns) {
    try {
      final dt = DateFormat(p).parse(normalized);
      return dt;
    } catch (_) {}
  }

  // fallback sentinel — prevents crashes downstream
  return DateTime.fromMillisecondsSinceEpoch(0);
}
