import 'dart:math';

/// 일별 SOH (State of Health) 모델
class DailySOH {
  final DateTime date;
  final double soh; // SOH 백분율 (0-100)

  DailySOH({required this.date, required this.soh});

  /// JSON으로부터 DailySOH 객체 생성 (내부 저장용)
  factory DailySOH.fromJson(Map<String, dynamic> json) {
    return DailySOH(
      date: DateTime.parse(json['date'] as String),
      soh: (json['soh'] as num).toDouble(),
    );
  }

  /// API 응답으로부터 DailySOH 객체 생성
  factory DailySOH.fromApiJson(Map<String, dynamic> json) {
    return DailySOH(
      date: DateTime.parse(json['date'] as String),
      soh: (json['soh'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// DailySOH 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {'date': date.toIso8601String(), 'soh': soh};
  }
}

/// 비교 차량 정보 모델
class PeerVehicle {
  final String measurement; // 차량 측정 ID
  final double avgSoh; // 평균 SOH
  final double avgMileage; // 평균 주행거리

  PeerVehicle({
    required this.measurement,
    required this.avgSoh,
    required this.avgMileage,
  });

  /// API 응답으로부터 PeerVehicle 객체 생성
  factory PeerVehicle.fromApiJson(Map<String, dynamic> json) {
    return PeerVehicle(
      measurement: json['measurement'] as String? ?? '',
      avgSoh: (json['avg_soh'] as num?)?.toDouble() ?? 0.0,
      avgMileage: (json['avg_mileage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// JSON으로부터 PeerVehicle 객체 생성
  factory PeerVehicle.fromJson(Map<String, dynamic> json) {
    return PeerVehicle(
      measurement: json['measurement'] as String,
      avgSoh: (json['avgSoh'] as num).toDouble(),
      avgMileage: (json['avgMileage'] as num).toDouble(),
    );
  }

  /// PeerVehicle 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'measurement': measurement,
      'avgSoh': avgSoh,
      'avgMileage': avgMileage,
    };
  }
}

/// SOH 비교 데이터 모델
class SOHComparison {
  final double allUserAverage; // 전체 사용자 평균 SOH
  final double sameModelAverage; // 동일 차종 평균 SOH
  final int percentileRank; // 상위 몇 % (예: 25 = 상위 25%)
  final double myMileage; // 내 차량 주행거리
  final List<PeerVehicle> peers; // 비교 차량 리스트

  SOHComparison({
    required this.allUserAverage,
    required this.sameModelAverage,
    required this.percentileRank,
    required this.myMileage,
    required this.peers,
  });

  /// JSON으로부터 SOHComparison 객체 생성
  factory SOHComparison.fromJson(Map<String, dynamic> json) {
    return SOHComparison(
      allUserAverage: (json['allUserAverage'] as num).toDouble(),
      sameModelAverage: (json['sameModelAverage'] as num).toDouble(),
      percentileRank: json['percentileRank'] as int,
      myMileage: (json['myMileage'] as num?)?.toDouble() ?? 0.0,
      peers:
          (json['peers'] as List?)
              ?.map(
                (item) => PeerVehicle.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  /// API 응답으로부터 SOHComparison 객체 생성
  factory SOHComparison.fromApiJson(Map<String, dynamic> json) {
    return SOHComparison(
      allUserAverage: (json['all_user_average'] as num?)?.toDouble() ?? 0.0,
      sameModelAverage: (json['same_model_average'] as num?)?.toDouble() ?? 0.0,
      percentileRank: json['percentile_rank'] as int? ?? 0,
      myMileage: 0.0, // 이 factory는 사용되지 않으므로 기본값
      peers: [],
    );
  }

  /// compare-to-peers API 응답으로부터 SOHComparison 객체 생성
  factory SOHComparison.fromComparisonApi(
    Map<String, dynamic> json,
    double myAverageSoh,
  ) {
    // peer_avg_soh: 동료 차량들의 평균 SOH
    final peerAvgSoh = (json['peer_avg_soh'] as num?)?.toDouble() ?? 0.0;

    // 내 차량 주행거리 추출
    final myMileage = (json['meas_avg_mileage'] as num?)?.toDouble() ?? 0.0;

    // peers 배열 파싱
    final peersJson = json['peers'] as List? ?? [];
    final List<PeerVehicle> peersList = peersJson
        .map((peer) => PeerVehicle.fromApiJson(peer as Map<String, dynamic>))
        .toList();

    // peers 배열에서 동일 차종 평균 계산
    double sameModelAverage = 0.0;
    if (peersList.isNotEmpty) {
      double sum = peersList.fold(0.0, (acc, peer) => acc + peer.avgSoh);
      sameModelAverage = sum / peersList.length;
    }

    // 내 SOH가 peers 중 몇 %인지 계산 (상위 N%)
    int percentileRank = 50; // 기본값
    if (peersList.isNotEmpty) {
      // 내 SOH보다 낮은 peer 수를 센다
      int lowerCount = peersList
          .where((peer) => myAverageSoh > peer.avgSoh)
          .length;
      // 상위 N% 계산: 100 - (내가 이긴 비율 * 100)
      percentileRank = (100 - (lowerCount / peersList.length * 100)).round();
    }

    return SOHComparison(
      allUserAverage: peerAvgSoh, // 전체 사용자 평균
      sameModelAverage: sameModelAverage, // 동일 차종 평균
      percentileRank: percentileRank, // 상위 몇 %
      myMileage: myMileage, // 내 차량 주행거리
      peers: peersList, // 비교 차량 리스트
    );
  }

  /// SOHComparison 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'allUserAverage': allUserAverage,
      'sameModelAverage': sameModelAverage,
      'percentileRank': percentileRank,
      'myMileage': myMileage,
      'peers': peers.map((peer) => peer.toJson()).toList(),
    };
  }
}

/// 배터리 상태 데이터 모델
class BatteryStatusData {
  final double currentSOH; // 현재 SOH (가장 최근 값)
  final double monthlyAverageSOH; // 월평균 SOH
  final double minSOH; // 해당 월 최소 SOH
  final double maxSOH; // 해당 월 최대 SOH
  final int year; // 선택된 년도
  final int month; // 선택된 월
  final List<DailySOH> dailySOHList; // 일자별 SOH 목록
  final SOHComparison comparison; // SOH 비교 데이터

  BatteryStatusData({
    required this.currentSOH,
    required this.monthlyAverageSOH,
    required this.minSOH,
    required this.maxSOH,
    required this.year,
    required this.month,
    required this.dailySOHList,
    required this.comparison,
  });

  /// 월간 변화율 계산 (월 초 대비 월 말)
  double get monthlyChange {
    if (dailySOHList.isEmpty) return 0.0;
    final firstSOH = dailySOHList.first.soh;
    final lastSOH = dailySOHList.last.soh;
    if (firstSOH == 0) return 0.0;
    return ((lastSOH - firstSOH) / firstSOH) * 100;
  }

  /// 표준편차 계산
  double get standardDeviation {
    if (dailySOHList.isEmpty) return 0.0;
    final sohValues = dailySOHList.map((e) => e.soh).toList();
    final mean = sohValues.reduce((a, b) => a + b) / sohValues.length;
    final variance =
        sohValues
            .map((value) => (value - mean) * (value - mean))
            .reduce((a, b) => a + b) /
        sohValues.length;
    return variance > 0 ? sqrt(variance) : 0.0;
  }

  /// 안정성 평가 (표준편차 기반)
  String get stabilityStatus {
    final std = standardDeviation;
    if (std < 0.3) return '매우 안정';
    if (std < 0.7) return '안정';
    if (std < 1.2) return '보통';
    return '불안정';
  }

  /// SOH 상태 평가 ("좋음", "보통", "주의")
  String get healthStatus {
    if (currentSOH >= 90) return '좋음';
    if (currentSOH >= 80) return '보통';
    return '주의';
  }

  /// JSON으로부터 BatteryStatusData 객체 생성
  factory BatteryStatusData.fromJson(Map<String, dynamic> json) {
    return BatteryStatusData(
      currentSOH: (json['currentSOH'] as num).toDouble(),
      monthlyAverageSOH: (json['monthlyAverageSOH'] as num).toDouble(),
      minSOH: (json['minSOH'] as num).toDouble(),
      maxSOH: (json['maxSOH'] as num).toDouble(),
      year: json['year'] as int,
      month: json['month'] as int,
      dailySOHList: (json['dailySOHList'] as List)
          .map((item) => DailySOH.fromJson(item as Map<String, dynamic>))
          .toList(),
      comparison: SOHComparison.fromJson(
        json['comparison'] as Map<String, dynamic>,
      ),
    );
  }

  /// trimmed-soh API 응답으로부터 BatteryStatusData 객체 생성
  factory BatteryStatusData.fromTrimmedSohApi(
    Map<String, dynamic> json,
    SOHComparison comparison,
  ) {
    // meta에서 년월 추출
    final meta = json['meta'] as Map<String, dynamic>;
    final startDateStr = meta['start'] as String;
    final startDate = DateTime.parse(startDateStr);
    final year = startDate.year;
    final month = startDate.month;

    // data 배열: [timestamp, soh, std] 형식
    final dataList = json['data'] as List;

    // 날짜별로 SOH 값들을 그룹화 (Map<String, List<double>>)
    final Map<String, List<double>> dailySOHMap = {};

    for (var row in dataList) {
      final rowData = row as List;
      if (rowData.length < 2) continue;

      final timestamp = rowData[0] as String;
      final soh = (rowData[1] as num).toDouble();

      // 날짜만 추출 (YYYY-MM-DD)
      final dateStr = timestamp.split('T')[0];

      // 날짜별로 SOH 값 추가
      if (!dailySOHMap.containsKey(dateStr)) {
        dailySOHMap[dateStr] = [];
      }
      dailySOHMap[dateStr]!.add(soh);
    }

    // 날짜별 평균 SOH 계산하여 DailySOH 리스트 생성
    final List<DailySOH> dailySOHList = [];
    final sortedDates = dailySOHMap.keys.toList()..sort();

    for (var dateStr in sortedDates) {
      final sohValues = dailySOHMap[dateStr]!;
      final averageSoh = sohValues.reduce((a, b) => a + b) / sohValues.length;
      final date = DateTime.parse(dateStr);
      dailySOHList.add(DailySOH(date: date, soh: averageSoh));
    }

    // 통계 계산
    if (dailySOHList.isEmpty) {
      // 데이터가 없는 경우 기본값 반환
      return BatteryStatusData(
        currentSOH: 0.0,
        monthlyAverageSOH: 0.0,
        minSOH: 0.0,
        maxSOH: 0.0,
        year: year,
        month: month,
        dailySOHList: [],
        comparison: comparison,
      );
    }

    final sohValues = dailySOHList.map((e) => e.soh).toList();
    final currentSOH = dailySOHList.last.soh; // 가장 최근 값
    final monthlyAverageSOH =
        sohValues.reduce((a, b) => a + b) / sohValues.length;
    final minSOH = sohValues.reduce((a, b) => a < b ? a : b);
    final maxSOH = sohValues.reduce((a, b) => a > b ? a : b);

    return BatteryStatusData(
      currentSOH: currentSOH,
      monthlyAverageSOH: monthlyAverageSOH,
      minSOH: minSOH,
      maxSOH: maxSOH,
      year: year,
      month: month,
      dailySOHList: dailySOHList,
      comparison: comparison,
    );
  }

  /// BatteryStatusData 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'currentSOH': currentSOH,
      'monthlyAverageSOH': monthlyAverageSOH,
      'minSOH': minSOH,
      'maxSOH': maxSOH,
      'year': year,
      'month': month,
      'dailySOHList': dailySOHList.map((soh) => soh.toJson()).toList(),
      'comparison': comparison.toJson(),
    };
  }

  /// 복사본 생성 (특정 필드만 수정)
  BatteryStatusData copyWith({
    double? currentSOH,
    double? monthlyAverageSOH,
    double? minSOH,
    double? maxSOH,
    int? year,
    int? month,
    List<DailySOH>? dailySOHList,
    SOHComparison? comparison,
  }) {
    return BatteryStatusData(
      currentSOH: currentSOH ?? this.currentSOH,
      monthlyAverageSOH: monthlyAverageSOH ?? this.monthlyAverageSOH,
      minSOH: minSOH ?? this.minSOH,
      maxSOH: maxSOH ?? this.maxSOH,
      year: year ?? this.year,
      month: month ?? this.month,
      dailySOHList: dailySOHList ?? this.dailySOHList,
      comparison: comparison ?? this.comparison,
    );
  }
}
