// UTF-8 인코딩 파일
// 한국어 주석: 음성 명령 기반 길 안내 요청 감지 및 목적지 추출 서비스

import 'package:flutter/foundation.dart';

import '../../models/navigation/route_model.dart';
import '../geocoding/geocoding_service.dart';

/// 음성 명령에서 길 안내 요청을 감지하고 목적지를 추출하는 서비스
class NavigationContextResolver {
  final GeocodingService _geocodingService;

  NavigationContextResolver({required GeocodingService geocodingService})
    : _geocodingService = geocodingService;

  /// 한국어 주석: 사용자 입력이 길 안내 요청인지 감지
  ///
  /// 키워드 예시: "길안내", "길찾기", "경로", "네비", "거기로", "안내해줘" 등
  bool isNavigationRequest(String userInput) {
    final input = userInput.toLowerCase().replaceAll(' ', '');

    const navigationKeywords = [
      '길안내',
      '길찾기',
      '경로',
      '네비',
      '네비게이션',
      '가는방법',
      '어떻게가',
      '거기로',
      '안내해',
      '안내해줘',
      '출발',
      '가자',
    ];

    return navigationKeywords.any((keyword) => input.contains(keyword));
  }

  /// 한국어 주석: 마지막 응답 메타데이터에서 LocationInfo 추출
  Future<LocationInfo?> extractDestinationFromMetadata(
    Map<String, dynamic>? metadata,
  ) async {
    if (metadata == null) {
      debugPrint('[NavigationContextResolver] metadata가 없습니다.');
      return null;
    }

    // 한국어 주석: location 필드 추출
    final dynamic locationRaw = metadata['location'];
    final location = locationRaw is String
        ? locationRaw
        : locationRaw != null
        ? locationRaw.toString()
        : null;
    if (location == null || location.trim().isEmpty) {
      debugPrint('[NavigationContextResolver] metadata.location이 비어 있습니다.');
      return null;
    }

    debugPrint('[NavigationContextResolver] geocoding 시작: $location');

    // 한국어 주석: 주소 → 좌표 변환
    final coordinates = await _geocodingService.getCoordinatesFromAddress(
      location,
    );
    if (coordinates == null) {
      debugPrint('[NavigationContextResolver] geocoding 실패: $location');
      return null;
    }

    // 한국어 주석: 간략한 장소명만 사용
    final displayName = _extractSimpleName(location);

    return LocationInfo(
      address: location,
      placeName: displayName,
      coordinates: coordinates,
    );
  }

  /// 한국어 주석: location 주소에서 간략한 이름 추출
  String _extractSimpleName(String location) {
    if (location.isEmpty) {
      return '음성 검색 결과';
    }

    final parts = location.split(',');
    if (parts.isEmpty) {
      return location.length > 30
          ? '${location.substring(0, 30)}...'
          : location;
    }

    final firstPart = parts[0].trim();
    final words = firstPart.split(' ');

    String simpleName;
    if (words.length >= 2) {
      simpleName = words.sublist(words.length - 2).join(' ');
    } else {
      simpleName = firstPart;
    }

    if (parts.length > 1) {
      final detail = parts[1].trim();
      final detailClean = detail.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
      if (detailClean.isNotEmpty) {
        simpleName = '$simpleName, $detailClean';
      }
    }

    return simpleName.length > 30
        ? '${simpleName.substring(0, 30)}...'
        : simpleName;
  }
}
