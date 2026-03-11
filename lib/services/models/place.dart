// lib/models/place.dart

class Place {
  final int id;
  final String name;
  final String location; // "위도,경도" 형식 (예: "35.8221056,128.5647426")
  final String local; // 지역 (예: "대구광역시")
  final String category; // 카테고리 (예: "일반음식점")
  final String content; // 주소 (예: "대구광역시 달서구...")
  final int searchNum; // 검색 횟수
  final String telNumber; // 전화번호
  final int type;
  final List<String> hashtags; // 해시태그 (현재는 비어있음)

  Place({
    required this.id,
    required this.name,
    required this.location,
    required this.local,
    required this.category,
    required this.content,
    required this.searchNum,
    required this.telNumber,
    required this.type,
    this.hashtags = const [],
  });

  /// JSON에서 Place 객체 생성
  factory Place.fromJson(Map<String, dynamic> json) {
    List<String> tags = [];
    if (json['hashtags'] != null) {
      if (json['hashtags'] is List) {
        tags = List<String>.from(json['hashtags']);
      } else if (json['hashtags'] is String) {
        tags = [json['hashtags']];
      }
    }

    return Place(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      local: json['local']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      searchNum: json['search_num'] ?? 0,
      telNumber: json['tel_number']?.toString() ?? '',
      type: json['type'] ?? 0,
      hashtags: tags,
    );
  }

  /// Place 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'local': local,
      'category': category,
      'content': content,
      'search_num': searchNum,
      'tel_number': telNumber,
      'type': type,
      'hashtags': hashtags,
    };
  }

  /// 좌표 정보가 유효한지 확인
  bool hasValidCoordinates() {
    if (location.isEmpty) return false;
    
    try {
      final parts = location.split(',');
      if (parts.length != 2) return false;
      
      final lat = double.parse(parts[0].trim());
      final lng = double.parse(parts[1].trim());
      
      // 대한민국 좌표 범위 확인
      return lat >= 33.0 && lat <= 43.0 && lng >= 124.0 && lng <= 132.0;
    } catch (e) {
      return false;
    }
  }

  /// 위도 반환
  double? get latitude {
    try {
      final parts = location.split(',');
      if (parts.length == 2) {
        return double.parse(parts[0].trim());
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// 경도 반환
  double? get longitude {
    try {
      final parts = location.split(',');
      if (parts.length == 2) {
        return double.parse(parts[1].trim());
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// 검색 횟수로 정렬용 (rankValue 대신 searchNum 사용)
  int get rankValue => searchNum;
}