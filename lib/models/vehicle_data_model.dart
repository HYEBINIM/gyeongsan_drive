/// API 응답 모델
class VehicleDataResponse {
  final List<VehicleData> data;

  VehicleDataResponse({required this.data});

  factory VehicleDataResponse.fromJson(Map<String, dynamic> json) {
    return VehicleDataResponse(
      data: (json['data'] as List)
          .map((item) => VehicleData.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 차량 실시간 데이터 모델
class VehicleData {
  // 배터리 온도
  final double
  batteryCoolantInletTemperature; // BMS_BatteryCoolantInletTemperature

  // 셀 전압 (192개)
  final List<double> cellVoltages; // BMS_CellVoltage_001 ~ 192
  final double cellVoltageMax; // BMS_CellVoltage_Max
  final double cellVoltageMin; // BMS_CellVoltage_Min

  // 배터리 상태
  final double displaySOC; // BMS_DisplaySOC (배터리 잔량 %)
  final double hvPackCurrent; // BMS_HVPackCurrent (고전압 전류 A)
  final double hvPackVoltage; // BMS_HVPackVoltage (고전압 전압 V)
  final int quickChargeCount; // BMS_QuickChargeCount (급속 충전 횟수)

  // 배터리 온도 (18개)
  final List<double> temperatures; // BMS_Temperature_01 ~ 18

  // 주행 정보
  final int mileage; // CLU_Mileage (주행거리 km)
  final double vehicleSpeed; // VCU_VehicleSpeed_STD (속도 km/h)

  VehicleData({
    required this.batteryCoolantInletTemperature,
    required this.cellVoltages,
    required this.cellVoltageMax,
    required this.cellVoltageMin,
    required this.displaySOC,
    required this.hvPackCurrent,
    required this.hvPackVoltage,
    required this.quickChargeCount,
    required this.temperatures,
    required this.mileage,
    required this.vehicleSpeed,
  });

  factory VehicleData.fromJson(Map<String, dynamic> json) {
    // 192개 셀 전압 파싱
    List<double> cellVoltages = [];
    for (int i = 1; i <= 192; i++) {
      String key = 'BMS_CellVoltage_${i.toString().padLeft(3, '0')}';
      final value = json[key];
      if (value != null) {
        cellVoltages.add((value as num).toDouble());
      } else {
        cellVoltages.add(0.0);
      }
    }

    // 18개 온도 파싱
    List<double> temperatures = [];
    for (int i = 1; i <= 18; i++) {
      String key = 'BMS_Temperature_${i.toString().padLeft(2, '0')}';
      final value = json[key];
      if (value != null) {
        temperatures.add((value as num).toDouble());
      } else {
        temperatures.add(0.0);
      }
    }

    return VehicleData(
      batteryCoolantInletTemperature:
          (json['BMS_BatteryCoolantInletTemperature'] as num? ?? 0.0)
              .toDouble(),
      cellVoltages: cellVoltages,
      cellVoltageMax: (json['BMS_CellVoltage_Max'] as num? ?? 0.0).toDouble(),
      cellVoltageMin: (json['BMS_CellVoltage_Min'] as num? ?? 0.0).toDouble(),
      displaySOC: (json['BMS_DisplaySOC'] as num? ?? 0.0).toDouble(),
      hvPackCurrent: (json['BMS_HVPackCurrent'] as num? ?? 0.0).toDouble(),
      hvPackVoltage: (json['BMS_HVPackVoltage'] as num? ?? 0.0).toDouble(),
      quickChargeCount: (json['BMS_QuickChargeCount'] as num? ?? 0).toInt(),
      temperatures: temperatures,
      mileage: (json['CLU_Mileage'] as num? ?? 0).toInt(),
      vehicleSpeed: (json['VCU_VehicleSpeed_STD'] as num? ?? 0.0).toDouble(),
    );
  }

  /// 평균 온도 계산
  double get averageTemperature {
    if (temperatures.isEmpty) return 0.0;
    return temperatures.reduce((a, b) => a + b) / temperatures.length;
  }

  /// 최대 온도 계산
  double get maxTemperature {
    if (temperatures.isEmpty) return 0.0;
    return temperatures.reduce((a, b) => a > b ? a : b);
  }

  /// 최소 온도 계산
  double get minTemperature {
    if (temperatures.isEmpty) return 0.0;
    return temperatures.reduce((a, b) => a < b ? a : b);
  }
}
