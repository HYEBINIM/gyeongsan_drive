import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/destination_search_result.dart';
import '../http/app_http_client.dart';

/// Kakao 로컬 API 서비스
/// 장소 검색 기능을 제공
class KakaoLocalApiService {
  final AppHttpClient _httpClient;

  KakaoLocalApiService({AppHttpClient? httpClient})
    : _httpClient = httpClient ?? AppHttpClient();

  static const String _baseUrl = 'https://dapi.kakao.com/v2/local';

  /// REST API 키 로드
  /// 1. dart-define (컴파일 타임 환경 변수) 우선 - 릴리즈 빌드용
  /// 2. .env 파일 (런타임 로드) fallback - 개발 편의용
  String get _apiKey {
    // 1. dart-define으로 주입된 값 확인 (릴리즈 빌드)
    const compileTimeKey = String.fromEnvironment('KAKAO_REST_API_KEY');
    if (compileTimeKey.isNotEmpty) {
      return compileTimeKey;
    }

    // 2. .env 파일에서 로드 (개발 환경 fallback)
    final runtimeKey = dotenv.env['KAKAO_REST_API_KEY'];
    if (runtimeKey != null && runtimeKey.isNotEmpty) {
      return runtimeKey;
    }

    // 3. 둘 다 없으면 에러
    throw Exception(
      'KAKAO_REST_API_KEY가 설정되지 않았습니다.\n'
      '릴리즈 빌드: --dart-define=KAKAO_REST_API_KEY=YOUR_KEY 사용\n'
      '개발 환경: .env 파일에 KAKAO_REST_API_KEY 설정',
    );
  }

  /// 키워드로 장소 검색
  ///
  /// [query] 검색할 키워드
  /// [size] 결과 개수 (기본 10개, 최대 15개)
  /// Returns: 검색 결과 리스트
  Future<List<SearchResult>> searchPlace(String query, {int size = 10}) async {
    try {
      // 빈 검색어 처리
      if (query.trim().isEmpty) {
        return [];
      }

      // API 요청 URL 생성
      final uri = Uri.parse('$_baseUrl/search/keyword.json').replace(
        queryParameters: {'query': query.trim(), 'size': size.toString()},
      );

      // HTTP GET 요청
      final response = await _httpClient.get(
        uri,
        headers: {'Authorization': 'KakaoAK $_apiKey'},
        timeout: const Duration(seconds: 10),
      );

      // 응답 처리
      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final documents = data['documents'] as List<dynamic>? ?? [];

        return documents
            .map(
              (doc) => SearchResult.fromKakaoJson(doc as Map<String, dynamic>),
            )
            .toList();
      } else if (response.statusCode == 400) {
        throw Exception('잘못된 검색 요청입니다');
      } else if (response.statusCode == 401) {
        throw Exception('Kakao API 인증에 실패했습니다. API 키를 확인해주세요');
      } else if (response.statusCode == 429) {
        throw Exception('요청 한도를 초과했습니다. 잠시 후 다시 시도해주세요');
      } else {
        throw Exception('장소 검색에 실패했습니다 (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('검색 요청 시간이 초과되었습니다');
    } on http.ClientException catch (e) {
      throw Exception('네트워크 연결을 확인해주세요: ${e.message}');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('장소 검색 중 오류가 발생했습니다: $e');
    }
  }
}
