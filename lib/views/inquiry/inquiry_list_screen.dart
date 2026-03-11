import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/inquiry/inquiry.dart';
import '../../services/inquiry/firestore_inquiry_service.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../routes/app_routes.dart';
import '../../utils/constants.dart';

/// 문의 목록 화면
class InquiryListScreen extends StatefulWidget {
  const InquiryListScreen({super.key});

  @override
  State<InquiryListScreen> createState() => _InquiryListScreenState();
}

class _InquiryListScreenState extends State<InquiryListScreen> {
  final FirestoreInquiryService _inquiryService = FirestoreInquiryService();
  final FirebaseAuthService _authService = FirebaseAuthService();

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid ?? '';

    if (userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('문의하기'), centerTitle: true),
        body: const Center(child: Text('로그인이 필요합니다')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('문의하기'), centerTitle: true),
      body: StreamBuilder<List<Inquiry>>(
        stream: _inquiryService.getUserInquiries(userId),
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

          final inquiries = snapshot.data ?? [];

          if (inquiries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '작성한 문의가 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '우측 하단의 버튼을 눌러 문의를 작성해보세요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: inquiries.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final inquiry = inquiries[index];
              return _buildInquiryItem(inquiry);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.inquiryCreate);
        },
        icon: const Icon(Icons.create),
        label: const Text(
          '문의 작성',
          style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
        ),
      ),
    );
  }

  /// 문의 항목 위젯
  Widget _buildInquiryItem(Inquiry inquiry) {
    final dateFormat = DateFormat('yyyy.MM.dd');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: inquiry.status == InquiryStatus.answered
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          inquiry.status == InquiryStatus.answered
              ? Icons.check_circle
              : Icons.access_time,
          color: inquiry.status == InquiryStatus.answered
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onSurfaceVariant,
          size: 24,
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: inquiry.status == InquiryStatus.answered
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              inquiry.status.displayName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: inquiry.status == InquiryStatus.answered
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              inquiry.title,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: AppConstants.fontFamilySmall,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          dateFormat.format(inquiry.createdAt),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
            fontFamily: AppConstants.fontFamilySmall,
          ),
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.inquiryDetail,
          arguments: inquiry.id,
        );
      },
    );
  }
}
