// UTF-8 인코딩 파일
// 한국어 주석: 음성 출력(TTS) 서비스

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 음성 출력 서비스 (Text-to-Speech)
/// flutter_tts 패키지를 래핑하여 사용
class TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  /// 초기화 여부
  bool get isInitialized => _isInitialized;

  /// 현재 재생 중인지 여부
  bool get isSpeaking => _isSpeaking;

  /// 초기화
  Future<void> initialize() async {
    try {
      // 한국어 설정
      await _tts.setLanguage('ko-KR');

      // 음성 속도 (0.0 ~ 1.0, 기본 0.5)
      await _tts.setSpeechRate(0.5);

      // 음성 볼륨 (0.0 ~ 1.0, 기본 1.0)
      await _tts.setVolume(1.0);

      // 음성 톤 (0.5 ~ 2.0, 기본 1.0)
      await _tts.setPitch(1.0);

      // 한국어 주석: speak Future가 실제 완료 시점에 resolve되도록 설정
      // 한국어 주석: 재생 Future를 실제 완료 시점에 완료시키기 위한 설정
      // flutter_tts 4.x: awaitSpeakCompletion 지원
      try {
        await _tts.awaitSpeakCompletion(true);
      } catch (_) {
        // 일부 플랫폼/버전에서 미지원일 수 있음 (무시)
      }

      // 완료 콜백 설정
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      // 시작 콜백 설정
      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      // 에러 콜백 설정
      _tts.setErrorHandler((error) {
        _isSpeaking = false;
      });

      _isInitialized = true;
    } catch (e) {
      // TTS 초기화 실패
    }
  }

  /// 텍스트를 음성으로 재생
  /// [text]: 읽을 텍스트
  /// [onComplete]: 완료 콜백 (옵션)
  Future<void> speak(String text, {VoidCallback? onComplete}) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // 이미 재생 중이면 중지
      if (_isSpeaking) {
        await stop();
      }

      // 한국어 주석: speak Future가 완료될 때까지 대기 (중복 호출 방지)
      _isSpeaking = true;
      await _tts.speak(text);
      _isSpeaking = false;

      // 한국어 주석: 외부 완료 콜백 호출(선택)
      onComplete?.call();
    } catch (e) {
      _isSpeaking = false;
    }
  }

  /// 음성 출력 중지
  Future<void> stop() async {
    try {
      await _tts.stop();
      _isSpeaking = false;
    } catch (e) {
      // TTS 중지 실패
    }
  }

  /// 음성 출력 일시 정지
  Future<void> pause() async {
    try {
      await _tts.pause();
    } catch (e) {
      // TTS 일시 정지 실패
    }
  }

  /// 음성 속도 설정 (0.0 ~ 1.0)
  Future<void> setSpeechRate(double rate) async {
    try {
      await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
    } catch (e) {
      // TTS 속도 설정 실패
    }
  }

  /// 음성 볼륨 설정 (0.0 ~ 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _tts.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      // TTS 볼륨 설정 실패
    }
  }

  /// 음성 톤 설정 (0.5 ~ 2.0)
  Future<void> setPitch(double pitch) async {
    try {
      await _tts.setPitch(pitch.clamp(0.5, 2.0));
    } catch (e) {
      // TTS 톤 설정 실패
    }
  }

  /// 사용 가능한 언어 목록 가져오기
  Future<List<dynamic>> getLanguages() async {
    try {
      return await _tts.getLanguages;
    } catch (e) {
      return [];
    }
  }

  /// 리소스 정리
  void dispose() {
    _tts.stop();
  }
}
