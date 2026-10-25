import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'TAILOR_API_BASE_URL',
            defaultValue: 'https://tailorapi.creativeease.app/api/v1/',
          );

  final http.Client _client;
  final String _baseUrl;
  String? _token;

  set token(String? value) => _token = value;

  Uri _uri(String path) {
    final root = _baseUrl.endsWith('/') ? _baseUrl : '$_baseUrl/';
    return Uri.parse(root).resolve(path);
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (_token case final token?) 'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _client
        .get(_uri(path), headers: _headers)
        .timeout(const Duration(seconds: 30));
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await _client
        .post(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    return _decode(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final response = await _client
        .delete(_uri(path), headers: _headers)
        .timeout(const Duration(seconds: 30));
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Request failed (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      throw const ApiException('The server returned an unreadable response.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? (decoded['message'] ?? decoded['errorDesc'])?.toString()
          : null;
      throw ApiException(
        message?.isNotEmpty == true
            ? message!
            : 'Request failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('The server returned an unexpected response.');
    }
    return decoded;
  }

  void close() => _client.close();
}
