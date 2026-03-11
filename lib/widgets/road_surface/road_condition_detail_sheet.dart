import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/road_condition_model.dart';
import '../../services/cache/road_condition_image_cache_manager.dart';
import '../../utils/constants.dart';

/// 도로 상태 상세 정보 바텀시트
/// 마커 클릭 시 이미지와 상세 정보를 표시
class RoadConditionDetailSheet extends StatelessWidget {
  final RoadConditionModel condition;
  final VoidCallback? onClose;

  static const double _imageAspectRatio = 4 / 3;
  static const double _contentHorizontalPadding = 16;

  // 한국어 주석: 메모리 캐시 - 앱 세션 내 URL 해석 결과 저장
  static final Map<String, Future<String>> _resolvedImageUrlCache = {};

  // 한국어 주석: 영구 캐시 키 (SharedPreferences)
  static const String _persistentCacheKey = 'road_condition_resolved_urls_v1';

  // 한국어 주석: 영구 캐시 TTL (7일)
  static const Duration _persistentCacheTtl = Duration(days: 7);

  // 한국어 주석: 영구 캐시 메모리 복사본 (SharedPreferences 접근 최소화)
  static Map<String, _CachedUrl>? _persistentCacheInMemory;

  // 한국어 주석: 프리패치 완료 추적
  static final Map<String, Completer<void>> _prefetchCompleters = {};

  // 한국어 주석: 병렬 프리패치 동시 실행 제한 (네트워크 과부하 방지)
  static const int _maxConcurrentPrefetch = 3;
  static int _currentPrefetchCount = 0;

  const RoadConditionDetailSheet({
    super.key,
    required this.condition,
    this.onClose,
  });

