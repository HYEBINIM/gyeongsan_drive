import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 한국어 주석: AuthProvider 접근
import 'package:remixicon/remixicon.dart';
import '../../providers/auth_provider.dart'; // 한국어 주석: 전역 인증 상태
import '../../routes/app_routes.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../services/storage/local_storage_service.dart';
import '../../utils/constants.dart';
import '../../utils/snackbar_utils.dart';
import 'login_required_dialog.dart';

/// 공통 Drawer 위젯
class AppDrawer extends StatelessWidget {
  static const int _fallbackTabIndex = 2;
  static const String _emailVerificationRequiredMessage =
      '이메일 인증 후 이용 가능한 기능입니다. 지역정보 탭으로 이동합니다.';

  final FirebaseAuthService _authService = FirebaseAuthService();
  final LocalStorageService _storageService = LocalStorageService();

  AppDrawer({super.key});

  Future<void> _navigateToFallbackTabWithMessage(
    BuildContext context,
    String message,
  ) async {
    if (!context.mounted) return;

    Navigator.of(context).pushReplacementNamed(
      AppRoutes.mainNavigation,
      arguments: {'initialIndex': _fallbackTabIndex, 'guardMessage': message},
    );
  }

  /// 간단한 탭 이동 (KISS): 현재 라우트를 mainNavigation으로 교체 이동
  /// [tabIndex]: 0 홈, 1 차량정보, 2 지역정보, 3 놀거리
  Future<void> _navigateToTab(BuildContext context, int tabIndex) async {
    // 한국어 주석: 로그인 필요 탭 (홈/차량정보)은 비로그인 시 로그인 유도 다이얼로그 표시
    const requiresAuthTabs = [0, 1]; // 0: 홈, 1: 차량정보
    if (requiresAuthTabs.contains(tabIndex)) {
      final authProvider = context.read<AuthProvider>();
      if (!authProvider.isAuthenticated) {
        final shouldLogin = await showLoginRequiredDialog(context);
        if (shouldLogin == true && context.mounted) {
          Navigator.pushNamed(
            context,
            AppRoutes.login,
            arguments: {
              'returnRoute': AppRoutes.mainNavigation,
              'returnArguments': tabIndex,
            },
          );
        }
        return;
      }

      if (!authProvider.isEmailVerified) {
        await _navigateToFallbackTabWithMessage(
          context,
          _emailVerificationRequiredMessage,
        );
        return;
      }
    }

    // 한국어 주석: Drawer를 명시적으로 닫지 않고 교체 내비게이션만 수행
    // (일부 화면에서 pop 직후 컨텍스트가 비활성화되어 push가 무시되는 문제 예방)
    Navigator.of(
      context,
    ).pushReplacementNamed(AppRoutes.mainNavigation, arguments: tabIndex);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    final displayName = currentUser?.displayName;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.5,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // 사용자 이름 영역 (displayName이 있을 때만 표시)
                  if (displayName != null && displayName.isNotEmpty)
                    ListTile(
                      title: Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.pop(context); // Drawer 닫기
                        Navigator.pushNamed(context, AppRoutes.profile);
                      },
                    ),
                  if (displayName != null && displayName.isNotEmpty)
                    const Divider(),

                  // 네비게이션 메뉴 (6개)
                  ListTile(
                    leading: const Icon(Icons.home),
                    title: const Text('홈'),
                    onTap: () => _navigateToTab(context, 0),
                  ),
                  ListTile(
                    leading: const Icon(Icons.directions_car),
                    title: const Text('차량정보'),
                    onTap: () => _navigateToTab(context, 1),
                  ),
                  ListTile(
                    leading: const Icon(RemixIcons.road_map_fill),
                    title: const Text('지역정보'),
                    onTap: () {
                      _navigateToTab(context, 2);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.attractions),
                    title: const Text('놀거리'),
                    onTap: () {
                      _navigateToTab(context, 3);
                    },
                  ),
                  ListTile(
                    leading: const Icon(RemixIcons.shield_user_fill),
                    title: const Text('안전귀가'),
                    onTap: () async {
                      final authProvider = context.read<AuthProvider>();
                      if (!authProvider.isAuthenticated) {
                        final shouldLogin = await showLoginRequiredDialog(
                          context,
                        );
                        if (shouldLogin == true && context.mounted) {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.login,
                            arguments: {'returnRoute': AppRoutes.safeHome},
                          );
                        }
                        return;
                      }

                      if (!authProvider.isEmailVerified) {
                        await _navigateToFallbackTabWithMessage(
                          context,
                          _emailVerificationRequiredMessage,
                        );
                        return;
                      }

                      // 한국어 주석: pop 없이 pushNamed만 수행하여 컨텍스트 무효화 이슈 방지
                      Navigator.of(context).pushNamed(AppRoutes.safeHome);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.traffic),
                    title: const Text('도로정보'),
                    onTap: () {
                      // 한국어 주석: 도로정보 전용 페이지에서 네이버 지도 표시
                      Navigator.of(context).pushNamed(AppRoutes.roadInfo);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.layers),
                    title: const Text('노면정보'),
                    onTap: () {
                      // 한국어 주석: 노면정보 화면으로 이동
                      Navigator.of(context).pushNamed(AppRoutes.roadSurface);
                    },
                  ),
                ],
              ),
            ),

            // 한국어 주석: 로그인/로그아웃 버튼 (조건부 렌더링)
            const Divider(height: 1),
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                if (authProvider.isAuthenticated) {
                  // 로그인 상태 → 로그아웃 버튼
                  return ListTile(
                    leading: const Icon(
                      RemixIcons.logout_box_r_line,
                      color: Colors.red,
                    ),
                    title: const Text(
                      '로그아웃',
                      style: TextStyle(
                        color: Colors.red,
                        fontFamily: AppConstants.fontFamilySmall,
                      ),
                    ),
                    onTap: () async {
                      // 로그아웃 확인 다이얼로그
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('로그아웃'),
                          content: const Text('로그아웃하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('로그아웃'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && context.mounted) {
                        try {
                          // 한국어 주석: Firebase/Google 로그아웃
                          await _authService.signOut();
                          // 한국어 주석: 자동 로그인 설정 제거
                          await _storageService.clearAutoLogin();
                          // 한국어 주석: 지역정보 탭으로 이동 (비로그인 상태 진입)
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.mainNavigation,
                              arguments: 2, // 지역정보 탭
                            );
                          }
                        } catch (e) {
                          // 한국어 주석: 예외 발생 시 사용자에게 안내
                          if (context.mounted) {
                            SnackBarUtils.showError(
                              context,
                              '로그아웃 중 오류가 발생했습니다: $e',
                            );
                          }
                        }
                      }
                    },
                  );
                } else {
                  // 비로그인 상태 → 로그인 버튼
                  return ListTile(
                    leading: Icon(
                      RemixIcons.login_box_line,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      '로그인',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontFamily: AppConstants.fontFamilySmall,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context); // Drawer 닫기
                      Navigator.pushNamed(context, AppRoutes.login);
                    },
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
