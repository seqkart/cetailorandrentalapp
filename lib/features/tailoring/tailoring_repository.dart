import '../../core/api_client.dart';
import '../../core/session_store.dart';

class TailoringRepository {
  const TailoringRepository(this._api);

  static const menuId = 38;
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> loadOrders(
    AuthSession session, {
    required String fromDate,
    required String toDate,
  }) async {
    final response = await _post(
      session,
      'Transaction/GetAllOrdersAsync?MenuId=$menuId',
      {'fromDate': fromDate, 'toDate': toDate},
    );
    return _list(response);
  }

  Future<List<Map<String, dynamic>>> loadOrdersByType(
    AuthSession session, {
    String status = '',
    String fromDate = '',
    String toDate = '',
  }) async {
    final payload = status == 'Today'
        ? <String, Object?>{'fromDate': fromDate, 'toDate': toDate}
        : <String, Object?>{
            'finYearID': session.financialYearId,
            'status': status,
          };
    final response = await _post(
      session,
      'Transaction/GetAllOrdersAsync',
      payload,
    );
    return _list(response);
  }

  Future<Map<String, dynamic>> saveOrder(
    AuthSession session,
    Map<String, Object?> payload,
  ) async {
    final response = await _post(
      session,
      'Transaction/SaveOrderAsync',
      payload,
    );
    _check(response);
    return response;
  }

  Future<List<Map<String, dynamic>>> loadItems(AuthSession session) async {
    final response = await _post(session, 'Transaction/GetAllItemsAsync', {
      'itemName': '',
      'menuId': menuId,
    });
    return _list(response);
  }

  Future<List<Map<String, dynamic>>> loadCustomers(AuthSession session) async {
    final response = await _post(session, 'Transaction/GetCustomersAsync', {
      'isActive': true,
      'mobileNo': null,
      'menuId': menuId,
    });
    return _list(response);
  }

  Future<List<Map<String, dynamic>>> loadSizes(AuthSession session) async =>
      _getList(session, 'Master/GetAllSizesAsync?MenuId=$menuId');

  Future<List<Map<String, dynamic>>> loadColors(AuthSession session) async =>
      _getList(session, 'Master/GetAllColorAsync?MenuId=$menuId');

  Future<List<Map<String, dynamic>>> loadProcesses(AuthSession session) async =>
      _getList(session, 'Master/GetAllProcessesAsync?MenuId=$menuId');

  Future<Map<String, dynamic>> saveProcess(
    AuthSession session,
    Map<String, Object?> payload,
  ) async {
    final response = await _post(session, 'Master/SaveProcessAsync', payload);
    _check(response);
    return response;
  }

  Future<List<Map<String, dynamic>>> loadTailors(AuthSession session) async =>
      _getList(session, 'Master/GetAllTailorsAsync?MenuId=$menuId');

  Future<List<Map<String, dynamic>>> loadVoucherSeries(
    AuthSession session,
  ) async {
    final response = await _post(session, 'Master/GetVoucherSeriesAsync', {
      'voucherMenuID': menuId,
      'menuId': menuId,
      'caseId': null,
      'fromDate': null,
      'toDate': null,
    });
    return _list(response);
  }

  Future<List<Map<String, dynamic>>> loadUnassignedOrders(
    AuthSession session,
  ) async {
    final response = await _post(
      session,
      'Transaction/GetUnassignedOrdersListAsync',
      {'fromDate': '', 'toDate': ''},
    );
    return _list(response);
  }

  Future<Map<String, dynamic>> assignOrders(
    AuthSession session, {
    required int employeeId,
    required List<int> orderDetailIds,
  }) async {
    final response = await _post(
      session,
      'Transaction/BulkAssignOrdersToTailorAsync',
      {'employeeId': employeeId, 'orderDetailIds': orderDetailIds},
    );
    _check(response);
    return response;
  }

  Future<List<Map<String, dynamic>>> loadAssignedOrders(
    AuthSession session, {
    int? employeeId,
  }) async {
    final response = await _post(
      session,
      'Transaction/GetAssignedOrdersListAsync',
      {'fromDate': '', 'toDate': '', 'employeeId': employeeId},
    );
    return _list(response);
  }

