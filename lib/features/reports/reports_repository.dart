import '../../core/api_client.dart';
import '../../core/session_store.dart';

class ReportResult {
  const ReportResult({
    this.rows = const [],
    this.accounts = const [],
    this.summary,
  });

  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> accounts;
  final Map<String, dynamic>? summary;
}

class ReportsRepository {
  const ReportsRepository(this._api);

  static const menuId = 38;
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> loadCustomers(AuthSession session) async {
    final response = await _post(session, 'Transaction/GetCustomersAsync', {
      'isActive': true,
      'mobileNo': null,
      'menuId': menuId,
    });
    _check(response);
    return _mapList(response['data']);
  }

  Future<List<Map<String, dynamic>>> loadItems(AuthSession session) async {
    final response = await _post(session, 'Transaction/GetAllItemsAsync', {
      'itemName': '',
      'menuId': menuId,
    });
    _check(response);
    return _mapList(response['data']);
  }

  Future<ReportResult> load(
    AuthSession session, {
    required String report,
    required Map<String, Object?> filters,
  }) async {
    final response = await _post(session, 'Report/$report', {
      ...filters,
      'menuId': menuId,
    });
    _check(response);

    final data = response['data'];
    final result = data is Map ? _map(data) : response;
    final list = data is List ? data : result['data'];
    return ReportResult(
      rows: _mapList(switch (report) {
        'GetCustomerLedger' => result['entries'] ?? list,
        'GetCashFlowSummary' => result['dailyCashFlow'] ?? list,
        _ => list,
      }),
      accounts: _mapList(result['accounts']),
      summary: result['summary'] is Map ? _map(result['summary'] as Map) : null,
    );
  }

  Future<Map<String, dynamic>> _post(
    AuthSession session,
    String path,
    Map<String, Object?> payload,
  ) {
    _api.token = session.token;
    return _api.post(path, payload);
  }

  List<Map<String, dynamic>> _mapList(Object? value) => value is List
      ? value.whereType<Map>().map(_map).toList(growable: false)
      : const [];

  Map<String, dynamic> _map(Map value) => {
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };

  void _check(Map<String, dynamic> response) {
    if (response['errorCode'] != null && response['errorCode'] != 0) {
      throw ApiException(
        response['message']?.toString() ??
            response['errorDesc']?.toString() ??
            'Unable to load report data.',
      );
    }
  }
}
