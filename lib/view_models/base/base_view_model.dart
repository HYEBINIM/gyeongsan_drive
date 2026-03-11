import 'package:flutter/foundation.dart';

/// 모든 ViewModel의 공통 부모 클래스
/// KISS 원칙: 반복되는 로딩/에러 상태 관리 로직을 한 곳에 집중
/// DRY 원칙: 각 ViewModel에서 중복되던 boilerplate 코드 제거
abstract class BaseViewModel extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

  /// 에러 발생 여부
  bool get hasError => _errorMessage != null;

  /// 한국어 주석: 로딩 상태 자동 관리 헬퍼 메서드
  /// try-catch-finally 패턴을 캡슐화하여 boilerplate 제거
  ///
  /// 사용 예시:
  /// ```dart
  /// await withLoading(() async {
  ///   final data = await _service.fetchData();
  ///   // 데이터 처리
  /// });
  /// ```
  Future<T> withLoading<T>(Future<T> Function() action) async {
    _startLoading();

    try {
      final result = await action();
      return _completeWithResult(result);
    } catch (e) {
      _completeWithError(e);
      rethrow; // 한국어 주석: 호출자가 에러를 처리할 수 있도록 re-throw
    }
  }

  /// 한국어 주석: 로딩 상태 자동 관리 (에러 무시 버전)
  /// 에러가 발생해도 re-throw하지 않고 errorMessage만 설정
  ///
  /// 사용 예시:
  /// ```dart
  /// await withLoadingSilent(() async {
  ///   await _service.saveData();
  /// });
  ///
  /// if (hasError) {
  ///   // 에러 처리 (UI에 표시 등)
  /// }
  /// ```
  Future<T?> withLoadingSilent<T>(Future<T> Function() action) async {
    _startLoading();

    try {
      final result = await action();
      return _completeWithResult(result);
    } catch (e) {
      _completeWithError(e);
      return null; // 한국어 주석: 에러 시 null 반환
    }
  }

  void _startLoading() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
  }

  T _completeWithResult<T>(T result) {
    _isLoading = false;
    notifyListeners();
    return result;
  }

  void _completeWithError(Object error) {
    _isLoading = false;
    _errorMessage = error.toString();
    notifyListeners();
  }

  /// 한국어 주석: 에러 메시지 초기화
  /// UI에서 에러 메시지를 표시한 후 호출하여 상태 정리
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 한국어 주석: 로딩 상태 수동 설정 (특수한 경우에만 사용)
  /// 일반적으로는 withLoading() 사용을 권장
  @protected
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// 한국어 주석: 에러 메시지 수동 설정 (특수한 경우에만 사용)
  @protected
  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }
}
