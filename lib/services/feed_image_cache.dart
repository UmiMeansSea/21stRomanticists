import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom CacheManager that stores feed images for 7 days.
/// Configured to keep up to 500 items in the cache to cover typical feed sizes.
///
/// Usage: pass as [imageRenderMethodForWeb] and [cacheManager] in
/// CachedNetworkImage to replace the default 1-day, memory-only store.
class FeedImageCacheManager {
  FeedImageCacheManager._();

  static const String key = 'feedImageCache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 500,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
