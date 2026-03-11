// UTF-8 인코딩 파일
// 한국어 주석: 음성 명령 ViewModel (MVVM 패턴)

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../models/navigation/route_model.dart';
import '../../models/vehicle_info_model.dart';
import '../../models/voice/rule_voice_intent.dart';
import '../../models/voice/voice_command_request.dart';
import '../../models/voice/voice_state.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../services/permission/permission_service.dart';
import '../../services/vehicle/firestore_vehicle_service.dart';
import '../../services/voice/navigation_context_resolver.dart';
import '../../services/voice/rule_vehicle_voice_service.dart';
import '../../services/voice/rule_voice_intent_matcher.dart';
import '../../services/voice/speech_service.dart';
import '../../services/voice/tts_service.dart';
import '../../services/voice/voice_command_service.dart';
import '../../services/voice/voice_cue_service.dart';
import '../../services/voice/wake_word_matcher.dart';
import '../../utils/app_logger.dart';
import '../../utils/constants.dart';

/// 음성 명령 ViewModel
/// 음성 인식, AI 처리, 음성 출력을 통합 관리
class VoiceCommandViewModel extends ChangeNotifier {
  final SpeechService _speechService;
  final TTSService _ttsService;
  final VoiceCommandService? _apiService;
  final PermissionService _permissionService;
  final NavigationContextResolver _navigationResolver;
  final FirebaseAuthService? _authService;
  final FirestoreVehicleService? _vehicleService;
  final RuleVehicleVoiceService _ruleVehicleVoiceService;
  final WakeWordMatcher _wakeWordMatcher;
  final RuleVoiceIntentMatcher _ruleVoiceIntentMatcher;
  final VoiceCueService _voiceCueService;

  void Function(LocationInfo destination)? onNavigationRequested;

  VoiceSessionState _sessionState = VoiceSessionState.initial();
  bool _isHandlingCommand = false;
  String? _lastRecognizedText;
  String? _lastSentQuery;
  bool _turnCommitted = false;
  Timer? _pendingErrorTimer;
  Timer? _listeningTimeoutTimer;
  int _listeningSessionId = 0;
  int _commandSessionId = 0;
  String? _activeVehicleMtId;
  int _lowConfidenceRetryCount = 0;

  Timer? _passiveRestartTimer;
  Timer? _passiveListeningTimeoutTimer;
  int _passiveWakeSessionId = 0;
  bool _passiveWakeEnabled = false;
  bool _passiveWakePaused = false;
  bool _isPassiveWakeListening = false;
  bool _isArmedQueryListening = false;
  bool _isManualSessionActive = false;
  bool _isPassiveTtsSpeaking = false;
  bool _isSyncingPassiveAvailability = false;
  int _passiveWakeClientErrorCount = 0;
  int? _lastScheduledPassiveWakeRestartDelayMs;
  DateTime? _lastPassiveWakeErrorLogAt;

  VoiceCommandViewModel({
    SpeechService? speechService,
    TTSService? ttsService,
    VoiceCommandService? apiService,
    PermissionService? permissionService,
    FirebaseAuthService? authService,
    FirestoreVehicleService? vehicleService,
    RuleVehicleVoiceService? ruleVehicleVoiceService,
    WakeWordMatcher? wakeWordMatcher,
    RuleVoiceIntentMatcher? ruleVoiceIntentMatcher,
    VoiceCueService? voiceCueService,
    required NavigationContextResolver navigationResolver,
  }) : _speechService = speechService ?? SpeechService(),
       _ttsService = ttsService ?? TTSService(),
       _apiService = apiService,
       _permissionService = permissionService ?? PermissionService(),
       _authService = authService,
       _vehicleService = vehicleService,
       _ruleVehicleVoiceService =
           ruleVehicleVoiceService ?? RuleVehicleVoiceService(),
       _wakeWordMatcher = wakeWordMatcher ?? const WakeWordMatcher(),
       _ruleVoiceIntentMatcher =
           ruleVoiceIntentMatcher ?? const RuleVoiceIntentMatcher(),
       _voiceCueService = voiceCueService ?? VoiceCueService(),
       _navigationResolver = navigationResolver;

  VoiceSessionState get sessionState => _sessionState;
  VoiceCommandState get state => _sessionState.state;
  String? get userInput => _sessionState.userInput;
  String? get aiResponse => _sessionState.aiResponse;
  String? get errorMessage => _sessionState.errorMessage;
  double? get confidence => _sessionState.confidence;
  List<ConversationEntry> get conversationHistory =>
      _sessionState.conversationHistory;
  bool get isListening => _state == VoiceCommandState.listening;
  bool get isProcessing => _state == VoiceCommandState.processing;
  bool get isSpeaking => _state == VoiceCommandState.speaking;
  bool get hasError => _state == VoiceCommandState.error;
  bool get isPassiveWakeListening => _isPassiveWakeListening;
  bool get isArmedQueryListening => _isArmedQueryListening;
  bool get isManualSessionActive => _isManualSessionActive;
  bool get shouldShowWakeQueryModal =>
      _isArmedQueryListening &&
      !_isManualSessionActive &&
      _state != VoiceCommandState.processing &&
      _state != VoiceCommandState.speaking &&
      _state != VoiceCommandState.completed &&
      _state != VoiceCommandState.error;

