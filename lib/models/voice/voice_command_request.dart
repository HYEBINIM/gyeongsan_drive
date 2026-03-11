// UTF-8 인코딩 파일
// 한국어 주석: 음성 명령 API 요청 모델 (Wisenut RAG API)

import '../../utils/constants.dart';

/// 음성 명령 API 요청 모델
/// Wisenut RAG API 형식에 맞춤
class VoiceCommandRequest {
  /// 쿼리 텍스트 (예: "차량 RD01RD01P001T01M04 운전자 습관 알려줘")
  final String query;

  /// 최대 도구 호출 횟수
  final int maxToolCalls;

  VoiceCommandRequest({required this.query, int? maxToolCalls})
    : maxToolCalls = maxToolCalls ?? _resolveDefaultMaxToolCalls();

  /// 한국어 주석: dotenv 미초기화/로드 실패 환경에서도 안전한 기본값을 사용
  static int _resolveDefaultMaxToolCalls() {
    try {
      return AppConstants.voiceCommandMaxToolCalls;
    } catch (_) {
      return 10;
    }
  }

  /// JSON으로 변환 (백엔드 API 형식)
  Map<String, dynamic> toJson() {
    return {'query': query, 'max_tool_calls': maxToolCalls};
  }

  /// JSON에서 생성
  factory VoiceCommandRequest.fromJson(Map<String, dynamic> json) {
    return VoiceCommandRequest(
      query: json['query'] as String,
      maxToolCalls: json['max_tool_calls'] as int?,
    );
  }

  @override
  String toString() {
    return 'VoiceCommandRequest(query: $query, maxToolCalls: $maxToolCalls)';
  }
}
