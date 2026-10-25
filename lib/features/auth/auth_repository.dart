import '../../core/api_client.dart';
import '../../core/session_store.dart';

class FinancialYear {
  const FinancialYear({
    required this.id,
    required this.name,
    required this.isCurrent,
  });

  final int id;
  final String name;
  final bool isCurrent;

  factory FinancialYear.fromJson(Map<String, dynamic> json) {
    final id = json['finYearID'];
    final name = json['finYearName'];
    if (id is! num || name is! String) {
      throw const FormatException(
        'The server returned an invalid financial year.',
      );
    }
    return FinancialYear(
      id: id.toInt(),
      name: name,
      isCurrent: json['isCurrent'] == true,
    );
  }
}

class AuthRepository {
  const AuthRepository(this._api, this._sessionStore);

  final ApiClient _api;
  final SessionStore _sessionStore;

  void clearToken() => _api.token = null;

  Future<List<FinancialYear>> loadFinancialYears(String appId) async {
    final response = await _api.post('Master/GetFinancialYearsByAppIdAsync', {
      'appId': appId.trim(),
      'menuId': 0,
      'caseId': null,
      'fromDate': null,
      'toDate': null,
    });
    final rows = response['data'];
    if (response['errorCode'] != 0 || rows is! List) {
      throw ApiException(
        response['message']?.toString() ??
            response['errorDesc']?.toString() ??
            'Unable to load financial years.',
      );
    }
    return rows
        .whereType<Map<String, dynamic>>()
        .map(FinancialYear.fromJson)
        .toList(growable: false);
  }

  Future<AuthSession> signIn({
    required String appId,
    required String userName,
    required String password,
    required FinancialYear financialYear,
  }) async {
    final response = await _api.post('Account/login', {
      'userName': userName.trim(),
      'password': password,
      'appId': appId.trim(),
      'latitude': '',
      'longitude': '',
    });

    final token = response['token'];
    if (response['errorCode'] != 0 || token is! String || token.isEmpty) {
      throw ApiException(
        response['message']?.toString() ??
            response['errorDesc']?.toString() ??
            'Sign-in failed. Check your details and try again.',
      );
    }

    final userRole = response['userRole'];
    if (userRole is! String ||
        !const {
          'ADMIN',
          'TAILOR',
          'RENTAL',
        }.contains(userRole.trim().toUpperCase())) {
      throw const ApiException(
        'Login response is missing a valid user role. Please contact support.',
      );
    }

    final session = AuthSession(
      token: token,
      appId: appId.trim(),
      financialYearId: financialYear.id,
      financialYearName: financialYear.name,
      companyName: response['companyName']?.toString() ?? '',
      userName: response['userName']?.toString() ?? userName.trim(),
      companyLogo: response['companylogo']?.toString() ?? '',
      userRole: userRole.trim().toUpperCase(),
    );
    await _sessionStore.write(session);
    return session;
  }
}
