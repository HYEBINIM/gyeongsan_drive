import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routes/app_routes.dart';
import '../../utils/constants.dart';
import '../../utils/snackbar_utils.dart';
import '../../view_models/profile/delete_account_viewmodel.dart';

/// 계정 삭제 화면
class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeleteAccountViewModel(),
      child: const _DeleteAccountView(),
    );
  }
}

/// 계정 삭제 화면 View (MVVM 패턴)
class _DeleteAccountView extends StatefulWidget {
  const _DeleteAccountView();

  @override
  State<_DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends State<_DeleteAccountView> {
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _agreedToDelete = false;

  /// 재인증 실행
  /// - 구글 로그인: 구글 재인증 플로우 실행
  /// - 이메일 로그인: 비밀번호 검증 후 재인증 실행
  Future<void> _reauthenticate() async {
    final viewModel = context.read<DeleteAccountViewModel>();
    final provider = viewModel.userProvider;

    // 이메일 로그인 사용자는 비밀번호 유효성 먼저 확인
    if (provider == 'password') {
      if (!_formKey.currentState!.validate()) return;
    }

    final password = provider == 'google.com' ? null : _passwordController.text;
    final ok = await viewModel.reauthenticate(password);

    if (!mounted) return;

    if (ok) {
      SnackBarUtils.showSuccess(context, '재인증이 완료되었습니다');
    } else if (viewModel.errorMessage != null) {
      SnackBarUtils.showError(context, viewModel.errorMessage!);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  /// 계정 삭제
  Future<void> _deleteAccount() async {
    final viewModel = context.read<DeleteAccountViewModel>();
    final provider = viewModel.userProvider;

    // 이메일 로그인 사용자만 비밀번호 검증
    if (provider == 'password' && !_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreedToDelete) {
      SnackBarUtils.showWarning(context, '삭제 동의에 체크해주세요');
      return;
    }

    // 재인증 선행 여부 확인
    if (!viewModel.isReauthValid) {
      SnackBarUtils.showWarning(context, '보안을 위해 먼저 재인증을 완료해주세요');
      return;
    }

    // 최종 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '정말로 계정을 삭제하시겠습니까?',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          '이 작업은 되돌릴 수 없습니다.\n'
          '모든 데이터가 영구적으로 삭제됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // ViewModel을 통한 계정 삭제 실행 (재인증 완료가 선행되어야 함)
    final success = await viewModel.deleteAccount();

    if (!mounted) return;

    if (success) {
      // 로그인 화면으로 이동
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );

      // 계정 삭제 완료 메시지
      SnackBarUtils.showSuccess(context, '계정이 삭제되었습니다');
    } else {
      // 에러 메시지 표시
      if (viewModel.errorMessage != null) {
        SnackBarUtils.showError(context, viewModel.errorMessage!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewModel = context.watch<DeleteAccountViewModel>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: const Text('계정 삭제', maxLines: 1),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              const SizedBox(height: 8),

              // 경고 메시지 - 미니멀 박스
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.error.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // 경고 아이콘 (배경 제거)
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 40,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 16),

                    // 제목
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '계정 삭제 경고',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.error,
                          fontFamily: AppConstants.fontFamilyBig,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 설명
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '계정을 삭제하면 다음 데이터가 영구적으로 삭제됩니다',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontFamily: AppConstants.fontFamilySmall,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 삭제 항목 리스트
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWarningItem('프로필 정보', colorScheme.error),
                        const SizedBox(height: 8),
                        _buildWarningItem('등록된 차량 정보', colorScheme.error),
                        const SizedBox(height: 8),
                        _buildWarningItem('사용 기록', colorScheme.error),
                        const SizedBox(height: 8),
                        _buildWarningItem('모든 설정', colorScheme.error),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 경고 텍스트 (박스 제거)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '이 작업은 되돌릴 수 없습니다',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.error,
                          fontFamily: AppConstants.fontFamilySmall,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Provider에 따른 조건부 UI
              if (viewModel.userProvider == 'google.com')
                // 구글 로그인 사용자: 안내 문구
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '구글 계정으로 로그인하셨습니다.\n계정 삭제 시 구글 재인증이 필요합니다.',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface,
                            fontFamily: AppConstants.fontFamilySmall,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                // 이메일 로그인 사용자: 비밀번호 입력 필드
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: '비밀번호 확인',
                    labelStyle: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                    hintText: '계정 삭제를 위해 비밀번호를 입력하세요',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                      ),
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
                      borderSide: BorderSide(color: colorScheme.error),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호를 입력해주세요';
                    }
                    return null;
                  },
                  enabled: !viewModel.isLoading,
                ),

              const SizedBox(height: 16),

              // 재인증 상태 표시 및 재인증 버튼
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: viewModel.isReauthValid
                      ? Colors.green.withValues(alpha: 0.08)
                      : colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: viewModel.isReauthValid
                        ? Colors.green.withValues(alpha: 0.3)
                        : colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      viewModel.isReauthValid
                          ? Icons.verified_rounded
                          : Icons.lock_clock_rounded,
                      color: viewModel.isReauthValid
                          ? Colors.green
                          : colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        viewModel.isReauthValid
                            ? '최근 재인증됨'
                            : (viewModel.userProvider == 'google.com'
                                  ? '계정 삭제를 위해 구글 재인증이 필요합니다'
                                  : '계정 삭제를 위해 비밀번호 재인증이 필요합니다'),
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: AppConstants.fontFamilySmall,
                          color: viewModel.isReauthValid
                              ? Colors.green
                              : colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: viewModel.isLoading ? null : _reauthenticate,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        side: BorderSide(
                          color: viewModel.isReauthValid
                              ? Colors.green
                              : colorScheme.primary,
                        ),
                        foregroundColor: viewModel.isReauthValid
                            ? Colors.green
                            : colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        viewModel.userProvider == 'google.com'
                            ? '구글로 재인증'
                            : '비밀번호 재인증',
                        style: const TextStyle(
                          fontFamily: AppConstants.fontFamilySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 삭제 동의 체크박스
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CheckboxListTile(
                  value: _agreedToDelete,
                  onChanged: viewModel.isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _agreedToDelete = value ?? false;
                          });
                        },
                  title: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '위 내용을 확인했으며, 계정 삭제에 동의합니다',
                      style: TextStyle(
                        fontFamily: AppConstants.fontFamilySmall,
                        color: colorScheme.onSurface,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: colorScheme.error,
                  checkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 계정 삭제 버튼 - 플랫 스타일 (재인증 완료 시에만 활성화)
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: viewModel.isLoading || !viewModel.isReauthValid
                      ? null
                      : _deleteAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: viewModel.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: const Text(
                            '계정 영구 삭제',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: AppConstants.fontFamilySmall,
                            ),
                            maxLines: 1,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // 취소 버튼
              OutlinedButton(
                onPressed: viewModel.isLoading
                    ? null
                    : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '취소',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: AppConstants.fontFamilySmall,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 경고 항목 위젯
  Widget _buildWarningItem(String text, Color errorColor) {
    return Row(
      children: [
        Icon(Icons.close_rounded, size: 18, color: errorColor),
        const SizedBox(width: 12),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: errorColor.withValues(alpha: 0.9),
                fontFamily: AppConstants.fontFamilySmall,
              ),
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }
}
