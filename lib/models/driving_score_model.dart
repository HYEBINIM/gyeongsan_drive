/// 일별 운전 점수 모델
class DailyScore {
  final DateTime date;
  final int score;

  DailyScore({required this.date, required this.score});

  /// JSON으로부터 DailyScore 객체 생성 (내부 저장용)
  factory DailyScore.fromJson(Map<String, dynamic> json) {
    return DailyScore(
      date: DateTime.parse(json['date'] as String),
      score: json['score'] as int,
    );
  }

  /// API 응답으로부터 DailyScore 객체 생성
  factory DailyScore.fromApiJson(Map<String, dynamic> json) {
    final dateValue = _readDateString(json, const ['date', 'DATE']);
    if (dateValue == null) {
      throw const FormatException('운전 행동 응답에 날짜 정보가 없습니다.');
    }

    return DailyScore(
      date: DateTime.parse(dateValue),
      score: _readIntLike(
        json,
        const ['driving_score', 'DRIVING_SCORE', 'score', 'SCORE'],
      ),
    );
  }

  /// DailyScore 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {'date': date.toIso8601String(), 'score': score};
  }
}

/// 운전 점수 데이터 모델
class DrivingScoreData {
  final int myScore; // 내 운전점수
  final int averageScore; // 운전자 평균 점수
  final int rankingPercentile; // 상위 몇 % (예: 52 = 상위 52%)
  final DateTime startDate; // 기간 시작일
  final DateTime endDate; // 기간 종료일
  final List<DailyScore> weeklyScores; // 주간 점수 목록
  final DrivingHabits? drivingHabits; // 운전 습관 통계 (선택적)

  DrivingScoreData({
    required this.myScore,
    required this.averageScore,
    required this.rankingPercentile,
    required this.startDate,
    required this.endDate,
    required this.weeklyScores,
    this.drivingHabits,
  });

