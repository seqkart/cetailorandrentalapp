import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ce_tailor_rentals/core/api_client.dart';

void main() {
  test('sends bearer token and JSON payload to the configured API', () async {
    late http.Request receivedRequest;
    final client = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((request) async {
        receivedRequest = request;
        return http.Response('{"errorCode":0,"data":[]}', 200);
      }),
    )..token = 'test-access-token';

    await client.post('Account/login', {'userName': 'operator'});

    expect(receivedRequest.url.path, '/api/v1/Account/login');
    expect(
      receivedRequest.headers['Authorization'],
      'Bearer test-access-token',
    );
    expect(receivedRequest.headers['Content-Type'], 'application/json');
    expect(jsonDecode(receivedRequest.body), {'userName': 'operator'});
  });

  test('reports an unsuccessful HTTP response', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient(
        (_) async => http.Response('{"message":"Not authorized"}', 401),
      ),
    );

    await expectLater(
      client.get('dashboard'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.message, 'message', 'Not authorized'),
      ),
    );
  });
}
