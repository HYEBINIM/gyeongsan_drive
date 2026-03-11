/// 목적지 검색 결과 모델
/// Kakao 로컬 API의 장소 검색 결과를 표현
class SearchResult {
  /// 장소명
  final String placeName;

  /// 도로명 주소
  final String address;

  /// 위도
  final double lat;

  /// 경도
  final double lng;

  /// 카테고리 (예: 지하철역, 카페 등)
  final String? category;

  const SearchResult({
    required this.placeName,
    required this.address,
    required this.lat,
    required this.lng,
    this.category,
  });

  /// Kakao API JSON 응답을 SearchResult로 변환
  factory SearchResult.fromKakaoJson(Map<String, dynamic> json) {
    return SearchResult(
      placeName: json['place_name'] as String? ?? '',
      address:
          json['road_address_name'] as String? ??
          json['address_name'] as String? ??
          '',
      lat: double.tryParse(json['y'] as String? ?? '0') ?? 0.0,
      lng: double.tryParse(json['x'] as String? ?? '0') ?? 0.0,
      category: json['category_group_name'] as String?,
    );
  }

  /// JSON으로 직렬화 (로컬 저장용)
  Map<String, dynamic> toJson() {
    return {
      'place_name': placeName,
      'address': address,
      'lat': lat,
      'lng': lng,
      'category': category,
    };
  }

  /// JSON에서 역직렬화
  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      placeName: json['place_name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String?,
    );
  }

  @override
  String toString() {
    return 'SearchResult(placeName: $placeName, address: $address, lat: $lat, lng: $lng)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchResult &&
        other.placeName == placeName &&
        other.address == address &&
        other.lat == lat &&
        other.lng == lng;
  }

  @override
  int get hashCode {
    return Object.hash(placeName, address, lat, lng);
  }
}
