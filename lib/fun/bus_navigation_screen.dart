// lib/fun/bus_navigation_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../models/bus_stop.dart';
import '../models/bus_route.dart';

/// 버스 전용 내비게이션 화면
class BusNavigationScreen extends StatefulWidget {
  final String destinationName;
  final double destinationLat;
  final double destinationLng;
  final BusRoute selectedRoute;
  final BusStop nearestStop;

  const BusNavigationScreen({
    super.key,
    required this.destinationName,
    required this.destinationLat,
    required this.destinationLng,
    required this.selectedRoute,
    required this.nearestStop,
  });

  @override
  State<BusNavigationScreen> createState() => _BusNavigationScreenState();
}

class _BusNavigationScreenState extends State<BusNavigationScreen> {
  NaverMapController? _mapController;
  final ApiService _apiService = ApiService();
  
  // 디자인 상수
  static const Color _primaryColor = Color(0xFF00C73C);
  static const Color _surfaceColor = Color(0xFF1C1C1E);
  static const Color _textPrimaryColor = Color(0xFFFFFFFF);
  static const Color _textSecondaryColor = Color(0xFFAAAAAA);
  
  // 내비게이션 상태
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  
  // 경로 데이터
  List<BusRouteStop> _routeStops = [];
  BusRouteStop? _destinationStop;
  int? _currentStopIndex;
  List<NLatLng> _realPathCoords = []; // 실제 도로 경로 좌표
  
  // 거리 계산
  int? _distanceToStop; // 현재 위치 → 탑승 정류장
  int? _distanceToDestination; // 하차 정류장 → 목적지
  int? _remainingStops; // 남은 정류장 수
  
  bool _isLoading = true;
  bool _isOnBus = false; // 버스 탑승 여부
  String? _errorMessage;
  
