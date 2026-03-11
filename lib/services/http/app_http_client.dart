import 'dart:convert';

import 'package:http/http.dart' as http;

/// 서비스 전반에서 재사용하는 HTTP 공통 클라이언트
class AppHttpClient {
  final http.Client _client;

  AppHttpClient({http.Client? client}) : _client = client ?? http.Client();

  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _client.get(uri, headers: headers).timeout(timeout);
  }

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _client.post(uri, headers: headers, body: body).timeout(timeout);
  }

  Future<Map<String, dynamic>> getJsonMap({
    required Uri uri,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 30),
    String Function(int statusCode, String body)? statusErrorBuilder,
  }) async {
    final response = await get(uri, headers: headers, timeout: timeout);
    _ensureSuccess(response, statusErrorBuilder);
    return _decodeJsonMap(response);
  }

  Future<Map<String, dynamic>> postJsonMap({
    required Uri uri,
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 30),
    String Function(int statusCode, String body)? statusErrorBuilder,
  }) async {
    final response = await post(
      uri,
      headers: headers,
      body: body,
      timeout: timeout,
    );
    _ensureSuccess(response, statusErrorBuilder);
    return _decodeJsonMap(response);
  }

  Map<String, dynamic> decodeJsonMapBody(http.Response response) {
    return _decodeJsonMap(response);
  }

  void _ensureSuccess(
    http.Response response,
    String Function(int statusCode, String body)? statusErrorBuilder,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final message = statusErrorBuilder != null
        ? statusErrorBuilder(response.statusCode, response.body)
        : 'HTTP 요청 실패: ${response.statusCode}';
    throw Exception(message);
  }

  Map<String, dynamic> _decodeJsonMap(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('응답 JSON 형식이 올바르지 않습니다');
    }
    return decoded;
  }

  void dispose() {
    _client.close();
  }
}
