// UTF-8 인코딩 파일
// 한국어 주석: 테마 관리 ViewModel (KISS & YAGNI 원칙 적용)

import 'package:flutter/material.dart';
import '../../services/storage/local_storage_service.dart';

/// 테마 모드 관리 ViewModel
/// 시스템/라이트/다크 모드 전환 및 설정 저장
class ThemeViewModel extends ChangeNotifier {
  final LocalStorageService _storageService = LocalStorageService();

  /// 현재 테마 모드 ('system', 'light', 'dark')
  /// 기본값: 'dark' (사용자가 명시적으로 변경하지 않으면 다크 모드 유지)
  String _themeMode = 'dark';

  /// 테마 모드 getter
  String get themeMode => _themeMode;

  /// MaterialApp의 ThemeMode로 변환
  /// Flutter의 내장 기능을 활용하여 시스템 테마 자동 감지
  ThemeMode get materialThemeMode {
    switch (_themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system; // Flutter가 자동으로 시스템 테마 감지
    }
  }

  /// 현재 테마 모드의 표시 라벨
  /// View에서 비즈니스 로직을 제거하기 위해 ViewModel에 배치 (MVVM 패턴)
  String get themeModeLabel {
    switch (_themeMode) {
      case 'system':
        return '시스템 설정 따르기';
      case 'light':
        return '라이트 모드';
      case 'dark':
        return '다크 모드';
      default:
        return '시스템 설정 따르기';
    }
  }

  /// 초기화: SharedPreferences에서 저장된 테마 모드 로드
  Future<void> initialize() async {
    try {
      _themeMode = await _storageService.getThemeMode();
      notifyListeners();
    } catch (e) {
      // 에러 발생 시 기본값('dark') 유지
      _themeMode = 'dark';
    }
  }

  /// 테마 모드 변경 및 저장
  /// [mode] 테마 모드 ('system', 'light', 'dark')
  Future<void> setThemeMode(String mode) async {
    if (_themeMode == mode) return; // 같은 모드면 무시 (DRY)

    _themeMode = mode;
    notifyListeners(); // UI 즉시 업데이트

    try {
      await _storageService.setThemeMode(mode);
    } catch (e) {
      // 저장 실패해도 UI는 이미 변경됨 (사용자 경험 우선)
      // 다음 실행 시 기본값으로 복원됨
    }
  }
}
