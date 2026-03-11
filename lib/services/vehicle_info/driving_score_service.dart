import '../../models/driving_score_model.dart';
import '../../utils/app_logger.dart';
import '../mcp/mcp_vehicle_client.dart';

class DrivingScoreQueryResult {
  final DrivingScoreData scoreData;
  final Map<DateTime, DrivingHabits> dailyHabitsMap;

  const DrivingScoreQueryResult({
    required this.scoreData,
    required this.dailyHabitsMap,
  });
}

/// 운전 점수 데이터 서비스
class DrivingScoreService {
  final McpVehicleClient _mcpClient;

  DrivingScoreService({McpVehicleClient? mcpClient})
    : _mcpClient = mcpClient ?? McpVehicleClient();

  /// MT_ID로 실제 API에서 운전 점수 데이터 조회 (7일치 운전 행동 데이터 포함)
  Future<DrivingScoreData> fetchDrivingScoreFromApi({
    required String mtId,
  }) async {
    final result = await fetchDrivingScoreQueryResult(mtId: mtId);
    return result.scoreData;
  }

  Future<DrivingScoreQueryResult> fetchDrivingScoreQueryResult({
    required String mtId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final normalizedMtId = _normalizeMtId(mtId);
      final range = _resolveDateRange(startDate: startDate, endDate: endDate);
      final scoreSnapshot = await _fetchDriverScoreSnapshot(
        mtId: normalizedMtId,
      );
      final behaviorResults = await _fetchDailyBehaviorRange(
        mtId: normalizedMtId,
        startDate: range.startDate,
        endDate: range.endDate,
      );

      final weeklyScores = behaviorResults
          .map((result) => result.score)
          .toList(growable: false);
      final dailyHabitsMap = <DateTime, DrivingHabits>{
        for (final result in behaviorResults) result.date: result.habits,
      };

      final latestHabits =
          dailyHabitsMap[range.endDate] ?? const DrivingHabits.empty();

      return DrivingScoreQueryResult(
        scoreData: DrivingScoreData(
          myScore: scoreSnapshot.driverScore,
          averageScore: scoreSnapshot.averageScore,
          rankingPercentile: scoreSnapshot.percentileRank,
          startDate: range.startDate,
          endDate: range.endDate,
          weeklyScores: weeklyScores,
          drivingHabits: latestHabits,
        ),
        dailyHabitsMap: dailyHabitsMap,
      );
    } on McpVehicleClientException catch (e) {
      if (_isNetworkError(e.message)) {
        throw '네트워크 연결 오류: ${e.message}';
      }
      throw '운전 점수 데이터 조회 실패: $e';
    } on FormatException catch (e) {
      throw '데이터 형식 오류: ${e.message}';
    } catch (e) {
      throw '운전 점수 데이터 조회 실패: $e';
    }
  }

  /// 특정 날짜의 일별 운전 행동 데이터 조회
  Future<Map<String, dynamic>> fetchDailyBehavior({
    required String mtId,
    required DateTime date,
  }) async {
    final result = await _fetchDailyBehaviorResult(mtId: mtId, date: date);
    return result.toMap();
  }

  /// 7일치 운전 행동 데이터 병렬 조회
  /// [startDate]가 제공되지 않으면 [endDate] 기준 7일 전부터 조회
  Future<Map<DateTime, Map<String, dynamic>>> fetchWeeklyBehaviorData({
    required String mtId,
    required DateTime endDate,
    DateTime? startDate,
  }) async {
    final results = await _fetchDailyBehaviorRange(
      mtId: mtId,
      startDate: startDate,
      endDate: endDate,
    );

    return {for (final result in results) result.date: result.toMap()};
  }

  /// 운전 점수 데이터 조회 (더미 데이터)
  Future<DrivingScoreData> fetchDrivingScoreData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // 실제 API 호출을 시뮬레이션하기 위한 지연
    await Future.delayed(const Duration(milliseconds: 500));

    // 기본 날짜 범위 설정 (제공된 이미지 기준: 2025년 10월 23일 ~ 29일)
    final defaultStartDate = DateTime(2025, 10, 23);
    final defaultEndDate = DateTime(2025, 10, 29);

    final start = startDate ?? defaultStartDate;
    final end = endDate ?? defaultEndDate;