  @visibleForTesting
  int get passiveWakeClientErrorCountForTest => _passiveWakeClientErrorCount;

  @visibleForTesting
  int? get lastScheduledPassiveWakeRestartDelayMsForTest =>
      _lastScheduledPassiveWakeRestartDelayMs;

  String? get vehicleQueryPrefix {
    final prefix = _activeVehicleMtId == null || _activeVehicleMtId!.isEmpty
        ? null
        : '차량 $_activeVehicleMtId의';
    return prefix;
  }

  String? get activeVehicleMtId => _activeVehicleMtId;
  VoiceCommandState get _state => _sessionState.state;

  void updateActiveVehicle(VehicleInfo? vehicle) {
    final nextMtId = vehicle?.mtId;
    if (_activeVehicleMtId == nextMtId) {
      return;
    }

    AppLogger.debug(
      '🎤 [음성명령] 활성 차량 업데이트: ${vehicle?.vehicleNumber ?? "없음"} (MT_ID: ${nextMtId ?? "없음"})',
    );

    _activeVehicleMtId = nextMtId;
    if (_activeVehicleMtId == null || _activeVehicleMtId!.isEmpty) {
      // ignore: discarded_futures
      stopPassiveWakeListening(clearEnabled: false);
      return;
    }

    if (_passiveWakeEnabled && !_passiveWakePaused && !_isManualSessionActive) {
      // ignore: discarded_futures
      _startPassiveWakeListeningIfEligible();
    }
  }

  int _nextCommandSessionId() {
    _commandSessionId += 1;
    return _commandSessionId;
  }

  bool _isActiveSession(int sessionId) => sessionId == _commandSessionId;

  void _invalidateSession() {
    _commandSessionId += 1;
  }

  int _nextPassiveWakeSessionId() {
    _passiveWakeSessionId += 1;
    return _passiveWakeSessionId;
  }

  bool _isActivePassiveWakeSession(int sessionId) {
    return sessionId == _passiveWakeSessionId;
  }

  void _invalidatePassiveWakeSession() {
    _passiveWakeSessionId += 1;
  }

  Future<void> initialize() async {
    try {
      final hasPermission = await _permissionService
          .requestMicrophonePermission();
      if (!hasPermission) {
        _updateState(_sessionState.error('마이크 권한이 거부되었습니다.'));
        return;
      }

      final speechInitialized = await _speechService.initialize();
      if (!speechInitialized) {
        _updateState(_sessionState.error('음성 인식을 초기화할 수 없습니다.'));
        return;
      }

      await _ttsService.initialize();
    } catch (_) {
      _updateState(_sessionState.error('초기화 중 오류가 발생했습니다.'));
    }
  }

  Future<void> syncPassiveWakeAvailability({
    required bool isForeground,
    required bool isAuthenticated,
  }) async {
    if (_isSyncingPassiveAvailability) {
      return;
    }

    _isSyncingPassiveAvailability = true;
    try {
      if (!isForeground || !isAuthenticated) {
        await stopPassiveWakeListening();
        return;
      }

      await startPassiveWakeListening();
    } finally {
      _isSyncingPassiveAvailability = false;
    }
  }

  Future<void> startPassiveWakeListening() async {
    _passiveWakeEnabled = true;
    _passiveWakePaused = false;
    await _startPassiveWakeListeningIfEligible();
  }

  Future<void> stopPassiveWakeListening({bool clearEnabled = true}) async {
    if (clearEnabled) {
      _passiveWakeEnabled = false;
      _passiveWakePaused = false;
    }
    _cancelPassiveWakeTimers();
    _invalidatePassiveWakeSession();
    await _stopPassiveListeningIfNeeded();
  }

  Future<void> pausePassiveWakeListening() async {
    _passiveWakePaused = true;
    _cancelPassiveWakeTimers();
    _invalidatePassiveWakeSession();
    await _stopPassiveListeningIfNeeded();
  }

  Future<void> resumePassiveWakeListeningIfEligible() async {
    if (!_passiveWakeEnabled) {
      return;
    }

    _passiveWakePaused = false;
    await _startPassiveWakeListeningIfEligible();
  }

  Future<void> endManualSession() async {
    if (!_isManualSessionActive) {
      return;
    }

    _isManualSessionActive = false;
    notifyListeners();
    await _startPassiveWakeListeningIfEligible();
  }

