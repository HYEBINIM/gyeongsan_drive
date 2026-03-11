// UTF-8 인코딩 파일
// 한국어 주석: 음성 명령 백엔드 API 서비스

// UTF-8 인코딩 파일
// 한국어 주석: HTTP 통신 및 타임아웃 예외 처리를 위한 import
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/voice/voice_command_request.dart';
import '../../models/voice/voice_command_response.dart';
import '../../utils/constants.dart';
import '../http/app_http_client.dart';

/// 음성 명령 백엔드 API 서비스
/// 커스텀 백엔드 서버와 통신하여 음성 명령을 처리
class VoiceCommandService {
  final AppHttpClient _httpClient;

  /// API 엔드포인트
  final String _apiUrl = AppConstants.voiceCommandApiUrl;

  /// 타임아웃 시간
  final Duration _timeout = Duration(
    milliseconds: AppConstants.voiceCommandTimeoutMs,
  );
  final List<Duration> _retryDelays = [
    Duration.zero,
    const Duration(milliseconds: 700),
  ];

  VoiceCommandService({http.Client? client})
    : _httpClient = AppHttpClient(client: client);

  /// 음성 명령 전송 및 응답 받기
  /// [request]: 음성 명령 요청 데이터
  /// 반환: AI 응답 데이터
  Future<VoiceCommandResponse> sendCommand(VoiceCommandRequest request) async {
    VoiceCommandResponse? lastError;
    final body = jsonEncode(request.toJson());

    for (var attempt = 0; attempt < _retryDelays.length; attempt++) {
      final delay = _retryDelays[attempt];
      if (delay.inMilliseconds > 0) {
        await Future.delayed(delay);
      }

      try {
        // HTTP POST 요청
        final response = await _httpClient.post(
          Uri.parse(_apiUrl),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'x-token': AppConstants.voiceCommandApiToken,
            'wisenut-authorization': AppConstants.voiceCommandApiAuth,
          },
          body: body,
          timeout: _timeout,
        );

        // 상태 코드 확인
        if (response.statusCode == 200) {
          final Map<String, dynamic> jsonData =
              jsonDecode(utf8.decode(response.bodyBytes))
                  as Map<String, dynamic>;

          return VoiceCommandResponse.fromJson(jsonData);
        } else if (response.statusCode == 400) {
          return VoiceCommandResponse.error('요청 형식이 올바르지 않습니다.');
        } else if (response.statusCode == 401) {
          return VoiceCommandResponse.error('인증에 실패했습니다. 다시 로그인해주세요.');
        } else if (response.statusCode >= 500) {
          lastError = VoiceCommandResponse.error(
            '서버에서 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
          );

          // 5xx는 한 번 재시도 후에도 실패하면 종료
          if (attempt == _retryDelays.length - 1) {
            return lastError;
          }
          continue;
        } else {
          return VoiceCommandResponse.error(
            '알 수 없는 오류가 발생했습니다. (${response.statusCode})',
          );
        }
      } on TimeoutException catch (_) {
        // 한국어 주석: 요청 타임아웃 처리 (재시도 대상)
        lastError = VoiceCommandResponse.error(
          '응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.',
        );
      } on http.ClientException catch (_) {
        lastError = VoiceCommandResponse.error('네트워크 연결을 확인해주세요.');
      } on FormatException catch (_) {
        lastError = VoiceCommandResponse.error('서버 응답을 처리할 수 없습니다.');
      } catch (e) {
        return VoiceCommandResponse.error('요청 처리 중 오류가 발생했습니다: $e');
      }

      if (attempt == _retryDelays.length - 1) {
        return lastError;
      }
    }

    return lastError ?? VoiceCommandResponse.error('요청 처리 중 오류가 발생했습니다.');
  }

  /// 연결 테스트 (헬스 체크)
  /// 반환: 연결 성공 시 true, 실패 시 false
  Future<bool> testConnection() async {
    try {
      final response = await _httpClient.get(
        Uri.parse(_apiUrl.replaceAll('/voice-command', '/health')),
        timeout: const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
