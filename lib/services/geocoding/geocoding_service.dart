import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart' as geocoding_pkg;
import 'package:latlong2/latlong.dart';
import '../http/app_http_client.dart';

/// 역지오코딩 서비스 (카카오 API 기반)
///
/// GPS 좌표와 주소 간 변환을 담당합니다.
/// - 기본적으로 카카오 로컬 API 사용
/// - API 실패 시 geocoding 패키지로 fallback
/// - 메모리 캐싱을 통한 중복 요청 방지
class GeocodingService {
  final AppHttpClient _httpClient;

  GeocodingService({AppHttpClient? httpClient})
    : _httpClient = httpClient ?? AppHttpClient();

  // 카카오 API 설정
  static const String _kakaoBaseUrl = 'https://dapi.kakao.com/v2/local';

  /// 좌표 기반 주소 캐시 (LRU 캐시)
  /// Key: "latitude,longitude" 형식
  /// Value: 주소 문자열
  final LinkedHashMap<String, String> _addressCache =
      LinkedHashMap<String, String>();

  /// 캐시 최대 크기
  static const int _maxCacheSize = 100;

  /// 카카오 REST API 키 로드
  /// 1. dart-define (컴파일 타임 환경 변수) 우선 - 릴리즈 빌드용
  /// 2. .env 파일 (런타임 로드) fallback - 개발 편의용
  String? get _kakaoApiKey {
    // 1. dart-define으로 주입된 값 확인 (릴리즈 빌드)
    const compileTimeKey = String.fromEnvironment('KAKAO_REST_API_KEY');
    if (compileTimeKey.isNotEmpty) {
      return compileTimeKey;
    }

    // 2. .env 파일에서 로드 (개발 환경 fallback)
    final runtimeKey = dotenv.env['KAKAO_REST_API_KEY'];
    if (runtimeKey != null && runtimeKey.isNotEmpty) {
      return runtimeKey;
    }

    // 3. 둘 다 없으면 null 반환 (fallback 메커니즘으로 처리)
    return null;
  }

  // ============================================================================
  // Public Methods
  // ============================================================================

  /// 좌표 → 주소 변환 (역지오코딩)
  ///
  /// [latitude] 위도
  /// [longitude] 경도
  ///
  /// Returns: 도로명 주소 우선, 없으면 지번 주소. 실패 시 좌표 문자열 반환
  ///
  /// 처리 순서:
  /// 1. 캐시 확인
  /// 2. 카카오 API 호출 (우선)
  /// 3. geocoding 패키지 fallback
  Future<String> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    // 1. 캐시 확인
    final cacheKey = _buildCacheKey(latitude, longitude);
    if (_addressCache.containsKey(cacheKey)) {
      // 캐시 히트: 최근 사용 항목으로 이동 (LRU)
      final cachedAddress = _addressCache.remove(cacheKey)!;
      _addressCache[cacheKey] = cachedAddress;
      return cachedAddress;
    }

    // 2. 카카오 API 호출 시도
    try {
      final address = await _getAddressFromKakaoApi(
        latitude: latitude,
        longitude: longitude,
      );

      if (address != null) {
        // 캐시에 저장
        _addToCache(cacheKey, address);
        return address;
      }
    } catch (e) {
      // 카카오 API 실패 시 fallback으로 진행
      debugPrint('[GeocodingService] 카카오 API 실패, fallback 사용: $e');
    }

