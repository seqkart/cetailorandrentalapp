String formatDisplayDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.year.toString().padLeft(4, '0')}';

DateTime? parseDateValue(Object? value) {
  if (value is DateTime) return value;
  if (value == null) return null;

  final text = value.toString().trim();
  if (text.isEmpty) return null;

  final dayFirst = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})(?:$|[ T])')
      .firstMatch(text);
  if (dayFirst != null) {
    final day = int.parse(dayFirst.group(1)!);
    final month = int.parse(dayFirst.group(2)!);
    final year = int.parse(dayFirst.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year == year && parsed.month == month && parsed.day == day) {
      return parsed;
    }
    return null;
  }

  return DateTime.tryParse(text);
}

String? formatDateValue(Object? value) {
  final parsed = parseDateValue(value);
  return parsed == null ? null : formatDisplayDate(parsed);
}

bool isDateField(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return normalized.contains('date') ||
      normalized.endsWith('on') ||
      normalized.endsWith('at');
}
