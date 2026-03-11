import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // 한국어 주석: Provider 접근을 위해 추가
import 'package:remixicon/remixicon.dart';
import '../home/home_screen.dart';
import '../vehicle_info/vehicle_info_screen.dart';
import '../../services/fun/fun_page.dart';
import '../region_info/region_info_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/login_required_dialog.dart'; // 한국어 주석: 로그인 유도 다이얼로그
import '../../providers/auth_provider.dart'; // 한국어 주석: 전역 인증 상태
import '../../routes/app_routes.dart';
import '../../utils/snackbar_utils.dart';
import '../../view_models/region_info/region_info_viewmodel.dart'; // 한국어 주석: 지역정보 바텀시트 상태 접근용

/// 하단 네비게이션 바를 포함한 메인 화면
class MainNavigationScreen extends StatefulWidget {
  /// 초기 선택될 탭 인덱스 (기본값: 0 - 홈)
  final int initialIndex;
  final String? guardMessage;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
    this.guardMessage,
  });

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  static const int _fallbackTabIndex = 2;
  static const List<int> _requiresEmailVerifiedTabs = [0, 1];
  static const String _emailVerificationRequiredMessage =
      '이메일 인증 후 이용 가능한 기능입니다. 지역정보 탭으로 이동합니다.';

  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyInitialGuard();
    });
  }

  bool _isEmailVerificationBlocked(int tabIndex, AuthProvider authProvider) {
    return _requiresEmailVerifiedTabs.contains(tabIndex) &&
        authProvider.isAuthenticated &&
        !authProvider.isEmailVerified;
  }

  void _showGuardMessage(String message) {
    if (!mounted) return;
    SnackBarUtils.showWarning(context, message);
  }

  void _moveToFallbackTab() {
    if (_currentIndex == _fallbackTabIndex) return;
    setState(() => _currentIndex = _fallbackTabIndex);
  }

  void _applyInitialGuard() {
    final authProvider = context.read<AuthProvider>();
    var messageShown = false;

    final guardMessage = widget.guardMessage;
    if (guardMessage != null && guardMessage.isNotEmpty) {
      _showGuardMessage(guardMessage);
      messageShown = true;
    }

    if (_isEmailVerificationBlocked(_currentIndex, authProvider)) {
      _moveToFallbackTab();
      if (!messageShown) {
        _showGuardMessage(_emailVerificationRequiredMessage);
      }
    }
  }

  /// 외부에서 탭을 변경하기 위한 메서드
  void changeTab(int index) {
    if (index >= 0 && index < 5 && index != _currentIndex) {
      final authProvider = context.read<AuthProvider>();
      if (_isEmailVerificationBlocked(index, authProvider)) {
        _moveToFallbackTab();
        _showGuardMessage(_emailVerificationRequiredMessage);
        return;
      }
      setState(() => _currentIndex = index);
    }
  }

  /// 현재 선택된 탭에 해당하는 화면 빌드
  /// IndexedStack 대신 조건부 렌더링으로 변경하여
  /// 실제로 선택된 탭만 빌드 (메모리 효율 + 권한 요청 타이밍 최적화)
  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return const HomeScreen(); // 홈
      case 1:
        return const VehicleInfoScreen(); // 차량정보
      case 2:
        return const RegionInfoScreen(); // 지역정보
      case 3:
        return const FunPage(); // 놀거리
      case 4:
        return const ProfileScreen(); // 내 정보
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 한국어 주석: 뒤로가기 버튼 동작 우선순위
    // 1. 하위 route(바텀시트/다이얼로그) 닫기
    // 2. 홈 외 탭에서는 홈으로 이동
    // 3. 홈 탭에서는 앱 종료 확인
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 한국어 주석: 1순위 - Navigator 스택에 하위 route가 있으면(바텀시트/다이얼로그) 먼저 닫기
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }

        // 한국어 주석: 1.5순위 - 지역정보 탭에서 인라인 바텀시트가 열려 있으면 먼저 닫기
        // (RegionInfoScreen의 바텀시트는 Navigator route가 아니라 위젯 상태이므로 별도 처리 필요)
        if (_currentIndex == 2) {
          final regionVm = context.read<RegionInfoViewModel>();
          if (regionVm.showPlaceList) {
            regionVm.hidePlaceList();
            return;
          }
        }

        // 한국어 주석: 2순위 - 홈이 아니라면 홈으로 이동
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }

        // 한국어 주석: 3순위 - 홈 탭에서는 앱 종료 확인
        final shouldExit = await _showExitConfirmationDialog();
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        drawer: AppDrawer(),
        body: SafeArea(child: _buildCurrentScreen()),
        bottomNavigationBar: CupertinoTabBar(
          currentIndex: _currentIndex,
          onTap: (index) async {
            if (index != _currentIndex) {
              // 한국어 주석: 로그인 필요 탭 체크 (0: 홈, 1: 차량정보)
              const requiresAuthTabs = [0, 1];
              final authProvider = context.read<AuthProvider>();

              if (requiresAuthTabs.contains(index)) {
                if (!authProvider.isAuthenticated) {
                  // 한국어 주석: 비로그인 상태 → 로그인 유도 다이얼로그 표시
                  final shouldLogin = await showLoginRequiredDialog(context);

                  if (!context.mounted) return;

                  if (shouldLogin == true) {
                    // 한국어 주석: 로그인하기 선택 → 로그인 화면으로 이동
                    // returnRoute로 원래 돌아올 탭 정보 전달
                    Navigator.pushNamed(
                      context,
                      AppRoutes.login,
                      arguments: {
                        'returnRoute': AppRoutes.mainNavigation,
                        'returnArguments': index, // 로그인 후 이 탭으로 복귀
                      },
                    );
                  }
                  return; // 한국어 주석: 탭 전환 취소
                }

                if (!authProvider.isEmailVerified) {
                  _moveToFallbackTab();
                  _showGuardMessage(_emailVerificationRequiredMessage);
                  return;
                }
              }

              // 한국어 주석: 탭 전환 시 현재 탭 인덱스만 갱신
              setState(() => _currentIndex = index);
            }
          },
          backgroundColor: Theme.of(context).colorScheme.surface,
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.6),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_car),
              label: '차량정보',
            ),
            BottomNavigationBarItem(
              icon: Icon(RemixIcons.road_map_fill),
              label: '지역정보',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.attractions),
              label: '놀거리',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: '내 정보'),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showExitConfirmationDialog() {
    final colorScheme = Theme.of(context).colorScheme;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '앱을 종료할까요?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '종료를 선택하면 앱이 종료됩니다.',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colorScheme.outlineVariant),
                          foregroundColor: colorScheme.onSurface,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text('종료'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
