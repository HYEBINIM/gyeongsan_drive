import '../../models/voice/rule_voice_intent.dart';
import '../vehicle/vehicle_api_service.dart';
import '../vehicle_info/driving_score_service.dart';

class RuleVehicleVoiceService {
  RuleVehicleVoiceService({
    VehicleApiService? vehicleApiService,
    DrivingScoreService? drivingScoreService,
  }) : _vehicleApiService = vehicleApiService ?? VehicleApiService(),
       _drivingScoreService = drivingScoreService ?? DrivingScoreService();

  final VehicleApiService _vehicleApiService;
  final DrivingScoreService _drivingScoreService;

  Future<String> buildResponse({
    required RuleVoiceIntent intent,
    required String mtId,
  }) async {
    switch (intent) {
      case RuleVoiceIntent.batterySoc:
        final data = await _vehicleApiService.getRealTimeCarInfo(mtId: mtId);
        final value = data?.displaySOC.round() ?? 0;
        return '현재 배터리 잔량은 $value퍼센트입니다.';
      case RuleVoiceIntent.vehicleSpeed:
        final data = await _vehicleApiService.getRealTimeCarInfo(mtId: mtId);
        final value = data?.vehicleSpeed.round() ?? 0;
        return '현재 차량 속도는 $value킬로미터입니다.';
      case RuleVoiceIntent.vehicleMileage:
        final data = await _vehicleApiService.getRealTimeCarInfo(mtId: mtId);
        final value = data?.mileage ?? 0;
        return '현재 총 주행거리는 $value킬로미터입니다.';
      case RuleVoiceIntent.drivingScore:
        final data = await _drivingScoreService.fetchDrivingScoreFromApi(
          mtId: mtId,
        );
        return '현재 운전 점수는 ${data.myScore}점입니다.';
      case RuleVoiceIntent.unsupported:
        throw StateError('지원하지 않는 intent입니다.');
    }
  }
}
