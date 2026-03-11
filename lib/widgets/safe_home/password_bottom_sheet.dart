import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../utils/safe_home_constants.dart';
import '../common/pin_code_input.dart';

/// 보안 암호 Bottom Sheet
/// 설정/관리/검증 모드 지원
class PasswordBottomSheet extends StatefulWidget {
  final bool isPasswordSet; // 암호 설정 여부
  final Future<void> Function(String) onSetPassword; // 암호 설정 시
  final bool Function(String) onVerifyPassword; // 암호 검증
  final Future<void> Function(String) onDeletePassword; // 암호 삭제 시

  const PasswordBottomSheet({
    super.key,
    required this.isPasswordSet,
    required this.onSetPassword,
    required this.onVerifyPassword,
    required this.onDeletePassword,
  });

  @override
  State<PasswordBottomSheet> createState() => _PasswordBottomSheetState();
}

enum _Mode {
  setting, // 암호 설정
  management, // 암호 관리
  verifying, // 암호 확인 (삭제 시)
}

class _PasswordBottomSheetState extends State<PasswordBottomSheet> {
  late _Mode _mode;
  String? _errorMessage;
  final TextEditingController _verifyPinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mode = widget.isPasswordSet ? _Mode.management : _Mode.setting;
  }

  @override
  void dispose() {
    _verifyPinController.dispose();
    super.dispose();
  }

  /// PIN 입력 완료 시
  void _onPinCompleted(String pin) async {
    setState(() => _errorMessage = null);

    if (_mode == _Mode.setting) {
      // 암호 설정 모드
      try {
        await widget.onSetPassword(pin);
        // Bottom Sheet는 상위에서 닫음
      } catch (e) {
        setState(() => _errorMessage = e.toString());
      }
    } else if (_mode == _Mode.verifying) {
      // 암호 확인 모드 (삭제 시)
      if (widget.onVerifyPassword(pin)) {
        try {
          await widget.onDeletePassword(pin);
          // Bottom Sheet는 상위에서 닫음
        } catch (e) {
          setState(() => _errorMessage = e.toString());
        }
      } else {
        setState(() => _errorMessage = '암호가 일치하지 않습니다');
      }
    }
  }

  /// 삭제 버튼 클릭 시
  Future<void> _onDeleteButtonTap() async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            '보안 암호 삭제',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
          content: Text(
            '정말 보안 암호를 삭제하시겠습니까?\n삭제 후 다시 설정할 수 있습니다.',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '취소',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                '삭제',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      // 검증 모드로 전환
      setState(() {
        _mode = _Mode.verifying;
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    // 한국어 주석: 뒤로가기 버튼으로 바텀시트 닫기 허용
    return PopScope(
      canPop: true,
      child: SafeArea(
        child: Container(
          height: screenHeight * 0.70, // 화면의 75% 높이
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
                      _mode == _Mode.management ? '보안 암호 관리' : '보안 암호 설정',
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

              // 내용
              Expanded(
                child: _mode == _Mode.management
                    ? _buildManagementMode(colorScheme)
                    : _buildPinInputMode(colorScheme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 암호 설정/확인 모드 (PIN 입력)
  Widget _buildPinInputMode(ColorScheme colorScheme) {
    // 한국어 주석: 삭제를 위한 검증 모드에서는 TextField를 사용하여
    // 과거 6자리 암호와 새 4자리 암호를 모두 입력할 수 있게 합니다.
    if (_mode == _Mode.verifying) {
      return SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 32,
          bottom: 32 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '기존 보안 암호를 입력해주세요',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
                fontFamily: AppConstants.fontFamilySmall,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _verifyPinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: SafeHomeConstants.legacyPinMaxLength,
              decoration: InputDecoration(
                labelText: '보안 암호',
                hintText:
                    '${SafeHomeConstants.pinLength}자리 숫자 (최대 ${SafeHomeConstants.legacyPinMaxLength}자리)',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.2,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outline, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                counterText: '',
              ),
              style: const TextStyle(letterSpacing: 4),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() {
                    _errorMessage = null;
                  });
                }
              },
              onSubmitted: (_) => _handleVerifyInput(),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: colorScheme.error,
                    fontSize: 14,
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _handleVerifyInput,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '암호 확인 후 삭제',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          // 안내 메시지
          Text(
            _mode == _Mode.setting
                ? '비상시 사용할 ${SafeHomeConstants.pinLength}자리\n숫자를 입력해주세요'
                : '기존 보안 암호를\n입력해주세요',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
              fontFamily: AppConstants.fontFamilySmall,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // PIN 입력 위젯
          PinCodeInput(
            minLength: SafeHomeConstants.pinLength,
            maxLength: SafeHomeConstants.pinLength,
            onCompleted: _onPinCompleted,
            errorMessage: _errorMessage,
            autoSubmit: true,
          ),
        ],
      ),
    );
  }

  /// 한국어 주석: 삭제를 위한 기존 암호 검증 처리
  void _handleVerifyInput() {
    final pin = _verifyPinController.text.trim();

    // 한국어 주석: 새 4자리 + 기존 6자리 숫자 모두 허용
    if (!SafeHomeConstants.isValidPin(pin)) {
      setState(() {
        _errorMessage =
            '보안 암호는 ${SafeHomeConstants.pinLength}자리 숫자입니다. (기존 ${SafeHomeConstants.legacyPinMaxLength}자리도 입력할 수 있어요)';
      });
      return;
    }

    _onPinCompleted(pin);
  }

  /// 암호 관리 모드 (삭제 버튼)
  Widget _buildManagementMode(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 현재 상태 표시
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '현재 상태: 설정됨',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimaryContainer,
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(SafeHomeConstants.pinLength, (index) {
                    return Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimary,
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 삭제 버튼
          ElevatedButton(
            onPressed: _onDeleteButtonTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.errorContainer,
              foregroundColor: colorScheme.onErrorContainer,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              '암호 삭제',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 안내 텍스트
          Text(
            '* 암호 변경: 삭제 후 다시 설정해주세요',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.outline,
              fontFamily: AppConstants.fontFamilySmall,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
