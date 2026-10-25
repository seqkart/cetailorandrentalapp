import 'package:ce_tailor_rentals/core/app_date_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats dates as dd-MM-yyyy', () {
    expect(formatDisplayDate(DateTime(2026, 10, 3)), '03-10-2026');
    expect(formatDateValue('2026-10-23T00:00:00'), '23-10-2026');
    expect(formatDateValue('3/10/2026'), '03-10-2026');
  });

  test('parses displayed day-first dates and rejects invalid dates', () {
    expect(parseDateValue('03-10-2026'), DateTime(2026, 10, 3));
    expect(parseDateValue('31-02-2026'), isNull);
    expect(parseDateValue('not a date'), isNull);
  });
}
