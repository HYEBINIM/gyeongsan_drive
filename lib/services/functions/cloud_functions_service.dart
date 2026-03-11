import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Cloud Function 응답 데이터
class FindIdResult {
  final bool verified; // 이름+이메일 검증 성공 여부
  final String maskedEmail; // 마스킹된 이메일 (검증 성공 시에만 제공)
  final String message;

  FindIdResult({
    required this.verified,
    required this.maskedEmail,
    required this.message,
  });
}

/// Firebase Cloud Functions 서비스
/// 서버 사이드 로직 호출을 담당
class CloudFunctionsService {
  // Cloud Functions 인스턴스 (서울 리전)
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-northeast3',
  );

  /// 이름과 이메일로 아이디 찾기 (Cloud Function 호출)
  ///
  /// 서버 사이드에서 안전하게 처리:
  /// - Rate limiting으로 무차별 대입 공격 방지
  /// - 이름 + 이메일 2단계 검증
  /// - 이메일 마스킹으로 보안 강화 (예: te*****r@ex*****.com)
  Future<FindIdResult> findUserIdByNameAndEmail({
    required String name,
    required String email,
  }) async {
    try {
      // Cloud Function 호출 (서버 사이드 검증)
      final callable = _functions.httpsCallable('findUserIdByNameAndEmail');
      final result = await callable.call({'name': name, 'email': email});

      // 응답 데이터 파싱
      final data = result.data as Map<dynamic, dynamic>;
      final verified = data['verified'] as bool? ?? false;
      final maskedEmail = data['maskedEmail'] as String? ?? '';
      final message = data['message'] as String;

      return FindIdResult(
        verified: verified,
        maskedEmail: maskedEmail,
        message: message,
      );
    } on FirebaseFunctionsException catch (e) {
      // Cloud Functions 특정 에러 처리
      debugPrint('Cloud Functions 에러: ${e.code}, ${e.message}');

      String errorMessage;
      switch (e.code) {
        case 'invalid-argument':
          errorMessage = '이름과 이메일을 모두 입력해주세요.';
          break;
        case 'resource-exhausted':
          errorMessage = '너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.';
          break;
        case 'unauthenticated':
          errorMessage = '인증이 필요합니다.';
          break;
        case 'permission-denied':
          errorMessage = '권한이 없습니다.';
          break;
        case 'unavailable':
          errorMessage = '서버에 연결할 수 없습니다. 네트워크 연결을 확인해주세요.';
          break;
        case 'deadline-exceeded':
          errorMessage = '요청 시간이 초과되었습니다. 다시 시도해주세요.';
          break;
        default:
          errorMessage = '오류가 발생했습니다: ${e.message}';
      }

      return FindIdResult(
        verified: false,
        maskedEmail: '',
        message: errorMessage,
      );
    } catch (e) {
      // 일반 에러 처리
      debugPrint('아이디 찾기 오류: $e');
      return FindIdResult(
        verified: false,
        maskedEmail: '',
        message: '오류가 발생했습니다. 다시 시도해주세요.',
      );
    }
  }
}
