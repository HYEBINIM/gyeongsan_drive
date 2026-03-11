import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/location_model.dart';
import '../../models/road_condition_model.dart';
import '../../services/location/location_service.dart';
import '../../services/permission/permission_service.dart';
import '../../services/road_surface/road_condition_service.dart';
import '../../widgets/road_surface/road_condition_detail_sheet.dart';

/// 노면 정보 화면 상태 관리
/// 위치, 도로 상태 데이터, 선택된 마커 등을 관리
class RoadSurfaceViewModel extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final PermissionService _permissionService = PermissionService();
  final RoadConditionService _roadConditionService = RoadConditionService();

  // 상태
  LocationModel? _currentLocation;
  List<RoadConditionModel> _roadConditions = [];
  RoadConditionModel? _selectedCondition;
  bool _isLoading = true;
  bool _isLoadingConditions = false;
  String? _errorMessage;

  // Getters
  LocationModel? get currentLocation => _currentLocation;
  List<RoadConditionModel> get roadConditions => _roadConditions;
  RoadConditionModel? get selectedCondition => _selectedCondition;
  bool get isLoading => _isLoading;
  bool get isLoadingConditions => _isLoadingConditions;
  String? get errorMessage => _errorMessage;
  bool get hasLocation => _currentLocation != null;
  bool get hasConditions => _roadConditions.isNotEmpty;

  /// 초기화: 위치 권한 요청 및 현재 위치 가져오기
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 위치 권한 요청
      final granted = await _permissionService.requestLocationPermission();
      if (!granted) {
        _isLoading = false;
        _errorMessage = '위치 권한이 필요합니다. 설정에서 위치 권한을 허용해주세요.';
        notifyListeners();
        return;
      }

      // 마지막 알려진 위치를 먼저 사용 (빠른 로딩)
      final lastKnownLocation = await _locationService.getLastKnownLocation();
      if (lastKnownLocation != null) {
        _currentLocation = lastKnownLocation;
        _isLoading = false;
        notifyListeners();

        // 주변 도로 상태 정보 로드
        await _loadRoadConditions();
      }

      // 정확한 현재 위치 가져오기
      final location = await _locationService.getCurrentLocation();
      _currentLocation = location;
      _isLoading = false;
      notifyListeners();

      // 위치가 변경되면 도로 상태 정보 다시 로드
      if (lastKnownLocation == null) {
        await _loadRoadConditions();
      }
    } catch (e) {
      if (_currentLocation == null) {
        _errorMessage = '위치 정보를 가져올 수 없습니다.';
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 도로 상태 정보 로드
  /// 한국어 주석: 반경 제한 없이 모든 노면 위험 정보를 조회
  /// 데이터 로드 후 선제적으로 이미지 URL을 해석하여 캐시 워밍업
  Future<void> _loadRoadConditions() async {
    _isLoadingConditions = true;
    notifyListeners();

    try {
      // 모든 도로 상태 정보 조회 (반경 제한 없음)
      _roadConditions = await _roadConditionService.getAllRoadConditions();
      _isLoadingConditions = false;
      notifyListeners();

      // 한국어 주석: 이미지 URL 선제적 해석 (사용자 인터랙션 전에 캐시 워밍업)
      // UI 블로킹 없이 백그라운드에서 실행
      unawaited(RoadConditionDetailSheet.preResolveUrls(_roadConditions));
    } catch (e) {
      _isLoadingConditions = false;
      // 도로 상태 로드 실패해도 지도는 표시
      notifyListeners();
    }
  }

  /// 도로 상태 정보 새로고침
  Future<void> refreshRoadConditions() async {
    await _loadRoadConditions();
  }

  /// 마커 선택
  void selectCondition(RoadConditionModel condition) {
    _selectedCondition = condition;
    notifyListeners();
  }

  /// 마커 선택 해제
  void clearSelection() {
    _selectedCondition = null;
    notifyListeners();
  }

  /// 위치 새로고침
  Future<void> refreshLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      _currentLocation = location;
      notifyListeners();
    } catch (e) {
      // 위치 갱신 실패 시 기존 위치 유지
    }
  }

  @override
  void dispose() {
    _selectedCondition = null;
    super.dispose();
  }
}
