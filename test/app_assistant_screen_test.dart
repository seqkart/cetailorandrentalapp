import 'package:ce_tailor_rentals/core/api_client.dart';
import 'package:ce_tailor_rentals/core/session_store.dart';
import 'package:ce_tailor_rentals/features/assistant/app_assistant_screen.dart';
import 'package:ce_tailor_rentals/features/rentals/rental_repository.dart';
import 'package:ce_tailor_rentals/features/tailoring/tailoring_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ce_tailor_rentals/l10n/generated/app_localizations.dart';

void main() {
  const session = AuthSession(
    token: 'assistant-test-token',
    appId: 'app-1',
    financialYearId: 1,
    financialYearName: '2026-27',
    companyName: 'Studio',
    userName: 'Admin',
    userRole: 'ADMIN',
  );

  Widget buildAssistant({
    required VoidCallback onStartTailoringOrder,
    required VoidCallback onOpenTailoringOrders,
    required ValueChanged<int> onOpenRentals,
    required VoidCallback onCreateItem,
    Locale locale = const Locale('en'),
  }) {
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((request) async {
        final path = request.url.path.toLowerCase();
        if (path.contains('getcustomersasync')) {
          return http.Response(
            '{"errorCode":0,"data":[{"customerID":1,"fullName":"Rohit Sharma","mobileNo":"9876543210"}]}',
            200,
          );
        }
        if (path.contains('getallordersasync')) {
          return http.Response(
            '{"errorCode":0,"data":[{"orderID":11,"orderNo":"ORD-26-01","customerName":"Rohit Sharma","status":"Booked"}]}',
            200,
          );
        }
        if (path.contains('getrentbookingsasync') ||
            path.contains('getrentcatalogasync') ||
            path.contains('getallitemsasync')) {
          return http.Response('{"errorCode":0,"data":[]}', 200);
        }
        return http.Response('{"errorCode":0,"data":[]}', 200);
      }),
    );
    return MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: AppAssistantScreen(
        session: session,
        rentalRepository: RentalRepository(api),
        tailoringRepository: TailoringRepository(api),
        onClose: () {},
        onStartTailoringOrder: onStartTailoringOrder,
        onOpenTailoringOrders: onOpenTailoringOrders,
        onOpenRentals: onOpenRentals,
        onCreateItem: onCreateItem,
      ),
    );
  }

  testWidgets('Hindi voice assistant understands a create-item request', (
    WidgetTester tester,
  ) async {
    var openedItemMaster = false;
    await tester.pumpWidget(
      buildAssistant(
        onStartTailoringOrder: () {},
        onOpenTailoringOrders: () {},
        onOpenRentals: (_) {},
        onCreateItem: () => openedItemMaster = true,
        locale: const Locale('hi'),
      ),
    );

    await tester.enterText(find.byType(TextField), 'नया आइटम बनाओ');
    await tester.tap(find.byTooltip('अनुरोध भेजें'));
    await tester.pumpAndSettle();

    expect(find.text('अवा'), findsWidgets);
    expect(find.text('आइटम मास्टर खोलें'), findsOneWidget);
    await tester.tap(find.text('आइटम मास्टर खोलें'));
    expect(openedItemMaster, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Punjabi voice assistant understands a create-item request', (
    WidgetTester tester,
  ) async {
    var openedItemMaster = false;
    await tester.pumpWidget(
      buildAssistant(
        onStartTailoringOrder: () {},
        onOpenTailoringOrders: () {},
        onOpenRentals: (_) {},
        onCreateItem: () => openedItemMaster = true,
        locale: const Locale('pa'),
      ),
    );

    await tester.enterText(find.byType(TextField), 'ਨਵਾਂ ਆਈਟਮ ਬਣਾਓ');
    await tester.tap(find.byTooltip('ਬੇਨਤੀ ਭੇਜੋ'));
    await tester.pumpAndSettle();

    expect(find.text('ਆਈਟਮ ਮਾਸਟਰ ਖੋਲ੍ਹੋ'), findsOneWidget);
    await tester.tap(find.text('ਆਈਟਮ ਮਾਸਟਰ ਖੋਲ੍ਹੋ'));
    expect(openedItemMaster, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create order request offers the existing form without saving', (
    WidgetTester tester,
  ) async {
    var openedOrderForm = false;
    await tester.pumpWidget(
      buildAssistant(
        onStartTailoringOrder: () => openedOrderForm = true,
        onOpenTailoringOrders: () {},
        onOpenRentals: (_) {},
        onCreateItem: () {},
      ),
    );

    await tester.enterText(find.byType(TextField), 'create a tailoring order');
    await tester.tap(find.byTooltip('Send request'));
    await tester.pumpAndSettle();

    expect(find.text('Open new order form'), findsOneWidget);
    expect(openedOrderForm, isFalse);
    await tester.tap(find.text('Open new order form'));
    expect(openedOrderForm, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual search displays matching signed-in app records', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildAssistant(
        onStartTailoringOrder: () {},
        onOpenTailoringOrders: () {},
        onOpenRentals: (_) {},
        onCreateItem: () {},
      ),
    );

    await tester.enterText(find.byType(TextField), 'find customer Rohit');
    await tester.tap(find.byTooltip('Send request'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Found '), findsOneWidget);
    expect(find.text('Rohit Sharma'), findsWidgets);
    expect(find.textContaining('Tailoring order'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'create rental request opens the booking section on confirmation',
    (WidgetTester tester) async {
      var selectedRentalTab = -1;
      await tester.pumpWidget(
        buildAssistant(
          onStartTailoringOrder: () {},
          onOpenTailoringOrders: () {},
          onOpenRentals: (tab) => selectedRentalTab = tab,
          onCreateItem: () {},
        ),
      );

      await tester.enterText(find.byType(TextField), 'start a rental booking');
      await tester.tap(find.byTooltip('Send request'));
      await tester.pumpAndSettle();

      expect(find.text('Open rental booking'), findsOneWidget);
      await tester.tap(find.text('Open rental booking'));
      expect(selectedRentalTab, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('create new item offers the Item Master create action', (
    WidgetTester tester,
  ) async {
    var openedItemMaster = false;
    await tester.pumpWidget(
      buildAssistant(
        onStartTailoringOrder: () {},
        onOpenTailoringOrders: () {},
        onOpenRentals: (_) {},
        onCreateItem: () => openedItemMaster = true,
      ),
    );

    await tester.enterText(find.byType(TextField), 'create new item');
    await tester.tap(find.byTooltip('Send request'));
    await tester.pumpAndSettle();

    expect(find.text('Open Item Master'), findsOneWidget);
    expect(openedItemMaster, isFalse);
    await tester.tap(find.text('Open Item Master'));
    expect(openedItemMaster, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assistant speaks its replies through the device voice channel', (
    WidgetTester tester,
  ) async {
    const channel = MethodChannel(
      'com.creativeease.ce_tailor_rentals/text_to_speech',
    );
    final spoken = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'speak') {
            spoken.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(
      buildAssistant(
        onStartTailoringOrder: () {},
        onOpenTailoringOrders: () {},
        onOpenRentals: (_) {},
        onCreateItem: () {},
      ),
    );
    await tester.enterText(find.byType(TextField), 'create new item');
    await tester.tap(find.byTooltip('Send request'));
    await tester.pumpAndSettle();

    expect(spoken, hasLength(1));
    expect(spoken.single, contains('Open Item Master'));
    expect(tester.takeException(), isNull);
  });
}
