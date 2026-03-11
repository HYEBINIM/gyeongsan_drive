// UTF-8 인코딩 파일
// 한국어 주석: 테마 선택 다이얼로그 위젯 (MVVM, DRY, KISS 원칙 준수)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/theme/theme_viewmodel.dart';
import '../../utils/constants.dart';

/// 테마 선택 다이얼로그
/// 사용자가 라이트/다크/시스템 테마를 선택할 수 있는 세련된 다이얼로그
class ThemeSelectionDialog extends StatefulWidget {
  const ThemeSelectionDialog({super.key});

  @override
  State<ThemeSelectionDialog> createState() => _ThemeSelectionDialogState();
}

class _ThemeSelectionDialogState extends State<ThemeSelectionDialog> {
  String? _selectedMode;

  @override
  void initState() {
    super.initState();
    // 현재 테마 모드를 초기 선택값으로 설정
    _selectedMode = Provider.of<ThemeViewModel>(
      context,
      listen: false,
    ).themeMode;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 한국어 주석: 뒤로가기 버튼으로 다이얼로그 닫기 허용
    return PopScope(
      canPop: true,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 300, // 최소 너비: 300px (작은 화면 대응)
            maxWidth: 500, // 최대 너비: 500px (큰 화면 제한)
          ),
          child: IntrinsicWidth(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 제목
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '사용하실 모드를 선택해주세요!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppConstants.fontFamilyBig,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 부제목
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '설정에서 언제든지 변경 가능합니다.',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: AppConstants.fontFamilySmall,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3개의 선택 카드
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _ThemeOptionCard(
                          mode: 'light',
                          label: '라이트 모드',
                          isSelected: _selectedMode == 'light',
                          onTap: () => setState(() => _selectedMode = 'light'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ThemeOptionCard(
                          mode: 'dark',
                          label: '다크 모드',
                          isSelected: _selectedMode == 'dark',
                          onTap: () => setState(() => _selectedMode = 'dark'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ThemeOptionCard(
                          mode: 'system',
                          label: '기기 설정 사용',
                          isSelected: _selectedMode == 'system',
                          onTap: () => setState(() => _selectedMode = 'system'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 하단 설명
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '화면 모드가 사용자 기기 화면 설정과 동일하게 적용됩니다.',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: AppConstants.fontFamilySmall,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 확인 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_selectedMode != null) {
                          // ViewModel을 통해 테마 변경
                          Provider.of<ThemeViewModel>(
                            context,
                            listen: false,
                          ).setThemeMode(_selectedMode!);
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppConstants.fontFamilyBig,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 테마 옵션 선택 카드
/// 미리보기 이미지, 라벨, 라디오 버튼을 포함
class _ThemeOptionCard extends StatelessWidget {
  final String mode;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    required this.mode,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 미리보기 이미지
          _ThemePreviewBox(mode: mode, isSelected: isSelected),
          const SizedBox(height: 8),

          // 라벨
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontFamily: AppConstants.fontFamilySmall,
                color: colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),

          // 라디오 버튼
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// 테마 미리보기 박스
/// 라이트/다크/시스템 모드를 시각적으로 표현
class _ThemePreviewBox extends StatelessWidget {
  final String mode;
  final bool isSelected;

  const _ThemePreviewBox({required this.mode, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.2),
          width: isSelected ? 2.5 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: _buildPreviewContent(),
      ),
    );
  }

  Widget _buildPreviewContent() {
    switch (mode) {
      case 'light':
        // 라이트 모드: 전체 흰색
        return Container(color: Colors.white);

      case 'dark':
        // 다크 모드: 전체 검은색
        return Container(color: Colors.black);

      case 'system':
        // 시스템 설정: 좌측 흰색 / 우측 검은색 반반
        return Row(
          children: [
            Expanded(child: Container(color: Colors.white)),
            Expanded(child: Container(color: Colors.black)),
          ],
        );

      default:
        return Container(color: Colors.grey);
    }
  }
}
