import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/profile/change_password_viewmodel.dart';
import '../../utils/constants.dart';
import '../../utils/snackbar_utils.dart';

/// 비밀번호 변경 화면
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;

  // 비밀번호 검증 상태
  final Map<String, bool> _validationStatus = {
    'length': false,
    'letter': false,
    'number': false,
    'special': false,
    'different': false,
  };

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  /// 실시간 비밀번호 검증
  void _validatePassword(String password) {
    setState(() {
      _validationStatus['length'] = password.length >= 8;
      _validationStatus['letter'] = password.contains(RegExp(r'[a-zA-Z]'));
      _validationStatus['number'] = password.contains(RegExp(r'[0-9]'));
      _validationStatus['special'] = password.contains(
        RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
      );
      _validationStatus['different'] =
          password.isNotEmpty && password != _currentPasswordController.text;
    });
  }

  /// 모든 조건 충족 여부
  bool get _isPasswordValid => _validationStatus.values.every((v) => v);

  /// 비밀번호 변경
  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final viewModel = context.read<ChangePasswordViewModel>();

    // ViewModel을 통해 비밀번호 변경
    final success = await viewModel.changePassword(
      _currentPasswordController.text,
      _newPasswordController.text,
    );

    if (mounted) {
      if (success) {
        SnackBarUtils.showSuccess(context, '비밀번호가 변경되었습니다');
        Navigator.pop(context);
      } else if (viewModel.errorMessage != null) {
        SnackBarUtils.showError(context, viewModel.errorMessage!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChangePasswordViewModel>(
      builder: (context, viewModel, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('비밀번호 변경'), centerTitle: true),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 16),

                  // 현재 비밀번호
                  TextFormField(
                    controller: _currentPasswordController,
                    decoration: InputDecoration(
                      labelText: '현재 비밀번호',
                      hintText: '현재 비밀번호를 입력하세요',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrentPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureCurrentPassword = !_obscureCurrentPassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: _obscureCurrentPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '현재 비밀번호를 입력해주세요';
                      }
                      return null;
                    },
                    enabled: !viewModel.isLoading,
                  ),

                  const SizedBox(height: 16),

                  // 새 비밀번호
                  TextFormField(
                    controller: _newPasswordController,
                    decoration: InputDecoration(
                      labelText: '새 비밀번호',
                      hintText: '새 비밀번호를 입력하세요',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: _obscureNewPassword,
                    onChanged: _validatePassword,
                    enabled: !viewModel.isLoading,
                  ),

                  const SizedBox(height: 16),

                  // 비밀번호 검증 규칙 표시
                  _buildValidationRules(),

                  const SizedBox(height: 24),

                  // 변경 버튼
                  ElevatedButton(
                    onPressed: (viewModel.isLoading || !_isPasswordValid)
                        ? null
                        : _changePassword,
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
                            '비밀번호 변경',
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

  Widget _buildValidationRules() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildValidationItem('8자 이상', _validationStatus['length']!),
          _buildValidationItem('영문 포함', _validationStatus['letter']!),
          _buildValidationItem('숫자 포함', _validationStatus['number']!),
          _buildValidationItem('특수문자 포함', _validationStatus['special']!),
          _buildValidationItem('현재 비밀번호와 다름', _validationStatus['different']!),
        ],
      ),
    );
  }

  Widget _buildValidationItem(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.cancel,
            size: 20,
            color: isValid ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isValid ? Colors.green : Colors.grey,
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
        ],
      ),
    );
  }
}