    // 3. Fallback: geocoding 패키지 사용
    try {
      final address = await _getAddressFromGeocoding(
        latitude: latitude,
        longitude: longitude,
      );
      // 캐시에 저장
      _addToCache(cacheKey, address);
      return address;
    } catch (e) {
      debugPrint('[GeocodingService] Fallback도 실패: $e');
      // 최종 실패 시 좌표 반환
      return '위도 ${latitude.toStringAsFixed(4)}, 경도 ${longitude.toStringAsFixed(4)}';
    }
  }

  /// 주소 → 좌표 변환 (정지오코딩)
  ///
  /// [address] 검색할 주소 (예: "대구광역시 달서구 파호동")
  ///
  /// Returns: LatLng 좌표 또는 null (실패 시)
  ///
  /// 처리 순서:
  /// 1. 카카오 API 호출 (우선)
  /// 2. geocoding 패키지 fallback
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    // 1. 카카오 API 호출 시도
    try {
      final coordinates = await _getCoordinatesFromKakaoApi(address);
      if (coordinates != null) {
        return coordinates;
      }
    } catch (e) {
      debugPrint('[GeocodingService] 카카오 주소 검색 실패, fallback 사용: $e');
    }

    // 2. Fallback: geocoding 패키지 사용
    try {
      return await _getCoordinatesFromGeocoding(address);
    } catch (e) {
      debugPrint('[GeocodingService] Fallback 주소 검색도 실패: $e');
      return null;
    }
  }

  /// 간략한 주소 형식 (시/군/구까지만)
  ///
  /// [latitude] 위도
  /// [longitude] 경도
  ///
  /// Returns: 간략한 주소 (예: "대구광역시 달서구")
  Future<String> getShortAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    // 1. 카카오 API 호출 시도
    try {
      final shortAddress = await _getShortAddressFromKakaoApi(
        latitude: latitude,
        longitude: longitude,
      );
      if (shortAddress != null) {
        return shortAddress;
      }
    } catch (e) {
      debugPrint('[GeocodingService] 카카오 간략 주소 실패, fallback 사용: $e');
    }

    // 2. Fallback: geocoding 패키지 사용
    try {
      return await _getShortAddressFromGeocoding(
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      debugPrint('[GeocodingService] Fallback 간략 주소도 실패: $e');
      return '현재위치';
    }
  }

  /// 캐시 초기화
  void clearCache() {
    _addressCache.clear();
  }

  // ============================================================================
  // 카카오 API Methods
  // ============================================================================

  /// 카카오 API: 좌표 → 주소 변환
  Future<String?> _getAddressFromKakaoApi({
    required double latitude,
    required double longitude,
  }) async {
    if (_kakaoApiKey == null || _kakaoApiKey!.isEmpty) {
      throw Exception('카카오 API 키가 설정되지 않았습니다');
    }

    final uri = Uri.parse('$_kakaoBaseUrl/geo/coord2address.json').replace(
      queryParameters: {
        'x': longitude.toString(), // 카카오 API는 경도가 x
        'y': latitude.toString(), // 위도가 y
        'input_coord': 'WGS84',
      },
    );

    final json = await _httpClient.getJsonMap(
      uri: uri,
      headers: {'Authorization': 'KakaoAK $_kakaoApiKey'},
      statusErrorBuilder: (statusCode, body) =>
          '카카오 API 호출 실패: $statusCode, $body',
    );
    final documents = json['documents'] as List<dynamic>?;

    if (documents == null || documents.isEmpty) {
      return null;
    }

    final document = documents.first as Map<String, dynamic>;

    // 도로명 주소 우선
    final roadAddress = document['road_address'] as Map<String, dynamic>?;
    if (roadAddress != null) {
      final addressName = roadAddress['address_name'] as String?;
      if (addressName != null && addressName.isNotEmpty) {
        return addressName;
      }
    }

    // 도로명 주소가 없으면 지번 주소 사용
    final address = document['address'] as Map<String, dynamic>?;
    if (address != null) {
      final addressName = address['address_name'] as String?;
      if (addressName != null && addressName.isNotEmpty) {
        return addressName;
      }
    }

    return null;
  }

  /// 카카오 API: 주소 → 좌표 변환
  Future<LatLng?> _getCoordinatesFromKakaoApi(String address) async {
    if (_kakaoApiKey == null || _kakaoApiKey!.isEmpty) {
      throw Exception('카카오 API 키가 설정되지 않았습니다');
    }

    final uri = Uri.parse(
      '$_kakaoBaseUrl/search/address.json',
    ).replace(queryParameters: {'query': address});

    final json = await _httpClient.getJsonMap(
      uri: uri,
      headers: {'Authorization': 'KakaoAK $_kakaoApiKey'},
      statusErrorBuilder: (statusCode, body) =>
          '카카오 주소 검색 실패: $statusCode, $body',
    );
    final documents = json['documents'] as List<dynamic>?;

    if (documents == null || documents.isEmpty) {
      return null;
    }

    final document = documents.first as Map<String, dynamic>;

    // 도로명 주소 좌표 우선
    final roadAddress = document['road_address'] as Map<String, dynamic>?;
    if (roadAddress != null) {
      final x = roadAddress['x'] as String?;
      final y = roadAddress['y'] as String?;
      if (x != null && y != null) {
        return LatLng(double.parse(y), double.parse(x));
      }
    }

    // 지번 주소 좌표
    final x = document['x'] as String?;
    final y = document['y'] as String?;
    if (x != null && y != null) {
      return LatLng(double.parse(y), double.parse(x));
    }

    return null;
  }

  /// 카카오 API: 간략한 주소 (시/군/구까지)
  Future<String?> _getShortAddressFromKakaoApi({
    required double latitude,
    required double longitude,
  }) async {
    if (_kakaoApiKey == null || _kakaoApiKey!.isEmpty) {
      throw Exception('카카오 API 키가 설정되지 않았습니다');
    }

    final uri = Uri.parse('$_kakaoBaseUrl/geo/coord2address.json').replace(
      queryParameters: {
        'x': longitude.toString(),
        'y': latitude.toString(),
        'input_coord': 'WGS84',
      },
    );

    final json = await _httpClient.getJsonMap(
      uri: uri,
      headers: {'Authorization': 'KakaoAK $_kakaoApiKey'},
      statusErrorBuilder: (statusCode, body) =>
          '카카오 API 호출 실패: $statusCode, $body',
    );
    final documents = json['documents'] as List<dynamic>?;

    if (documents == null || documents.isEmpty) {
      return null;
    }

    final document = documents.first as Map<String, dynamic>;

    // 도로명 주소에서 추출
    final roadAddress = document['road_address'] as Map<String, dynamic>?;
    if (roadAddress != null) {
      final region1 = roadAddress['region_1depth_name'] as String?; // 시/도
      final region2 = roadAddress['region_2depth_name'] as String?; // 구

      final parts = <String>[];
      if (region1 != null && region1.isNotEmpty) parts.add(region1);
      if (region2 != null && region2.isNotEmpty) parts.add(region2);

      if (parts.isNotEmpty) {
        return parts.join(' ');
      }
    }

    // 지번 주소에서 추출
    final address = document['address'] as Map<String, dynamic>?;
    if (address != null) {
      final region1 = address['region_1depth_name'] as String?;
      final region2 = address['region_2depth_name'] as String?;

      final parts = <String>[];
      if (region1 != null && region1.isNotEmpty) parts.add(region1);
      if (region2 != null && region2.isNotEmpty) parts.add(region2);

      if (parts.isNotEmpty) {
        return parts.join(' ');
      }
    }

    return null;
  }

  // ============================================================================
  // Fallback Methods (geocoding 패키지)
  // ============================================================================

  /// Fallback: geocoding 패키지로 좌표 → 주소 변환
  Future<String> _getAddressFromGeocoding({
    required double latitude,
    required double longitude,
  }) async {
    final List<geocoding_pkg.Placemark> placemarks = await geocoding_pkg
        .placemarkFromCoordinates(latitude, longitude);

    if (placemarks.isEmpty) {
      return '위도 ${latitude.toStringAsFixed(4)}, 경도 ${longitude.toStringAsFixed(4)}';
    }

    final geocoding_pkg.Placemark place = placemarks.first;
    final List<String> addressParts = [];

    // 시/도 (administrativeArea)
    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      addressParts.add(place.administrativeArea!);
    }

    // 시/군/구 (locality)
    if (place.locality != null && place.locality!.isNotEmpty) {
      addressParts.add(place.locality!);
    }

    // 동/읍/면 (subLocality 또는 thoroughfare)
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      addressParts.add(place.subLocality!);
    } else if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
      addressParts.add(place.thoroughfare!);
    }

    // 상세 주소 (subThoroughfare - 건물 번호)
    if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) {
      addressParts.add(place.subThoroughfare!);
    }

    if (addressParts.isEmpty) {
      return '위도 ${latitude.toStringAsFixed(4)}, 경도 ${longitude.toStringAsFixed(4)}';
    }

    return addressParts.join(' ');
  }

  /// Fallback: geocoding 패키지로 주소 → 좌표 변환
  Future<LatLng?> _getCoordinatesFromGeocoding(String address) async {
    final List<geocoding_pkg.Location> locations = await geocoding_pkg
        .locationFromAddress(address);

    if (locations.isEmpty) {
      return null;
    }

    final geocoding_pkg.Location location = locations.first;
    return LatLng(location.latitude, location.longitude);
  }

  /// Fallback: geocoding 패키지로 간략한 주소 가져오기
  Future<String> _getShortAddressFromGeocoding({
    required double latitude,
    required double longitude,
  }) async {
    final List<geocoding_pkg.Placemark> placemarks = await geocoding_pkg
        .placemarkFromCoordinates(latitude, longitude);

    if (placemarks.isEmpty) {
      return '현재위치';
    }

    final geocoding_pkg.Placemark place = placemarks.first;
    final List<String> addressParts = [];

    // 시/도
    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      addressParts.add(place.administrativeArea!);
    }

    // 시/군/구
    if (place.locality != null && place.locality!.isNotEmpty) {
      addressParts.add(place.locality!);
    }

    return addressParts.isEmpty ? '현재위치' : addressParts.join(' ');
  }

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /// 캐시 키 생성
  String _buildCacheKey(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
  }

  /// 캐시에 항목 추가 (LRU 정책)
  void _addToCache(String key, String value) {
    // 기존 항목이 있으면 제거 (최신 항목으로 다시 추가)
    if (_addressCache.containsKey(key)) {
      _addressCache.remove(key);
    }

    // 캐시 크기 제한
    if (_addressCache.length >= _maxCacheSize) {
      // 가장 오래된 항목(첫 번째 항목) 제거
      _addressCache.remove(_addressCache.keys.first);
    }

    // 새 항목 추가 (맨 뒤에 추가됨)
    _addressCache[key] = value;
  }
}
