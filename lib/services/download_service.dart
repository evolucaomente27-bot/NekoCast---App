import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../main.dart' show AnimeService;
import 'allanime_service.dart';

/// Download status enum
enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

/// Download quality enum
enum DownloadQuality {
  auto,
  low, // 480p
  medium, // 720p
  high, // 1080p
}

/// Download item model
class DownloadItem {
  final String id;
  final String animeId;
  final String animeName;
  final String episodeNumber;
  final String episodeTitle;
  final String videoUrl;
  final String thumbnailUrl;
  final DownloadQuality quality;
  DownloadStatus status;
  double progress;
  int bytesDownloaded;
  int totalBytes;
  String? filePath;
  String? error;
  DateTime createdAt;
  DateTime? completedAt;

  DownloadItem({
    required this.id,
    required this.animeId,
    required this.animeName,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.videoUrl,
    required this.thumbnailUrl,
    this.quality = DownloadQuality.auto,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.filePath,
    this.error,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'animeId': animeId,
      'animeName': animeName,
      'episodeNumber': episodeNumber,
      'episodeTitle': episodeTitle,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'quality': quality.index,
      'status': status.index,
      'progress': progress,
      'bytesDownloaded': bytesDownloaded,
      'totalBytes': totalBytes,
      'filePath': filePath,
      'error': error,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
    };
  }

