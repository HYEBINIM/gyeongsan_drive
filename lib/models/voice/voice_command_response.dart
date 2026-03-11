// UTF-8 인코딩 파일
// 한국어 주석: 음성 명령 API 응답 모델

import 'dart:convert';

/// 음성 명령 API 응답 모델
class VoiceCommandResponse {
  /// AI 응답 텍스트
  final String responseText;

  /// 세션 ID (대화 이어가기용)
  final String? sessionId;

  /// 실행된 액션 (옵션, 예: 'get_battery_status', 'get_location' 등)
  final String? action;

  /// 추가 데이터 (옵션)
  final Map<String, dynamic>? data;

  /// 성공 여부
  final bool success;

  /// 에러 메시지 (실패 시)
  final String? errorMessage;

  /// 타임스탬프
  final DateTime timestamp;

  VoiceCommandResponse({
    required this.responseText,
    this.sessionId,
    this.action,
    this.data,
    this.success = true,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// JSON에서 생성 (Wisenut API 응답 형식)
  factory VoiceCommandResponse.fromJson(Map<String, dynamic> json) {
    final isSuccess = json['status'] == 'success';
    final rawResponse = json['response'] as String? ?? '';

    // 한국어 주석: "\n\n" 이후의 JSON 메타데이터 제거
    final cleanedResponse = _extractCleanResponse(rawResponse);
    final metadata = _extractMetadata(rawResponse);

    return VoiceCommandResponse(
      responseText: cleanedResponse,
      sessionId: null, // Wisenut API는 session_id를 반환하지 않음
      action: null,
      // 추가 데이터 저장 (분석용)
      data: {
        if (json['tool_calls_used'] != null)
          'tool_calls_used': json['tool_calls_used'],
        if (json['tools_used'] != null) 'tools_used': json['tools_used'],
        if (metadata != null) 'metadata': metadata,
      },
      success: isSuccess,
      errorMessage: !isSuccess
          ? (json['error'] as String? ?? '요청 처리 실패')
          : null,
      timestamp: DateTime.now(),
    );
  }

  /// 한국어 주석: "\n\n" 이전의 자연어 응답 텍스트만 추출
  static String _extractCleanResponse(String rawResponse) {
    final splitIndex = rawResponse.indexOf('\n\n');
    if (splitIndex != -1) {
      return rawResponse.substring(0, splitIndex).trim();
    }
    return rawResponse.trim();
  }

  /// 한국어 주석: "\n\n" 이후의 JSON 메타데이터 파싱 (선택적)
  static Map<String, dynamic>? _extractMetadata(String rawResponse) {
    final splitIndex = rawResponse.indexOf('\n\n');
    if (splitIndex == -1) {
      return null;
    }

    final jsonPart = rawResponse.substring(splitIndex + 2).trim();
    if (jsonPart.isEmpty) {
      return null;
    }

    try {
      // JSON 파싱 시도
      final decoded = jsonDecode(jsonPart);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // 파싱 실패 시 무시 (메타데이터는 선택적 정보)
    }

    return null;
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'response_text': responseText,
      if (sessionId != null) 'session_id': sessionId,
      if (action != null) 'action': action,
      if (data != null) 'data': data,
      'success': success,
      if (errorMessage != null) 'error_message': errorMessage,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// 에러 응답 생성
  factory VoiceCommandResponse.error(String errorMessage) {
    return VoiceCommandResponse(
      responseText: '죄송합니다. 요청을 처리할 수 없습니다.',
      success: false,
      errorMessage: errorMessage,
    );
  }

  /// 복사 생성자
  VoiceCommandResponse copyWith({
    String? responseText,
    String? sessionId,
    String? action,
    Map<String, dynamic>? data,
    bool? success,
    String? errorMessage,
    DateTime? timestamp,
  }) {
    return VoiceCommandResponse(
      responseText: responseText ?? this.responseText,
      sessionId: sessionId ?? this.sessionId,
      action: action ?? this.action,
      data: data ?? this.data,
      success: success ?? this.success,
      errorMessage: errorMessage ?? this.errorMessage,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'VoiceCommandResponse(responseText: $responseText, action: $action, success: $success, errorMessage: $errorMessage)';
  }
}
