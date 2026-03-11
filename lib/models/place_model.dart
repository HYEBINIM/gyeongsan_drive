/// 장소 정보 모델
class PlaceModel {
  final String id;
  final String name;
  final String category;
  final bool isOpen;
  final String? openingHours;
  final double distanceKm;
  final String address;
  final String? phoneNumber;
  final double latitude;
  final double longitude;
  final Map<String, dynamic>? hoursData; // Firebase hours 원본 데이터

  PlaceModel({
    required this.id,
    required this.name,
    required this.category,
    required this.isOpen,
    this.openingHours,
    required this.distanceKm,
    required this.address,
    this.phoneNumber,
    required this.latitude,
    required this.longitude,
    this.hoursData,
  });

  /// JSON에서 PlaceModel 생성
  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      isOpen: json['isOpen'] as bool? ?? false,
      openingHours: json['openingHours'] as String?,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      hoursData: json['hoursData'] as Map<String, dynamic>?,
    );
  }

  /// 한국어 주석: 음성 명령 API 메타데이터에서 PlaceModel 생성
  /// 메타데이터 구조: {"answer": "...", "location": "...", "category": "..."}
  ///
  /// 카테고리 자동 추론 전략 (3단계 폴백):
  /// 1. 백엔드 제공 category 사용 (우선순위 최상)
  /// 2. tools_used에서 추론 (예: search_pharmacies → pharmacy)
  /// 3. 쿼리 텍스트에서 키워드 매칭 (예: "약국" → pharmacy)
  /// 4. 기본값 'hospital' 사용
  ///
  /// [metadata]: API 응답 메타데이터
  /// [toolsUsed]: API 응답의 tools_used 필드
  /// [originalQuery]: 사용자의 원본 음성 쿼리
  factory PlaceModel.fromVoiceMetadata(
    Map<String, dynamic> metadata, {
    List<dynamic>? toolsUsed,
    String? originalQuery,
  }) {
    final location = metadata['location'] as String? ?? '';

    // 한국어 주석: location에서 간략한 장소명 추출 (주소의 마지막 부분 사용)
    // 예: "경상북도 경산시 하양읍 하양로 112, 3층 (하양읍)" → "하양로 112, 3층"
    String placeName = _extractSimpleName(location);

    // 한국어 주석: 고유 ID 생성 (타임스탬프 기반)
    final id = 'voice_${DateTime.now().millisecondsSinceEpoch}';

    // 한국어 주석: 카테고리 자동 추론
    final category = _inferCategory(
      metadata: metadata,
      toolsUsed: toolsUsed,
      query: originalQuery ?? '',
    );

    return PlaceModel(
      id: id,
      name: placeName,
      category: category,
      isOpen: true, // 한국어 주석: 음성 검색 결과는 기본적으로 운영 중으로 가정
      openingHours: null,
      distanceKm: 0.0, // 한국어 주석: 거리는 지오코딩 후 계산
      address: location,
      phoneNumber: null, // 한국어 주석: 백엔드에서 제공 필요
      latitude: 0.0, // 한국어 주석: 지오코딩 전에는 0으로 설정
      longitude: 0.0,
      hoursData: null,
    );
  }

  /// 한국어 주석: 카테고리 자동 추론 (3단계 폴백 전략)
  ///
  /// 1순위: 백엔드 제공 category
  /// 2순위: tools_used 분석
  /// 3순위: 쿼리 키워드 매칭
  /// 기본값: 'hospital'
  static String _inferCategory({
    required Map<String, dynamic> metadata,
    List<dynamic>? toolsUsed,
    required String query,
  }) {
    // 1순위: 백엔드에서 category를 제공한 경우
    if (metadata['category'] != null) {
      final category = metadata['category'] as String;
      if (_isValidCategory(category)) {
        return category;
      }
    }

    // 2순위: tools_used 기반 추론
    final fromTools = _inferFromTools(toolsUsed);
    if (fromTools != null) {
      return fromTools;
    }

    // 3순위: 쿼리 키워드 매칭
    final fromQuery = _inferFromQuery(query);
    if (fromQuery != null) {
      return fromQuery;
    }

    // 기본값
    return 'hospital';
  }

  /// 한국어 주석: 유효한 카테고리인지 확인
  static bool _isValidCategory(String category) {
    const validCategories = [
      'hospital',
      'pharmacy',
      'parking',
      'restroom',
      'restaurant',
    ];
    return validCategories.contains(category);
  }

  /// 한국어 주석: tools_used 필드에서 카테고리 추론
  ///
  /// 도구 이름에 카테고리 키워드가 포함되어 있으면 해당 카테고리 반환
  /// 예: "search_pharmacies" → "pharmacy"
  static String? _inferFromTools(List<dynamic>? tools) {
    if (tools == null || tools.isEmpty) {
      return null;
    }

    // 도구 이름 → 카테고리 매핑
    const toolCategoryMap = {
      'hospital': ['hospital', 'clinic', '병원', '의원'],
      'pharmacy': ['pharmacy', 'pharmacies', '약국'],
      'parking': ['parking', '주차'],
      'restroom': ['restroom', 'toilet', '화장실'],
      'restaurant': ['restaurant', 'food', '음식', '식당'],
    };

    for (var tool in tools) {
      final toolName = tool.toString().toLowerCase();

      // 각 카테고리의 키워드를 도구 이름에서 검색
      for (var entry in toolCategoryMap.entries) {
        final categoryId = entry.key;
        final keywords = entry.value;

        for (var keyword in keywords) {
          if (toolName.contains(keyword.toLowerCase())) {
            return categoryId;
          }
        }
      }
    }

    return null;
  }

  /// 한국어 주석: 쿼리 텍스트에서 키워드 매칭으로 카테고리 추론
  ///
  /// 음성 인식 쿼리에 카테고리 관련 키워드가 포함되어 있으면 해당 카테고리 반환
  /// 예: "근처 약국 찾아줘" → "pharmacy"
  static String? _inferFromQuery(String query) {
    if (query.isEmpty) {
      return null;
    }

    final queryLower = query.toLowerCase();

    // 키워드 → 카테고리 매핑 (우선순위 순서대로)
    const keywordMap = {
      'pharmacy': ['약국', 'pharmacy', '약', '드럭스토어'],
      'parking': ['주차', '주차장', 'parking', '파킹'],
      'restroom': ['화장실', '화장', '변소', 'restroom', 'toilet', '화'],
      'restaurant': ['식당', '음식점', '맛집', 'restaurant', '밥', '음식'],
      'hospital': ['병원', '의원', '클리닉', 'hospital', 'clinic', '진료소'],
    };

    // 한국어 주석: 각 카테고리의 키워드를 쿼리에서 검색
    // 주의: 짧은 키워드는 오탐지 가능성이 있으므로 긴 키워드를 먼저 검사
    for (var entry in keywordMap.entries) {
      final categoryId = entry.key;
      final keywords = entry.value;

      for (var keyword in keywords) {
        if (queryLower.contains(keyword.toLowerCase())) {
          return categoryId;
        }
      }
    }

    return null;
  }

  /// 한국어 주석: location 주소에서 간략한 이름 추출
  /// 예: "경상북도 경산시 하양읍 하양로 112, 3층 (하양읍)" → "하양로 112, 3층"
  static String _extractSimpleName(String location) {
    if (location.isEmpty) {
      return '음성 검색 결과';
    }

    // 한국어 주석: 쉼표 앞부분에서 도로명/지번 주소 추출
    // "경상북도 경산시 하양읍 하양로 112, 3층" → ["경상북도 경산시 하양읍 하양로 112", " 3층"]
    final parts = location.split(',');
    if (parts.isEmpty) {
      return location.length > 30
          ? '${location.substring(0, 30)}...'
          : location;
    }

    // 한국어 주석: 첫 번째 부분에서 마지막 2개 단어만 사용 (도로명 + 번지)
    // "경상북도 경산시 하양읍 하양로 112" → ["경상북도", "경산시", "하양읍", "하양로", "112"]
    final firstPart = parts[0].trim();
    final words = firstPart.split(' ');

    String simpleName;
    if (words.length >= 2) {
      // 마지막 2개 단어 사용 (예: "하양로 112")
      simpleName = words.sublist(words.length - 2).join(' ');
    } else {
      simpleName = firstPart;
    }

    // 한국어 주석: 상세 주소가 있으면 추가 (예: "3층", "101호")
    if (parts.length > 1) {
      final detail = parts[1].trim();
      // 괄호 제거 (예: "(하양읍)" 제거)
      final detailClean = detail.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
      if (detailClean.isNotEmpty) {
        simpleName = '$simpleName, $detailClean';
      }
    }

    return simpleName.length > 30
        ? '${simpleName.substring(0, 30)}...'
        : simpleName;
  }

  /// PlaceModel을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'isOpen': isOpen,
      'openingHours': openingHours,
      'distanceKm': distanceKm,
      'address': address,
      'phoneNumber': phoneNumber,
      'latitude': latitude,
      'longitude': longitude,
      'hoursData': hoursData,
    };
  }

  /// 더미 데이터 (테스트용)
  static List<PlaceModel> getDummyPlaces(String category) {
    switch (category) {
      case 'hospital':
        return [
          PlaceModel(
            id: '1',
            name: '파티마여성병원스마트분과의원',
            category: 'hospital',
            isOpen: true,
            openingHours: '23:00까지 운영중',
            distanceKm: 19.3,
            address: '경상북도 경산시 팬티밸리2로 57, 4층, 9동 (중산동)',
            phoneNumber: '053-1234-5678',
            latitude: 37.5665,
            longitude: 126.9780,
          ),
          PlaceModel(
            id: '2',
            name: '폼그린소아청소년과과의원',
            category: 'hospital',
            isOpen: false,
            openingHours: '21:00에 운영종료',
            distanceKm: 19.6,
            address: '경상북도 경산시 대학로 11, 3~6층 (중산동)',
            phoneNumber: '053-2345-6789',
            latitude: 37.4979,
            longitude: 127.0276,
          ),
        ];
      case 'pharmacy':
        return [
          PlaceModel(
            id: '3',
            name: '24시온누리약국',
            category: 'pharmacy',
            isOpen: true,
            openingHours: '24시간 운영',
            distanceKm: 12.5,
            address: '경상북도 경산시 중앙로 123 (중산동)',
            phoneNumber: '053-3456-7890',
            latitude: 37.5000,
            longitude: 127.0000,
          ),
          PlaceModel(
            id: '4',
            name: '행복드림약국',
            category: 'pharmacy',
            isOpen: true,
            openingHours: '22:00까지 운영중',
            distanceKm: 15.2,
            address: '경상북도 경산시 대학로 456 (압량읍)',
            phoneNumber: '053-4567-8901',
            latitude: 37.5100,
            longitude: 127.0100,
          ),
        ];
      default:
        return [
          PlaceModel(
            id: '5',
            name: '$category 샘플 장소 1',
            category: category,
            isOpen: true,
            openingHours: '18:00까지 운영중',
            distanceKm: 10.0,
            address: '경상북도 경산시 샘플로 100',
            phoneNumber: '053-5678-9012',
            latitude: 37.5200,
            longitude: 127.0200,
          ),
        ];
    }
  }

  /// copyWith 패턴
  PlaceModel copyWith({
    String? id,
    String? name,
    String? category,
    bool? isOpen,
    String? openingHours,
    double? distanceKm,
    String? address,
    String? phoneNumber,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? hoursData,
  }) {
    return PlaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      isOpen: isOpen ?? this.isOpen,
      openingHours: openingHours ?? this.openingHours,
      distanceKm: distanceKm ?? this.distanceKm,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      hoursData: hoursData ?? this.hoursData,
    );
  }

  @override
  String toString() {
    return 'PlaceModel(id: $id, name: $name, category: $category, isOpen: $isOpen, distanceKm: $distanceKm)';
  }
}
