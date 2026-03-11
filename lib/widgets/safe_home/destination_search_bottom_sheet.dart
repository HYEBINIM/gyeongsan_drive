import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/destination_search_result.dart';
import '../../models/recent_search.dart';
import '../../view_models/safe_home/safe_home_settings_viewmodel.dart';
import '../../utils/constants.dart';

/// 목적지 검색 Bottom Sheet
/// 검색창 + 최근 검색 + 검색 결과를 표시
class DestinationSearchBottomSheet extends StatefulWidget {
  const DestinationSearchBottomSheet({super.key});

  @override
  State<DestinationSearchBottomSheet> createState() =>
      _DestinationSearchBottomSheetState();
}

class _DestinationSearchBottomSheetState
    extends State<DestinationSearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<SearchResult> _searchResults = [];
  List<RecentSearch> _recentSearches = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _errorMessage;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();

    // 텍스트 변경 시 디바운싱 적용 검색
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 최근 검색어 불러오기
  Future<void> _loadRecentSearches() async {
    try {
      final viewModel = context.read<SafeHomeSettingsViewModel>();
      final searches = await viewModel.searchService.getRecentSearches();
      if (mounted) {
        setState(() {
          _recentSearches = searches;
        });
      }
    } catch (e) {
      // 최근 검색어 로드 실패는 무시 (핵심 기능 아님)
    }
  }

  /// 검색어 변경 시 디바운싱 처리
  void _onSearchChanged() {
    _debounceTimer?.cancel();

    final query = _searchController.text.trim();

    // 검색어가 비어있으면 검색 결과 초기화
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _errorMessage = null;
      });
      return;
    }

    // 500ms 후에 검색 실행
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  /// 실제 검색 수행
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _errorMessage = null;
    });

    try {
      final viewModel = context.read<SafeHomeSettingsViewModel>();
      final results = await viewModel.searchService.searchDestination(query);

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });

        // 검색 성공 시 최근 검색어 갱신
        await _loadRecentSearches();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// 최근 검색어 클릭 시
  void _onRecentSearchTap(RecentSearch recentSearch) {
    _searchController.text = recentSearch.query;
    _performSearch(recentSearch.query);
  }

  /// 최근 검색어 삭제
  Future<void> _onRecentSearchDelete(RecentSearch recentSearch) async {
    try {
      final viewModel = context.read<SafeHomeSettingsViewModel>();
      await viewModel.searchService.removeRecentSearch(recentSearch.query);
      await _loadRecentSearches();
    } catch (e) {
      // 삭제 실패는 무시
    }
  }

  /// 검색 결과 선택 시
  /// 한국어 주석: 실제 선택된 목적지만 최근 검색에 저장
  void _onResultTap(SearchResult result) {
    // 비동기 저장 후 바텀시트 닫기 (콜백은 동기 시그니처 유지)
    () async {
      try {
        final vm = context.read<SafeHomeSettingsViewModel>();
        await vm.searchService.saveSelectedToRecent(result);
      } catch (_) {
        // 저장 실패는 무시 (핵심 기능 아님)
      }

      if (!mounted) return;
      Navigator.of(context).pop(result);
    }();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    // 한국어 주석: 뒤로가기 버튼으로 바텀시트 닫기 허용
    return PopScope(
      canPop: true,
      child: Container(
        height: screenHeight * 0.85, // 화면의 85% 높이
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // AppBar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '목적지 검색',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.onSurface),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 검색창
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                autofocus: true,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
                decoration: InputDecoration(
                  hintText: '장소, 지하철역, 주소 검색',
                  hintStyle: TextStyle(
                    color: colorScheme.outline,
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                  prefixIcon: Icon(Icons.search, color: colorScheme.outline),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: colorScheme.outline),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // 내용 영역
            Expanded(child: _buildContent(colorScheme)),
          ],
        ),
      ),
    );
  }

  /// 내용 영역 빌드 (최근 검색 or 검색 결과)
  Widget _buildContent(ColorScheme colorScheme) {
    // 로딩 중
    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }

    // 에러 발생
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 검색 후 결과 표시
    if (_hasSearched) {
      return _buildSearchResults(colorScheme);
    }

    // 검색 전 최근 검색어 표시
    return _buildRecentSearches(colorScheme);
  }

  /// 최근 검색어 표시
  Widget _buildRecentSearches(ColorScheme colorScheme) {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '최근 검색한 목적지가 없습니다',
            style: TextStyle(
              color: colorScheme.outline,
              fontSize: 14,
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '최근 검색',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
        ),
        ..._recentSearches.map((recentSearch) {
          return _RecentSearchItem(
            recentSearch: recentSearch,
            onTap: () => _onRecentSearchTap(recentSearch),
            onDelete: () => _onRecentSearchDelete(recentSearch),
          );
        }),
      ],
    );
  }

  /// 검색 결과 표시
  Widget _buildSearchResults(ColorScheme colorScheme) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                '검색 결과가 없습니다',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '다른 검색어로 다시 시도해주세요',
                style: TextStyle(
                  color: colorScheme.outline,
                  fontSize: 14,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _SearchResultItem(
          result: result,
          onTap: () => _onResultTap(result),
        );
      },
    );
  }
}

/// 최근 검색어 아이템
class _RecentSearchItem extends StatelessWidget {
  final RecentSearch recentSearch;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecentSearchItem({
    required this.recentSearch,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(Icons.history, color: colorScheme.outline),
        title: Row(
          children: [
            Expanded(
              child: Text(
                recentSearch.query,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              recentSearch.formattedDate,
              style: TextStyle(
                color: colorScheme.outline,
                fontSize: 12,
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.close, color: colorScheme.outline, size: 20),
          onPressed: onDelete,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}

/// 검색 결과 아이템
class _SearchResultItem extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _SearchResultItem({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(Icons.place, color: colorScheme.primary),
      title: Text(
        result.placeName,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          fontFamily: AppConstants.fontFamilySmall,
        ),
      ),
      subtitle: Text(
        result.address,
        style: TextStyle(
          color: colorScheme.outline,
          fontSize: 13,
          fontFamily: AppConstants.fontFamilySmall,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
