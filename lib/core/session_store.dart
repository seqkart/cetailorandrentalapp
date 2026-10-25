import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.appId,
    required this.financialYearId,
    required this.financialYearName,
    required this.companyName,
    required this.userName,
    this.companyLogo = '',
    required this.userRole,
  });

  final String token;
  final String appId;
  final int financialYearId;
  final String financialYearName;
  final String companyName;
  final String userName;
  final String companyLogo;
  final String userRole;

  String get normalizedRole => userRole.trim().toUpperCase();
  bool get hasSupportedRole =>
      const {'ADMIN', 'TAILOR', 'RENTAL'}.contains(normalizedRole);
  bool get isAdmin => normalizedRole == 'ADMIN';
  bool get canViewTailoring => isAdmin || normalizedRole == 'TAILOR';
  bool get canViewRentals => isAdmin || normalizedRole == 'RENTAL';

  Map<String, Object> toJson() => {
    'token': token,
    'appId': appId,
    'financialYearId': financialYearId,
    'financialYearName': financialYearName,
    'companyName': companyName,
    'userName': userName,
    'companyLogo': companyLogo,
    'userRole': userRole,
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    final appId = json['appId'];
    final financialYearId = json['financialYearId'];
    if (token is! String ||
        token.isEmpty ||
        appId is! String ||
        financialYearId is! int) {
      throw const FormatException('Saved sign-in session is invalid.');
    }

    return AuthSession(
      token: token,
      appId: appId,
      financialYearId: financialYearId,
      financialYearName: json['financialYearName']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      companyLogo: json['companyLogo']?.toString() ?? '',
      userRole: json['userRole']?.toString() ?? '',
    );
  }
}

class SessionStore {
  const SessionStore(this._storage);

  static const _sessionKey = 'auth_session';
  static const _pinKey = 'unlock_pin';
  static const _biometricKey = 'biometric_unlock_enabled';
  static const _localeKey = 'app_locale';
  final FlutterSecureStorage _storage;

  Future<AuthSession?> read() async {
    final value = await _storage.read(key: _sessionKey);
    if (value == null) return null;

    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Saved sign-in session is invalid.');
    }
    return AuthSession.fromJson(decoded);
  }

  Future<void> write(AuthSession session) =>
      _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));

  Future<String?> readPin() => _storage.read(key: _pinKey);

  Future<bool> readBiometricPreference() async =>
      await _storage.read(key: _biometricKey) == 'true';

  Future<String?> readLocale() => _storage.read(key: _localeKey);

  Future<void> writeLocale(String languageCode) =>
      _storage.write(key: _localeKey, value: languageCode);

  Future<void> saveUnlockSettings({
    required String pin,
    required bool useBiometrics,
  }) async {
    await _storage.write(key: _pinKey, value: pin);
    await _storage.write(key: _biometricKey, value: useBiometrics.toString());
  }

  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _biometricKey);
  }
}
