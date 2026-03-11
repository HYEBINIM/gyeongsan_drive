// lib/fun/bus_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../models/bus_stop.dart';
import '../models/bus_route.dart';
import 'navigation_screen.dart';
import 'bus_navigation_screen.dart';

// ==================== 디자인 시스템 (네이버 지도 스타일) ====================

class AppColors {
  // 블랙 기반 색상
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF1C1C1E);
  static const surfaceVariant = Color(0xFF2C2C2E);
  static const surfaceElevated = Color(0xFF3A3A3C);
  
  // 네이버 그린
  static const primary = Color(0xFF00C73C);
  static const primaryDark = Color(0xFF00A030);
  static const primaryLight = Color(0xFF00E047);
  
  // 경로 색상
  static const routePath = Color(0xFF888888);
  static const routeOutline = Color(0xFFFFFFFF);
  
  // 텍스트 색상
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFAAAAAA);
  static const textDisabled = Color(0xFF666666);
  
  // UI 요소
  static const divider = Color(0xFF2C2C2E);
  static const border = Color(0xFF3A3A3C);
  
  // 상태 색상
  static const error = Color(0xFFFF453A);
  static const warning = Color(0xFFFFD60A);
  static const success = Color(0xFF30D158);
  
  // 버스 노선 타입별 색상
  static const busBlue = Color(0xFF3B82F6);
  static const busGreen = Color(0xFF10B981);
  static const busRed = Color(0xFFEF4444);
  static const busYellow = Color(0xFFF59E0B);
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
}

class AppTextStyle {
  static const display = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.5,
  );
  
  static const headline = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.3,
  );
  
  static const title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.3,
  );
  
  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.2,
  );
  
  static const body = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
    height: 1.4,
    letterSpacing: -0.1,
  );
  
  static const caption = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
    height: 1.3,
    letterSpacing: -0.1,
  );
  
  static const label = TextStyle(
    fontSize: 12,
    color: AppColors.textDisabled,
    height: 1.3,
  );
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
}

enum ViewMode {
  nearbyStops,
  stopRoutes,
  routeDetail,
}

// ==================== 컴팩트 버스번호 카드 ====================

class BusNumberCard extends StatelessWidget {
  final String routeName;
  final VoidCallback? onTap;
  
