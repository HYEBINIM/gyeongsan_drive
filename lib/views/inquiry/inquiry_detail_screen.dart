import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/inquiry/inquiry.dart';
import '../../services/inquiry/firestore_inquiry_service.dart';
import '../../utils/constants.dart';
import '../../utils/snackbar_utils.dart';

/// 문의 상세 화면
class InquiryDetailScreen extends StatefulWidget {
  final String inquiryId;

  const InquiryDetailScreen({super.key, required this.inquiryId});

  @override
  State<InquiryDetailScreen> createState() => _InquiryDetailScreenState();
}

class _InquiryDetailScreenState extends State<InquiryDetailScreen> {
  final FirestoreInquiryService _inquiryService = FirestoreInquiryService();
  bool _isDeleting = false;

  /// 문의 삭제
  Future<void> _deleteInquiry(Inquiry inquiry) async {
    // 답변 완료된 문의는 삭제 불가
    if (inquiry.status == InquiryStatus.answered) {
      SnackBarUtils.showWarning(context, '답변이 완료된 문의는 삭제할 수 없습니다');
      return;
    }

    // 삭제 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('문의 삭제'),
        content: const Text('이 문의를 삭제하시겠습니까?'),
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

    setState(() {
      _isDeleting = true;
    });

    try {
      await _inquiryService.deleteInquiry(widget.inquiryId);

      if (mounted) {
        SnackBarUtils.showSuccess(context, '문의가 삭제되었습니다');
        Navigator.pop(context); // 목록 화면으로 돌아가기
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, '오류: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문의 상세'), centerTitle: true),
      body: FutureBuilder<Inquiry?>(
        future: _inquiryService.getInquiryById(widget.inquiryId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '오류가 발생했습니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.error,
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                ],
              ),
            );
          }

          final inquiry = snapshot.data;

          if (inquiry == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '문의를 찾을 수 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                ],
              ),
            );
          }

          return _buildInquiryDetail(inquiry);
        },
      ),
    );
  }

  /// 문의 상세 내용 위젯
  Widget _buildInquiryDetail(Inquiry inquiry) {
    final dateFormat = DateFormat('yyyy년 MM월 dd일 HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상태 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: inquiry.status == InquiryStatus.answered
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  inquiry.status == InquiryStatus.answered
                      ? Icons.check_circle
                      : Icons.access_time,
                  size: 16,
                  color: inquiry.status == InquiryStatus.answered
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 4),
                Text(
                  inquiry.status.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: inquiry.status == InquiryStatus.answered
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 제목
          Text(
            inquiry.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: AppConstants.fontFamilyBig,
            ),
          ),

          const SizedBox(height: 12),

          // 작성 정보
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Text(
                inquiry.userName,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.access_time,
                size: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Text(
                dateFormat.format(inquiry.createdAt),
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 구분선
          Divider(
            thickness: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),

          const SizedBox(height: 24),

          // 문의 내용 제목
          Text(
            '문의 내용',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),

          const SizedBox(height: 12),

          // 문의 내용
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              inquiry.content,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // 답변 영역
          if (inquiry.status == InquiryStatus.answered &&
              inquiry.answer != null) ...[
            Text(
              '답변',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (inquiry.answeredAt != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateFormat.format(inquiry.answeredAt!),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withValues(alpha: 0.6),
                              fontFamily: AppConstants.fontFamilySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    inquiry.answer!,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // 답변 대기중 메시지
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '답변 대기중입니다.\n빠른 시일 내에 답변 드리겠습니다.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                        fontFamily: AppConstants.fontFamilySmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 삭제 버튼 (답변 전에만)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isDeleting ? null : () => _deleteInquiry(inquiry),
                icon: _isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: const Text(
                  '문의 삭제',
                  style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
