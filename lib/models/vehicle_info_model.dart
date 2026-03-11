/// 차량 기본 정보 모델 (Firebase 저장용)
class VehicleInfo {
  final String vehicleId; // Firebase 자동 생성 ID
  final String vehicleNumber; // 차량번호 (예: 경북16바3597)
  final String region; // 지역
  final String modelName; // 차량 모델명
  final String manufacturer; // 제조사 (예: 현대, 기아)
  final String fuelType; // 연료 타입
  final String mtId; // MT_ID (API measurement 파라미터)
  final DateTime registeredAt; // 등록 일시
  final bool isActive; // 현재 활성화된 차량 여부

  VehicleInfo({
    required this.vehicleId,
    required this.vehicleNumber,
    required this.region,
    required this.modelName,
    required this.manufacturer,
    required this.fuelType,
    required this.mtId,
    required this.registeredAt,
    this.isActive = false,
  });

  /// Firebase 데이터에서 VehicleInfo 생성
  factory VehicleInfo.fromJson(String id, Map<String, dynamic> json) {
    return VehicleInfo(
      vehicleId: id,
      vehicleNumber: json['vehicleNumber'] as String? ?? '',
      region: json['region'] as String? ?? '',
      modelName: json['modelName'] as String? ?? '',
      manufacturer: json['manufacturer'] as String? ?? '',
      fuelType: json['fuelType'] as String? ?? '',
      mtId: json['mtId'] as String? ?? '',
      registeredAt: json['registeredAt'] != null
          ? DateTime.parse(json['registeredAt'] as String)
          : DateTime.now(),
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  /// Firebase 저장용 JSON 변환
  Map<String, dynamic> toJson() {
    return {
      'vehicleNumber': vehicleNumber,
      'region': region,
      'modelName': modelName,
      'manufacturer': manufacturer,
      'fuelType': fuelType,
      'mtId': mtId,
      'registeredAt': registeredAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// 일부 필드만 업데이트한 새 인스턴스 생성
  VehicleInfo copyWith({
    String? vehicleId,
    String? vehicleNumber,
    String? region,
    String? modelName,
    String? manufacturer,
    String? fuelType,
    String? mtId,
    DateTime? registeredAt,
    bool? isActive,
  }) {
    return VehicleInfo(
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      region: region ?? this.region,
      modelName: modelName ?? this.modelName,
      manufacturer: manufacturer ?? this.manufacturer,
      fuelType: fuelType ?? this.fuelType,
      mtId: mtId ?? this.mtId,
      registeredAt: registeredAt ?? this.registeredAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
