import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef _SignedUrlInvoker = Future<String> Function(
    Map<String, dynamic> payload);

/// Service for caching signed URLs to reduce redundant API calls
///
/// Caches signed URLs in memory for the duration of the app session.
/// URLs expire after 1 hour for timeline thumbnails, or 2 hours for detail view media.
///
/// This service is designed to be non-blocking: Supabase RPCs are executed in a
/// worker isolate using compute() to completely offload network I/O from the UI thread.
class TimelineImageCacheService {
  TimelineImageCacheService({_SignedUrlInvoker? isolateInvoker})
      : _isolateInvoker = isolateInvoker ?? _invokeSignedUrlInBackground;

  final _SignedUrlInvoker _isolateInvoker;
  final Map<String, _CachedUrl> _cache = {};
  // Cache of in-flight Future promises to avoid duplicate calls for the same image
  final Map<String, Future<String>> _pendingFutures = {};
  static const int _urlExpirySeconds = 3600; // 1 hour for timeline thumbnails
  static const int _detailViewExpirySeconds =
      7200; // 2 hours for detail view media

  /// Get a signed URL for a storage path, using cache if available
  ///
  /// [supabaseUrl] is the Supabase project URL
  /// [supabaseAnonKey] is the Supabase anonymous/publishable key
  /// [bucket] is the storage bucket name ('memories-photos' or 'memories-videos')
  /// [path] is the storage path (can be a full URL or just the path)
  /// [accessToken] is the optional user access token for private buckets
  ///
  /// Returns a Future that resolves to the signed URL.
  /// Returns immediately without blocking the UI thread.
  Future<String> getSignedUrl(
    String supabaseUrl,
    String supabaseAnonKey,
    String bucket,
    String path, {
    String? accessToken,
  }) {
    return getSignedUrlWithExpiry(supabaseUrl, supabaseAnonKey, bucket, path,
        _urlExpirySeconds, accessToken);
  }

  /// Get a signed URL for detail view media with extended expiry
  ///
  /// Use this method for detail view carousel and lightbox media to ensure
  /// URLs remain valid for longer detail view sessions.
  ///
  /// [supabaseUrl] is the Supabase project URL
  /// [supabaseAnonKey] is the Supabase anonymous/publishable key
  /// [bucket] is the storage bucket name ('memories-photos' or 'memories-videos')
  /// [path] is the storage path (can be a full URL or just the path)
  /// [accessToken] is the optional user access token for private buckets
  ///
  /// Returns a Future that resolves to the signed URL.
  /// Returns immediately without blocking the UI thread.
  Future<String> getSignedUrlForDetailView(
    String supabaseUrl,
    String supabaseAnonKey,
    String bucket,
    String path, {
    String? accessToken,
  }) {
    return getSignedUrlWithExpiry(supabaseUrl, supabaseAnonKey, bucket, path,
        _detailViewExpirySeconds, accessToken);
  }

  /// Normalize a storage path, extracting it from a full URL if necessary
  ///
  /// If [path] is a full Supabase Storage public URL, extracts the storage path.
  /// If [path] is already a storage path, returns it as-is.
  String _normalizeStoragePath(String path) {
    // Check if it's a full URL
    if (path.startsWith('http://') || path.startsWith('https://')) {
      try {
        final uri = Uri.parse(path);
        final pathSegments = uri.pathSegments;

        // Supabase Storage public URLs have format:
        // /storage/v1/object/public/{bucket-name}/{path}
        // We need to find the index of 'public' and extract everything after the bucket name
        final publicIndex = pathSegments.indexOf('public');
        if (publicIndex != -1 && publicIndex < pathSegments.length - 1) {
          // Everything after 'public' is: bucket-name, then the actual path
          // Skip the bucket name (publicIndex + 1) and join the rest
          final storagePath = pathSegments.sublist(publicIndex + 2).join('/');
          // debugPrint(
          //    '[TimelineImageCacheService] Extracted storage path from URL: $storagePath');
          // developer.log('Extracted storage path from URL: $storagePath',
          //    name: 'TimelineImageCacheService');
          return storagePath;
        }
      } catch (e) {
        debugPrint(
            '[TimelineImageCacheService] Failed to parse URL, using as-is: $e');
        developer.log('Failed to parse URL, using as-is: $e',
            name: 'TimelineImageCacheService');
      }
    }

    // Return as-is if not a URL or parsing failed
    return path;
  }

