import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 도로 상태 이미지 전용 캐시 매니저
/// ImageCacheManager 믹스인을 사용하여 이미지 리사이즈 기능 지원
class RoadConditionImageCacheManager extends CacheManager
    with ImageCacheManager {
  static const String _cacheKey = 'roadConditionImagesV1';

  static final RoadConditionImageCacheManager _instance =
      RoadConditionImageCacheManager._();

  static RoadConditionImageCacheManager get instance => _instance;

  RoadConditionImageCacheManager._()
      : super(
          Config(
            _cacheKey,
            stalePeriod: const Duration(days: 30),
            maxNrOfCacheObjects: 200,
          ),
        );
}
