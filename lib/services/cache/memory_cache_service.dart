/// 메모리 캐시 서비스
///
/// LRU (Least Recently Used) 캐시를 사용하여
/// 자주 사용되는 데이터를 메모리에 임시 저장합니다.
class MemoryCacheService {
  // 싱글톤 패턴
  static final MemoryCacheService _instance = MemoryCacheService._internal();
  factory MemoryCacheService() => _instance;
  MemoryCacheService._internal();

  /// LRU 캐시 (최대 100개 항목)
  final _cache = <String, _CacheEntry>{};
  static const int _maxCacheSize = 100;
  static const Duration _defaultTtl = Duration(minutes: 5);

  /// 캐시에서 데이터 가져오기
  ///
  /// [key] 캐시 키
  /// Returns: 캐시된 데이터 또는 null (만료된 경우 자동 삭제)
  T? get<T>(String key) {
    final entry = _cache[key];

    if (entry == null) {
      return null;
    }

    // 만료 확인
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    // LRU 업데이트: 접근한 항목을 맨 뒤로 이동
    _cache.remove(key);
    _cache[key] = entry;

    return entry.data as T;
  }

  /// 캐시에 데이터 저장
  ///
  /// [key] 캐시 키
  /// [data] 저장할 데이터
  /// [ttl] 캐시 유효 시간 (기본: 5분)
  void set<T>(String key, T data, {Duration? ttl}) {
    // 캐시 크기 제한
    if (_cache.length >= _maxCacheSize) {
      // 가장 오래된 항목 제거 (맨 앞)
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }

    final entry = _CacheEntry(
      data: data,
      expiry: DateTime.now().add(ttl ?? _defaultTtl),
    );

    _cache[key] = entry;
  }

  /// 특정 키의 캐시 삭제
  void remove(String key) {
    _cache.remove(key);
  }

  /// 특정 패턴과 일치하는 모든 캐시 삭제
  ///
  /// [pattern] 정규식 패턴
  /// 예: `removeByPattern(r'^user_.*')` → 'user_'로 시작하는 모든 캐시 삭제
  void removeByPattern(String pattern) {
    final regex = RegExp(pattern);
    _cache.removeWhere((key, _) => regex.hasMatch(key));
  }

  /// 모든 캐시 삭제
  void clear() {
    _cache.clear();
  }

  /// 만료된 캐시 항목 제거
  void cleanExpired() {
    _cache.removeWhere((_, entry) => entry.isExpired);
  }

  /// 캐시 통계 정보
  Map<String, dynamic> getStats() {
    cleanExpired();
    return {
      'size': _cache.length,
      'maxSize': _maxCacheSize,
      'utilizationRate':
          '${(_cache.length / _maxCacheSize * 100).toStringAsFixed(1)}%',
    };
  }
}

/// 캐시 항목
class _CacheEntry {
  final dynamic data;
  final DateTime expiry;

  _CacheEntry({required this.data, required this.expiry});

  bool get isExpired => DateTime.now().isAfter(expiry);
}