    // 더미 주간 점수 데이터 (이미지와 동일한 값)
    final weeklyScores = [
      DailyScore(date: DateTime(2025, 10, 23), score: 79),
      DailyScore(date: DateTime(2025, 10, 24), score: 82),
      DailyScore(date: DateTime(2025, 10, 25), score: 86),
      DailyScore(date: DateTime(2025, 10, 26), score: 86),
      DailyScore(date: DateTime(2025, 10, 27), score: 86),
      DailyScore(date: DateTime(2025, 10, 28), score: 80),
      DailyScore(date: DateTime(2025, 10, 29), score: 91),
    ];

    // 더미 운전 습관 통계 데이터 (이미지와 동일한 값)
    final drivingHabits = DrivingHabits(
      distance: 284, // 주행거리 284km
      suddenTurn: 0, // 급유턴 0회
      suddenBraking: 31, // 급감속 31회
      suddenStart: 54, // 급출발 54회
      suddenHorn: 16, // 급정지 16회
      suddenLeftTurn: 0, // 급좌회전 0회
      suddenAcceleration: 301, // 급가속 301회
      suddenRightTurn: 0, // 급우회전 0회
    );

    // 더미 운전 점수 데이터 반환
    return DrivingScoreData(
      myScore: 76, // 내 운전점수
      averageScore: 75, // 운전자 평균 점수
      rankingPercentile: 52, // 상위 52%
      startDate: start,
      endDate: end,
      weeklyScores: weeklyScores,
      drivingHabits: drivingHabits, // 운전 습관 통계 추가
    );
  }

  /// 특정 기간의 운전 점수 데이터 조회 (실제 API 연동)
  Future<DrivingScoreData> fetchDrivingScoreDataByDateRange({
    required String mtId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final result = await fetchDrivingScoreQueryResult(
      mtId: mtId,
      startDate: startDate,
      endDate: endDate,
    );
    return result.scoreData;
  }

  /// 운전 점수 데이터 새로고침
  Future<DrivingScoreData> refreshDrivingScoreData() async {
    return fetchDrivingScoreData();
  }

  Future<_DriverScoreSnapshot> _fetchDriverScoreSnapshot({
    required String mtId,
  }) async {
    final normalizedMtId = _normalizeMtId(mtId);
    final scoreData = await _callDriverScoreTool(mtId: normalizedMtId);

    final source = _extractPrimaryPayload(scoreData);

    final driverScore = _readIntValue(source, const [
      'DRIVER_SCORE',
      'driver_score',
    ]);
    final averageScore = _readIntValue(source, const [
      'AVERAGE_SCORE',
      'average_score',
    ]);

    final percentileRaw = _firstValue(source, const [
      'PERCENTILE_RANK',
      'percentile_rank',
      'percentile',
    ]);
    final percentileRank = _normalizePercentile(percentileRaw);

    if (driverScore == null || averageScore == null) {
      throw const FormatException('운전 점수 응답 형식이 올바르지 않습니다.');
    }

    return _DriverScoreSnapshot(
      driverScore: driverScore,
      averageScore: averageScore,
      percentileRank: percentileRank,
    );
  }

  Future<Map<String, dynamic>> _callDriverScoreTool({
    required String mtId,
  }) async {
    const toolName = 'get_driver_score';
    final primaryArguments = <String, dynamic>{'mt_id': mtId};

    try {
      return await _mcpClient.callTool(toolName, primaryArguments);
    } on McpVehicleClientException catch (e) {
      if (!_shouldRetryDriverScoreWithUppercaseMtId(e.message)) {
        rethrow;
      }

      AppLogger.debug(
        '📊 [운전점수] get_driver_score 입력 키 호환 재시도: '
        'mt_id -> MT_ID, mtId=$mtId, error=$e',
      );

      return _mcpClient.callTool(toolName, <String, dynamic>{'MT_ID': mtId});
    }
  }

  Future<List<_DailyBehaviorResult>> _fetchDailyBehaviorRange({
    required String mtId,
    DateTime? startDate,
    required DateTime endDate,
  }) async {
    final normalizedMtId = _normalizeMtId(mtId);
    final normalizedRange = _resolveDateRange(
      startDate: startDate,
      endDate: endDate,
    );
    final daysDiff = normalizedRange.endDate
        .difference(normalizedRange.startDate)
        .inDays;

    final futures = <Future<_DailyBehaviorResult>>[];
    for (int i = 0; i <= daysDiff; i++) {
      final date = normalizedRange.startDate.add(Duration(days: i));
      futures.add(_fetchDailyBehaviorResult(mtId: normalizedMtId, date: date));
    }

    final results = await Future.wait(futures);
    final hasUsableResult = results.any((result) => !result.hadError);
    if (hasUsableResult) {
      return results;
    }

    String? detail;
    for (final result in results) {
      final message = result.errorMessage;
      if (message != null && message.isNotEmpty) {
        detail = message;
        break;
      }
    }

    final suffix = detail == null ? '' : ' ($detail)';
    throw FormatException('운전 행동 데이터 조회에 모두 실패했습니다.$suffix');
  }

  Future<_DailyBehaviorResult> _fetchDailyBehaviorResult({
    required String mtId,
    required DateTime date,
  }) async {
    final normalizedMtId = _normalizeMtId(mtId);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final dateStr = _formatDate(normalizedDate);

    try {
      final jsonData = await _mcpClient.callTool(
        'get_driving_behavior',
        <String, dynamic>{'measurement': normalizedMtId, 'date': dateStr},
      );

      final data = _extractBehaviorRow(jsonData);
      if (data == null || data.isEmpty) {
        return _DailyBehaviorResult.empty(normalizedDate);
      }

      final normalized = <String, dynamic>{...data};
      normalized.putIfAbsent('date', () => dateStr);

      if (!_looksLikeDrivingBehaviorRow(normalized)) {
        throw const FormatException('운전 행동 응답 형식이 올바르지 않습니다.');
      }

      final dailyScore = DailyScore.fromApiJson(normalized);
      final drivingHabits = DrivingHabits.fromApiJson(normalized);

      return _DailyBehaviorResult.success(
        date: normalizedDate,
        score: dailyScore,
        habits: drivingHabits,
      );
    } on McpVehicleClientException catch (e) {
      AppLogger.debug(
        '📊 [운전점수] 운전 행동 조회 실패: MT_ID=$normalizedMtId, date=$dateStr, error=$e',
      );
      return _DailyBehaviorResult.error(
        normalizedDate,
        'MCP tool 호출 실패(get_driving_behavior): $e',
      );
    } on FormatException catch (e) {
      AppLogger.debug(
        '📊 [운전점수] 운전 행동 파싱 실패: MT_ID=$normalizedMtId, date=$dateStr, error=${e.message}',
      );
      return _DailyBehaviorResult.error(normalizedDate, e.message);
    } catch (e) {
      AppLogger.debug(
        '📊 [운전점수] 운전 행동 처리 실패: MT_ID=$normalizedMtId, date=$dateStr, error=$e',
      );
      return _DailyBehaviorResult.error(normalizedDate, e.toString());
    }
  }

  _NormalizedDateRange _resolveDateRange({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (startDate == null && endDate == null) {
      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);
      final normalizedEndDate = normalizedToday.subtract(
        const Duration(days: 1),
      );
      final normalizedStartDate = normalizedEndDate.subtract(
        const Duration(days: 6),
      );
      return _NormalizedDateRange(
        startDate: normalizedStartDate,
        endDate: normalizedEndDate,
      );
    }

    if (endDate == null) {
      throw const FormatException('날짜 범위가 올바르지 않습니다.');
    }

    final normalizedEndDate = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );
    if (startDate == null) {
      return _NormalizedDateRange(
        startDate: normalizedEndDate.subtract(const Duration(days: 6)),
        endDate: normalizedEndDate,
      );
    }

    final normalizedStartDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    if (normalizedStartDate.isAfter(normalizedEndDate)) {
      throw const FormatException('시작일은 종료일보다 이후일 수 없습니다.');
    }

    return _NormalizedDateRange(
      startDate: normalizedStartDate,
      endDate: normalizedEndDate,
    );
  }

  String _normalizeMtId(String mtId) {
    final normalizedMtId = mtId.trim();
    if (normalizedMtId.isEmpty) {
      throw const FormatException('mt_id 값이 비어 있습니다.');
    }
    return normalizedMtId;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool _looksLikeDrivingBehaviorRow(Map<String, dynamic> source) {
    return _containsAnyKey(source, const [
      'driving_score',
      'DRIVING_SCORE',
      'mileage',
      'MILEAGE',
      'behavior_sudden_left',
      'BEHAVIOR_SUDDEN_LEFT',
      'behavior_sudden_right',
      'BEHAVIOR_SUDDEN_RIGHT',
      'behavior_sudden_uturn',
      'BEHAVIOR_SUDDEN_UTURN',
      'behavior_sudden_acceleration',
      'BEHAVIOR_SUDDEN_ACCELERATION',
      'behavior_sudden_deceleration',
      'BEHAVIOR_SUDDEN_DECELERATION',
      'behavior_sudden_start',
      'BEHAVIOR_SUDDEN_START',
      'behavior_sudden_stop',
      'BEHAVIOR_SUDDEN_STOP',
      'SUDDEN_START_COUNT',
      'SUDDEN_STOP_COUNT',
      'SUDDEN_ACCL_COUNT',
      'SUDDEN_DECL_COUNT',
      'SUDDEN_LEFT_COUNT',
      'SUDDEN_RIGHT_COUNT',
      'SUDDEN_UTURN_COUNT',
    ]);
  }

  bool _containsAnyKey(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      if (source.containsKey(key)) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic>? _extractBehaviorRow(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is List) {
      if (data.isEmpty) {
        return null;
      }
      return _asMap(data.first);
    }
    if (data is Map) {
      return _asMap(data);
    }

    final result = payload['result'];
    if (result is List) {
      if (result.isEmpty) {
        return null;
      }
      return _asMap(result.first);
    }
    if (result is Map) {
      return _asMap(result);
    }

    return _asMap(payload);
  }

  Map<String, dynamic> _extractPrimaryPayload(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is Map) {
      return _asMap(data) ?? payload;
    }
    if (data is List && data.isNotEmpty) {
      final first = _asMap(data.first);
      if (first != null) {
        return first;
      }
    }

    final result = payload['result'];
    if (result is Map) {
      return _asMap(result) ?? payload;
    }

    return payload;
  }

  dynamic _firstValue(Map<String, dynamic> source, List<String> keys) {
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

  int? _readIntValue(Map<String, dynamic> source, List<String> keys) {
    final value = _firstValue(source, keys);
    if (value == null) {
      return null;
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

    return null;
  }

  int _normalizePercentile(dynamic value) {
    final parsed = _toDouble(value);
    if (parsed == null) {
      return 0;
    }

    // 0~1 범위 비율이면 백분율로 변환
    if (parsed >= 0 && parsed <= 1) {
      return (parsed * 100).round();
    }

    return parsed.round();
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final normalized = value.trim().replaceAll('%', '');
      return double.tryParse(normalized);
    }
    return null;
  }

  bool _isNetworkError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('failed to establish sse connection') ||
        normalized.contains('socket') ||
        normalized.contains('connection') ||
        normalized.contains('timed out waiting for endpoint') ||
        normalized.contains('transport disconnected');
  }

  bool _shouldRetryDriverScoreWithUppercaseMtId(String message) {
    final normalized = message.toLowerCase();
    if (!normalized.contains('input validation error') ||
        !normalized.contains('required property')) {
      return false;
    }

    return message.contains("'MT_ID'") || message.contains('"MT_ID"');
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, dynamic nestedValue) {
        return MapEntry(key.toString(), nestedValue);
      });
    }
    return null;
  }
}

