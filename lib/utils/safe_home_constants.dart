// UTF-8 인코딩 파일
// 한국어 주석: 안전귀가 관련 상수 정의 (DRY)

class SafeHomeConstants {
  // 한국어 주석: 보안 암호(PIN) 자릿수 (고정 4자리)
  static const int pinLength = 4;

  // 한국어 주석: 기존 앱에서 사용하던 보안 암호(PIN) 최대 자릿수 (호환용 6자리)
  static const int legacyPinMaxLength = 6;

  // 한국어 주석: 보안 암호(PIN) 최대 시도 횟수
  static const int pinMaxAttempts = 3;

  // 한국어 주석: 암호 검증 성공 후 적용할 이상 감지 쿨다운 시간(분)
  // - UX/안전성 균형을 위해 기본값 1분으로 설정
  static const int alertCooldownMinutes = 1;

  // 한국어 주석: 새 정책(4자리) + 기존(6자리) PIN 모두 허용하는 유효성 검사
  static bool isValidPin(String pin) {
    if (pin.isEmpty) {
      return false;
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(pin)) {
      return false;
    }

    final length = pin.length;
    return length >= pinLength && length <= legacyPinMaxLength;
  }
}
