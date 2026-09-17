import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Centralized configuration and request helper for NekoCast Backend API
class BackendConfig {
  static String? _cachedWorkingBaseUrl;
  static DateTime? _lastHealthCheck;

  static List<String> get candidateBaseUrls {
    if (kIsWeb) {
      return [
        'http://localhost:8080',
        'https://nekocast.discloud.app',
        'https://nekocast.discloud.site',
      ];
    }

    final isAndroid = !kIsWeb && Platform.isAndroid;
    return [
      if (isAndroid) 'http://10.0.2.2:8080',
      'http://localhost:8080',
      'https://nekocast.discloud.app',
      'https://nekocast.discloud.site',
    ];
  }

  /// Returns the fastest available working backend base URL
  static Future<String?> getWorkingBaseUrl({Duration timeout = const Duration(milliseconds: 1800)}) async {
    // If cached within last 3 minutes and working, return it
    if (_cachedWorkingBaseUrl != null &&
        _lastHealthCheck != null &&
        DateTime.now().difference(_lastHealthCheck!).inMinutes < 3) {
      return _cachedWorkingBaseUrl;
    }

    // Try candidates in order
    for (final base in candidateBaseUrls) {
      try {
        final res = await http.get(Uri.parse('$base/health')).timeout(timeout);
        if (res.statusCode == 200) {
          _cachedWorkingBaseUrl = base;
          _lastHealthCheck = DateTime.now();
          return base;
        }
      } catch (_) {
        // Silently skip offline or unreachable candidates
      }
    }

    // Fallback: return first candidate
    return candidateBaseUrls.first;
  }

  /// Makes a resilient GET request trying available backend URLs
  static Future<http.Response?> get(
    String path, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final cleanPath = path.startsWith('/') ? path : '/$path';

    // If we have a cached working base, try it first
    if (_cachedWorkingBaseUrl != null) {
      try {
        final url = Uri.parse('$_cachedWorkingBaseUrl$cleanPath');
        final res = await http.get(url, headers: headers).timeout(timeout);
        if (res.statusCode == 200) {
          return res;
        }
      } catch (_) {
        _cachedWorkingBaseUrl = null; // Invalidate cache on failure
      }
    }

    // Iterate through candidates with quick timeout
    for (final base in candidateBaseUrls) {
      try {
        final url = Uri.parse('$base$cleanPath');
        final res = await http.get(url, headers: headers).timeout(timeout);
        if (res.statusCode == 200) {
          _cachedWorkingBaseUrl = base;
          _lastHealthCheck = DateTime.now();
          return res;
        }
      } catch (_) {
        // Next candidate
      }
    }

    return null;
  }
}
