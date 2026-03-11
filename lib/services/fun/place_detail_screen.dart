// lib/fun/place_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../models/place.dart';
import '../models/bus_stop.dart';
import '../models/bus_route.dart';
import '../services/api_service.dart';
import 'navigation_screen.dart';
import 'bus_navigation_screen.dart';

/// 장소 상세 정보 및 네이버 지도 화면
class PlaceDetailScreen extends StatefulWidget {
  final Place place;

  const PlaceDetailScreen({
    super.key,
    required this.place,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  NaverMapController? _mapController;
  final DraggableScrollableController _sheetController = 
      DraggableScrollableController();
  final ApiService _apiService = ApiService();
  
  NLatLng? _currentPosition;
  List<BusStop> _nearbyStops = [];
  BusRoute? _nearestRoute;
  BusStop? _nearestStop;
  bool _isLoadingBusInfo = false;
  
  // 디자인 상수 - bus_tab.dart와 동일
  static const Color _background = Color(0xFF000000);
  static const Color _surface = Color(0xFF1C1C1E);
  static const Color _surfaceVariant = Color(0xFF2C2C2E);
  static const Color _primary = Color(0xFF00C73C);
  static const Color _primaryDark = Color(0xFF00A030);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFAAAAAA);
  static const Color _border = Color(0xFF3A3A3C);
  
  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }
  
  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = NLatLng(position.latitude, position.longitude);
      });
      
      // 근처 버스 정류장 로드
      await _loadNearbyBusStops(position.latitude, position.longitude);
    } catch (e) {
      print('위치 초기화 오류: $e');
    }
  }
  
  Future<void> _loadNearbyBusStops(double lat, double lon) async {
    setState(() => _isLoadingBusInfo = true);
    
    try {
      final stops = await _apiService.fetchNearbyBusStops(
        lat: lat,
        lon: lon,
        radiusKm: 1,
      );
      
      if (stops.isNotEmpty) {
        // 가장 가까운 정류장 찾기
        final nearestStop = stops.first;
        
        // 해당 정류장의 노선 조회
        final routes = await _apiService.fetchBusRoutesAtStop(
          stopCode: nearestStop.stopCode,
          cityName: nearestStop.cityName ?? '경산',
        );
        
        if (mounted) {
          setState(() {
            _nearbyStops = stops;
            _nearestStop = nearestStop;
            _nearestRoute = routes.isNotEmpty ? routes.first : null;
            _isLoadingBusInfo = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingBusInfo = false);
        }
      }
    } catch (e) {
      print('버스 정보 로드 오류: $e');
      if (mounted) {
        setState(() => _isLoadingBusInfo = false);
      }
    }
  }

  /// location 필드에서 위도, 경도 파싱 ("위도,경도" 형식)
  (double?, double?) _parseLocation() {
    try {
      final parts = widget.place.location.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        
        if (lat != null && lng != null) {
          print('좌표 파싱 성공: 위도=$lat, 경도=$lng');
          return (lat, lng);
        }
      }
      print('좌표 파싱 실패: location=${widget.place.location}');
    } catch (e) {
      print('좌표 파싱 오류: $e');
    }
    return (null, null);
  }

  /// 안내 시작 - bus_tab.dart와 동일한 다이얼로그
  void _startNavigation() async {
    final (lat, lng) = _parseLocation();
    if (lat == null || lng == null) {
      _showErrorSnackBar('목적지 위치 정보를 찾을 수 없습니다.');
      return;
    }
    
    if (_currentPosition == null) {
      _showErrorSnackBar('현재 위치를 찾을 수 없습니다.');
      return;
    }

    final destination = NLatLng(lat, lng);
    final destinationName = widget.place.name;
    
    // 길안내 방법 선택 다이얼로그
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '길안내 방법 선택',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 버스 안내 버튼
            if (_nearestRoute != null && _nearestStop != null)
              _buildNavigationOption(
                icon: Icons.directions_bus,
                title: '버스로 안내',
                subtitle: '${_nearestRoute!.routeName}번 이용',
                color: _primary,
                onTap: () {
                  Navigator.pop(context);
                  _startBusNavigation(destinationName, destination);
                },
              ),
            if (_nearestRoute != null && _nearestStop != null)
              const SizedBox(height: 12),
            // 자동차 안내 버튼
            _buildNavigationOption(
              icon: Icons.directions_car,
              title: '자동차로 안내',
              subtitle: '최적 경로 안내',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _startCarNavigation(destinationName, destination);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNavigationOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: _textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 버스 길안내 시작
  void _startBusNavigation(String destinationName, NLatLng destination) {
    if (_nearestRoute == null || _nearestStop == null) return;
    
    print('🚌 버스 길안내 시작: $destinationName');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusNavigationScreen(
          destinationName: destinationName,
          destinationLat: destination.latitude,
          destinationLng: destination.longitude,
          selectedRoute: _nearestRoute!,
          nearestStop: _nearestStop!,
        ),
      ),
    );
  }
  
  // 자동차 길안내 시작
  void _startCarNavigation(String destinationName, NLatLng destination) {
    print('🚗 자동차 길안내 시작: $destinationName');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationScreen(
          destinationName: destinationName,
          destinationLat: destination.latitude,
          destinationLng: destination.longitude,
        ),
      ),
    );
  }

  /// 전화 걸기
  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showErrorSnackBar('전화를 걸 수 없습니다.');
    }
  }

  /// 에러 스낵바 표시
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (lat, lng) = _parseLocation();
    
    if (lat == null || lng == null) {
      return Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: Text(widget.place.name),
          backgroundColor: _surface,
          foregroundColor: _textPrimary,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_off,
                  size: 64,
                  color: _textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  '위치 정보를 찾을 수 없습니다.',
                  style: TextStyle(
                    fontSize: 16,
                    color: _textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          // 네이버 지도
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(lat, lng),
                zoom: 15,
                bearing: 0,
                tilt: 0,
              ),
              mapType: NMapType.basic,
              activeLayerGroups: [NLayerGroup.building, NLayerGroup.transit],
              locale: const Locale('ko'),
            ),
            onMapReady: (controller) {
              _mapController = controller;
              
              final marker = NMarker(
                id: 'place_marker',
                position: NLatLng(lat, lng),
              );
              
              final infoWindow = NInfoWindow.onMarker(
                id: marker.info.id,
                text: widget.place.name,
              );
              
              marker.setOnTapListener((NMarker marker) {
                _sheetController.animateTo(
                  0.6,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              });
              
              controller.addOverlay(marker);
              marker.openInfoWindow(infoWindow);
            },
          ),

          // 상단 앱바
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _border,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                      color: _textPrimary,
                    ),
                    Expanded(
                      child: Text(
                        widget.place.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),

          // 하단 정보 패널
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.35,
            minChildSize: 0.2,
            maxChildSize: 0.8,
            snap: true,
            snapSizes: const [0.35, 0.6],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border.all(
                    color: _border,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // 드래그 핸들
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 장소명
                          Text(
                            widget.place.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 카테고리
                          if (widget.place.category.isNotEmpty) 
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.restaurant,
                                    size: 14,
                                    color: Colors.orange.shade400,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.place.category,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 20),

                          // 위치 정보
                          _buildInfoRow(
                            Icons.location_on,
                            '주소',
                            widget.place.content.isNotEmpty 
                                ? widget.place.content 
                                : widget.place.local,
                          ),
                          
                          const SizedBox(height: 20),

                          // 안내 시작 버튼 (주소 아래로 이동)
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: _primary.withOpacity(0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _startNavigation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.navigation, size: 22),
                                    const SizedBox(width: 10),
                                    Text(
                                      _isLoadingBusInfo ? '로딩중...' : '안내 시작',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 상세 정보 섹션
                          Text(
                            '상세 정보',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 검색 횟수
                          _buildDetailItem(
                            icon: Icons.trending_up,
                            title: '인기도',
                            value: '검색 ${widget.place.searchNum}회',
                            iconColor: Colors.red.shade400,
                          ),

                          const SizedBox(height: 12),

                          // ID 정보
                          _buildDetailItem(
                            icon: Icons.tag,
                            title: 'ID',
                            value: '#${widget.place.id}',
                            iconColor: _primary,
                          ),

                          // 전화번호
                          if (widget.place.telNumber.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => _makePhoneCall(widget.place.telNumber),
                              child: _buildDetailItem(
                                icon: Icons.phone,
                                title: '전화번호',
                                value: widget.place.telNumber,
                                iconColor: Colors.green.shade400,
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // 지도에서 크게 보기 버튼
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _sheetController.animateTo(
                                  0.2,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              icon: const Icon(Icons.map, size: 18),
                              label: const Text('지도 크게 보기'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _primary,
                                side: BorderSide(color: _primary, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 정보 행 위젯
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: _primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 상세 정보 아이템
  Widget _buildDetailItem({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}