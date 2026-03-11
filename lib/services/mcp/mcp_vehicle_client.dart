import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mcp_client/mcp_client.dart';

class McpVehicleClientException implements Exception {
  final String message;

  const McpVehicleClientException(this.message);

  @override
  String toString() => message;
}

/// 차량 데이터 전용 MCP 클라이언트
class McpVehicleClient {
  static final McpVehicleClient _sharedInstance = McpVehicleClient._internal();

  factory McpVehicleClient() => _sharedInstance;

  McpVehicleClient._internal();

  Client? _client;
  Future<void>? _connectingFuture;

  static String get serverUrl {
    const compileTimeUrl = String.fromEnvironment('MCP_SERVER_URL');
    if (compileTimeUrl.isNotEmpty) {
      return compileTimeUrl;
    }
    return _requireRuntimeEnv('MCP_SERVER_URL');
  }

  static String get authToken {
    const compileTimeToken = String.fromEnvironment('MCP_AUTH_TOKEN');
    if (compileTimeToken.isNotEmpty) {
      return compileTimeToken;
    }
    return _requireRuntimeEnv('MCP_AUTH_TOKEN');
  }

  static String _requireRuntimeEnv(String key) {
    if (!dotenv.isInitialized) {
      throw StateError(
        '환경 변수 초기화가 완료되지 않았습니다. main()에서 dotenv.load()를 먼저 호출하세요.',
      );
    }

    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('$key 값이 비어 있습니다. --dart-define 또는 .env 설정을 확인하세요.');
    }
    return value;
  }

  Future<Map<String, dynamic>> callTool(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    try {
      final client = await _ensureConnected();
      final result = await client.callTool(name, arguments);
      final textContents = _extractTextContents(result);
      final payload = _parsePayloadFromTextContents(textContents);

      if (payload != null) {
        _throwIfPayloadError(payload, toolName: name);
      }

      if (result.isError == true) {
        final detail = _buildIsErrorDetail(
          payload: payload,
          textContents: textContents,
        );
        throw McpVehicleClientException('MCP tool 호출 실패($name): $detail');
      }

      if (payload == null) {
        if (textContents.isEmpty) {
          throw FormatException('MCP tool 응답에 text content가 없습니다. ($name)');
        }
        throw FormatException(
          'MCP tool 응답 text content를 JSON으로 해석할 수 없습니다. ($name)',
        );
      }

      return payload;
    } on McpVehicleClientException {
      rethrow;
    } on FormatException catch (e) {
      throw McpVehicleClientException('MCP 응답 파싱 실패($name): ${e.message}');
    } catch (e) {
      throw McpVehicleClientException('MCP tool 호출 실패($name): $e');
    }
  }

  Future<Client> _ensureConnected() async {
    final existingClient = _client;
    if (existingClient != null) {
      return existingClient;
    }

    final pending = _connectingFuture;
    if (pending != null) {
      await pending;
      final connectedClient = _client;
      if (connectedClient != null) {
        return connectedClient;
      }
      throw const McpVehicleClientException('MCP 클라이언트 연결 상태를 확인할 수 없습니다.');
    }

    final completer = Completer<void>();
    _connectingFuture = completer.future;

    try {
      final transport = await SseClientTransport.create(
        serverUrl: serverUrl,
        headers: <String, String>{'Authorization': 'Token $authToken'},
      );

      final client = McpClient.createClient(
        McpClient.simpleConfig(name: 'east-vehicle-client', version: '1.0.0'),
      );

      await client.connectWithRetry(
        transport,
        maxRetries: 3,
        delay: const Duration(seconds: 1),
      );

      _client = client;
      completer.complete();
      return client;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _connectingFuture = null;
    }
  }

  List<String> _extractTextContents(CallToolResult result) {
    return result.content
        .whereType<TextContent>()
        .map((content) => content.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }

  Map<String, dynamic>? _parsePayloadFromTextContents(
    List<String> textContents,
  ) {
    for (final text in textContents) {
      final parsed = _decodeJsonTextToMap(text);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  String _buildIsErrorDetail({
    Map<String, dynamic>? payload,
    required List<String> textContents,
  }) {
    final detailParts = <String>[];

    if (payload != null) {
      final statusCode = _readStatusCode(payload);
      if (statusCode != null) {
        detailParts.add('status_code=$statusCode');
      }

      final errorField = _readErrorField(payload);
      if (errorField != null && errorField.isNotEmpty) {
        detailParts.add('error=$errorField');
      }

      final messageField = _readMessageField(payload);
      if (messageField != null &&
          messageField.isNotEmpty &&
          messageField != errorField) {
        detailParts.add('message=$messageField');
      }
    }

    if (detailParts.isNotEmpty) {
      return detailParts.join(', ');
    }

    if (textContents.isNotEmpty) {
      final preview = _sanitizeRawTextPreview(textContents.first);
      return 'isError=true, raw=$preview';
    }

    return 'isError=true';
  }

  String _sanitizeRawTextPreview(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    const maxLength = 180;
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength)}...';
  }

  Map<String, dynamic>? _decodeJsonTextToMap(String text) {
    try {
      final decoded = jsonDecode(text);
      return _toMap(decoded);
    } catch (_) {
      return null;
    }
  }

  void _throwIfPayloadError(
    Map<String, dynamic> payload, {
    required String toolName,
  }) {
    final statusCode = _readStatusCode(payload);
    if (statusCode != null && statusCode >= 400) {
      final errorField = _readErrorField(payload);
      final messageField = _readMessageField(payload);
      final details = <String>['status_code=$statusCode'];
      if (errorField != null && errorField.isNotEmpty) {
        details.add('error=$errorField');
      }
      if (messageField != null &&
          messageField.isNotEmpty &&
          messageField != errorField) {
        details.add('message=$messageField');
      }
      throw McpVehicleClientException(
        'MCP tool 호출 실패($toolName): ${details.join(', ')}',
      );
    }

    final errorField = _readErrorField(payload);
    if (errorField != null && errorField.isNotEmpty) {
      throw McpVehicleClientException('MCP tool 호출 실패($toolName): $errorField');
    }
  }

  int? _readStatusCode(Map<String, dynamic> payload) {
    final topLevel =
        _toInt(payload['status_code']) ?? _toInt(payload['statusCode']);
    if (topLevel != null) {
      return topLevel;
    }

    final nested = _toMap(payload['data']);
    if (nested != null) {
      return _toInt(nested['status_code']) ?? _toInt(nested['statusCode']);
    }

    return null;
  }

  String? _readErrorField(Map<String, dynamic> payload) {
    final topLevelError = payload['error'];
    if (topLevelError != null && topLevelError.toString().trim().isNotEmpty) {
      return topLevelError.toString().trim();
    }

    final nested = _toMap(payload['data']);
    if (nested != null) {
      final nestedError = nested['error'];
      if (nestedError != null && nestedError.toString().trim().isNotEmpty) {
        return nestedError.toString().trim();
      }
    }

    return null;
  }

  String? _readMessageField(Map<String, dynamic> payload) {
    final topLevel = payload['message'] ?? payload['detail'];
    if (topLevel != null && topLevel.toString().trim().isNotEmpty) {
      return topLevel.toString().trim();
    }

    final nested = _toMap(payload['data']);
    if (nested != null) {
      final nestedMessage = nested['message'] ?? nested['detail'];
      if (nestedMessage != null && nestedMessage.toString().trim().isNotEmpty) {
        return nestedMessage.toString().trim();
      }
    }

    return null;
  }

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  Map<String, dynamic>? _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, dynamic nestedValue) {
        return MapEntry(key.toString(), nestedValue);
      });
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.map((key, dynamic nestedValue) {
            return MapEntry(key.toString(), nestedValue);
          });
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void dispose() {
    _client?.dispose();
    _client = null;
    _connectingFuture = null;
  }
}
