import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 영구 캐시 서비스
///
/// SharedPreferences를 사용하여 데이터를 디스크에 저장합니다.
/// 앱 재시작 후에도 캐시가 유지되며, TTL(Time To Live) 기반으로 만료됩니다.
class PersistentCacheService {
  // 싱글톤 패턴
  static final PersistentCacheService _instance =
      PersistentCacheService._internal();
  factory PersistentCacheService() => _instance;
  PersistentCacheService._internal();

  // 캐시 키 접두사
  static const String _cachePrefix = 'persistent_cache_';
  static const String _expiryPrefix = 'persistent_cache_expiry_';

  // 기본 TTL: 24시간
  static const Duration defaultTtl = Duration(hours: 24);

  /// 캐시에서 JSON 리스트 가져오기
  ///
  /// [key] 캐시 키
  /// Returns: 캐시된 JSON 리스트 또는 null (만료된 경우)
  Future<List<dynamic>?> getJsonList(String key) async {
    final prefs = await SharedPreferences.getInstance();

    // 만료 시간 확인
    final expiryKey = '$_expiryPrefix$key';
    final expiryMs = prefs.getInt(expiryKey);

    if (expiryMs == null) {
      return null;
    }

    final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
    if (DateTime.now().isAfter(expiry)) {
      // 만료된 캐시 삭제
      await remove(key);
      return null;
    }

    // 캐시 데이터 가져오기
    final cacheKey = '$_cachePrefix$key';
    final jsonString = prefs.getString(cacheKey);

    if (jsonString == null) {
      return null;
    }

    try {
      return jsonDecode(jsonString) as List<dynamic>;
    } catch (e) {
      // 파싱 실패 시 캐시 삭제
      await remove(key);
      return null;
    }
  }

  /// 캐시에 JSON 리스트 저장
  ///
  /// [key] 캐시 키
  /// [data] 저장할 JSON 리스트
  /// [ttl] 캐시 유효 시간 (기본: 24시간)
  Future<void> setJsonList(
    String key,
    List<dynamic> data, {
    Duration? ttl,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final cacheKey = '$_cachePrefix$key';
    final expiryKey = '$_expiryPrefix$key';

    final jsonString = jsonEncode(data);
    final expiry = DateTime.now().add(ttl ?? defaultTtl);

    await prefs.setString(cacheKey, jsonString);
    await prefs.setInt(expiryKey, expiry.millisecondsSinceEpoch);
  }

  /// 특정 키의 캐시 삭제
  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();

    final cacheKey = '$_cachePrefix$key';
    final expiryKey = '$_expiryPrefix$key';

    await prefs.remove(cacheKey);
    await prefs.remove(expiryKey);
  }

  /// 모든 캐시 삭제
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    final keysToRemove = keys.where((key) {
      return key.startsWith(_cachePrefix) || key.startsWith(_expiryPrefix);
    }).toList();

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }

  /// 캐시가 유효한지 확인
  Future<bool> isValid(String key) async {
    final prefs = await SharedPreferences.getInstance();

    final expiryKey = '$_expiryPrefix$key';
    final expiryMs = prefs.getInt(expiryKey);

    if (expiryMs == null) {
      return false;
    }

    final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
    return DateTime.now().isBefore(expiry);
  }
}
