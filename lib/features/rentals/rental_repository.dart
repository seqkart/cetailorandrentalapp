import '../../core/api_client.dart';
import '../../core/session_store.dart';

class RentalRepository {
  const RentalRepository(this._api);

  static const rentalMenuId = 38;
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> loadCatalog(
    AuthSession session, {
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    _api.token = session.token;
    final response = await _postCommon('GetRentCatalogAsync', {
      'fromDate': _date(fromDate),
      'toDate': _date(toDate),
    });
    return _listData(response);
  }

  Future<List<Map<String, dynamic>>> loadItems(AuthSession session) async {
    _api.token = session.token;
    final response = await _api.post('Transaction/GetAllItemsAsync', {
      'itemName': '',
      'menuId': rentalMenuId,
    });
    _checkResponse(response);
    return _listData(response);
  }

  Future<List<Map<String, dynamic>>> loadItemGroups(AuthSession session) async {
    _api.token = session.token;
    final response = await _api.get(
      'Master/GetAllGroupMstAsync?MenuId=$rentalMenuId',
    );
    _checkResponse(response);
    return _listData(response);
  }

  Future<List<Map<String, dynamic>>> loadItemUnits(AuthSession session) async {
    _api.token = session.token;
    final response = await _api.get(
      'Master/GetAllUnitsAsync?MenuId=$rentalMenuId',
    );
    _checkResponse(response);
    return _listData(response);
  }

  Future<Map<String, dynamic>> saveItemGroup(
    AuthSession session,
    String name,
  ) async {
    _api.token = session.token;
    final response = await _api.post('Master/SaveGroupMstAsync', {
      'groupID': 0,
      'groupName': name,
      'isActive': true,
    });
    _checkResponse(response);
    return response;
  }

  Future<List<Map<String, dynamic>>> loadSizes(AuthSession session) async {
    _api.token = session.token;
    final response = await _api.get(
      'Master/GetAllSizesAsync?MenuId=$rentalMenuId',
    );
    _checkResponse(response);
    return _listData(response);
  }

  Future<List<Map<String, dynamic>>> loadColors(AuthSession session) async {
    _api.token = session.token;
    final response = await _api.get(
      'Master/GetAllColorAsync?MenuId=$rentalMenuId',
    );
    _checkResponse(response);
    return _listData(response);
  }

  Future<Map<String, dynamic>> saveSize(
    AuthSession session,
    String name,
  ) async {
    _api.token = session.token;
    final response = await _api.post('Master/SaveSizeAsync', {
      'sizeID': 0,
      'sizeName': name,
      'isActive': true,
    });
    _checkResponse(response);
    return response;
  }

  Future<Map<String, dynamic>> saveColor(
    AuthSession session,
    String name,
  ) async {
    _api.token = session.token;
    final response = await _api.post('Master/SaveColorAsync', {
      'colorID': 0,
      'colorName': name,
    });
    _checkResponse(response);
    return response;
  }

  Future<Map<String, dynamic>> saveItem(
    AuthSession session,
    Map<String, Object?> payload,
  ) async {
    _api.token = session.token;
    final response = await _api.post('Transaction/SaveItemAsync', payload);
    _checkResponse(response);
    return response;
  }

  Future<Map<String, dynamic>> saveCatalog(
    AuthSession session,
    Map<String, Object?> payload,
  ) async {
    _api.token = session.token;
    final response = await _api.post(
      'Transaction/SaveRentCatalogAsync',
      payload,
    );
    _checkResponse(response);
    return response;
  }

  Future<List<Map<String, dynamic>>> loadCustomers(AuthSession session) async {
    _api.token = session.token;
    return _listData(await _postCommon('GetCustomersAsync', const {}));
  }

  Future<Map<String, dynamic>> saveCustomer(
    AuthSession session,
    Map<String, Object?> payload,
  ) async {
    _api.token = session.token;
    final response = await _api.post('Transaction/SaveCustomerAsync', payload);
    _checkResponse(response);
    return response;
  }

  Future<List<Map<String, dynamic>>> loadMeasurements(
    AuthSession session,
  ) async {
    _api.token = session.token;
    final response = await _api.get(
      'Master/GetAllMeasurementsAsync?MenuId=$rentalMenuId',
    );
    _checkResponse(response);
    return _listData(response);
  }

  Future<Map<String, dynamic>> saveMeasurement(
    AuthSession session,
    String name,
  ) async {
    _api.token = session.token;
    final response = await _api.post('Master/SaveMeasurementsAsync', {
      'measurementID': 0,
      'measurementName': name,
    });
    _checkResponse(response);
    return response;
  }

  Future<List<Map<String, dynamic>>> loadTailors(AuthSession session) async {
    _api.token = session.token;
    final response = await _api.get(
      'Master/GetAllTailorsAsync?MenuId=$rentalMenuId',
    );
    _checkResponse(response);
    return _listData(response)
        .where((tailor) => tailor['isActive'] != false)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> loadVoucherSeries(
    AuthSession session,
  ) async {
    _api.token = session.token;
    final response = await _api.post('Master/GetVoucherSeriesAsync', {
      'voucherMenuID': rentalMenuId,
      'menuId': rentalMenuId,
      'caseId': null,
      'fromDate': null,
      'toDate': null,
    });
    _checkResponse(response);
    return _listData(response);
  }

  Future<List<Map<String, dynamic>>> loadBookings(AuthSession session) async {
    _api.token = session.token;
    return _listData(await _postCommon('GetRentBookingsAsync', const {}));
  }

  Future<Map<String, dynamic>> saveBooking(
    AuthSession session,
    Map<String, Object?> payload,
  ) async {
    _api.token = session.token;
    final response = await _api.post(
      'Transaction/SaveRentBookingAsync',
      payload,
    );
    _checkResponse(response);
    return response;
  }

  Future<Map<String, dynamic>> deliverBooking(
    AuthSession session,
    Map<String, Object?> payload,
  ) async {
    _api.token = session.token;
    final response = await _api.post(
      'Transaction/ConvertRentBookingToRentAsync',
      payload,
    );
    _checkResponse(response);
    return response;
  }

  Future<List<Map<String, dynamic>>> findOpenRents(
    AuthSession session,
    String mobile,
  ) async {
    _api.token = session.token;
    final response = await _api.get(
      'Transaction/GetRentByMobileAsync?mobileNo=${Uri.encodeQueryComponent(mobile)}',
    );
    _checkResponse(response);
    final rents = _listData(response);
    return rents
        .where((rent) {
          final details = rent['rentDetails'];
          return details is! List ||
              details.any(
                (detail) =>
                    detail is Map &&
                    detail['status']?.toString().toLowerCase() != 'returned',
              );
        })
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> saveReturn(
    AuthSession session,
    Map<String, Object?> payload,
  ) async {
    _api.token = session.token;
    final response = await _api.post(
      'Transaction/SaveRentReturnAsync',
      payload,
    );
    _checkResponse(response);
    return response;
  }

  Future<Map<String, dynamic>> _postCommon(
    String endpoint,
    Map<String, Object?> values,
  ) async {
    final response = await _api.post('transaction/$endpoint', {
      ...values,
      'menuId': rentalMenuId,
      'caseId': null,
      'fromDate': values['fromDate'],
      'toDate': values['toDate'],
      'bookingID': values['bookingID'],
    });
    _checkResponse(response);
    return response;
  }

  void _checkResponse(Map<String, dynamic> response) {
    final errorCode = response['errorCode'];
    if (errorCode != null && errorCode != 0) {
      throw ApiException(
        response['message']?.toString() ??
            response['errorDesc']?.toString() ??
            'The rental request failed.',
      );
    }
  }

  List<Map<String, dynamic>> _listData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) {
      return data.whereType<Map>().map(_stringMap).toList(growable: false);
    }
    if (data is Map) return [_stringMap(data)];
    return const [];
  }

  Map<String, dynamic> _stringMap(Map value) => {
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
