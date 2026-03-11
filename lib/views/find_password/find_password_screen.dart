import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/find_password/find_password_viewmodel.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/loading_button.dart';
import '../../utils/constants.dart';
import '../../routes/app_routes.dart';

/// 비밀번호 찾기 화면
class FindPasswordScreen extends StatefulWidget {
  const FindPasswordScreen({super.key});

  @override
  State<FindPasswordScreen> createState() => _FindPasswordScreenState();
}

class _FindPasswordScreenState extends State<FindPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<FindPasswordViewModel>(
        builder: (context, viewModel, child) {
          // 이메일 발송 성공 시 성공 화면 표시
          if (viewModel.emailSent) {
            return _buildSuccessView(context, viewModel);
          }

          // 기본 입력 화면
          return _buildInputView(context, viewModel);
        },
      ),
    );
  }

  /// 입력 화면
  Widget _buildInputView(
    BuildContext context,
    FindPasswordViewModel viewModel,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // 제목
              Text(
                AppConstants.findPasswordTitle,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                  fontFamily: AppConstants.fontFamilyBig,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              // 부제목 (안내 메시지)
              Text(
                AppConstants.findPasswordInstruction,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
              const SizedBox(height: 40),

              // 이메일 입력 필드
              CustomTextField(
                label: AppConstants.findPasswordEmailLabel,
                hint: AppConstants.findPasswordEmailHint,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: (value) => viewModel.setEmail(value),
                labelColor: colorScheme.onSurface,
                hintColor: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 8),

              // 에러 메시지
              if (viewModel.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    viewModel.errorMessage!,
                    style: TextStyle(
                      color: colorScheme.error,
                      fontSize: 14,
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // 비밀번호 재설정 이메일 발송 버튼
              LoadingButton(
                text: AppConstants.findPasswordSubmitButton,
                onPressed: viewModel.isButtonEnabled
                    ? () => viewModel.submitResetPassword()
                    : null,
                isLoading: viewModel.isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 이메일 발송 성공 화면
  Widget _buildSuccessView(
    BuildContext context,
    FindPasswordViewModel viewModel,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 성공 아이콘
            Icon(
              Icons.mark_email_read,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),

            // 성공 제목
            Text(
              AppConstants.findPasswordSuccessTitle,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: AppConstants.fontFamilyBig,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // 성공 메시지
            Text(
              AppConstants.findPasswordSuccessMessage,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                fontFamily: AppConstants.fontFamilySmall,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  // 상태 초기화 후 로그인 화면으로 이동
                  viewModel.reset();
                  Navigator.pushReplacementNamed(context, AppRoutes.login);
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  AppConstants.findPasswordConfirmButton,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