  Future<void> dismissWakeQueryModal() async {
    if (!_isArmedQueryListening) {
      return;
    }

    _invalidatePassiveWakeSession();
    _cancelPassiveWakeTimers();
    await _speechService.stopListening();
    _setPassiveListeningState(wakeListening: false, armedQueryListening: false);
    await _startPassiveWakeListeningIfEligible();
  }

  Future<void> startVoiceCommand({required String queryPrefix}) async {
    AppLogger.debug('🎤 [음성명령] 음성 명령 시작: queryPrefix = $queryPrefix');

    final sessionId = _nextCommandSessionId();

    try {
      if (!_isManualSessionActive) {
        _isManualSessionActive = true;
        await pausePassiveWakeListening();
        notifyListeners();
      }

      _isHandlingCommand = false;
      _lastRecognizedText = null;
      _lastSentQuery = null;
      _pendingErrorTimer?.cancel();
      _pendingErrorTimer = null;
      _listeningTimeoutTimer?.cancel();
      _listeningTimeoutTimer = null;
      _lowConfidenceRetryCount = 0;

      if (isSpeaking || _isPassiveTtsSpeaking) {
        await stopSpeaking();
      }

      _updateState(_sessionState.listening(), sessionId: sessionId);
      _listeningSessionId += 1;
      final currentSessionId = _listeningSessionId;
      _pendingErrorTimer?.cancel();
      _pendingErrorTimer = null;
      _listeningTimeoutTimer?.cancel();
      _listeningTimeoutTimer = Timer(
        Duration(milliseconds: AppConstants.voiceListeningTimeoutMs),
        () async {
          final stillSameSession = currentSessionId == _listeningSessionId;
          final isStillListening =
              _sessionState.state == VoiceCommandState.listening;
          if (!stillSameSession ||
              _isHandlingCommand ||
              !isStillListening ||
              !_isActiveSession(sessionId)) {
            return;
          }

          await _speechService.stopListening();
          _isHandlingCommand = false;
          _updateState(
            _sessionState.errorWithRetry('error_speech_timeout'),
            sessionId: sessionId,
          );
        },
      );

      final started = await _speechService.startListening(
        onResult: (text, confidence) async {
          final cleaned = text.trim();
          if (cleaned.isEmpty) {
            return;
          }
          if (_isHandlingCommand) {
            return;
          }
          if (_lastRecognizedText == cleaned) {
            return;
          }
          if (!_isActiveSession(sessionId)) {
            return;
          }

          _isHandlingCommand = true;
          _lastRecognizedText = cleaned;
          _pendingErrorTimer?.cancel();
          _pendingErrorTimer = null;
          _listeningTimeoutTimer?.cancel();

          final validation = _speechService.validateSpeechQuality(
            cleaned,
            confidence,
          );

          if (!validation['isValid']) {
            final reason = validation['reason'] as String;
            final message = validation['message'] as String;

            if (reason == 'low_confidence') {
              _lowConfidenceRetryCount += 1;

              AppLogger.debug(
                '🎤 [음성명령] 낮은 신뢰도 (${(confidence * 100).toStringAsFixed(1)}%) - 재시도 $_lowConfidenceRetryCount/${AppConstants.maxLowConfidenceRetries}',
              );

              if (_lowConfidenceRetryCount >=
                  AppConstants.maxLowConfidenceRetries) {
                _updateState(
                  _sessionState.copyWith(
                    state: VoiceCommandState.error,
                    errorMessage: '음성 인식 정확도가 낮습니다. 조용한 곳에서 다시 시도해주세요.',
                    errorType: VoiceErrorType.lowConfidence,
                  ),
                  sessionId: sessionId,
                );
                _lowConfidenceRetryCount = 0;
                _isHandlingCommand = false;
                return;
              }

              _updateState(
                _sessionState.copyWith(
                  state: VoiceCommandState.error,
                  errorMessage:
                      '$message (신뢰도: ${(confidence * 100).toStringAsFixed(0)}%)',
                  errorType: VoiceErrorType.lowConfidence,
                ),
                sessionId: sessionId,
              );
              _isHandlingCommand = false;
              return;
            }

            if (reason == 'noise_detected') {
              AppLogger.debug('🎤 [음성명령] 노이즈 감지: "$cleaned"');

              _updateState(
                _sessionState.copyWith(
                  state: VoiceCommandState.error,
                  errorMessage: message,
                  errorType: VoiceErrorType.noiseDetected,
                ),
                sessionId: sessionId,
              );
              _isHandlingCommand = false;
              return;
            }
          }

          final filteredText = validation['filteredText'] as String;
          _lowConfidenceRetryCount = 0;

          AppLogger.debug(
            '🎤 [음성명령] 음성 인식 성공: "$filteredText" (신뢰도: ${(confidence * 100).toStringAsFixed(1)}%)',
          );

          final query = '$queryPrefix $filteredText';
          await _processVoiceCommand(
            filteredText,
            query: query,
            confidence: confidence,
            sessionId: sessionId,
          );
        },
        onError: (error) {
          _pendingErrorTimer?.cancel();
          _pendingErrorTimer = Timer(const Duration(milliseconds: 500), () {
            final stillSameSession = currentSessionId == _listeningSessionId;
            final isStillListening =
                _sessionState.state == VoiceCommandState.listening;
            if (stillSameSession &&
                !_isHandlingCommand &&
                isStillListening &&
                _isActiveSession(sessionId)) {
              _updateState(
                _sessionState.errorWithRetry(error),
                sessionId: sessionId,
              );
            }
            _isHandlingCommand = false;
          });
        },
        behavior: SpeechSessionBehavior.manualCommand,
      );

      if (!started) {
        _listeningTimeoutTimer?.cancel();
        _listeningTimeoutTimer = null;
        _updateState(
          _sessionState.error('음성 인식을 시작할 수 없습니다.'),
          sessionId: sessionId,
        );
      }
    } catch (_) {
      _listeningTimeoutTimer?.cancel();
      _listeningTimeoutTimer = null;
      _pendingErrorTimer?.cancel();
      _pendingErrorTimer = null;
      _updateState(
        _sessionState.error('음성 명령을 처리할 수 없습니다.'),
        sessionId: sessionId,
      );
    }
  }

