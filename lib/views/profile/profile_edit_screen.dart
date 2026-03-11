import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/profile/profile_edit_viewmodel.dart';
import '../../view_models/profile/profile_viewmodel.dart';
import '../../utils/constants.dart';
import '../../utils/snackbar_utils.dart';

/// 프로필 편집 화면
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // 현재 사용자 이름으로 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<ProfileEditViewModel>();
      _nameController.text = viewModel.currentName;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 프로필 업데이트
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final viewModel = context.read<ProfileEditViewModel>();
    final profileViewModel = context.read<ProfileViewModel>();
    final newName = _nameController.text.trim();

    // ViewModel을 통해 프로필 업데이트 (Firebase Auth + Firestore)
    final success = await viewModel.updateProfile(newName);

    if (mounted) {
      if (success) {
        // ProfileViewModel 새로고침 (ProfileScreen 자동 업데이트)
        await profileViewModel.refreshUserInfo();

        if (!mounted) return;

        SnackBarUtils.showSuccess(context, '프로필이 업데이트되었습니다');
        Navigator.pop(context); // 이전 화면으로 돌아가기
      } else if (viewModel.errorMessage != null) {
        SnackBarUtils.showError(context, viewModel.errorMessage!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileEditViewModel>(
      builder: (context, viewModel, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('이름 변경'), centerTitle: true),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 이름 입력 필드
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '이름',
                      hintText: '이름을 입력하세요',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '이름을 입력해주세요';
                      }
                      if (value.trim().length < 2) {
                        return '이름은 최소 2자 이상이어야 합니다';
                      }
                      if (value.trim().length > 50) {
                        return '이름은 최대 50자까지 가능합니다';
                      }
                      return null;
                    },
                    maxLength: 50,
                    enabled: !viewModel.isLoading,
                  ),

                  const SizedBox(height: 24),

                  // 저장 버튼
                  ElevatedButton(
                    onPressed: viewModel.isLoading ? null : _updateProfile,
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
                            '저장',
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
