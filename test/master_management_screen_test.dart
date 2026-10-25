import 'dart:convert';

import 'package:ce_tailor_rentals/core/api_client.dart';
import 'package:ce_tailor_rentals/core/session_store.dart';
import 'package:ce_tailor_rentals/features/dashboard/master_management_screen.dart';
import 'package:ce_tailor_rentals/features/rentals/rental_repository.dart';
import 'package:ce_tailor_rentals/features/tailoring/tailoring_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const session = AuthSession(
    token: 'test-token',
    appId: 'app-123',
    financialYearId: 42,
    financialYearName: '2026-27',
    companyName: 'Studio',
    userName: 'Admin',
    userRole: 'ADMIN',
  );

  testWidgets('Item Master form saves item details, not a rental catalogue', (
    tester,
  ) async {
    http.Request? saveRequest;
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/GetAllGroupMstAsync')) {
          return http.Response(
            '{"errorCode":0,"data":[{"groupID":4,"groupName":"Clothing"}]}',
            200,
          );
        }
        if (request.url.path.endsWith('/GetAllUnitsAsync')) {
          return http.Response(
            '{"errorCode":0,"data":[{"unitID":2,"unitName":"Piece"}]}',
            200,
          );
        }
        if (request.url.path.endsWith('/SaveItemAsync')) {
          saveRequest = request;
          return http.Response('{"errorCode":0,"data":{}}', 200);
        }
        return http.Response('{"errorCode":0,"data":[]}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MasterManagementScreen(
          session: session,
          rentalRepository: RentalRepository(api),
          tailoringRepository: TailoringRepository(api),
          kind: MasterKind.items,
          onOpenMenu: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Item Master'), findsOneWidget);
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('master-item-name')), 'Kurta');

    await tester.tap(find.byKey(const Key('master-item-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clothing').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('master-item-unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Piece').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save item'));
    await tester.pumpAndSettle();

    expect(saveRequest, isNotNull);
    expect(saveRequest!.url.path, '/api/v1/Transaction/SaveItemAsync');
    final payload = jsonDecode(saveRequest!.body) as Map<String, dynamic>;
    expect(payload, containsPair('itemId', 0));
    expect(payload, containsPair('itemName', 'Kurta'));
    expect(payload, containsPair('itemRate', 0));
    expect(payload, containsPair('unitId', 2));
    expect(payload, containsPair('groupId', 4));
    expect(payload, containsPair('groupName', 'Clothing'));
    expect(payload, containsPair('isActive', true));
    expect(payload['createdDate'], isA<String>());
    expect(saveRequest!.body, isNot(contains('catalogID')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('group master opens a create form and saves through group API', (
    tester,
  ) async {
    http.Request? saveRequest;
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/SaveGroupMstAsync')) {
          saveRequest = request;
          return http.Response('{"errorCode":0,"data":{}}', 200);
        }
        return http.Response('{"errorCode":0,"data":[]}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MasterManagementScreen(
          session: session,
          rentalRepository: RentalRepository(api),
          tailoringRepository: TailoringRepository(api),
          kind: MasterKind.groups,
          onOpenMenu: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add group'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Formal wear');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saveRequest!.url.path, '/api/v1/Master/SaveGroupMstAsync');
    expect(jsonDecode(saveRequest!.body), {
      'groupID': 0,
      'groupName': 'Formal wear',
      'isActive': true,
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('Item Master can open directly into the add-item form', (
    tester,
  ) async {
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient(
        (_) async => http.Response('{"errorCode":0,"data":[]}', 200),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MasterManagementScreen(
          session: session,
          rentalRepository: RentalRepository(api),
          tailoringRepository: TailoringRepository(api),
          kind: MasterKind.items,
          onOpenMenu: null,
          openCreateOnStart: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Item Master item'), findsOneWidget);
    expect(find.byKey(const Key('master-item-name')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('master assistant action stays in the app bar beside Add', (
    tester,
  ) async {
    var openedAssistant = false;
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient(
        (_) async => http.Response('{"errorCode":0,"data":[]}', 200),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MasterManagementScreen(
          session: session,
          rentalRepository: RentalRepository(api),
          tailoringRepository: TailoringRepository(api),
          kind: MasterKind.items,
          onOpenMenu: null,
          onOpenAssistant: () => openedAssistant = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Ask assistant'), findsOneWidget);
    expect(find.text('Add item'), findsOneWidget);
    final addButton = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(addButton.shape, isA<StadiumBorder>());
    await tester.tap(find.byTooltip('Ask assistant'));
    expect(openedAssistant, isTrue);
    expect(tester.takeException(), isNull);
  });
}
