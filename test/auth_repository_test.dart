import 'dart:convert';

import 'package:ce_tailor_rentals/core/api_client.dart';
import 'package:ce_tailor_rentals/core/session_store.dart';
import 'package:ce_tailor_rentals/features/auth/auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('uses the Angular financial-year and login API contracts', () async {
    final requests = <http.Request>[];
    final sessionStore = _MemorySessionStore();
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('GetFinancialYearsByAppIdAsync')) {
          return http.Response(
            '{"errorCode":0,"data":[{"finYearID":5,"finYearName":"2025-26","isCurrent":true}]}',
            200,
          );
        }
        return http.Response(
          '{"errorCode":0,"token":"test-token","userID":12,"userName":"Taylor","companyName":"Studio","companylogo":"https://example.test/studio.png","userRole":"RENTAL"}',
          200,
        );
      }),
    );
    final repository = AuthRepository(api, sessionStore);

    final years = await repository.loadFinancialYears(' app-123 ');
    final session = await repository.signIn(
      appId: ' app-123 ',
      userName: ' Taylor ',
      password: 'not-persisted',
      financialYear: years.single,
    );

    expect(
      requests[0].url.path,
      '/api/v1/Master/GetFinancialYearsByAppIdAsync',
    );
    expect(jsonDecode(requests[0].body), {
      'appId': 'app-123',
      'menuId': 0,
      'caseId': null,
      'fromDate': null,
      'toDate': null,
    });
    expect(requests[1].url.path, '/api/v1/Account/login');
    expect(jsonDecode(requests[1].body), {
      'userName': 'Taylor',
      'password': 'not-persisted',
      'appId': 'app-123',
      'latitude': '',
      'longitude': '',
    });
    expect(years.single.id, 5);
    expect(session.financialYearId, 5);
    expect(session.userName, 'Taylor');
    expect(session.userRole, 'RENTAL');
    expect(session.companyLogo, 'https://example.test/studio.png');
    expect(
      AuthSession.fromJson(session.toJson()).companyLogo,
      'https://example.test/studio.png',
    );
    expect(session.canViewRentals, isTrue);
    expect(session.canViewTailoring, isFalse);
    expect(sessionStore.savedSession, same(session));
    expect(session.toJson().containsKey('password'), isFalse);
  });

  test(
    'rejects a successful login response without a supported role',
    () async {
      final sessionStore = _MemorySessionStore();
      final api = ApiClient(
        baseUrl: 'https://example.test/api/v1/',
        client: MockClient(
          (_) async => http.Response(
            '{"errorCode":0,"token":"test-token","companyName":"Studio"}',
            200,
          ),
        ),
      );
      final repository = AuthRepository(api, sessionStore);

      await expectLater(
        repository.signIn(
          appId: 'app-123',
          userName: 'Taylor',
          password: 'password',
          financialYear: const FinancialYear(
            id: 5,
            name: '2025-26',
            isCurrent: true,
          ),
        ),
        throwsA(isA<ApiException>()),
      );
      expect(sessionStore.savedSession, isNull);
    },
  );
}

class _MemorySessionStore extends SessionStore {
  _MemorySessionStore() : super(const FlutterSecureStorage());

  AuthSession? savedSession;

  @override
  Future<void> write(AuthSession session) async {
    savedSession = session;
  }
}
