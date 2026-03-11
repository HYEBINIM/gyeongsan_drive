import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../models/navigation/route_model.dart';
import '../../models/navigation/route_type.dart';
import '../../models/navigation/navigation_state.dart';
import '../../models/navigation/maneuver_model.dart';
import '../http/app_http_client.dart';

/// Valhalla API 클라이언트 서비스
/// 공개 Valhalla 서버를 사용하여 실제 경로 계산
class ValhallaApiService {
  final AppHttpClient _httpClient;

  ValhallaApiService({AppHttpClient? httpClient})
    : _httpClient = httpClient ?? AppHttpClient();

  // Valhalla 공개 서버 엔드포인트
  static const String _baseUrl = 'https://valhalla1.openstreetmap.de';
  static const Duration _timeout = Duration(seconds: 30);

  /// 경로 계산
  ///
  /// [start] 출발지 좌표
  /// [destination] 도착지 좌표
  /// [costing] Valhalla costing 모드 (auto, pedestrian, bicycle)
  /// [costingOptions] 경로 타입별 costing 옵션
  ///
  /// Returns: 계산된 경로 정보
  Future<RouteModel> getRoute({
    required LatLng start,
    required LatLng destination,
    required String costing,
    required RouteType routeType,
    Map<String, dynamic>? costingOptions,
  }) async {
    try {
      // 1. 요청 바디 구성
      final requestBody = {
        'locations': [
          {'lat': start.latitude, 'lon': start.longitude},
          {'lat': destination.latitude, 'lon': destination.longitude},
        ],
        'costing': costing,
        'units': 'kilometers',
        'language': 'ko-KR',
      };

      // costing_options 추가
      if (costingOptions != null && costingOptions.isNotEmpty) {
        requestBody['costing_options'] = {costing: costingOptions};
      }

      debugPrint('🚀 Valhalla API 요청: $costing, ${routeType.label}');
      debugPrint('📍 출발: ${start.latitude}, ${start.longitude}');
      debugPrint('📍 도착: ${destination.latitude}, ${destination.longitude}');

      // 2. HTTP POST 요청 + 응답 파싱
      final data = await _httpClient.postJsonMap(
        uri: Uri.parse('$_baseUrl/route'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
        timeout: _timeout,
        statusErrorBuilder: (statusCode, _) => 'Valhalla API 오류: $statusCode',
      );

      // 5. RouteModel로 변환
      final route = _parseValhallaResponse(data, routeType);

      debugPrint(
        '✅ 경로 계산 완료: ${route.totalDistanceKm.toStringAsFixed(1)}km, ${route.estimatedMinutes}분',
      );

      return route;
    } on http.ClientException catch (e) {
      throw '네트워크 연결 실패: $e';
    } on FormatException catch (e) {
      throw 'API 응답 파싱 실패: $e';
    } catch (e) {
      throw '경로 계산 실패: $e';
    }
  }

  /// Valhalla 응답을 RouteModel로 변환
  ///
  /// Valhalla 응답 구조:
  /// {
  ///   "trip": {
  ///     "summary": {
  ///       "length": 10.5,     // km
  ///       "time": 600         // seconds
  ///     },
  ///     "legs": [{
  ///       "shape": "encoded_polyline_string",
  ///       "maneuvers": [...]
  ///     }]
  ///   }
  /// }
  RouteModel _parseValhallaResponse(
    Map<String, dynamic> data,
    RouteType routeType,
  ) {
    // trip 객체 추출
    final trip = data['trip'] as Map<String, dynamic>?;
    if (trip == null) {
      throw 'Valhalla 응답에 trip 정보가 없습니다';
    }

    // summary 정보 추출
    final summary = trip['summary'] as Map<String, dynamic>?;
    if (summary == null) {
      throw 'Valhalla 응답에 summary 정보가 없습니다';
    }

    final distanceKm = (summary['length'] as num?)?.toDouble() ?? 0.0;
    final timeSeconds = (summary['time'] as num?)?.toInt() ?? 0;
    final estimatedMinutes = (timeSeconds / 60).round();

    // legs 배열 추출
    final legs = trip['legs'] as List<dynamic>?;
    if (legs == null || legs.isEmpty) {
      throw 'Valhalla 응답에 legs 정보가 없습니다';
    }

    // 첫 번째 leg의 shape (encoded polyline) 추출
    final firstLeg = legs.first as Map<String, dynamic>;
    final encodedShape = firstLeg['shape'] as String?;

    // shape 디코딩
    List<LatLng> routePoints;
    if (encodedShape != null && encodedShape.isNotEmpty) {
      routePoints = _decodePolyline(encodedShape);
    } else {
      // shape가 없으면 빈 리스트
      routePoints = [];
    }

    // maneuvers 파싱 (길안내 기능에 필수)
    final maneuversData = firstLeg['maneuvers'] as List<dynamic>?;
    List<ManeuverModel>? maneuvers;
    if (maneuversData != null && maneuversData.isNotEmpty) {
      maneuvers = [];
      for (var m in maneuversData) {
        final maneuverMap = m as Map<String, dynamic>;

        // begin_shape_index로 maneuver 시작 좌표 찾기
        // Valhalla가 숫자를 double로 반환할 수 있어 num 기반으로 안전 변환
        final beginShapeIndex = (maneuverMap['begin_shape_index'] as num?)
            ?.toInt();
        LatLng? beginLocation;

        if (beginShapeIndex != null &&
            beginShapeIndex < routePoints.length &&
            beginShapeIndex >= 0) {
          beginLocation = routePoints[beginShapeIndex];
        }

        maneuvers.add(
          // fromJson 팩토리 메서드로 street_names 포함 전체 필드 파싱
          ManeuverModel.fromJson(maneuverMap, beginLocation),
        );
      }

      debugPrint('✅ Maneuvers 파싱 완료: ${maneuvers.length}개');
    }

    // 예상 택시비 계산 (기본요금 4,800원 + km당 1,000원)
    final taxiFare = (4800 + (distanceKm * 1000)).round();

    return RouteModel(
      routePoints: routePoints,
      totalDistanceKm: distanceKm,
      estimatedMinutes: estimatedMinutes,
      estimatedTaxiFare: taxiFare,
      routeType: routeType.label,
      summary: '${distanceKm.toStringAsFixed(1)}km, $estimatedMinutes분',
      maneuvers: maneuvers,
    );
  }

  /// Polyline6 인코딩 문자열을 LatLng 리스트로 디코딩
  ///
  /// Valhalla는 Google Polyline Algorithm (precision 6)을 사용
  /// 참고: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0;
    int lng = 0;
    const precision = 1e6; // Valhalla uses precision 6

    while (index < len) {
      int shift = 0;
      int result = 0;
      int byte;

      // 위도 디코딩
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);

      final deltaLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += deltaLat;

      shift = 0;
      result = 0;

      // 경도 디코딩
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);

