import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/announcement/announcement.dart';
import '../../services/announcement/firestore_announcement_service.dart';
import '../../utils/constants.dart';

/// 공지사항 상세 화면
class AnnouncementDetailScreen extends StatelessWidget {
  /// 한국어 주석: 이미 로딩된 공지 객체 (목록 화면에서 진입 시 사용)
  final Announcement? announcement;

  /// 한국어 주석: 딥링크 등으로 전달된 공지 ID (알림에서 진입 시 사용)
  final String? announcementId;

  const AnnouncementDetailScreen({
    super.key,
    this.announcement,
    this.announcementId,
  }) : assert(
         announcement != null || announcementId != null,
         'announcement 또는 announcementId 중 하나는 필수입니다.',
       );

  static final _dateFormat = DateFormat('yyyy년 MM월 dd일 HH:mm');

  @override
  Widget build(BuildContext context) {
    // 한국어 주석: 이미 공지 객체가 있으면 그대로 사용
    if (announcement != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('공지사항'), centerTitle: true),
        body: _buildAnnouncementDetail(context, announcement!),
      );
    }

    // 한국어 주석: 공지 ID만 있는 경우 Firestore에서 조회 후 렌더링
    final service = FirestoreAnnouncementService();
    return Scaffold(
      appBar: AppBar(title: const Text('공지사항'), centerTitle: true),
      body: FutureBuilder<Announcement?>(
        future: service.getAnnouncementById(announcementId!),
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

          final loaded = snapshot.data;

          if (loaded == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 48,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '공지사항을 찾을 수 없습니다',
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

          return _buildAnnouncementDetail(context, loaded);
        },
      ),
    );
  }

  /// 공지사항 상세 내용 위젯
  Widget _buildAnnouncementDetail(
    BuildContext context,
    Announcement announcement,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 배지 영역 (중요, 카테고리)
          if (announcement.isImportant || announcement.category != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (announcement.isImportant)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.campaign,
                          size: 16,
                          color: Theme.of(context).colorScheme.onError,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '중요 공지',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onError,
                            fontFamily: AppConstants.fontFamilySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (announcement.category != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      announcement.category!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontFamily: AppConstants.fontFamilySmall,
                      ),
                    ),
                  ),
              ],
            ),

          if (announcement.isImportant || announcement.category != null)
            const SizedBox(height: 16),

          // 제목
          Text(
            announcement.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: AppConstants.fontFamilyBig,
            ),
          ),

          const SizedBox(height: 12),

          // 날짜
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Text(
                _dateFormat.format(announcement.createdAt),
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

          // 내용
          Text(
            announcement.content,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
