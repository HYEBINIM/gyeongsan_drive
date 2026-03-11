import 'package:flutter/material.dart';
import '../../models/vehicle_data_model.dart';
import '../../models/vehicle_info_model.dart';
import '../../services/vehicle/vehicle_api_service.dart';
import '../../services/vehicle/firestore_vehicle_service.dart'; // RTDB → Firestore
import '../../services/auth/firebase_auth_service.dart';
import '../../utils/app_logger.dart';
import '../base/base_view_model.dart';
import '../base/auth_mixin.dart';
import 'voice_command_viewmodel.dart';

enum HomeViewStatus { idle, loading, loaded, error }

/// 홈 화면의 비즈니스 로직을 담당하는 ViewModel
class HomeViewModel extends BaseViewModel with AuthMixin {
  final VehicleApiService _apiService;
  final FirestoreVehicleService _firebaseService; // RTDB → Firestore

  @override
  final FirebaseAuthService authService;

  HomeViewModel({
    required VehicleApiService apiService,
    required FirestoreVehicleService firebaseService, // RTDB → Firestore
    required this.authService,
  }) : _apiService = apiService,
       _firebaseService = firebaseService;

  // 상태 관리
  VehicleInfo? _vehicleInfo; // 사용자의 차량 정보
  VehicleData? _vehicleData; // 실시간 차량 데이터
  bool _isRefreshing = false;
  bool _hasVehicle = false; // 차량 등록 여부
  bool _isInitialized = false; // 초기화 완료 여부 (중복 호출 방지)
  HomeViewStatus _state = HomeViewStatus.idle;
  VoiceCommandViewModel? _voiceCommandViewModel;

  // Getters
  VehicleInfo? get vehicleInfo => _vehicleInfo;
  VehicleData? get vehicleData => _vehicleData;
  bool get isRefreshing => _isRefreshing;
  bool get hasVehicle => _hasVehicle;
  bool get hasData => _vehicleData != null && _vehicleInfo != null;
  HomeViewStatus get state => _state;

  /// 한국어 주석: 음성 명령 VM을 주입해 MT_ID 변경 이벤트 전달
  void attachVoiceCommandViewModel(VoiceCommandViewModel? viewModel) {
    _voiceCommandViewModel = viewModel;
    _syncVoiceCommandVehicle();
  }

  /// 초기 로드: 사용자 차량 확인 후 데이터 조회
  /// [force] 매개변수를 true로 설정하면 이미 초기화된 경우에도 재초기화
  Future<void> initialize({bool force = false}) async {
    // 이미 초기화되었고 force가 false면 조기 반환 (중복 호출 방지)
    if (_isInitialized && !force && _state != HomeViewStatus.error) {
      return;
    }

    _setLoadingState();

    try {
      await withLoading(() async {
        // 1. 현재 로그인한 사용자 확인
        final userId = requiredUserId;

        // 2. 사용자의 활성화된 차량 조회
        final vehicleInfo = await _firebaseService.getUserActiveVehicle(
          userId,
          forceServer: force, // force가 true면 캐시 무시하고 서버에서 최신 데이터 가져오기
        );

        if (vehicleInfo == null) {
          // 등록된 차량 없음
          _hasVehicle = false;
          _vehicleInfo = null;
          _syncVoiceCommandVehicle();
          _vehicleData = null;
          AppLogger.debug('🏠 [홈] 등록된 차량 없음');
        } else {
          // 차량 있음
          _hasVehicle = true;
          _vehicleInfo = vehicleInfo;
          _syncVoiceCommandVehicle();

          // 한국어 주석: 홈 초기화 시 mtid 및 차량번호 디버그 출력
          AppLogger.debug(
            '🏠 [홈] 차량 정보 로드: ${vehicleInfo.vehicleNumber} (MT_ID: ${vehicleInfo.mtId})',
          );

          // manufacturer 필드 마이그레이션 (필요한 경우)
          await _migrateManufacturerIfNeeded(userId, vehicleInfo);

          // API 데이터 조회
          await _loadVehicleData();
        }

        // 초기화 완료 표시
        _isInitialized = true;
      });

      _setState(HomeViewStatus.loaded);
    } catch (_) {
      _setState(HomeViewStatus.error);
      rethrow;
    }
  }

  /// 차량 데이터 로드 (내부 메서드)
  Future<void> _loadVehicleData() async {
    final vehicleInfo = _vehicleInfo;
    if (vehicleInfo == null) {
      throw '차량 정보가 없습니다';
    }

    // 한국어 주석: 차량 데이터 요청 시 mtid 및 차량번호 디버그 출력
    AppLogger.debug(
      '🏠 [홈] 차량 데이터 요청: ${vehicleInfo.vehicleNumber} (MT_ID: ${vehicleInfo.mtId})',
    );

    try {
      final data = await _apiService.getRealTimeCarInfo(mtId: vehicleInfo.mtId);

      if (data != null) {
        _vehicleData = data;
      } else {
        throw '차량 데이터가 없습니다';
      }
    } catch (e) {
      throw _normalizeErrorMessage(e);
    }
  }

