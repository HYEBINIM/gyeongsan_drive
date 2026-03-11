//lib/services/api_service.dart (전체 수정 버전)
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/place.dart';
import '../models/event.dart';
import '../models/bus_stop.dart';
import '../models/bus_route.dart';

// ⭐ 버스 노선 주변 장소 데이터 클래스 추가
class BusRoutePlaces {
  final List<dynamic> restaurants;
  final List<dynamic> attractions;
  final List<dynamic> events;

  BusRoutePlaces({
    required this.restaurants,
    required this.attractions,
    required this.events,
  });

  factory BusRoutePlaces.fromJson(Map<String, dynamic> json) {
    return BusRoutePlaces(
      restaurants: json['restaurants'] ?? [],
      attractions: json['attractions'] ?? [],
      events: json['events'] ?? [],
    );
  }
}

class ApiService {
  
  static const String _apiBaseUrl = 'http://211.58.207.209:2441/api/v1'; 
  
  // 카카오 API 키 (여기에 발급받은 REST API 키를 입력하세요)
  static const String _kakaoRestApiKey = '2d4a8ae426cac5566021305177587cef';
  
  static const String _naverGeocodeClientId = 't14lkvxmuw'; 
  static const String _naverGeocodeClientSecret = 'niNPCTn2zud0jHMwfLpNVvDarGdmxlEGjyjqLIGM'; 
  static const String _naverGeocodeApiUrl = 'https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc';
  
