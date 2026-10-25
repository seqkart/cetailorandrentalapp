import '../../core/api_client.dart';
import '../../core/session_store.dart';

class AdministrationRepository {
  const AdministrationRepository(this._api);

  static const _customerMenuId = 38;
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> loadCustomers(AuthSession session) async {
    _authorize(session);
    return _list(
      await _api.post('Transaction/GetCustomersAsync', {
        'menuId': _customerMenuId,
        'isActive': null,
        'mobileNo': null,
        'customerName': null,
      }),
    );
  }

  Future<void> saveCustomer(
    AuthSession session,
    Map<String, Object?> values,
  ) async {
    _authorize(session);
    _check(
      await _api.post('Transaction/SaveCustomerAsync', {
        'menuId': _customerMenuId,
        ...values,
      }),
    );
  }

  Future<void> deleteCustomer(AuthSession session, int customerId) async {
    _authorize(session);
    _check(
      await _api.delete(
        'Transaction/DeleteCustomerByIdAsync?customerID=$customerId',
      ),
    );
  }

  Future<List<Map<String, dynamic>>> loadUsers(AuthSession session) async {
    _authorize(session);
    return _list(
      await _api.post('Master/GetAllUsers', {'menuId': 0, 'isActive': null}),
    );
  }

  Future<List<Map<String, dynamic>>> loadRoles(AuthSession session) async {
    _authorize(session);
    return _list(
      await _api.post('Master/GetUserRoles', {'menuId': 0, 'isActive': true}),
    );
  }

  Future<void> saveUser(
    AuthSession session,
    Map<String, Object?> values,
  ) async {
    _authorize(session);
    _check(await _api.post('Master/SaveUserWithRole', values));
  }

  Future<void> deleteUser(AuthSession session, int userId) async {
    _authorize(session);
    _check(
      await _api.post('Master/DeleteUser', {'menuId': 0, 'userID': userId}),
    );
  }

  Future<List<Map<String, dynamic>>> loadMenus(AuthSession session) async {
    _authorize(session);
    return _list(
      await _api.post('Master/GetMenuHierarchy', {
        'menuId': 0,
        'isActive': true,
        'isVisible': true,
      }),
    );
  }

  Future<List<Map<String, dynamic>>> loadUserPermissions(
    AuthSession session,
    int userId,
  ) async {
    _authorize(session);
    return _list(
      await _api.post('Account/GetUserAllMenuPermissions', {
        'menuId': 0,
        'userId': userId,
      }),
    );
  }

  Future<void> savePermissions(
    AuthSession session,
    int userId,
    List<Map<String, Object?>> permissions,
  ) async {
    _authorize(session);
    _check(
      await _api.post('Account/SaveUserPermissions', {
        'userId': userId,
        'permissions': permissions,
      }),
    );
  }

  Future<Map<String, dynamic>> loadCompany(AuthSession session) async {
    _authorize(session);
    final response = await _api.get(
      'Master/GetCompanyByAppId/${Uri.encodeComponent(session.appId)}',
    );
    _check(response);
    final data = response['data'];
    if (data is Map) return _stringMap(data);
    if (data is List) {
      final first = data.whereType<Map>().firstOrNull;
      if (first != null) return _stringMap(first);
    }
    return <String, dynamic>{};
  }

  Future<void> saveCompany(
    AuthSession session,
    Map<String, Object?> values,
  ) async {
    _authorize(session);
    _check(await _api.post('Master/SaveCompany', values));
  }

  void _authorize(AuthSession session) {
    if (!session.isAdmin) {
      throw const ApiException(
        'Administrator access is required for this operation.',
      );
    }
    _api.token = session.token;
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> response) {
    _check(response);
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

  void _check(Map<String, dynamic> response) {
    if (response['errorCode'] != null && response['errorCode'] != 0) {
      throw ApiException(
        response['message']?.toString() ??
            response['errorDesc']?.toString() ??
            'The administration request failed.',
      );
    }
  }
}
