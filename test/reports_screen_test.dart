import 'dart:convert';

import 'package:ce_tailor_rentals/core/api_client.dart';
import 'package:ce_tailor_rentals/core/session_store.dart';
import 'package:ce_tailor_rentals/features/reports/reports_repository.dart';
import 'package:ce_tailor_rentals/features/reports/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const session = AuthSession(
    token: 'reports-token',
    appId: 'app-123',
    financialYearId: 42,
    financialYearName: '2026-27',
    companyName: 'Studio',
    userName: 'Taylor',
    userRole: 'ADMIN',
  );

  testWidgets('reports menu opens a filtered report table', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const shareChannel = MethodChannel(
      'com.creativeease.ce_tailor_rentals/report_share',
    );
    const printingChannel = MethodChannel('net.nfet.printing');
    Map<Object?, Object?>? shareArguments;
    var printRequested = false;
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      shareArguments = call.arguments as Map<Object?, Object?>;
      final bytes = shareArguments!['bytes'] as List<int>;
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      return null;
    });
    messenger.setMockMethodCallHandler(printingChannel, (call) async {
      if (call.method == 'printingInfo') {
        return {
          'directPrint': false,
          'dynamicLayout': true,
          'canPrint': true,
          'canShare': true,
          'canRaster': true,
        };
      }
      if (call.method == 'printPdf') {
        printRequested = true;
        throw PlatformException(
          code: 'test_print_error',
          message: 'Mock print dialog error',
        );
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(shareChannel, null);
      messenger.setMockMethodCallHandler(printingChannel, null);
    });

    http.Request? activeRentalRequest;
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/api/v1/Transaction/GetCustomersAsync':
            return http.Response(
              '{"errorCode":0,"data":[{"customerID":12,"fullName":"Alex","mobileNo":"9876543210"}]}',
              200,
            );
          case '/api/v1/Transaction/GetAllItemsAsync':
            return http.Response(
              '{"errorCode":0,"data":[{"itemId":21,"itemName":"Shirt"}]}',
              200,
            );
          case '/api/v1/Report/GetActiveRentals':
            activeRentalRequest = request;
            return http.Response(
              '{"errorCode":0,"data":[{"rentNo":"R-1","rentDate":"2026-10-23T00:00:00","customerName":"Alex","rentalVariantAmount":1200,"pendingAmount":200}]}',
              200,
            );
          default:
            return http.Response('{"errorCode":0,"data":[]}', 200);
        }
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReportsScreen(
          session: session,
          repository: ReportsRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active Rentals'), findsOneWidget);

    await tester.tap(find.text('Active Rentals').first);
    await tester.pumpAndSettle();

    expect(find.text('Report filters'), findsOneWidget);
    expect(find.text('Apply filters'), findsOneWidget);
    expect(find.text('Date range'), findsOneWidget);
    expect(find.text('R-1'), findsOneWidget);
    expect(find.text('23-10-2026'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Report data'), findsOneWidget);
    expect(find.text('1 record'), findsOneWidget);
    expect(find.text('Print'), findsOneWidget);
    expect(find.text('Share PDF'), findsOneWidget);
    expect(activeRentalRequest, isNotNull);
    final body = jsonDecode(activeRentalRequest!.body) as Map<String, dynamic>;
    expect(body['menuId'], 38);

    await tester.tap(find.text('Share PDF'));
    await tester.pumpAndSettle();
    expect(shareArguments?['filename'], endsWith('.pdf'));
    expect(shareArguments?['title'], 'Active Rentals');

    await tester.tap(find.text('Print'));
    await tester.pumpAndSettle();
    expect(printRequested, isTrue);
    expect(find.textContaining('Could not print report:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