  /// Internal method to get signed URL with custom expiry
  ///
  /// Returns immediately with a Future. The Supabase RPC is executed in a worker
  /// isolate using compute() to completely offload network I/O from the UI thread.
  /// If multiple callers request the same image simultaneously, they all receive
  /// the same Future promise.
  Future<String> getSignedUrlWithExpiry(
    String supabaseUrl,
    String supabaseAnonKey,
    String bucket,
    String path,
    int expirySeconds, [
    String? accessToken,
  ]) {
    // Normalize the path (extract from URL if necessary)
    final normalizedPath = _normalizeStoragePath(path);
    final cacheKey = '$bucket/$normalizedPath';
    final cached = _cache[cacheKey];

    // Check if cached URL is still valid (not expired)
    // Note: We check expiry based on the cached expiry time, not the requested expiry
    if (cached != null && !cached.isExpired) {
      developer.log(
        '[TimelineImageCacheService] Cache hit for $cacheKey',
        name: 'TimelineImageCacheService',
      );
      return Future.value(cached.url);
    }

    // Check if there's already a pending Future for this cache key
    // This prevents duplicate Supabase calls when multiple widgets request the same image
    final pendingFuture = _pendingFutures[cacheKey];
    if (pendingFuture != null) {
      developer.log(
        '[TimelineImageCacheService] Pending future hit for $cacheKey',
        name: 'TimelineImageCacheService',
      );
      return pendingFuture;
    }

    developer.log(
      '[TimelineImageCacheService] Cache miss for $cacheKey '
      '(expirySeconds=$expirySeconds)',
      name: 'TimelineImageCacheService',
    );

    final payload = _buildPayload(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      bucket: bucket,
      path: normalizedPath,
      expirySeconds: expirySeconds,
      accessToken: accessToken,
    );

    final future = _isolateInvoker(payload).then((url) {
      _cache[cacheKey] = _CachedUrl(
        url: url,
        expiresAt: DateTime.now().add(Duration(seconds: expirySeconds)),
      );
      developer.log(
        '[TimelineImageCacheService] Generated signed URL for $cacheKey',
        name: 'TimelineImageCacheService',
      );
      return url;
    }).catchError((error, stackTrace) {
      developer.log(
        '[TimelineImageCacheService] Signed URL request failed for $cacheKey',
        name: 'TimelineImageCacheService',
        error: error,
        stackTrace: stackTrace,
      );
      throw error;
    });
    final trackedFuture = future.whenComplete(() {
      _pendingFutures.remove(cacheKey);
    });
    _pendingFutures[cacheKey] = trackedFuture;
    return trackedFuture;
  }

  /// Clear expired entries from cache
  ///
  /// Call this periodically to prevent memory leaks
  void clearExpired() {
    _cache.removeWhere((key, value) => value.isExpired);
  }

  /// Clear all cached URLs and pending futures
  void clear() {
    _cache.clear();
    _pendingFutures.clear();
  }

  /// Get cache size (for debugging)
  int get cacheSize => _cache.length;

  Map<String, dynamic> _buildPayload({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String bucket,
    required String path,
    required int expirySeconds,
    String? accessToken,
  }) {
    return {
      'supabaseUrl': supabaseUrl,
      'supabaseAnonKey': supabaseAnonKey,
      'bucket': bucket,
      'path': path,
      'expirySeconds': expirySeconds,
      'accessToken': accessToken,
    };
  }
}

/// Internal class for cached URL with expiry
class _CachedUrl {
  final String url;
  final DateTime expiresAt;

  _CachedUrl({
    required this.url,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

Future<String> _invokeSignedUrlInBackground(Map<String, dynamic> payload) {
  return compute<Map<String, dynamic>, String>(
    _createSignedUrlInIsolate,
    payload,
  );
}

Future<String> _createSignedUrlInIsolate(Map<String, dynamic> request) {
  return _createSignedUrlInIsolateImpl(
    request['supabaseUrl'] as String,
    request['supabaseAnonKey'] as String,
    request['bucket'] as String,
    request['path'] as String,
    request['expirySeconds'] as int,
    request['accessToken'] as String?,
  );
}

/// Implementation of the isolate function for creating signed URLs
///
/// This is the actual function that runs in the worker isolate.
Future<String> _createSignedUrlInIsolateImpl(
  String supabaseUrl,
  String supabaseAnonKey,
  String bucket,
  String path,
  int expirySeconds,
  String? accessToken,
) async {
  try {
    // Create a new Supabase client in the isolate
    // This is safe because we're only using the URL and anon key
    // If accessToken is provided, pass it in headers to allow access to private buckets
    final headers = accessToken != null
        ? {'Authorization': 'Bearer $accessToken'}
        : <String, String>{};

    final supabase = SupabaseClient(
      supabaseUrl,
      supabaseAnonKey,
      headers: headers,
    );

    // Generate the signed URL
    final url = await supabase.storage.from(bucket).createSignedUrl(
          path,
          expirySeconds,
        );

    return url;
  } catch (e) {
    // Re-throw with context for better error messages
    throw Exception(
      'Failed to create signed URL in isolate: bucket=$bucket, path=$path, error=$e',
    );
  }
}
