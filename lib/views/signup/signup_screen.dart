import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../view_models/signup/signup_viewmodel.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/terms_checkbox.dart';
import '../../widgets/common/loading_button.dart';
import '../../utils/constants.dart';

/// 회원가입 화면 (이름 입력, 이메일 검증 포함)
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with WidgetsBindingObserver {
  // 약관 URL 상수
  static const String _termsUrl = 'https://e-company.co.kr/policy/terms.html';
  static const String _privacyUrl =
      'https://e-company.co.kr/policy/privacy.html';
  static const String _locationTermsUrl =
      'https://e-company.co.kr/policy/location_terms.html';

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addObserver(context.read<SignupViewModel>());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.removeObserver(context.read<SignupViewModel>());
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      // 한국어 주석: 키보드가 올라올 때 자동으로 본문을 밀어올려 하단 버튼이 가려지지 않도록 처리
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () {
            // 한국어 주석: View가 Navigation 로직 담당 (MVVM 패턴)
            final viewModel = context.read<SignupViewModel>();
            if (viewModel.isFirstStep) {
              Navigator.pop(context); // 로그인 화면으로
            } else {
              viewModel.goToPreviousStep(); // 이전 단계로
            }
          },
        ),
      ),
      body: Consumer<SignupViewModel>(
        builder: (context, viewModel, child) {
          switch (viewModel.currentStep) {
            case SignupStep.nameInput:
              return _buildNameInputStep(viewModel);
            case SignupStep.emailInput:
              return _buildEmailInputStep(viewModel);
            case SignupStep.emailVerification:
              return _buildEmailVerificationStep(viewModel);
            case SignupStep.passwordInput:
              return _buildPasswordInputStep(viewModel);
            case SignupStep.termsAgreement:
              return _buildTermsAgreementStep(viewModel);
          }
        },
      ),
    );
  }

  Widget _buildNameInputStep(SignupViewModel viewModel) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.nameInputTitle,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: AppConstants.fontFamilyBig,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 32),
            CustomTextField(
              label: AppConstants.nameLabel,
              hint: AppConstants.nameHint,
              controller: _nameController,
              errorText: viewModel.errorMessage,
              labelColor: colorScheme.onSurface,
              hintColor: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            LoadingButton(
              text: AppConstants.nameNextButton,
              onPressed: () => viewModel.submitName(_nameController.text),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailInputStep(SignupViewModel viewModel) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.emailInputTitle,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: AppConstants.fontFamilyBig,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 32),
            CustomTextField(
              label: AppConstants.emailLabel,
              hint: AppConstants.emailHint,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              errorText: viewModel.errorMessage,
              labelColor: colorScheme.onSurface,
              hintColor: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            LoadingButton(
              text: AppConstants.verifyButton,
              onPressed: () =>
                  viewModel.sendVerificationEmail(_emailController.text),
              isLoading: viewModel.isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailVerificationStep(SignupViewModel viewModel) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.verificationSentTitle,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: AppConstants.fontFamilyBig,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${viewModel.userEmail}${AppConstants.verificationSentMessage}',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.87),
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppConstants.verificationInstruction,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                viewModel.errorMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.error,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
            ],
            const SizedBox(height: 32),
            CustomTextField(
              label: AppConstants.emailLabel,
              hint: '',
              controller: _emailController,
              enabled: false,
              labelColor: colorScheme.onSurface,
            ),
            const SizedBox(height: 24),
            // 한국어 주석: 수동 인증 확인 버튼 (웹/특정 환경에서 필요)
            LoadingButton(
              text: '인증 확인',
              onPressed: () => viewModel.checkEmailVerification(),
              isLoading: viewModel.isLoading,
            ),
            const SizedBox(height: 12),
            LoadingButton(
              text: AppConstants.resendEmailButton,
              onPressed: () => viewModel.resendVerificationEmail(),
              isLoading: viewModel.isLoading,
              backgroundColor: Theme.of(context).colorScheme.surface,
              textColor: Theme.of(context).colorScheme.primary,
              borderColor: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  /// 비밀번호 설정 단계 (간소화 - 비밀번호 입력 + 체크리스트만 표시)
  Widget _buildPasswordInputStep(SignupViewModel viewModel) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          // 한국어 주석: 키보드 높이만큼 하단 여백을 추가하여 오버플로우 방지
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목
              Text(
                AppConstants.passwordSetTitle,
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
                '안전한 비밀번호를 설정해주세요',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
              const SizedBox(height: 32),

              // 비밀번호 입력
              CustomTextField(
                label: AppConstants.passwordLabel,
                hint: AppConstants.passwordHint,
                controller: _passwordController,
                isPassword: true,
                onChanged: (value) => viewModel.setPassword(value),
                labelColor: colorScheme.onSurface,
                hintColor: colorScheme.onSurface.withValues(alpha: 0.6),
              ),

              // 비밀번호 조건 체크리스트
              if (_passwordController.text.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '비밀번호 조건',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontFamily: AppConstants.fontFamilySmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCheckItem(
                        '8자 이상',
                        viewModel.validationStatus['length']!,
                      ),
                      _buildCheckItem(
                        '영문자 포함',
                        viewModel.validationStatus['letter']!,
                      ),
                      _buildCheckItem(
                        '숫자 포함',
                        viewModel.validationStatus['number']!,
                      ),
                      _buildCheckItem(
                        '특수문자 포함',
                        viewModel.validationStatus['special']!,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // 다음 버튼
              LoadingButton(
                text: '다음',
                onPressed: viewModel.isPasswordNextButtonEnabled
                    ? () => viewModel.moveToTermsAgreement()
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 약관 동의 단계 (약관 체크박스만 표시)
  Widget _buildTermsAgreementStep(SignupViewModel viewModel) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          // 한국어 주석: 약관 세부사항 화면 이동 후 복귀 시 안정성 보장
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목
              Text(
                '약관 동의',
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
                '서비스 이용을 위해 약관에 동의해주세요',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
              const SizedBox(height: 32),

              // 전체 동의 체크박스
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: TermsCheckbox(
                  label: AppConstants.termsAgreeAll,
                  value: viewModel.isAllAgreed,
                  onChanged: (value) =>
                      viewModel.toggleAllAgreed(value ?? false),
                  isRequired: false,
                  hasDetail: false,
                ),
              ),
              const SizedBox(height: 12),

              // 구분선
              Divider(color: colorScheme.outlineVariant, height: 1),
              const SizedBox(height: 12),

              // 만 14세 이상 확인
              TermsCheckbox(
                label: AppConstants.termsAge14,
                value: viewModel.isOver14,
                onChanged: (value) => viewModel.toggleOver14(value ?? false),
                isRequired: true,
                hasDetail: false,
              ),
              const SizedBox(height: 8),

              // 이용약관 동의
              TermsCheckbox(
                label: AppConstants.termsService,
                value: viewModel.agreedToService,
                onChanged: (value) =>
                    viewModel.toggleServiceAgreed(value ?? false),
                isRequired: true,
                hasDetail: true,
                onDetailTap: () => _launchURL(_termsUrl),
              ),
              const SizedBox(height: 8),

              // 개인정보 처리방침 동의
              TermsCheckbox(
                label: AppConstants.termsPrivacy,
                value: viewModel.agreedToPrivacy,
                onChanged: (value) =>
                    viewModel.togglePrivacyAgreed(value ?? false),
                isRequired: true,
                hasDetail: true,
                onDetailTap: () => _launchURL(_privacyUrl),
              ),
              const SizedBox(height: 8),

              // 위치기반 서비스 약관 동의
              TermsCheckbox(
                label: '위치기반 서비스 이용약관',
                value: viewModel.agreedToLocation,
                onChanged: (value) =>
                    viewModel.toggleLocationAgreed(value ?? false),
                isRequired: true,
                hasDetail: true,
                onDetailTap: () => _launchURL(_locationTermsUrl),
              ),

              const SizedBox(height: 32),

              // 회원가입 완료 버튼
              LoadingButton(
                text: AppConstants.completeSignupButton,
                onPressed: viewModel.isCompleteButtonEnabled
                    ? () => viewModel.completeSignup(context)
                    : null,
                isLoading: viewModel.isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 비밀번호 조건 체크 아이템 위젯
  Widget _buildCheckItem(String label, bool isValid) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: isValid
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isValid
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: isValid ? FontWeight.w500 : FontWeight.w400,
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
          ),
        ],
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
