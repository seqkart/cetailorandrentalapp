import 'package:ce_tailor_rentals/splash/animated_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('splash transitions even when its animation ticker is disabled', (
    tester,
  ) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TickerMode(
          enabled: false,
          child: AnimatedSplash(onFinished: () => finished = true),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 6));

    expect(finished, isTrue);
    expect(tester.takeException(), isNull);
  });
}
