import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/safe_home/safe_home_settings_viewmodel.dart';
import '../../utils/constants.dart';
import '../../utils/snackbar_utils.dart';

/// 이상 감지 기준 설정 Bottom Sheet
/// 음직임 없음 감지 시간, 도착시간 초과 허용, 경고 알림 횟수 설정
class AnomalyDetectionBottomSheet extends StatelessWidget {
  const AnomalyDetectionBottomSheet({super.key});

  // 드롭다운 옵션 상수 (DRY 원칙)
  static const List<int> _minuteOptions = [1, 3, 5, 10];
  static const List<int> _countOptions = [1, 2, 3, 5];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    // 한국어 주석: 뒤로가기 버튼으로 바텀시트 닫기 허용
    return PopScope(
      canPop: true,
      child: SafeArea(
        child: Container(
          height: screenHeight * 0.7, // 화면의 70% 높이
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // AppBar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '이상 감지 기준',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppConstants.fontFamilySmall,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: colorScheme.onSurface),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // 설정 항목들
              Expanded(
                child: Consumer<SafeHomeSettingsViewModel>(
                  builder: (context, viewModel, _) {
                    return ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: [
                        // 1. 음직임 없음 감지 시간
                        _buildDropdownSection(
                          context: context,
                          title: '음직임 없음 감지 시간',
                          subtitle: '설정한 시간 동안 움직임이 없으면 이상으로 판단합니다',
                          currentValue: viewModel.noMovementDetectionMinutes,
                          options: _minuteOptions,
                          unit: '분',
                          onChanged: (value) async {
                            try {
                              await viewModel.updateNoMovementDetection(value);
                              if (context.mounted) {
                                SnackBarUtils.showSuccess(
                                  context,
                                  '음직임 없음 감지 시간이 $value분으로 설정되었습니다',
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                SnackBarUtils.showError(context, '설정 실패: $e');
                              }
                            }
                          },
                        ),

                        const SizedBox(height: 16),

                        // 2. 도착시간 초과 허용
                        _buildDropdownSection(
                          context: context,
                          title: '도착시간 초과 허용',
                          subtitle: '설정한 시간 초과 시 자동신고를 발송합니다',
                          currentValue: viewModel.arrivalTimeOverlayMinutes,
                          options: _minuteOptions,
                          unit: '분',
                          onChanged: (value) async {
                            try {
                              await viewModel.updateArrivalTimeOverlay(value);
                              if (context.mounted) {
                                SnackBarUtils.showSuccess(
                                  context,
                                  '도착시간 초과 허용이 $value분으로 설정되었습니다',
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                SnackBarUtils.showError(context, '설정 실패: $e');
                              }
                            }
                          },
                        ),

                        const SizedBox(height: 16),

                        // 3. 경고 알림 횟수
                        _buildDropdownSection(
                          context: context,
                          title: '경고 알림 횟수',
                          subtitle:
                              '알림이 설정 횟수를 초과하면 자동으로 경고 후 지정시간이 진행되면 비상신고를 전송합니다',
                          currentValue: viewModel.warningAlertCount,
                          options: _countOptions,
                          unit: '회',
                          onChanged: (value) async {
                            try {
                              await viewModel.updateWarningAlertCount(value);
                              if (context.mounted) {
                                SnackBarUtils.showSuccess(
                                  context,
                                  '경고 알림 횟수가 $value회로 설정되었습니다',
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                SnackBarUtils.showError(context, '설정 실패: $e');
                              }
                            }
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 재사용 가능한 드롭다운 섹션 빌더 (DRY 원칙)
  Widget _buildDropdownSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required int currentValue,
    required List<int> options,
    required String unit,
    required ValueChanged<int> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
            const SizedBox(height: 4),

            // 부제
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
                fontSize: 12,
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
            const SizedBox(height: 16),

            // 드롭다운
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant, width: 1),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: currentValue,
                  isExpanded: true,
                  dropdownColor: colorScheme.surfaceContainerHigh,
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: colorScheme.onSurface,
                  ),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                  items: options.map((value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value$unit'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onChanged(value);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