  Future<void> _processVoiceCommand(
    String userText, {
    required String query,
    required double confidence,
    required int sessionId,
  }) async {
    try {
      if (!_isActiveSession(sessionId)) {
        return;
      }

      await _speechService.stopListening();
      _listeningTimeoutTimer?.cancel();

      if (!_isActiveSession(sessionId)) {
        return;
      }

      if (_navigationResolver.isNavigationRequest(userText)) {
        await _handleNavigationRequest(userText, sessionId: sessionId);
        return;
      }

      _updateState(
        _sessionState.processing(userText, confidence: confidence),
        sessionId: sessionId,
      );

      if (_lastSentQuery == query) {
        return;
      }
      _lastSentQuery = query;

      final request = VoiceCommandRequest(query: query);
      final apiService = _apiService ?? VoiceCommandService();
      final response = await apiService.sendCommand(request);

      if (!_isActiveSession(sessionId)) {
        return;
      }

      if (response.success) {
        final metadata = response.data?['metadata'] as Map<String, dynamic>?;
        await _speakResponse(
          response.responseText,
          metadata: metadata,
          data: response.data,
          sessionId: sessionId,
        );
      } else {
        _updateState(
          _sessionState.error(response.errorMessage ?? '요청 처리에 실패했습니다.'),
          sessionId: sessionId,
        );
      }
    } catch (_) {
      if (_isActiveSession(sessionId)) {
        _updateState(
          _sessionState.error('음성 처리 중 오류가 발생했습니다.'),
          sessionId: sessionId,
        );
      }
    } finally {
      _isHandlingCommand = false;
    }
  }

  Future<void> _handleNavigationRequest(
    String userText, {
    required int sessionId,
  }) async {
    if (!_isActiveSession(sessionId)) {
      return;
    }

    _updateState(
      _sessionState.processing(userText, confidence: 1.0),
      sessionId: sessionId,
    );

    try {
      final metadata =
          _sessionState.metadata ??
          (_sessionState.data?['metadata'] as Map<String, dynamic>?);
      AppLogger.debug(
        '🎤 [길안내] metadata: ${metadata ?? "없음"}, data keys: ${_sessionState.data?.keys.toList()}',
      );
      final destination = await _navigationResolver
          .extractDestinationFromMetadata(metadata);

      if (destination == null) {
        final hasMetadata = metadata != null;
        final errorMsg = hasMetadata
            ? '죄송합니다. 해당 주소의 위치를 찾지 못했습니다. 다시 검색 후 시도해주세요.'
            : '이전에 검색한 장소가 없습니다. 먼저 장소를 검색해주세요.';
        await _speakResponse(errorMsg, sessionId: sessionId);
        return;
      }

      const successMsg = '길 안내를 시작합니다.';
      await _speakResponse(
        successMsg,
        metadata: metadata,
        data: _sessionState.data,
        sessionId: sessionId,
      );

      onNavigationRequested?.call(destination);
    } catch (e) {
      AppLogger.debug('🎤 [길안내] 처리 중 예외: $e');
      await _speakResponse(
        '길 안내 준비 중 오류가 발생했습니다. 다시 시도해주세요.',
        sessionId: sessionId,
      );
    }
  }

  Future<void> _speakResponse(
    String responseText, {
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? data,
    required int sessionId,
  }) async {
    try {
      if (!_isActiveSession(sessionId)) {
        return;
      }

      _turnCommitted = false;
      _updateState(
        _sessionState.speaking(responseText, metadata: metadata, data: data),
        sessionId: sessionId,
      );
      await _ttsService.speak(responseText);
      if (!_isActiveSession(sessionId)) {
        return;
      }
      _completeTurn(responseText, sessionId: sessionId);
    } catch (_) {
      if (_isActiveSession(sessionId)) {
        _updateState(
          _sessionState.error('음성 출력 중 오류가 발생했습니다.'),
          sessionId: sessionId,
        );
      }
    }
  }

