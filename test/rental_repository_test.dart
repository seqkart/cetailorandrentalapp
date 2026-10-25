import 'dart:convert';

import 'package:ce_tailor_rentals/core/api_client.dart';
import 'package:ce_tailor_rentals/core/session_store.dart';
import 'package:ce_tailor_rentals/features/rentals/rental_repository.dart';
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

  test('loads date-filtered catalog and Angular rental resources', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('{"errorCode":0,"data":[]}', 200);
      }),
    );
    final repository = RentalRepository(api);

    await repository.loadCatalog(
      session,
      fromDate: DateTime(2026, 10, 23),
      toDate: DateTime(2026, 10, 25),
    );
    await repository.loadCustomers(session);
    await repository.loadVoucherSeries(session);
    await repository.loadBookings(session);
    await repository.findOpenRents(session, '9876543210');

    expect(requests.map((request) => request.url.path), [
      '/api/v1/transaction/GetRentCatalogAsync',
      '/api/v1/transaction/GetCustomersAsync',
      '/api/v1/Master/GetVoucherSeriesAsync',
      '/api/v1/transaction/GetRentBookingsAsync',
      '/api/v1/Transaction/GetRentByMobileAsync',
    ]);
    final catalog = jsonDecode(requests[0].body) as Map<String, dynamic>;
    expect(catalog['menuId'], RentalRepository.rentalMenuId);
    expect(catalog['fromDate'], '2026-10-23');
    expect(catalog['toDate'], '2026-10-25');
    expect(jsonDecode(requests[2].body), {
      'voucherMenuID': RentalRepository.rentalMenuId,
      'menuId': RentalRepository.rentalMenuId,
      'caseId': null,
      'fromDate': null,
      'toDate': null,
    });
    expect(requests[4].url.queryParameters['mobileNo'], '9876543210');
    expect(
      requests.every((request) {
        return request.headers['authorization'] == 'Bearer rental-token';
      }),
      isTrue,
    );
  });

  test(
    'posts booking, delivery and return through Angular endpoints',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'https://example.test/api/v1/',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"errorCode":0,"message":"saved"}', 200);
        }),
      );
      final repository = RentalRepository(api);

      await repository.saveBooking(session, const {'bookingID': 0});
      await repository.deliverBooking(session, const {'bookingID': 9});
      await repository.saveReturn(session, const {'returnDate': '2026-10-23'});

      expect(requests.map((request) => request.url.path), [
        '/api/v1/Transaction/SaveRentBookingAsync',
        '/api/v1/Transaction/ConvertRentBookingToRentAsync',
        '/api/v1/Transaction/SaveRentReturnAsync',
      ]);
      expect(jsonDecode(requests[1].body), {'bookingID': 9});
      expect(
        requests.every((request) {
          return request.headers['authorization'] == 'Bearer rental-token';
        }),
        isTrue,
      );
    },
  );

  test('creates customers and loads/saves alteration masters', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('{"errorCode":0,"data":[]}', 200);
      }),
    );
    final repository = RentalRepository(api);

    await repository.saveCustomer(session, const {
      'customerID': 0,
      'fullName': 'Asha',
      'mobileNo': '9876543210',
      'email': '',
      'stateId': 28,
      'address1': '',
      'address2': '',
      'cityID': 2,
      'isActive': true,
    });
    await repository.loadMeasurements(session);
    await repository.saveMeasurement(session, 'Chest');
    await repository.loadTailors(session);

    expect(requests.map((request) => request.url.path), [
      '/api/v1/Transaction/SaveCustomerAsync',
      '/api/v1/Master/GetAllMeasurementsAsync',
      '/api/v1/Master/SaveMeasurementsAsync',
      '/api/v1/Master/GetAllTailorsAsync',
    ]);
    expect(requests[0].body, contains('"mobileNo":"9876543210"'));
    expect(requests[1].url.queryParameters['MenuId'], '38');
    expect(jsonDecode(requests[2].body), {
      'measurementID': 0,
      'measurementName': 'Chest',
    });
    expect(requests[3].url.queryParameters['MenuId'], '38');
    expect(
      requests.every(
        (request) =>
            request.headers['authorization']?.contains(session.token) == true,
      ),
      isTrue,
    );
  });

  test(
    'loads catalogue masters and saves item plus rental catalogue',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'https://example.test/api/v1/',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"errorCode":0,"data":[]}', 200);
        }),
      );
      final repository = RentalRepository(api);

      await repository.loadItems(session);
      await repository.loadItemGroups(session);
      await repository.loadItemUnits(session);
      await repository.loadSizes(session);
      await repository.loadColors(session);
      await repository.saveItemGroup(session, 'Traditional wear');
      await repository.saveSize(session, 'Tall');
      await repository.saveColor(session, 'Teal');
      await repository.saveItem(session, const {
        'itemId': 0,
        'itemName': 'Dress',
      });
      await repository.saveCatalog(session, const {
        'catalogID': 0,
        'itemId': 8,
      });

      expect(requests.map((request) => request.url.path), [
        '/api/v1/Transaction/GetAllItemsAsync',
        '/api/v1/Master/GetAllGroupMstAsync',
        '/api/v1/Master/GetAllUnitsAsync',
        '/api/v1/Master/GetAllSizesAsync',
        '/api/v1/Master/GetAllColorAsync',
        '/api/v1/Master/SaveGroupMstAsync',
        '/api/v1/Master/SaveSizeAsync',
        '/api/v1/Master/SaveColorAsync',
        '/api/v1/Transaction/SaveItemAsync',
        '/api/v1/Transaction/SaveRentCatalogAsync',
      ]);
      expect(jsonDecode(requests[0].body), {
        'itemName': '',
        'menuId': RentalRepository.rentalMenuId,
      });
      expect(requests[1].url.queryParameters['MenuId'], '38');
      expect(requests[2].url.queryParameters['MenuId'], '38');
      expect(requests[3].url.queryParameters['MenuId'], '38');
      expect(requests[4].url.queryParameters['MenuId'], '38');
      expect(jsonDecode(requests[5].body), {
        'groupID': 0,
        'groupName': 'Traditional wear',
        'isActive': true,
      });
      expect(jsonDecode(requests[6].body), {
        'sizeID': 0,
        'sizeName': 'Tall',
        'isActive': true,
      });
      expect(jsonDecode(requests[7].body), {'colorID': 0, 'colorName': 'Teal'});
      expect(jsonDecode(requests[8].body), {'itemId': 0, 'itemName': 'Dress'});
      expect(jsonDecode(requests[9].body), {'catalogID': 0, 'itemId': 8});
    },
  );

  test('reports API errors instead of treating them as successful saves', () {
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient(
        (_) async =>
            http.Response('{"errorCode":1,"message":"Not available"}', 200),
      ),
    );

    expect(
      RentalRepository(api).loadBookings(session),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Not available',
        ),
      ),
    );
  });
}