  Future<Map<String, dynamic>> receiveTailorJobs(
    AuthSession session,
    List<int> jobDetailIds,
  ) async {
    final response = await _post(
      session,
      'Transaction/BulkMarkJobsAsReceivedAsync',
      {'jobDetailIds': jobDetailIds},
    );
    _check(response);
    return response;
  }

  Future<List<Map<String, dynamic>>> loadPrefitOrders(
    AuthSession session,
  ) async {
    final response = await _post(
      session,
      'Transaction/GetAllReadyForPrefitOrdersAsync',
      {'fromDate': '', 'toDate': ''},
    );
    final orders = response['orders'];
    if (orders is List) return _mapList(orders);
    return _list(response);
  }

  Future<Map<String, dynamic>?> loadMeasurementMappings(
    AuthSession session,
    int groupId,
  ) async {
    final response = await _get(
      session,
      'Master/GetAllMeasurementMappingsByGroupIdNestedAsync?groupId=$groupId',
    );
    final mappings = _list(response);
    return mappings.isEmpty ? null : mappings.first;
  }

  Future<Map<String, dynamic>> updatePrefitStatus(
    AuthSession session,
    Map<String, Object?> payload,
  ) async {
    final response = await _post(
      session,
      'Transaction/UpdatePrefitApprovalStatusAsync',
      payload,
    );
    _check(response);
    return response;
  }

  Future<List<Map<String, dynamic>>> loadOrderMeasurements(
    AuthSession session,
    int orderDetailId,
  ) async {
    final response = await _get(
      session,
      'Transaction/GetOrderDetailMeasurementsAsync?orderDetailId=$orderDetailId',
    );
    return _list(response);
  }

  Future<List<Map<String, dynamic>>> loadInvoices(
    AuthSession session, {
    String fromDate = '',
    String toDate = '',
  }) async {
    final response = await _post(session, 'Transaction/GetAllInvoicesAsync', {
      'FinYearID': session.financialYearId,
      'finYearID': session.financialYearId,
      'menuId': menuId,
      'fromDate': fromDate,
      'toDate': toDate,
      'caseId': null,
    });
    return _list(response);
  }

  Future<Map<String, dynamic>> generateInvoice(
    AuthSession session,
    Map<String, Object?> payload,
  ) async {
    final response = await _post(
      session,
      'Transaction/GenerateInvoiceAsync',
      payload,
    );
    _check(response);
    return response;
  }

  Future<Map<String, dynamic>?> findOrderByBarcode(
    AuthSession session,
    String barcode,
  ) async {
    final response = await _get(
      session,
      'Transaction/GetOrderByIdAsync?barcode=${Uri.encodeQueryComponent(barcode)}&itemStatus=Approved',
    );
    _check(response);
    final data = response['data'];
    return data is Map ? _map(data) : null;
  }

  Future<Map<String, dynamic>> _post(
    AuthSession session,
    String path,
    Map<String, Object?> payload,
  ) async {
    _api.token = session.token;
    return _api.post(path, payload);
  }

  Future<Map<String, dynamic>> _get(AuthSession session, String path) async {
    _api.token = session.token;
    return _api.get(path);
  }

  Future<List<Map<String, dynamic>>> _getList(
    AuthSession session,
    String path,
  ) async {
    final response = await _get(session, path);
    return _list(response);
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> response) {
    _check(response);
    final value = response['data'];
    return value is List ? _mapList(value) : const [];
  }

  List<Map<String, dynamic>> _mapList(List value) =>
      value.whereType<Map>().map(_map).toList(growable: false);

  Map<String, dynamic> _map(Map value) => {
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };

  void _check(Map<String, dynamic> response) {
    if (response['errorCode'] != null && response['errorCode'] != 0) {
      throw ApiException(
        response['message']?.toString() ??
            response['errorDesc']?.toString() ??
            'The tailoring request failed.',
      );
    }
  }
}
