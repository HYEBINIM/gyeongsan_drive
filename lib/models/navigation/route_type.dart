import 'navigation_state.dart';

/// 경로 타입 열거형
/// 5가지 경로 옵션 정의
enum RouteType {
  /// 추천경로 - 가장 효율적인 경로
  recommended('추천경로', '가장 효율적인 경로'),

  /// 최소시간 - 시간이 가장 짧은 경로
  fastest('최소시간', '시간이 가장 짧은 경로'),

  /// 거리우선 - 거리가 가장 짧은 경로
  shortest('거리우선', '거리가 가장 짧은 경로'),

  /// 큰길우선 - 큰 도로 위주 경로
  mainRoad('큰길우선', '큰 도로 위주 경로'),

  /// 고속도로우선 - 고속도로 이용 경로
  highway('고속도로우선', '고속도로 이용 경로');

  /// 라벨 (UI에 표시될 텍스트)
  final String label;

  /// 설명 (경로의 특징)
  final String description;

  const RouteType(this.label, this.description);
}

/// RouteType 확장 기능
/// TransportMode별로 다른 라벨, 설명, 사용 가능한 타입 제공
extension RouteTypeExtension on RouteType {
  /// TransportMode에 따른 라벨 반환
  /// 도보/자전거 모드일 때는 각 교통수단에 맞는 라벨로 변경
  String labelForMode(TransportMode mode) {
    if (mode == TransportMode.walk) {
      switch (this) {
        case RouteType.shortest:
          return '최단거리';
        case RouteType.mainRoad:
          return '큰길 우선';
        case RouteType.recommended:
          return '편안한길';
        default:
          return label;
      }
    }

    if (mode == TransportMode.bike) {
      switch (this) {
        case RouteType.recommended:
          return '자전거도로 우선';
        case RouteType.shortest:
          return '최단거리';
        case RouteType.fastest:
          return '편안한길';
        default:
          return label;
      }
    }

    // car는 기존 라벨 사용
    return label;
  }

  /// TransportMode에 따른 설명 반환
  /// 도보/자전거 모드일 때는 각 교통수단에 맞는 설명으로 변경
  String descriptionForMode(TransportMode mode) {
    if (mode == TransportMode.walk) {
      switch (this) {
        case RouteType.shortest:
          return '거리가 가장 짧은 경로';
        case RouteType.mainRoad:
          return '인도/보행로 우선, 골목길 회피';
        case RouteType.recommended:
          return '계단/언덕 회피, 조명 있는 길 선호';
        default:
          return description;
      }
    }

    if (mode == TransportMode.bike) {
      switch (this) {
        case RouteType.recommended:
          return '사이클웨이/분리된 자전거 인프라 우선';
        case RouteType.shortest:
          return '거리가 가장 짧은 경로';
        case RouteType.fastest:
          return '언덕/나쁜 노면/차량도로 회피';
        default:
          return description;
      }
    }

    // car는 기존 설명 사용
    return description;
  }

  /// TransportMode별 사용 가능한 RouteType 목록
  /// - car: 5가지 (추천, 최소시간, 거리우선, 큰길우선, 고속도로우선)
  /// - walk: 3가지 (최단거리, 큰길우선, 편안한길)
  /// - bike: 3가지 (추천, 최소시간, 거리우선)
  static List<RouteType> availableTypes(TransportMode mode) {
    switch (mode) {
      case TransportMode.car:
        return [
          RouteType.recommended,
          RouteType.fastest,
          RouteType.shortest,
          RouteType.mainRoad,
          RouteType.highway,
        ];
      case TransportMode.walk:
        return [
          RouteType.shortest, // 최단거리
          RouteType.mainRoad, // 큰길 우선
          RouteType.recommended, // 편안한길
        ];
      case TransportMode.bike:
        return [RouteType.recommended, RouteType.fastest, RouteType.shortest];
    }
  }
}
