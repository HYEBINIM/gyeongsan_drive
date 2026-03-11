import '../../models/vehicle_info_model.dart';
import '../../services/vehicle/firestore_vehicle_service.dart'; // RTDB → Firestore
import '../../services/auth/firebase_auth_service.dart';
import '../base/base_view_model.dart';
import '../base/auth_mixin.dart';

/// 차량 등록 화면의 비즈니스 로직을 담당하는 ViewModel
class VehicleRegistrationViewModel extends BaseViewModel with AuthMixin {
  final FirestoreVehicleService _vehicleFirebaseService; // RTDB → Firestore

  @override
  final FirebaseAuthService authService;

  VehicleRegistrationViewModel({
    required FirestoreVehicleService vehicleFirebaseService, // RTDB → Firestore
    required this.authService,
  }) : _vehicleFirebaseService = vehicleFirebaseService;

  // 상태 관리
  String _vehicleNumber = '';
  bool _isValidating = false;
  Map<String, dynamic>? _vehicleInfo;
  bool _isValidated = false;
  bool _isFinalizingRegistration = false; // 등록 완료 후 후속 처리 중 상태

  // Getters
  String get vehicleNumber => _vehicleNumber;
  bool get isValidating => _isValidating;
  Map<String, dynamic>? get vehicleInfo => _vehicleInfo;
  bool get isValidated => _isValidated;
  bool get isFinalizingRegistration => _isFinalizingRegistration;
  bool get canRegister => _isValidated && _vehicleInfo != null && !isLoading;
  bool get isVehicleNumberValid =>
      RegExp(r'^\d{4}$').hasMatch(_vehicleNumber.trim());

  /// 차량번호 설정
  void setVehicleNumber(String number) {
    _vehicleNumber = number;
    _isValidated = false;
    _vehicleInfo = null;
    clearError();
    notifyListeners();
  }

  /// 차량번호 검증 및 정보 조회
  ///
  /// 반환값:
  /// - null: 결과가 없거나 단일 결과(이 경우 ViewModel 내부에서 바로 선택 처리)
  /// - List<Map>: 동일한 뒷 4자리를 가진 차량이 여러 대인 경우, 선택용 목록
  Future<List<Map<String, dynamic>>?> validateVehicleNumber() async {
    final trimmed = _vehicleNumber.trim();

    if (trimmed.isEmpty) {
      setError('차량번호 뒷 4자리를 입력해주세요');
      return null;
    }

    if (!RegExp(r'^\d{4}$').hasMatch(trimmed)) {
      setError('차량번호 뒷 4자리 숫자만 입력해주세요');
      return null;
    }

    _isValidating = true;
    _vehicleInfo = null;
    _isValidated = false;
    notifyListeners();

    try {
      // Firebase cars 배열에서 부분 차량번호로 검색 (여러 대 가능)
      final results = await _vehicleFirebaseService
          .searchVehiclesByPartialNumber(trimmed);

      if (results.isEmpty) {
        setError('등록되지 않은 차량번호입니다');
        _isValidated = false;
        return null;
      }

      if (results.length == 1) {
        // 한국어 주석: 결과가 1대인 경우 바로 확정
        selectVehicle(results.first);
        return null;
      }

      // 한국어 주석: 동일한 뒷 4자리를 가진 차량이 여러 대인 경우
      // View에서 선택할 수 있도록 전체 목록을 반환하고,
      // 선택 전까지는 _vehicleInfo를 비워둔다.
      clearError();
      _vehicleInfo = null;
      _isValidated = false;
      return results;
    } catch (e) {
      setError(e.toString());
      _isValidated = false;
      return null;
    } finally {
      _isValidating = false;
      notifyListeners();
    }
  }

  /// 한국어 주석: 여러 검색 결과 중 사용자가 선택한 차량을 확정
  void selectVehicle(Map<String, dynamic> vehicle) {
    _vehicleInfo = vehicle;
    _isValidated = true;
    clearError();
    notifyListeners();
  }

  /// 차량 등록
  Future<bool> registerVehicle() async {
    if (!_isValidated || _vehicleInfo == null) {
      setError('먼저 차량 정보를 조회해주세요');
      return false;
    }

    return await withLoadingSilent(() async {
          // 1. 현재 로그인한 사용자 확인
          final userId = requiredUserId;

          // 2. 차량 정보 생성
          final vehicleInfoModel = VehicleInfo(
            vehicleId: '', // Firebase에서 자동 생성
            vehicleNumber: _vehicleInfo!['vehicleNumber'] as String,
            region: _vehicleInfo!['region'] as String,
            modelName: _vehicleInfo!['modelName'] as String,
            manufacturer: _vehicleInfo!['manufacturer'] as String? ?? '',
            fuelType: _vehicleInfo!['fuelType'] as String,
            mtId: _vehicleInfo!['mtId'] as String,
            registeredAt: DateTime.now(),
            isActive: true,
          );

          // 3. Firebase에 등록
          await _vehicleFirebaseService.registerUserVehicle(
            userId,
            vehicleInfoModel,
          );

          return true;
        }) ??
        false;
  }

  /// 등록 후속 처리 시작 (HomeViewModel 갱신 등)
  void setFinalizingRegistration(bool value) {
    _isFinalizingRegistration = value;
    notifyListeners();
  }

  /// 초기화
  void reset() {
    _vehicleNumber = '';
    _isValidating = false;
    _vehicleInfo = null;
    _isValidated = false;
    _isFinalizingRegistration = false;
    clearError();
    notifyListeners();
  }
}
