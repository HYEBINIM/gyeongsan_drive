import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/constants.dart';
import '../../routes/app_routes.dart';
import '../../view_models/theme/theme_viewmodel.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/dialogs/theme_selection_dialog.dart';

/// 앱 설정 화면 (알림, 테마 등)
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  // 약관 URL 상수
  static const String _termsUrl = 'https://e-company.co.kr/policy/terms.html';
  static const String _privacyUrl =
      'https://e-company.co.kr/policy/privacy.html';
  static const String _locationTermsUrl =
      'https://e-company.co.kr/policy/location_terms.html';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('앱 설정'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          children: [
            // 알림 설정 섹션
            const SectionHeader(title: '알림'),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text(
                '알림',
                style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
              ),
              subtitle: const Text(
                '알림 설정을 관리합니다',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.notificationSettings);
              },
            ),

            const Divider(height: 32),

            // 테마 설정 섹션
            const SectionHeader(title: '화면'),
            Consumer<ThemeViewModel>(
              builder: (context, themeViewModel, _) {
                return ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: const Text(
                    '테마',
                    style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
                  ),
                  subtitle: Text(
                    themeViewModel.themeModeLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _showThemeDialog();
                  },
                );
              },
            ),

            const Divider(height: 32),

            // 정보 섹션
            const SectionHeader(title: '정보'),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text(
                '버전 정보',
                style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
              ),
              subtitle: const Text(
                '1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text(
                '이용약관',
                style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
              ),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () => _launchURL(_termsUrl),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text(
                '개인정보 처리방침',
                style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
              ),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () => _launchURL(_privacyUrl),
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text(
                '위치기반서비스 이용약관',
                style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
              ),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () => _launchURL(_locationTermsUrl),
            ),
          ],
        ),
      ),
    );
  }

  /// 테마 선택 다이얼로그 표시
  /// 재사용 가능한 위젯을 사용하여 코드 중복 제거 (DRY 원칙)
  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => const ThemeSelectionDialog(),
    );
  }

  /// 외부 브라우저에서 URL 열기
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('링크를 열 수 없습니다');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('링크를 열 수 없습니다: $urlString'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
