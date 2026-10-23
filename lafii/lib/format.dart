const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsLong = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
}

/// Saturday, 17th Oct
String longDay(DateTime d) => '${_days[d.weekday - 1]}, ${ordinal(d.day)} ${_months[d.month - 1]}';

/// 17th Oct, 2026
String dayMonthYear(DateTime d) => '${ordinal(d.day)} ${_months[d.month - 1]}, ${d.year}';

/// 10:14 am
String clock(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'am' : 'pm'}';
}

String monthName(int m) => _monthsLong[m - 1];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int daysBetween(DateTime from, DateTime to) =>
    dateOnly(to).difference(dateOnly(from)).inDays;

/// "Today", "1 day", "4 days" for elapsed time. Plain text only (7.4).
String elapsedDays(DateTime since, DateTime now) {
  final n = daysBetween(since, now);
  if (n <= 0) return 'Today';
  return n == 1 ? '1 day' : '$n days';
}

/// "Today", "Tomorrow", weekday name within the week, else the date.
String dueWhen(DateTime due, DateTime now) {
  final n = daysBetween(now, due);
  if (n < 0) return 'Overdue';
  if (n == 0) return 'Today';
  if (n == 1) return 'Tomorrow';
  if (n < 7) return _days[due.weekday - 1].substring(0, 3);
  return '${ordinal(due.day)} ${_months[due.month - 1]}';
}

/// Digits and a leading +, as typed. Null when it is not a plausible number.
String? cleanPhone(String s) {
  final t = s.replaceAll(RegExp(r'[\s\-()]'), '');
  if (!RegExp(r'^\+?\d{9,15}$').hasMatch(t)) return null;
  return t;
}

/// "0244174417" to "024 417 4417". Other lengths are returned as stored.
String showPhone(String p) =>
    RegExp(r'^0\d{9}$').hasMatch(p) ? '${p.substring(0, 3)} ${p.substring(3, 6)} ${p.substring(6)}' : p;

/// Formats a number without a trailing .0
String num1(num v) =>
    v is double && v != v.roundToDouble() ? v.toStringAsFixed(1) : '${v.round()}';