  factory DownloadItem.fromMap(Map<String, dynamic> map) {
    return DownloadItem(
      id: map['id'],
      animeId: map['animeId'],
      animeName: map['animeName'],
      episodeNumber: map['episodeNumber'],
      episodeTitle: map['episodeTitle'],
      videoUrl: map['videoUrl'],
      thumbnailUrl: map['thumbnailUrl'],
      quality: DownloadQuality.values[map['quality']],
      status: DownloadStatus.values[map['status']],
      progress: map['progress'],
      bytesDownloaded: map['bytesDownloaded'],
      totalBytes: map['totalBytes'],
      filePath: map['filePath'],
      error: map['error'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
          : null,
    );
  }

  DownloadItem copyWith({
    DownloadStatus? status,
    double? progress,
    int? bytesDownloaded,
    int? totalBytes,
    String? filePath,
    String? error,
    DateTime? completedAt,
  }) {
    return DownloadItem(
      id: id,
      animeId: animeId,
      animeName: animeName,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      quality: quality,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      filePath: filePath ?? this.filePath,
      error: error ?? this.error,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class _ResolvedDownloadStream {
  final String url;
  final Map<String, String> headers;

  const _ResolvedDownloadStream({required this.url, required this.headers});
}

/// Download service - manages all download operations
class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  Database? _database;
  Future<void>? _initializationFuture;
  final Map<String, DownloadItem> _downloads = {};
  final Map<String, StreamSubscription> _activeDownloads = {};
  final Map<String, http.Client> _downloadClients = {};
  int _maxConcurrentDownloads = 3;
  int _activeDownloadCount = 0;

  List<DownloadItem> get downloads => _downloads.values.toList();
  List<DownloadItem> get activeDownloads => _downloads.values
      .where(
        (d) =>
            d.status == DownloadStatus.downloading ||
            d.status == DownloadStatus.queued,
      )
      .toList();
  List<DownloadItem> get completedDownloads => _downloads.values
      .where((d) => d.status == DownloadStatus.completed)
      .toList();

  int get maxConcurrentDownloads => _maxConcurrentDownloads;
  set maxConcurrentDownloads(int value) {
    _maxConcurrentDownloads = value.clamp(1, 5);
    notifyListeners();
  }

  /// Initialize the download service
  Future<void> initialize() async {
    _initializationFuture ??= _initialize();
    return _initializationFuture!;
  }

  Future<void> _initialize() async {
    _database = await _initDatabase();
    await _loadDownloads();
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(documentsDirectory.path, 'downloads.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE downloads (
            id TEXT PRIMARY KEY,
            animeId TEXT NOT NULL,
            animeName TEXT NOT NULL,
            episodeNumber TEXT NOT NULL,
            episodeTitle TEXT NOT NULL,
            videoUrl TEXT NOT NULL,
            thumbnailUrl TEXT NOT NULL,
            quality INTEGER NOT NULL,
            status INTEGER NOT NULL,
            progress REAL NOT NULL,
            bytesDownloaded INTEGER NOT NULL,
            totalBytes INTEGER NOT NULL,
            filePath TEXT,
            error TEXT,
            createdAt INTEGER NOT NULL,
            completedAt INTEGER
          )
        ''');
      },
    );
  }

  /// Load downloads from database
  Future<void> _loadDownloads() async {
    if (_database == null) {
      return;
    }

    final List<Map<String, dynamic>> maps = await _database!.query('downloads');
    _downloads.clear();

    for (var map in maps) {
      final download = DownloadItem.fromMap(map);
      _downloads[download.id] = download;

      // Reset downloading status to queued on app restart
      if (download.status == DownloadStatus.downloading) {
        _downloads[download.id] = download.copyWith(
          status: DownloadStatus.queued,
        );
      }
    }

    notifyListeners();
  }

  /// Add a download to the queue
  Future<String> addDownload({
    required String animeId,
    required String animeName,
    required String episodeNumber,
    required String episodeTitle,
    required String videoUrl,
    required String thumbnailUrl,
    DownloadQuality quality = DownloadQuality.auto,
  }) async {
    await initialize();
    final id = '${animeId}_$episodeNumber';

    // Check if already exists
    if (_downloads.containsKey(id)) {
      final existing = _downloads[id]!;
      if (existing.status == DownloadStatus.completed) {
        throw Exception('Episode already downloaded');
      }
      if (existing.status == DownloadStatus.downloading ||
          existing.status == DownloadStatus.queued) {
        throw Exception('Episode is already in download queue');
      }
      // If failed or cancelled, allow re-download
      await deleteDownload(id);
    }

    final download = DownloadItem(
      id: id,
      animeId: animeId,
      animeName: animeName,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      quality: quality,
    );

    _downloads[id] = download;
    await _saveDownload(download);

    notifyListeners();
    _processQueue();

    return id;
  }

  /// Add multiple downloads (batch download)
  Future<List<String>> addBatchDownloads({
    required String animeId,
    required String animeName,
    required List<Map<String, String>> episodes,
    required String thumbnailUrl,
    DownloadQuality quality = DownloadQuality.auto,
  }) async {
    final List<String> downloadIds = [];

    for (var episode in episodes) {
      try {
        final id = await addDownload(
          animeId: animeId,
          animeName: animeName,
          episodeNumber: episode['number']!,
          episodeTitle: episode['title'] ?? 'Episode ${episode['number']}',
          videoUrl: episode['url']!,
          thumbnailUrl: thumbnailUrl,
          quality: quality,
        );
        downloadIds.add(id);
      } catch (e) {
        debugPrint('Failed to add episode ${episode['number']}: $e');
      }
    }

    return downloadIds;
  }

  /// Process the download queue
  void _processQueue() {
    if (_activeDownloadCount >= _maxConcurrentDownloads) {
      return;
    }

    final queuedDownloads =
        _downloads.values
            .where((d) => d.status == DownloadStatus.queued)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (var download in queuedDownloads) {
      if (_activeDownloadCount >= _maxConcurrentDownloads) break;
      _startDownload(download.id);
    }
  }

  /// Start a download
  Future<void> _startDownload(String id) async {
    final download = _downloads[id];
    if (download == null) {
      return;
    }

    _activeDownloadCount++;
    _downloads[id] = download.copyWith(status: DownloadStatus.downloading);
    await _saveDownload(_downloads[id]!);
    notifyListeners();

    try {
      // Check if this is an AllAnime episode (videoUrl is just episode number)
      final isAllAnimeEpisode =
          !download.videoUrl.startsWith('http') &&
          int.tryParse(download.videoUrl) != null;

      if (!isAllAnimeEpisode) {
        // Validate URL for AnimeFire - must be a full URL
        final Uri uri;
        try {
          uri = Uri.parse(download.videoUrl);
          if (!uri.hasScheme ||
              (uri.scheme != 'http' && uri.scheme != 'https')) {
            throw Exception('Invalid URL format');
          }
          if (uri.host.isEmpty) {
            throw Exception('Invalid URL format');
          }
        } catch (e) {
          if (e.toString().contains('Invalid URL format')) {
            rethrow;
          }
          throw Exception('Invalid video URL: ${download.videoUrl}');
        }
      }

      // Start the download (URL resolution happens in _downloadHttp)
      await _downloadHttp(id);
    } catch (e) {
      debugPrint('Download error for $id: $e');
      _downloads[id] = download.copyWith(
        status: DownloadStatus.failed,
        error: e.toString(),
      );
      await _saveDownload(_downloads[id]!);
    } finally {
      _activeDownloadCount--;
      _activeDownloads.remove(id);
      _downloadClients.remove(id);
      notifyListeners();
      _processQueue();
    }
  }

  /// Download via HTTP
  Future<void> _downloadHttp(String id) async {
    final download = _downloads[id];
    if (download == null) {
      return;
    }

    debugPrint('[Download] Starting download for $id');
    debugPrint('[Download] Episode URL: ${download.videoUrl}');
    debugPrint('[Download] Anime ID: ${download.animeId}');

    // Resolve the actual video URL (extract from page and get direct link)
    late _ResolvedDownloadStream resolvedStream;
    try {
      debugPrint('[Download] Resolving video URL...');

      // Check if this is an AllAnime episode (videoUrl is just episode number)
      final isAllAnimeEpisode =
          !download.videoUrl.startsWith('http') &&
          int.tryParse(download.videoUrl) != null;

      if (isAllAnimeEpisode) {
        // AllAnime: use AllAnimeService to get video URL
        debugPrint(
          '[Download] Detected AllAnime episode, fetching video URL...',
        );

        // animeId is the AllAnime show ID (e.g., "8sB7F65RGSQ3dMjYa")
        final animeShowId = download.animeId;
        final episodeNumber = download.videoUrl;

        debugPrint(
          '[Download] AllAnime Show ID: $animeShowId, Episode: $episodeNumber',
        );

        final videoUrl = await AllAnimeService.getEpisodeURL(
          animeShowId,
          episodeNumber,
        );

        if (videoUrl == null || videoUrl.isEmpty) {
          throw Exception('Failed to get video URL from AllAnime');
        }

        debugPrint('[Download] AllAnime video URL: $videoUrl');

        // We no longer block HLS early, we handle it later

        final videoResult = await AnimeService.extractActualVideoURL(
          videoUrl,
          referer: 'https://allanime.to/',
          fallbackHeaders: _defaultDownloadHeaders(
            referer: 'https://allanime.to/',
          ),
        );
        resolvedStream = _ResolvedDownloadStream(
          url: videoResult.url,
          headers: _mergeHeaders(
            _defaultDownloadHeaders(referer: 'https://allanime.to/'),
            videoResult.headers,
          ),
        );

        if (resolvedStream.url.contains('.m3u8') ||
            resolvedStream.url.contains('master.m3u8')) {
          await _downloadHls(id, resolvedStream);
          return;
        }
      } else {
        // AnimeFire: use AnimeService URL extraction
        debugPrint(
          '[Download] Detected AnimeFire episode, extracting video URL...',
        );

        // Step 1: Extract video source from episode page
        final videoSrc = await AnimeService.extractVideoURL(download.videoUrl);
        debugPrint('[Download] Extracted video source: $videoSrc');

        // We no longer block HLS early, we handle it later

        // Step 2: Get the actual video URL
        final videoResult = await AnimeService.extractActualVideoURL(
          videoSrc,
          referer: 'https://animefire.plus/',
          fallbackHeaders: _defaultDownloadHeaders(
            referer: 'https://animefire.plus/',
          ),
        );
        resolvedStream = _ResolvedDownloadStream(
          url: videoResult.url,
          headers: _mergeHeaders(
            _defaultDownloadHeaders(referer: 'https://animefire.plus/'),
            videoResult.headers,
          ),
        );
        debugPrint('[Download] Resolved video URL: ${resolvedStream.url}');

        // Final check for HLS
        if (resolvedStream.url.contains('.m3u8') ||
            resolvedStream.url.contains('master.m3u8')) {
          await _downloadHls(id, resolvedStream);
          return;
        }
      }
    } catch (e) {
      throw Exception('Failed to get video URL: $e');
    }

    // Create download directory
    final downloadDir = await _getDownloadDirectory();
    final safeAnimeName = _sanitizeFileName(download.animeName);
    final animeDir = Directory(path.join(downloadDir.path, safeAnimeName));
    await animeDir.create(recursive: true);

    final fileName = 'Episode_${download.episodeNumber}.mp4';
    final filePath = path.join(animeDir.path, fileName);
    debugPrint('[Download] Saving to: $filePath');

    _downloads[id] = _downloads[id]!.copyWith(filePath: filePath);
    await _saveDownload(_downloads[id]!);

    // Create HTTP client
    final client = http.Client();
    _downloadClients[id] = client;

    try {
      final file = File(filePath);
      final existingBytes = await file.exists() ? await file.length() : 0;

      // Get content length first
      debugPrint('[Download] Getting content length...');
      final totalBytes = await _getRemoteFileSize(
        client,
        resolvedStream.url,
        resolvedStream.headers,
      );
      debugPrint(
        '[Download] Total size: $totalBytes bytes (${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB)',
      );

      // Start streaming download
      debugPrint('[Download] Starting stream...');
      final canResume = existingBytes > 0 && totalBytes > existingBytes;
      final request = http.Request('GET', Uri.parse(resolvedStream.url));
      request.headers.addAll(
        _downloadRequestHeaders(
          resolvedStream.headers,
          rangeStart: canResume ? existingBytes : null,
        ),
      );
      final response = await client.send(request);

      if (canResume && response.statusCode == HttpStatus.ok) {
        debugPrint('[Download] Server ignored Range request; restarting file.');
        await file.writeAsBytes(const []);
      } else if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw Exception('Failed to download: ${response.statusCode}');
      }

      _validateDownloadResponse(response);

      final startBytes = response.statusCode == HttpStatus.partialContent
          ? existingBytes
          : 0;
      final sink = file.openWrite(
        mode: startBytes > 0 ? FileMode.append : FileMode.write,
      );
      int bytesDownloaded = startBytes;
      int lastNotificationBytes = 0;
      int lastSaveBytes = startBytes;
      const notificationInterval = 256 * 1024; // 256KB
      const saveInterval = 1024 * 1024; // 1MB

      await for (var chunk in response.stream) {
        // Check if download was cancelled
        if (!_downloads.containsKey(id) ||
            _downloads[id]!.status == DownloadStatus.cancelled) {
          await sink.close();
          await file.delete();
          return;
        }

        // Check if download was paused
        if (_downloads[id]!.status == DownloadStatus.paused) {
          await sink.close();
          return;
        }

        sink.add(chunk);
        bytesDownloaded += chunk.length;

        // Update progress in memory
        final progress = totalBytes > 0 ? bytesDownloaded / totalBytes : 0.0;
        _downloads[id] = _downloads[id]!.copyWith(
          progress: progress,
          bytesDownloaded: bytesDownloaded,
          totalBytes: totalBytes > 0 ? totalBytes : bytesDownloaded,
        );

        // Notify UI every 256KB
        if (bytesDownloaded - lastNotificationBytes >= notificationInterval) {
          lastNotificationBytes = bytesDownloaded;
          notifyListeners();
        }

        // Save to DB and log every 1MB or 1%
        final shouldSave = totalBytes > 0
            ? (totalBytes >= 100 &&
                  (bytesDownloaded - lastSaveBytes) >= (totalBytes ~/ 100))
            : ((bytesDownloaded - lastSaveBytes) >= saveInterval);

        if (shouldSave) {
          lastSaveBytes = bytesDownloaded;
          debugPrint(
            '[Download] Progress: ${(progress * 100).toStringAsFixed(1)}% (${(bytesDownloaded / 1024 / 1024).toStringAsFixed(2)} MB)',
          );
          await _saveDownload(_downloads[id]!);
        }
      }

      await sink.flush();
      await sink.close();

      if (totalBytes > 0 && bytesDownloaded < totalBytes) {
        throw Exception(
          'Download incomplete: ${formatBytes(bytesDownloaded)} of ${formatBytes(totalBytes)}',
        );
      }

      debugPrint('[Download] Download completed: $id');
      debugPrint('[Download] File saved to: $filePath');

      // Download completed
      _downloads[id] = _downloads[id]!.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        filePath: filePath,
        completedAt: DateTime.now(),
      );
      await _saveDownload(_downloads[id]!);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Resolve relative URL against base URL
  String _resolveUrl(String relativeUrl, String baseUrl) {
    if (relativeUrl.startsWith('http://') ||
        relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }
    final baseUri = Uri.parse(baseUrl);
    return baseUri.resolve(relativeUrl).toString();
  }

  /// Download HLS stream (m3u8)
  Future<void> _downloadHls(
    String id,
    _ResolvedDownloadStream resolvedStream,
  ) async {
    final download = _downloads[id];
    if (download == null) return;

    debugPrint('[Download] Starting HLS download for $id');
    final client = http.Client();
    _downloadClients[id] = client;

    try {
      // 1. Fetch the m3u8 playlist
      String playlistUrl = resolvedStream.url;
      var response = await client.get(
        Uri.parse(playlistUrl),
        headers: resolvedStream.headers,
      );
      if (response.statusCode != HttpStatus.ok) {
        throw Exception(
          'Failed to fetch m3u8 playlist: ${response.statusCode}',
        );
      }

      String playlistContent = response.body;

      // 2. Check if it's a master playlist (contains other m3u8 files)
      if (playlistContent.contains('#EXT-X-STREAM-INF')) {
        debugPrint('[Download] Found master playlist, finding best quality...');
        final lines = playlistContent.split('\n');
        String bestStreamUrl = '';
        int maxBandwidth = 0;

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('#EXT-X-STREAM-INF')) {
            // Try to extract bandwidth
            final bandwidthMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
            if (bandwidthMatch != null) {
              final bandwidth = int.parse(bandwidthMatch.group(1)!);
              if (bandwidth > maxBandwidth && i + 1 < lines.length) {
                maxBandwidth = bandwidth;
                bestStreamUrl = lines[i + 1].trim();
              }
            } else if (bestStreamUrl.isEmpty && i + 1 < lines.length) {
              // Fallback if no bandwidth specified
              bestStreamUrl = lines[i + 1].trim();
            }
          }
        }

        if (bestStreamUrl.isNotEmpty) {
          playlistUrl = _resolveUrl(bestStreamUrl, playlistUrl);
          debugPrint('[Download] Selected stream playlist: $playlistUrl');
          response = await client.get(
            Uri.parse(playlistUrl),
            headers: resolvedStream.headers,
          );
          if (response.statusCode != HttpStatus.ok) {
            throw Exception(
              'Failed to fetch stream playlist: ${response.statusCode}',
            );
          }
          playlistContent = response.body;
        } else {
          throw Exception('Could not parse master playlist properly.');
        }
      }

      // 3. Extract .ts segment URLs
      final lines = playlistContent.split('\n');
      final segmentUrls = <String>[];
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
          segmentUrls.add(_resolveUrl(trimmed, playlistUrl));
        }
      }

      if (segmentUrls.isEmpty) {
        throw Exception('No segments found in the playlist.');
      }

      debugPrint(
        '[Download] Found ${segmentUrls.length} segments to download.',
      );

      // 4. Create file
      final downloadDir = await _getDownloadDirectory();
      final safeAnimeName = _sanitizeFileName(download.animeName);
      final animeDir = Directory(path.join(downloadDir.path, safeAnimeName));
      await animeDir.create(recursive: true);

      final fileName = 'Episode_${download.episodeNumber}.ts'; // Saving as .ts
      final filePath = path.join(animeDir.path, fileName);
      debugPrint('[Download] Saving to: $filePath');

      _downloads[id] = _downloads[id]!.copyWith(
        filePath: filePath,
        totalBytes: segmentUrls.length,
        bytesDownloaded: 0,
        progress: 0.0,
      );
      await _saveDownload(_downloads[id]!);

      final file = File(filePath);
      // Determine starting segment if resuming
      int startSegment = 0;
      // We don't support simple resume for HLS right now because we don't track which segments are downloaded.
      // So we will overwrite if it exists.
      if (await file.exists()) {
        await file.delete();
      }

      final sink = file.openWrite();

      for (int i = startSegment; i < segmentUrls.length; i++) {
        // Check if download was cancelled or paused
        if (!_downloads.containsKey(id) ||
            _downloads[id]!.status == DownloadStatus.cancelled) {
          await sink.close();
          await file.delete();
          return;
        }
        if (_downloads[id]!.status == DownloadStatus.paused) {
          await sink.close();
          return;
        }

        final segmentUrl = segmentUrls[i];
        try {
          final segResponse = await client.get(
            Uri.parse(segmentUrl),
            headers: resolvedStream.headers,
          );
          if (segResponse.statusCode == HttpStatus.ok) {
            sink.add(segResponse.bodyBytes);
          } else {
            throw Exception(
              'Failed to download segment $i: HTTP ${segResponse.statusCode}',
            );
          }
        } catch (e) {
          throw Exception('Error downloading segment $i: $e');
        }

        // Update progress
        _downloads[id] = _downloads[id]!.copyWith(
          progress: (i + 1) / segmentUrls.length,
          bytesDownloaded: i + 1, // Using segments as bytes for HLS progress
          totalBytes: segmentUrls.length,
        );

        // Notify every 5 segments or at the end
        if (i % 5 == 0 || i == segmentUrls.length - 1) {
          notifyListeners();
          await _saveDownload(_downloads[id]!);
        }
      }

      await sink.flush();
      await sink.close();

      debugPrint('[Download] HLS Download completed: $id');

      // Mark as completed
      _downloads[id] = _downloads[id]!.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        filePath: filePath,
        completedAt: DateTime.now(),
      );
      await _saveDownload(_downloads[id]!);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Pause a download
  Future<void> pauseDownload(String id) async {
    final download = _downloads[id];
    if (download == null || download.status != DownloadStatus.downloading) {
      return;
    }

    _downloads[id] = download.copyWith(status: DownloadStatus.paused);
    await _saveDownload(_downloads[id]!);
    notifyListeners();
  }

  /// Resume a download
  Future<void> resumeDownload(String id) async {
    final download = _downloads[id];
    if (download == null || download.status != DownloadStatus.paused) {
      return;
    }

    _downloads[id] = download.copyWith(status: DownloadStatus.queued);
    await _saveDownload(_downloads[id]!);
    notifyListeners();
    _processQueue();
  }

  /// Cancel a download
  Future<void> cancelDownload(String id) async {
    final download = _downloads[id];
    if (download == null) {
      return;
    }

    _downloads[id] = download.copyWith(status: DownloadStatus.cancelled);
    _downloadClients[id]?.close();
    await _saveDownload(_downloads[id]!);

    // Delete partial file
    if (download.filePath != null) {
      final file = File(download.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    notifyListeners();
  }

  /// Retry a failed download
  Future<void> retryDownload(String id) async {
    final download = _downloads[id];
    if (download == null || download.status != DownloadStatus.failed) {
      return;
    }

    _downloads[id] = download.copyWith(
      status: DownloadStatus.queued,
      error: null,
      progress: 0,
      bytesDownloaded: 0,
    );
    await _saveDownload(_downloads[id]!);
    notifyListeners();
    _processQueue();
  }

  /// Delete a download
  Future<void> deleteDownload(String id) async {
    final download = _downloads[id];
    if (download == null) {
      return;
    }

    // Cancel if active
    if (download.status == DownloadStatus.downloading) {
      await cancelDownload(id);
    }

    // Delete file
    if (download.filePath != null) {
      final file = File(download.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Remove from database
    await _database?.delete('downloads', where: 'id = ?', whereArgs: [id]);
    _downloads.remove(id);
    notifyListeners();
  }

  /// Clear all completed downloads
  Future<void> clearCompleted() async {
    final completed = _downloads.values
        .where((d) => d.status == DownloadStatus.completed)
        .toList();

    for (var download in completed) {
      await deleteDownload(download.id);
    }
  }

  /// Clear all failed downloads
  Future<void> clearFailedDownloads() async {
    final failed = _downloads.values
        .where(
          (d) =>
              d.status == DownloadStatus.failed ||
              d.status == DownloadStatus.cancelled,
        )
        .toList();

    for (var download in failed) {
      await deleteDownload(download.id);
    }
  }

  /// Get download by ID
  DownloadItem? getDownload(String id) => _downloads[id];

  /// Get downloads for an anime
  List<DownloadItem> getAnimeDownloads(String animeId) {
    return _downloads.values.where((d) => d.animeId == animeId).toList()
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
  }

  /// Save download to database
  Future<void> _saveDownload(DownloadItem download) async {
    await _database?.insert(
      'downloads',
      download.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, String> _defaultDownloadHeaders({String? referer}) {
    return {
      HttpHeaders.userAgentHeader:
          'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
      HttpHeaders.acceptHeader: 'video/mp4,video/*;q=0.9,*/*;q=0.8',
      HttpHeaders.acceptLanguageHeader: 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
      HttpHeaders.acceptEncodingHeader: 'identity',
      if (referer != null && referer.isNotEmpty)
        HttpHeaders.refererHeader: referer,
    };
  }

  Map<String, String> _mergeHeaders(
    Map<String, String> baseHeaders,
    Map<String, String> overrideHeaders,
  ) {
    final headers = Map<String, String>.from(baseHeaders);
    overrideHeaders.forEach((key, value) {
      if (value.isNotEmpty) {
        headers[key] = value;
      }
    });
    return headers;
  }

  Map<String, String> _downloadRequestHeaders(
    Map<String, String> headers, {
    int? rangeStart,
  }) {
    final requestHeaders = Map<String, String>.from(headers);
    requestHeaders[HttpHeaders.acceptEncodingHeader] = 'identity';
    if (rangeStart != null && rangeStart > 0) {
      requestHeaders[HttpHeaders.rangeHeader] = 'bytes=$rangeStart-';
    }
    return requestHeaders;
  }

  Future<int> _getRemoteFileSize(
    http.Client client,
    String url,
    Map<String, String> headers,
  ) async {
    try {
      final headResponse = await client
          .head(Uri.parse(url), headers: _downloadRequestHeaders(headers))
          .timeout(const Duration(seconds: 15));
      final contentLength = int.tryParse(
        headResponse.headers[HttpHeaders.contentLengthHeader] ?? '',
      );
      if (headResponse.statusCode < 400 && contentLength != null) {
        return contentLength;
      }
    } catch (e) {
      debugPrint('[Download] HEAD failed, trying ranged GET: $e');
    }

    final request = http.Request('GET', Uri.parse(url));
    request.headers.addAll(_downloadRequestHeaders(headers, rangeStart: 0));
    request.headers[HttpHeaders.rangeHeader] = 'bytes=0-0';
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 15));
    await response.stream.drain();

    final contentRange = response.headers[HttpHeaders.contentRangeHeader];
    if (contentRange != null) {
      final totalMatch = RegExp(r'/(\d+)$').firstMatch(contentRange);
      final total = int.tryParse(totalMatch?.group(1) ?? '');
      if (total != null) {
        return total;
      }
    }

    return int.tryParse(
          response.headers[HttpHeaders.contentLengthHeader] ?? '',
        ) ??
        0;
  }

  void _validateDownloadResponse(http.StreamedResponse response) {
    final contentType =
        response.headers[HttpHeaders.contentTypeHeader]?.toLowerCase() ?? '';
    if (contentType.contains('text/html') ||
        contentType.contains('application/json')) {
      throw Exception(
        'Server returned $contentType instead of video. Try another source or retry later.',
      );
    }
  }

  /// Get download directory
  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      return Directory(path.join(directory!.path, 'NekoCast', 'Downloads'));
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return Directory(path.join(directory.path, 'Downloads'));
    }
  }

  /// Sanitize file name
  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  /// Get total download size
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Dispose resources
  @override
  void dispose() {
    for (var client in _downloadClients.values) {
      client.close();
    }
    _downloadClients.clear();
    _activeDownloads.clear();
    super.dispose();
  }
}
