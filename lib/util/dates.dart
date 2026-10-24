import '../models/service_stint.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';
String fullDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
String rangeLabel(DateRange r) => '${monthYear(r.start)} – ${monthYear(r.end)}';

String durationLabel(int days) {
  if (days < 60) return '$days days';
  final months = (days / 30.44).round();
  if (months < 24) return '$months months';
  return '${(days / 365.25).toStringAsFixed(1)} years';
}
