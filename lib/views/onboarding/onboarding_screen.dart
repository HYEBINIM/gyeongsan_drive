import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/onboarding/onboarding_viewmodel.dart';
import '../../utils/constants.dart';

/// 온보딩 화면 (단일 리스트 형태)
/// 권한 설명만 표시하고, 실제 권한 요청은 각 기능 사용 시점에 수행
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ChangeNotifierProvider(
      create: (_) => OnboardingViewModel(),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 제목
                Text(
                  AppConstants.onboardingTitle,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppConstants.fontFamilyBig,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),

                // 부제목
                Text(
                  AppConstants.onboardingSubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                ),
                const SizedBox(height: 32),

                // 권한 리스트 (스크롤 가능)
                Expanded(
                  child: ListView(
                    children: [
                      _PermissionItem(
                        icon: Icons.notifications,
                        iconColor: const Color(0xFFFFB800),
                        title: AppConstants.notificationPermissionShortTitle,
                        description:
                            AppConstants.notificationPermissionShortDesc,
                      ),
                      const SizedBox(height: 16),
                      _PermissionItem(
                        icon: Icons.location_on,
                        iconColor: const Color(0xFF3B82F6),
                        title: AppConstants.locationPermissionShortTitle,
                        description: AppConstants.locationPermissionShortDesc,
                      ),
                      _PermissionItem(
                        icon: Icons.mic,
                        iconColor: const Color(0xFF34A853),
                        title: AppConstants.microphonePermissionShortTitle,
                        description: AppConstants.microphonePermissionShortDesc,
                      ),
                      _PermissionItem(
                        icon: Icons.contacts,
                        iconColor: const Color(0xFFEA4335),
                        title: AppConstants.contactPermissionShortTitle,
                        description: AppConstants.contactPermissionShortDesc,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 하단 설명
                Text(
                  AppConstants.onboardingDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // 버튼 2개 (로그인하기, 둘러보기)
                Consumer<OnboardingViewModel>(
                  builder: (context, viewModel, _) {
                    return Column(
                      children: [
                        // 로그인하고 시작하기 버튼
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              // 로그인 화면으로 이동
                              viewModel.completeWithLogin(context);
                            },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '로그인하고 시작하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: AppConstants.fontFamilySmall,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 둘러보기 버튼 (아웃라인)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () {
                              // 비로그인으로 지역정보 탭으로 이동
                              viewModel.completeWithoutLogin(context);
                            },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                color: colorScheme.primary,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              '둘러보기',
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.primary,
                                fontFamily: AppConstants.fontFamilySmall,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 권한 항목 위젯
class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _PermissionItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          // 아이콘
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),

          // 제목 + 설명
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppConstants.fontFamilySmall,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
