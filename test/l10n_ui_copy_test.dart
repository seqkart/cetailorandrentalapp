import 'package:ce_tailor_rentals/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared screen copy follows Hindi and Punjabi locales', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hi'),
        supportedLocales: const [Locale('en'), Locale('hi'), Locale('pa')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Text(localizedUiText(context, 'Save order')),
        ),
      ),
    );
    expect(find.text('ऑर्डर सेव करें'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pa'),
        supportedLocales: const [Locale('en'), Locale('hi'), Locale('pa')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Text(localizedUiText(context, 'Save order')),
        ),
      ),
    );
    expect(find.text('ਆਰਡਰ ਸੇਵ ਕਰੋ'), findsOneWidget);
  });
}
