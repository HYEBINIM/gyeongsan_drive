import '../../models/vehicle_info_model.dart';
import '../../services/vehicle/firestore_vehicle_service.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../base/base_view_model.dart';
import '../base/auth_mixin.dart';
import '../home/home_viewmodel.dart';
import '../vehicle_info/vehicle_info_viewmodel.dart';
import '../home/voice_command_viewmodel.dart';
import '../../utils/app_logger.dart';

/// 차량 관리 화면 ViewModel
class VehicleManagementViewModel extends BaseViewModel with AuthMixin {
  final FirestoreVehicleService _vehicleService;

  @override
  final FirebaseAuthService authService;

  HomeViewModel? _homeViewModel;
  VehicleInfoViewModel? _vehicleInfoViewModel;
  VoiceCommandViewModel? _voiceCommandViewModel;

  VehicleManagementViewModel({
    required FirestoreVehicleService vehicleService,
    required this.authService,
  }) : _vehicleService = vehicleService;

  // 상태
  List<VehicleInfo> _vehicles = [];

  // Getter
  List<VehicleInfo> get vehicles => _vehicles;
  VehicleInfo? get activeVehicle =>
      _vehicles.where((v) => v.isActive).firstOrNull;

  /// 한국어 주석: 홈/차량정보/음성명령 VM을 주입하여 차량 변경 시 즉시 재동기화
  VehicleManagementViewModel attachDependentViewModels({
    HomeViewModel? homeViewModel,
    VehicleInfoViewModel? vehicleInfoViewModel,
    VoiceCommandViewModel? voiceCommandViewModel,
  }) {
    _homeViewModel = homeViewModel;
    _vehicleInfoViewModel = vehicleInfoViewModel;
    _voiceCommandViewModel = voiceCommandViewModel;
    return this;
  }

  /// 차량 목록 로드
  ///
  /// [forceServer]가 true면 서버 강제 조회로 최신 상태를 반영합니다.
  Future<void> loadVehicles({bool forceServer = false}) async {
    await withLoading(() async {
      final userId = requiredUserId;

      _vehicles = await _vehicleService.getUserVehicles(
        userId,
        forceServer: forceServer,
      );
    });
  }

  /// 활성 차량 변경
  Future<bool> setActiveVehicle(String vehicleId) async {
    final result = await withLoadingSilent(() async {
      final userId = requiredUserId;

      await _vehicleService.setActiveVehicle(userId, vehicleId);

      // 서버 강제 조회로 최신 활성 차량과 목록 동기화
      final newActive = await _vehicleService.getUserActiveVehicle(
        userId,
        forceServer: true,
      );

      // 한국어 주석: 차량 변경 시 mtid 및 차량번호 디버그 출력
      AppLogger.debug(
        '🚗 [차량관리] 차량 변경 완료: ${newActive?.vehicleNumber ?? "없음"} (MT_ID: ${newActive?.mtId ?? "없음"})',
      );

      await loadVehicles(forceServer: true);

      await _reloadLinkedViewModels(newActiveVehicle: newActive);
      return true;
    });

    return result ?? false;
  }

  Future<void> _reloadLinkedViewModels({VehicleInfo? newActiveVehicle}) async {
    // 한국어 주석: 명시적으로 전달된 활성 차량 우선 사용, 없으면 내부 목록에서 조회
    newActiveVehicle ??= activeVehicle;

    // 활성 차량 정보가 없으면 일반 초기화만 수행
    if (newActiveVehicle == null) {
      final futures = <Future<void>>[];
      if (_homeViewModel != null) {
        futures.add(_homeViewModel!.initialize(force: true));
      }
      if (_vehicleInfoViewModel != null) {
        futures.add(_vehicleInfoViewModel!.initialize());
      }
      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }
      // VoiceCommandViewModel 초기화 (활성 차량 없음)
      _voiceCommandViewModel?.updateActiveVehicle(null);
      return;
    }

    // 모든 ViewModel에 활성 차량 정보를 직접 전달 (Firestore 재조회 없이)
    final futures = <Future<void>>[];

    if (_homeViewModel != null) {
      futures.add(
        _homeViewModel!.applyActiveVehicleAndReload(newActiveVehicle),
      );
    }

    if (_vehicleInfoViewModel != null) {
      futures.add(
        _vehicleInfoViewModel!.applyActiveVehicleAndReload(newActiveVehicle),
      );
    }

    // 병렬 실행으로 성능 향상
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    // VoiceCommandViewModel은 동기 업데이트 (마지막에 실행하여 덮어쓰기 방지)
    _voiceCommandViewModel?.updateActiveVehicle(newActiveVehicle);
  }

  /// 차량 삭제
  Future<bool> deleteVehicle(String vehicleId) async {
    final result = await withLoadingSilent(() async {
      final userId = requiredUserId;

      await _vehicleService.deleteVehicle(userId, vehicleId);
      // 목록 새로고침
      await loadVehicles();
      return true;
    });

    return result ?? false;
  }
}
