import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/profile/change_email_viewmodel.dart';
import '../../utils/constants.dart';
import '../../utils/snackbar_utils.dart';

/// 이메일 변경 화면
class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newEmailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _newEmailController.dispose();
    super.dispose();
  }

  /// 이메일 변경
  Future<void> _changeEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final viewModel = context.read<ChangeEmailViewModel>();
    final newEmail = _newEmailController.text.trim();

    // ViewModel을 통해 이메일 변경 요청 (인증 이메일 발송)
    final success = await viewModel.requestEmailChange(
      _passwordController.text,
      newEmail,
    );

    if (mounted && success) {
      // 성공 다이얼로그 표시
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('인증 이메일 발송'),
          content: Text(
            '$newEmail\n\n위 이메일로 인증 링크가 발송되었습니다.\n'
            '이메일의 링크를 클릭하여 이메일 변경을 완료해주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 다이얼로그 닫기
                Navigator.pop(context); // 화면 닫기
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } else if (mounted && viewModel.errorMessage != null) {
      SnackBarUtils.showError(context, viewModel.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChangeEmailViewModel>(
      builder: (context, viewModel, _) {
        final currentEmail = viewModel.currentEmail;

        return Scaffold(
          appBar: AppBar(title: const Text('이메일 변경'), centerTitle: true),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 16),

                  // 현재 이메일 표시
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '현재 이메일',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                  fontFamily: AppConstants.fontFamilySmall,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentEmail,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontFamily: AppConstants.fontFamilySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 비밀번호 확인
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: '비밀번호 확인',
                      hintText: '현재 비밀번호를 입력하세요',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력해주세요';
                      }
                      return null;
                    },
                    enabled: !viewModel.isLoading,
                  ),

                  const SizedBox(height: 16),

                  // 새 이메일
                  TextFormField(
                    controller: _newEmailController,
                    decoration: const InputDecoration(
                      labelText: '새 이메일',
                      hintText: '새 이메일 주소를 입력하세요',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '새 이메일을 입력해주세요';
                      }
                      // 이메일 형식 검증
                      final emailRegex = RegExp(
                        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                      );
                      if (!emailRegex.hasMatch(value.trim())) {
                        return '유효한 이메일 형식이 아닙니다';
                      }
                      if (value.trim() == currentEmail) {
                        return '현재 이메일과 다른 이메일을 입력해주세요';
                      }
                      return null;
                    },
                    enabled: !viewModel.isLoading,
                  ),

                  const SizedBox(height: 8),

                  // 안내 메시지 (배경색 제거, 색상 outline으로 변경)
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.outline,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '새 이메일로 인증 링크가 발송됩니다.\n'
                            '이메일의 링크를 클릭하여 변경을 완료해주세요.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                              fontFamily: AppConstants.fontFamilySmall,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 변경 버튼
                  ElevatedButton(
                    onPressed: viewModel.isLoading ? null : _changeEmail,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: viewModel.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            '이메일 변경',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: AppConstants.fontFamilySmall,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