  Future<void> stopListening() async {
    try {
      _invalidateSession();
      await _speechService.stopListening();
      _listeningTimeoutTimer?.cancel();
      _listeningTimeoutTimer = null;
      _pendingErrorTimer?.cancel();
      _pendingErrorTimer = null;
      _updateState(VoiceSessionState.initial());
    } catch (_) {
      // manual stop failure is ignored
    }
  }

  Future<void> stopSpeaking() async {
    try {
      if (_isPassiveTtsSpeaking) {
        _isPassiveTtsSpeaking = false;
        await _ttsService.stop();
        notifyListeners();
        await _startPassiveWakeListeningIfEligible();
        return;
      }

      _invalidateSession();
      await _ttsService.stop();
      if (_sessionState.aiResponse != null) {
        _completeTurn(_sessionState.aiResponse!, sessionId: _commandSessionId);
      } else {
        _updateState(VoiceSessionState.initial());
      }
    } catch (_) {
      // manual stop failure is ignored
    }
  }

  void reset() {
    _invalidateSession();
    _isHandlingCommand = false;
    _lastRecognizedText = null;
    _lastSentQuery = null;
    _turnCommitted = false;
    _lowConfidenceRetryCount = 0;
    _pendingErrorTimer?.cancel();
    _pendingErrorTimer = null;
    _listeningTimeoutTimer?.cancel();
    _listeningTimeoutTimer = null;
    _updateState(VoiceSessionState.initial());
  }

