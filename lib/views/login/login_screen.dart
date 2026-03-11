import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/login/login_viewmodel.dart';
import '../../widgets/common/loading_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../utils/constants.dart';

/// 로그인 화면 UI
/// 이메일 로그인과 Google 소셜 로그인 옵션을 제공
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();
    final colorScheme = Theme.of(context).colorScheme;

    // 한국어 주석: returnRoute arguments 가져오기 (로그인 후 복귀 경로)
    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () {
            // 한국어 주석: 로그인 페이지에서 뒤로가기 시 이전 화면으로 이동
            // - 네비게이터 스택에 이전 화면이 있을 경우 pop
            // - 없으면 아무 동작도 하지 않음 (시스템 뒤로가기 사용)
            Navigator.maybePop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // 제목
                Text(
                  AppConstants.loginTitle,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    fontFamily: AppConstants.fontFamilyBig,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                // 부제목
                Text(
                  AppConstants.loginSubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                ),
                const SizedBox(height: 24),
                // 이메일 입력 필드
                CustomTextField(
                  label: AppConstants.emailInputLabel,
                  hint: AppConstants.emailHint,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  labelColor: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 16),
                // 비밀번호 입력 필드
                CustomTextField(
                  label: AppConstants.passwordInputLabel,
                  hint: AppConstants.passwordHint,
                  controller: _passwordController,
                  isPassword: true,
                  labelColor: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 12),
                // 자동 로그인 체크박스
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        context.read<LoginViewModel>().setRememberMe(
                          !context.read<LoginViewModel>().rememberMe,
                        );
                      },
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.watch<LoginViewModel>().rememberMe
                              ? colorScheme.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: context.watch<LoginViewModel>().rememberMe
                            ? Icon(
                                Icons.check,
                                size: 14,
                                color: colorScheme.onPrimary,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppConstants.rememberMeText,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontFamily: AppConstants.fontFamilySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 로그인 버튼
                LoadingButton(
                  text: AppConstants.loginButtonText,
                  onPressed: () => viewModel.onEmailPasswordLogin(
                    _emailController.text,
                    _passwordController.text,
                    context,
                    arguments: arguments, // 한국어 주석: returnRoute 전달
                  ),
                  isLoading: viewModel.isEmailLoading,
                  backgroundColor: colorScheme.primary,
                  textColor: colorScheme.onPrimary,
                ),
                const SizedBox(height: 16),
                // 아이디 찾기 | 비밀번호 찾기 | 회원가입
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => viewModel.onFindId(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        AppConstants.findIdText,
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontFamily: AppConstants.fontFamilySmall,
                        ),
                      ),
                    ),
                    Text(
                      '|',
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () => viewModel.onFindPassword(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        AppConstants.findPasswordText,
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontFamily: AppConstants.fontFamilySmall,
                        ),
                      ),
                    ),
                    Text(
                      '|',
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () => viewModel.onSignup(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        AppConstants.signupText,
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontFamily: AppConstants.fontFamilySmall,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // 구분선
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        AppConstants.dividerText,
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 14,
                          fontFamily: AppConstants.fontFamilySmall,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Google 로그인 버튼
                LoadingButton(
                  text: AppConstants.googleLoginButton,
                  onPressed: () => viewModel.onGoogleLogin(
                    context,
                    arguments: arguments, // 한국어 주석: returnRoute 전달
                  ),
                  isLoading: viewModel.isGoogleLoading,
                  backgroundColor: colorScheme.surface,
                  textColor: colorScheme.onSurface,
                  borderColor: colorScheme.onSurface.withValues(alpha: 0.2),
                  icon: Image.asset(
                    'assets/icons/ic_google.webp',
                    width: 24,
                    height: 24,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
