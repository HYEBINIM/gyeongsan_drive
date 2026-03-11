import 'package:flutter/material.dart';
import '../../models/inquiry/inquiry.dart';
import '../../services/inquiry/firestore_inquiry_service.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/snackbar_utils.dart';

/// 문의 작성 화면
class InquiryCreateScreen extends StatefulWidget {
  const InquiryCreateScreen({super.key});

  @override
  State<InquiryCreateScreen> createState() => _InquiryCreateScreenState();
}

class _InquiryCreateScreenState extends State<InquiryCreateScreen> {
  final FirestoreInquiryService _inquiryService = FirestoreInquiryService();
  final FirebaseAuthService _authService = FirebaseAuthService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// 문의 작성
  Future<void> _submitInquiry() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      SnackBarUtils.showWarning(context, '로그인이 필요합니다');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final inquiry = Inquiry(
        id: '', // Firestore가 자동 생성
        userId: currentUser.uid,
        userEmail: currentUser.email ?? '',
        userName: currentUser.displayName ?? '사용자',
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        status: InquiryStatus.pending,
        createdAt: DateTime.now(),
      );

      await _inquiryService.createInquiry(inquiry);

      if (mounted) {
        SnackBarUtils.showSuccess(context, '문의가 접수되었습니다');
        Navigator.pop(context); // 목록 화면으로 돌아가기
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, '오류: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문의 작성'), centerTitle: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 안내 메시지
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '문의 내용을 상세히 작성해주시면\n더 정확한 답변을 받으실 수 있습니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontFamily: AppConstants.fontFamilySmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 제목
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                hintText: '문의 제목을 입력하세요',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '제목을 입력해주세요';
                }
                if (value.trim().length < 5) {
                  return '제목은 최소 5자 이상 입력해주세요';
                }
                return null;
              },
              enabled: !_isLoading,
              maxLength: 100,
            ),

            const SizedBox(height: 16),

            // 내용
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: '내용',
                hintText: '문의 내용을 상세히 입력하세요',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              maxLines: 10,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '내용을 입력해주세요';
                }
                if (value.trim().length < 10) {
                  return '내용은 최소 10자 이상 입력해주세요';
                }
                return null;
              },
              enabled: !_isLoading,
              maxLength: 1000,
            ),

            const SizedBox(height: 24),

            // 제출 버튼
            ElevatedButton(
              onPressed: _isLoading ? null : _submitInquiry,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      '문의 접수',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: AppConstants.fontFamilySmall,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