  const BusNumberCard({
    Key? key,
    required this.routeName,
    this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primaryDark,
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppColors.primaryLight.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_bus,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(height: 4),
                Text(
                  routeName,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.title.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== 컴팩트 정류장 카드 ====================

class BusStopCard extends StatelessWidget {
  final String stopName;
  final int? distance;
  final VoidCallback onTap;
  
  const BusStopCard({
    Key? key,
    required this.stopName,
    this.distance,
    required this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                // 정류장 아이콘
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.8),
                        AppColors.primaryDark.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                
                // 정류장 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        stopName,
                        style: AppTextStyle.bodyLarge.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (distance != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.near_me,
                              size: 11,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${distance}m',
                              style: AppTextStyle.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // 화살표 아이콘
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.textDisabled,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== 메인 BusTab 클래스 ====================

class BusTab extends StatefulWidget {
  const BusTab({Key? key}) : super(key: key);

  @override
  State<BusTab> createState() => _BusTabState();
}

class _BusTabState extends State<BusTab> with SingleTickerProviderStateMixin {
  NaverMapController? _mapController;
  final ApiService _apiService = ApiService();
  TabController? _tabController;
  
  late DraggableScrollableController _sheetController;
  
  static const double _minChildSize = 0.15;
  static const double _initialChildSize = 0.35;
  static const double _maxChildSize = 0.8;
  static const double _snapMiddle = 0.5;
  
  NLatLng? _currentPosition;
  List<BusStop> _busStops = [];
  
  ViewMode _currentViewMode = ViewMode.nearbyStops;
  
  BusStop? _selectedStop;
  List<BusRoute> _selectedStopRoutes = [];
  BusRoute? _selectedRoute;
  List<BusRouteStop> _selectedRouteStops = [];
  BusRoutePlaces? _routePlaces;
  
  dynamic _selectedPlace;
  bool _isSelectedPlaceEvent = false;
  
  bool _isLoading = false;
  bool _isLoadingRoutes = false;
  bool _isLoadingRouteStops = false;
  bool _isLoadingPlaces = false;
  
  Timer? _debounceTimer;
  bool _showNavigationButton = false;
  int _currentTabIndex = 0;
  double _currentZoom = 15.0;
  
  // 뒤로가기 더블탭 관련
  DateTime? _lastBackPressed;
  
  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _tabController = TabController(length: 3, vsync: this);
    _tabController!.addListener(_onTabChanged);
    _initializeNaverMap();
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _sheetController.dispose();
    _tabController?.dispose();
    super.dispose();
  }
  
  void _onTabChanged() {
    if (_tabController!.indexIsChanging) return;
    setState(() {
      _currentTabIndex = _tabController!.index;
      _selectedPlace = null;
      _showNavigationButton = false;
    });
    _updateMarkers();
  }
  
  void _snapToNearestSize(double velocity) {
    if (!_sheetController.isAttached) return;
    
    final currentSize = _sheetController.size;
    double targetSize;
    
    if (velocity > 500) {
      targetSize = _minChildSize;
    } else if (velocity < -500) {
      targetSize = _maxChildSize;
    } else {
      if (currentSize < (_minChildSize + _snapMiddle) / 2) {
        targetSize = _minChildSize;
      } else if (currentSize < (_snapMiddle + _maxChildSize) / 2) {
        targetSize = _snapMiddle;
      } else {
        targetSize = _maxChildSize;
      }
    }
    
    _sheetController.animateTo(
      targetSize,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
  
  Future<void> _initializeNaverMap() async {
    await NaverMapSdk.instance.initialize(
      clientId: 't14lkvxmuw',
      onAuthFailed: (ex) => print('네이버 지도 인증 실패: $ex'),
    );
    _initializeLocation();
  }
  
  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackBar('위치 서비스가 비활성화되어 있습니다.');
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackBar('위치 권한이 거부되었습니다.');
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar('위치 권한이 영구적으로 거부되었습니다.');
        setState(() => _isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = NLatLng(position.latitude, position.longitude);
      });

      await _loadNearbyStops(position.latitude, position.longitude);
      
    } catch (e) {
      print('위치 초기화 오류: $e');
      _showErrorSnackBar('위치를 가져오는데 실패했습니다.');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadNearbyStops(double lat, double lon) async {
    try {
      final stops = await _apiService.fetchNearbyBusStops(
        lat: lat,
        lon: lon,
        radiusKm: 2,
      );

      if (mounted) {
        setState(() => _busStops = stops);
        await _updateMarkers();
      }
      
      print('✅ 정류장 ${stops.length}개 로드 완료');
    } catch (e) {
      print('정류장 로드 오류: $e');
    }
  }
  
  NLatLng? _getPlacePosition(dynamic place, bool isEvent) {
    if (isEvent) {
      final mapx = place['mapx'] != null ? double.tryParse(place['mapx'].toString()) : null;
      final mapy = place['mapy'] != null ? double.tryParse(place['mapy'].toString()) : null;
      if (mapx != null && mapy != null) return NLatLng(mapy, mapx);
    } else {
      final location = place['location']?.toString().split(',') ?? [];
      final lat = location.isNotEmpty ? double.tryParse(location[0]) : null;
      final lon = location.length > 1 ? double.tryParse(location[1]) : null;
      if (lat != null && lon != null) return NLatLng(lat, lon);
    }
    return null;
  }
  
  Future<void> _updateMarkers() async {
    if (_mapController == null) return;
    
    print('🔄 마커 업데이트 시작 - ViewMode: $_currentViewMode');
    await _mapController!.clearOverlays();
    
    if (_currentViewMode == ViewMode.routeDetail && _selectedRouteStops.isNotEmpty) {
      await _addRoutePath();
    }
    
    if (_currentPosition != null) {
      await _addCurrentLocationMarker();
    }
    
    if (_currentViewMode == ViewMode.nearbyStops || _currentViewMode == ViewMode.stopRoutes) {
      await _addStopMarkers();
    }
    
    if (_currentViewMode == ViewMode.routeDetail && _routePlaces != null && _selectedPlace == null) {
      await _addPlaceMarkers();
    }
    
    if (_currentViewMode == ViewMode.routeDetail && _selectedRouteStops.isNotEmpty && _selectedPlace == null) {
      await _addStartEndPins();
    }
    
    if (_selectedPlace != null) {
      await _addSelectedPlaceMarker();
    }
    
    print('✅ 마커 업데이트 완료');
  }
  
  Color _getRouteColor(String? routeType) {
    return AppColors.primary;
  }
  
  String _getRouteTypeName(String? routeType) {
    switch (routeType) {
      case '1': return '일반';
      case '2': return '좌석';
      case '3': return '마을';
      case '4': return '급행';
      default: return '일반';
    }
  }
  
  Future<void> _addCurrentLocationMarker() async {
    final marker = NMarker(
      id: 'current_location',
      position: _currentPosition!,
      icon: const NOverlayImage.fromAssetImage('assets/images/marker_current.png'),
      size: const Size(36, 36),
      anchor: const NPoint(0.5, 0.5),
    );
    
    await _mapController!.addOverlay(marker);
  }
  
  Future<void> _addStopMarkers() async {
    NMarker? selectedMarker;
    
    for (var stop in _busStops) {
      final isSelected = _selectedStop?.id == stop.id;
      
      if (isSelected) {
        selectedMarker = NMarker(
          id: 'stop_${stop.id}',
          position: NLatLng(stop.lat, stop.lon),
          icon: NOverlayImage.fromAssetImage('assets/images/marker_stop_selected.png'),
          size: const Size(32, 32),
          anchor: const NPoint(0.5, 0.5),
        );
        
        if (_currentZoom >= 13) {
          selectedMarker.setCaption(NOverlayCaption(
            text: stop.stopName,
            textSize: 12,
            color: Colors.black,
            haloColor: Colors.white,
          ));
        }
        
        selectedMarker.setOnTapListener((_) => _onStopMarkerTapped(stop));
      } else {
        final marker = NMarker(
          id: 'stop_${stop.id}',
          position: NLatLng(stop.lat, stop.lon),
          icon: NOverlayImage.fromAssetImage('assets/images/marker_stop.png'),
          size: const Size(24, 24),
          anchor: const NPoint(0.5, 0.5),
        );
        
        if (_currentZoom >= 13) {
          marker.setCaption(NOverlayCaption(
            text: stop.stopName,
            textSize: 11,
            color: AppColors.textSecondary,
            haloColor: Colors.white,
          ));
        }
        
        marker.setOnTapListener((_) => _onStopMarkerTapped(stop));
        await _mapController!.addOverlay(marker);
      }
    }
    
    if (selectedMarker != null) {
      await _mapController!.addOverlay(selectedMarker);
    }
  }
  
  Future<void> _addRoutePath() async {
    final coords = _selectedRouteStops.map((s) => NLatLng(s.lat, s.lon)).toList();
    
    await _mapController!.addOverlay(NPathOverlay(
      id: 'route_path',
      coords: coords,
      color: AppColors.routePath,
      width: 6,
      outlineColor: AppColors.routeOutline,
      outlineWidth: 2,
    ));
  }
  
  Future<void> _addStartEndPins() async {
    if (_selectedRouteStops.isEmpty) return;
    
    final startMarker = NMarker(
      id: 'pin_start',
      position: NLatLng(_selectedRouteStops.first.lat, _selectedRouteStops.first.lon),
      icon: const NOverlayImage.fromAssetImage('assets/images/pin_start.png'),
      size: const Size(40, 56),
      anchor: const NPoint(0.5, 1.0),
    );
    
    startMarker.setCaption(NOverlayCaption(
      text: _selectedRouteStops.first.stopName,
      textSize: 12,
      color: AppColors.primary,
      haloColor: Colors.white,
    ));
    
    await _mapController!.addOverlay(startMarker);
    
    if (_selectedRouteStops.length > 1) {
      final endMarker = NMarker(
        id: 'pin_end',
        position: NLatLng(_selectedRouteStops.last.lat, _selectedRouteStops.last.lon),
        icon: const NOverlayImage.fromAssetImage('assets/images/pin_end.png'),
        size: const Size(40, 56),
        anchor: const NPoint(0.5, 1.0),
      );
      
      endMarker.setCaption(NOverlayCaption(
        text: _selectedRouteStops.last.stopName,
        textSize: 12,
        color: AppColors.primary,
        haloColor: Colors.white,
      ));
      
      await _mapController!.addOverlay(endMarker);
    }
  }
  
  Future<void> _addPlaceMarkers() async {
    List<dynamic> currentPlaces = [];
    String assetImage = '';
    
    if (_currentTabIndex == 0) {
      currentPlaces = _routePlaces!.restaurants;
      assetImage = 'assets/images/marker_restaurant.png';
    } else if (_currentTabIndex == 1) {
      currentPlaces = _routePlaces!.attractions;
      assetImage = 'assets/images/marker_attraction.png';
    } else if (_currentTabIndex == 2) {
      currentPlaces = _routePlaces!.events;
      assetImage = 'assets/images/marker_event.png';
    }
    
    if (currentPlaces.isEmpty) return;
    
    for (int i = 0; i < currentPlaces.length; i++) {
      final place = currentPlaces[i];
      final isEvent = _currentTabIndex == 2;
      final pos = _getPlacePosition(place, isEvent);
      if (pos == null) continue;
      
      final marker = NMarker(
        id: 'place_$i',
        position: pos,
        icon: NOverlayImage.fromAssetImage(assetImage),
        size: const Size(28, 28),
        anchor: const NPoint(0.5, 0.5),
      );
      
      if (_currentZoom >= 13) {
        marker.setCaption(NOverlayCaption(
          text: place['name'] ?? place['title'] ?? '장소',
          textSize: 11,
          color: AppColors.textSecondary,
          haloColor: Colors.white,
        ));
      }
      
      marker.setOnTapListener((_) => _onPlaceTapped(place, isEvent));
      
      await _mapController!.addOverlay(marker);
    }
  }
  
  Future<void> _addSelectedPlaceMarker() async {
    final pos = _getPlacePosition(_selectedPlace, _isSelectedPlaceEvent);
    if (pos == null) return;
    
    final marker = NMarker(
      id: 'selected_place',
      position: pos,
      icon: const NOverlayImage.fromAssetImage('assets/images/pin_destination.png'),
      size: const Size(44, 62),
      anchor: const NPoint(0.5, 1.0),
    );
    
    marker.setCaption(NOverlayCaption(
      text: _selectedPlace['name'] ?? _selectedPlace['title'] ?? '목적지',
      textSize: 12,
      color: AppColors.primary,
      haloColor: Colors.white,
    ));
    
    await _mapController!.addOverlay(marker);
  }
  
  void _onCameraChange(NCameraUpdateReason reason, bool animated) async {
    if (_mapController == null) return;
    
    final position = await _mapController!.getCameraPosition();
    final newZoom = position.zoom;
    
    if ((newZoom - _currentZoom).abs() > 0.5) {
      _currentZoom = newZoom;
      await _updateMarkers();
    } else {
      _currentZoom = newZoom;
    }
    
    if (_currentViewMode != ViewMode.nearbyStops || _showNavigationButton) return;
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_mapController != null) {
        final pos = await _mapController!.getCameraPosition();
        _loadNearbyStops(pos.target.latitude, pos.target.longitude);
      }
    });
  }
  
  void _onStopMarkerTapped(BusStop stop) async {
    print('🚏 정류장 선택: ${stop.stopName}');
    
    setState(() {
      _currentViewMode = ViewMode.stopRoutes;
      _selectedStop = stop;
      _selectedRoute = null;
      _selectedRouteStops = [];
      _selectedPlace = null;
      _showNavigationButton = false;
      _isLoadingRoutes = true;
    });
    
    await _updateMarkers();
    
    if (_mapController != null) {
      _mapController!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(stop.lat, stop.lon),
          zoom: 16.0,
        ),
      );
    }
    
    try {
      final routes = await _apiService.fetchBusRoutesAtStop(
        stopCode: stop.stopCode,
        cityName: stop.cityName ?? '경산',
      );
      
      if (mounted) {
        setState(() {
          _selectedStopRoutes = routes;
          _isLoadingRoutes = false;
        });
      }
    } catch (e) {
      print('노선 로드 오류: $e');
      if (mounted) setState(() => _isLoadingRoutes = false);
    }
  }
  
  void _onRouteSelected(BusRoute route) async {
    print('🚌 노선 선택: ${route.routeName}');
    
    setState(() {
      _currentViewMode = ViewMode.routeDetail;
      _selectedRoute = route;
      _selectedPlace = null;
      _showNavigationButton = false;
      _isLoadingRouteStops = true;
      _isLoadingPlaces = true;
      _currentTabIndex = 0;
    });
    
    _tabController?.index = 0;
    
    try {
      final results = await Future.wait([
        _apiService.fetchBusRouteStops(
          routeId: route.routeId,
          cityName: route.cityName ?? '경산',
        ),
        _apiService.fetchBusRoutePlaces(
          routeId: route.routeId,
          cityName: route.cityName ?? '경산',
          radiusKm: 0.5,
        ),
      ]);
      
      if (mounted) {
        final stops = results[0] as List<BusRouteStop>;
        final places = results[1] as BusRoutePlaces;
        
        setState(() {
          _selectedRouteStops = stops;
          _routePlaces = places;
          _isLoadingRouteStops = false;
          _isLoadingPlaces = false;
        });
        
        await _updateMarkers();
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted && _mapController != null) {
          _fitMapToRoute();
        }
      }
    } catch (e) {
      print('노선 정보 로드 오류: $e');
      if (mounted) {
        setState(() {
          _isLoadingRouteStops = false;
          _isLoadingPlaces = false;
        });
      }
    }
  }
  
  void _onPlaceTapped(dynamic place, bool isEvent) async {
    final pos = _getPlacePosition(place, isEvent);
    if (pos == null || _mapController == null) return;
    
    setState(() {
      _selectedPlace = place;
      _isSelectedPlaceEvent = isEvent;
      _showNavigationButton = true;
    });
    
    await _updateMarkers();
    
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        _minChildSize,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    
    final currentPos = await _mapController!.getCameraPosition();
    final targetZoom = math.max(currentPos.zoom - 1, 14.0);
    
    _mapController!.updateCamera(
      NCameraUpdate.scrollAndZoomTo(
        target: pos,
        zoom: targetZoom,
      ),
    );
  }
  
  // ✅ 길안내 시작 - 자동차/버스 선택 다이얼로그
  void _startNavigation() async {
    if (_selectedPlace == null || _currentPosition == null) return;
    
    final destination = _getPlacePosition(_selectedPlace, _isSelectedPlaceEvent);
    if (destination == null) return;
    
    final destinationName = _selectedPlace['name'] ?? _selectedPlace['title'] ?? '목적지';
    
    // 길안내 방법 선택 다이얼로그
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          '길안내 방법 선택',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 버스 안내 버튼
            if (_selectedRoute != null && _selectedStop != null)
              _buildNavigationOption(
                icon: Icons.directions_bus,
                title: '버스로 안내',
                subtitle: '${_selectedRoute!.routeName}번 이용',
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(context);
                  _startBusNavigation(destinationName, destination);
                },
              ),
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
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyle.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyle.caption,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 버스 길안내 시작
  void _startBusNavigation(String destinationName, NLatLng destination) {
    if (_selectedRoute == null || _selectedStop == null) return;
    
    print('🚌 버스 길안내 시작: $destinationName');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusNavigationScreen(
          destinationName: destinationName,
          destinationLat: destination.latitude,
          destinationLng: destination.longitude,
          selectedRoute: _selectedRoute!,
          nearestStop: _selectedStop!,
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
  
  void _fitMapToRoute() {
    if (_selectedRouteStops.isEmpty || _mapController == null) return;
  
    double minLat = _selectedRouteStops.first.lat;
    double maxLat = _selectedRouteStops.first.lat;
    double minLon = _selectedRouteStops.first.lon;
    double maxLon = _selectedRouteStops.first.lon;
  
    for (var stop in _selectedRouteStops) {
      minLat = math.min(minLat, stop.lat);
      maxLat = math.max(maxLat, stop.lat);
      minLon = math.min(minLon, stop.lon);
      maxLon = math.max(maxLon, stop.lon);
    }
  
    _mapController!.updateCamera(
      NCameraUpdate.fitBounds(
        NLatLngBounds(
          southWest: NLatLng(minLat, minLon),
          northEast: NLatLng(maxLat, maxLon),
        ),
        padding: const EdgeInsets.only(
          top: 200,
          left: 60,
          right: 60,
          bottom: 350,
        ),
      ),
    );
    
    Future.delayed(const Duration(milliseconds: 500), () {
      _updateMarkers();
    });
  }
  
  void _moveToCurrentLocation() async {
    if (_currentPosition != null && _mapController != null) {
      setState(() {
        _currentViewMode = ViewMode.nearbyStops;
        _selectedStop = null;
        _selectedRoute = null;
        _selectedRouteStops = [];
        _selectedPlace = null;
        _showNavigationButton = false;
      });
      await _updateMarkers();
      
      _mapController!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: _currentPosition!, zoom: 15.0),
      );
    }
  }
  
  // ✅ 뒤로가기 처리 함수
  Future<bool> _onWillPop() async {
    if (_showNavigationButton) {
      setState(() {
        _selectedPlace = null;
        _showNavigationButton = false;
      });
      
      await _updateMarkers();
      
      if (_sheetController.isAttached) {
        _sheetController.animateTo(
          _snapMiddle,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      
      _fitMapToRoute();
      return false;
    } else if (_currentViewMode == ViewMode.routeDetail) {
      setState(() {
        _currentViewMode = ViewMode.stopRoutes;
        _selectedRoute = null;
        _selectedRouteStops = [];
        _routePlaces = null;
        _selectedPlace = null;
        _showNavigationButton = false;
        _currentTabIndex = 0;
      });
      await _updateMarkers();
      
      if (_selectedStop != null && _mapController != null) {
        _mapController!.updateCamera(
          NCameraUpdate.scrollAndZoomTo(
            target: NLatLng(_selectedStop!.lat, _selectedStop!.lon),
            zoom: 16.0,
          ),
        );
      }
      return false;
    } else if (_currentViewMode == ViewMode.stopRoutes) {
      setState(() {
        _currentViewMode = ViewMode.nearbyStops;
        _selectedStop = null;
        _selectedStopRoutes = [];
      });
      await _updateMarkers();
      
      if (_currentPosition != null && _mapController != null) {
        _mapController!.updateCamera(
          NCameraUpdate.scrollAndZoomTo(
            target: _currentPosition!,
            zoom: 15.0,
          ),
        );
      }
      return false;
    } else {
      // 홈 화면에서 뒤로가기 - 더블탭 확인
      final now = DateTime.now();
      if (_lastBackPressed == null || 
          now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
        _lastBackPressed = now;
        _showInfoSnackBar('뒤로가기 버튼을 한번 더 누르면 종료됩니다');
        return false;
      }
      return true;
    }
  }
  
  void _goBack() {
    _onWillPop();
  }
  
  String _formatEventDate(String dateStr) {
    if (dateStr.length == 8) {
      return '${dateStr.substring(0, 4)}.${dateStr.substring(4, 6)}.${dateStr.substring(6, 8)}';
    }
    return dateStr;
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTextStyle.body.copyWith(color: Colors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        margin: const EdgeInsets.all(AppSpacing.lg),
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTextStyle.body.copyWith(color: Colors.white)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        margin: const EdgeInsets.all(AppSpacing.lg),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            _currentPosition == null
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  )
                : NaverMap(
                    options: NaverMapViewOptions(
                      initialCameraPosition: NCameraPosition(
                        target: _currentPosition!,
                        zoom: 15.0,
                      ),
                      locationButtonEnable: false,
                    ),
                    onMapReady: (controller) async {
                      _mapController = controller;
                      await _updateMarkers();
                    },
                    onCameraChange: _onCameraChange,
                  ),
            
            if (_isLoading)
              Container(
                color: AppColors.background.withOpacity(0.7),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              ),
            
            if (_currentViewMode == ViewMode.routeDetail && _selectedRoute != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    margin: const EdgeInsets.all(AppSpacing.lg),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: AppColors.border,
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
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _goBack,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: Icon(
                                Icons.arrow_back,
                                color: AppColors.textPrimary,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Center(
                            child: Text(
                              _selectedRoute!.routeName,
                              style: AppTextStyle.title.copyWith(
                                color: AppColors.background,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _showNavigationButton && _selectedPlace != null
                                    ? _selectedPlace['name'] ?? _selectedPlace['title'] ?? '목적지'
                                    : '${_getRouteTypeName(_selectedRoute!.routeType)}버스',
                                style: AppTextStyle.bodyLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _showNavigationButton
                                    ? '현재 위치에서 출발'
                                    : '${_selectedRoute!.startStop} → ${_selectedRoute!.endStop}',
                                style: AppTextStyle.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            if (_showNavigationButton)
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.xl,
                child: SafeArea(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _startNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.navigation, size: 24),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            '안내 시작',
                            style: AppTextStyle.title.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            
            if (!_showNavigationButton)
              _buildBottomPanel(),
            
            // ✅ 현재 위치 버튼 - 하단패널의 위에 고정
            AnimatedBuilder(
              animation: _sheetController,
              builder: (context, child) {
                final screenHeight = MediaQuery.of(context).size.height;
                final sheetHeight = _sheetController.isAttached 
                    ? screenHeight * _sheetController.size
                    : screenHeight * _initialChildSize;

                return Positioned(
                  bottom: sheetHeight,
                  right: AppSpacing.md,
                  child: child!,
                );
              },
              child: SafeArea(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      onTap: _moveToCurrentLocation,
                      borderRadius: BorderRadius.circular(22),
                      child: Center(
                        child: Icon(
                          Icons.my_location,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBottomPanel() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _initialChildSize,
      minChildSize: _minChildSize,
      maxChildSize: _maxChildSize,
      snap: true,
      snapSizes: const [_minChildSize, _snapMiddle, _maxChildSize],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
            border: Border.all(
              color: AppColors.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildDraggableHandle(),
              Expanded(
                child: _buildPanelContent(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildDraggableHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        if (!_sheetController.isAttached) return;
        
        final delta = details.primaryDelta! / context.size!.height;
        final newSize = (_sheetController.size - delta).clamp(_minChildSize, _maxChildSize);
        _sheetController.jumpTo(newSize);
      },
      onVerticalDragEnd: (details) {
        _snapToNearestSize(details.primaryVelocity ?? 0);
      },
      onTap: () {
        if (!_sheetController.isAttached) return;
        
        final currentSize = _sheetController.size;
        final targetSize = currentSize < _snapMiddle ? _maxChildSize : _minChildSize;
        _sheetController.animateTo(
          targetSize,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPanelContent(ScrollController scrollController) {
    switch (_currentViewMode) {
      case ViewMode.nearbyStops:
        return _buildNearbyStopsList(scrollController);
      case ViewMode.stopRoutes:
        return _buildStopRoutesList(scrollController);
      case ViewMode.routeDetail:
        return _buildRoutePlacesList(scrollController);
      default:
        return const SizedBox.shrink();
    }
  }
  
  Widget _buildNearbyStopsList(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.8),
                      AppColors.primaryDark.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '주변 정류장',
                style: AppTextStyle.headline.copyWith(fontSize: 18),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '${_busStops.length}개',
                  style: AppTextStyle.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        if (_busStops.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.xxl * 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Icon(
                    Icons.search_off,
                    size: 48,
                    color: AppColors.textDisabled,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '주변에 정류장이 없습니다',
                  style: AppTextStyle.body,
                ),
              ],
            ),
          )
        else
          ...List.generate(_busStops.length, (index) {
            final stop = _busStops[index];
            final distance = _currentPosition != null
                ? _calculateDistance(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                    stop.lat,
                    stop.lon,
                  )
                : null;
            
            return BusStopCard(
              stopName: stop.stopName,
              distance: distance,
              onTap: () => _onStopMarkerTapped(stop),
            );
          }),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
  
  Widget _buildStopRoutesList(ScrollController scrollController) {
    final uniqueRoutes = <String, BusRoute>{};
    for (var route in _selectedStopRoutes) {
      if (!uniqueRoutes.containsKey(route.routeName)) {
        uniqueRoutes[route.routeName] = route;
      }
    }
    final displayRoutes = uniqueRoutes.values.toList();

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _goBack,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedStop!.stopName,
                      style: AppTextStyle.headline.copyWith(fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '경유 버스',
                      style: AppTextStyle.caption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        if (_isLoadingRoutes)
          Container(
            padding: const EdgeInsets.all(AppSpacing.xxl * 2),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (displayRoutes.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.xxl * 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Icon(
                    Icons.search_off,
                    size: 48,
                    color: AppColors.textDisabled,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '경유하는 버스가 없습니다',
                  style: AppTextStyle.body,
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.2,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
              ),
              itemCount: displayRoutes.length,
              itemBuilder: (context, index) {
                final route = displayRoutes[index];
                return BusNumberCard(
                  routeName: route.routeName,
                  onTap: () => _onRouteSelected(route),
                );
              },
            ),
          ),
      ],
    );
  }
  
  Widget _buildRoutePlacesList(ScrollController scrollController) {
    if (_isLoadingPlaces) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_routePlaces == null) {
      return Center(
        child: Text('정보를 불러올 수 없습니다', style: AppTextStyle.body),
      );
    }
    
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            border: Border(
              bottom: BorderSide(
                color: AppColors.divider,
                width: 1,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: AppTextStyle.body.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: AppTextStyle.body,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.restaurant, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Text('맛집 ${_routePlaces!.restaurants.length}'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.place, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Text('관광 ${_routePlaces!.attractions.length}'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Text('행사 ${_routePlaces!.events.length}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPlacesList(_routePlaces!.restaurants, '맛집', scrollController),
              _buildPlacesList(_routePlaces!.attractions, '관광지', scrollController),
              _buildEventsList(_routePlaces!.events, scrollController),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPlacesList(List<dynamic> places, String type, ScrollController scrollController) {
    if (places.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                type == '맛집' ? Icons.restaurant_menu : Icons.place_outlined,
                size: 48,
                color: AppColors.textDisabled,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '이 노선 주변에 $type이(가) 없습니다',
              style: AppTextStyle.body,
            ),
          ],
        ),
      );
    }
    
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: places.length,
      separatorBuilder: (context, index) => Divider(
        height: AppSpacing.xxl,
        color: AppColors.divider,
      ),
      itemBuilder: (context, index) {
        final place = places[index];
        
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onPlaceTapped(place, false),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        type == '맛집' ? Icons.restaurant : Icons.place,
                        color: AppColors.primary.withOpacity(0.6),
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                place['name'] ?? '이름 없음',
                                style: AppTextStyle.bodyLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (place['search_num'] != null && place['search_num'] > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '🔥 ${place['search_num']}',
                                  style: AppTextStyle.label.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (place['category'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(AppSpacing.xs),
                            ),
                            child: Text(
                              place['category'],
                              style: AppTextStyle.label,
                            ),
                          ),
                        if (place['content'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            place['content'],
                            style: AppTextStyle.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (place['tel_number'] != null && place['tel_number'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '📞 ${place['tel_number']}',
                            style: AppTextStyle.label,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textDisabled,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildEventsList(List<dynamic> events, ScrollController scrollController) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                Icons.event_busy,
                size: 48,
                color: AppColors.textDisabled,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '이 노선 주변에 진행 중인 행사가 없습니다',
              style: AppTextStyle.body,
            ),
          ],
        ),
      );
    }
    
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: events.length,
      separatorBuilder: (context, index) => Divider(
        height: AppSpacing.xxl,
        color: AppColors.divider,
      ),
      itemBuilder: (context, index) {
        final event = events[index];
        
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onPlaceTapped(event, true),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: event['firstimage'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Image.network(
                              event['firstimage'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.event,
                                    color: AppColors.primary.withOpacity(0.6),
                                    size: 32,
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.event,
                              color: AppColors.primary.withOpacity(0.6),
                              size: 32,
                            ),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          event['title'] ?? '제목 없음',
                          style: AppTextStyle.bodyLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (event['eventstartdate'] != null && event['eventenddate'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '📅 ${_formatEventDate(event['eventstartdate'])} ~ ${_formatEventDate(event['eventenddate'])}',
                            style: AppTextStyle.caption,
                          ),
                        ],
                        if (event['addr1'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '📍 ${event['addr1']}',
                            style: AppTextStyle.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textDisabled,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  int _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return (earthRadius * c).round();
  }
  
  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }
}