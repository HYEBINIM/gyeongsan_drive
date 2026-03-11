import 'package:permission_handler/permission_handler.dart';

/// 권한 관리 서비스
/// 앱에서 필요한 권한 요청 및 상태 확인
class PermissionService {
  /// 위치 권한 요청
  /// 반환: 권한이 허용되면 true, 거부되면 false
  Future<bool> requestLocationPermission() async {
    try {
      // 현재 권한 상태 확인
      final status = await Permission.location.status;

      // 이미 권한이 허용된 경우
      if (status.isGranted) {
        return true;
      }

      // 영구적으로 거부된 경우 (설정으로 이동 필요)
      if (status.isPermanentlyDenied) {
        return false;
      }

      // 권한 요청 팝업 표시
      final result = await Permission.location.request();

      return result.isGranted;
    } catch (e) {
      throw '위치 권한 요청 중 오류가 발생했습니다: $e';
    }
  }

  /// 알림 권한 요청
  /// 반환: 권한이 허용되면 true, 거부되면 false
  Future<bool> requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (e) {
      throw '알림 권한 요청 중 오류가 발생했습니다: $e';
    }
  }

  /// 마이크 권한 요청
  /// 반환: 권한이 허용되면 true, 거부되면 false
  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      throw '마이크 권한 요청 중 오류가 발생했습니다: $e';
    }
  }

  /// 위치 권한 상태 확인
  Future<PermissionStatus> getLocationPermissionStatus() async {
    return await Permission.location.status;
  }

  /// 알림 권한 상태 확인
  Future<PermissionStatus> getNotificationPermissionStatus() async {
    return await Permission.notification.status;
  }

  /// 마이크 권한 상태 확인
  Future<PermissionStatus> getMicrophonePermissionStatus() async {
    return await Permission.microphone.status;
  }

  /// 모든 필수 권한이 허용되었는지 확인
  /// 반환: 모든 권한이 허용되면 true, 하나라도 거부되면 false
  Future<bool> areAllPermissionsGranted() async {
    try {
      final locationStatus = await getLocationPermissionStatus();
      final notificationStatus = await getNotificationPermissionStatus();
      final microphoneStatus = await getMicrophonePermissionStatus();

      return locationStatus.isGranted &&
          notificationStatus.isGranted &&
          microphoneStatus.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// 권한이 영구적으로 거부되었는지 확인
  /// 사용자가 "다시 묻지 않기"를 선택한 경우
  Future<bool> isLocationPermissionPermanentlyDenied() async {
    final status = await Permission.location.status;
    return status.isPermanentlyDenied;
  }

  Future<bool> isNotificationPermissionPermanentlyDenied() async {
    final status = await Permission.notification.status;
    return status.isPermanentlyDenied;
  }

  Future<bool> isMicrophonePermissionPermanentlyDenied() async {
    final status = await Permission.microphone.status;
    return status.isPermanentlyDenied;
  }

  /// 앱 설정 화면 열기
  /// 권한을 영구적으로 거부한 경우 설정에서 수동으로 변경 필요
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      throw '설정 화면 열기 중 오류가 발생했습니다: $e';
    }
  }
}
