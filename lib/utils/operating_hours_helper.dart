/// 운영시간 계산 유틸리티
///
/// Firebase hours 데이터를 기반으로 현재 운영 중인지 판단하고
/// 운영시간 텍스트를 생성하는 헬퍼 클래스
class OperatingHoursHelper {
  /// 현재 운영 중인지 판단
  ///
  /// hours 형식: {"1": {"start": "0900", "close": "1800"}, ...}
  /// 1 = 월요일, 2 = 화요일, ..., 7 = 일요일
  static bool isOpenNow(Map<String, dynamic>? hours) {
    if (hours == null || hours.isEmpty) return false;

    final now = DateTime.now();
    final weekday = now.weekday.toString(); // 1-7

    final todayHours = hours[weekday];
    if (todayHours == null) return false;

    final currentTime = now.hour * 100 + now.minute; // 예: 14:30 → 1430
    final startTime = int.tryParse(todayHours['start']?.toString() ?? '0') ?? 0;
    final closeTime = int.tryParse(todayHours['close']?.toString() ?? '0') ?? 0;

    // 24시간 운영 (2359, 2400)
    if (closeTime >= 2359) return true;

    return currentTime >= startTime && currentTime < closeTime;
  }

  /// 운영시간 텍스트 생성
  ///
  /// 반환 예시:
  /// - "18시까지" (운영 중)
  /// - "24시간 운영" (24시간)
  /// - "" (운영시간 정보 없음)
  static String getOperatingHoursText(Map<String, dynamic>? hours) {
    if (hours == null || hours.isEmpty) return '';

    final now = DateTime.now();
    final weekday = now.weekday.toString();
    final todayHours = hours[weekday];

    if (todayHours == null) return '';

    final closeTime = todayHours['close']?.toString() ?? '';

    // 24시간 운영
    if (closeTime == '2359' || closeTime == '2400' || closeTime == '0000') {
      return '24시간 운영';
    }

    // 시간 파싱 ("1800" → "18시까지")
    if (closeTime.length >= 4) {
      final hour = closeTime.substring(0, 2);
      final hourInt = int.tryParse(hour);
      if (hourInt != null) {
        return '$hourInt시까지';
      }
    }

    return '';
  }

  /// 오늘 운영시간 가져오기 (디버깅용)
  static Map<String, String>? getTodayHours(Map<String, dynamic>? hours) {
    if (hours == null || hours.isEmpty) return null;

    final now = DateTime.now();
    final weekday = now.weekday.toString();
    final todayHours = hours[weekday];

    if (todayHours == null) return null;

    return {
      'start': todayHours['start']?.toString() ?? '',
      'close': todayHours['close']?.toString() ?? '',
    };
  }
}
