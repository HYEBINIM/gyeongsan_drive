// UTF-8 인코딩 파일
// 한국어 주석: 음성 인식(STT) 서비스

import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../utils/app_logger.dart';
import '../../utils/constants.dart';
import 'wake_word_matcher.dart';

enum SpeechSessionBehavior { manualCommand, passiveWake, armedQuery }

/// 음성 인식 서비스 (Speech-to-Text)
/// speech_to_text 패키지를 래핑하여 사용
class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final WakeWordMatcher _wakeWordMatcher = const WakeWordMatcher();
  bool _isInitialized = false;
  // 한국어 주석: ViewModel로 에러/상태를 전달하기 위한 외부 리스너 및 결과 대기 플래그
  Function(String message)? _externalOnError;
  FutureOr<void> Function()? _externalOnNoResult;
  bool _awaitingFinalResult = false;
  bool _receivedFinalResult = false; // 한국어 주석: 최종 결과 수신 여부
  Timer? _statusCheckTimer; // 한국어 주석: status 기반 타임아웃 오검출 방지용 딜레이 타이머
  Timer? _internalStopGuardTimer;
  SpeechSessionBehavior _sessionBehavior = SpeechSessionBehavior.manualCommand;
  DateTime? _lastStopRequestedAt;
  bool _isInternalStopGuardActive = false;
  Completer<void>? _transitionCompleter;

  /// 초기화 여부
  bool get isInitialized => _isInitialized;

  /// 음성 인식 가능 여부
  bool get isAvailable => _speech.isAvailable;

  /// 현재 듣는 중인지 여부
  bool get isListening => _speech.isListening;

  /// 초기화
  /// 반환: 초기화 성공 시 true, 실패 시 false
  Future<bool> initialize() async {
    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          final message = error.errorMsg;
          if (_shouldIgnorePluginError(message)) {
            return;
          }
          _notifyError(message);
        },
        onStatus: (status) {
          // 한국어 주석: 일부 단말에서 notListening -> onResult(최종) 순서로 콜백이 올 수 있어
          // 오검출을 방지하기 위해 약간의 딜레이 후 최종 결과 수신 여부를 확인
          if (status == 'notListening' || status == 'done') {
            _statusCheckTimer?.cancel();
            _statusCheckTimer = Timer(const Duration(milliseconds: 350), () {
              if (_awaitingFinalResult &&
                  !_receivedFinalResult &&
                  !_speech.isListening) {
                _notifyNoResult();
              }
            });
          }
        },
      );

      return _isInitialized;
    } catch (e) {
      return false;
    }
  }

  /// 음성 인식 시작
  /// [onResult]: 음성 인식 결과 콜백 (텍스트, 신뢰도)
  /// [onError]: 에러 콜백
  /// [locale]: 언어 설정 (기본: 한국어 'ko_KR')
  Future<bool> startListening({
    required Function(String text, double confidence) onResult,
    Function(String error)? onError,
    FutureOr<void> Function()? onNoResult,
    String locale = AppConstants.voiceRecognitionLocale,
    Duration pauseFor = const Duration(seconds: 10),
    stt.ListenMode listenMode = stt.ListenMode.confirmation,
    bool partialResults = false,
    SpeechSessionBehavior behavior = SpeechSessionBehavior.manualCommand,
  }) async {
    return _runWithTransitionLock(() async {
      try {
        if (!_isInitialized) {
          final initialized = await initialize();
          if (!initialized) {
            onError?.call('음성 인식을 초기화할 수 없습니다.');
            return false;
          }
        }

        if (_speech.isListening) {
          return true;
        }

        await _waitForTransitionCooldownIfNeeded();

        _sessionBehavior = behavior;
        _externalOnError = onError;
        _externalOnNoResult = onNoResult;
        _awaitingFinalResult = true;
        _receivedFinalResult = false;
        _statusCheckTimer?.cancel();

        await _speech.listen(
          onResult: (result) {
            final text = result.recognizedWords.trim();
            final rawConfidence = result.confidence;
            final confidence = rawConfidence.isNaN || rawConfidence < 0
                ? 0.0
                : rawConfidence;
            final shouldHandlePartialWakeResult =
                behavior == SpeechSessionBehavior.passiveWake &&
                partialResults &&
                text.isNotEmpty &&
                _wakeWordMatcher.matchesWakePhrase(text);

            if (result.finalResult || shouldHandlePartialWakeResult) {
              _receivedFinalResult = true;
              _resetPendingResultState(clearHandlers: true);
              onResult(text, confidence);
            }
          },
          localeId: locale,
          pauseFor: pauseFor,
          listenOptions: stt.SpeechListenOptions(
            listenMode: listenMode,
            partialResults: partialResults,
            cancelOnError: true,
          ),
        );

        return true;
      } catch (e) {
        _resetPendingResultState(clearHandlers: true);
        onError?.call('음성 인식을 시작할 수 없습니다: $e');
        return false;
      }
    });
  }

  /// 음성 인식 중지
  Future<void> stopListening() async {
    await _runWithTransitionLock(() async {
      try {
        _beginInternalStopGuard();
        _resetPendingResultState(clearHandlers: true);
        if (_speech.isListening) {
          await _speech.stop();
        }
      } catch (e) {
        // 음성 인식 중지 실패
      }
    });
  }

  /// 음성 인식 취소
  Future<void> cancel() async {
    await _runWithTransitionLock(() async {
      try {
        _beginInternalStopGuard();
        _resetPendingResultState(clearHandlers: true);
        if (_speech.isListening) {
          await _speech.cancel();
        }
      } catch (e) {
        // 음성 인식 취소 실패
      }
    });
  }

  /// 지원되는 언어 목록 가져오기
  Future<List<stt.LocaleName>> getAvailableLocales() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      return await _speech.locales();
    } catch (e) {
      return [];
    }
  }

  /// 노이즈 필터링: 필러 단어 제거 및 정규화
  /// [text]: 원본 텍스트
  /// 반환: 정제된 텍스트
  String applyNoiseFilter(String text) {
    String filtered = text.trim();
    filtered = filtered.replaceAll(AppConstants.fillerWordsPattern, '');
    filtered = filtered.replaceAll(RegExp(r'\s+'), ' ');
    filtered = filtered.trim();

    if (filtered != text.trim()) {
      AppLogger.debug('🎤 [노이즈필터] 원본: "$text" -> 필터링: "$filtered"');
    }

    return filtered;
  }

  /// 음성 품질 검증
  /// [text]: 인식된 텍스트
  /// [confidence]: 신뢰도 (0.0 ~ 1.0)
  /// 반환: {isValid, reason}
  Map<String, dynamic> validateSpeechQuality(String text, double confidence) {
    if (confidence < AppConstants.voiceConfidenceThreshold) {
      return {
        'isValid': false,
        'reason': 'low_confidence',
        'message': '음성을 명확히 인식하지 못했습니다. 다시 말씀해주세요.',
        'confidence': confidence,
      };
    }

    final filteredText = applyNoiseFilter(text);
    if (filteredText.length < AppConstants.minRecognizedTextLength) {
      return {
        'isValid': false,
        'reason': 'noise_detected',
        'message': '음성이 너무 짧습니다. 다시 말씀해주세요.',
        'filteredText': filteredText,
      };
    }

    if (filteredText.isEmpty) {
      return {
        'isValid': false,
        'reason': 'noise_detected',
        'message': '유효한 음성을 인식하지 못했습니다. 다시 말씀해주세요.',
        'filteredText': filteredText,
      };
    }

    return {
      'isValid': true,
      'filteredText': filteredText,
      'confidence': confidence,
    };
  }

  Map<String, dynamic> validateWakeWordQuality(String text, double confidence) {
    final normalizedText = _wakeWordMatcher.normalizeWakeTranscript(text);
    if (normalizedText.isEmpty) {
      return {
        'isValid': false,
        'reason': 'noise_detected',
        'message': '유효한 호출어를 인식하지 못했습니다.',
        'filteredText': normalizedText,
      };
    }

    final matchedWakeWord = _wakeWordMatcher.matchesWakePhrase(normalizedText);
    if (matchedWakeWord &&
        confidence >= AppConstants.passiveWakeConfidenceThreshold) {
      return {
        'isValid': true,
        'filteredText': normalizedText,
        'confidence': confidence,
      };
    }

    if (matchedWakeWord &&
        normalizedText.length >=
            AppConstants.passiveWakeMinRecognizedTextLength) {
      return {
        'isValid': true,
        'filteredText': normalizedText,
        'confidence': confidence,
      };
    }

    if (confidence < AppConstants.passiveWakeConfidenceThreshold) {
      return {
        'isValid': false,
        'reason': 'low_confidence',
        'message': '호출어를 명확히 인식하지 못했습니다.',
        'confidence': confidence,
        'filteredText': normalizedText,
      };
    }

    return {
      'isValid': false,
      'reason': 'wake_word_mismatch',
      'message': '호출어가 감지되지 않았습니다.',
      'filteredText': normalizedText,
    };
  }

  /// 리소스 정리
  void dispose() {
    _resetPendingResultState(clearHandlers: true);
    _internalStopGuardTimer?.cancel();
    _speech.stop();
  }

  void _notifyError(String message) {
    final onError = _externalOnError;
    _resetPendingResultState(clearHandlers: true);
    onError?.call(message);
  }

  void _notifyNoResult() {
    final onNoResult = _externalOnNoResult;
    if (_sessionBehavior != SpeechSessionBehavior.manualCommand &&
        onNoResult != null) {
      _resetPendingResultState(clearHandlers: true);
      unawaited(Future<void>.sync(onNoResult));
      return;
    }

    _notifyError('error_speech_timeout');
  }

  void _resetPendingResultState({required bool clearHandlers}) {
    _awaitingFinalResult = false;
    _receivedFinalResult = false;
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;

    if (clearHandlers) {
      _externalOnError = null;
      _externalOnNoResult = null;
      _sessionBehavior = SpeechSessionBehavior.manualCommand;
    }
  }

  void _beginInternalStopGuard() {
    _lastStopRequestedAt = DateTime.now();
    _isInternalStopGuardActive = true;
    _internalStopGuardTimer?.cancel();
    _internalStopGuardTimer = Timer(
      Duration(milliseconds: AppConstants.speechTransitionCooldownMs),
      () {
        _isInternalStopGuardActive = false;
      },
    );
  }

  bool _shouldIgnorePluginError(String message) {
    if (!_isInternalStopGuardActive) {
      return false;
    }

    return message == 'error_client' || message == 'error_speech_timeout';
  }

  Future<void> _waitForTransitionCooldownIfNeeded() async {
    final lastStopRequestedAt = _lastStopRequestedAt;
    if (lastStopRequestedAt == null) {
      return;
    }

    final elapsedMs = DateTime.now()
        .difference(lastStopRequestedAt)
        .inMilliseconds;
    final remainingMs = AppConstants.speechTransitionCooldownMs - elapsedMs;
    if (remainingMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: remainingMs));
    }
  }

  Future<T> _runWithTransitionLock<T>(Future<T> Function() operation) async {
    while (_transitionCompleter != null) {
      await _transitionCompleter!.future;
    }

    final completer = Completer<void>();
    _transitionCompleter = completer;

    try {
      return await operation();
    } finally {
      _transitionCompleter = null;
      completer.complete();
    }
  }
}