  // 마커
  NMarker? _currentLocationMarker;
  NMarker? _boardingStopMarker;
  NMarker? _alightingStopMarker;
  NMarker? _destinationMarker;
  NPathOverlay? _routePath;

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  /// 내비게이션 초기화
  Future<void> _initializeNavigation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. 현재 위치 가져오기
      final position = await _getCurrentPosition();
      if (position == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = '현재 위치를 가져올 수 없습니다.';
        });
        return;
      }

      setState(() {
        _currentPosition = position;
      });

      // 2. 버스 노선 정류장 정보 가져오기
      await _loadRouteStops();

      // 3. 목적지와 가장 가까운 하차 정류장 찾기
      _findDestinationStop();

      // 4. 거리 계산
      _calculateDistances();

      // 5. 실시간 위치 추적 시작
      _startLocationTracking();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('초기화 오류: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '버스 내비게이션을 시작할 수 없습니다.';
      });
    }
  }

  /// 현재 위치 가져오기
  Future<Position?> _getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackBar('위치 서비스가 비활성화되어 있습니다.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackBar('위치 권한이 거부되었습니다.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar('위치 권한이 영구적으로 거부되었습니다.');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('위치 가져오기 오류: $e');
      return null;
    }
  }

  /// 버스 노선 정류장 로드
  Future<void> _loadRouteStops() async {
    try {
      final stops = await _apiService.fetchBusRouteStops(
        routeId: widget.selectedRoute.routeId,
        cityName: widget.selectedRoute.cityName ?? '경산',
      );

      // 탑승 정류장의 인덱스 찾기 (위치 기반으로 찾기)
      int boardingStopIndex = -1;
      double minDistance = double.infinity;
      
      for (int i = 0; i < stops.length; i++) {
        final distance = Geolocator.distanceBetween(
          stops[i].lat,
          stops[i].lon,
          widget.nearestStop.lat,
          widget.nearestStop.lon,
        );
        
        if (distance < minDistance) {
          minDistance = distance;
          boardingStopIndex = i;
        }
      }

      setState(() {
        _routeStops = stops;
        _currentStopIndex = boardingStopIndex >= 0 ? boardingStopIndex : 0;
      });

      print('✅ 노선 정류장 ${stops.length}개 로드 완료');
      print('탑승 정류장 인덱스: $boardingStopIndex');

      // 실제 도로 경로 생성
      await _generateRealPath();
    } catch (e) {
      print('노선 정류장 로드 오류: $e');
      throw e;
    }
  }

  /// 실제 도로를 따라가는 경로 생성
  Future<void> _generateRealPath() async {
    if (_routeStops.isEmpty) return;
    
    print('🛣️ 실제 도로 경로 생성 시작...');
    
    try {
      // 네이버 길찾기 API로 실제 경로 생성
      final realPathCoords = await _apiService.getBusRouteRealPath(_routeStops);
      
      setState(() {
        _realPathCoords = realPathCoords.map((coord) => 
          NLatLng(coord['lat']!, coord['lng']!)
        ).toList();
      });
      
      print('✅ 실제 도로 경로 생성 완료: ${_realPathCoords.length}개 좌표');
    } catch (e) {
      print('⚠️ 실제 경로 생성 실패, 직선 경로 사용: $e');
      // 실패 시 기존 직선 경로 사용
      setState(() {
        _realPathCoords = _routeStops.map((stop) => 
          NLatLng(stop.lat, stop.lon)
        ).toList();
      });
    }
  }

  /// 목적지와 가장 가까운 하차 정류장 찾기
  void _findDestinationStop() {
    if (_routeStops.isEmpty || _currentStopIndex == null) return;

    double minDistance = double.infinity;
    BusRouteStop? closestStop;
    int closestStopIndex = -1;

    // 탑승 정류장 이후의 정류장들 중에서 목적지와 가장 가까운 정류장 찾기
    for (int i = _currentStopIndex! + 1; i < _routeStops.length; i++) {
      final stop = _routeStops[i];
      final distance = Geolocator.distanceBetween(
        stop.lat,
        stop.lon,
        widget.destinationLat,
        widget.destinationLng,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestStop = stop;
        closestStopIndex = i;
      }
    }

    setState(() {
      _destinationStop = closestStop;
      if (closestStop != null && _currentStopIndex != null) {
        _remainingStops = closestStopIndex - _currentStopIndex!;
      }
    });

    print('✅ 하차 정류장: ${closestStop?.stopName}');
    print('남은 정류장: $_remainingStops개');
  }

  /// 거리 계산
  void _calculateDistances() {
    if (_currentPosition == null) return;

    // 현재 위치 → 탑승 정류장
    _distanceToStop = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      widget.nearestStop.lat,
      widget.nearestStop.lon,
    ).round();

    // 하차 정류장 → 목적지
    if (_destinationStop != null) {
      _distanceToDestination = Geolocator.distanceBetween(
        _destinationStop!.lat,
        _destinationStop!.lon,
        widget.destinationLat,
        widget.destinationLng,
      ).round();
    }

    setState(() {});
  }

  /// 실시간 위치 추적 시작
  void _startLocationTracking() {
    print('=== 버스 위치 추적 시작 ===');
    
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // 10미터마다 업데이트
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _updateCurrentLocation(position);
    });
  }

  /// 현재 위치 업데이트
  Future<void> _updateCurrentLocation(Position position) async {
    setState(() {
      _currentPosition = position;
    });

    // 탑승 정류장까지의 거리 업데이트
    if (!_isOnBus) {
      final distanceToBoarding = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        widget.nearestStop.lat,
        widget.nearestStop.lon,
      ).round();

      setState(() {
        _distanceToStop = distanceToBoarding;
      });

      // 탑승 정류장 근처 도착 (50m 이내)
      if (distanceToBoarding < 50) {
        _showBoardingDialog();
      }
    } else {
      // 버스 탑승 중 - 하차 정류장까지의 거리 확인
      if (_destinationStop != null) {
        final distanceToAlighting = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          _destinationStop!.lat,
          _destinationStop!.lon,
        ).round();

        // 하차 정류장 근처 (100m 이내)
        if (distanceToAlighting < 100) {
          _showAlightingDialog();
        }
      }
    }

    // 현재 위치 마커 업데이트
    if (_mapController != null && _currentLocationMarker != null) {
      _currentLocationMarker!.setPosition(
        NLatLng(position.latitude, position.longitude),
      );

      // 카메라를 현재 위치로 부드럽게 이동
      try {
        final cameraUpdate = NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(position.latitude, position.longitude),
        );
        await _mapController!.updateCamera(cameraUpdate);
      } catch (e) {
        print('카메라 업데이트 오류: $e');
      }
    }
  }

  /// 버스 탑승 안내 다이얼로그
  void _showBoardingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.directions_bus,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '정류장 도착',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimaryColor,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '${widget.nearestStop.stopName}에 도착했습니다.\n${widget.selectedRoute.routeName}번 버스를 탑승하세요.',
          style: const TextStyle(
            fontSize: 15,
            color: _textSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _isOnBus = true;
              });
              Navigator.pop(context);
              _showInfoSnackBar('버스 탑승 모드로 전환되었습니다.');
            },
            child: const Text(
              '탑승 완료',
              style: TextStyle(
                color: _primaryColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 버스 하차 안내 다이얼로그
  void _showAlightingDialog() {
    _positionStream?.cancel();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '하차 안내',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimaryColor,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_destinationStop?.stopName}에서 하차하세요.',
              style: const TextStyle(
                fontSize: 15,
                color: _textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            if (_distanceToDestination != null)
              Text(
                '목적지까지 도보 ${_formatDistance(_distanceToDestination!)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: _textSecondaryColor,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 다이얼로그 닫기
              Navigator.pop(context); // 내비게이션 화면 닫기
            },
            child: const Text(
              '확인',
              style: TextStyle(
                color: _primaryColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 지도에 마커와 경로 그리기
  Future<void> _drawOnMap() async {
    if (_mapController == null || _routeStops.isEmpty) return;

    try {
      // 실제 도로 경로 그리기 (있는 경우) 또는 정류장 연결 경로
      final coords = _realPathCoords.isNotEmpty 
          ? _realPathCoords 
          : _routeStops.map((s) => NLatLng(s.lat, s.lon)).toList();
      
      _routePath = NPathOverlay(
        id: 'bus_route',
        coords: coords,
        width: 8,
        color: _primaryColor,
        outlineColor: Colors.white,
        outlineWidth: 2,
      );
      await _mapController!.addOverlay(_routePath!);

      // 현재 위치 마커
      if (_currentPosition != null) {
        _currentLocationMarker = NMarker(
          id: 'current_location',
          position: NLatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: const NOverlayImage.fromAssetImage('assets/images/marker_current.png'),
          size: const Size(36, 36),
          anchor: const NPoint(0.5, 0.5),
        );
        await _mapController!.addOverlay(_currentLocationMarker!);
      }

      // 탑승 정류장 마커
      _boardingStopMarker = NMarker(
        id: 'boarding_stop',
        position: NLatLng(widget.nearestStop.lat, widget.nearestStop.lon),
        icon: const NOverlayImage.fromAssetImage('assets/images/pin_start.png'),
        size: const Size(40, 56),
        anchor: const NPoint(0.5, 1.0),
      );
      
      _boardingStopMarker!.setCaption(NOverlayCaption(
        text: '${widget.selectedRoute.routeName} 탑승',
        textSize: 12,
        color: _primaryColor,
        haloColor: Colors.white,
      ));
      
      await _mapController!.addOverlay(_boardingStopMarker!);

      // 하차 정류장 마커
      if (_destinationStop != null) {
        _alightingStopMarker = NMarker(
          id: 'alighting_stop',
          position: NLatLng(_destinationStop!.lat, _destinationStop!.lon),
          icon: const NOverlayImage.fromAssetImage('assets/images/marker_stop_selected.png'),
          size: const Size(32, 32),
          anchor: const NPoint(0.5, 0.5),
        );
        
        _alightingStopMarker!.setCaption(NOverlayCaption(
          text: '하차',
          textSize: 12,
          color: Colors.red,
          haloColor: Colors.white,
        ));
        
        await _mapController!.addOverlay(_alightingStopMarker!);
      }

      // 목적지 마커
      _destinationMarker = NMarker(
        id: 'destination',
        position: NLatLng(widget.destinationLat, widget.destinationLng),
        icon: const NOverlayImage.fromAssetImage('assets/images/pin_destination.png'),
        size: const Size(44, 62),
        anchor: const NPoint(0.5, 1.0),
      );
      
      _destinationMarker!.setCaption(NOverlayCaption(
        text: widget.destinationName,
        textSize: 12,
        color: _primaryColor,
        haloColor: Colors.white,
      ));
      
      await _mapController!.addOverlay(_destinationMarker!);

      // 카메라 조정
      _fitCameraToRoute();
    } catch (e) {
      print('지도 그리기 오류: $e');
    }
  }

  /// 카메라를 경로에 맞추기
  Future<void> _fitCameraToRoute() async {
    if (_mapController == null || _routeStops.isEmpty) return;

    try {
      double minLat = _routeStops.first.lat;
      double maxLat = _routeStops.first.lat;
      double minLon = _routeStops.first.lon;
      double maxLon = _routeStops.first.lon;

      for (var stop in _routeStops) {
        minLat = math.min(minLat, stop.lat);
        maxLat = math.max(maxLat, stop.lat);
        minLon = math.min(minLon, stop.lon);
        maxLon = math.max(maxLon, stop.lon);
      }

      // 목적지도 포함
      minLat = math.min(minLat, widget.destinationLat);
      maxLat = math.max(maxLat, widget.destinationLat);
      minLon = math.min(minLon, widget.destinationLng);
      maxLon = math.max(maxLon, widget.destinationLng);

      final bounds = NLatLngBounds(
        southWest: NLatLng(minLat, minLon),
        northEast: NLatLng(maxLat, maxLon),
      );

      final cameraUpdate = NCameraUpdate.fitBounds(
        bounds,
        padding: const EdgeInsets.all(100),
      );
      await _mapController!.updateCamera(cameraUpdate);
    } catch (e) {
      print('카메라 조정 오류: $e');
    }
  }

  /// 거리 포맷
  String _formatDistance(int meters) {
    if (meters < 1000) {
      return '${meters}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  /// 에러 스낵바 표시
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
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
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// 정보 스낵바 표시
  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    
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
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
              SizedBox(height: 16),
              Text(
                '버스 경로를 준비하고 있습니다...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _textPrimaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: _surfaceColor,
          foregroundColor: _textPrimaryColor,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: _textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initializeNavigation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '다시 시도',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 네이버 지도
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: _currentPosition != null
                  ? NCameraPosition(
                      target: NLatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: 15,
                    )
                  : NCameraPosition(
                      target: NLatLng(
                        widget.nearestStop.lat,
                        widget.nearestStop.lon,
                      ),
                      zoom: 15,
                    ),
              mapType: NMapType.basic,
              activeLayerGroups: [NLayerGroup.building, NLayerGroup.transit],
            ),
            onMapReady: (controller) async {
              _mapController = controller;
              await _drawOnMap();
            },
          ),

          // 상단 정보 카드
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 헤더
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _primaryColor,
                                Color(0xFF00A030),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.directions_bus,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.selectedRoute.routeName}번 버스',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.destinationName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _textSecondaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: _textPrimaryColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFF2C2C2E)),
                    const SizedBox(height: 16),
                    
                    // 안내 정보
                    if (!_isOnBus) ...[
                      // 탑승 대기 모드
                      Row(
                        children: [
                          const Icon(
                            Icons.directions_walk,
                            color: _primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '탑승 정류장까지',
                            style: TextStyle(
                              fontSize: 14,
                              color: _textSecondaryColor,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _distanceToStop != null
                                ? _formatDistance(_distanceToStop!)
                                : '계산 중',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.place,
                              color: _textSecondaryColor,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.nearestStop.stopName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _textPrimaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // 버스 탑승 모드
                      Row(
                        children: [
                          const Icon(
                            Icons.bus_alert,
                            color: _primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '남은 정류장',
                            style: TextStyle(
                              fontSize: 14,
                              color: _textSecondaryColor,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _remainingStops != null
                                ? '$_remainingStops개'
                                : '계산 중',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.place,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _destinationStop?.stopName ?? '하차 정류장',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _textPrimaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_distanceToDestination != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '도보 ${_formatDistance(_distanceToDestination!)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textSecondaryColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 하단 현재 위치 버튼
          Positioned(
            bottom: 20,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(28),
                child: InkWell(
                  onTap: () async {
                    if (_mapController != null && _currentPosition != null) {
                      try {
                        final cameraUpdate = NCameraUpdate.scrollAndZoomTo(
                          target: NLatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          zoom: 16,
                        );
                        await _mapController!.updateCamera(cameraUpdate);
                      } catch (e) {
                        print('카메라 이동 오류: $e');
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 56,
                    height: 56,
                    child: const Center(
                      child: Icon(
                        Icons.my_location,
                        color: _primaryColor,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}