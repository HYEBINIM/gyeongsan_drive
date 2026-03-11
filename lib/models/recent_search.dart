/// 최근 검색 기록 모델
class RecentSearch {
  /// 검색어
  final String query;

  /// 검색 시간 (millisecondsSinceEpoch)
  final int timestamp;

  const RecentSearch({required this.query, required this.timestamp});

  /// JSON에서 역직렬화
  factory RecentSearch.fromJson(Map<String, dynamic> json) {
    return RecentSearch(
      query: json['query'] as String? ?? '',
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }

  /// JSON으로 직렬화
  Map<String, dynamic> toJson() {
    return {'query': query, 'timestamp': timestamp};
  }

  /// 날짜 포맷 (MM.dd. 형식)
  String get formattedDate {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month.$day.';
  }

  @override
  String toString() {
    return 'RecentSearch(query: $query, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecentSearch &&
        other.query == query &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(query, timestamp);
}
