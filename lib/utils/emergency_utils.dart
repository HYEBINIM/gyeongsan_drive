import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/safe_home_settings.dart';

/// 비상 상황 관련 유틸리티 함수
///
/// KISS 원칙: 간단한 순수 함수로 구현 (별도 서비스 클래스 불필요)
class EmergencyUtils {
  EmergencyUtils._();

  /// 첫 번째 비상연락처에게 전화 걸기
  ///
  /// [contacts] 비상연락처 목록 (첫 번째 연락처에만 전화)
  ///
  /// **동작 방식**:
  /// - 연락처 목록이 비어있으면 로그만 출력
  /// - 첫 번째 연락처에게만 전화
  /// - Android/iOS 모두 시스템 전화 앱 자동 실행
  static Future<void> makeEmergencyCall(List<EmergencyContact> contacts) async {
    if (contacts.isEmpty) {
      debugPrint('⚠️ 비상연락처가 없어 전화를 걸 수 없습니다.');
      return;
    }

    final contact = contacts.first;
    try {
      debugPrint('📞 비상 전화 걸기: ${contact.name} (${contact.phone})');

      final uri = Uri.parse('tel:${contact.phone}');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        debugPrint('✅ 전화 걸기 성공: ${contact.name}');
      } else {
        debugPrint('❌ 전화를 걸 수 없습니다: ${contact.phone}');
      }
    } catch (e) {
      debugPrint('❌ 전화 걸기 중 오류: $e');
    }
  }
}