  String _cleanHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '');
  }

  // --- 1. 현위치 역지오코딩 (네이버 API 유지) ---
  Future<String> reverseGeocode({required double lat, required double lon}) async {
    if (_naverGeocodeClientId == 'YOUR_NAVER_MAP_CLIENT_ID') { 
      print('네이버 지도 API 키를 설정해주세요. 기본값 경산으로 진행합니다.');
      return '경산'; 
    }
    
    final url = Uri.parse('$_naverGeocodeApiUrl?coords=$lon,$lat&output=json');

    try {
      final response = await http.get(
        url,
        headers: {
          'X-NCP-APIGW-API-KEY-ID': _naverGeocodeClientId, 
          'X-NCP-APIGW-API-KEY': _naverGeocodeClientSecret,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final results = data['results'] as List<dynamic>?;

        if (results != null && results.isNotEmpty) {
          final String area1Name = results[0]['region']['area1']['name'] as String;
          final String area2Name = results[0]['region']['area2']['name'] as String; 
          
          if (area2Name.contains('경산')) return '경산';
          if (area1Name.contains('대구')) return '대구';
          
          return results[0]['region']['area3']['name'] as String;
        } else {
          print('Naver Geocode API returned no results.');
          return '경산'; 
        }
      } else {
        print('Naver Geocode API Failed: ${response.statusCode}');
        return '경산'; 
      }
    } catch (e) {
      print('Geocode Request error: $e');
      return '경산'; 
    }
  }

  // --- 2. 현위치 기반 TOP 5 장소 데이터 가져오기 ---
  Future<List<Place>> fetchHotplaces({required String locationName}) async {
    print('DB 조회 로직으로 전환됨: fetchHotplaces를 DB에서 상위 5개만 가져오도록 수정합니다.');
    
    final List<Map<String, dynamic>> dbResults = await _fetchPlacesFromDatabase(
      locationName: locationName,
    );
    
    final int limit = dbResults.length.clamp(0, 5); 
    
    List<Place> top5Places = [];
    for (int i = 0; i < limit; i++) {
      final item = dbResults[i];
      
      top5Places.add(Place(
        id: item['id'] ?? (i + 1),
        name: item['name'] as String? ?? '이름 없음',
        location: item['location'] as String? ?? '',
        local: item['local'] as String? ?? locationName,
        category: item['category'] as String? ?? '',
        content: item['content'] as String? ?? '',
        searchNum: item['search_num'] ?? (dbResults.length - i) * 10,
        telNumber: item['tel_number'] as String? ?? '',
        type: item['type'] ?? 0,
        hashtags: ['#${item['category'] ?? '음식점'}'],
      ));
    }
    
    return top5Places;
  }

  Future<List<Map<String, dynamic>>> _fetchPlacesFromDatabase({
    required String locationName,
  }) async {
    final url = Uri.parse('$_apiBaseUrl/place/top?location=$locationName'); 

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(utf8.decode(response.bodyBytes));
        
        List<dynamic> places;
        if (responseData is List) {
          places = responseData;
        } else if (responseData is Map && responseData.containsKey('places')) {
          places = responseData['places'] as List;
        } else {
          print('DB API 응답 형식 오류');
          return [];
        }
        
        print('DB API 조회 성공. 지역: $locationName, 조회된 장소 수: ${places.length}');
        return places.cast<Map<String, dynamic>>();

      } else {
        print('DB API 호출 실패 (Status: ${response.statusCode}). Response: ${utf8.decode(response.bodyBytes)}');
        return []; 
      }
    } catch (e) {
      print('DB API 요청 오류: $e');
      return []; 
    }
  }

  Future<List<Place>> fetchTourContentList({
    required Set<String> uniquePlaceNames,
    required int targetCount,
    required int currentCount,
    required String locationName, 
  }) async {
    return [];
  }

  // --- 4. DB 조회 데이터를 Place 모델로 변환 및 최종 목록 생성 (TOP 100) ---
  Future<List<Place>> fetchHotplacesList({
    required String locationName, 
    required List<Place> existingPlaces, 
  }) async {
    const int targetCount = 100;
    
    final List<Map<String, dynamic>> dbResults = await _fetchPlacesFromDatabase(
      locationName: locationName,
    );
    
    List<Place> finalPlaces = [];
    for (int i = 0; i < dbResults.length; i++) {
      final item = dbResults[i];
      
      finalPlaces.add(Place(
        id: item['id'] ?? (i + 1),
        name: item['name'] as String? ?? '이름 없음',
        location: item['location'] as String? ?? '',
        local: item['local'] as String? ?? locationName,
        category: item['category'] as String? ?? '',
        content: item['content'] as String? ?? '',
        searchNum: item['search_num'] ?? (dbResults.length - i) * 10,
        telNumber: item['tel_number'] as String? ?? '',
        type: item['type'] ?? 0,
        hashtags: ['#${item['category'] ?? '음식점'}'],
      ));
    }
    
    List<Place> result = finalPlaces.sublist(0, finalPlaces.length.clamp(0, targetCount));

    print('\n--- 최종 TOP ${result.length} 장소 목록 출력 (DB 조회, search_num 기준) ---');
    for (int i = 0; i < result.length; i++) {
      final place = result[i];
      print('${i + 1}위: ${place.name} (검색횟수: ${place.searchNum})');
    }
    print('---------------------------------------------------\n');

    return result;
  }
  
  // --- 5. 내 주변 장소 데이터 가져오기 ---
  Future<List<Place>> fetchNearbyPlaces({
    required double lat, 
    required double lon,
  }) async {
    final url = Uri.parse('$_apiBaseUrl/place/nearby?lat=$lat&lon=$lon');
    
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(utf8.decode(response.bodyBytes));
        
        List<dynamic> places;
        if (responseData is List) {
          places = responseData;
        } else if (responseData is Map && responseData.containsKey('places')) {
          places = responseData['places'] as List;
        } else {
          print('Nearby API 응답 형식 오류');
          return [];
        }
        
        List<Place> placesList = [];
        for (int i = 0; i < places.length; i++) {
            final item = places[i];
            
            double distanceKm = item['distance_km'] is double 
                ? item['distance_km'] 
                : (item['distance_km'] as int?)?.toDouble() ?? 0.0;
            
            String distanceText = distanceKm < 1 
                ? '${(distanceKm * 1000).toStringAsFixed(0)}m' 
                : '${distanceKm.toStringAsFixed(1)}km'; 

            List<String> hashtags = [distanceText, '#${item['category'] ?? '음식점'}']; 

            placesList.add(Place(
              id: item['id'] ?? (i + 1),
              name: item['name'] as String? ?? '이름 없음',
              location: item['location'] as String? ?? '',
              local: item['local'] as String? ?? '',
              category: item['category'] as String? ?? '',
              content: item['content'] as String? ?? '',
              searchNum: item['search_num'] ?? 0,
              telNumber: item['tel_number'] as String? ?? '',
              type: item['type'] ?? 0,
              hashtags: hashtags,
            ));
        }
        
        print('내 주변 장소 조회 성공: ${placesList.length}개');
        return placesList;
      } else {
        print('DB Nearby API Failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Nearby Request error: $e');
      return [];
    }
  }

  // --- 6. 문화 행사 데이터 가져오기 ---
  Future<List<Event>> fetchEvents({
    required double lat,
    required double lon,
    String? startDate,
    String? endDate,
  }) async {
    String queryParams = 'lat=$lat&lon=$lon';
    
    if (startDate != null) {
      queryParams += '&start_date=$startDate';
    }
    
    if (endDate != null) {
      queryParams += '&end_date=$endDate';
    }
    
    final url = Uri.parse('$_apiBaseUrl/event/nearby?$queryParams');
    
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(utf8.decode(response.bodyBytes));
        
        List<dynamic> events;
        if (responseData is List) {
          events = responseData;
        } else if (responseData is Map && responseData.containsKey('events')) {
          events = responseData['events'] as List;
        } else {
          print('Events API 응답 형식 오류');
          return [];
        }
        
        List<Event> eventsList = [];
        for (int i = 0; i < events.length; i++) {
          final item = events[i];
          
          eventsList.add(Event(
            contentId: item['contentid'] as String? ?? '',
            title: item['title'] as String? ?? '제목 없음',
            addr1: item['addr1'] as String? ?? '',
            addr2: item['addr2'] as String? ?? '',
            mapX: item['mapx'] as String? ?? '',
            mapY: item['mapy'] as String? ?? '',
            firstImage: item['firstimage'] as String? ?? '',
            tel: item['tel'] as String? ?? '',
            areaCode: item['areacode'] as String? ?? '',
            sigunguCode: item['sigungucode'] as String? ?? '',
            eventStartDate: item['eventstartdate'] as String?,
            eventEndDate: item['eventenddate'] as String?,
            progressType: item['progresstype'] as String?,
            festivalType: item['festivaltype'] as String?,
          ));
        }
        
        print('문화 행사 조회 성공: ${eventsList.length}개');
        return eventsList;
      } else if (response.statusCode == 404) {
        print('Events API 미구현 (404) - 빈 목록 반환');
        return [];
      } else {
        print('Events API Failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Events Request error: $e');
      return [];
    }
  }

  // --- 7. 내 주변 버스 정류장 데이터 가져오기 ---
  Future<List<BusStop>> fetchNearbyBusStops({
    required double lat, 
    required double lon,
    int radiusKm = 1,
  }) async {
    final url = Uri.parse('$_apiBaseUrl/bus/nearby?lat=$lat&lon=$lon&radius=$radiusKm');
    
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(utf8.decode(response.bodyBytes));
        
        List<dynamic> stops;
        if (responseData is List) {
          stops = responseData;
        } else if (responseData is Map && responseData.containsKey('stops')) {
          stops = responseData['stops'] as List;
        } else {
          print('Bus Stops API 응답 형식 오류');
          return [];
        }
        
        List<BusStop> stopsList = stops.map((item) => BusStop.fromJson(item)).toList();
        
        print('내 주변 버스 정류장 조회 성공: ${stopsList.length}개');
        return stopsList;
      } else if (response.statusCode == 404) {
        print('Bus Stops API 미구현 (404) - 빈 목록 반환');
        return [];
      } else {
        print('Bus Stops API Failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Bus Stops Request error: $e');
      return [];
    }
  }

  // --- 8. 정류장의 노선 목록 가져오기 ---
  Future<List<BusRoute>> fetchBusRoutesAtStop({
    required String stopCode,
    required String cityName,
  }) async {
    final url = Uri.parse('$_apiBaseUrl/bus/stop/$stopCode/routes?city=$cityName');
    
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(utf8.decode(response.bodyBytes));
        
        List<dynamic> routes;
        if (responseData is List) {
          routes = responseData;
        } else if (responseData is Map && responseData.containsKey('routes')) {
          routes = responseData['routes'] as List;
        } else {
          print('Bus Routes API 응답 형식 오류');
          return [];
        }
        
        List<BusRoute> routesList = routes.map((item) => BusRoute.fromJson(item)).toList();
        
        print('정류장 노선 조회 성공: ${routesList.length}개');
        return routesList;
      } else if (response.statusCode == 404) {
        print('Bus Routes API 미구현 (404) - 빈 목록 반환');
        return [];
      } else {
        print('Bus Routes API Failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Bus Routes Request error: $e');
      return [];
    }
  }

  // --- 9. 노선의 전체 경로(정류장 목록) 가져오기 ---
  Future<List<BusRouteStop>> fetchBusRouteStops({
    required String routeId,
    required String cityName,
  }) async {
    final url = Uri.parse('$_apiBaseUrl/bus/route/$routeId/stops?city=$cityName');
    
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(utf8.decode(response.bodyBytes));
        
        List<dynamic> stops;
        if (responseData is List) {
          stops = responseData;
        } else if (responseData is Map && responseData.containsKey('stops')) {
          stops = responseData['stops'] as List;
        } else {
          print('Route Stops API 응답 형식 오류');
          return [];
        }
        
        List<BusRouteStop> stopsList = stops.map((item) => BusRouteStop.fromJson(item)).toList();
        
        print('노선 경로 조회 성공: ${stopsList.length}개 정류장');
        return stopsList;
      } else if (response.statusCode == 404) {
        print('Route Stops API 미구현 (404) - 빈 목록 반환');
        return [];
      } else {
        print('Route Stops API Failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Route Stops Request error: $e');
      return [];
    }
  }

  // --- 10. ⭐ 버스 노선 주변 맛집/관광지/행사 가져오기 (NEW) ---
  Future<BusRoutePlaces> fetchBusRoutePlaces({
    required String routeId,
    required String cityName,
    double radiusKm = 0.5,
  }) async {
    final url = Uri.parse('$_apiBaseUrl/bus/route/$routeId/places?city=$cityName&radius=$radiusKm');
    
    try {
      final response = await http.get(url);
  
      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(utf8.decode(response.bodyBytes));
        
        if (responseData is Map) {
          // ⭐ Map<dynamic, dynamic>을 Map<String, dynamic>으로 캐스팅
          final Map<String, dynamic> data = Map<String, dynamic>.from(responseData);
          final places = BusRoutePlaces.fromJson(data);
          print('노선 주변 장소 조회 성공: 맛집 ${places.restaurants.length}개, 관광지 ${places.attractions.length}개, 행사 ${places.events.length}개');
          return places;
        } else {
          print('Route Places API 응답 형식 오류');
          return BusRoutePlaces(restaurants: [], attractions: [], events: []);
        }
      } else if (response.statusCode == 404) {
        print('Route Places API 미구현 (404) - 빈 목록 반환');
        return BusRoutePlaces(restaurants: [], attractions: [], events: []);
      } else {
        print('Route Places API Failed: ${response.statusCode}');
        return BusRoutePlaces(restaurants: [], attractions: [], events: []);
      }
    } catch (e) {
      print('Route Places Request error: $e');
      return BusRoutePlaces(restaurants: [], attractions: [], events: []);
    }
  }

  // --- 11. 카카오 장소 검색 API ---
  Future<List<Place>> searchPlaces({
    required String query,
    required double currentLat,
    required double currentLon,
  }) async {
    if (_kakaoRestApiKey == 'YOUR_KAKAO_REST_API_KEY') {
      throw Exception('카카오 REST API 키를 설정해주세요.');
    }

    print('🔍 카카오 검색 시작: "$query"');
    
    // 주소인지 판단
    bool isAddress = _isAddressQuery(query);
    
    if (isAddress) {
      print('🏠 주소 검색 모드');
      return await _searchByAddress(query, currentLat, currentLon);
    } else {
      print('🏢 키워드 검색 모드');
      return await _searchByKeyword(query, currentLat, currentLon);
    }
  }

  // api_service.dart에 추가

  // --- 12. DB 장소 검색 ---
  Future<List<Place>> searchPlacesFromDB({
    required String query,
    required double currentLat,
    required double currentLon,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    print('🔍 DB 검색 시작: "$query"');
    
    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse('$_apiBaseUrl/place/search?query=$encodedQuery&lat=$currentLat&lon=$currentLon');
    
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(utf8.decode(response.bodyBytes));
        
        List<dynamic> places;
        if (responseData is List) {
          places = responseData;
        } else if (responseData is Map && responseData.containsKey('places')) {
          places = responseData['places'] as List;
        } else {
          print('DB 검색 API 응답 형식 오류');
          return [];
        }
        
        List<Place> placesList = [];
        for (int i = 0; i < places.length; i++) {
          final item = places[i];
          
          double? distanceKm;
          if (item.containsKey('distance_km')) {
            distanceKm = item['distance_km'] is double 
                ? item['distance_km'] 
                : (item['distance_km'] as int?)?.toDouble();
          }
          
          String distanceText = '';
          List<String> hashtags = [];
          
          if (distanceKm != null) {
            distanceText = distanceKm < 1 
                ? '${(distanceKm * 1000).toStringAsFixed(0)}m' 
                : '${distanceKm.toStringAsFixed(1)}km';
            hashtags.add(distanceText);
          }
          
          if (item['category'] != null && (item['category'] as String).isNotEmpty) {
            hashtags.add('#${item['category']}');
          }

          placesList.add(Place(
            id: item['id'] ?? (i + 1),
            name: item['name'] as String? ?? '이름 없음',
            location: item['location'] as String? ?? '',
            local: item['local'] as String? ?? '',
            category: item['category'] as String? ?? '',
            content: item['content'] as String? ?? '',
            searchNum: item['search_num'] ?? 0,
            telNumber: item['tel_number'] as String? ?? '',
            type: item['type'] ?? 0,
            hashtags: hashtags,
          ));
        }
        
        print('✅ DB 검색 성공: ${placesList.length}개');
        return placesList;
      } else {
        print('❌ DB 검색 API 실패: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ DB 검색 오류: $e');
      return [];
    }
  }

  /// 입력이 주소인지 판단
  bool _isAddressQuery(String query) {
    List<String> addressKeywords = [
      '로', '길', '동', '구', '시', '군', '읍', '면', '리',
      '번지', '번길', '가', '대로', '아파트', '빌딩'
    ];
    
    bool hasNumber = RegExp(r'\d').hasMatch(query);
    bool hasAddressKeyword = addressKeywords.any((keyword) => query.contains(keyword));
    
    return hasNumber && hasAddressKeyword;
  }

  /// 주소로 검색
  Future<List<Place>> _searchByAddress(
    String address,
    double currentLat,
    double currentLon,
  ) async {
    try {
      // 카카오 주소 검색 API
      final encodedAddress = Uri.encodeComponent(address);
      final url = Uri.parse('https://dapi.kakao.com/v2/local/search/address.json?query=$encodedAddress');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'KakaoAK $_kakaoRestApiKey',
        },
      );

      print('📡 카카오 주소 검색 API 응답 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final documents = data['documents'] as List<dynamic>?;
        
        if (documents != null && documents.isNotEmpty) {
          final firstResult = documents[0];
          double addressLat = double.parse(firstResult['y'] as String);
          double addressLon = double.parse(firstResult['x'] as String);
          
          print('✅ 주소 좌표: 위도 $addressLat, 경도 $addressLon');
          
          // 해당 좌표 근처의 장소 검색
          return await _searchNearbyPlaces(addressLat, addressLon);
        } else {
          print('⚠️ 주소 검색 결과 없음. 키워드 검색으로 전환');
          return await _searchByKeyword(address, currentLat, currentLon);
        }
      } else {
        print('❌ 카카오 주소 검색 실패: ${response.statusCode}');
        return await _searchByKeyword(address, currentLat, currentLon);
      }
    } catch (e) {
      print('❌ 주소 검색 오류: $e');
      return await _searchByKeyword(address, currentLat, currentLon);
    }
  }

  /// 키워드로 검색
  Future<List<Place>> _searchByKeyword(
    String keyword,
    double currentLat,
    double currentLon,
  ) async {
    try {
      final encodedKeyword = Uri.encodeComponent(keyword);
      // 현재 위치 기준으로 검색 (x=경도, y=위도, radius=20000m)
      final url = Uri.parse(
        'https://dapi.kakao.com/v2/local/search/keyword.json?query=$encodedKeyword&x=$currentLon&y=$currentLat&radius=20000&size=15&sort=distance'
      );
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'KakaoAK $_kakaoRestApiKey',
        },
      );

      print('📡 카카오 키워드 검색 API 응답 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final documents = data['documents'] as List<dynamic>?;
        
        if (documents == null || documents.isEmpty) {
          print('⚠️ 검색 결과 없음');
          return [];
        }
        
        print('✅ 검색 결과: ${documents.length}개');
        
        List<Place> places = [];
        for (int i = 0; i < documents.length; i++) {
          final doc = documents[i];
          
          try {
            String placeName = doc['place_name'] as String? ?? '';
            String categoryName = doc['category_name'] as String? ?? '';
            String addressName = doc['address_name'] as String? ?? '';
            String roadAddressName = doc['road_address_name'] as String? ?? '';
            String phone = doc['phone'] as String? ?? '';
            
            String finalAddress = roadAddressName.isNotEmpty ? roadAddressName : addressName;
            
            // 좌표
            double placeLon = double.parse(doc['x'] as String? ?? '0');
            double placeLat = double.parse(doc['y'] as String? ?? '0');
            
            // 거리 계산
            double distanceKm = _calculateDistance(currentLat, currentLon, placeLat, placeLon);
            String distanceText = distanceKm < 1 
                ? '${(distanceKm * 1000).toStringAsFixed(0)}m' 
                : '${distanceKm.toStringAsFixed(1)}km';
            
            // 카테고리 처리
            String mainCategory = '';
            List<String> categoryTags = [];
            
            if (categoryName.isNotEmpty) {
              List<String> categories = categoryName.split('>').map((c) => c.trim()).toList();
              mainCategory = categories.isNotEmpty ? categories.last : categoryName;
              categoryTags = categories.map((c) => '#$c').toList();
            }
            
            // 해시태그 생성
            List<String> hashtags = [distanceText];
            hashtags.addAll(categoryTags);
            
            places.add(Place(
              id: i + 1,
              name: placeName,
              location: finalAddress,
              local: addressName.split(' ').isNotEmpty ? addressName.split(' ')[0] : '',
              category: mainCategory,
              content: categoryName,
              searchNum: 0,
              telNumber: phone,
              type: 6,
              hashtags: hashtags,
            ));
            
          } catch (e) {
            print('⚠️ 항목 파싱 오류 (index: $i): $e');
            continue;
          }
        }
        
        print('✅ 카카오 장소 검색 성공: ${places.length}개');
        if (places.isNotEmpty && places.first.hashtags.isNotEmpty) {
          print('📍 가장 가까운 장소: ${places.first.name} (${places.first.hashtags.first})');
        }
        
        return places;
        
      } else if (response.statusCode == 401) {
        throw Exception('카카오 API 인증 실패. API 키를 확인해주세요.');
      } else {
        throw Exception('카카오 검색 API 호출 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ 카카오 검색 요청 오류: $e');
      rethrow;
    }
  }

  /// 특정 좌표 근처의 장소 검색 (반경 1km)
  Future<List<Place>> _searchNearbyPlaces(double lat, double lon) async {
    try {
      // 카테고리 없이 전체 검색 (음식점, 카페, 편의점 등)
      final url = Uri.parse(
        'https://dapi.kakao.com/v2/local/search/keyword.json?x=$lon&y=$lat&radius=1000&size=15&sort=distance'
      );
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'KakaoAK $_kakaoRestApiKey',
        },
      );

      print('📡 카카오 근처 장소 검색 API 응답 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final documents = data['documents'] as List<dynamic>?;
        
        if (documents == null || documents.isEmpty) {
          print('⚠️ 근처 장소 없음');
          return [];
        }
        
        print('✅ 근처 장소: ${documents.length}개');
        
        List<Place> places = [];
        for (int i = 0; i < documents.length; i++) {
          final doc = documents[i];
          
          try {
            String placeName = doc['place_name'] as String? ?? '';
            String categoryName = doc['category_name'] as String? ?? '';
            String addressName = doc['address_name'] as String? ?? '';
            String roadAddressName = doc['road_address_name'] as String? ?? '';
            String phone = doc['phone'] as String? ?? '';
            String distance = doc['distance'] as String? ?? '0';
            
            String finalAddress = roadAddressName.isNotEmpty ? roadAddressName : addressName;
            
            // 거리 포맷팅
            double distanceM = double.parse(distance);
            String distanceText = distanceM < 1000 
                ? '${distanceM.toStringAsFixed(0)}m' 
                : '${(distanceM / 1000).toStringAsFixed(1)}km';
            
            // 카테고리 처리
            String mainCategory = '';
            List<String> categoryTags = [];
            
            if (categoryName.isNotEmpty) {
              List<String> categories = categoryName.split('>').map((c) => c.trim()).toList();
              mainCategory = categories.isNotEmpty ? categories.last : categoryName;
              categoryTags = categories.map((c) => '#$c').toList();
            }
            
            // 해시태그 생성
            List<String> hashtags = [distanceText];
            hashtags.addAll(categoryTags);
            
            places.add(Place(
              id: i + 1,
              name: placeName,
              location: finalAddress,
              local: addressName.split(' ').isNotEmpty ? addressName.split(' ')[0] : '',
              category: mainCategory,
              content: categoryName,
              searchNum: 0,
              telNumber: phone,
              type: 6,
              hashtags: hashtags,
            ));
            
          } catch (e) {
            print('⚠️ 항목 파싱 오류 (index: $i): $e');
            continue;
          }
        }
        
        print('✅ 근처 장소 검색 성공: ${places.length}개');
        if (places.isNotEmpty && places.first.hashtags.isNotEmpty) {
          print('📍 가장 가까운 장소: ${places.first.name} (${places.first.hashtags.first})');
        }
        
        return places;
        
      } else {
        print('❌ 근처 장소 검색 실패: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ 근처 장소 검색 오류: $e');
      return [];
    }
  }

  /// Haversine 공식으로 두 지점 간의 거리 계산 (km 단위)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  Future<List<BusStop>> fetchBusStopsByCamera({
    required double centerLat,
    required double centerLon,
    int radiusKm = 2,
  }) async {
    return await fetchNearbyBusStops(
      lat: centerLat,
      lon: centerLon,
      radiusKm: radiusKm,
    );
  }
}