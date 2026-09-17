import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class GoogleVideoProxy {
  static bool simulateLegacyError = false;
  static bool disableProxy = false;

  GoogleVideoProxy({
    required Uri targetUri,
    required Map<String, String> forwardHeaders,
  }) : _targetUri = targetUri,
       _forwardHeaders = Map.unmodifiable(forwardHeaders);

  final Uri _targetUri;
  final Map<String, String> _forwardHeaders;

  HttpServer? _server;
  HttpClient? _client;
  StreamSubscription<HttpRequest>? _subscription;
  Uri? _localUri;

  bool get isRunning => _server != null;
  Uri? get localUri => _localUri;
  int? get port => _server?.port;
  Uri get targetUri => _targetUri;
  Map<String, String> get forwardHeaders => _forwardHeaders;

  Future<Uri> start() async {
    if (_localUri != null && _server != null) {
      return _localUri!;
    }

    _client = _createHttpClient();

    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    String pathExtension = '.mp4';
    final targetStr = _targetUri.toString().toLowerCase();
    if (targetStr.contains('.m3u8') ||
        targetStr.contains('akumast.net') ||
        targetStr.contains('/m.jpg') ||
        targetStr.contains('/h.jpg') ||
        targetStr.contains('/p.jpg')) {
      pathExtension = '.m3u8';
    } else if (targetStr.contains('.mpd')) {
      pathExtension = '.mpd';
    }

    _localUri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: server.port,
      path: '/stream$pathExtension',
    );

    _subscription = server.listen(
      _handleRequest,
      onError: (error, stackTrace) {
        debugPrint('GoogleVideoProxy server error: $error');
        debugPrint('$stackTrace');
      },
    );

    debugPrint('GoogleVideoProxy started at $_localUri');
    return _localUri!;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;

    await _server?.close(force: true);
    _server = null;

    _client?.close(force: true);
    _client = null;

    _localUri = null;
  }

  HttpClient _createHttpClient() {
    final client = HttpClient();
    
    // Find User-Agent case-insensitively
    String? userAgent;
    for (final entry in _forwardHeaders.entries) {
      if (entry.key.toLowerCase() == 'user-agent') {
        userAgent = entry.value;
        break;
      }
    }

    if (userAgent != null && userAgent.isNotEmpty) {
      client.userAgent = userAgent;
    }
    client.autoUncompress = false;
    client.connectionTimeout = const Duration(seconds: 12);
    return client;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final client = _client ?? _createHttpClient();
    _client = client;

    final isStreamEndpoint = request.uri.path.startsWith('/stream');
    Uri currentTargetUri;
    if (isStreamEndpoint) {
      currentTargetUri = _targetUri;
    } else {
      // Sub-resource request (e.g. HLS sub-playlist or fMP4 segments)
      // Strip leading '/' so Uri.resolve preserves _targetUri's directory path!
      final rawPath = request.uri.path;
      final relPath = rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;
      currentTargetUri = _targetUri.resolve(relPath);
      debugPrint('GoogleVideoProxy resolved sub-resource: $rawPath -> $currentTargetUri');
    }

    HttpClientResponse? finalResponse;
    int redirectCount = 0;
    const maxRedirects = 5;

    while (redirectCount < maxRedirects) {
      HttpClientRequest upstreamRequest;
      try {
        upstreamRequest = await client.openUrl(request.method, currentTargetUri);
        upstreamRequest.followRedirects = simulateLegacyError;
      } catch (error, stackTrace) {
        debugPrint('GoogleVideoProxy upstream open error: $error');
        debugPrint('$stackTrace');
        return _failRequest(request, HttpStatus.badGateway, 'Proxy open error');
      }

      // Apply persisted headers on every redirect hop
      _forwardHeaders.forEach((key, value) {
        if (_shouldSkipRequestHeader(key)) return;
        upstreamRequest.headers.set(key, value);
      });

      // Forward range and other relevant headers from the local request.
      final forwardedHeaders = <String>[
        HttpHeaders.rangeHeader,
        HttpHeaders.acceptHeader,
        HttpHeaders.acceptLanguageHeader,
        HttpHeaders.acceptEncodingHeader,
      ];

      for (final headerName in forwardedHeaders) {
        final value = request.headers.value(headerName);
        if (value != null && value.isNotEmpty) {
          upstreamRequest.headers.set(headerName, value);
        }
      }

      // Ensure Accept-Encoding is identity if not overridden.
      if (upstreamRequest.headers.value(HttpHeaders.acceptEncodingHeader) ==
          null) {
        final encoding =
            _forwardHeaders[HttpHeaders.acceptEncodingHeader] ?? 'identity';
        upstreamRequest.headers.set(HttpHeaders.acceptEncodingHeader, encoding);
      }

      HttpClientResponse upstreamResponse;
      try {
        upstreamResponse = await upstreamRequest.close();
      } catch (error, stackTrace) {
        debugPrint('GoogleVideoProxy upstream request error: $error');
        debugPrint('$stackTrace');
        return _failRequest(request, HttpStatus.badGateway, 'Proxy fetch error');
      }

      final isRedirect = upstreamResponse.statusCode == HttpStatus.movedPermanently ||
          upstreamResponse.statusCode == HttpStatus.found ||
          upstreamResponse.statusCode == HttpStatus.seeOther ||
          upstreamResponse.statusCode == HttpStatus.temporaryRedirect ||
          upstreamResponse.statusCode == HttpStatus.permanentRedirect;

      if (isRedirect) {
        final location = upstreamResponse.headers.value(HttpHeaders.locationHeader);
        if (location != null && location.isNotEmpty) {
          final redirectUri = currentTargetUri.resolve(location);
          debugPrint('GoogleVideoProxy following redirect ($redirectCount): $currentTargetUri -> $redirectUri');
          await upstreamResponse.drain();
          currentTargetUri = redirectUri;
          redirectCount++;
          continue;
        }
      }

      finalResponse = upstreamResponse;
      break;
    }

    if (finalResponse == null) {
      return _failRequest(request, HttpStatus.badGateway, 'Too many redirects');
    }

    request.response.statusCode = finalResponse.statusCode;

    final targetLower = _targetUri.toString().toLowerCase();
    final isHlsManifest = isStreamEndpoint &&
        (request.uri.path.endsWith('.m3u8') ||
            currentTargetUri.path.endsWith('.m3u8') ||
            currentTargetUri.path.endsWith('/m.jpg') ||
            currentTargetUri.path.endsWith('/h.jpg') ||
            currentTargetUri.path.endsWith('/p.jpg') ||
            targetLower.contains('akumast.net'));

    final isSubPlaylist = !isStreamEndpoint &&
        (request.uri.path.endsWith('.m3u8') ||
            request.uri.path.endsWith('/p.jpg') ||
            currentTargetUri.path.endsWith('/p.jpg'));

    final isHlsSegment = !isStreamEndpoint &&
        !isSubPlaylist &&
        (request.uri.path.endsWith('.jpg') ||
            request.uri.path.endsWith('.ts') ||
            request.uri.path.endsWith('.m4s'));

    final isDashManifest = isStreamEndpoint &&
        request.uri.path.endsWith('.mpd') &&
        !isHlsManifest;

    finalResponse.headers.forEach((name, values) {
      if (_shouldSkipResponseHeader(
        name,
        isHlsManifest: isHlsManifest || isSubPlaylist,
        isDashManifest: isDashManifest,
      )) {
        return;
      }
      for (final value in values) {
        request.response.headers.add(name, value);
      }
    });

    // Add CORS headers for web/mobile players
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    request.response.headers.set('Access-Control-Allow-Headers', '*');

    if (isHlsManifest || isSubPlaylist) {
      request.response.headers.contentType =
          ContentType('application', 'vnd.apple.mpegurl');
    } else if (isDashManifest) {
      request.response.headers.contentType =
          ContentType('application', 'dash+xml');
    } else if (isHlsSegment && targetLower.contains('akumast.net')) {
      request.response.headers.contentType =
          ContentType('video', 'mp4');
    }

    try {
      if (request.method == 'HEAD') {
        await finalResponse.drain();
        await request.response.close();
      } else {
        await finalResponse.pipe(request.response);
      }
    } catch (error, stackTrace) {
      debugPrint('GoogleVideoProxy piping error: $error');
      debugPrint('$stackTrace');
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  bool _shouldSkipRequestHeader(String name) {
    final lower = name.toLowerCase();
    return lower == 'connection' ||
        lower == 'host' ||
        lower == 'content-length' ||
        lower == 'accept-encoding';
  }

  bool _shouldSkipResponseHeader(
    String name, {
    bool isHlsManifest = false,
    bool isDashManifest = false,
  }) {
    final lower = name.toLowerCase();
    if ((isHlsManifest || isDashManifest) && lower == 'content-type') {
      return true;
    }
    return lower == 'connection' || lower == 'transfer-encoding';
  }

  Future<void> _failRequest(
    HttpRequest request,
    int statusCode,
    String message,
  ) async {
    request.response.statusCode = statusCode;
    request.response.write(message);
    await request.response.close();
  }
}
