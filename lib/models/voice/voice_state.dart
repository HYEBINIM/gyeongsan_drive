// UTF-8 인코딩 파일
// 한국어 주석: 음성 명령 상태 정의

/// 음성 명령 처리 상태
enum VoiceCommandState {
  /// 대기 중 (초기 상태)
  idle,

  /// 음성 인식 중 (마이크 듣는 중)
  listening,

  /// AI 처리 중 (백엔드 API 호출 중)
  processing,

  /// 음성 출력 중 (TTS 재생 중)
  speaking,

  /// 완료
  completed,

  /// 에러 발생
  error,
}

/// 재시도 가능한 음성 인식 에러 타입
enum VoiceErrorType {
  /// 음성을 인식하지 못함 (error_no_match)
  speechNoMatch,

  /// 음성 입력 시간 초과 (error_speech_timeout)
  speechTimeout,

  /// 신뢰도 낮음 (인식했으나 정확도가 임계값 미만)
  lowConfidence,

  /// 노이즈 감지 (너무 짧거나 의미 없는 입력)
  noiseDetected,
}

/// 대화 항목 (한 턴의 대화)
class ConversationEntry {
  final String userInput;
  final String aiResponse;

  ConversationEntry({required this.userInput, required this.aiResponse});
}

/// 음성 명령 세션 상태 모델
class VoiceSessionState {
  /// 현재 상태
  final VoiceCommandState state;

  /// 사용자가 말한 텍스트 (STT 결과)
  final String? userInput;

  /// AI 응답 텍스트
  final String? aiResponse;

  /// 에러 메시지
  final String? errorMessage;

  /// 에러 타입 (null이면 재시도 불가)
  final VoiceErrorType? errorType;

  /// 음성 인식 신뢰도 (0.0 ~ 1.0)
  final double? confidence;

  /// 대화 히스토리
  final List<ConversationEntry> conversationHistory;

  /// 음성 응답 메타데이터 (장소 정보 등)
  final Map<String, dynamic>? metadata;

  /// 음성 응답 데이터 (tools_used, metadata 등 포함)
  final Map<String, dynamic>? data;

  const VoiceSessionState({
    required this.state,
    this.userInput,
    this.aiResponse,
    this.errorMessage,
    this.errorType,
    this.confidence,
    this.conversationHistory = const [],
    this.metadata,
    this.data,
  });

  /// 재시도 가능 여부 (errorType이 있으면 재시도 가능)
  bool get canRetryVoiceRecognition => errorType != null;

  /// 초기 상태
  factory VoiceSessionState.initial() {
    return const VoiceSessionState(
      state: VoiceCommandState.idle,
      conversationHistory: [],
    );
  }

  /// 듣는 중 상태
  VoiceSessionState listening() {
    return VoiceSessionState(
      state: VoiceCommandState.listening,
      conversationHistory: conversationHistory,
      metadata: metadata,
      data: data,
    );
  }

  /// 처리 중 상태
  VoiceSessionState processing(String input, {double? confidence}) {
    return VoiceSessionState(
      state: VoiceCommandState.processing,
      userInput: input,
      confidence: confidence,
      conversationHistory: conversationHistory,
      metadata: metadata,
      data: data,
    );
  }

  /// 음성 출력 중 상태
  VoiceSessionState speaking(
    String response, {
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? data,
  }) {
    return VoiceSessionState(
      state: VoiceCommandState.speaking,
      userInput: userInput,
      aiResponse: response,
      confidence: confidence,
      conversationHistory: conversationHistory,
      metadata: metadata ?? this.metadata,
      data: data ?? this.data,
    );
  }

  /// 완료 상태 (히스토리에 대화 추가)
  VoiceSessionState completed(String response) {
    final newHistory = [
      ...conversationHistory,
      if (userInput != null)
        ConversationEntry(userInput: userInput!, aiResponse: response),
    ];

    return VoiceSessionState(
      state: VoiceCommandState.completed,
      userInput: userInput,
      aiResponse: response,
      confidence: confidence,
      conversationHistory: newHistory,
      metadata: metadata,
      data: data,
    );
  }

  /// 에러 상태 (재시도 불가)
  VoiceSessionState error(String message) {
    return VoiceSessionState(
      state: VoiceCommandState.error,
      userInput: userInput,
      errorMessage: message,
      errorType: null, // 재시도 불가
      confidence: confidence,
      conversationHistory: conversationHistory,
      metadata: metadata,
      data: data,
    );
  }

  /// 재시도 가능한 에러 상태 (error_no_match, error_speech_timeout)
  VoiceSessionState errorWithRetry(String errorMsg) {
    final isNoMatch = errorMsg.contains('error_no_match');
    final isTimeout = errorMsg.contains('error_speech_timeout');

    if (isNoMatch || isTimeout) {
      final type = isNoMatch
          ? VoiceErrorType.speechNoMatch
          : VoiceErrorType.speechTimeout;
      final message = isNoMatch ? '음성을 인식하지 못했습니다.' : '음성 입력 시간이 초과되었습니다.';

      return VoiceSessionState(
        state: VoiceCommandState.error,
        userInput: userInput,
        errorMessage: message,
        errorType: type, // 재시도 가능
        confidence: confidence,
        conversationHistory: conversationHistory,
        metadata: metadata,
        data: data,
      );
    }

    // 재시도 불가능한 에러 (errorType = null)
    return error(errorMsg);
  }

  /// 상태 복사
  VoiceSessionState copyWith({
    VoiceCommandState? state,
    String? userInput,
    String? aiResponse,
    String? errorMessage,
    VoiceErrorType? errorType,
    double? confidence,
    List<ConversationEntry>? conversationHistory,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? data,
  }) {
    return VoiceSessionState(
      state: state ?? this.state,
      userInput: userInput ?? this.userInput,
      aiResponse: aiResponse ?? this.aiResponse,
      errorMessage: errorMessage ?? this.errorMessage,
      errorType: errorType ?? this.errorType,
      confidence: confidence ?? this.confidence,
      conversationHistory: conversationHistory ?? this.conversationHistory,
      metadata: metadata ?? this.metadata,
      data: data ?? this.data,
    );
  }
}
