// UTF-8 인코딩 파일
// 한국어 주석: 안전귀가 모니터링 이벤트 모델

import 'package:equatable/equatable.dart';

/// 한국어 주석: 모니터링 이벤트 타입
enum SafeHomeEventType {
  noMovementDetected, // 일정 시간 움직임 없음 감지
  arrivalTimeExceeded, // 도착 시간 초과 감지
}

/// 한국어 주석: 모니터링 이벤트 데이터
class SafeHomeEvent extends Equatable {
  final SafeHomeEventType type; // 이벤트 타입
  final String message; // 사용자 표시 메시지
  final DateTime timestamp; // 발생 시각

  const SafeHomeEvent({
    required this.type,
    required this.message,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [type, message, timestamp];
}