  void _updateState(VoiceSessionState newState, {int? sessionId}) {
    if (sessionId != null && !_isActiveSession(sessionId)) {
      return;
    }
    _sessionState = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _invalidateSession();
    _invalidatePassiveWakeSession();
    _isHandlingCommand = false;
    _lastRecognizedText = null;
    _lastSentQuery = null;
    _turnCommitted = false;
    _lowConfidenceRetryCount = 0;
    _pendingErrorTimer?.cancel();
    _pendingErrorTimer = null;
    _listeningTimeoutTimer?.cancel();
    _listeningTimeoutTimer = null;
    _cancelPassiveWakeTimers();
    _speechService.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  void _completeTurn(String responseText, {required int sessionId}) {
    if (_turnCommitted || !_isActiveSession(sessionId)) {
      return;
    }
    _updateState(_sessionState.completed(responseText), sessionId: sessionId);
    _turnCommitted = true;
  }

  @visibleForTesting
  Future<void> processVoiceCommandForTest(
    String userText, {
    required String query,
    double confidence = 1.0,
    int sessionId = 0,
  }) async {
    await _processVoiceCommand(
      userText,
      query: query,
      confidence: confidence,
      sessionId: sessionId,
    );
  }

  @visibleForTesting
  Future<void> handleWakePhraseForTest(String text) async {
    final normalized = _wakeWordMatcher.stripWakeWordPrefix(text);
    if (!_wakeWordMatcher.matchesWakePhrase(text)) {
      return;
    }

    _passiveWakeEnabled = true;
    _passiveWakePaused = false;
    _setPassiveListeningState(wakeListening: false, armedQueryListening: false);
    await _voiceCueService.playWakeAcknowledgement();
    _setPassiveListeningState(wakeListening: false, armedQueryListening: true);
    if (normalized.isEmpty) {
      return;
    }
  }

  @visibleForTesting
  Future<void> handleWakeTranscriptForTest(
    String text, {
    double confidence = 1.0,
  }) async {
    _passiveWakeEnabled = true;
    _passiveWakePaused = false;
    final sessionId = _nextPassiveWakeSessionId();
    await _handlePassiveWakeTranscript(
      text,
      confidence: confidence,
      sessionId: sessionId,
    );
  }

  @visibleForTesting
  Future<void> handleArmedQueryForTest(
    String text, {
    double confidence = 1.0,
  }) async {
    _passiveWakeEnabled = true;
    _passiveWakePaused = false;
    final sessionId = _nextPassiveWakeSessionId();
    await _handleArmedQueryTranscript(
      text,
      confidence: confidence,
      sessionId: sessionId,
    );
  }

  @visibleForTesting
  Future<void> handlePassiveWakeNoResultForTest() async {
    _passiveWakeEnabled = true;
    _passiveWakePaused = false;
    final sessionId = _nextPassiveWakeSessionId();
    _setPassiveListeningState(wakeListening: true, armedQueryListening: false);
    await _handlePassiveWakeNoResult(sessionId: sessionId);
  }

  @visibleForTesting
  Future<void> handlePassiveWakeErrorForTest(String error) async {
    _passiveWakeEnabled = true;
    _passiveWakePaused = false;
    final sessionId = _nextPassiveWakeSessionId();
    _setPassiveListeningState(wakeListening: true, armedQueryListening: false);
    await _handlePassiveWakeError(error, sessionId: sessionId);
  }

  @visibleForTesting
  Future<void> handleArmedQueryNoResultForTest() async {
    _passiveWakeEnabled = true;
    _passiveWakePaused = false;
    final sessionId = _nextPassiveWakeSessionId();
    _setPassiveListeningState(wakeListening: false, armedQueryListening: true);
    await _handleArmedQueryNoResult(sessionId: sessionId);
  }

  Future<void> _startPassiveWakeListeningIfEligible() async {
    if (!_passiveWakeEnabled ||
        _passiveWakePaused ||
        _isManualSessionActive ||
        _isPassiveWakeListening ||
        _isArmedQueryListening ||
        _speechService.isListening ||
        _isPassiveTtsSpeaking ||
        _ttsService.isSpeaking) {
      return;
    }

    final permissionStatus = await _permissionService
        .getMicrophonePermissionStatus();
    if (permissionStatus != PermissionStatus.granted) {
      return;
    }

    if (!_speechService.isInitialized) {
      final initialized = await _speechService.initialize();
      if (!initialized) {
        return;
      }
    }

    final hasActiveVehicle = await _ensureActiveVehicleLoaded();
    if (!hasActiveVehicle) {
      return;
    }

    final sessionId = _nextPassiveWakeSessionId();
    _setPassiveListeningState(wakeListening: true, armedQueryListening: false);
    _lastScheduledPassiveWakeRestartDelayMs = null;

    _passiveListeningTimeoutTimer?.cancel();
    _passiveListeningTimeoutTimer = Timer(
      Duration(milliseconds: AppConstants.passiveWakeListeningTimeoutMs),
      () async {
        if (!_isActivePassiveWakeSession(sessionId) ||
            !_isPassiveWakeListening) {
          return;
        }
        await _stopPassiveListeningIfNeeded();
        _schedulePassiveWakeRestart();
      },
    );

    final started = await _speechService.startListening(
      onResult: (text, confidence) async {
        await _handlePassiveWakeTranscript(
          text,
          confidence: confidence,
          sessionId: sessionId,
        );
      },
      onNoResult: () async {
        await _handlePassiveWakeNoResult(sessionId: sessionId);
      },
      onError: (error) async {
        await _handlePassiveWakeError(error, sessionId: sessionId);
      },
      pauseFor: Duration(seconds: AppConstants.passiveWakePauseSeconds),
      listenMode: stt.ListenMode.dictation,
      partialResults: AppConstants.passiveWakePartialResults,
      behavior: SpeechSessionBehavior.passiveWake,
    );

    if (!started) {
      await _stopPassiveListeningIfNeeded();
      if (_lastScheduledPassiveWakeRestartDelayMs != null) {
        return;
      }
      _schedulePassiveWakeRestart(
        delayMs: _nextPassiveWakeClientErrorDelayMs(),
      );
      return;
    }

    _resetPassiveWakeErrorBackoff();
  }

  Future<void> _handlePassiveWakeTranscript(
    String text, {
    required double confidence,
    required int sessionId,
  }) async {
    if (!_isActivePassiveWakeSession(sessionId)) {
      return;
    }

    _passiveListeningTimeoutTimer?.cancel();
    final normalizedText = _wakeWordMatcher.normalizeWakeTranscript(text);
    final validation = _speechService.validateWakeWordQuality(
      normalizedText,
      confidence,
    );
    if (validation['isValid'] != true) {
      AppLogger.debug(
        '🎤 [호출어] wake mismatch: raw="$text", normalized="$normalizedText", reason=${validation['reason']}',
      );
      await _stopPassiveListeningIfNeeded();
      _schedulePassiveWakeRestart();
      return;
    }

    final filteredText = validation['filteredText'] as String;
    if (!_wakeWordMatcher.matchesWakePhrase(filteredText)) {
      await _stopPassiveListeningIfNeeded();
      _schedulePassiveWakeRestart();
      return;
    }

    _resetPassiveWakeErrorBackoff();
    await _stopPassiveListeningIfNeeded();
    if (!_isActivePassiveWakeSession(sessionId)) {
      return;
    }

    await _voiceCueService.playWakeAcknowledgement();
    await _startArmedQueryListening();
  }

  Future<void> _handlePassiveWakeNoResult({required int sessionId}) async {
    if (!_isActivePassiveWakeSession(sessionId)) {
      return;
    }

    _passiveListeningTimeoutTimer?.cancel();
    await _stopPassiveListeningIfNeeded();
    _schedulePassiveWakeRestart();
  }

  Future<void> _handlePassiveWakeError(
    String error, {
    required int sessionId,
  }) async {
    if (!_isActivePassiveWakeSession(sessionId)) {
      return;
    }

    _passiveListeningTimeoutTimer?.cancel();
    if (error == 'error_speech_timeout') {
      await _stopPassiveListeningIfNeeded();
      _schedulePassiveWakeRestart();
      return;
    }

    if (error == 'error_client') {
      final delayMs = _nextPassiveWakeClientErrorDelayMs();
      await _stopPassiveListeningIfNeeded();
      _schedulePassiveWakeRestart(delayMs: delayMs);
      if (_shouldLogPassiveWakeError()) {
        AppLogger.debug('🎤 [호출어] passive listen transient error: $error');
      }
      return;
    }

    await _stopPassiveListeningIfNeeded();
    _schedulePassiveWakeRestart(delayMs: _nextPassiveWakeClientErrorDelayMs());
    if (_shouldLogPassiveWakeError()) {
      AppLogger.warning('🎤 [호출어] passive listen unexpected error: $error');
    }
  }

  Future<void> _startArmedQueryListening() async {
    if (!_passiveWakeEnabled ||
        _passiveWakePaused ||
        _isManualSessionActive ||
        _speechService.isListening) {
      return;
    }

    final sessionId = _nextPassiveWakeSessionId();
    _setPassiveListeningState(wakeListening: false, armedQueryListening: true);
    _lastScheduledPassiveWakeRestartDelayMs = null;

    _passiveListeningTimeoutTimer?.cancel();
    _passiveListeningTimeoutTimer = Timer(
      Duration(milliseconds: AppConstants.armedQueryListeningTimeoutMs),
      () async {
        if (!_isActivePassiveWakeSession(sessionId) ||
            !_isArmedQueryListening) {
          return;
        }
        await _stopPassiveListeningIfNeeded();
        await _speakPassivePrompt(AppConstants.passiveWakeNoQuestionMessage);
      },
    );

    final started = await _speechService.startListening(
      onResult: (text, confidence) async {
        await _handleArmedQueryTranscript(
          text,
          confidence: confidence,
          sessionId: sessionId,
        );
      },
      onNoResult: () async {
        await _handleArmedQueryNoResult(sessionId: sessionId);
      },
      onError: (error) async {
        await _handleArmedQueryError(error, sessionId: sessionId);
      },
      pauseFor: Duration(seconds: AppConstants.armedQueryPauseSeconds),
      behavior: SpeechSessionBehavior.armedQuery,
    );

    if (!started) {
      await _stopPassiveListeningIfNeeded();
      await _speakPassivePrompt(AppConstants.passiveWakeNoQuestionMessage);
    }
  }

  Future<void> _handleArmedQueryTranscript(
    String text, {
    required double confidence,
    required int sessionId,
  }) async {
    if (!_isActivePassiveWakeSession(sessionId)) {
      return;
    }

    _passiveListeningTimeoutTimer?.cancel();
    final validation = _speechService.validateSpeechQuality(text, confidence);
    if (validation['isValid'] != true) {
      await _stopPassiveListeningIfNeeded();
      await _speakPassivePrompt(AppConstants.passiveWakeNoQuestionMessage);
      return;
    }

    final filteredText = validation['filteredText'] as String;
    final normalizedQuery = _wakeWordMatcher.stripWakeWordPrefix(filteredText);
    if (normalizedQuery.isEmpty) {
      await _stopPassiveListeningIfNeeded();
      await _speakPassivePrompt(AppConstants.passiveWakeNoQuestionMessage);
      return;
    }

    await _stopPassiveListeningIfNeeded();
    await _processRuleVehicleQuery(normalizedQuery);
  }

  Future<void> _handleArmedQueryError(
    String error, {
    required int sessionId,
  }) async {
    if (!_isActivePassiveWakeSession(sessionId)) {
      return;
    }

    _passiveListeningTimeoutTimer?.cancel();
    if (error == 'error_speech_timeout') {
      await _stopPassiveListeningIfNeeded();
      await _speakPassivePrompt(AppConstants.passiveWakeNoQuestionMessage);
      return;
    }

    await _stopPassiveListeningIfNeeded();
    await _speakPassivePrompt(AppConstants.passiveWakeNoQuestionMessage);
    AppLogger.debug('🎤 [호출어] armed query error: $error');
  }

  Future<void> _handleArmedQueryNoResult({required int sessionId}) async {
    if (!_isActivePassiveWakeSession(sessionId)) {
      return;
    }

    _passiveListeningTimeoutTimer?.cancel();
    await _stopPassiveListeningIfNeeded();
    await _speakPassivePrompt(AppConstants.passiveWakeNoQuestionMessage);
  }

  Future<void> _processRuleVehicleQuery(String userText) async {
    final intent = _ruleVoiceIntentMatcher.match(userText);
    if (intent == RuleVoiceIntent.unsupported) {
      await _speakPassivePrompt(AppConstants.passiveWakeUnsupportedMessage);
      return;
    }

    final hasActiveVehicle = await _ensureActiveVehicleLoaded();
    if (!hasActiveVehicle || _activeVehicleMtId == null) {
      await _speakPassivePrompt(
        AppConstants.passiveWakeVehicleUnavailableMessage,
      );
      return;
    }

    try {
      final response = await _ruleVehicleVoiceService.buildResponse(
        intent: intent,
        mtId: _activeVehicleMtId!,
      );
      await _speakPassivePrompt(response);
    } catch (e) {
      AppLogger.debug('🎤 [호출어] rule voice fetch failed: $e');
      await _speakPassivePrompt(AppConstants.passiveWakeFetchFailedMessage);
    }
  }

  Future<void> _speakPassivePrompt(String message) async {
    _isPassiveTtsSpeaking = true;
    notifyListeners();
    try {
      await _ttsService.speak(message);
    } catch (_) {
      // passive TTS는 실패해도 재대기를 막지 않는다.
    } finally {
      _isPassiveTtsSpeaking = false;
      notifyListeners();
      await _startPassiveWakeListeningIfEligible();
    }
  }

  Future<bool> _ensureActiveVehicleLoaded() async {
    final authService = _authService;
    final vehicleService = _vehicleService;
    if (authService == null || vehicleService == null) {
      return _activeVehicleMtId != null && _activeVehicleMtId!.isNotEmpty;
    }

    final currentUser = authService.currentUser;
    if (currentUser == null) {
      updateActiveVehicle(null);
      return false;
    }

    if (_activeVehicleMtId != null && _activeVehicleMtId!.isNotEmpty) {
      return true;
    }

    try {
      final vehicle = await vehicleService.getUserActiveVehicle(
        currentUser.uid,
      );
      updateActiveVehicle(vehicle);
      return _activeVehicleMtId != null && _activeVehicleMtId!.isNotEmpty;
    } catch (e) {
      AppLogger.debug('🎤 [호출어] 활성 차량 동기화 실패: $e');
      return false;
    }
  }

  Future<void> _stopPassiveListeningIfNeeded() async {
    await _speechService.stopListening();
    _setPassiveListeningState(wakeListening: false, armedQueryListening: false);
  }

  void _schedulePassiveWakeRestart({int? delayMs}) {
    _passiveRestartTimer?.cancel();
    if (!_passiveWakeEnabled ||
        _passiveWakePaused ||
        _isManualSessionActive ||
        _isPassiveTtsSpeaking) {
      _lastScheduledPassiveWakeRestartDelayMs = null;
      return;
    }

    final effectiveDelayMs =
        delayMs ?? AppConstants.passiveWakeIdleRestartDelayMs;
    _lastScheduledPassiveWakeRestartDelayMs = effectiveDelayMs;
    _passiveRestartTimer = Timer(Duration(milliseconds: effectiveDelayMs), () {
      // ignore: discarded_futures
      _startPassiveWakeListeningIfEligible();
    });
  }

  int _nextPassiveWakeClientErrorDelayMs() {
    final attempt = _passiveWakeClientErrorCount;
    _passiveWakeClientErrorCount += 1;

    var delayMs = AppConstants.passiveWakeClientErrorInitialDelayMs;
    for (var i = 0; i < attempt; i += 1) {
      delayMs *= 2;
      if (delayMs >= AppConstants.passiveWakeClientErrorMaxDelayMs) {
        return AppConstants.passiveWakeClientErrorMaxDelayMs;
      }
    }

    if (delayMs > AppConstants.passiveWakeClientErrorMaxDelayMs) {
      return AppConstants.passiveWakeClientErrorMaxDelayMs;
    }
    return delayMs;
  }

  void _resetPassiveWakeErrorBackoff() {
    _passiveWakeClientErrorCount = 0;
  }

  bool _shouldLogPassiveWakeError() {
    final now = DateTime.now();
    final lastLoggedAt = _lastPassiveWakeErrorLogAt;
    if (lastLoggedAt != null &&
        now.difference(lastLoggedAt).inMilliseconds <
            AppConstants.passiveWakeErrorLogCooldownMs) {
      return false;
    }

    _lastPassiveWakeErrorLogAt = now;
    return true;
  }

  void _setPassiveListeningState({
    required bool wakeListening,
    required bool armedQueryListening,
  }) {
    final shouldNotify =
        _isPassiveWakeListening != wakeListening ||
        _isArmedQueryListening != armedQueryListening;
    _isPassiveWakeListening = wakeListening;
    _isArmedQueryListening = armedQueryListening;
    if (shouldNotify) {
      notifyListeners();
    }
  }

  void _cancelPassiveWakeTimers() {
    _passiveRestartTimer?.cancel();
    _passiveRestartTimer = null;
    _passiveListeningTimeoutTimer?.cancel();
    _passiveListeningTimeoutTimer = null;
    _lastScheduledPassiveWakeRestartDelayMs = null;
  }
}
