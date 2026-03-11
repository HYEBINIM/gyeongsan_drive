import 'package:cloud_firestore/cloud_firestore.dart';

/// 공지사항 모델
class Announcement {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final bool isImportant;
  final String? category;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.isImportant = false,
    this.category,
  });

  /// Firestore 문서에서 Announcement 객체 생성
  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Announcement(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isImportant: data['isImportant'] ?? false,
      category: data['category'],
    );
  }

  /// Announcement 객체를 Firestore 문서로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'isImportant': isImportant,
      if (category != null) 'category': category,
    };
  }

  /// copyWith 메서드
  Announcement copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    bool? isImportant,
    String? category,
  }) {
    return Announcement(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isImportant: isImportant ?? this.isImportant,
      category: category ?? this.category,
    );
  }
}
