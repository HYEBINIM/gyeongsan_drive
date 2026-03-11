// lib/models/event.dart
class Event {
  final String contentId;
  final String title;
  final String addr1;
  final String addr2;
  final String mapX;
  final String mapY;
  final String firstImage;
  final String tel;
  final String areaCode;
  final String sigunguCode;
  final String? eventStartDate;  // 새로 추가
  final String? eventEndDate;    // 새로 추가
  final String? progressType;    // 새로 추가
  final String? festivalType;    // 새로 추가

  Event({
    required this.contentId,
    required this.title,
    required this.addr1,
    required this.addr2,
    required this.mapX,
    required this.mapY,
    required this.firstImage,
    required this.tel,
    required this.areaCode,
    required this.sigunguCode,
    this.eventStartDate,
    this.eventEndDate,
    this.progressType,
    this.festivalType,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      contentId: json['contentid'] as String? ?? '',
      title: json['title'] as String? ?? '제목 없음',
      addr1: json['addr1'] as String? ?? '',
      addr2: json['addr2'] as String? ?? '',
      mapX: json['mapx'] as String? ?? '',
      mapY: json['mapy'] as String? ?? '',
      firstImage: json['firstimage'] as String? ?? '',
      tel: json['tel'] as String? ?? '',
      areaCode: json['areacode'] as String? ?? '',
      sigunguCode: json['sigungucode'] as String? ?? '',
      eventStartDate: json['eventstartdate'] as String?,
      eventEndDate: json['eventenddate'] as String?,
      progressType: json['progresstype'] as String?,
      festivalType: json['festivaltype'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contentid': contentId,
      'title': title,
      'addr1': addr1,
      'addr2': addr2,
      'mapx': mapX,
      'mapy': mapY,
      'firstimage': firstImage,
      'tel': tel,
      'areacode': areaCode,
      'sigungucode': sigunguCode,
      'eventstartdate': eventStartDate,
      'eventenddate': eventEndDate,
      'progresstype': progressType,
      'festivaltype': festivalType,
    };
  }
}