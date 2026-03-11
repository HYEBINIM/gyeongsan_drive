//lib/fun/current_location_tab.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; 
import '../services/api_service.dart';
import '../models/place.dart';
import 'top_100_list_screen.dart'; 
import '../models/event.dart';
import 'place_detail_screen.dart';
import 'search_screen.dart';

/// 현위치에서 떠나기 탭
class CurrentLocationTab extends StatefulWidget {
  const CurrentLocationTab({super.key});

  @override
  State<CurrentLocationTab> createState() => _CurrentLocationTabState();
}

class _CurrentLocationTabState extends State<CurrentLocationTab> {
  final ApiService _apiService = ApiService();
  
  // 디자인 상수 정의 - bus_tab.dart 블랙 테마 스타일
  static const Color _background = Color(0xFF000000);
  static const Color _surface = Color(0xFF1C1C1E);
  static const Color _surfaceVariant = Color(0xFF2C2C2E);
  static const Color _surfaceElevated = Color(0xFF3A3A3C);
  
  static const Color _primary = Color(0xFF00C73C);
  static const Color _primaryDark = Color(0xFF00A030);
  static const Color _primaryLight = Color(0xFF00E047);
  
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFAAAAAA);
  static const Color _textDisabled = Color(0xFF666666);
  
  static const Color _divider = Color(0xFF2C2C2E);
  static const Color _border = Color(0xFF3A3A3C);
  
  static const Color _error = Color(0xFFFF453A);
  static const Color _warning = Color(0xFFFFD60A);
  static const Color _success = Color(0xFF30D158);
  
  static const double _largeBorderRadius = 12.0;
  static const double _mediumBorderRadius = 8.0;
  static const double _spacing = 24.0;
  static const double _mediumSpacing = 16.0;
  static const double _smallSpacing = 8.0;
  
  List<Place> _hotplaces = [];
  List<Place> _nearbyPlaces = [];
  List<Event> _events = [];
  
  bool _isLoading = true;
  String _errorMessage = '';  // 변수명 변경: _error -> _errorMessage
  double _currentLat = 35.8722; 
  double _currentLon = 128.6025; 
  String _currentLocationName = '대구';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<String> _determinePositionAndReverseGeocode() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('위치 서비스가 비활성화되어 있습니다.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('위치 권한이 거부되었습니다. 설정을 확인해 주세요.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error('위치 권한이 영구적으로 거부되었습니다. 앱 설정에서 권한을 변경해 주세요.');
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    
    _currentLat = position.latitude;
    _currentLon = position.longitude;

    return await _apiService.reverseGeocode(
        lat: _currentLat, lon: _currentLon);
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    String locationName;
    try {
      locationName = await _determinePositionAndReverseGeocode();
      _currentLocationName = locationName; 
      
      final hotplaces = await _apiService.fetchHotplaces(locationName: _currentLocationName);
      final nearbyPlaces = await _apiService.fetchNearbyPlaces(
          lat: _currentLat, lon: _currentLon);
      final events = await _apiService.fetchEvents(
          lat: _currentLat, lon: _currentLon);

      setState(() {
        _hotplaces = hotplaces;
        _nearbyPlaces = nearbyPlaces;
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        String errorMessage = e.toString().contains('위치') || e.toString().contains('네이버') 
            ? e.toString().replaceFirst('Exception: ', '') 
            : '데이터 로드 실패: ${e.toString()}';
        _errorMessage = errorMessage;
        _isLoading = false;
      });
      print('Fetching data failed: $e');
    }
  }

  /// 이벤트 날짜 문자열을 DateTime으로 변환 (YYYYMMDD 형식)
  DateTime? _parseEventDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    
    try {
      dateStr = dateStr.trim();
      if (dateStr.length >= 8) {
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        return DateTime(year, month, day);
      }
    } catch (e) {
      print('날짜 파싱 오류: $dateStr - $e');
    }
    return null;
  }

  /// 이벤트 상태 판단 (표시용)
  String _getEventStatusLabel(Event event) {
    if (event.eventStartDate == null || 
        event.eventEndDate == null ||
        event.eventStartDate!.isEmpty || 
        event.eventEndDate!.isEmpty) {
      return '';
    }

    final now = DateTime.now();
    final startDate = _parseEventDate(event.eventStartDate);
    final endDate = _parseEventDate(event.eventEndDate);

    if (startDate == null || endDate == null) return '';

    if (now.isAfter(endDate)) {
      return '종료';
    } else if (now.isBefore(startDate)) {
      return '예정';
    } else {
      return '진행중';
    }
  }

  /// 이벤트 상태별 색상
  Color _getEventStatusColor(String status) {
    switch (status) {
      case '종료':
        return _textDisabled;
      case '진행중':
        return _primary;
      case '예정':
        return _warning;
      default:
        return _textSecondary;
    }
  }

  /// Place type을 텍스트로 변환
  String _getPlaceTypeText(int type) {
    switch (type) {
      case 3:
        return '화장실';
      case 4:
        return '주차장';
      case 5:
        return '드라이브 스루';
      case 6:
        return '음식점';
      default:
        return '기타';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: _background,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_primary),
            strokeWidth: 3.0,
          ),
        ),
      );
    }
    
    if (_errorMessage.isNotEmpty) {
      return Container(
        color: _background,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: _textSecondary),
                const SizedBox(height: _mediumSpacing),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textPrimary, 
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: _spacing),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _fetchData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_mediumBorderRadius),
                      ),
                    ),
                    child: const Text(
                      '다시 시도',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: _background,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            
            // 헤더 - 위치 정보
            _buildLocationHeader(),
            const SizedBox(height: _mediumSpacing),

            // 1. 인기 장소 TOP
            _buildHotplacesSection(),
            const SizedBox(height: _mediumSpacing), 

            // 2. 내 주변 인기 장소
            _buildNearbyPlacesSection(),
            const SizedBox(height: _mediumSpacing), 

            // 3. 문화 행사 정보
            _buildEventsSection(),
            const SizedBox(height: _spacing), 
          ],
        ),
      ),
    );
  }

  // 검색바
  Widget _buildLocationHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(_largeBorderRadius),
          border: Border.all(
            color: _border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          onTap: () {
            // 검색 화면으로 이동 (현재 위치 전달)
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SearchScreen(
                  currentLat: _currentLat,
                  currentLon: _currentLon,
                ),
              ),
            );
          },
          readOnly: true,
          style: const TextStyle(color: _textPrimary),
          decoration: InputDecoration(
            hintText: '가고 싶은 곳을 검색해 보세요',
            hintStyle: TextStyle(
              color: _textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: _textSecondary,
              size: 22,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_largeBorderRadius),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_largeBorderRadius),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_largeBorderRadius),
              borderSide: BorderSide(
                color: _primary.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  // 인기 장소 섹션
  Widget _buildHotplacesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'HOT 플레이스',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => _navigateToTop100List(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '전체보기',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: _primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildHotplacesList(),
      ],
    );
  }

  // 인기 장소 리스트
  Widget _buildHotplacesList() {
    if (_hotplaces.isEmpty) {
      return _buildEmptyState('인기 장소 데이터가 없습니다.', Icons.trending_up);
    }

    final int displayCount = _hotplaces.length.clamp(0, 5);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(_largeBorderRadius),
        border: Border.all(
          color: _border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(displayCount, (index) {
          final place = _hotplaces[index];
          final bool isLast = index == displayCount - 1;
          
          return Column(
            children: [
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlaceDetailScreen(place: place),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(_largeBorderRadius),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 순위
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: index < 3 
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    _primary,
                                    _primaryDark,
                                  ],
                                )
                              : null,
                          color: index >= 3 ? _surfaceVariant : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: index < 3 ? Colors.white : _textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // 장소 정보
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: _textPrimary,
                              ),
                            ),
                            if (place.hashtags.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                place.hashtags.take(2).join(' '),
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      Icon(
                        Icons.chevron_right,
                        color: _textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 68),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: _divider,
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  // 내 주변 인기 장소 섹션
  Widget _buildNearbyPlacesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Text(
            '내 주변 인기 장소',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildNearbyPlacesList(),
      ],
    );
  }

  // 내 주변 인기 장소 리스트 (가로 스크롤)
  Widget _buildNearbyPlacesList() {
    if (_nearbyPlaces.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildEmptyState('주변 인기 장소 데이터가 없습니다.', Icons.location_off),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _nearbyPlaces.length.clamp(0, 10),
        itemBuilder: (context, index) {
          final place = _nearbyPlaces[index];
          final String distanceText = place.hashtags.isNotEmpty 
              ? place.hashtags.first 
              : '거리 미정';
          
          return Container(
            width: 160,
            margin: EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(_largeBorderRadius),
              border: Border.all(
                color: _border,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlaceDetailScreen(place: place),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(_largeBorderRadius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 - 이미지 영역
                  Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.15),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(_largeBorderRadius),
                        topRight: Radius.circular(_largeBorderRadius),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // 순위 뱃지
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: index < 3 
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        _primary,
                                        _primaryDark,
                                      ],
                                    )
                                  : null,
                              color: index >= 3 ? _textSecondary : null,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${index + 1}위',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        // 중앙 아이콘
                        Center(
                          child: Icon(
                            Icons.place,
                            size: 32,
                            color: _primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 하단 - 정보 영역
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 장소명
                          Text(
                            place.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: _textPrimary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          
                          // 타입 (type 컬럼 기반 텍스트)
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 12,
                                color: _textSecondary,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  _getPlaceTypeText(place.type),
                                  style: TextStyle(
                                    color: _textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          
                          const Spacer(),
                          
                          // 하단 - 거리 정보
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _primary.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.navigation,
                                  size: 10,
                                  color: _primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  distanceText,
                                  style: TextStyle(
                                    color: _primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 문화 행사 섹션
  Widget _buildEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Text(
            '문화 행사',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildEventsList(),
      ],
    );
  }

  // 문화 행사 목록
  Widget _buildEventsList() {
    if (_events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildEmptyState('문화 행사 정보가 없습니다.', Icons.event_busy),
      );
    }

    final int displayCount = _events.length.clamp(0, 10);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(_largeBorderRadius),
          border: Border.all(
            color: _border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: List.generate(displayCount, (index) {
            final event = _events[index];
            final bool isLast = index == displayCount - 1;
            
            String address = event.addr1.isNotEmpty ? event.addr1 : event.addr2;
            if (address.isEmpty) address = '장소 미정';
            
            String dateText = '';
            if (event.eventStartDate != null && 
                event.eventEndDate != null &&
                event.eventStartDate!.isNotEmpty &&
                event.eventEndDate!.isNotEmpty) {
              final startDate = _parseEventDate(event.eventStartDate);
              final endDate = _parseEventDate(event.eventEndDate);
              if (startDate != null && endDate != null) {
                dateText = '${startDate.month}.${startDate.day} ~ ${endDate.month}.${endDate.day}';
              }
            }
            
            final statusLabel = _getEventStatusLabel(event);
            final statusColor = _getEventStatusColor(statusLabel);
            
            return Column(
              children: [
                InkWell(
                  onTap: () => print('${event.title} 상세 정보 보기'),
                  borderRadius: BorderRadius.circular(_largeBorderRadius),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 아이콘
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.event,
                            color: Colors.orange.shade400,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // 행사 정보
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 제목과 상태 뱃지
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      event.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: _textPrimary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (statusLabel.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: statusColor.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              
                              // 날짜
                              if (dateText.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 12,
                                      color: _textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      dateText,
                                      style: TextStyle(
                                        color: _textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                              ],
                              
                              // 주소
                              Row(
                                children: [
                                  Icon(
                                    Icons.place,
                                    size: 12,
                                    color: _textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      address,
                                      style: TextStyle(
                                        color: _textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        Icon(
                          Icons.chevron_right,
                          color: _textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.only(left: 68),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: _divider,
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // 빈 상태 위젯
  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(_largeBorderRadius),
        border: Border.all(
          color: _border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: _textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // Top 100 목록 화면으로 이동
  Future<void> _navigateToTop100List(BuildContext context) async {
    // 전체 100개 목록을 가져옴
    final allHotplaces = await _apiService.fetchHotplacesList(
      locationName: _currentLocationName,
      existingPlaces: _hotplaces,
    );
    
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Top100ListScreen(
          allHotplaces: allHotplaces,
        ),
      ),
    );
  }
}