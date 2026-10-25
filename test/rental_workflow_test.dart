import 'dart:convert';

import 'package:ce_tailor_rentals/core/api_client.dart';
import 'package:ce_tailor_rentals/core/session_store.dart';
import 'package:ce_tailor_rentals/features/dashboard/administration_repository.dart';
import 'package:ce_tailor_rentals/features/dashboard/dashboard_repository.dart';
import 'package:ce_tailor_rentals/features/dashboard/dashboard_screen.dart';
import 'package:ce_tailor_rentals/features/rentals/rental_repository.dart';
import 'package:ce_tailor_rentals/features/rentals/rental_workflow_screen.dart';
import 'package:ce_tailor_rentals/features/reports/reports_repository.dart';
import 'package:ce_tailor_rentals/features/tailoring/tailoring_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const session = AuthSession(
    token: 'rental-token',
    appId: 'app-123',
    financialYearId: 42,
    financialYearName: '2026-27',
    companyName: 'Studio',
    userName: 'Rental User',
    userRole: 'RENTAL',
  );

  testWidgets('rental catalog cart and booking submit use selected dates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? bookingPayload;
    final requests = <http.Request>[];
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((request) async {
        requests.add(request);
        switch (request.url.path) {
          case '/api/v1/transaction/GetCustomersAsync':
            return http.Response(
              '{"errorCode":0,"data":[{"customerID":8,"fullName":"Asha","mobileNo":"9876543210"}]}',
              200,
            );
          case '/api/v1/Master/GetVoucherSeriesAsync':
            return http.Response(
              '{"errorCode":0,"data":[{"voucherSeriesID":3,"isCurrent":true}]}',
              200,
            );
          case '/api/v1/transaction/GetRentCatalogAsync':
            return http.Response(
              '{"errorCode":0,"data":[{"catalogID":12,"itemId":21,"itemCode":"DR-1","itemName":"Blue Dress","groupName":"Gowns","securityDeposit":500,"variants":[{"variantID":7,"sizeID":2,"sizeName":"M","colorID":4,"colorName":"Blue","availableQty":2,"rentRate":750}]}]}',
              200,
            );
          case '/api/v1/Transaction/SaveRentBookingAsync':
            bookingPayload = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              '{"errorCode":0,"message":"Booking saved","bookingID":54}',
              200,
            );
          default:
            return http.Response('{"errorCode":0,"data":[]}', 200);
        }
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RentalWorkflowScreen(
          session: session,
          repository: RentalRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Find available items'));
    await tester.pumpAndSettle();
    expect(find.text('Blue Dress'), findsOneWidget);
    expect(find.text('2 available'), findsOneWidget);

    await tester.ensureVisible(find.text('Add to cart'));
    await tester.tap(find.text('Add to cart'));
    await tester.pumpAndSettle();
    expect(find.text('View cart'), findsOneWidget);
    expect(find.byTooltip('Increase quantity'), findsOneWidget);
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pumpAndSettle();
    expect(find.text('2 item(s) in cart'), findsOneWidget);
    await tester.tap(find.byTooltip('Decrease quantity'));
    await tester.pumpAndSettle();
    expect(find.text('1 item(s) in cart'), findsOneWidget);
    await tester.tap(find.text('View cart'));
    await tester.pumpAndSettle();

    expect(find.text('Complete your booking'), findsOneWidget);
    expect(find.text('Your cart'), findsOneWidget);
    await tester.tap(find.text('Search by customer name or mobile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Asha');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asha').last);
    await tester.pumpAndSettle();

    final paidField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Advance payment collected',
    );
    await tester.enterText(paidField, '100');
    await tester.ensureVisible(find.text('Confirm rental booking'));
    await tester.tap(find.text('Confirm rental booking'));
    await tester.pumpAndSettle();

    expect(bookingPayload?['customerID'], 8);
    expect(bookingPayload?['finYearID'], 42);
    expect(bookingPayload?['voucherSeriesId'], 3);
    expect(bookingPayload?['totalAmount'], 750);
    expect(bookingPayload?['bookingAmount'], 100);
    expect(bookingPayload?['securityDeposit'], 500);
    expect(bookingPayload?['securityDepositStatus'], 'Unpaid');
    expect(bookingPayload?['status'], 'Booked');
    expect(bookingPayload?['bookingDetails'], [
      {
        'bookingDetailID': 0,
        'catalogID': 12,
        'variantID': 7,
        'itemId': 21,
        'sizeID': 2,
        'colorID': 4,
        'qty': 1,
        'rate': 750,
        'remarks': '',
        'measurements': [],
        'assignedToTailorId': null,
      },
    ]);
    expect(bookingPayload?['bookingPayments'], hasLength(1));
    expect(
      jsonDecode(
        requests
            .firstWhere(
              (request) =>
                  request.url.path == '/api/v1/transaction/GetRentCatalogAsync',
            )
            .body,
      ),
      containsPair('fromDate', isA<String>()),
    );
    expect(find.text('Booking saved'), findsOneWidget);
  });

  testWidgets('creates an item and availability variant in the catalogue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? itemPayload;
    Map<String, dynamic>? catalogPayload;
    Map<String, dynamic>? sizePayload;
    Map<String, dynamic>? colorPayload;
    Map<String, dynamic>? groupPayload;
    var sizeCreated = false;
    var colorCreated = false;
    var groupCreated = false;
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/api/v1/Master/GetVoucherSeriesAsync':
            return http.Response('{"errorCode":0,"data":[]}', 200);
          case '/api/v1/Master/GetAllMeasurementsAsync':
          case '/api/v1/Master/GetAllTailorsAsync':
            return http.Response('{"errorCode":0,"data":[]}', 200);
          case '/api/v1/Master/GetAllSizesAsync':
            return http.Response(
              jsonEncode({
                'errorCode': 0,
                'data': sizeCreated
                    ? [
                        {'sizeID': 6, 'sizeName': 'Tall'},
                      ]
                    : [],
              }),
              200,
            );
          case '/api/v1/Master/GetAllColorAsync':
            return http.Response(
              jsonEncode({
                'errorCode': 0,
                'data': colorCreated
                    ? [
                        {'colorID': 7, 'colorName': 'Teal'},
                      ]
                    : [],
              }),
              200,
            );
          case '/api/v1/Master/GetAllGroupMstAsync':
            return http.Response(
              jsonEncode({
                'errorCode': 0,
                'data': groupCreated
                    ? [
                        {
                          'groupID': 5,
                          'groupName': 'Traditional wear',
                          'isActive': true,
                        },
                      ]
                    : [],
              }),
              200,
            );
          case '/api/v1/Master/GetAllUnitsAsync':
            return http.Response(
              '{"errorCode":0,"data":[{"unitID":3,"unitName":"Piece"}]}',
              200,
            );
          case '/api/v1/Transaction/GetAllItemsAsync':
            return http.Response('{"errorCode":0,"data":[]}', 200);
          case '/api/v1/Master/SaveGroupMstAsync':
            groupCreated = true;
            groupPayload = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response('{"errorCode":0,"message":"saved"}', 200);
          case '/api/v1/Master/SaveSizeAsync':
            sizeCreated = true;
            sizePayload = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              '{"errorCode":1,"message":"Size already exist"}',
              200,
            );
          case '/api/v1/Master/SaveColorAsync':
            colorCreated = true;
            colorPayload = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response('{"errorCode":0,"message":"saved"}', 200);
          case '/api/v1/Transaction/SaveItemAsync':
            itemPayload = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response('{"errorCode":0,"data":{"itemId":88}}', 200);
          case '/api/v1/Transaction/SaveRentCatalogAsync':
            catalogPayload = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              '{"errorCode":0,"message":"Catalogue item saved"}',
              200,
            );
          case '/api/v1/transaction/GetRentCatalogAsync':
            return http.Response('{"errorCode":0,"data":[]}', 200);
          default:
            return http.Response('{"errorCode":0,"data":[]}', 200);
        }
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RentalWorkflowScreen(
          session: session,
          repository: RentalRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add item to Item Master'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Item name *'),
      'Green Dress',
    );
    await tester.tap(find.byTooltip('Add group'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Group name'),
      'Traditional wear',
    );
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unit *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Piece').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Item rate *'),
      '250',
    );
    await tester.tap(find.text('Save item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add size'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Size name'), 'Tall');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add colour'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Colour name'),
      'Teal',
    );
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Total qty *'),
      '3',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Rent rate *'),
      '800',
    );
    expect(find.text('From files'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    await tester.tap(find.text('Create catalogue item'));
    await tester.pumpAndSettle();

    expect(itemPayload?['itemName'], 'Green Dress');
    expect(itemPayload?['groupId'], 5);
    expect(itemPayload?['groupName'], 'Traditional wear');
    expect(itemPayload?['unitId'], 3);
    expect(itemPayload?['itemRate'], 250);
    expect(groupPayload, {
      'groupID': 0,
      'groupName': 'Traditional wear',
      'isActive': true,
    });
    expect(sizePayload, {'sizeID': 0, 'sizeName': 'Tall', 'isActive': true});
    expect(colorPayload, {'colorID': 0, 'colorName': 'Teal'});
    expect(catalogPayload?['itemId'], 88);
    expect(catalogPayload?['baseRentRate'], 0);
    expect(catalogPayload?['securityDeposit'], 0);
    expect(catalogPayload?['variants'], [
      {
        'variantID': 0,
        'sizeID': 6,
        'colorID': 7,
        'totalQty': 3,
        'rentRate': 800,
        'isActive': true,
        'photos': [],
      },
    ]);
    expect(find.text('Base rent rate'), findsNothing);
    expect(find.text('Security deposit'), findsNothing);
    expect(find.text('Green Dress added to rental catalogue.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking delivery and item return submit Angular lifecycle data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var delivered = false;
    Map<String, dynamic>? deliveryPayload;
    Map<String, dynamic>? returnPayload;
    final dueDate = DateTime.now()
        .add(const Duration(days: 5))
        .toIso8601String();
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/api/v1/transaction/GetCustomersAsync':
            return http.Response('{"errorCode":0,"data":[]}', 200);
          case '/api/v1/Master/GetVoucherSeriesAsync':
            return http.Response(
              '{"errorCode":0,"data":[{"voucherSeriesID":3,"isCurrent":true}]}',
              200,
            );
          case '/api/v1/transaction/GetRentBookingsAsync':
            return http.Response(
              jsonEncode({
                'errorCode': 0,
                'data': [
                  {
                    'bookingID': 54,
                    'bookingNo': 'RB-54',
                    'customerName': 'Asha',
                    'customerMobile': '9876543210',
                    'fromDate': dueDate,
                    'toDate': dueDate,
                    'totalAmount': 750,
                    'status': delivered ? 'Delivered' : 'Booked',
                    'rentID': delivered ? 91 : null,
                    'securityDeposit': 100,
                  },
                ],
              }),
              200,
            );
          case '/api/v1/Transaction/ConvertRentBookingToRentAsync':
            deliveryPayload = jsonDecode(request.body) as Map<String, dynamic>;
            delivered = true;
            return http.Response('{"errorCode":0,"rentID":91}', 200);
          case '/api/v1/Transaction/GetRentByMobileAsync':
            return http.Response(
              jsonEncode({
                'errorCode': 0,
                'data': [
                  {
                    'rentID': 91,
                    'rentNo': 'R-91',
                    'customerName': 'Asha',
                    'customerMobile': '9876543210',
                    'returnDate': dueDate,
                    'pendingAmount': 25,
                    'securityDeposit': 0,
                    'rentDetails': [
                      {
                        'detailID': 111,
                        'itemId': 21,
                        'itemName': 'Blue Dress',
                        'sizeName': 'M',
                        'colorName': 'Blue',
                        'qty': 1,
                        'rate': 750,
                        'status': 'Delivered',
                        'returnDate': dueDate,
                      },
                    ],
                  },
                ],
              }),
              200,
            );
          case '/api/v1/Transaction/SaveRentReturnAsync':
            returnPayload = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              '{"errorCode":0,"message":"Return saved"}',
              200,
            );
          default:
            return http.Response('{"errorCode":0,"data":[]}', 200);
        }
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RentalWorkflowScreen(
          session: session,
          repository: RentalRepository(api),
          initialTab: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deliver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm delivery'));
    await tester.pumpAndSettle();
    expect(deliveryPayload?['bookingID'], 54);
    expect(deliveryPayload?['voucherSeriesID'], 3);
    expect(find.text('Delivered'), findsOneWidget);

    await tester.tap(find.text('Returns'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Customer mobile number',
      ),
      '9876543210',
    );
    await tester.tap(find.text('Find active rentals'));
    await tester.pumpAndSettle();
    expect(find.text('R-91'), findsOneWidget);
    await tester.ensureVisible(find.text('Save return'));
    await tester.tap(find.text('Save return'));
    await tester.pumpAndSettle();

    expect(returnPayload?['voucherSeriesId'], 3);
    expect(returnPayload?['rentReturnDetails'], [
      {
        'menuId': 0,
        'detailID': 111,
        'itemId': 21,
        'returnQty': 1,
        'status': 'Returned',
        'damageAmount': 0.0,
        'lateAmount': 0.0,
        'otherCharges': 0.0,
        'remarks': '',
        'rentItemPhotos': [],
      },
    ]);
    expect(returnPayload?['rentReturnPayments'], hasLength(1));
    expect(find.text('Rental return saved.'), findsOneWidget);
  });

  testWidgets('creates a missing customer and saves per-item alterations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var customerCreated = false;
    Map<String, dynamic>? bookingPayload;
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/api/v1/transaction/GetCustomersAsync':
            return http.Response(
              jsonEncode({
                'errorCode': 0,
                'data': customerCreated
                    ? [
                        {
                          'customerID': 12,
                          'fullName': 'New Customer',
                          'mobileNo': '9876543210',
                        },
                      ]
                    : [],
              }),
              200,
            );
          case '/api/v1/Master/GetVoucherSeriesAsync':
            return http.Response(
              '{"errorCode":0,"data":[{"voucherSeriesID":3,"isCurrent":true}]}',
              200,
            );
          case '/api/v1/Master/GetAllMeasurementsAsync':
            return http.Response(
              '{"errorCode":0,"data":[{"measurementID":5,"measurementName":"Chest"}]}',
              200,
            );
          case '/api/v1/Master/GetAllTailorsAsync':
            return http.Response(
              '{"errorCode":0,"data":[{"employeeID":6,"fullName":"Ravi Tailor","isActive":true}]}',
              200,
            );
          case '/api/v1/transaction/GetRentCatalogAsync':
            return http.Response(
              '{"errorCode":0,"data":[{"catalogID":12,"itemId":21,"itemCode":"DR-1","itemName":"Blue Dress","securityDeposit":500,"variants":[{"variantID":7,"sizeID":2,"sizeName":"M","colorID":4,"colorName":"Blue","availableQty":2,"rentRate":750}]}]}',
              200,
            );
          case '/api/v1/Transaction/SaveCustomerAsync':
            customerCreated = true;
            return http.Response('{"errorCode":0,"customerID":12}', 200);
          case '/api/v1/Transaction/SaveRentBookingAsync':
            bookingPayload = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              '{"errorCode":0,"message":"Booking saved"}',
              200,
            );
          default:
            return http.Response('{"errorCode":0,"data":[]}', 200);
        }
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RentalWorkflowScreen(
          session: session,
          repository: RentalRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find available items'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to cart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View cart'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search by customer name or mobile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '9876543210');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add customer • 9876543210'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Full name *',
      ),
      'New Customer',
    );
    await tester.tap(find.text('Save customer'));
    await tester.pumpAndSettle();
    expect(customerCreated, isTrue);
    expect(find.textContaining('New Customer'), findsOneWidget);

    await tester.ensureVisible(find.text('Alteration required'));
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add measurements & assign tailor'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byType(DropdownButtonFormField<Map<String, dynamic>>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ravi Tailor').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Chest');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chest').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '38');
    await tester.tap(find.text('Save item alteration'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Confirm rental booking'));
    await tester.tap(find.text('Confirm rental booking'));
    await tester.pumpAndSettle();
    expect(bookingPayload?['customerID'], 12);
    expect(bookingPayload?['isAlterationRequired'], isTrue);
    expect(bookingPayload?['bookingDetails'], [
      containsPair('assignedToTailorId', 6),
    ]);
    expect((bookingPayload?['bookingDetails'] as List).single['measurements'], [
      {
        'measurementMapId': 5,
        'measurementName': 'Chest',
        'measurementValue': 38,
      },
    ]);
  });

  testWidgets('dashboard Rentals destination opens rental workspace', (
    tester,
  ) async {
    const adminSession = AuthSession(
      token: 'admin-token',
      appId: 'app-123',
      financialYearId: 42,
      financialYearName: '2026-27',
      companyName: 'Studio',
      userName: 'Admin',
      userRole: 'ADMIN',
    );
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient(
        (_) async => http.Response('{"errorCode":0,"data":[]}', 200),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          session: adminSession,
          repository: DashboardRepository(api),
          rentalRepository: RentalRepository(api),
          reportsRepository: ReportsRepository(api),
          tailoringRepository: TailoringRepository(api),
          administrationRepository: AdministrationRepository(api),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rental').last);
    await tester.pumpAndSettle();

    expect(find.text('Rental workspace'), findsOneWidget);
    expect(find.text('Catalogue'), findsOneWidget);
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Business overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
