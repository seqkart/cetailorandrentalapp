import 'dart:convert';

import 'package:ce_tailor_rentals/core/api_client.dart';
import 'package:ce_tailor_rentals/core/session_store.dart';
import 'package:ce_tailor_rentals/features/dashboard/administration_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const session = AuthSession(
    token: 'admin-token',
    appId: 'app-123',
    financialYearId: 42,
    financialYearName: '2026-27',
    companyName: 'Studio',
    userName: 'Admin',
    userRole: 'ADMIN',
  );

  test(
    'customer create, update, list, and delete use documented endpoints',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'https://example.test/api/v1/',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"errorCode":0,"data":[]}', 200);
        }),
      );
      final repository = AdministrationRepository(api);

      await repository.loadCustomers(session);
      await repository.saveCustomer(session, const {
        'customerID': 0,
        'fullName': 'Asha',
        'mobileNo': '9876543210',
      });
      await repository.deleteCustomer(session, 17);

      expect(requests.map((request) => request.method), [
        'POST',
        'POST',
        'DELETE',
      ]);
      expect(requests.map((request) => request.url.path), [
        '/api/v1/Transaction/GetCustomersAsync',
        '/api/v1/Transaction/SaveCustomerAsync',
        '/api/v1/Transaction/DeleteCustomerByIdAsync',
      ]);
      expect(jsonDecode(requests[0].body), {
        'menuId': 38,
        'isActive': null,
        'mobileNo': null,
        'customerName': null,
      });
      expect(jsonDecode(requests[1].body), {
        'menuId': 38,
        'customerID': 0,
        'fullName': 'Asha',
        'mobileNo': '9876543210',
      });
      expect(requests[2].url.queryParameters['customerID'], '17');
    },
  );

  test(
    'users, roles, permissions, and company use their API contracts',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'https://example.test/api/v1/',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"errorCode":0,"data":[]}', 200);
        }),
      );
      final repository = AdministrationRepository(api);

      await repository.loadUsers(session);
      await repository.loadRoles(session);
      await repository.saveUser(session, const {'userID': 4, 'menuId': 0});
      await repository.loadMenus(session);
      await repository.loadUserPermissions(session, 4);
      await repository.savePermissions(session, 4, const [
        {'menuId': 12, 'access': true},
      ]);
      await repository.loadCompany(session);
      await repository.saveCompany(session, const {'companyID': 1});

      expect(requests.map((request) => request.url.path), [
        '/api/v1/Master/GetAllUsers',
        '/api/v1/Master/GetUserRoles',
        '/api/v1/Master/SaveUserWithRole',
        '/api/v1/Master/GetMenuHierarchy',
        '/api/v1/Account/GetUserAllMenuPermissions',
        '/api/v1/Account/SaveUserPermissions',
        '/api/v1/Master/GetCompanyByAppId/app-123',
        '/api/v1/Master/SaveCompany',
      ]);
      expect(jsonDecode(requests[4].body), {'menuId': 0, 'userId': 4});
      expect(jsonDecode(requests[5].body), {
        'userId': 4,
        'permissions': [
          {'menuId': 12, 'access': true},
        ],
      });
      expect(jsonDecode(requests[7].body), {'companyID': 1});
    },
  );

  test('non-admin sessions cannot call administration endpoints', () async {
    var requestCount = 0;
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((_) async {
        requestCount++;
        return http.Response('{"errorCode":0,"data":[]}', 200);
      }),
    );
    final repository = AdministrationRepository(api);
    const nonAdmin = AuthSession(
      token: 'tailor-token',
      appId: 'app-123',
      financialYearId: 42,
      financialYearName: '2026-27',
      companyName: 'Studio',
      userName: 'Taylor',
      userRole: 'TAILOR',
    );

    await expectLater(
      repository.loadUsers(nonAdmin),
      throwsA(isA<ApiException>()),
    );
    expect(requestCount, 0);
  });
}
