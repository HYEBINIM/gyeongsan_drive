import 'package:cloud_firestore/cloud_firestore.dart';

/// 문의 상태
enum InquiryStatus {
  pending('대기중'),
  answered('답변완료');

  final String displayName;
  const InquiryStatus(this.displayName);
}

/// 문의 모델
class Inquiry {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final String title;
  final String content;
  final InquiryStatus status;
  final DateTime createdAt;
  final String? answer;
  final DateTime? answeredAt;

  Inquiry({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.title,
    required this.content,
    required this.status,
    required this.createdAt,
    this.answer,
    this.answeredAt,
  });

  /// Firestore 문서에서 Inquiry 객체 생성
  factory Inquiry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Inquiry(
      id: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      status: InquiryStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => InquiryStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      answer: data['answer'],
      answeredAt: data['answeredAt'] != null
          ? (data['answeredAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Inquiry 객체를 Firestore 문서로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'title': title,
      'content': content,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (answer != null) 'answer': answer,
      if (answeredAt != null) 'answeredAt': Timestamp.fromDate(answeredAt!),
    };
  }

  /// copyWith 메서드
  Inquiry copyWith({
    String? id,
    String? userId,
    String? userEmail,
    String? userName,
    String? title,
    String? content,
    InquiryStatus? status,
    DateTime? createdAt,
    String? answer,
    DateTime? answeredAt,
  }) {
    return Inquiry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      title: title ?? this.title,
      content: content ?? this.content,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      answer: answer ?? this.answer,
      answeredAt: answeredAt ?? this.answeredAt,
    );
  }
}
