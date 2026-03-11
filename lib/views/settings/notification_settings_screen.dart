import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../view_models/notification/notification_settings_viewmodel.dart';
import '../../widgets/common/section_header.dart';

/// 알림 설정 화면
/// YAGNI 원칙: 현재 필요한 3개 설정만 포함 (전체, 소리, 진동)
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          children: [
            Consumer<NotificationSettingsViewModel>(
              builder: (context, viewModel, _) {
                if (!viewModel.isInitializing && viewModel.isInitialized) {
                  return const SizedBox.shrink();
                }

                return const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '알림 설정을 불러오는 중입니다...',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: AppConstants.fontFamilySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // 전체 설정 섹션
            const SectionHeader(title: '알림 설정'),

            // 전체 알림 수신
            Consumer<NotificationSettingsViewModel>(
              builder: (context, viewModel, _) {
                return SwitchListTile(
                  title: const Text(
                    '알림 받기',
                    style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
                  ),
                  subtitle: const Text(
                    '모든 알림을 받습니다',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                  secondary: const Icon(Icons.notifications),
                  value: viewModel.enabled,
                  onChanged: viewModel.isReady
                      ? (value) {
                          viewModel.toggleEnabled(value);
                        }
                      : null,
                );
              },
            ),

            // 알림 소리
            Consumer<NotificationSettingsViewModel>(
              builder: (context, viewModel, _) {
                return SwitchListTile(
                  title: const Text(
                    '소리',
                    style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
                  ),
                  subtitle: const Text(
                    '알림 소리를 켭니다',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                  secondary: const Icon(Icons.volume_up),
                  value: viewModel.sound,
                  onChanged: viewModel.isReady && viewModel.enabled
                      ? (value) {
                          viewModel.toggleSound(value);
                        }
                      : null, // 전체 알림이 꺼져있으면 비활성화
                );
              },
            ),

            // 알림 진동
            Consumer<NotificationSettingsViewModel>(
              builder: (context, viewModel, _) {
                return SwitchListTile(
                  title: const Text(
                    '진동',
                    style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
                  ),
                  subtitle: const Text(
                    '알림 진동을 켭니다',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                  secondary: const Icon(Icons.vibration),
                  value: viewModel.vibration,
                  onChanged: viewModel.isReady && viewModel.enabled
                      ? (value) {
                          viewModel.toggleVibration(value);
                        }
                      : null, // 전체 알림이 꺼져있으면 비활성화
                );
              },
            ),

            const Divider(height: 32),

            // 알림 타입 섹션
            const SectionHeader(title: '알림 종류'),

            // 공지사항 알림
            Consumer<NotificationSettingsViewModel>(
              builder: (context, viewModel, _) {
                return SwitchListTile(
                  title: const Text(
                    '공지사항',
                    style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
                  ),
                  subtitle: const Text(
                    '새로운 공지사항이 등록되면 알림을 받습니다',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                  secondary: const Icon(Icons.campaign),
                  value: viewModel.announcements,
                  onChanged: viewModel.isReady && viewModel.enabled
                      ? (value) {
                          viewModel.toggleAnnouncements(value);
                        }
                      : null,
                );
              },
            ),

            // 문의 답변 알림
            Consumer<NotificationSettingsViewModel>(
              builder: (context, viewModel, _) {
                return SwitchListTile(
                  title: const Text(
                    '문의 답변',
                    style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
                  ),
                  subtitle: const Text(
                    '문의하기 답변이 등록되면 알림을 받습니다',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                  secondary: const Icon(Icons.question_answer),
                  value: viewModel.inquiryReplies,
                  onChanged: viewModel.isReady && viewModel.enabled
                      ? (value) {
                          viewModel.toggleInquiryReplies(value);
                        }
                      : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
