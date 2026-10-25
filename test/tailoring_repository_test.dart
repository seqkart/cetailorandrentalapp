import 'dart:convert';

import 'package:ce_tailor_rentals/core/api_client.dart';
import 'package:ce_tailor_rentals/core/session_store.dart';
import 'package:ce_tailor_rentals/features/tailoring/tailoring_repository.dart';
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
    userName: 'Taylor',
    userRole: 'TAILOR',
  );

  test('orders list uses the Angular menu query and date payload', () async {
    late http.Request request;
    final repository = TailoringRepository(
      ApiClient(
        baseUrl: 'https://example.test/api/v1/',
        client: MockClient((value) async {
          request = value;
          return http.Response('{"errorCode":0,"data":[]}', 200);
        }),
      ),
    );

    await repository.loadOrders(
      session,
      fromDate: '01-06-2026',
      toDate: '08-06-2026',
    );

    expect(request.url.path, '/api/v1/Transaction/GetAllOrdersAsync');
    expect(request.url.queryParameters['MenuId'], '38');
    expect(jsonDecode(request.body), {
      'fromDate': '01-06-2026',
      'toDate': '08-06-2026',
    });
  });

  test('saves process master through the Angular master endpoint', () async {
    late http.Request request;
    final repository = TailoringRepository(
      ApiClient(
        baseUrl: 'https://example.test/api/v1/',
        client: MockClient((value) async {
          request = value;
          return http.Response('{"errorCode":0,"message":"saved"}', 200);
        }),
      ),
    );

    await repository.saveProcess(session, const {
      'processID': 0,
      'processName': 'Stitching',
      'processDescription': '',
      'isActive': true,
    });

    expect(request.url.path, '/api/v1/Master/SaveProcessAsync');
    expect(jsonDecode(request.body), {
      'processID': 0,
      'processName': 'Stitching',
      'processDescription': '',
      'isActive': true,
    });
    expect(request.headers['authorization'], contains(session.token));
  });

  test('all-orders status uses the financial year payload', () async {
    late http.Request request;
    final repository = TailoringRepository(
      ApiClient(
        baseUrl: 'https://example.test/api/v1/',
        client: MockClient((value) async {
          request = value;
          return http.Response('{"errorCode":0,"data":[]}', 200);
        }),
      ),
    );

    await repository.loadOrdersByType(session, status: 'Booked');

    expect(request.url.path, '/api/v1/Transaction/GetAllOrdersAsync');
    expect(request.url.query, isEmpty);
    expect(jsonDecode(request.body), {'finYearID': 42, 'status': 'Booked'});
  });

  test(
    'today status submits the date range without a financial year',
    () async {
      late http.Request request;
      final repository = TailoringRepository(
        ApiClient(
          baseUrl: 'https://example.test/api/v1/',
          client: MockClient((value) async {
            request = value;
            return http.Response('{"errorCode":0,"data":[]}', 200);
          }),
        ),
      );

      await repository.loadOrdersByType(
        session,
        status: 'Today',
        fromDate: '08-06-2026',
        toDate: '08-06-2026',
      );

      expect(jsonDecode(request.body), {
        'fromDate': '08-06-2026',
        'toDate': '08-06-2026',
      });
    },
  );
}
