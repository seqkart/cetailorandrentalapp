import 'package:ce_tailor_rentals/core/api_client.dart';
import 'package:ce_tailor_rentals/core/session_store.dart';
import 'package:ce_tailor_rentals/features/reports/reports_repository.dart';
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

  test('report requests include menu ID and preserve report filters', () async {
    final requests = <http.Request>[];
    final repository = ReportsRepository(
      ApiClient(
        baseUrl: 'https://example.test/api/v1/',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{"errorCode":0,"data":[{"rentNo":"R-1"}]}',
            200,
          );
        }),
      ),
    );

    final result = await repository.load(
      session,
      report: 'GetActiveRentals',
      filters: {
        'fromDate': '2026-10-01',
        'customerId': 12,
        'customerMobileNo': '9876543210',
        'itemId': 21,
      },
    );

    expect(requests.single.url.path, '/api/v1/Report/GetActiveRentals');
    expect(requests.single.headers['Authorization'], 'Bearer reports-token');
    expect(requests.single.body, contains('"menuId":38'));
    expect(requests.single.body, contains('"customerId":12'));
    expect(requests.single.body, contains('"itemId":21'));
    expect(result.rows.single['rentNo'], 'R-1');
  });

  test(
    'ledger and cash flow reports map their summary response shapes',
    () async {
      final repository = ReportsRepository(
        ApiClient(
          baseUrl: 'https://example.test/api/v1/',
          client: MockClient((request) async {
            if (request.url.path.endsWith('GetCustomerLedger')) {
              return http.Response(
                '{"errorCode":0,"entries":[{"voucherNumber":"V-1"}],"summary":{"closingBalance":25}}',
                200,
              );
            }
            return http.Response(
              '{"errorCode":0,"accounts":[{"accountType":"Cash"}],"dailyCashFlow":[{"netFlow":10}]}',
              200,
            );
          }),
        ),
      );

      final ledger = await repository.load(
        session,
        report: 'GetCustomerLedger',
        filters: {'customerID': 12},
      );
      final cashFlow = await repository.load(
        session,
        report: 'GetCashFlowSummary',
        filters: const {},
      );

      expect(ledger.rows.single['voucherNumber'], 'V-1');
      expect(ledger.summary?['closingBalance'], 25);
      expect(cashFlow.rows.single['netFlow'], 10);
      expect(cashFlow.accounts.single['accountType'], 'Cash');
    },
  );

  test('all Angular report endpoints are available', () async {
    final requests = <http.Request>[];
    final repository = ReportsRepository(
      ApiClient(
        baseUrl: 'https://example.test/api/v1/',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"errorCode":0,"data":[]}', 200);
        }),
      ),
    );
    const endpoints = [
      'GetActiveRentals',
      'GetBookingsInHand',
      'GetTailoringOrders',
      'GetRentBookingsPendingTailorAssignment',
      'GetReturnedRentals',
      'GetCustomerLedger',
      'GetCashFlowSummary',
    ];

    for (final endpoint in endpoints) {
      await repository.load(session, report: endpoint, filters: const {});
    }

    expect(
      requests.map((request) => request.url.path.split('/').last),
      endpoints,
    );
    expect(
      requests.every((request) => request.body.contains('"menuId":38')),
      isTrue,
    );
  });
}