  /// 새로고침
  Future<void> refreshData() async {
    if (_isRefreshing || _vehicleInfo == null) return;

    _isRefreshing = true;
    _setLoadingState();

    // 한국어 주석: 데이터 새로고침 시 mtid 및 차량번호 디버그 출력
    AppLogger.debug(
      '🏠 [홈] 데이터 새로고침: ${_vehicleInfo!.vehicleNumber} (MT_ID: ${_vehicleInfo!.mtId})',
    );

    String? refreshError;
    try {
      await _loadVehicleData();
      _setState(HomeViewStatus.loaded, notify: false);
    } catch (e) {
      debugPrint('새로고침 실패: $e');
      refreshError = _normalizeErrorMessage(e);
      _setState(HomeViewStatus.error, notify: false);
    } finally {
      _isRefreshing = false;
      if (refreshError != null) {
        setError(refreshError);
      } else {
        notifyListeners();
      }
    }
  }

  /// 차량 정보만 선택적으로 갱신 (경량 갱신)
  /// 차량 등록/변경 후 사용하여 불필요한 전체 초기화를 방지
  Future<void> refreshVehicleOnly() async {
    _setLoadingState();

    await withLoadingSilent(() async {
      // 1. 현재 로그인한 사용자 확인
      final userId = requiredUserId;

      // 2. 서버에서 최신 차량 정보만 조회
      final vehicleInfo = await _firebaseService.getUserActiveVehicle(
        userId,
        forceServer: true,
      );

      if (vehicleInfo != null) {
        _hasVehicle = true;
        _vehicleInfo = vehicleInfo;
        _syncVoiceCommandVehicle();

        AppLogger.debug(
          '🏠 [홈] 차량 정보만 갱신: ${vehicleInfo.vehicleNumber} (MT_ID: ${vehicleInfo.mtId})',
        );

        // manufacturer 필드 마이그레이션 (필요한 경우)
        await _migrateManufacturerIfNeeded(userId, vehicleInfo);

        // 차량 데이터도 갱신
        await _loadVehicleData();
      } else {
        _hasVehicle = false;
        _vehicleInfo = null;
        _vehicleData = null;
        _syncVoiceCommandVehicle();
      }
    });

    if (hasError) {
      _setState(HomeViewStatus.error);
    } else {
      _setState(HomeViewStatus.loaded);
    }
  }

  /// 차량 등록 후 다시 로드
  Future<void> reloadAfterVehicleRegistration() async {
    await initialize();
  }

  /// manufacturer 필드가 없는 경우 마이그레이션
  Future<void> _migrateManufacturerIfNeeded(
    String userId,
    VehicleInfo vehicleInfo,
  ) async {
    // manufacturer 필드가 비어있는 경우에만 실행
    if (vehicleInfo.manufacturer.isEmpty) {
      try {
        // Firebase cars 배열에서 차량 정보 재조회
        final carData = await _firebaseService.getVehicleByFullNumber(
          vehicleInfo.vehicleNumber,
        );

        if (carData != null && carData['manufacturer'] != null) {
          final manufacturer = carData['manufacturer'] as String;

          // Firebase에 manufacturer 필드 업데이트
          await _firebaseService.updateVehicleFields(
            userId,
            vehicleInfo.vehicleId,
            {'manufacturer': manufacturer},
          );

          // 메모리 상의 vehicleInfo도 업데이트
          _vehicleInfo = vehicleInfo.copyWith(manufacturer: manufacturer);
          _syncVoiceCommandVehicle();
        }
      } catch (e) {
        // 마이그레이션 실패해도 앱 실행은 계속
        debugPrint('manufacturer 마이그레이션 실패: $e');
      }
    }
  }

  // 한국어 주석: clearError()는 BaseViewModel에서 상속

  /// 한국어 주석: 차량 관리 화면에서 활성 차량을 변경한 직후
  /// 새 MT_ID로 실시간 데이터를 빠르게 다시 로드하기 위한 헬퍼
  Future<void> applyActiveVehicleAndReload(VehicleInfo vehicle) async {
    // 한국어 주석: 차량 적용 시 mtid 및 차량번호 디버그 출력
    AppLogger.debug(
      '🏠 [홈] 활성 차량 적용: ${vehicle.vehicleNumber} (MT_ID: ${vehicle.mtId})',
    );

    // 즉시 활성 차량 교체 및 상태 반영 (스켈레톤 표시 목적)
    _vehicleInfo = vehicle;

    _syncVoiceCommandVehicle();
    _hasVehicle = true;
    clearError();
    _setState(HomeViewStatus.loading, notify: false);
    _isInitialized = true; // 한국어 주석: 재초기화된 상태로 간주
    notifyListeners(); // 즉시 UI 반영: 새 차량 정보를 구독자들에게 알림

    try {
      await withLoading(() async {
        final userId = requiredUserId;
        // manufacturer 필드 보정 시도 (필요한 경우)
        await _migrateManufacturerIfNeeded(userId, vehicle);
        await _loadVehicleData();
      });
      _setState(HomeViewStatus.loaded);
    } catch (_) {
      _setState(HomeViewStatus.error);
      rethrow;
    }
  }

  void _setLoadingState() {
    _state = HomeViewStatus.loading;
    if (errorMessage != null) {
      setError(null);
    } else {
      notifyListeners();
    }
  }

  void _setState(HomeViewStatus nextState, {bool notify = true}) {
    _state = nextState;
    if (notify) {
      notifyListeners();
    }
  }

  String _normalizeErrorMessage(Object error) {
    final message = error.toString().trim();
    if (message.isEmpty) {
      return '알 수 없는 오류가 발생했습니다';
    }
    return message;
  }

  void _syncVoiceCommandVehicle() {
    _voiceCommandViewModel?.updateActiveVehicle(_vehicleInfo);
  }
}
