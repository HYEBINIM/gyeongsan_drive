import 'dart:async';
import 'dart:math';

import '../../models/battery_status_model.dart';
import '../mcp/mcp_vehicle_client.dart';

enum BatteryAssessmentState { idle, requesting, processing, ready, failed }

class BatteryStatusException implements Exception {
  final String message;

  const BatteryStatusException(this.message);

  @override
  String toString() => message;
}

class BatteryRequestCancelledException extends BatteryStatusException {
  const BatteryRequestCancelledException() : super('취소된 배터리 상태 요청입니다.');
}

/// 배터리 상태 데이터 서비스
class BatteryStatusService {
  static const Duration _defaultMaxWait = Duration(seconds: 90);
  static const List<int> _defaultModelIds = <int>[1001, 1002, 1003];
  static const String _pollingTimeoutMessage = '응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.';
  static const String _networkErrorMessage = '네트워크 상태를 확인해주세요.';

  final McpVehicleClient _mcpClient;

  BatteryStatusService({McpVehicleClient? mcpClient})
    : _mcpClient = mcpClient ?? McpVehicleClient();

  /// MT_ID와 년월로 실제 API에서 배터리 상태 데이터 조회
  Future<BatteryStatusData> fetchBatteryStatusFromApi({
    required String mtId,
    required int year,
    required int month,
    Duration maxWait = _defaultMaxWait,
    void Function(BatteryAssessmentState state)? onStateChanged,
    bool Function()? isCancelled,
  }) async {
    final requestTimeout = maxWait > Duration.zero ? maxWait : _defaultMaxWait;
    _emitState(onStateChanged, BatteryAssessmentState.requesting);

    try {
      _throwIfCancelled(isCancelled);

      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0);
      final startDateStr = _formatDate(startDate);
      final endDateStr = _formatDate(endDate);

      _emitState(onStateChanged, BatteryAssessmentState.processing);

      final trimmedPayload = await _mcpClient
          .callTool('get_trimmed_soh', <String, dynamic>{
            'measurement': mtId,
            'start': startDateStr,
            'end': endDateStr,
            'window_days': 1,
            'min_samples': 5,
          })
          .timeout(requestTimeout);
      _throwIfCancelled(isCancelled);

      final comparisonPayload = await _mcpClient
          .callTool('compare_to_peers', <String, dynamic>{
            'measurement': mtId,
            'model_ids': _defaultModelIds,
            'start_date': startDateStr,
            'end_date': endDateStr,
            'k': 2,
          })
          .timeout(requestTimeout);
      _throwIfCancelled(isCancelled);

      final body = _buildReadyBody(
        trimmedPayload: trimmedPayload,
        comparisonPayload: comparisonPayload,
      );
      final readyData = _parseReadyPayload(
        body,
        fallbackYear: year,
        fallbackMonth: month,
      );
      _emitState(onStateChanged, BatteryAssessmentState.ready);
      return readyData;
    } on BatteryRequestCancelledException {
      rethrow;
    } on BatteryStatusException catch (_) {
      _emitState(onStateChanged, BatteryAssessmentState.failed);
      rethrow;
    } on McpVehicleClientException catch (e) {
      _emitState(onStateChanged, BatteryAssessmentState.failed);
      if (_isNetworkError(e.message)) {
        throw const BatteryStatusException(_networkErrorMessage);
      }
      throw BatteryStatusException('배터리 상태 데이터 조회 실패: $e');
    } on TimeoutException {
      _emitState(onStateChanged, BatteryAssessmentState.failed);
      throw const BatteryStatusException(_pollingTimeoutMessage);
    } on FormatException catch (e) {
      _emitState(onStateChanged, BatteryAssessmentState.failed);
      throw BatteryStatusException('데이터 형식 오류: ${e.message}');
    } catch (e) {
      _emitState(onStateChanged, BatteryAssessmentState.failed);
      throw BatteryStatusException('배터리 상태 데이터 조회 실패: $e');
    }
  }

  void _emitState(
    void Function(BatteryAssessmentState state)? onStateChanged,
    BatteryAssessmentState state,
  ) {
    onStateChanged?.call(state);
  }

  void _throwIfCancelled(bool Function()? isCancelled) {
    if (isCancelled?.call() ?? false) {
      throw const BatteryRequestCancelledException();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _buildReadyBody({
    required Map<String, dynamic> trimmedPayload,
    required Map<String, dynamic> comparisonPayload,
  }) {
    final trimmedData = _extractToolDataMap(
      trimmedPayload,
      preferredKeys: const ['trimmed_soh'],
    );
    final comparisonData = _extractToolDataMap(
      comparisonPayload,
      preferredKeys: const [
        'peer_comparison',
        'compare_to_peers',
        'comparison',
      ],
    );

    return <String, dynamic>{
      'status': 'ready',
      'data': <String, dynamic>{
        'raw_data': <String, dynamic>{
          'trimmed_soh': trimmedData,
          'peer_comparison': comparisonData,
        },
      },
    };
  }

  Map<String, dynamic> _extractToolDataMap(
    Map<String, dynamic> payload, {
    List<String> preferredKeys = const [],
  }) {
    Map<String, dynamic>? extractPreferred(Map<String, dynamic> source) {
      for (final key in preferredKeys) {
        final preferred = _asMap(source[key]);
        if (preferred.isNotEmpty) {
          return preferred;
        }
      }
      return null;
    }

    final payloadPreferred = extractPreferred(payload);
    if (payloadPreferred != null) {
      return payloadPreferred;
    }

    if (payload.containsKey('meta') && payload.containsKey('data')) {
      return payload;
    }

    final data = payload['data'];
    if (data is Map) {
      final map = _asMap(data);
      final nestedPreferred = extractPreferred(map);
      if (nestedPreferred != null) {
        return nestedPreferred;
      }
      if (map.containsKey('meta') && map.containsKey('data')) {
        return map;
      }
      if (map.isNotEmpty) {
        return map;
      }
    }

    final result = payload['result'];
    if (result is Map) {
      final map = _asMap(result);
      final nestedPreferred = extractPreferred(map);
      if (nestedPreferred != null) {
        return nestedPreferred;
      }
      if (map.containsKey('meta') && map.containsKey('data')) {
        return map;
      }
      if (map.isNotEmpty) {
        return map;
      }
    }

    return payload;
  }

  bool _isNetworkError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('failed to establish sse connection') ||
        normalized.contains('socket') ||
        normalized.contains('connection') ||
        normalized.contains('timed out waiting for endpoint') ||
        normalized.contains('transport disconnected');
  }

  BatteryStatusData _parseReadyPayload(
    Map<String, dynamic> body, {
    required int fallbackYear,
    required int fallbackMonth,
  }) {
    final status = body['status']?.toString().toLowerCase();
    if (status != null && status.isNotEmpty && status != 'ready') {
      throw BatteryStatusException('배터리 상태 데이터 조회 실패: status=$status');
    }

    final data = _asMap(body['data']);
    final payload = data.isNotEmpty ? data : body;

    return _buildBatteryStatusData(
      payload,
      fallbackYear: fallbackYear,
      fallbackMonth: fallbackMonth,
    );
  }

  BatteryStatusData _buildBatteryStatusData(
    Map<String, dynamic> payload, {
    required int fallbackYear,
    required int fallbackMonth,
  }) {
    final assessment = _asMap(payload['assessment']);
    final source = assessment.isNotEmpty ? assessment : payload;
    final metrics = _asMap(source['metrics']);
    final dailySOHList = _extractDailySOHList(source, payload);

    final currentSOH =
        _readDouble(source, const ['currentSOH', 'current_soh']) ??
        _readDouble(metrics, const ['latest_soh', 'latestSoh']) ??
        (dailySOHList.isNotEmpty ? dailySOHList.last.soh : 0.0);

    final monthlyAverageSOH =
        _readDouble(source, const [
          'monthlyAverageSOH',
          'monthly_average_soh',
          'average_soh',
        ]) ??
        _readDouble(metrics, const ['meas_avg_soh']) ??
        _averageSOH(dailySOHList);

    final minSOH =
        _readDouble(source, const ['minSOH', 'min_soh']) ??
        _minSOH(dailySOHList);

    final maxSOH =
        _readDouble(source, const ['maxSOH', 'max_soh']) ??
        _maxSOH(dailySOHList);

    final parsedYearMonth = _resolveYearMonth(
      payload: payload,
      source: source,
      fallbackYear: fallbackYear,
      fallbackMonth: fallbackMonth,
    );

    return BatteryStatusData(
      currentSOH: currentSOH,
      monthlyAverageSOH: monthlyAverageSOH,
      minSOH: minSOH,
      maxSOH: maxSOH,
      year: parsedYearMonth.year,
      month: parsedYearMonth.month,
      dailySOHList: dailySOHList,
      comparison: _extractComparison(payload, source),
    );
  }

  DateTime _resolveYearMonth({
    required Map<String, dynamic> payload,
    required Map<String, dynamic> source,
    required int fallbackYear,
    required int fallbackMonth,
  }) {
    final sourceYear =
        _readInt(source, const ['year']) ??
        _readInt(source, const ['target_year']);
    final sourceMonth =
        _readInt(source, const ['month']) ??
        _readInt(source, const ['target_month']);
    if (sourceYear != null &&
        sourceMonth != null &&
        sourceMonth >= 1 &&
        sourceMonth <= 12) {
      return DateTime(sourceYear, sourceMonth, 1);
    }

    final metaStart = _extractTrimmedMetaStart(payload, source);
    if (metaStart != null) {
      return DateTime(metaStart.year, metaStart.month, 1);
    }

    return DateTime(fallbackYear, fallbackMonth, 1);
  }

  DateTime? _extractTrimmedMetaStart(
    Map<String, dynamic> payload,
    Map<String, dynamic> source,
  ) {
    final evidence = _asMap(source['evidence']);
    final evidenceMeta = _asMap(evidence['trimmed_meta']);
    final evidenceStart = evidenceMeta['start']?.toString();
    if (evidenceStart != null && evidenceStart.isNotEmpty) {
      final parsed = DateTime.tryParse(evidenceStart);
      if (parsed != null) {
        return parsed;
      }
    }

    final rawData = _asMap(payload['raw_data']);
    final trimmedSoh = _asMap(rawData['trimmed_soh']);
    final meta = _asMap(trimmedSoh['meta']);
    final metaStart = meta['start']?.toString();
    if (metaStart != null && metaStart.isNotEmpty) {
      return DateTime.tryParse(metaStart);
    }

    return null;
  }

  List<DailySOH> _extractDailySOHList(
    Map<String, dynamic> source,
    Map<String, dynamic> payload,
  ) {
    var rawList = _asList(source['dailySOHList']);
    rawList = rawList.isNotEmpty ? rawList : _asList(source['daily_soh_list']);
    rawList = rawList.isNotEmpty ? rawList : _asList(source['daily_soh']);
    rawList = rawList.isNotEmpty ? rawList : _asList(source['daily']);
    if (rawList.isEmpty) {
      final rawData = _asMap(payload['raw_data']);
      final trimmedSoh = _asMap(rawData['trimmed_soh']);
      final trimmedRows = _asList(trimmedSoh['data']);
      final trimmedDaily = _aggregateTrimmedRowsByDay(trimmedRows);
      if (trimmedDaily.isNotEmpty) {
        return trimmedDaily;
      }
      rawList = _asList(rawData['dailySOHList']);
      rawList = rawList.isNotEmpty ? rawList : _asList(rawData['daily_soh']);
    }

    final parsed = <DailySOH>[];
    for (final item in rawList) {
      final daily = _parseDailySOH(item);
      if (daily != null) {
        parsed.add(daily);
      }
    }

    parsed.sort((a, b) => a.date.compareTo(b.date));
    return parsed;
  }

  List<DailySOH> _aggregateTrimmedRowsByDay(List<dynamic> rows) {
    if (rows.isEmpty) {
      return const <DailySOH>[];
    }

    final grouped = <DateTime, List<double>>{};
    for (final row in rows) {
      DateTime? timestamp;
      double? soh;

      if (row is List && row.length >= 2) {
        final rawTimestamp = row[0]?.toString();
        final rawSoh = row[1];
        if (rawTimestamp == null || rawTimestamp.isEmpty) {
          continue;
        }

        timestamp = DateTime.tryParse(rawTimestamp);
        if (rawSoh is num) {
          soh = rawSoh.toDouble();
        } else if (rawSoh is String) {
          soh = double.tryParse(rawSoh);
        }
      } else if (row is Map) {
        final mapped = _asMap(row);
        final rawTimestamp =
            mapped['t']?.toString() ?? mapped['timestamp']?.toString();
        if (rawTimestamp == null || rawTimestamp.isEmpty) {
          continue;
        }

        timestamp = DateTime.tryParse(rawTimestamp);
        soh =
            _readDouble(mapped, const ['soh', 'value']) ??
            _readDouble(mapped, const ['avg_soh']);
      }

      if (timestamp == null || soh == null) {
        continue;
      }

      final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
      grouped.putIfAbsent(day, () => <double>[]).add(soh);
    }

    final result =
        grouped.entries
            .map((entry) {
              final values = entry.value;
              if (values.isEmpty) {
                return null;
              }
              final sum = values.reduce((a, b) => a + b);
              return DailySOH(date: entry.key, soh: sum / values.length);
            })
            .whereType<DailySOH>()
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    return result;
  }

  DailySOH? _parseDailySOH(dynamic item) {
    try {
      if (item is Map) {
        final row = _asMap(item);
        final dateString =
            row['date']?.toString() ?? row['timestamp']?.toString();
        if (dateString == null || dateString.isEmpty) {
          return null;
        }

        final soh =
            _readDouble(row, const ['soh', 'value']) ??
            _readDouble(row, const ['avg_soh']) ??
            0.0;
        return DailySOH(date: DateTime.parse(dateString), soh: soh);
      }

      if (item is List && item.length >= 2) {
        final timestamp = item[0]?.toString();
        final sohValue = item[1];
        if (timestamp == null || timestamp.isEmpty) {
          return null;
        }
        return DailySOH(
          date: DateTime.parse(timestamp),
          soh: (sohValue as num?)?.toDouble() ?? 0.0,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  SOHComparison _extractComparison(
    Map<String, dynamic> payload,
    Map<String, dynamic> source,
  ) {
    final metrics = _asMap(source['metrics']);
    var comparisonSource = _asMap(source['comparison']);
    if (comparisonSource.isEmpty) {
      comparisonSource = _asMap(payload['comparison']);
    }
    if (comparisonSource.isEmpty) {
      final rawData = _asMap(payload['raw_data']);
      comparisonSource = _asMap(rawData['peer_comparison']);
      if (comparisonSource.isEmpty) {
        comparisonSource = _asMap(rawData['comparison']);
      }
    }

    if (comparisonSource.isEmpty) {
      return _createDummyComparison();
    }

    final peers = _extractPeers(comparisonSource);
    final sameModelAverage =
        _readDouble(comparisonSource, const [
          'sameModelAverage',
          'same_model_average',
        ]) ??
        _readDouble(metrics, const ['peer_mean_soh']) ??
        (peers.isEmpty
            ? 0.0
            : peers.map((peer) => peer.avgSoh).reduce((a, b) => a + b) /
                  peers.length);

    return SOHComparison(
      allUserAverage:
          _readDouble(comparisonSource, const [
            'allUserAverage',
            'all_user_average',
            'peer_avg_soh',
          ]) ??
          _readDouble(metrics, const ['peer_mean_soh']) ??
          0.0,
      sameModelAverage: sameModelAverage,
      percentileRank:
          _readInt(comparisonSource, const [
            'percentileRank',
            'percentile_rank',
          ]) ??
          _readInt(metrics, const ['percentile']) ??
          0,
      myMileage:
          _readDouble(comparisonSource, const [
            'myMileage',
            'my_mileage',
            'meas_avg_mileage',
          ]) ??
          0.0,
      peers: peers,
    );
  }

  List<PeerVehicle> _extractPeers(Map<String, dynamic> comparisonSource) {
    final rawPeers = _asList(comparisonSource['peers']);
    final peers = <PeerVehicle>[];

    for (final item in rawPeers) {
      if (item is! Map) {
        continue;
      }
      final peer = _asMap(item);
      peers.add(
        PeerVehicle(
          measurement:
              peer['measurement']?.toString() ??
              peer['mt_id']?.toString() ??
              '',
          avgSoh: _readDouble(peer, const ['avgSoh', 'avg_soh', 'soh']) ?? 0.0,
          avgMileage:
              _readDouble(peer, const [
                'avgMileage',
                'avg_mileage',
                'mileage',
              ]) ??
              0.0,
        ),
      );
    }

    return peers;
  }

  double? _readDouble(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  int? _readInt(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, dynamic nestedValue) => MapEntry(key.toString(), nestedValue),
      );
    }
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) {
      return value;
    }
    return const <dynamic>[];
  }

  double _averageSOH(List<DailySOH> list) {
    if (list.isEmpty) {
      return 0.0;
    }
    final sum = list.map((item) => item.soh).reduce((a, b) => a + b);
    return sum / list.length;
  }

  double _minSOH(List<DailySOH> list) {
    if (list.isEmpty) {
      return 0.0;
    }
    return list.map((item) => item.soh).reduce(min);
  }

  double _maxSOH(List<DailySOH> list) {
    if (list.isEmpty) {
      return 0.0;
    }
    return list.map((item) => item.soh).reduce(max);
  }

  /// 더미 비교 데이터 생성 (fallback)
  SOHComparison _createDummyComparison() {
    return SOHComparison(
      allUserAverage: 89.5,
      sameModelAverage: 91.2,
      percentileRank: 28,
      myMileage: 150000.0, // 더미 주행거리
      peers: [
        // 더미 비교 차량 2대
        PeerVehicle(measurement: 'DUMMY01', avgSoh: 88.5, avgMileage: 175000.0),
        PeerVehicle(measurement: 'DUMMY02', avgSoh: 90.5, avgMileage: 165000.0),
      ],
    );
  }

  /// 특정 년월의 배터리 상태 데이터 조회 (더미 데이터)
  Future<BatteryStatusData> fetchBatteryStatusData({
    required int year,
    required int month,
  }) async {
    // 실제 API 호출을 시뮬레이션하기 위한 지연
    await Future.delayed(const Duration(milliseconds: 800));

    // 해당 월의 일수 계산
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // 더미 SOH 데이터 생성 (90% ~ 95% 범위에서 약간의 변동)
    final random = Random(year * 12 + month); // 동일 년월은 동일한 시드
    final baseSOH = 92.0; // 기준 SOH
    final dailySOHList = <DailySOH>[];

    // 일자별 SOH 생성 (약간의 노이즈 추가)
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      // -2% ~ +2% 범위의 변동
      final variation = (random.nextDouble() - 0.5) * 4;
      final soh = (baseSOH + variation).clamp(88.0, 96.0);
      dailySOHList.add(DailySOH(date: date, soh: soh));
    }

    // 통계 계산
    final sohValues = dailySOHList.map((e) => e.soh).toList();
    final currentSOH = dailySOHList.last.soh; // 가장 최근 값
    final monthlyAverageSOH =
        sohValues.reduce((a, b) => a + b) / sohValues.length;
    final minSOH = sohValues.reduce((a, b) => a < b ? a : b);
    final maxSOH = sohValues.reduce((a, b) => a > b ? a : b);

    // 더미 비교 데이터 생성
    final comparison = SOHComparison(
      allUserAverage: 89.5, // 전체 사용자 평균
      sameModelAverage: 91.2, // 동일 차종 평균
      percentileRank: 28, // 상위 28%
      myMileage: 150000.0, // 더미 주행거리
      peers: [
        // 더미 비교 차량 2대
        PeerVehicle(measurement: 'DUMMY01', avgSoh: 88.5, avgMileage: 175000.0),
        PeerVehicle(measurement: 'DUMMY02', avgSoh: 90.5, avgMileage: 165000.0),
      ],
    );

    // BatteryStatusData 객체 생성 및 반환
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

  /// 배터리 상태 데이터 새로고침
  Future<BatteryStatusData> refreshBatteryStatusData({
    required int year,
    required int month,
  }) async {
    return fetchBatteryStatusData(year: year, month: month);
  }
}
