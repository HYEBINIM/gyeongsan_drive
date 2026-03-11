// UTF-8 인코딩 파일
// 한국어 주석: 비상 상황 시 보안 암호 입력 Bottom Sheet
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/safe_home_event.dart';
import '../../view_models/safe_home/safe_home_monitor_viewmodel.dart';
import '../../utils/safe_home_constants.dart';

/// 보안 암호 입력 Bottom Sheet
///
/// Safe Home 이벤트 발생 시 사용자의 안전을 확인하기 위한 PIN 입력 Bottom Sheet
///
/// **특징**:
/// - Modal Bottom Sheet (높이 85%, 키보드 대응)
/// - isDismissible: false (강제 입력)
/// - Material 3 디자인 + 긴급성 강조 (빨간색 상단 테두리)
/// - 실패 횟수 표시
/// - 3회 실패 시 비상연락처 전화 안내
class SecurityVerificationBottomSheet extends StatefulWidget {
  /// 발생한 이벤트
  final SafeHomeEvent event;

  /// 현재 암호 입력 실패 횟수
  final int failCount;

  /// 암호 검증 콜백
  ///
  /// [pin] 사용자가 입력한 PIN
  /// 한국어 주석: 비동기 콜백으로 정의하여 검증/네트워크 작업과 상태 전환을 명확히 처리
  final Future<void> Function(String) onVerify;

  const SecurityVerificationBottomSheet({
    super.key,
    required this.event,
    required this.failCount,
    required this.onVerify,
  });

  @override
  State<SecurityVerificationBottomSheet> createState() =>
      _SecurityVerificationBottomSheetState();
}

class _SecurityVerificationBottomSheetState
    extends State<SecurityVerificationBottomSheet> {
  final _pinController = TextEditingController();
  bool _isVerifying = false;
  String? _inlineError; // 한국어 주석: 스낵바 대신 바텀시트 내부 에러 표기

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  /// 암호 검증 처리
  Future<void> _handleVerify() async {
    final pin = _pinController.text.trim();

    // 입력 검증
    if (!SafeHomeConstants.isValidPin(pin)) {
      _showError(
        '보안 암호는 ${SafeHomeConstants.pinLength}자리 숫자입니다. (기존 ${SafeHomeConstants.legacyPinMaxLength}자리도 입력할 수 있어요)',
      );
      return;
    }

    // 검증 중 상태
    setState(() {
      _isVerifying = true;
    });

    try {
      // 한국어 주석: 콜백 호출 (ViewModel이 실제 검증 수행)
      await widget.onVerify(pin);
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  /// 에러 메시지 표시
  void _showError(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _inlineError = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.of(context).size.height;

    // 한국어 주석: 비상 상황 보안 인증은 뒤로가기로 우회 불가
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // 한국어 주석: 뒤로가기 시도 시 진동으로 피드백
          HapticFeedback.mediumImpact();
          // 한국어 주석: 인라인 에러 메시지 표시
          setState(() {
            _inlineError = '보안 암호 입력이 필요합니다.';
          });
        }
      },
      child: Container(
        // 한국어 주석: 화면의 90% 높이 사용 (긴급성 강조)
        constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          // 한국어 주석: 상단 빨간색 테두리 (비상 상황 강조)
          border: Border(top: BorderSide(color: colorScheme.error, width: 4)),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 타이틀
                  Text(
                    '비상 상황 감지',
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // 이벤트 메시지
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.event.message,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),

                  // 안내 문구
                  Text(
                    '보안 암호를 입력하여 경고를 해제하세요.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.secondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // PIN 입력 필드
                  TextField(
                    controller: _pinController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: SafeHomeConstants.legacyPinMaxLength,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    enabled: !_isVerifying,
                    decoration: InputDecoration(
                      labelText: '보안 암호',
                      hintText:
                          '${SafeHomeConstants.pinLength}자리 숫자 (최대 ${SafeHomeConstants.legacyPinMaxLength}자리)',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.error,
                          width: 2,
                        ),
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: colorScheme.secondary,
                      ),
                      counterText: '', // 글자 수 카운터 숨김
                    ),
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      letterSpacing: 4, // PIN 입력 시각적 효과
                    ),
                    onSubmitted: (_) => _handleVerify(),
                    onChanged: (_) {
                      if (_inlineError != null) {
                        setState(() {
                          _inlineError = null; // 한국어 주석: 입력 중 에러 문구 제거
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // 한국어 주석: 인라인 에러 메시지
                  if (_inlineError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: colorScheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _inlineError!,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 한국어 주석: 실패/남은 횟수 표시 + 임계 초과 시 전화 안내
                  Builder(
                    builder: (context) {
                      // 한국어 주석: 실시간 실패 횟수는 모니터 VM에서 조회 (BottomSheet 생성 후에도 갱신 반영)
                      final failCount = context
                          .select<SafeHomeMonitorViewModel, int>(
                            (vm) => vm.verificationFailCount,
                          );
                      // 한국어 주석: PIN 시도 횟수 제한은 경고 알림 횟수와 별개로 고정(3회)
                      // - UX: 일반적인 보안 패턴과 동일하게 3회 제한
                      // - 경고 알림 횟수는 이상 감지 이벤트 빈도에 대한 설정이므로 혼합하지 않음
                      const int allowed = SafeHomeConstants.pinMaxAttempts;
                      final remaining = (allowed - failCount) > 0
                          ? (allowed - failCount)
                          : 0;

                      // 한국어 주석: 실패 이력이 없으면 안내 생략
                      final showAttempts = failCount > 0;

                      final attemptInfo = showAttempts
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (remaining == 0
                                    ? colorScheme.error.withValues(alpha: 0.08)
                                    : colorScheme.surfaceContainerLow),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: (remaining == 0
                                      ? colorScheme.error.withValues(alpha: 0.3)
                                      : colorScheme.outlineVariant),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    remaining == 0
                                        ? Icons.error_outline
                                        : Icons.info_outline,
                                    color: remaining == 0
                                        ? colorScheme.error
                                        : colorScheme.onSurfaceVariant,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '남은 횟수: $remaining회',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: remaining == 0
                                            ? colorScheme.error
                                            : colorScheme.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink();

                      // 한국어 주석: 임계 초과 시 전화 안내 배지
                      final shouldShowCallBadge = failCount >= allowed;
                      final callBadge = shouldShowCallBadge
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.error.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: colorScheme.error.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.phone_in_talk,
                                      color: colorScheme.error,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '비상연락처에 전화를 걸었습니다.',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.error,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [attemptInfo, callBadge],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // 확인 버튼
                  FilledButton(
                    onPressed: _isVerifying ? null : _handleVerify,
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isVerifying
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : const Text(
                            '확인',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
