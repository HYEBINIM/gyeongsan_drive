import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart';
import '../../models/recent_search.dart';
import '../../models/notification_settings.dart';
import '../../models/driving_score_model.dart';

/// 로컬 저장소 서비스
/// SharedPreferences를 사용하여 로컬 데이터 관리
class LocalStorageService {
  /// 온보딩 완료 여부 확인
  /// 반환: true면 이미 온보딩 완료, false면 온보딩 필요
  Future<bool> isOnboardingComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(AppConstants.onboardingCompleteKey) ?? false;
    } catch (e) {
      // 에러 발생 시 온보딩 필요로 간주
      return false;
    }
  }

  /// 온보딩 완료 상태 저장
  /// 온보딩 완료 후 호출하여 다음 실행 시 건너뛰도록 설정
  Future<void> setOnboardingComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.onboardingCompleteKey, true);
    } catch (e) {
      throw '온보딩 완료 상태 저장 중 오류가 발생했습니다: $e';
    }
  }

  /// 온보딩 완료 상태 초기화 (테스트용)
  /// 개발 중 온보딩을 다시 보고 싶을 때 사용
  Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.onboardingCompleteKey);
    } catch (e) {
      throw '온보딩 상태 초기화 중 오류가 발생했습니다: $e';
    }
  }

  /// 자동 로그인 활성화 여부 확인
  /// 반환: true면 자동 로그인 활성화, false면 비활성화
  Future<bool> isAutoLoginEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(AppConstants.autoLoginKey) ?? false;
    } catch (e) {
      // 에러 발생 시 자동 로그인 비활성화로 간주
      return false;
    }
  }

  /// 자동 로그인 설정 저장
  /// [enabled] true면 자동 로그인 활성화, false면 비활성화
  Future<void> setAutoLoginEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.autoLoginKey, enabled);
    } catch (e) {
      throw '자동 로그인 설정 저장 중 오류가 발생했습니다: $e';
    }
  }

  /// 자동 로그인 설정 초기화 (로그아웃 시 사용)
  /// 로그아웃 시 자동 로그인 설정을 제거
  Future<void> clearAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.autoLoginKey);
    } catch (e) {
      throw '자동 로그인 설정 초기화 중 오류가 발생했습니다: $e';
    }
  }

  /// 사용자 프로필 초기화 여부 캐시 확인
  /// [uid]에 해당하는 프로필이 이미 Firestore에 존재하는지 로컬에서 빠르게 판별
  Future<bool> hasCachedUserProfile(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached =
          prefs.getStringList(AppConstants.userProfileCacheKey) ?? <String>[];
      return cached.contains(uid);
    } catch (e) {
      // 캐시 조회 실패 시 기본값(false) 반환
      return false;
    }
  }

  /// 사용자 프로필 초기화 여부 캐시 저장
  /// 신규 가입 완료 또는 기존 사용자 확인 시 호출
  Future<void> markUserProfileInitialized(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached =
          prefs.getStringList(AppConstants.userProfileCacheKey) ?? <String>[];
      if (!cached.contains(uid)) {
        cached.add(uid);
        await prefs.setStringList(AppConstants.userProfileCacheKey, cached);
      }
    } catch (e) {
      throw '사용자 프로필 캐시 저장 중 오류가 발생했습니다: $e';
    }
  }

  /// 사용자 프로필 캐시 제거
  /// 계정 삭제 등으로 로컬 상태를 초기화할 때 사용
  Future<void> clearUserProfileCache(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached =
          prefs.getStringList(AppConstants.userProfileCacheKey) ?? <String>[];
      if (cached.remove(uid)) {
        await prefs.setStringList(AppConstants.userProfileCacheKey, cached);
      }
    } catch (e) {
      throw '사용자 프로필 캐시 제거 중 오류가 발생했습니다: $e';
    }
  }

  // ============================================================================
  // 최근 검색어 관리 (안전귀가 목적지 검색)
  // ============================================================================

  /// 최근 검색어 목록 조회 (타임스탬프 포함)
  /// 반환: 최근 검색어 리스트 (최대 10개, 최신순)
  Future<List<RecentSearch>> getRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(AppConstants.recentSearchesKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => RecentSearch.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // 에러 발생 시 빈 리스트 반환 (기존 데이터 호환성 문제 포함)
      return [];
    }
  }

  /// 최근 검색어 목록 저장 (타임스탬프 포함)
  /// [searches] 저장할 검색어 리스트
  Future<void> saveRecentSearches(List<RecentSearch> searches) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = searches.map((search) => search.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(AppConstants.recentSearchesKey, jsonString);
    } catch (e) {
      throw '최근 검색어 저장 중 오류가 발생했습니다: $e';
    }
  }

  /// 최근 검색어 전체 삭제
  /// 개인정보 보호를 위한 기능
  Future<void> clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.recentSearchesKey);
    } catch (e) {
      throw '최근 검색어 삭제 중 오류가 발생했습니다: $e';
    }
  }

  // ============================================================================
  // 테마 모드 관리
  // ============================================================================

  /// 테마 모드 조회
  /// 반환: 'system', 'light', 'dark' 중 하나 (기본값: 'dark')
  Future<String> getThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(AppConstants.themeModeKey) ?? 'dark';
    } catch (e) {
      // 에러 발생 시 기본값 반환 (다크 모드)
      return 'dark';
    }
  }

  /// 테마 모드 저장
  /// [mode] 테마 모드 ('system', 'light', 'dark')
  Future<void> setThemeMode(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.themeModeKey, mode);
    } catch (e) {
      throw '테마 모드 저장 중 오류가 발생했습니다: $e';
    }
  }

  // ============================================================================
  // 알림 설정 관리
  // ============================================================================

  /// 알림 설정 조회
  /// 반환: NotificationSettings 객체 (저장된 값 없으면 기본값)
  Future<NotificationSettings> getNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(AppConstants.notificationSettingsKey);

      if (jsonString == null || jsonString.isEmpty) {
        return NotificationSettings.defaults();
      }

      final Map<String, dynamic> jsonMap =
          jsonDecode(jsonString) as Map<String, dynamic>;
      return NotificationSettings.fromJson(jsonMap);
    } catch (e) {
      // 에러 발생 시 기본값 반환
      return NotificationSettings.defaults();
    }
  }

  /// 알림 설정 저장
  /// [settings] 저장할 알림 설정 객체
  Future<void> saveNotificationSettings(NotificationSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(settings.toJson());
      await prefs.setString(AppConstants.notificationSettingsKey, jsonString);
    } catch (e) {
      throw '알림 설정 저장 중 오류가 발생했습니다: $e';
    }
  }

  // ============================================================================
  // 운전 점수 일 단위 캐시 관리 (차량별)
  // ============================================================================

  /// 운전 점수 캐시 저장 (차량별, 하루 단위)
  Future<void> saveDrivingScoreCache(String mtId, DrivingScoreData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${AppConstants.drivingScoreCacheKeyPrefix}$mtId';
      final payload = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
        'scoreData': data.toJson(),
      };
      final jsonString = jsonEncode(payload);
      await prefs.setString(key, jsonString);
    } catch (e) {
      // 한국어 주석: 캐시 저장 실패는 치명적이지 않으므로 조용히 무시
    }
  }

  /// 오늘 날짜 기준으로 유효한 운전 점수 캐시 조회
  /// - 앱을 재시작해도 같은 날이면 캐시된 점수를 반환
  /// - 날짜가 바뀐 경우 캐시를 무효화하고 null 반환
  Future<DrivingScoreData?> getTodayDrivingScoreCache(String mtId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${AppConstants.drivingScoreCacheKeyPrefix}$mtId';
      final jsonString = prefs.getString(key);

      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }

      final Map<String, dynamic> jsonMap =
          jsonDecode(jsonString) as Map<String, dynamic>;
      final updatedAtStr = jsonMap['updatedAt'] as String?;
      if (updatedAtStr == null) {
        await prefs.remove(key);
        return null;
      }

      final updatedAt = DateTime.tryParse(updatedAtStr);
      if (updatedAt == null) {
        await prefs.remove(key);
        return null;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final cachedDay = DateTime(
        updatedAt.year,
        updatedAt.month,
        updatedAt.day,
      );

      // 한국어 주석: 00시가 지나 날짜가 변경되면 캐시 무효화
      if (today != cachedDay) {
        await prefs.remove(key);
        return null;
      }

      final dynamic scoreDynamic = jsonMap['scoreData'];
      if (scoreDynamic is! Map<String, dynamic>) {
        await prefs.remove(key);
        return null;
      }

      final scoreJson = scoreDynamic;
      return DrivingScoreData.fromJson(scoreJson);
    } catch (e) {
      // 한국어 주석: 캐시 조회 오류 시 캐시를 사용하지 않음
      return null;
    }
  }

  // ============================================================================
  // 운전 습관 일 단위 캐시 관리 (차량별)
  // ============================================================================

  /// 운전 습관 캐시 저장 (차량별, 하루 단위)
  /// - 날짜별 DrivingHabits 맵을 JSON으로 저장
  Future<void> saveDrivingHabitsCache(
    String mtId,
    Map<DateTime, DrivingHabits> habitsMap,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${AppConstants.drivingHabitsCacheKeyPrefix}$mtId';

      // 한국어 주석: 날짜는 일 단위만 중요하므로 정규화 후 ISO 문자열 키로 사용
      final habitsJson = <String, dynamic>{};
      habitsMap.forEach((date, habits) {
        final normalizedDate = DateTime(date.year, date.month, date.day);
        habitsJson[normalizedDate.toIso8601String()] = habits.toJson();
      });

      final payload = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
        'habits': habitsJson,
      };

      final jsonString = jsonEncode(payload);
      await prefs.setString(key, jsonString);
    } catch (e) {
      // 한국어 주석: 캐시 저장 실패는 치명적이지 않으므로 조용히 무시
    }
  }

  /// 오늘 날짜 기준으로 유효한 운전 습관 캐시 조회
  /// - 앱을 재시작해도 같은 날이면 캐시된 운전 습관 데이터를 반환
  /// - 날짜가 바뀐 경우 캐시를 무효화하고 null 반환
  Future<Map<DateTime, DrivingHabits>?> getTodayDrivingHabitsCache(
    String mtId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${AppConstants.drivingHabitsCacheKeyPrefix}$mtId';
      final jsonString = prefs.getString(key);

      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }

      final Map<String, dynamic> jsonMap =
          jsonDecode(jsonString) as Map<String, dynamic>;
      final updatedAtStr = jsonMap['updatedAt'] as String?;
      if (updatedAtStr == null) {
        await prefs.remove(key);
        return null;
      }

      final updatedAt = DateTime.tryParse(updatedAtStr);
      if (updatedAt == null) {
        await prefs.remove(key);
        return null;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final cachedDay = DateTime(
        updatedAt.year,
        updatedAt.month,
        updatedAt.day,
      );

      // 한국어 주석: 00시가 지나 날짜가 변경되면 캐시 무효화
      if (today != cachedDay) {
        await prefs.remove(key);
        return null;
      }

      final habitsDynamic = jsonMap['habits'];
      if (habitsDynamic is! Map) {
        await prefs.remove(key);
        return null;
      }

      final result = <DateTime, DrivingHabits>{};
      habitsDynamic.forEach((dateKey, value) {
        if (dateKey is! String) {
          return;
        }
        final date = DateTime.tryParse(dateKey);
        if (date == null) {
          return;
        }

        if (value is Map<String, dynamic>) {
          final habits = DrivingHabits.fromJson(value);
          final normalizedDate = DateTime(date.year, date.month, date.day);
          result[normalizedDate] = habits;
        } else if (value is Map) {
          // 한국어 주석: dynamic Map도 허용하여 이전 버전과의 호환성 확보
          final habits = DrivingHabits.fromJson(
            value.map((k, v) => MapEntry(k.toString(), v)),
          );
          final normalizedDate = DateTime(date.year, date.month, date.day);
          result[normalizedDate] = habits;
        }
      });

      return result.isEmpty ? null : result;
    } catch (e) {
      // 한국어 주석: 캐시 조회 오류 시 캐시를 사용하지 않음
      return null;
    }
  }
}