  /// JSON으로부터 DrivingScoreData 객체 생성
  factory DrivingScoreData.fromJson(Map<String, dynamic> json) {
    return DrivingScoreData(
      myScore: json['myScore'] as int,
      averageScore: json['averageScore'] as int,
      rankingPercentile: json['rankingPercentile'] as int,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      weeklyScores: (json['weeklyScores'] as List)
          .map((item) => DailyScore.fromJson(item as Map<String, dynamic>))
          .toList(),
      drivingHabits: json['drivingHabits'] != null
          ? DrivingHabits.fromJson(
              json['drivingHabits'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// DrivingScoreData 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'myScore': myScore,
      'averageScore': averageScore,
      'rankingPercentile': rankingPercentile,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'weeklyScores': weeklyScores.map((score) => score.toJson()).toList(),
      'drivingHabits': drivingHabits?.toJson(),
    };
  }

  /// 복사본 생성 (특정 필드만 수정)
  DrivingScoreData copyWith({
    int? myScore,
    int? averageScore,
    int? rankingPercentile,
    DateTime? startDate,
    DateTime? endDate,
    List<DailyScore>? weeklyScores,
    DrivingHabits? drivingHabits,
  }) {
    return DrivingScoreData(
      myScore: myScore ?? this.myScore,
      averageScore: averageScore ?? this.averageScore,
      rankingPercentile: rankingPercentile ?? this.rankingPercentile,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      weeklyScores: weeklyScores ?? this.weeklyScores,
      drivingHabits: drivingHabits ?? this.drivingHabits,
    );
  }
}

/// 운전 습관 통계 모델
class DrivingHabits {
  final int distance; // 주행거리 (km)
  final int suddenTurn; // 급유턴 (회)
  final int suddenBraking; // 급감속 (회)
  final int suddenStart; // 급출발 (회)
  final int suddenHorn; // 급정지 (회) - API: behavior_sudden_stop
  final int suddenLeftTurn; // 급좌회전 (회)
  final int suddenAcceleration; // 급가속 (회)
  final int suddenRightTurn; // 급우회전 (회)

  const DrivingHabits({
    required this.distance,
    required this.suddenTurn,
    required this.suddenBraking,
    required this.suddenStart,
    required this.suddenHorn,
    required this.suddenLeftTurn,
    required this.suddenAcceleration,
    required this.suddenRightTurn,
  });

  /// 운전 습관 기본값 (모든 필드 0)
  const DrivingHabits.empty()
    : distance = 0,
      suddenTurn = 0,
      suddenBraking = 0,
      suddenStart = 0,
      suddenHorn = 0,
      suddenLeftTurn = 0,
      suddenAcceleration = 0,
      suddenRightTurn = 0;

  /// JSON으로부터 DrivingHabits 객체 생성 (내부 저장용)
  factory DrivingHabits.fromJson(Map<String, dynamic> json) {
    return DrivingHabits(
      distance: json['distance'] as int,
      suddenTurn: json['suddenTurn'] as int,
      suddenBraking: json['suddenBraking'] as int,
      suddenStart: json['suddenStart'] as int,
      suddenHorn: json['suddenHorn'] as int,
      suddenLeftTurn: json['suddenLeftTurn'] as int,
      suddenAcceleration: json['suddenAcceleration'] as int,
      suddenRightTurn: json['suddenRightTurn'] as int,
    );
  }

  /// API 응답으로부터 DrivingHabits 객체 생성
  factory DrivingHabits.fromApiJson(Map<String, dynamic> json) {
    return DrivingHabits(
      distance: _readIntLike(json, const ['mileage', 'MILEAGE']),
      suddenTurn: _readIntLike(
        json,
        const [
          'behavior_sudden_uturn',
          'BEHAVIOR_SUDDEN_UTURN',
          'SUDDEN_UTURN_COUNT',
        ],
      ),
      suddenBraking: _readIntLike(
        json,
        const [
          'behavior_sudden_deceleration',
          'BEHAVIOR_SUDDEN_DECELERATION',
          'SUDDEN_DECL_COUNT',
        ],
      ),
      suddenStart: _readIntLike(
        json,
        const [
          'behavior_sudden_start',
          'BEHAVIOR_SUDDEN_START',
          'SUDDEN_START_COUNT',
        ],
      ),
      suddenHorn: _readIntLike(
        json,
        const [
          'behavior_sudden_stop',
          'BEHAVIOR_SUDDEN_STOP',
          'SUDDEN_STOP_COUNT',
        ],
      ), // 급정지
      suddenLeftTurn: _readIntLike(
        json,
        const [
          'behavior_sudden_left',
          'BEHAVIOR_SUDDEN_LEFT',
          'SUDDEN_LEFT_COUNT',
        ],
      ),
      suddenAcceleration: _readIntLike(
        json,
        const [
          'behavior_sudden_acceleration',
          'BEHAVIOR_SUDDEN_ACCELERATION',
          'SUDDEN_ACCL_COUNT',
        ],
      ),
      suddenRightTurn: _readIntLike(
        json,
        const [
          'behavior_sudden_right',
          'BEHAVIOR_SUDDEN_RIGHT',
          'SUDDEN_RIGHT_COUNT',
        ],
      ),
    );
  }

  /// DrivingHabits 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'distance': distance,
      'suddenTurn': suddenTurn,
      'suddenBraking': suddenBraking,
      'suddenStart': suddenStart,
      'suddenHorn': suddenHorn,
      'suddenLeftTurn': suddenLeftTurn,
      'suddenAcceleration': suddenAcceleration,
      'suddenRightTurn': suddenRightTurn,
    };
  }
}

dynamic _firstApiValue(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    if (!source.containsKey(key)) {
      continue;
    }

    final value = source[key];
    if (value != null) {
      return value;
    }
  }

  return null;
}

int _readIntLike(Map<String, dynamic> source, List<String> keys) {
  final value = _firstApiValue(source, keys);
  if (value == null) {
    return 0;
  }

  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final trimmed = value.trim();
    final parsedInt = int.tryParse(trimmed);
    if (parsedInt != null) {
      return parsedInt;
    }

    final parsedDouble = double.tryParse(trimmed);
    if (parsedDouble != null) {
      return parsedDouble.toInt();
    }
  }

  return 0;
}

String? _readDateString(Map<String, dynamic> source, List<String> keys) {
  final value = _firstApiValue(source, keys);
  if (value == null) {
    return null;
  }

  if (value is DateTime) {
    return value.toIso8601String();
  }

  return value.toString();
}
