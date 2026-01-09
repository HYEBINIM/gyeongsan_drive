// lib/fun/search_screen.dart

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../models/place.dart';
import 'place_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final double currentLat;
  final double currentLon;

  const SearchScreen({
    Key? key,
    required this.currentLat,
    required this.currentLon,
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  
  // 블랙 테마 색상
  static const Color _background = Color(0xFF000000);
  static const Color _surface = Color(0xFF1C1C1E);
  static const Color _surfaceVariant = Color(0xFF2C2C2E);
  static const Color _primary = Color(0xFF00C73C);
  static const Color _primaryDark = Color(0xFF00A030);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFAAAAAA);
  static const Color _textDisabled = Color(0xFF666666);
  static const Color _divider = Color(0xFF2C2C2E);
  static const Color _border = Color(0xFF3A3A3C);
  
  List<Place> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  
  @override
  void initState() {
    super.initState();
    // 텍스트 변경 리스너 추가
    _searchController.addListener(_onSearchTextChanged);
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }
  
  /// 검색어 변경 시 호출 (실시간 검색)
  void _onSearchTextChanged() {
    // 기존 타이머 취소
    _debounceTimer?.cancel();
    
    // 검색어가 비어있으면 결과 초기화
    if (_searchController.text.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }
    
    // 로딩 상태 표시
    if (!_isSearching) {
      setState(() {
        _isSearching = true;
      });
    }
    
    // 500ms 후에 검색 실행 (debounce)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(_searchController.text);
    });
  }
  
  /// 실제 검색 수행
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }
    
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });
    
    try {
      // DB에서 검색
      final results = await _apiService.searchPlacesFromDB(
        query: query,
        currentLat: widget.currentLat,
        currentLon: widget.currentLon,
      );
      
      // 검색어가 변경되지 않았을 때만 결과 업데이트
      if (_searchController.text.trim() == query.trim()) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('검색 오류: $e');
      
      if (_searchController.text.trim() == query.trim()) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '검색 중 오류가 발생했습니다',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: _surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _border,
              width: 1,
            ),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: '장소, 음식점, 주소 검색',
              hintStyle: const TextStyle(
                color: _textSecondary,
                fontSize: 15,
              ),
              prefixIcon: _isSearching
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_primary),
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.search,
                      color: _textSecondary,
                      size: 20,
                    ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: _textSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        // clear()를 호출하면 listener가 자동으로 호출됨
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              // Enter 키를 누르면 즉시 검색
              _debounceTimer?.cancel();
              _performSearch(value);
            },
          ),
        ),
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    // 검색 전 초기 화면
    if (!_hasSearched && !_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _surfaceVariant,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                Icons.search,
                size: 64,
                color: _textDisabled,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '장소를 검색해보세요',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '음식점, 카페, 관광지 등을 검색할 수 있습니다',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    
    // 검색 중이면서 아직 결과가 없을 때
    if (_isSearching && _searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: _primary,
            ),
            const SizedBox(height: 16),
            Text(
              '검색 중...',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    
    // 검색 완료 후 결과가 없을 때
    if (!_isSearching && _searchResults.isEmpty && _hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _surfaceVariant,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                Icons.search_off,
                size: 64,
                color: _textDisabled,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '검색 결과가 없습니다',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '다른 검색어로 시도해보세요',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    
    // 검색 결과가 있을 때
    return Column(
      children: [
        // 결과 개수 표시
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _surface,
            border: Border(
              bottom: BorderSide(
                color: _divider,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                '검색 결과',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${_searchResults.length}개',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // 검색 결과 리스트
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _searchResults.length,
            separatorBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                height: 1,
                thickness: 1,
                color: _divider,
              ),
            ),
            itemBuilder: (context, index) {
              final place = _searchResults[index];
              return _buildPlaceCard(place);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildPlaceCard(Place place) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaceDetailScreen(place: place),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 아이콘
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _primary.withOpacity(0.8),
                      _primaryDark.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIconForType(place.type),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // 장소 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이름
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    
                    // 카테고리
                    if (place.category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _border,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          place.category,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 6),
                    
                    // 주소 및 거리
                    Row(
                      children: [
                        Icon(
                          Icons.place,
                          size: 14,
                          color: _textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place.content.isNotEmpty ? place.content : place.local,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    // 해시태그 (거리 포함)
                    if (place.hashtags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: place.hashtags.take(3).map((tag) {
                          bool isDistance = tag.contains('m') || tag.contains('km');
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDistance 
                                  ? _primary.withOpacity(0.15)
                                  : _surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDistance 
                                    ? _primary.withOpacity(0.3)
                                    : _border,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isDistance ? FontWeight.w600 : FontWeight.w400,
                                color: isDistance ? _primary : _textSecondary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              
              // 화살표
              Icon(
                Icons.chevron_right,
                color: _textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  IconData _getIconForType(int type) {
    switch (type) {
      case 3:
        return Icons.wc;
      case 4:
        return Icons.local_parking;
      case 5:
        return Icons.drive_eta;
      case 6:
        return Icons.restaurant;
      default:
        return Icons.place;
    }
  }
}