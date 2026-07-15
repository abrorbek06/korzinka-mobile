import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  final Map<String, File> _memoryCache = {};
  static const int _maxMemoryCacheSize = 50;
  static const int _maxDiskCacheAgeDays = 30;

  Future<File?> getCachedImage(String url) async {
    // Check memory cache first
    if (_memoryCache.containsKey(url)) {
      debugPrint('📷 Image found in memory cache: $url');
      return _memoryCache[url];
    }

    // Check disk cache
    final diskFile = await _getCachedFileFromDisk(url);
    if (diskFile != null && await diskFile.exists()) {
      // Check if file is too old
      final lastModified = await diskFile.lastModified();
      final age = DateTime.now().difference(lastModified);
      if (age.inDays > _maxDiskCacheAgeDays) {
        await diskFile.delete();
        return null;
      }

      // Add to memory cache
      _addToMemoryCache(url, diskFile);
      debugPrint('📷 Image found in disk cache: $url');
      return diskFile;
    }

    return null;
  }

  Future<File> cacheImage(String url) async {
    // Check if already cached
    final cached = await getCachedImage(url);
    if (cached != null) {
      return cached;
    }

    // Download and cache
    debugPrint('📷 Downloading and caching image: $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final file = await _saveToDisk(url, bytes);
        _addToMemoryCache(url, file);
        return file;
      } else {
        throw Exception('Failed to download image: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error caching image: $e');
      rethrow;
    }
  }

  Future<void> preloadImages(List<String> urls) async {
    debugPrint('📷 Preloading ${urls.length} images...');
    
    for (final url in urls) {
      try {
        final cached = await getCachedImage(url);
        if (cached == null) {
          await cacheImage(url);
        }
      } catch (e) {
        debugPrint('❌ Error preloading image $url: $e');
      }
    }
    
    debugPrint('✅ Image preloading complete');
  }

  Future<void> clearCache() async {
    // Clear memory cache
    _memoryCache.clear();

    // Clear disk cache
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint('🗑️ Image cache cleared');
      }
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  Future<int> getCacheSize() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('❌ Error calculating cache size: $e');
      return 0;
    }
  }

  Future<void> clearOldCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) return;

      final now = DateTime.now();
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          final lastModified = await entity.lastModified();
          final age = now.difference(lastModified);
          if (age.inDays > _maxDiskCacheAgeDays) {
            await entity.delete();
            debugPrint('🗑️ Deleted old cached file: ${entity.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error clearing old cache: $e');
    }
  }

  Future<File?> _getCachedFileFromDisk(String url) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = _generateFileName(url);
      final file = File(p.join(cacheDir.path, fileName));
      
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting cached file from disk: $e');
      return null;
    }
  }

  Future<File> _saveToDisk(String url, List<int> bytes) async {
    final cacheDir = await _getCacheDirectory();
    final fileName = _generateFileName(url);
    final file = File(p.join(cacheDir.path, fileName));
    
    await file.writeAsBytes(bytes);
    return file;
  }

  void _addToMemoryCache(String url, File file) {
    // Remove oldest if cache is full
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      final firstKey = _memoryCache.keys.first;
      _memoryCache.remove(firstKey);
    }
    _memoryCache[url] = file;
  }

  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(p.join(appDir.path, 'image_cache'));
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }

  String _generateFileName(String url) {
    // Generate a safe filename from URL
    final uri = Uri.parse(url);
    final path = uri.path;
    final extension = p.extension(path);
    final nameWithoutExtension = p.basenameWithoutExtension(path);
    
    // Hash the name to avoid issues with long filenames
    final hash = nameWithoutExtension.hashCode;
    return '${hash}_$nameWithoutExtension$extension';
  }

  // Get cached image URL for use with cached_network_image
  String? getCachedImageUrl(String url) {
    // This is a placeholder for integration with cached_network_image
    // The actual implementation would use the cached_network_image package
    return url;
  }
}
