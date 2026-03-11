import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/constants.dart';
import '../../utils/snackbar_utils.dart';
import '../common/terms_checkbox.dart';

/// 구글 소셜 로그인 시 약관 동의를 받는 Modal Bottom Sheet
class TermsAgreementBottomSheet extends StatefulWidget {
  /// 동의 완료 시 호출되는 콜백
  final Future<void> Function(
    bool agreedToService,
    bool agreedToPrivacy,
    bool agreedToLocation,
    bool isOver14,
  )
  onAgree;

  /// 취소 시 호출되는 콜백
  final Future<void> Function() onCancel;

  const TermsAgreementBottomSheet({
    super.key,
    required this.onAgree,
    required this.onCancel,
  });

  @override
  State<TermsAgreementBottomSheet> createState() =>
      _TermsAgreementBottomSheetState();
}

class _TermsAgreementBottomSheetState extends State<TermsAgreementBottomSheet> {
  // 약관 URL 상수
  static const String _termsUrl = 'https://e-company.co.kr/policy/terms.html';
  static const String _privacyUrl =
      'https://e-company.co.kr/policy/privacy.html';
  static const String _locationTermsUrl =
      'https://e-company.co.kr/policy/location_terms.html';

  // 약관 동의 상태
  bool _agreedToService = false; // 이용약관
  bool _agreedToPrivacy = false; // 개인정보 처리방침
  bool _agreedToLocation = false; // 위치기반 서비스 약관
  bool _isOver14 = false; // 만 14세 이상

  // 모든 필수 약관이 동의되었는지 확인
  bool get _isAllAgreed =>
      _agreedToService && _agreedToPrivacy && _agreedToLocation && _isOver14;

  // 전체 동의 상태
  bool get _isAllChecked => _isAllAgreed;

  // 전체 동의 토글
  void _toggleAllAgreed(bool value) {
    setState(() {
      _agreedToService = value;
      _agreedToPrivacy = value;
      _agreedToLocation = value;
      _isOver14 = value;
    });
  }

  // 동의하고 시작하기 버튼 클릭
  void _handleAgree() {
    if (!_isAllAgreed) {
      SnackBarUtils.showWarning(context, AppConstants.termsNotAgreedError);
      return;
    }

    // 한국어 주석: Bottom Sheet를 먼저 닫아서 체감 속도 향상
    if (mounted) {
      Navigator.of(context).pop();
    }

    // 한국어 주석: 콜백은 백그라운드에서 실행 (네비게이션 + 데이터 저장)
    widget.onAgree(
      _agreedToService,
      _agreedToPrivacy,
      _agreedToLocation,
      _isOver14,
    );
  }

  // 취소 버튼 클릭
  Future<void> _handleCancel() async {
    // 경고 다이얼로그 표시
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('알림'),
        content: const Text(AppConstants.termsDialogCancelWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 진행'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('로그인 취소'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.onCancel();
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showError(context, '오류가 발생했습니다: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false, // 뒤로가기 버튼 비활성화
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle (시각적 요소만)
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 스크롤 가능한 콘텐츠 영역
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Text(
                      AppConstants.termsDialogTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppConstants.fontFamilyBig,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 설명 메시지
                    Text(
                      AppConstants.termsDialogMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.secondary,
                        fontFamily: AppConstants.fontFamilySmall,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 전체 동의 체크박스
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline,
                          width: 1,
                        ),
                      ),
                      child: TermsCheckbox(
                        label: AppConstants.termsAgreeAll,
                        value: _isAllChecked,
                        onChanged: (value) => _toggleAllAgreed(value ?? false),
                        isRequired: false,
                        hasDetail: false,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 만 14세 이상 확인 (필수)
                    TermsCheckbox(
                      label: AppConstants.termsAge14,
                      value: _isOver14,
                      onChanged: (value) => setState(() {
                        _isOver14 = value ?? false;
                      }),
                      isRequired: true,
                      hasDetail: false,
                    ),
                    const SizedBox(height: 16),

                    // 이용약관 동의 (필수 + 상세보기)
                    TermsCheckbox(
                      label: AppConstants.termsService,
                      value: _agreedToService,
                      onChanged: (value) => setState(() {
                        _agreedToService = value ?? false;
                      }),
                      isRequired: true,
                      hasDetail: true,
                      onDetailTap: () => _launchURL(_termsUrl),
                    ),
                    const SizedBox(height: 16),

                    // 개인정보 처리방침 동의 (필수 + 상세보기)
                    TermsCheckbox(
                      label: AppConstants.termsPrivacy,
                      value: _agreedToPrivacy,
                      onChanged: (value) => setState(() {
                        _agreedToPrivacy = value ?? false;
                      }),
                      isRequired: true,
                      hasDetail: true,
                      onDetailTap: () => _launchURL(_privacyUrl),
                    ),
                    const SizedBox(height: 16),

                    // 위치기반 서비스 약관 동의 (필수 + 상세보기)
                    TermsCheckbox(
                      label: '위치기반 서비스 이용약관',
                      value: _agreedToLocation,
                      onChanged: (value) => setState(() {
                        _agreedToLocation = value ?? false;
                      }),
                      isRequired: true,
                      hasDetail: true,
                      onDetailTap: () => _launchURL(_locationTermsUrl),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // 하단 고정 버튼 영역
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(color: colorScheme.outline, width: 1),
                ),
              ),
              child: Row(
                children: [
                  // 취소 버튼 (Outlined)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: colorScheme.outline,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: colorScheme.onSurface,
                      ),
                      child: const Text(
                        AppConstants.termsDialogCancelButton,
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: AppConstants.fontFamilySmall,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 동의하고 시작하기 버튼 (Primary)
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _handleAgree,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        AppConstants.termsDialogAgreeButton,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: AppConstants.fontFamilySmall,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
        SnackBarUtils.showError(context, '링크를 열 수 없습니다: $urlString');
      }
    }
  }
}
