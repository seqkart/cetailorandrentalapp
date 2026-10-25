import 'package:ce_tailor_rentals/core/api_client.dart';
import 'package:ce_tailor_rentals/core/session_store.dart';
import 'package:ce_tailor_rentals/features/tailoring/tailoring_repository.dart';
import 'package:ce_tailor_rentals/features/tailoring/tailoring_workflow_screen.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const session = AuthSession(
    token: 'tailor-token',
    appId: 'app-123',
    financialYearId: 42,
    financialYearName: '2026-27',
    companyName: 'Studio',
    userName: 'Taylor',
    userRole: 'TAILOR',
  );

  testWidgets('tailoring workspace opens the stitching order form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((request) async {
        final response =
            request.url.path.endsWith('GetAllReadyForPrefitOrdersAsync')
            ? '{"errorCode":0,"orders":[]}'
            : '{"errorCode":0,"data":[]}';
        return http.Response(response, 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TailoringWorkflowScreen(
          session: session,
          repository: TailoringRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tailoring transactions'), findsOneWidget);
    await tester.tap(find.text('New order').first);
    await tester.pumpAndSettle();

    expect(find.text('Create stitching order'), findsOneWidget);
    expect(find.text('Customer *'), findsOneWidget);
    expect(find.text('Stitching items'), findsOneWidget);
    expect(find.text('Payment & notes'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stitching order save sends a JSON-encodable numeric rate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    http.Request? saveRequest;
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((request) async {
        final path = request.url.path.toLowerCase();
        if (path.endsWith('getcustomersasync')) {
          return http.Response(
            '{"errorCode":0,"data":[{"customerID":11,"fullName":"Alex Tailor","mobileNo":"9876543210"}]}',
            200,
          );
        }
        if (path.endsWith('getallitemsasync')) {
          return http.Response(
            '{"errorCode":0,"data":[{"itemId":21,"itemName":"Shirt","itemRate":1250,"groupId":31}]}',
            200,
          );
        }
        if (path.endsWith('getallsizesasync')) {
          return http.Response(
            '{"errorCode":0,"data":[{"sizeID":41,"sizeName":"M"}]}',
            200,
          );
        }
        if (path.endsWith('getallcolorasync')) {
          return http.Response(
            '{"errorCode":0,"data":[{"colorID":51,"colorName":"Blue"}]}',
            200,
          );
        }
        if (path.endsWith('getallprocessesasync')) {
          return http.Response(
            '{"errorCode":0,"data":[{"processID":61,"processName":"Stitching"}]}',
            200,
          );
        }
        if (path.endsWith('getalltailorsasync')) {
          return http.Response('{"errorCode":0,"data":[]}', 200);
        }
        if (path.endsWith('getvoucherseriesasync')) {
          return http.Response(
            '{"errorCode":0,"data":[{"voucherSeriesID":71,"voucherSeriesName":"Stitching","isCurrent":true}]}',
            200,
          );
        }
        if (path.endsWith('getallreadyforprefitordersasync')) {
          return http.Response('{"errorCode":0,"orders":[]}', 200);
        }
        if (path.endsWith('saveorderasync')) {
          saveRequest = request;
          return http.Response('{"errorCode":0,"data":{}}', 200);
        }
        return http.Response('{"errorCode":0,"data":[]}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TailoringWorkflowScreen(
          session: session,
          repository: TailoringRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New order').first);
    await tester.pumpAndSettle();

    Future<void> choose(int index, String option) async {
      final field = find.byType(DropdownButtonFormField<int>).at(index);
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    await choose(0, 'Stitching');
    await choose(1, 'Alex Tailor · 9876543210');
    await tester.enterText(find.byType(TextFormField).at(0), '9876543210');
    await tester.enterText(find.byType(TextFormField).at(1), 'Alex Tailor');
    await choose(2, 'Shirt');
    await choose(3, 'M');
    await choose(4, 'Blue');
    await choose(5, 'Stitching');

    final rateField = find.byType(TextFormField).at(6);
    await tester.ensureVisible(rateField);
    await tester.enterText(rateField, '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Save order'));
    await tester.pumpAndSettle();

    expect(find.text('Amount must be greater than 0'), findsOneWidget);
    expect(saveRequest, isNull);

    await tester.enterText(rateField, '1250');
    await tester.tap(find.widgetWithText(FilledButton, 'Save order'));
    await tester.pumpAndSettle();

    expect(saveRequest, isNotNull);
    final payload = jsonDecode(saveRequest!.body) as Map<String, dynamic>;
    final item = (payload['orderDetails'] as List).single as Map;
    expect(item['rate'], 1250);
    expect(item['rate'], isA<num>());
    expect(item['amount'], 1250);
    expect(item['discountAmount'], 0);
    expect(item['netAmount'], 1250);
    expect(item['amount'], greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('invoice save sends Angular-compatible payment details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    http.Request? invoiceRequest;
    var invoiceGenerated = false;
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((request) async {
        final path = request.url.path.toLowerCase();
        if (path.endsWith('getorderbyidasync')) {
          return http.Response(
            '{"errorCode":0,"data":{"orderID":5,"orderNo":"ORD-5","customerName":"Alex Tailor","orderDetails":[{"detailID":7,"status":"Approved","itemName":"Shirt","sizeName":"M","colorName":"Blue","netAmount":1250} ]}}',
            200,
          );
        }
        if (path.endsWith('generateinvoiceasync')) {
          invoiceRequest = request;
          invoiceGenerated = true;
          return http.Response('{"errorCode":0,"data":{}}', 200);
        }
        if (path.endsWith('getallinvoicesasync') && invoiceGenerated) {
          return http.Response(
            '{"errorCode":0,"data":[{"invoiceNo":"INV-2026-10-0001","customerName":"Alex Tailor","invoiceDate":"2026-10-23","totalAmount":1250}]}',
            200,
          );
        }
        return http.Response('{"errorCode":0,"data":[]}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TailoringWorkflowScreen(
          session: session,
          repository: TailoringRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Invoice list').first);
    await tester.tap(find.text('Invoice list').first);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(TabBar), matching: find.text('Invoice')),
      findsNothing,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Invoice'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'ITEM-7');
    await tester.tap(find.byIcon(Icons.search).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Invoice · ORD-5'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '500');
    await tester.tap(find.widgetWithText(FilledButton, 'Generate invoice'));
    await tester.pumpAndSettle();

    expect(invoiceRequest, isNotNull);
    final payload = jsonDecode(invoiceRequest!.body) as Map<String, dynamic>;
    expect(payload['orderDetailIds'], [7]);
    final paymentWrapper = (payload['paymentDetails'] as List).single;
    expect(paymentWrapper['bookingAmount'], 500);
    expect(paymentWrapper['securityDeposit'], 0);
    final payment = (paymentWrapper['payments'] as List).single;
    expect(payment['paymentMode'], 'CASH');
    expect(payment['totalAmount'], 500);
    expect(payment['paymentDetailID'], 0);
    expect(payment.containsKey('amount'), isFalse);
    expect(find.text('Invoice list'), findsWidgets);
    expect(find.text('INV-2026-10-0001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