class _NormalizedDateRange {
  final DateTime startDate;
  final DateTime endDate;

  const _NormalizedDateRange({required this.startDate, required this.endDate});
}

class _DailyBehaviorResult {
  final DateTime date;
  final DailyScore score;
  final DrivingHabits habits;
  final bool hasData;
  final bool hadError;
  final String? errorMessage;

  const _DailyBehaviorResult._({
    required this.date,
    required this.score,
    required this.habits,
    required this.hasData,
    required this.hadError,
    this.errorMessage,
  });

  factory _DailyBehaviorResult.success({
    required DateTime date,
    required DailyScore score,
    required DrivingHabits habits,
  }) {
    return _DailyBehaviorResult._(
      date: date,
      score: score,
      habits: habits,
      hasData: true,
      hadError: false,
    );
  }

  factory _DailyBehaviorResult.empty(DateTime date) {
    return _DailyBehaviorResult._(
      date: date,
      score: DailyScore(date: date, score: 0),
      habits: const DrivingHabits.empty(),
      hasData: false,
      hadError: false,
    );
  }

  factory _DailyBehaviorResult.error(DateTime date, String message) {
    return _DailyBehaviorResult._(
      date: date,
      score: DailyScore(date: date, score: 0),
      habits: const DrivingHabits.empty(),
      hasData: false,
      hadError: true,
      errorMessage: message,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'date': date,
      'score': score,
      'habits': habits,
      'hasData': hasData,
      'hadError': hadError,
      'error': errorMessage,
    };
  }
}

class _DriverScoreSnapshot {
  final int driverScore;
  final int averageScore;
  final int percentileRank;

  const _DriverScoreSnapshot({
    required this.driverScore,
    required this.averageScore,
    required this.percentileRank,
  });
}
