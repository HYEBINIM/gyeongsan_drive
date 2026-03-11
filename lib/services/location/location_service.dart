import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';
import '../../models/location_model.dart';

/// 위치 정보 관리 서비스
/// 현재 위치 가져오기 및 위치 권한 확인
class LocationService {
  /// 위치 서비스 활성화 여부 확인
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// 위치 권한 상태 확인
  /// 온보딩에서 이미 권한을 요청했으므로, 상태만 확인
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// 현재 위치 가져오기
  /// 온보딩에서 이미 권한을 부여받았다고 가정
  /// 권한이 없거나 위치 서비스가 비활성화된 경우 예외 발생
  Future<LocationModel> getCurrentLocation() async {
    try {
      // 위치 서비스 활성화 확인
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw '위치 서비스가 비활성화되어 있습니다. 기기 설정에서 위치 서비스를 활성화해주세요.';
      }

      // 권한 상태 확인
      final permission = await checkPermission();

      // 권한이 거부된 경우
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw '위치 권한이 거부되었습니다. 설정에서 위치 권한을 허용해주세요.';
      }

      // 현재 위치 가져오기
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // 10미터 이동 시 업데이트
        ),
      );

      return LocationModel.fromPosition(position);
    } catch (e) {
      // 에러 메시지 그대로 던지기
      if (e is String) {
        rethrow;
      }
      throw '현재 위치를 가져올 수 없습니다: $e';
    }
  }

  /// 위치 스트림 가져오기 (실시간 위치 추적)
  /// 필요한 경우에만 사용
  Stream<LocationModel> getLocationStream() {
    final settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // 10미터 이동 시 업데이트
    );
    return Geolocator.getPositionStream(
      locationSettings: settings,
    ).map((position) => LocationModel.fromPosition(position));
  }

  /// 안전귀가 전용 백그라운드 위치 스트림
  /// - Android: Foreground Service 알림으로 백그라운드 유지
  /// - iOS: Background Location 업데이트 허용 및 인디케이터 표시
  Stream<LocationModel> getSafeHomeBackgroundLocationStream() {
    final LocationSettings platformSettings;
    if (Platform.isAndroid) {
      platformSettings = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '안전귀가 활성화',
          notificationText: '이상 감지 중 (위치 서비스 동작)',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (Platform.isIOS) {
      platformSettings = AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      platformSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    return Geolocator.getPositionStream(
      locationSettings: platformSettings,
    ).map((position) => LocationModel.fromPosition(position));
  }

  /// 두 위치 사이의 거리 계산 (미터 단위)
  double getDistanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// 마지막으로 알려진 위치 가져오기 (빠른 응답, 정확도 낮을 수 있음)
  Future<LocationModel?> getLastKnownLocation() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;

      return LocationModel.fromPosition(position);
    } catch (e) {
      return null;
    }
  }
}
