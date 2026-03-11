import '../../models/destination_search_result.dart';
import '../../models/recent_search.dart';
import '../storage/local_storage_service.dart';
import 'kakao_local_api_service.dart';

/// 목적지 검색 통합 서비스
/// Kakao API 검색 + 최근 검색어 관리를 통합 제공
class DestinationSearchService {
  final KakaoLocalApiService _kakaoApi = KakaoLocalApiService();
  final LocalStorageService _storage = LocalStorageService();

  /// 최근 검색어 최대 보관 개수
  static const int _maxRecentSearches = 999;

  /// 장소 검색 (선택 저장 아님)
  ///
  /// [query] 검색할 키워드
  /// Returns: 검색 결과 리스트
  Future<List<SearchResult>> searchDestination(String query) async {
    try {
      // Kakao API로 검색
      final results = await _kakaoApi.searchPlace(query);
      // 한국어 주석: 요구사항에 따라 '검색' 단계에서는 최근 검색어에 추가하지 않음
      // 실제 사용자가 결과를 '선택'했을 때만 최근 검색어로 저장합니다. (YAGNI/DRY)
      return results;
    } catch (e) {
      // 에러를 상위로 전달
      rethrow;
    }
  }

  /// 실제 선택된 목적지를 최근 검색어로 저장
  /// - 검색 단계가 아닌, 사용자 선택 시점에서만 호출
  Future<void> saveSelectedToRecent(SearchResult result) async {
    try {
      final label = result.placeName.trim();
      if (label.isEmpty) return;

      await _addToRecentSearches(label);
    } catch (e) {
      // 최근 검색어 저장 실패는 핵심 기능이 아니므로 무시
    }
  }

  /// 최근 검색어 목록 조회
  ///
  /// Returns: 최근 검색어 리스트 (최대 999개, 최신순)
  Future<List<RecentSearch>> getRecentSearches() async {
    try {
      return await _storage.getRecentSearches();
    } catch (e) {
      // 에러 발생 시 빈 리스트 반환
      return [];
    }
  }

  /// 특정 검색어 삭제
  ///
  /// [query] 삭제할 검색어
  Future<void> removeRecentSearch(String query) async {
    try {
      final searches = await _storage.getRecentSearches();
      searches.removeWhere((search) => search.query == query);
      await _storage.saveRecentSearches(searches);
    } catch (e) {
      // 에러 발생 시 무시 (사용자 경험 저해 방지)
    }
  }

  /// 최근 검색어 전체 삭제
  Future<void> clearAllRecentSearches() async {
    try {
      await _storage.clearRecentSearches();
    } catch (e) {
      // 에러 발생 시 무시
    }
  }

  /// 최근 검색어에 추가 (내부 메서드)
  /// - 중복 제거
  /// - 최신순 정렬
  /// - 최대 개수 유지
  Future<void> _addToRecentSearches(String query) async {
    try {
      final searches = await _storage.getRecentSearches();

      // 기존에 같은 검색어가 있으면 제거 (중복 방지)
      searches.removeWhere((search) => search.query == query);

      // 현재 시간으로 새로운 검색 기록 생성하여 맨 앞에 추가 (최신순)
      final newSearch = RecentSearch(
        query: query,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      searches.insert(0, newSearch);

      // 최대 개수 초과 시 오래된 항목 제거
      if (searches.length > _maxRecentSearches) {
        searches.removeRange(_maxRecentSearches, searches.length);
      }

      await _storage.saveRecentSearches(searches);
    } catch (e) {
      // 최근 검색어 저장 실패는 핵심 기능이 아니므로 무시
    }
  }
}