      final deltaLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += deltaLng;

      points.add(LatLng(lat / precision, lng / precision));
    }

    return points;
  }

  /// TransportMode를 Valhalla costing 모드로 변환
  static String getCostingMode(TransportMode mode) {
    switch (mode) {
      case TransportMode.car:
        return 'auto';
      case TransportMode.walk:
        return 'pedestrian';
      case TransportMode.bike:
        return 'bicycle';
    }
  }

  /// RouteType에 따른 costing_options 생성
  ///
  /// [routeType] 경로 타입
  /// [options] 사용자 설정 옵션 (무료도로, 자동차전용도로 제외 등)
  /// [mode] 교통수단 (pedestrian/bicycle일 때 별도 로직 적용)
  ///
  /// Returns: Valhalla costing_options Map
  static Map<String, dynamic> getCostingOptions(
    RouteType routeType,
    RouteOptions options,
    TransportMode mode,
  ) {
    // pedestrian 모드일 때는 별도 로직 적용
    if (mode == TransportMode.walk) {
      return _getPedestrianCostingOptions(routeType, options);
    }

    // bicycle 모드일 때는 별도 로직 적용
    if (mode == TransportMode.bike) {
      return _getBicycleCostingOptions(routeType, options);
    }

    // 자동차 모드의 기존 로직
    final costingOptions = <String, dynamic>{};

    // RouteType별 기본 설정
    switch (routeType) {
      case RouteType.recommended:
        // 1) 추천 경로: 일반용, 깔끔한 내비
        costingOptions['shortest'] = false;
        costingOptions['use_distance'] = 0.0;
        costingOptions['use_highways'] = 0.6;
        costingOptions['use_living_streets'] = 0.3;
        costingOptions['use_tracks'] = 0.1;
        costingOptions['maneuver_penalty'] = 5;
        costingOptions['exclude_unpaved'] = false;
        break;

      case RouteType.fastest:
        // 2) 최소 시간: 진짜 '속도'만 보겠다
        costingOptions['shortest'] = false;
        costingOptions['use_distance'] = 0.0;
        costingOptions['maneuver_penalty'] = 0; // 회전 페널티 없음
        break;

      case RouteType.shortest:
        // 3) 거리 우선: 최단거리
        costingOptions['shortest'] = true;
        break;

      case RouteType.mainRoad:
        // 4) 큰길 우선: 간선·직진 위주
        costingOptions['shortest'] = false;
        costingOptions['use_highways'] = 0.9;
        costingOptions['use_living_streets'] = 0.1;
        costingOptions['use_tracks'] = 0.0;
        costingOptions['maneuver_penalty'] = 8; // 회전 많이 싫어함
        costingOptions['exclude_unpaved'] = true; // 비포장도로 제외
        break;

      case RouteType.highway:
        // 5) 고속도로 우선
        costingOptions['shortest'] = false;
        costingOptions['use_highways'] = 1.0; // 고속도로 최대 선호
        costingOptions['use_tolls'] = 0.8; // 유료도로 선호
        break;
    }

    // RouteOptions 반영 (사용자 설정이 우선)
    if (options.avoidTollRoads) {
      costingOptions['use_tolls'] = 0.0; // 유료도로 완전 회피
    }

    if (options.avoidHighways) {
      costingOptions['use_highways'] = 0.0; // 고속도로 완전 회피
    }

    return costingOptions;
  }

  /// Pedestrian(도보) 모드 전용 costing_options 생성
  ///
  /// 도보 모드에서는 3가지 경로 타입 지원:
  /// - shortest: 최단거리
  /// - mainRoad: 큰길 우선 (인도/보행로 선호, 골목길 회피)
  /// - recommended: 편안한길 (계단/언덕 회피, 조명 선호)
  ///
  /// [routeType] 경로 타입
  /// [options] 사용자 설정 옵션
  ///
  /// Returns: Valhalla pedestrian costing_options Map
  static Map<String, dynamic> _getPedestrianCostingOptions(
    RouteType routeType,
    RouteOptions options,
  ) {
    final costingOptions = <String, dynamic>{};

    switch (routeType) {
      case RouteType.shortest:
        // 1) 최단거리: 거리가 가장 짧은 경로
        costingOptions['shortest'] = true;
        break;

      case RouteType.mainRoad:
        // 2) 큰길 우선: 인도/보행로 선호, 골목길/진입로 회피
        costingOptions['shortest'] = false;
        costingOptions['walkway_factor'] = 0.8; // 보행로 선호
        costingOptions['sidewalk_factor'] = 0.8; // 인도 선호
        costingOptions['alley_factor'] = 3.0; // 골목길 페널티
        costingOptions['driveway_factor'] = 6.0; // 진입로 페널티
        costingOptions['use_living_streets'] = 0.3; // 생활도로 낮은 선호
        costingOptions['use_tracks'] = 0.2; // 오솔길 낮은 선호
        costingOptions['step_penalty'] = 20; // 계단 약간 회피
        costingOptions['use_lit'] = 0.7; // 조명 있는 길 선호
        break;

      case RouteType.recommended:
        // 3) 편안한길: 계단/언덕 회피, 조명 선호
        costingOptions['shortest'] = false;
        costingOptions['walkway_factor'] = 0.7; // 보행로 강하게 선호
        costingOptions['sidewalk_factor'] = 0.7; // 인도 강하게 선호
        costingOptions['alley_factor'] = 4.0; // 골목길 강한 페널티
        costingOptions['driveway_factor'] = 8.0; // 진입로 강한 페널티
        costingOptions['step_penalty'] = 60; // 계단 강하게 회피
        costingOptions['elevator_penalty'] = 30; // 엘리베이터 페널티
        costingOptions['use_hills'] = 0.1; // 언덕 강하게 회피
        costingOptions['use_lit'] = 1.0; // 조명 있는 길 최대 선호
        costingOptions['max_hiking_difficulty'] = 1; // 낮은 난이도만
        costingOptions['use_ferry'] = 0.3; // 페리 낮은 선호
        break;

      default:
        // 기타 RouteType은 기본 pedestrian 설정 사용
        costingOptions['shortest'] = false;
        break;
    }

    return costingOptions;
  }

  /// Bicycle(자전거) 모드 전용 costing_options 생성
  ///
  /// 자전거 모드에서는 3가지 경로 타입 지원:
  /// - recommended: 자전거도로 우선 (사이클웨이/분리된 인프라)
  /// - shortest: 최단거리
  /// - fastest: 편안한길 (언덕/나쁜 노면/차량도로 회피)
  ///
  /// [routeType] 경로 타입
  /// [options] 사용자 설정 옵션
  ///
  /// Returns: Valhalla bicycle costing_options Map
  static Map<String, dynamic> _getBicycleCostingOptions(
    RouteType routeType,
    RouteOptions options,
  ) {
    final costingOptions = <String, dynamic>{};

    switch (routeType) {
      case RouteType.recommended:
        // 1) 자전거도로 우선: 사이클웨이/분리된 자전거 인프라 선호
        costingOptions['bicycle_type'] = 'hybrid';
        costingOptions['cycling_speed'] = 18;
        costingOptions['use_roads'] = 0.1; // 차량 도로 회피
        costingOptions['use_hills'] = 0.4; // 언덕 약간 회피
        costingOptions['avoid_bad_surfaces'] = 0.8; // 나쁜 노면 회피
        costingOptions['use_living_streets'] = 0.3;
        costingOptions['use_ferry'] = 0.3;
        break;

      case RouteType.shortest:
        // 2) 최단거리: 순수 거리 기준
        costingOptions['shortest'] = true;
        break;

      case RouteType.fastest:
        // 3) 편안한길: Low-stress 경로 (언덕/나쁜 노면/차량도로 기피)
        costingOptions['bicycle_type'] = 'city';
        costingOptions['cycling_speed'] = 16;
        costingOptions['use_roads'] = 0.0; // 차량 도로 완전 회피
        costingOptions['use_hills'] = 0.1; // 언덕 강하게 회피
        costingOptions['avoid_bad_surfaces'] = 1.0; // 나쁜 노면 완전 회피
        costingOptions['use_living_streets'] = 0.2;
        costingOptions['use_ferry'] = 0.2;
        break;

      default:
        // 기타 RouteType은 기본 bicycle 설정 사용
        costingOptions['shortest'] = false;
        break;
    }

    return costingOptions;
  }
}
