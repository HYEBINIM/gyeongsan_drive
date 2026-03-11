import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../../models/place_model.dart';
import '../cache/memory_cache_service.dart';
import '../cache/persistent_cache_service.dart';

/// 페이지네이션 결과를 담는 클래스
class PaginatedPlaces {
  final List<PlaceModel> places;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const PaginatedPlaces({
    required this.places,
    required this.lastDocument,
    required this.hasMore,
  });
}

/// 지역 정보 Firestore 서비스
///
/// Firestore의 region_info 데이터를 조회하고
/// PlaceModel로 변환하는 서비스 (RTDB에서 마이그레이션됨)
///
/// GeoPoint와 GeoFlutterFire를 사용한 반경 검색 지원
/// 메모리 캐시를 통한 성능 최적화
class FirestoreRegionInfoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'eastapp-dev',
  );

  final MemoryCacheService _cache = MemoryCacheService();
  final PersistentCacheService _persistentCache = PersistentCacheService();

  /// 페이지네이션 기본 페이지 크기
  static const int defaultPageSize = 30;

  /// 카테고리별 전체 장소 리스트 가져오기 (영구 캐시 사용)
  ///
  /// [categoryId]: UI 카테고리 ID
  /// [forceRefresh]: true면 캐시를 무시하고 서버에서 새로 로드
  /// Returns: PlaceModel 리스트 (전체 데이터)
  ///
  /// 24시간 영구 캐시를 사용하여 Firestore 읽기 비용을 절감합니다.
  /// 필터링과 정렬은 ViewModel에서 수행합니다.
  Future<List<PlaceModel>> getAllPlacesByCategory(
    String categoryId, {
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = 'region_places_$categoryId';

      // 1. 영구 캐시 확인 (forceRefresh가 아닌 경우)
      if (!forceRefresh) {
        final cachedData = await _persistentCache.getJsonList(cacheKey);
        if (cachedData != null) {
          // 캐시에서 PlaceModel로 변환
          return cachedData
              .map((json) => PlaceModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }

      // 2. Firestore에서 전체 데이터 로드
      final firebasePath = _getCategoryPath(categoryId);
      final snapshot = await _firestore
          .collection('region_info')
          .doc(firebasePath)
          .collection('items')
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      // 3. 데이터 파싱
      final places = <PlaceModel>[];
      final isMedical = categoryId == 'hospital' || categoryId == 'pharmacy';

      for (final doc in snapshot.docs) {
        final placeData = doc.data();
        final place = isMedical
            ? _parseMedicalPlace(doc.id, placeData, categoryId)
            : _parseGeneralPlace(doc.id, placeData, categoryId);
        places.add(place);
      }

      // 4. 영구 캐시에 저장 (24시간)
      final jsonList = places.map((p) => p.toJson()).toList();
      await _persistentCache.setJsonList(cacheKey, jsonList);

      return places;
    } catch (e) {
      throw '장소 정보를 불러올 수 없습니다: $e';
    }
  }

  /// 카테고리별 장소 리스트 가져오기 (페이지네이션 지원)
  ///
  /// [categoryId]: UI 카테고리 ID (hospital, pharmacy, parking, restroom, restaurant)
  /// [pageSize]: 한 페이지에 가져올 문서 수 (기본: 30)
  /// [lastDocument]: 이전 페이지의 마지막 문서 (커서 기반 페이지네이션)
  /// [useCache]: 캐시 사용 여부 (기본: true, 첫 페이지만)
  /// Returns: PaginatedPlaces (장소 목록, 마지막 문서, 추가 데이터 여부)
  Future<PaginatedPlaces> getPlacesByCategoryPaginated(
    String categoryId, {
    int pageSize = defaultPageSize,
    DocumentSnapshot? lastDocument,
    bool useCache = true,
  }) async {
    try {
      // 첫 페이지이고 캐시 사용 시 캐시 확인
      final cacheKey = 'places_${categoryId}_page0';
      if (lastDocument == null && useCache) {
        final cached = _cache.get<PaginatedPlaces>(cacheKey);
        if (cached != null) {
          return cached;
        }
      }

      // 1. 카테고리 ID → Firebase 경로 변환
      final firebasePath = _getCategoryPath(categoryId);

      // 2. Firestore 쿼리 구성 (페이지네이션)
      Query query = _firestore
          .collection('region_info')
          .doc(firebasePath)
          .collection('items')
          .limit(pageSize + 1); // +1로 다음 페이지 존재 여부 확인

      // 커서 기반 페이지네이션: 이전 페이지의 마지막 문서 이후부터
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      // 3. Firestore 조회
      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        return const PaginatedPlaces(
          places: [],
          lastDocument: null,
          hasMore: false,
        );
      }

      // 4. 다음 페이지 존재 여부 확인
      final hasMore = snapshot.docs.length > pageSize;
      final docs = hasMore ? snapshot.docs.sublist(0, pageSize) : snapshot.docs;

      // 5. 데이터 파싱
      final places = <PlaceModel>[];
      final isMedical = categoryId == 'hospital' || categoryId == 'pharmacy';

      for (final doc in docs) {
        final placeData = doc.data() as Map<String, dynamic>;

        final place = isMedical
            ? _parseMedicalPlace(doc.id, placeData, categoryId)
            : _parseGeneralPlace(doc.id, placeData, categoryId);

        places.add(place);
      }

      final result = PaginatedPlaces(
        places: places,
        lastDocument: docs.isNotEmpty ? docs.last : null,
        hasMore: hasMore,
      );

      // 첫 페이지만 캐시 저장 (5분간 유효)
      if (lastDocument == null) {
        _cache.set(cacheKey, result);
      }

      return result;
    } catch (e) {
      throw '장소 정보를 불러올 수 없습니다: $e';
    }
  }

  /// 카테고리별 장소 리스트 가져오기 (레거시 - 전체 조회)
  ///
  /// [categoryId]: UI 카테고리 ID (hospital, pharmacy, parking, restroom, restaurant)
  /// [useCache]: 캐시 사용 여부 (기본: true)
  /// Returns: PlaceModel 리스트 (거리, 운영상태는 ViewModel에서 계산)
  ///
  /// @deprecated 페이지네이션 버전 사용 권장: getPlacesByCategoryPaginated
  Future<List<PlaceModel>> getPlacesByCategory(
    String categoryId, {
    bool useCache = true,
  }) async {
    try {
      // 캐시 확인
      final cacheKey = 'places_$categoryId';
      if (useCache) {
        final cached = _cache.get<List<PlaceModel>>(cacheKey);
        if (cached != null) {
          return cached;
        }
      }

      // 1. 카테고리 ID → Firebase 경로 변환
      final firebasePath = _getCategoryPath(categoryId);

      // 2. Firestore 조회
      final snapshot = await _firestore
          .collection('region_info')
          .doc(firebasePath)
          .collection('items')
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      // 3. 데이터 파싱
      final places = <PlaceModel>[];

      // 4. 의료 API vs 일반 장소 형식 구분
      final isMedical = categoryId == 'hospital' || categoryId == 'pharmacy';

      for (final doc in snapshot.docs) {
        final placeData = doc.data();

        final place = isMedical
            ? _parseMedicalPlace(doc.id, placeData, categoryId)
            : _parseGeneralPlace(doc.id, placeData, categoryId);

        places.add(place);
      }

      // 캐시 저장 (5분간 유효)
      _cache.set(cacheKey, places);

      return places;
    } catch (e) {
      throw '장소 정보를 불러올 수 없습니다: $e';
    }
  }

  /// 반경 내 장소 검색 (GeoFlutterFire 사용)
  ///
  /// [categoryId]: 카테고리 ID
  /// [center]: 중심 좌표 (GeoPoint)
  /// [radiusInKm]: 반경 (km)
  /// Returns: 반경 내 PlaceModel 리스트
  Future<List<PlaceModel>> getPlacesWithinRadius(
    String categoryId,
    GeoPoint center,
    double radiusInKm,
  ) async {
    try {
      final firebasePath = _getCategoryPath(categoryId);
      final isMedical = categoryId == 'hospital' || categoryId == 'pharmacy';

      // GeoFlutterFire를 사용한 반경 검색
      final geo = GeoCollectionReference(
        _firestore
            .collection('region_info')
            .doc(firebasePath)
            .collection('items'),
      );

      // 반경 검색 쿼리
      final stream = geo.subscribeWithin(
        center: GeoFirePoint(center),
        radiusInKm: radiusInKm,
        field: 'location', // GeoPoint 필드명
        geopointFrom: (data) =>
            data['location'] as GeoPoint? ?? const GeoPoint(0, 0),
      );

      // Stream을 Future로 변환 (첫 번째 결과만)
      final docs = await stream.first;

      final places = <PlaceModel>[];
      for (final doc in docs) {
        final placeData = doc.data() as Map<String, dynamic>;

        final place = isMedical
            ? _parseMedicalPlace(doc.id, placeData, categoryId)
            : _parseGeneralPlace(doc.id, placeData, categoryId);

        places.add(place);
      }

      return places;
    } catch (e) {
      throw '반경 내 장소 검색 실패: $e';
    }
  }

  /// Firebase 경로 매핑
  ///
  /// UI 카테고리 ID → Firebase 경로
  String _getCategoryPath(String categoryId) {
    const pathMap = {
      'hospital': 'clinics',
      'pharmacy': 'pharmacies',
      'parking': 'parkings',
      'restroom': 'restrooms',
      'restaurant': 'driveThru',
    };
    return pathMap[categoryId] ?? categoryId;
  }

  /// 의료 API 형식 파싱 (clinics, pharmacies)
  ///
  /// 필드 매핑:
  /// - hpid → id
  /// - dutyName → name
  /// - dutyAddr → address
  /// - dutyTel1 → phoneNumber
  /// - location (GeoPoint) → latitude, longitude
  /// - hours → hoursData (원본 그대로 저장)
  PlaceModel _parseMedicalPlace(
    String id,
    Map<String, dynamic> data,
    String category,
  ) {
    // GeoPoint에서 위도/경도 추출
    final location = data['location'] as GeoPoint?;
    final latitude = location?.latitude ?? 0.0;
    final longitude = location?.longitude ?? 0.0;

    return PlaceModel(
      id: id,
      name: data['dutyName'] as String? ?? '',
      category: category,
      address: data['dutyAddr'] as String? ?? '',
      phoneNumber: data['dutyTel1'] as String?,
      latitude: latitude,
      longitude: longitude,
      distanceKm: 0.0, // ViewModel에서 계산
      isOpen: false, // ViewModel에서 계산
      openingHours: null, // ViewModel에서 생성
      hoursData: _convertHoursToMap(data['hours']),
    );
  }

  /// 일반 장소 형식 파싱 (parkings, restrooms, driveThru)
  ///
  /// 필드 매핑:
  /// - name → name
  /// - address → address
  /// - tel → phoneNumber
  /// - location (GeoPoint) → latitude, longitude
  /// - hours → hoursData (원본 그대로 저장)
  PlaceModel _parseGeneralPlace(
    String id,
    Map<String, dynamic> data,
    String category,
  ) {
    // GeoPoint에서 위도/경도 추출
    final location = data['location'] as GeoPoint?;
    final latitude = location?.latitude ?? 0.0;
    final longitude = location?.longitude ?? 0.0;

    return PlaceModel(
      id: id,
      name: data['name'] as String? ?? '',
      category: category,
      address: data['address'] as String? ?? '',
      phoneNumber: data['tel'] as String?,
      latitude: latitude,
      longitude: longitude,
      distanceKm: 0.0,
      isOpen: false,
      openingHours: null,
      hoursData: _convertHoursToMap(data['hours']),
    );
  }

  /// Firebase hours 데이터를 Map으로 변환
  ///
  /// Firestore에서는 Map 타입이 그대로 유지됨
  Map<String, dynamic>? _convertHoursToMap(dynamic hours) {
    if (hours == null) return null;

    // 이미 Map인 경우
    if (hours is Map) {
      return Map<String, dynamic>.from(hours);
    }

    return null;
  }
}