  // 한국어 주석: URL(토큰/쿼리)이 바뀌어도 디스크 캐시를 재사용할 수 있도록 안정적인 캐시 키를 사용합니다.
  // 한국어 주석: 서버 리사이즈 적용 시 사이즈별 캐시가 분리되도록 size를 포함합니다.
  static String _imageCacheKey(
    RoadConditionModel condition, {
    int? width,
    int? height,
  }) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return 'road_condition_${condition.id}';
    }

    return 'road_condition_${condition.id}_${width}x$height';
  }

  static bool _isHttpUrl(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  /// 한국어 주석: 영구 캐시 초기화 (앱 시작 시 호출)
  static Future<void> initializePersistentCache() async {
    if (_persistentCacheInMemory != null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_persistentCacheKey);

      if (jsonString != null) {
        final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
        final now = DateTime.now();

        _persistentCacheInMemory = {};
        for (final entry in jsonData.entries) {
          final cachedUrl = _CachedUrl.fromJson(
            entry.value as Map<String, dynamic>,
          );
          // TTL 검사: 만료되지 않은 항목만 로드
          if (now.difference(cachedUrl.cachedAt) < _persistentCacheTtl) {
            _persistentCacheInMemory![entry.key] = cachedUrl;
          }
        }
      } else {
        _persistentCacheInMemory = {};
      }
    } catch (e) {
      debugPrint('RoadConditionDetailSheet: 영구 캐시 초기화 실패 - $e');
      _persistentCacheInMemory = {};
    }
  }

  /// 한국어 주석: 영구 캐시에서 URL 조회
  static String? _getFromPersistentCache(String originalUrl) {
    final cached = _persistentCacheInMemory?[originalUrl];
    if (cached == null) return null;

    // TTL 검사
    if (DateTime.now().difference(cached.cachedAt) >= _persistentCacheTtl) {
      _persistentCacheInMemory?.remove(originalUrl);
      return null;
    }

    return cached.resolvedUrl;
  }

  /// 한국어 주석: 영구 캐시에 URL 저장
  static Future<void> _saveToPersistentCache(
    String originalUrl,
    String resolvedUrl,
  ) async {
    if (resolvedUrl.isEmpty) return;

    final cachedUrl = _CachedUrl(
      resolvedUrl: resolvedUrl,
      cachedAt: DateTime.now(),
    );

    _persistentCacheInMemory ??= {};
    _persistentCacheInMemory![originalUrl] = cachedUrl;

    // 비동기로 SharedPreferences에 저장 (UI 블로킹 방지)
    unawaited(_persistCacheToStorage());
  }

  /// 한국어 주석: 메모리 캐시를 SharedPreferences에 저장
  static Future<void> _persistCacheToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = <String, dynamic>{};

      for (final entry in (_persistentCacheInMemory ?? {}).entries) {
        jsonData[entry.key] = entry.value.toJson();
      }

      await prefs.setString(_persistentCacheKey, jsonEncode(jsonData));
    } catch (e) {
      debugPrint('RoadConditionDetailSheet: 영구 캐시 저장 실패 - $e');
    }
  }

  static Future<String> _resolveImageUrl(String imageUrl) {
    final normalized = imageUrl.trim();
    if (normalized.isEmpty) return Future.value('');

    // 1. 메모리 캐시 확인 (진행 중인 Future 포함)
    final cached = _resolvedImageUrlCache[normalized];
    if (cached != null) return cached;

    // 2. 영구 캐시 확인 (동기)
    final persistentCached = _getFromPersistentCache(normalized);
    if (persistentCached != null) {
      return Future.value(persistentCached);
    }

    // 3. 새로 해석
    final future = _resolveImageUrlInternal(normalized);
    _resolvedImageUrlCache[normalized] = future;
    return future;
  }

  /// 한국어 주석: 여러 URL을 병렬로 해석 (프리패치 최적화용)
  static Future<Map<String, String>> _resolveImageUrlsBatch(
    List<String> imageUrls,
  ) async {
    final results = <String, String>{};
    final futures = <Future<MapEntry<String, String>>>[];

    for (final url in imageUrls) {
      final normalized = url.trim();
      if (normalized.isEmpty) continue;

      futures.add(
        _resolveImageUrl(
          normalized,
        ).then((resolved) => MapEntry(normalized, resolved)),
      );
    }

    final entries = await Future.wait(futures);
    for (final entry in entries) {
      results[entry.key] = entry.value;
    }

    return results;
  }

  static Future<String> _resolveImageUrlInternal(String imageUrl) async {
    if (_isHttpUrl(imageUrl)) return imageUrl;

    // gs:// 또는 Storage 경로인 경우에만 Firebase Storage에서 URL 해석 시도
    if (imageUrl.startsWith('gs://') || _looksLikeStoragePath(imageUrl)) {
      try {
        String resolvedUrl;
        if (imageUrl.startsWith('gs://')) {
          resolvedUrl = await FirebaseStorage.instance
              .refFromURL(imageUrl)
              .getDownloadURL();
        } else {
          final normalizedPath = imageUrl.startsWith('/')
              ? imageUrl.substring(1)
              : imageUrl;
          resolvedUrl = await FirebaseStorage.instance
              .ref(normalizedPath)
              .getDownloadURL();
        }

        // 영구 캐시에 저장
        unawaited(_saveToPersistentCache(imageUrl, resolvedUrl));

        return resolvedUrl;
      } catch (e) {
        _resolvedImageUrlCache.remove(imageUrl);
        // Firebase Storage 해석 실패 시 빈 문자열 반환하여 에러 플레이스홀더 표시
        // gs:// 또는 Storage 경로는 직접 로드할 수 없으므로 원본 반환하지 않음
        debugPrint(
          'RoadConditionDetailSheet: Storage URL 해석 실패 - $imageUrl, 오류: $e',
        );
        return '';
      }
    }

    // 그 외의 경우 원본 URL 그대로 반환 (CachedNetworkImage가 처리)
    return imageUrl;
  }

  /// Storage 경로처럼 보이는지 확인
  /// - 알려진 Storage prefix (road_conditions/ 등)
  /// - 이미지 파일 확장자로 끝나는 경로
  /// - 슬래시를 포함하는 상대 경로 (HTTP가 아닌 경우)
  static bool _looksLikeStoragePath(String path) {
    if (path.isEmpty) return false;

    final lowerPath = path.toLowerCase();

    // 1. 알려진 Firebase Storage 경로 prefix 확인
    const knownStoragePrefixes = ['road_conditions/', 'images/', 'uploads/'];
    for (final prefix in knownStoragePrefixes) {
      if (lowerPath.startsWith(prefix)) return true;
    }

    // 2. 이미지 파일 확장자로 끝나는 경로
    if (lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.png') ||
        lowerPath.endsWith('.gif') ||
        lowerPath.endsWith('.webp')) {
      return true;
    }

    // 3. 슬래시를 포함하는 상대 경로 (scheme이 없는 경우)
    // 예: "folder/subfolder/file" 또는 "/folder/file"
    final uri = Uri.tryParse(path);
    if (uri != null && uri.scheme.isEmpty && path.contains('/')) {
      return true;
    }

    return false;
  }

  static String _buildServerResizedUrl(
    String imageUrl, {
    required int width,
    required int height,
  }) {
    if (imageUrl.isEmpty || width <= 0 || height <= 0) {
      return imageUrl;
    }

    final uri = Uri.tryParse(imageUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return imageUrl;
    }

    // 한국어 주석: 리사이즈 파라미터를 지원하는 서비스만 처리
    // 일반 외부 서버는 ?w=&h= 파라미터를 지원하지 않으므로 원본 URL 사용
    if (!_supportsResizeParams(uri)) {
      return imageUrl;
    }

    final queryParameters = Map<String, String>.from(uri.queryParameters);
    if (_hasSizeParams(queryParameters)) {
      return imageUrl;
    }

    queryParameters['w'] = width.toString();
    queryParameters['h'] = height.toString();
    queryParameters.putIfAbsent('fit', () => 'cover');

    return uri.replace(queryParameters: queryParameters).toString();
  }

  /// 리사이즈 파라미터를 지원하는 이미지 서비스인지 확인
  static bool _supportsResizeParams(Uri uri) {
    final host = uri.host.toLowerCase();

    // Firebase Storage는 리사이즈 미지원
    if (_isFirebaseStorageUrl(uri)) return false;

    // 서명된 URL은 파라미터 추가 불가
    if (_isSignedUrl(uri)) return false;

    // 리사이즈 파라미터를 지원하는 알려진 CDN/이미지 서비스
    const supportedHosts = [
      'imgix.net',
      'cloudinary.com',
      'res.cloudinary.com',
      'imagekit.io',
      'ik.imagekit.io',
      'images.unsplash.com',
      'cdn.sanity.io',
    ];

    for (final supportedHost in supportedHosts) {
      if (host == supportedHost || host.endsWith('.$supportedHost')) {
        return true;
      }
    }

    // 그 외 일반 서버는 리사이즈 미지원으로 간주
    return false;
  }

  static bool _hasSizeParams(Map<String, String> queryParameters) {
    for (final key in queryParameters.keys) {
      final lower = key.toLowerCase();
      if (lower == 'w' ||
          lower == 'h' ||
          lower == 'width' ||
          lower == 'height' ||
          lower == 'max-width' ||
          lower == 'max-height') {
        return true;
      }
    }
    return false;
  }

  static bool _isSignedUrl(Uri uri) {
    for (final key in uri.queryParameters.keys) {
      final lower = key.toLowerCase();
      if (lower.startsWith('x-goog-') ||
          lower.startsWith('x-amz-') ||
          lower == 'signature' ||
          lower == 'sig') {
        return true;
      }
    }
    return false;
  }

  static bool _isFirebaseStorageUrl(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'firebasestorage.googleapis.com' ||
        host.endsWith('.firebasestorage.app')) {
      return true;
    }

    if (host == 'storage.googleapis.com') {
      final path = uri.path.toLowerCase();
      return path.contains('/o/') || path.contains('/download/storage/v1/b/');
    }

    return false;
  }

  /// 바텀시트 표시
  /// 한국어 주석: 즉시 바텀시트를 열고 백그라운드에서 프리패치 진행
  /// 이전 구현은 300ms 대기했으나, 사용자 체감 속도 개선을 위해 즉시 표시
  static Future<void> show(
    BuildContext context, {
    required RoadConditionModel condition,
    VoidCallback? onClose,
  }) async {
    // 프리패치 시작 (백그라운드 - 대기하지 않음)
    unawaited(_startPrefetchWithTracking(context, condition));

    if (!context.mounted) return;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          RoadConditionDetailSheet(condition: condition, onClose: onClose),
    );
  }

  /// 한국어 주석: 프리패치 완료 추적을 포함한 프리패치 시작
  static Future<void> _startPrefetchWithTracking(
    BuildContext context,
    RoadConditionModel condition,
  ) {
    final cacheKey = condition.id;

    // 이미 진행 중인 프리패치가 있으면 해당 Future 반환
    final existingCompleter = _prefetchCompleters[cacheKey];
    if (existingCompleter != null && !existingCompleter.isCompleted) {
      return existingCompleter.future;
    }

    // 새 Completer 생성
    final completer = Completer<void>();
    _prefetchCompleters[cacheKey] = completer;

    // 프리패치 실행
    _prefetchImage(context, condition)
        .then((_) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        })
        .catchError((e) {
          if (!completer.isCompleted) {
            completer.complete(); // 에러 발생해도 완료 처리
          }
        });

    return completer.future;
  }

  static ({int width, int height}) _targetImageSizePx(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableWidth =
        mediaQuery.size.width -
        mediaQuery.padding.horizontal -
        (_contentHorizontalPadding * 2);
    if (availableWidth <= 0) return (width: 0, height: 0);

    final devicePixelRatio = mediaQuery.devicePixelRatio;
    final widthPx = (availableWidth * devicePixelRatio).round();
    final heightPx = (availableWidth / _imageAspectRatio * devicePixelRatio)
        .round();
    return (width: widthPx, height: heightPx);
  }

  /// 외부에서 상세 이미지 프리패치에 사용할 수 있는 공개 API
  static void prefetchImage(
    BuildContext context,
    RoadConditionModel condition,
  ) {
    unawaited(_prefetchImage(context, condition));
  }

  /// 한국어 주석: 도로 상태 데이터 로드 직후 URL을 선제적으로 해석
  /// ViewModel에서 호출하여 사용자가 마커를 탭하기 전에 URL 캐시를 워밍업
  static Future<void> preResolveUrls(
    List<RoadConditionModel> conditions,
  ) async {
    if (conditions.isEmpty) return;

    // 영구 캐시가 초기화되지 않았으면 먼저 초기화
    await initializePersistentCache();

    // URL 해석을 병렬로 수행 (이미지 다운로드는 하지 않음 - 빠른 캐시 워밍업)
    final imageUrls = conditions.map((c) => c.imageUrl).toList();
    await _resolveImageUrlsBatch(imageUrls);
  }

  /// 한국어 주석: 여러 이미지를 병렬로 프리패치 (지도 화면 최적화용)
  /// URL 해석과 이미지 다운로드 모두 병렬로 수행 (동시 실행 수 제한)
  static Future<void> prefetchImagesBatch(
    BuildContext context,
    List<RoadConditionModel> conditions,
  ) async {
    if (conditions.isEmpty || !context.mounted) return;

    // 1. URL 해석을 병렬로 수행
    final imageUrls = conditions.map((c) => c.imageUrl).toList();
    await _resolveImageUrlsBatch(imageUrls);

    // 2. 이미지 프리패치 (병렬 - 동시 실행 수 제한으로 네트워크 과부하 방지)
    final futures = <Future<void>>[];
    for (final condition in conditions) {
      if (!context.mounted) break;
      futures.add(_prefetchImageWithConcurrencyLimit(context, condition));
    }
    await Future.wait(futures);
  }

  /// 한국어 주석: 동시 실행 수를 제한하는 프리패치 래퍼
  static Future<void> _prefetchImageWithConcurrencyLimit(
    BuildContext context,
    RoadConditionModel condition,
  ) async {
    // 동시 실행 수 제한 대기
    while (_currentPrefetchCount >= _maxConcurrentPrefetch) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!context.mounted) return;
    }

    _currentPrefetchCount++;
    try {
      await _prefetchImage(context, condition);
    } finally {
      _currentPrefetchCount--;
    }
  }

  static Future<void> _prefetchImage(
    BuildContext context,
    RoadConditionModel condition,
  ) async {
    final sizePx = _targetImageSizePx(context);
    if (sizePx.width <= 0 || sizePx.height <= 0) return;

    final imageUrl = await _resolveImageUrl(condition.imageUrl);
    if (imageUrl.isEmpty || !context.mounted) return;

    final resizedImageUrl = _buildServerResizedUrl(
      imageUrl,
      width: sizePx.width,
      height: sizePx.height,
    );
    final cacheKey = resizedImageUrl == imageUrl
        ? _imageCacheKey(condition)
        : _imageCacheKey(condition, width: sizePx.width, height: sizePx.height);

    // 한국어 주석: 바텀시트 애니메이션 전에 다운로드/디코딩을 미리 시작하여 첫 표시 지연을 줄입니다.
    final provider = ResizeImage(
      CachedNetworkImageProvider(
        resizedImageUrl,
        cacheKey: cacheKey,
        cacheManager: RoadConditionImageCacheManager.instance,
        maxWidth: sizePx.width,
        maxHeight: sizePx.height,
      ),
      width: sizePx.width,
      height: sizePx.height,
    );

    if (!context.mounted) return;
    unawaited(precacheImage(provider, context));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    // 한국어 주석: Container 내부에 SafeArea를 배치하여
    // 배경색은 전체 영역을 채우고, 콘텐츠만 SafeArea 영역을 피함
    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        // 한국어 주석: 하단 시스템 UI 영역(홈 인디케이터) 확보
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들 바
            _buildHandle(colorScheme),

            // 헤더
            _buildHeader(context, colorScheme),

            const Divider(height: 1),

            // 콘텐츠
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이미지
                    _buildImage(context, colorScheme),

                    const SizedBox(height: 16),

                    // 상세 정보
                    _buildDetails(colorScheme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    // 한국어 주석: 포트홀 아이콘과 색상으로 통일
    const dangerColor = Colors.orange;
    const dangerIcon = Icons.warning_amber_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 포트홀 아이콘 (통일)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: dangerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(dangerIcon, color: dangerColor, size: 24),
          ),

          const SizedBox(width: 12),

          // 제목: "상세 정보"로 변경
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '상세 정보',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppConstants.fontFamilySmall,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  condition.formattedCollectTime,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                ),
              ],
            ),
          ),

          // 닫기 버튼
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
              onClose?.call();
            },
            icon: Icon(
              Icons.close,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context, ColorScheme colorScheme) {
    final sizePx = _targetImageSizePx(context);
    final memCacheWidth = sizePx.width > 0 ? sizePx.width : null;
    final memCacheHeight = sizePx.height > 0 ? sizePx.height : null;
    final rawImageUrl = condition.imageUrl.trim();

    Widget buildErrorPlaceholder() {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              '이미지를 불러올 수 없습니다',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildLoadingPlaceholder() {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    Widget buildFrame(Widget child) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(aspectRatio: _imageAspectRatio, child: child),
      );
    }

    Widget buildImageWithUrl(String originalImageUrl) {
      final resizedImageUrl = _buildServerResizedUrl(
        originalImageUrl,
        width: sizePx.width,
        height: sizePx.height,
      );
      final resizedCacheKey = resizedImageUrl == originalImageUrl
          ? _imageCacheKey(condition)
          : _imageCacheKey(
              condition,
              width: sizePx.width,
              height: sizePx.height,
            );
      final originalCacheKey = _imageCacheKey(condition);

      Widget buildCachedImage({
        required String imageUrl,
        required String cacheKey,
        required bool allowFallback,
      }) {
        return CachedNetworkImage(
          imageUrl: imageUrl,
          cacheKey: cacheKey,
          cacheManager: RoadConditionImageCacheManager.instance,
          fit: BoxFit.cover,
          memCacheWidth: memCacheWidth,
          memCacheHeight: memCacheHeight,
          maxWidthDiskCache: memCacheWidth,
          maxHeightDiskCache: memCacheHeight,
          placeholder: (context, url) => buildLoadingPlaceholder(),
          errorWidget: (context, url, error) {
            debugPrint(
              'RoadConditionDetailSheet: 이미지 로딩 실패\n'
              '  URL: $url\n'
              '  Error: $error\n'
              '  allowFallback: $allowFallback',
            );
            if (!allowFallback || originalImageUrl.isEmpty) {
              return buildErrorPlaceholder();
            }
            return buildCachedImage(
              imageUrl: originalImageUrl,
              cacheKey: originalCacheKey,
              allowFallback: false,
            );
          },
        );
      }

      return buildFrame(
        buildCachedImage(
          imageUrl: resizedImageUrl,
          cacheKey: resizedCacheKey,
          allowFallback: resizedImageUrl != originalImageUrl,
        ),
      );
    }

    if (rawImageUrl.isEmpty) {
      return buildFrame(buildErrorPlaceholder());
    }

    if (_isHttpUrl(rawImageUrl)) {
      return buildImageWithUrl(rawImageUrl);
    }

    return FutureBuilder<String>(
      future: _resolveImageUrl(rawImageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return buildFrame(buildLoadingPlaceholder());
        }
        final resolvedImageUrl = snapshot.data?.trim() ?? '';
        if (resolvedImageUrl.isEmpty) {
          return buildFrame(buildErrorPlaceholder());
        }
        return buildImageWithUrl(resolvedImageUrl);
      },
    );
  }

  Widget _buildDetails(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 한국어 주석: 감지 시간은 헤더에 이미 표시되므로 중복 제거
          _buildDetailRow(
            colorScheme,
            icon: Icons.location_on_outlined,
            label: '위치',
            value:
                '${condition.latitude.toStringAsFixed(6)}, ${condition.longitude.toStringAsFixed(6)}',
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            colorScheme,
            icon: Icons.devices,
            label: '디바이스',
            value: condition.collectDevSerial,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    ColorScheme colorScheme, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor ?? colorScheme.onSurface,
              fontFamily: AppConstants.fontFamilySmall,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

/// 한국어 주석: 영구 캐시에 저장할 URL 정보
class _CachedUrl {
  final String resolvedUrl;
  final DateTime cachedAt;

  const _CachedUrl({required this.resolvedUrl, required this.cachedAt});

  factory _CachedUrl.fromJson(Map<String, dynamic> json) {
    return _CachedUrl(
      resolvedUrl: json['resolvedUrl'] as String? ?? '',
      cachedAt:
          DateTime.tryParse(json['cachedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'resolvedUrl': resolvedUrl, 'cachedAt': cachedAt.toIso8601String()};
  }
}
