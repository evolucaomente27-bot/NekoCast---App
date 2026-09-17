import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'widgets/desktop_video_player.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'models/anilist_models.dart';
import 'services/anilist_service.dart';
import 'services/allanime_service.dart';
import 'services/locale_service.dart';
import 'services/episode_thumbnail_service.dart';
import 'services/player_service.dart';
import 'services/playback_wake_lock.dart';
import 'services/watch_history_service.dart';
import 'package:media_kit/media_kit.dart';
import 'l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/video_player_screen.dart';
import 'services/download_service.dart';
import 'services/manga_service.dart';
import 'services/doh_service.dart';
import 'services/tv_mode_service.dart';
import 'theme/app_colors.dart';
import 'utils/performance_config.dart';
import 'google_video_proxy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    debugPrint('[MediaKit] Initialization warning: $e');
  }

  // InicializaÃ§Ã£o do SQLite FFI para plataformas Desktop (Windows/Linux/macOS)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Inicializa serviÃ§o DoH e sobrescreve resoluÃ§Ã£o HTTP globalmente
  final dohService = DohService();
  await dohService.load();
  HttpOverrides.global = DohHttpOverrides(dohService);

  // Inicializa serviÃ§o de Modo TV / Fire Stick
  final tvModeService = TvModeService();
  await tvModeService.initialize();

  // Inicializa configuraÃ§Ãµes de performance
  PerformanceConfig.init();

  final downloadService = DownloadService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleService()),
        ChangeNotifierProvider(create: (_) => MangaService()),
        ChangeNotifierProvider(create: (_) => WatchHistoryService()..load()),
        ChangeNotifierProvider(create: (_) => PlayerService()..load()),
        ChangeNotifierProvider.value(value: dohService),
        ChangeNotifierProvider.value(value: downloadService),
        ChangeNotifierProvider.value(value: tvModeService),
      ],
      child: const MyApp(),
    ),
  );

  unawaited(
    downloadService.initialize().catchError((error, stackTrace) {
      debugPrint('Download service initialization failed: $error');
      debugPrint('$stackTrace');
    }),
  );
}

// Logo Widget Helper
class LogoWidget extends StatelessWidget {
  final double size;
  final Color? color;

  const LogoWidget({super.key, this.size = 80, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.getPrimaryGradient(),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: (color ?? AppColors.primary).withValues(alpha: 0.28),
            blurRadius: size * 0.16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.inventory_2_rounded,
        size: size * 0.58,
        color: Colors.white,
      ),
    );
  }
}

// Theme Provider
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true; // Dark theme by default

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}

// Models
class Episode {
  final String number;
  final String url;
  final String? thumbnail;
  final String? title;
  final String? description;
  final String? audioType;

  Episode({
    required this.number,
    required this.url,
    this.thumbnail,
    this.title,
    this.description,
    this.audioType,
  });

  @override
  String toString() => number;

  bool get isDubbed => audioType?.toLowerCase().contains('dub') ?? false;
  bool get isSubbed => audioType?.toLowerCase().contains('leg') ?? false;

  /// Get episode thumbnail URL
  String? getImageUrl() => thumbnail;
}

/// Stream Episode List Item with enhanced metadata
class StreamEpisodeListItem {
  final String episodeNumber;
  final String? thumbnailUrl;
  final String? title;
  final String? description;
  final String? url;
  final Duration? duration;
  final DateTime? airDate;

  StreamEpisodeListItem({
    required this.episodeNumber,
    this.thumbnailUrl,
    this.title,
    this.description,
    this.url,
    this.duration,
    this.airDate,
  });

  /// Get episode thumbnail image URL
  String? getImageUrl() => thumbnailUrl;

  /// Convert to Episode for compatibility
  Episode toEpisode() {
    return Episode(
      number: episodeNumber,
      url: url ?? '',
      thumbnail: thumbnailUrl,
      title: title,
      description: description,
    );
  }

  factory StreamEpisodeListItem.fromJson(Map<String, dynamic> json) {
    return StreamEpisodeListItem(
      episodeNumber:
          json['episodeNumber']?.toString() ?? json['number']?.toString() ?? '',
      thumbnailUrl: json['thumbnail'] ?? json['thumbnailUrl'] ?? json['image'],
      title: json['title'] ?? json['name'],
      description: json['description'] ?? json['synopsis'],
      url: json['url'],
      duration: json['duration'] != null
          ? Duration(
              seconds: json['duration'] is int
                  ? json['duration']
                  : int.tryParse(json['duration'].toString()) ?? 0,
            )
          : null,
      airDate: json['airDate'] != null
          ? DateTime.tryParse(json['airDate'].toString())
          : null,
    );
  }
}

enum AnimeSource {
  animeFire,
  allAnime,
  hiAnime,
  consumet,
  sugoi,
  anify,
  animesOnline,
  animesOrion,
  animesDigital,
}

class Anime {
  final String name;
  final String url;
  final AnimeSource source;
  final String? allAnimeId; // ID do AllAnime para buscar episÃ³dios
  final String? allAnimeMode; // 'sub' ou 'dub'
  final String? hiAnimeId; // ID do HiAnime para buscar episÃ³dios
  final String? consumetId; // ID do Consumet
  final String? consumetMode; // 'sub' ou 'dub'
  final String? sugoiId; // ID do SugoiAPI PT-BR
  final String? anifyId; // ID do Anify
  final String? animesOnlineId; // ID do AnimesOnline PT-BR
  final String? animesOrionId; // ID do AnimesOrion PT-BR
  final String? animesDigitalId; // ID do AnimesDigital PT-BR
  final String? animesDigitalUrl; // URL do AnimesDigital PT-BR
  final String? audioType; // 'Dublado & Legendado', 'Dublado', 'Legendado'
  final String?
  fallbackImageUrl; // Imagem de fallback antes do AniList carregar
  MediaDetails? aniListData;
  bool isLoadingAniList = false;

  Anime({
    required this.name,
    required this.url,
    this.source = AnimeSource.animeFire,
    this.allAnimeId,
    this.allAnimeMode,
    this.hiAnimeId,
    this.consumetId,
    this.consumetMode,
    this.sugoiId,
    this.anifyId,
    this.animesOnlineId,
    this.animesOrionId,
    this.animesDigitalId,
    this.animesDigitalUrl,
    this.audioType,
    this.aniListData,
    this.fallbackImageUrl,
  });

  @override
  String toString() => name;

  int? malIdOverride;
  int? anilistIdOverride;

  String get imageUrl => aniListData?.coverImage.best ?? fallbackImageUrl ?? '';
  String get bannerUrl => aniListData?.bannerImage ?? '';
  String get description => aniListData?.description ?? '';
  int? get malId => aniListData?.idMal ?? malIdOverride;
  int? get anilistId => aniListData?.id ?? anilistIdOverride;
  List<String> get genres => aniListData?.genres ?? [];
  String? get status => aniListData?.status;
  int? get episodeCount => aniListData?.episodes;
  double? get averageScore => aniListData?.averageScore;
  bool get isDubbed =>
      (audioType?.toLowerCase().contains('dub') ?? false) ||
      allAnimeMode == 'dub' ||
      consumetMode == 'dub' ||
      name.toLowerCase().contains('dublado') ||
      name.toLowerCase().contains('(dub)');
  String get sourceName {
    switch (source) {
      case AnimeSource.animeFire:
        return 'AnimeFire';
      case AnimeSource.allAnime:
        return 'AllAnime';
      case AnimeSource.hiAnime:
        return 'HiAnime (HD)';
      case AnimeSource.consumet:
        return 'Consumet (Global)';
      case AnimeSource.sugoi:
        return 'SugoiAPI (PT-BR)';
      case AnimeSource.anify:
        return 'Anify';
      case AnimeSource.animesOnline:
        return 'AnimesOnline (PT-BR)';
      case AnimeSource.animesOrion:
        return 'AnimesOrion (PT-BR)';
      case AnimeSource.animesDigital:
        return 'AnimesDigital (PT-BR)';
    }
  }
}

class EpisodeStreamOption {
  final String url;
  final String audio; // 'dublado', 'legendado', etc.
  final List<String> qualities;

  EpisodeStreamOption({
    required this.url,
    required this.audio,
    this.qualities = const [],
  });

  String get streamUrl => url;
  String get audioType => audio;
  bool get isDubbed => audio.toLowerCase().contains('dub');
  bool get isSubbed => audio.toLowerCase().contains('leg');

  String get label => displayName;
  String get displayName {
    if (isDubbed) return 'Dublado (PT-BR)';
    if (isSubbed) return 'Legendado';
    return audio.isNotEmpty ? audio : 'Padrão';
  }
}

class EpisodeStreamResult {
  final String primaryUrl;
  final List<EpisodeStreamOption> availableStreams;
  final String currentAudio;

  EpisodeStreamResult({
    required this.primaryUrl,
    required this.availableStreams,
    required this.currentAudio,
  });

  bool get hasMultipleAudio => availableStreams.length > 1;

  EpisodeStreamOption? get selectedStream {
    try {
      return availableStreams.firstWhere(
        (s) => s.audio == currentAudio,
        orElse: () => availableStreams.firstWhere(
          (s) => s.url == primaryUrl,
          orElse: () => availableStreams.isNotEmpty
              ? availableStreams.first
              : EpisodeStreamOption(url: primaryUrl, audio: currentAudio),
        ),
      );
    } catch (_) {
      return EpisodeStreamOption(url: primaryUrl, audio: currentAudio);
    }
  }
}

class VideoData {
  final String src;
  final String label;

  VideoData({required this.src, required this.label});

  factory VideoData.fromJson(Map<String, dynamic> json) {
    return VideoData(src: json['src'] ?? '', label: json['label'] ?? '');
  }

  int get quality {
    final match = RegExp(r'\d+').firstMatch(label);
    return int.tryParse(match?.group(0) ?? '') ?? 0;
  }
}

class VideoResponse {
  final List<VideoData> data;
  final Map<String, dynamic> resposta;

  VideoResponse({required this.data, required this.resposta});

  factory VideoResponse.fromJson(Map<String, dynamic> json) {
    var dataList = json['data'] as List? ?? [];
    List<VideoData> videoDataList = dataList
        .map((item) => VideoData.fromJson(item))
        .toList();

    return VideoResponse(
      data: videoDataList,
      resposta: json['resposta'] ?? json['response'] ?? {},
    );
  }

  VideoData? get preferredVideo {
    final playable = data
        .where((video) => video.src.trim().isNotEmpty)
        .toList();
    if (playable.isEmpty) return null;

    playable.sort((a, b) {
      final scoreA = _qualityScore(a.quality);
      final scoreB = _qualityScore(b.quality);
      return scoreB.compareTo(scoreA);
    });
    return playable.first;
  }

  static int _qualityScore(int quality) {
    if (quality == 720) return 500;
    if (quality == 480) return 450;
    if (quality == 360) return 400;
    if (quality == 1080) return 350;
    return quality;
  }
}

class VideoStreamResult {
  final String url;
  final Map<String, String> headers;
  final bool isGoogleVideo;

  const VideoStreamResult({
    required this.url,
    Map<String, String>? headers,
    this.isGoogleVideo = false,
  }) : headers = headers ?? const {};

  bool get hasHeaders => headers.isNotEmpty;
}

// Database Helper
class DatabaseHelper {
  static Database? _database;
  static const String dbName = 'anime.db';
  static const String animeTable = 'anime';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final path = p.join(await getDatabasesPath(), dbName);
    return await openDatabase(path, version: 1, onCreate: _createDb);
  }

  static Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $animeTable(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    ''');
  }

  static Future<void> addAnimeNames(List<String> animeNames) async {
    final db = await database;
    for (String name in animeNames) {
      await db.insert(animeTable, {'name': name});
    }
  }

  static Future<List<String>> getAnimeNames() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(animeTable);
    return List.generate(maps.length, (i) => maps[i]['name']);
  }
}

// API Service
class AnimeService {
  // O AnimeFire migrou para o domÃ­nio .io e a busca antiga
  // /pesquisar/<slug> deixou de ser a rota principal.
  static const String baseSiteUrl = 'https://animefire.one';
  static const String _animeFireApiBaseUrl = 'https://api.animefire.one';
  static const String _legacyBaseSiteUrl = 'https://animefire.plus';
  static const String _googleVideoUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1';
  static const String _bloggerOrigin = 'https://www.blogger.com';
  static const String _bloggerReferer = 'https://www.blogger.com/';

  static Future<List<Anime>> searchAnime(String animeName) async {
    try {
      debugPrint('[AnimeService] Searching in multiple sources: $animeName');

      // Buscar simultaneamente em AnimeFire e AllAnime
      final results = await Future.wait([
        searchAnimeFireOnly(animeName),
        searchAllAnimeOnly(animeName),
      ]);

      // Combinar resultados
      final List<Anime> allAnimes = [];
      allAnimes.addAll(results[0]); // AnimeFire
      allAnimes.addAll(results[1]); // AllAnime

      debugPrint(
        '[AnimeService] Total results: ${allAnimes.length} (AnimeFire: ${results[0].length}, AllAnime: ${results[1].length})',
      );

      // Enriquecer com dados do AniList em paralelo
      await Future.wait(
        allAnimes.map((anime) => enrichAnimeWithAniList(anime)),
      );

      return allAnimes;
    } catch (e) {
      throw Exception('Error searching anime: $e');
    }
  }

  static Future<List<Anime>> searchAnimeFireOnly(String animeName) async {
    // A busca atual do AnimeFire jÃ¡ normaliza acentos e espaÃ§os. Repetir as
    // variaÃ§Ãµes antigas gerava vÃ¡rias requisiÃ§Ãµes 400 para a mesma pesquisa.
    final results = await _searchAnimeFire(animeName);
    if (results.isNotEmpty) return results;

    final normalized = _normalizeAnimeFireQuery(animeName);
    if (normalized.isEmpty || normalized == animeName.trim()) return results;
    return _searchAnimeFire(normalized);
  }

  static Future<List<Anime>> searchAllAnimeOnly(String animeName) async {
    return _searchSourceWithVariants(animeName, _searchAllAnime);
  }

  static Future<List<Anime>> _searchSourceWithVariants(
    String animeName,
    Future<List<Anime>> Function(String query) searchFn,
  ) async {
    final queries = _buildSearchQueries(animeName);
    final uniqueResults = <String, Anime>{};

    for (final query in queries) {
      final results = await searchFn(query);
      for (final anime in results) {
        final key = '${anime.source.name}:${anime.allAnimeId ?? anime.url}';
        uniqueResults.putIfAbsent(key, () => anime);
      }

      if (uniqueResults.length >= 6) {
        break;
      }
    }

    final mergedResults = uniqueResults.values.toList();
    mergedResults.sort(
      (a, b) =>
          _scoreTitleMatch(
            _normalizeAnimeTitle(b.name),
            _normalizeAnimeTitle(animeName),
          ).compareTo(
            _scoreTitleMatch(
              _normalizeAnimeTitle(a.name),
              _normalizeAnimeTitle(animeName),
            ),
          ),
    );

    return mergedResults;
  }

  /// Busca no AnimeFire
  static Future<List<Anime>> _searchAnimeFire(String animeName) async {
    try {
      final query = animeName.trim();
      final apiSearchUrl = Uri.parse(
        '$_animeFireApiBaseUrl/animes/pesquisar?q=${Uri.encodeComponent(query)}&v=2',
      );

      // O site atual renderiza os cards no navegador; a API entrega os dados
      // diretamente e evita depender de seletores HTML que mudam com o layout.
      final apiResponse = await http
          .get(
            apiSearchUrl,
            headers: {
              HttpHeaders.acceptHeader: 'application/json',
              HttpHeaders.acceptLanguageHeader: 'pt-BR,pt;q=0.9,en;q=0.8',
              HttpHeaders.userAgentHeader:
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
              HttpHeaders.refererHeader: '$baseSiteUrl/animes/pesquisar',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (apiResponse.statusCode == 200) {
        final apiResults = _parseAnimeFireApiResults(apiResponse.body);
        if (apiResults.isNotEmpty) {
          debugPrint('[AnimeFire] API returned ${apiResults.length} results');
          return apiResults;
        }
      } else {
        debugPrint(
          '[AnimeFire] API search failed (${apiResponse.statusCode}): $apiSearchUrl',
        );
      }

      // Fallback HTML para instalaÃ§Ãµes antigas do AnimeFire.
      final currentSearchUrl = Uri.parse(
        '$baseSiteUrl/animes/pesquisar?q=${Uri.encodeComponent(query)}',
      );
      final legacySearchUrl = Uri.parse(
        '$_legacyBaseSiteUrl/pesquisar/${_treatAnimeName(animeName)}',
      );

      for (final searchUrl in [currentSearchUrl, legacySearchUrl]) {
        final response = await http
            .get(
              searchUrl,
              headers: {
                HttpHeaders.acceptHeader:
                    'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                HttpHeaders.acceptLanguageHeader: 'pt-BR,pt;q=0.9,en;q=0.8',
                HttpHeaders.userAgentHeader:
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
                HttpHeaders.refererHeader: '$baseSiteUrl/animes/pesquisar',
                'Origin': baseSiteUrl,
                'Sec-Fetch-Dest': 'document',
                'Sec-Fetch-Mode': 'navigate',
                'Sec-Fetch-Site': 'same-origin',
                'Sec-Fetch-User': '?1',
                'Upgrade-Insecure-Requests': '1',
              },
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          debugPrint(
            '[AnimeFire] Search failed (${response.statusCode}): $searchUrl',
          );
          continue;
        }

        final animes = _parseAnimeFireSearchResults(response.body);
        if (animes.isNotEmpty || searchUrl == legacySearchUrl) {
          debugPrint('[AnimeFire] Found ${animes.length} results');
          return animes;
        }
      }

      return [];
    } catch (e) {
      debugPrint('[AnimeFire] Search error: $e');
      return [];
    }
  }

  static List<Anime> _parseAnimeFireApiResults(String body) {
    try {
      final decoded = jsonDecode(body);
      final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
      if (data is! List) return [];

      return data
          .whereType<Map>()
          .map((item) {
            final id = item['id']?.toString().trim() ?? '';
            String title = item['title']?.toString().trim() ?? '';
            if (title.isEmpty && item['titles'] is Map) {
              final titles = item['titles'] as Map;
              title = titles['BR']?.toString().trim() ??
                  titles['EN']?.toString().trim() ??
                  titles['JP']?.toString().trim() ??
                  '';
            }
            if (title.isEmpty) {
              title = item['name']?.toString().trim() ?? '';
            }

            final poster = item['poster_src']?.toString().trim() ??
                item['image']?.toString().trim();
            final audio = item['audio']?.toString().trim();
            if (id.isEmpty || title.isEmpty) return null;

            return Anime(
              name: title,
              url: '$baseSiteUrl/anime/$id',
              source: AnimeSource.animeFire,
              audioType: audio,
              fallbackImageUrl: poster?.isNotEmpty == true ? poster : null,
            );
          })
          .whereType<Anime>()
          .toList();
    } catch (e) {
      debugPrint('[AnimeFire] Invalid API search response: $e');
      return [];
    }
  }

  /// Busca um catálogo curado de animes com dublagem brasileira (PT-BR) no AnimeFire.
  static Future<List<Anime>> getDubbedAnimes({int limit = 30}) async {
    final results = <Anime>[];
    final seenIds = <String>{};

    final endpoints = [
      '$_animeFireApiBaseUrl/animes/lancamentos?v=2',
      '$_animeFireApiBaseUrl/animes?v=2',
      '$_animeFireApiBaseUrl/animes/pesquisar?q=dublado&v=2',
      '$_animeFireApiBaseUrl/animes/pesquisar?q=naruto%20dublado&v=2',
      '$_animeFireApiBaseUrl/animes/pesquisar?q=dragon%20ball%20dublado&v=2',
    ];

    for (final ep in endpoints) {
      try {
        final response = await http.get(
          Uri.parse(ep),
          headers: {
            HttpHeaders.acceptHeader: 'application/json',
            HttpHeaders.acceptLanguageHeader: 'pt-BR,pt;q=0.9,en;q=0.8',
            HttpHeaders.userAgentHeader:
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
            HttpHeaders.refererHeader: '$baseSiteUrl/',
          },
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final animes = _parseAnimeFireApiResults(response.body);
          for (final anime in animes) {
            if (anime.isDubbed) {
              final id = _animeFireIdFromUrl(anime.url) ?? anime.name;
              if (seenIds.add(id)) {
                results.add(anime);
                if (results.length >= limit) break;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AnimeFire] Error fetching dubbed animes from $ep: $e');
      }
      if (results.length >= limit) break;
    }

    return results;
  }

  static String? _animeFireIdFromUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    if (segments.length < 2 || segments[segments.length - 2] != 'anime') {
      return null;
    }
    final id = segments.last.trim();
    return id.isEmpty ? null : id;
  }

  static String? _animeFireSearchTitleFromLegacyUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    final segments = uri.pathSegments;
    final animesIndex = segments.indexOf('animes');
    if (animesIndex == -1 || animesIndex + 1 >= segments.length) {
      return null;
    }

    final slug = segments[animesIndex + 1]
        .replaceFirst(RegExp(r'-todos-os-episodios$', caseSensitive: false), '')
        .replaceAll('-', ' ')
        .trim();
    return slug.isEmpty ? null : slug;
  }

  static int? _animeFireEpisodeNumberFromLegacyUrl(String value) {
    final segments = Uri.tryParse(value)?.pathSegments ?? const <String>[];
    if (segments.isEmpty) return null;
    return int.tryParse(segments.last);
  }

  static Future<String?> _findAnimeFireIdByTitle(String title) async {
    final query = title.trim();
    if (query.isEmpty) return null;

    try {
      final response = await http
          .get(
            Uri.parse(
              '$_animeFireApiBaseUrl/animes/pesquisar?q=${Uri.encodeComponent(query)}&v=2',
            ),
            headers: {
              HttpHeaders.acceptHeader: 'application/json',
              HttpHeaders.refererHeader: '$baseSiteUrl/animes/pesquisar',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final matches = _parseAnimeFireApiResults(response.body);
      if (matches.isEmpty) return null;

      final normalizedQuery = _normalizeAnimeTitle(query);
      matches.sort(
        (a, b) =>
            _scoreTitleMatch(
              _normalizeAnimeTitle(b.name),
              normalizedQuery,
            ).compareTo(
              _scoreTitleMatch(_normalizeAnimeTitle(a.name), normalizedQuery),
            ),
      );
      return _animeFireIdFromUrl(matches.first.url);
    } catch (e) {
      debugPrint('[AnimeFire] Could not resolve "$title" in the API: $e');
      return null;
    }
  }

  static Future<String?> _resolveLegacyAnimeFireEpisodeUrl(
    String episodeUrl, {
    String? animeTitle,
  }) async {
    final episodeNumber = _animeFireEpisodeNumberFromLegacyUrl(episodeUrl);
    if (episodeNumber == null) return null;

    final queries = <String>{};
    final legacyTitle = _animeFireSearchTitleFromLegacyUrl(episodeUrl);
    if (legacyTitle != null) queries.add(legacyTitle);
    if (animeTitle?.trim().isNotEmpty == true) queries.add(animeTitle!.trim());

    for (final query in queries) {
      final animeId = await _findAnimeFireIdByTitle(query);
      if (animeId == null) continue;

      try {
        final response = await http
            .get(
              Uri.parse('$_animeFireApiBaseUrl/anime/$animeId?v=2'),
              headers: {HttpHeaders.acceptHeader: 'application/json'},
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;

        final decoded = jsonDecode(response.body);
        final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
        final episodes = data is Map<String, dynamic> ? data['episodes'] : null;
        if (episodes is! List) continue;

        for (final episode in episodes.whereType<Map>()) {
          if (episode['number']?.toString() != episodeNumber.toString()) {
            continue;
          }
          final id = episode['id']?.toString().trim() ?? '';
          if (id.isNotEmpty) {
            return '$_animeFireApiBaseUrl/episode/$id';
          }
        }
      } catch (e) {
        debugPrint('[AnimeFire] Could not resolve legacy episode: $e');
      }
    }

    return null;
  }

  static String _normalizeAnimeFireQuery(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[:-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<Anime> _parseAnimeFireSearchResults(String body) {
    final document = html_parser.parse(body);
    final elements = document.querySelectorAll(
      'a[href^="/anime/"], a[href*="/anime/"], '
      '.row.ml-1.mr-1 a, .card_ani .ani_name a',
    );

    final animes = <Anime>[];
    final seenUrls = <String>{};

    for (final element in elements) {
      final rawUrl = element.attributes['href']?.trim() ?? '';
      if (rawUrl.isEmpty || !_isAnimeFireAnimeUrl(rawUrl)) continue;

      final url = _resolveAnimeFireUrl(rawUrl);
      if (!seenUrls.add(url)) continue;

      final card = element.parent?.parent;
      final titleElement =
          element.querySelector('h3') ??
          card?.querySelector('h3') ??
          element.querySelector('.ani_name');
      final name = (titleElement?.text ?? element.text).trim().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      if (name.isEmpty) continue;

      final imageElement =
          element.querySelector('img') ??
          card?.querySelector('img') ??
          element.parent?.querySelector('img');
      final thumbnail =
          imageElement?.attributes['data-src'] ??
          imageElement?.attributes['data-lazy-src'] ??
          imageElement?.attributes['src'];

      final anime = Anime(
        name: name,
        url: url,
        source: AnimeSource.animeFire,
        fallbackImageUrl: thumbnail?.trim().isEmpty == true
            ? null
            : thumbnail?.trim(),
      );
      animes.add(anime);

      if (animes.length <= 3) {
        debugPrint('[AnimeFire] Anime: $name, thumbnail: $thumbnail');
      }
    }

    return animes;
  }

  static bool _isAnimeFireAnimeUrl(String rawUrl) {
    final normalized = rawUrl.toLowerCase();
    return normalized.startsWith('/anime/') ||
        normalized.startsWith('/animes/') ||
        normalized.startsWith('https://animefire.one/anime/') ||
        normalized.startsWith('https://animefire.one/animes/') ||
        normalized.startsWith('https://animefire.io/anime/') ||
        normalized.startsWith('https://animefire.plus/animes/') ||
        normalized.startsWith('https://animefire.plus/anime/');
  }

  static String _resolveAnimeFireUrl(String rawUrl) {
    final parsed = Uri.tryParse(rawUrl);
    if (parsed != null && parsed.hasScheme) return parsed.toString();
    return Uri.parse(baseSiteUrl).resolve(rawUrl).toString();
  }

  /// Busca no AllAnime
  static Future<List<Anime>> _searchAllAnime(String animeName) async {
    try {
      final response = await AllAnimeService.searchAnime(animeName);

      if (response == null || response.shows.isEmpty) {
        debugPrint('[AllAnime] No results found');
        return [];
      }

      List<Anime> animes = [];
      for (var show in response.shows) {
        final episodeInfo = show.episodeCount > 0
            ? ' (${show.episodeCount} eps)'
            : '';

        // Usar thumbnail do AllAnime como fallback se disponÃ­vel
        final fallbackImage = show.thumbnail?.isNotEmpty == true
            ? show.thumbnail!
            : null;

        animes.add(
          Anime(
            name: '${show.displayName}$episodeInfo',
            url: show.id, // Para AllAnime, a "URL" Ã© o ID
            source: AnimeSource.allAnime,
            allAnimeId: show.id,
            fallbackImageUrl: fallbackImage, // Fallback atÃ© AniList carregar
          ),
        );
      }

      debugPrint('[AllAnime] Found ${animes.length} results');
      return animes;
    } catch (e) {
      debugPrint('[AllAnime] Search error: $e');
      return [];
    }
  }

  /// Enriches an anime with data from AniList
  static Future<void> enrichAnimeWithAniList(Anime anime) async {
    try {
      anime.isLoadingAniList = true;

      final aniListResponse = await AniListService.fetchAnimeFromAniList(
        anime.name,
      );

      if (aniListResponse != null) {
        anime.aniListData = aniListResponse.data.media;
        debugPrint(
          '[AnimeService] Enriched ${anime.name} with AniList data - '
          'ID: ${anime.anilistId}, Cover: ${anime.imageUrl}',
        );
      } else {
        debugPrint('[AnimeService] No AniList data found for ${anime.name}');
      }
    } catch (e) {
      debugPrint(
        '[AnimeService] Failed to enrich ${anime.name} with AniList: $e',
      );
    } finally {
      anime.isLoadingAniList = false;
    }
  }

  static Future<List<Episode>> getAnimeEpisodes(Anime anime) async {
    try {
      debugPrint(
        '[AnimeService] Getting episodes for ${anime.name} from ${anime.sourceName}',
      );
      debugPrint('[AnimeService] Anime thumbnail URL: ${anime.imageUrl}');
      debugPrint(
        '[AnimeService] Has AniList data: ${anime.aniListData != null}',
      );
      debugPrint('[AnimeService] Fallback image: ${anime.fallbackImageUrl}');

      if (anime.source == AnimeSource.allAnime) {
        return await _getEpisodesFromAllAnime(anime);
      } else {
        return await _getEpisodesFromAnimeFire(anime);
      }
    } catch (e) {
      throw Exception('Error getting episodes: $e');
    }
  }

  /// Busca episÃ³dios do AnimeFire
  static Future<List<Episode>> _getEpisodesFromAnimeFire(Anime anime) async {
    try {
      debugPrint('[AnimeFire] Fetching episodes for: ${anime.name}');
      debugPrint('[AnimeFire] Anime thumbnail: ${anime.imageUrl}');

      List<int> episodeNumbers = [];
      List<Episode> tempEpisodes = [];

      var animeId = _animeFireIdFromUrl(anime.url);
      animeId ??= await _findAnimeFireIdByTitle(
        _animeFireSearchTitleFromLegacyUrl(anime.url) ?? anime.name,
      );
      if (animeId != null) {
        final apiUrl = Uri.parse('$_animeFireApiBaseUrl/anime/$animeId?v=2');
        final apiResponse = await http
            .get(
              apiUrl,
              headers: {
                HttpHeaders.acceptHeader: 'application/json',
                HttpHeaders.userAgentHeader:
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
                HttpHeaders.refererHeader: anime.url,
              },
            )
            .timeout(const Duration(seconds: 10));

        if (apiResponse.statusCode == 200) {
          final decoded = jsonDecode(apiResponse.body);
          final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
          final apiEpisodes = data is Map<String, dynamic>
              ? data['episodes']
              : null;

          if (apiEpisodes is List) {
            // Verificar se o anime possui múltiplas temporadas
            int maxSeason = 1;
            for (final item in apiEpisodes.whereType<Map>()) {
              final s = int.tryParse(item['season']?.toString() ?? '1') ?? 1;
              if (s > maxSeason) maxSeason = s;
            }

            for (final item in apiEpisodes.whereType<Map>()) {
              final id = item['id']?.toString().trim() ?? '';
              final number = item['number']?.toString().trim() ?? '';
              if (id.isEmpty || number.isEmpty) continue;

              final epNum = int.tryParse(number);
              if (epNum == null) continue;

              final season =
                  int.tryParse(item['season']?.toString() ?? '1') ?? 1;
              final displayPrefix = maxSeason > 1
                  ? 'T$season: Ep $number'
                  : 'Episódio $number';

              episodeNumbers.add(epNum);
              tempEpisodes.add(
                Episode(
                  number: displayPrefix,
                  url: '$_animeFireApiBaseUrl/episode/$id',
                  title: item['title']?.toString(),
                  description: item['synopsis']?.toString(),
                  thumbnail: item['still_src']?.toString(),
                  audioType: item['audio']?.toString(),
                ),
              );
            }
          }
        }
      }

      // Compatibilidade com o HTML do domÃ­nio antigo.
      if (tempEpisodes.isEmpty) {
        final response = await http
            .get(
              Uri.parse(anime.url),
              headers: _buildRequestHeaders(referer: baseSiteUrl),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          throw Exception('Failed to get episodes: ${response.statusCode}');
        }

        final document = html_parser.parse(response.body);
        final episodeElements = document.querySelectorAll(
          'a.lEp.epT.divNumEp.smallbox.px-2.mx-1.text-left.d-flex',
        );

        for (var element in episodeElements) {
          final number = element.text.trim();
          final url = element.attributes['href'] ?? '';
          if (number.isNotEmpty && url.isNotEmpty) {
            final episodeNumMatch = RegExp(r'\d+').firstMatch(number);
            if (episodeNumMatch != null) {
              final epNum = int.tryParse(episodeNumMatch.group(0)!);
              if (epNum != null) {
                episodeNumbers.add(epNum);
                tempEpisodes.add(Episode(number: number, url: url));
              }
            }
          }
        }
      }

      // Batch fetch episode-specific thumbnails from multiple sources
      debugPrint('[AnimeFire] Fetching episode-specific thumbnails...');
      final kitsuThumbnails = await EpisodeThumbnailService.batchGetThumbnails(
        animeTitle: anime.name,
        episodeNumbers: episodeNumbers,
        malId: anime.malId?.toString(),
        anilistId: anime.anilistId?.toString(),
      );

      if (kitsuThumbnails.isNotEmpty) {
        debugPrint(
          '[AnimeFire] Got ${kitsuThumbnails.length} episode-specific thumbnails from Kitsu',
        );
      }

      List<Episode> episodes = [];
      for (int i = 0; i < tempEpisodes.length; i++) {
        final tempEp = tempEpisodes[i];
        final epNum = episodeNumbers[i];

        // Priority: Kitsu thumbnail > Anime thumbnail
        String? episodeThumbnail;
        if (tempEp.thumbnail?.isNotEmpty == true) {
          episodeThumbnail = tempEp.thumbnail;
          if (episodes.length < 3) {
            debugPrint('[AnimeFire] Episode $epNum: Using AnimeFire thumbnail');
          }
        } else if (kitsuThumbnails.containsKey(epNum)) {
          episodeThumbnail = kitsuThumbnails[epNum];
          if (episodes.length < 3) {
            debugPrint('[AnimeFire] Episode $epNum: Using Kitsu thumbnail');
          }
        } else {
          episodeThumbnail = anime.imageUrl.isNotEmpty ? anime.imageUrl : null;
        }

        episodes.add(
          Episode(
            number: tempEp.number,
            url: tempEp.url,
            thumbnail: episodeThumbnail,
          ),
        );
      }

      debugPrint('[AnimeFire] Found ${episodes.length} episodes');
      if (episodes.isNotEmpty) {
        debugPrint(
          '[AnimeFire] First episode thumbnail: ${episodes.first.thumbnail}',
        );
      }
      return episodes;
    } catch (e) {
      debugPrint('[AnimeFire] Get episodes error: $e');
      throw Exception('Error getting episodes from AnimeFire: $e');
    }
  }

  /// Busca episÃ³dios do AllAnime com thumbnails
  static Future<List<Episode>> _getEpisodesFromAllAnime(Anime anime) async {
    try {
      final animeId = anime.allAnimeId ?? anime.url;
      final showThumbnail = anime.imageUrl; // Use anime's image as fallback

      debugPrint('[AllAnime] Fetching episodes for: ${anime.name}');
      debugPrint('[AllAnime] Show thumbnail: $showThumbnail');

      // Try to get detailed episodes with thumbnails first
      final detailedEpisodes = await AllAnimeService.getEpisodesListDetailed(
        animeId,
        showThumbnail: showThumbnail,
      );

      if (detailedEpisodes.isEmpty) {
        debugPrint('[AllAnime] No episodes found');
        return [];
      }

      // Batch fetch episode-specific thumbnails from multiple sources
      final episodeNumbers = detailedEpisodes
          .map((e) => int.tryParse(e.episodeNumber))
          .where((n) => n != null)
          .cast<int>()
          .toList();

      debugPrint('[AllAnime] Fetching episode-specific thumbnails...');
      final kitsuThumbnails = await EpisodeThumbnailService.batchGetThumbnails(
        animeTitle: anime.name,
        episodeNumbers: episodeNumbers,
        malId: anime.malId?.toString(),
        anilistId: anime.anilistId?.toString(),
      );

      if (kitsuThumbnails.isNotEmpty) {
        debugPrint(
          '[AllAnime] Got ${kitsuThumbnails.length} episode-specific thumbnails from Kitsu',
        );
      }

      List<Episode> episodes = [];
      for (var allAnimeEp in detailedEpisodes) {
        final displayNumber = allAnimeEp.episodeNumber.contains('.')
            ? 'EpisÃ³dio ${allAnimeEp.episodeNumber}'
            : 'EpisÃ³dio ${allAnimeEp.episodeNumber}';

        // Priority: Kitsu thumbnail > AllAnime thumbnail > Show thumbnail
        String? episodeThumbnail;

        final epNum = int.tryParse(allAnimeEp.episodeNumber);
        if (epNum != null && kitsuThumbnails.containsKey(epNum)) {
          episodeThumbnail = kitsuThumbnails[epNum];
          if (episodes.length < 3) {
            debugPrint('[AllAnime] Episode $epNum: Using Kitsu thumbnail');
          }
        } else {
          episodeThumbnail = allAnimeEp.getImageUrl();
          if (episodeThumbnail == null || episodeThumbnail.isEmpty) {
            episodeThumbnail = showThumbnail;
          }
        }

        episodes.add(
          Episode(
            number: displayNumber,
            url: allAnimeEp
                .episodeNumber, // Para AllAnime, guardamos o nÃºmero do episÃ³dio
            thumbnail: episodeThumbnail, // Add thumbnail (with fallback)
            title: allAnimeEp.title,
            description: allAnimeEp.description,
          ),
        );

        // Log first few episodes for debugging
        if (episodes.length <= 3) {
          debugPrint(
            '[AllAnime] Episode ${allAnimeEp.episodeNumber} final thumbnail: $episodeThumbnail',
          );
        }
      }

      debugPrint(
        '[AllAnime] Converted ${episodes.length} episodes with thumbnails',
      );
      return episodes;
    } catch (e) {
      debugPrint('[AllAnime] Get episodes error: $e');
      throw Exception('Error getting episodes from AllAnime: $e');
    }
  }

  static Future<EpisodeStreamResult> getEpisodeStreams(
    String episodeUrl, {
    String? animeTitle,
    String? preferredAudio,
  }) async {
    try {
      debugPrint('Extracting video streams from page: $episodeUrl');

      var resolvedEpisodeUrl = episodeUrl;
      final sourceUri = Uri.tryParse(episodeUrl);
      final isLegacyAnimeFireEpisode =
          sourceUri != null &&
          (sourceUri.host == 'animefire.one' ||
              sourceUri.host == 'animefire.io' ||
              sourceUri.host == 'animefire.plus') &&
          sourceUri.pathSegments.contains('animes');
      if (isLegacyAnimeFireEpisode) {
        final apiEpisodeUrl = await _resolveLegacyAnimeFireEpisodeUrl(
          episodeUrl,
          animeTitle: animeTitle,
        );
        if (apiEpisodeUrl != null) {
          resolvedEpisodeUrl = apiEpisodeUrl;
          debugPrint(
            '[AnimeFire] Legacy episode resolved: $resolvedEpisodeUrl',
          );
        }
      }

      final isApiEpisode = resolvedEpisodeUrl.startsWith(_animeFireApiBaseUrl) ||
          resolvedEpisodeUrl.contains('api.animefire.') ||
          resolvedEpisodeUrl.contains('/episode/');

      if (isApiEpisode) {
        var apiEpisodeUrl = resolvedEpisodeUrl;
        if (apiEpisodeUrl.contains('api.animefire.io')) {
          apiEpisodeUrl = apiEpisodeUrl.replaceAll('api.animefire.io', 'api.animefire.one');
        }
        if (!apiEpisodeUrl.contains('v=')) {
          apiEpisodeUrl += apiEpisodeUrl.contains('?') ? '&v=2' : '?v=2';
        }
        final response = await http.get(
          Uri.parse(apiEpisodeUrl),
          headers: _buildRequestHeaders(referer: baseSiteUrl),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to get video page: ${response.statusCode}');
        }

        final decoded = jsonDecode(response.body);
        final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
        final streams = data is Map<String, dynamic> ? data['streams'] : null;
        if (streams is List && streams.isNotEmpty) {
          final streamList = streams.whereType<Map>().toList();
          final streamOptions = streamList.map((s) {
            final url = s['url']?.toString().trim() ?? '';
            final audio = s['audio']?.toString().trim() ?? '';
            final rawQualities = s['qualities'] as List?;
            final qualities = rawQualities?.map((q) => q.toString()).toList() ?? <String>[];
            return EpisodeStreamOption(url: url, audio: audio, qualities: qualities);
          }).where((opt) => opt.url.isNotEmpty).toList();

          if (streamOptions.isNotEmpty) {
            final titleLower = (animeTitle ?? '').toLowerCase();
            final titleWantsDub = titleLower.contains('dublado') || titleLower.contains('(dub)');
            final prefAudioLower = (preferredAudio ?? '').toLowerCase();
            final wantsDub = prefAudioLower.contains('dub') || (prefAudioLower.isEmpty && titleWantsDub);

            EpisodeStreamOption selectedStream;
            if (wantsDub) {
              selectedStream = streamOptions.firstWhere(
                (s) => s.isDubbed,
                orElse: () => streamOptions.firstWhere(
                  (s) => s.isSubbed,
                  orElse: () => streamOptions.first,
                ),
              );
            } else if (prefAudioLower.contains('leg')) {
              selectedStream = streamOptions.firstWhere(
                (s) => s.isSubbed,
                orElse: () => streamOptions.firstWhere(
                  (s) => s.isDubbed,
                  orElse: () => streamOptions.first,
                ),
              );
            } else {
              // Default preferência: Dublado se disponível, senão legendado
              selectedStream = streamOptions.firstWhere(
                (s) => s.isDubbed,
                orElse: () => streamOptions.firstWhere(
                  (s) => s.isSubbed,
                  orElse: () => streamOptions.first,
                ),
              );
            }

            debugPrint(
              '[AnimeFire] Selected stream (${selectedStream.audio}): ${selectedStream.url} '
              '(Total streams available: ${streamOptions.length})',
            );

            return EpisodeStreamResult(
              primaryUrl: selectedStream.url,
              availableStreams: streamOptions,
              currentAudio: selectedStream.audio,
            );
          } else {
            final isAllOffline = streamList.isNotEmpty &&
                streamList.every(
                  (s) =>
                      s['is_offline'] == true ||
                      s['url'] == null ||
                      s['url'].toString().trim().isEmpty,
                );
            if (isAllOffline) {
              throw Exception(
                'Este episódio está temporariamente indisponível no servidor do AnimeFire.',
              );
            }
          }
        }
        throw Exception(
          'Nenhum stream de vídeo disponível no AnimeFire para este episódio no momento.',
        );
      }

      final singleUrl = await _extractVideoUrlFromHtml(resolvedEpisodeUrl);
      return EpisodeStreamResult(
        primaryUrl: singleUrl,
        availableStreams: [EpisodeStreamOption(url: singleUrl, audio: 'padrao')],
        currentAudio: 'padrao',
      );
    } catch (e) {
      throw Exception('Error extracting video stream: $e');
    }
  }

  static Future<String> extractVideoURL(
    String episodeUrl, {
    String? animeTitle,
    String? preferredAudio,
  }) async {
    final result = await getEpisodeStreams(
      episodeUrl,
      animeTitle: animeTitle,
      preferredAudio: preferredAudio,
    );
    return result.primaryUrl;
  }

  static Future<String> _extractVideoUrlFromHtml(String pageUrl) async {
    final response = await http.get(
      Uri.parse(pageUrl),
      headers: _buildRequestHeaders(referer: baseSiteUrl),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to get video page: ${response.statusCode}');
    }

    final document = html_parser.parse(response.body);

    final selectors = [
      'video',
      'div[data-video-src]',
      'div[data-src]',
      'div[data-url]',
      'div[data-video]',
      'div[data-player]',
      'iframe[src*="video"]',
      'iframe[src*="player"]',
    ];

    for (String selector in selectors) {
      final elements = document.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        final attributes = [
          'data-video-src',
          'data-src',
          'data-url',
          'data-video',
          'src',
        ];

        for (var element in elements) {
          for (String attr in attributes) {
            final videoSrc = element.attributes[attr];
            if (videoSrc != null && videoSrc.isNotEmpty) {
              return videoSrc;
            }
          }
        }
      }
    }

    final bloggerLink = _findBloggerLink(response.body);
    if (bloggerLink.isNotEmpty) {
      return bloggerLink;
    }

    final videoUrlPattern = RegExp(
      r'''https?://[^\s<>"']+?\.(?:mp4|m3u8)(?:\?[^\s<>"']*)?''',
    );
    final match = videoUrlPattern.firstMatch(response.body);
    if (match != null) {
      return match.group(0)!;
    }

    throw Exception('No video source found in the page');
  }

  static Future<VideoStreamResult> extractActualVideoURL(
    String videoSrc, {
    String? referer,
    Map<String, String>? fallbackHeaders,
  }) async {
    try {
      debugPrint('Processing video source: $videoSrc');
      final baseHeaders = Map<String, String>.from(fallbackHeaders ?? const {});

      if (videoSrc.contains('blogger.com')) {
        final bloggerResult = await _extractBloggerVideoURL(videoSrc);
        return _mergeVideoStreamResult(bloggerResult, baseHeaders);
      }

      if (_looksLikeDirectVideoUrl(videoSrc)) {
        return await _finalizeDirectVideoUrl(
          videoSrc,
          referer: referer,
          fallbackHeaders: baseHeaders,
        );
      }

      if (videoSrc.contains('animefire.plus/video/')) {
        debugPrint('Found animefire.plus video URL, fetching content...');

        final response = await http.get(
          Uri.parse(videoSrc),
          headers: _buildRequestHeaders(referer: referer),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to get video data: ${response.statusCode}');
        }

        try {
          // Try to parse as JSON first
          final jsonData = json.decode(response.body);
          final videoResponse = VideoResponse.fromJson(jsonData);

          final preferredVideo = videoResponse.preferredVideo;
          if (preferredVideo != null) {
            debugPrint(
              'Found video data with ${videoResponse.data.length} qualities',
            );
            return await _finalizeDirectVideoUrl(
              preferredVideo.src,
              referer: referer,
              fallbackHeaders: baseHeaders,
            );
          }
        } catch (jsonError) {
          debugPrint('Failed to parse as JSON, trying other methods...');
        }

        // Fallback: Try to find direct video URL in content
        final videoUrlPattern = RegExp(
          r'''https?://[^\s<>"']+?\.(?:mp4|m3u8)(?:\?[^\s<>"']*)?''',
        );
        final match = videoUrlPattern.firstMatch(response.body);
        if (match != null) {
          final directUrl = match.group(0)!;
          debugPrint('Found direct video URL: $directUrl');
          return await _finalizeDirectVideoUrl(
            directUrl,
            referer: referer,
            fallbackHeaders: baseHeaders,
          );
        }

        final bloggerLink = _findBloggerLink(response.body);
        if (bloggerLink.isNotEmpty) {
          debugPrint('Found blogger link: $bloggerLink');
          final bloggerResult = await _extractBloggerVideoURL(bloggerLink);
          return _mergeVideoStreamResult(bloggerResult, baseHeaders);
        }
      }

      final response = await http.get(
        Uri.parse(videoSrc),
        headers: _buildRequestHeaders(referer: referer),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to get video data: ${response.statusCode}');
      }

      final jsonData = json.decode(response.body);
      final videoResponse = VideoResponse.fromJson(jsonData);
      final preferredVideo = videoResponse.preferredVideo;

      if (preferredVideo == null) {
        throw Exception('No video data found');
      }

      return await _finalizeDirectVideoUrl(
        preferredVideo.src,
        referer: referer,
        fallbackHeaders: baseHeaders,
      );
    } catch (e) {
      throw Exception('Error extracting actual video URL: $e');
    }
  }

  static Map<String, String> _buildRequestHeaders({String? referer}) {
    return {
      HttpHeaders.userAgentHeader:
          'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
      HttpHeaders.acceptHeader:
          'application/json,text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      if (referer != null && referer.isNotEmpty)
        HttpHeaders.refererHeader: referer,
    };
  }

  // Helper function to find Blogger video links
  static String _findBloggerLink(String content) {
    final pattern = RegExp(
      r'https://www\.blogger\.com/video\.g\?token=([A-Za-z0-9_-]+)',
    );
    final match = pattern.firstMatch(content);

    if (match != null) {
      return match.group(0) ?? '';
    }

    return '';
  }

  // Extract actual video URL from Blogger
  static Future<VideoStreamResult> _extractBloggerVideoURL(
    String bloggerUrl,
  ) async {
    try {
      debugPrint('Extracting actual video URL from Blogger: $bloggerUrl');

      final response = await http.get(
        Uri.parse(bloggerUrl),
        headers: {
          HttpHeaders.userAgentHeader: _googleVideoUserAgent,
          HttpHeaders.refererHeader: 'https://animefire.plus/',
        },
      );

      debugPrint('Blogger response status: ${response.statusCode}');
      debugPrint('Response headers: ${response.headers}');

      if (response.headers.containsKey('location')) {
        final location = response.headers['location']!;
        debugPrint('Found redirect in headers: $location');
        if (location.contains('.mp4') ||
            location.contains('googlevideo.com') ||
            location.contains('googleusercontent.com')) {
          return await _createVideoStreamResult(location, referer: bloggerUrl);
        }
      }

      final content = response.body;
      debugPrint('Response body length: ${content.length}');

      if (content.isNotEmpty) {
        final previewLength = content.length > 2000 ? 2000 : content.length;
        debugPrint('Response preview: ${content.substring(0, previewLength)}');
      }

      final videoConfigStart = content.indexOf('VIDEO_CONFIG = ');
      if (videoConfigStart != -1) {
        final jsonStart = content.indexOf('{', videoConfigStart);
        if (jsonStart != -1) {
          int braceCount = 0;
          int jsonEnd = jsonStart;

          for (int i = jsonStart; i < content.length; i++) {
            if (content[i] == '{') {
              braceCount++;
            } else if (content[i] == '}') {
              braceCount--;
              if (braceCount == 0) {
                jsonEnd = i;
                break;
              }
            }
          }

          if (jsonEnd > jsonStart) {
            final configJson = content.substring(jsonStart, jsonEnd + 1);
            debugPrint(
              'Found VIDEO_CONFIG JSON: ${configJson.length > 500 ? '${configJson.substring(0, 500)}...' : configJson}',
            );

            try {
              final config = json.decode(configJson);
              if (config is Map) {
                if (config.containsKey('streams') &&
                    config['streams'] is List) {
                  final streams = config['streams'] as List;
                  if (streams.isNotEmpty && streams[0] is Map) {
                    final firstStream = streams[0] as Map;
                    if (firstStream.containsKey('play_url')) {
                      final videoUrl = firstStream['play_url'].toString();
                      debugPrint(
                        'Found video URL in streams[0].play_url: $videoUrl',
                      );
                      return await _createVideoStreamResult(
                        videoUrl,
                        referer: bloggerUrl,
                      );
                    }
                  }
                }

                final possibleKeys = [
                  'url',
                  'stream_url',
                  'video_url',
                  'source',
                  'src',
                ];
                for (final key in possibleKeys) {
                  if (config.containsKey(key) && config[key] != null) {
                    final videoUrl = config[key].toString();
                    if (videoUrl.isNotEmpty && videoUrl.contains('http')) {
                      debugPrint(
                        'Found video URL in VIDEO_CONFIG[$key]: $videoUrl',
                      );
                      return await _createVideoStreamResult(
                        videoUrl,
                        referer: bloggerUrl,
                      );
                    }
                  }
                }
              }
            } catch (jsonError) {
              debugPrint('Failed to parse VIDEO_CONFIG JSON: $jsonError');

              final playUrlPattern = RegExp(r'"play_url"\s*:\s*"([^"]+)"');
              final playUrlMatch = playUrlPattern.firstMatch(configJson);
              if (playUrlMatch != null) {
                final videoUrl = playUrlMatch.group(1)!;
                debugPrint(
                  'Extracted play_url directly from JSON string: $videoUrl',
                );
                return await _createVideoStreamResult(
                  videoUrl,
                  referer: bloggerUrl,
                );
              }
            }
          }
        }
      }

      final patterns = [
        RegExp(
          r'https://[^"\s<>]+videoplayback[^"\s<>]*',
          caseSensitive: false,
        ),
        RegExp(
          r'https://[^"\s<>]+\.googlevideo\.com[^"\s<>]*',
          caseSensitive: false,
        ),
        RegExp(
          r'https://[^"\s<>]+\.googleusercontent\.com[^"\s<>]*videoplayback[^"\s<>]*',
          caseSensitive: false,
        ),
        RegExp(
          r'https://[^"\s<>]+\.googleapis\.com[^"\s<>]*',
          caseSensitive: false,
        ),
        RegExp(r'stream_url.*?"([^"]*)"', caseSensitive: false),
        RegExp(r'video_url.*?"([^"]*)"', caseSensitive: false),
        RegExp(r'"url":\s*"([^"]*videoplayback[^"]*)"', caseSensitive: false),
        RegExp(r'"url":\s*"([^"]*\.mp4[^"]*)"', caseSensitive: false),
        RegExp(r'https://[^"\s<>]+\.mp4[^"\s<>]*', caseSensitive: false),
      ];

      for (int i = 0; i < patterns.length; i++) {
        final pattern = patterns[i];
        final match = pattern.firstMatch(content);
        if (match != null) {
          String videoUrl = match.group(1) ?? match.group(0)!;
          videoUrl = videoUrl
              .replaceAll(r'\u003d', '=')
              .replaceAll(r'\u0026', '&')
              .replaceAll(r'\\/', '/')
              .replaceAll(r'\\', '')
              .replaceAll(r'\/', '/');

          debugPrint('Found video URL with pattern ${i + 1}: $videoUrl');

          if (videoUrl.startsWith('http') &&
              (videoUrl.contains('.mp4') ||
                  videoUrl.contains('googlevideo') ||
                  videoUrl.contains('googleusercontent'))) {
            return await _createVideoStreamResult(
              videoUrl,
              referer: bloggerUrl,
            );
          }
        }
      }

      final scriptMatches = RegExp(
        r'<script[^>]*>(.*?)</script>',
        dotAll: true,
      ).allMatches(content);
      for (final scriptMatch in scriptMatches) {
        final scriptContent = scriptMatch.group(1) ?? '';
        final jsPatterns = [
          RegExp(r'https://[^"]+videoplayback[^"]*'),
          RegExp(r'https://[^"]+\.googlevideo\.com[^"]*'),
          RegExp(
            r'https://[^"]+\.googleusercontent\.com[^"]*videoplayback[^"]*',
          ),
        ];

        for (final jsPattern in jsPatterns) {
          final jsMatch = jsPattern.firstMatch(scriptContent);
          if (jsMatch != null) {
            final videoUrl = jsMatch.group(0)!;
            debugPrint('Found video URL in JavaScript: $videoUrl');
            return await _createVideoStreamResult(
              videoUrl,
              referer: bloggerUrl,
            );
          }
        }
      }

      final tokenMatch = RegExp(
        r'token=([A-Za-z0-9_-]+)',
      ).firstMatch(bloggerUrl);
      if (tokenMatch != null) {
        final token = tokenMatch.group(1)!;
        debugPrint('Extracted token: $token');

        final alternativeUrls = [
          'https://www.blogger.com/video-play/mp4/$token',
          'https://blogger.googleusercontent.com/video.g?token=$token',
          'https://redirector.googlevideo.com/videoplayback?token=$token',
        ];

        for (final altUrl in alternativeUrls) {
          debugPrint('Trying alternative URL: $altUrl');
          try {
            final testResponse = await http.head(Uri.parse(altUrl));
            if (testResponse.statusCode == 200 ||
                testResponse.statusCode == 302) {
              debugPrint('Alternative URL works: $altUrl');
              return await _createVideoStreamResult(
                altUrl,
                referer: bloggerUrl,
              );
            }
          } catch (e) {
            debugPrint('Alternative URL failed: $altUrl - $e');
          }
        }
      }

      debugPrint('Could not extract video URL from Blogger response');
      return VideoStreamResult(url: bloggerUrl);
    } catch (e) {
      debugPrint('Error extracting Blogger video URL: $e');
      return VideoStreamResult(url: bloggerUrl);
    }
  }

  static Future<VideoStreamResult> _createVideoStreamResult(
    String url, {
    String? referer,
  }) async {
    if (url.contains('googlevideo.com') || url.contains('videoplayback')) {
      debugPrint('Processing Google Video URL for native playback...');
      return await _processGoogleVideoURL(url, referer: referer);
    }

    return VideoStreamResult(url: url);
  }

  static Future<VideoStreamResult> _finalizeDirectVideoUrl(
    String url, {
    String? referer,
    Map<String, String>? fallbackHeaders,
  }) async {
    final baseHeaders = Map<String, String>.from(fallbackHeaders ?? const {});
    if (url.contains('googlevideo.com') ||
        url.contains('videoplayback') ||
        url.contains('googleusercontent.com')) {
      final googleResult = await _createVideoStreamResult(
        url,
        referer: referer,
      );
      return _mergeVideoStreamResult(googleResult, baseHeaders);
    }

    if (url.contains('akumast.net') || url.contains('.jpg')) {
      baseHeaders.putIfAbsent('Referer', () => 'https://animefire.one/');
      baseHeaders.putIfAbsent('Origin', () => 'https://animefire.one');
      baseHeaders.putIfAbsent(
        'User-Agent',
        () =>
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      );
      return VideoStreamResult(url: url, headers: baseHeaders);
    }

    return _mergeVideoStreamResult(VideoStreamResult(url: url), baseHeaders);
  }

  static VideoStreamResult _mergeVideoStreamResult(
    VideoStreamResult result,
    Map<String, String> baseHeaders,
  ) {
    final headers = Map<String, String>.from(baseHeaders);
    if (result.hasHeaders) {
      headers.addAll(result.headers);
    }

    return VideoStreamResult(
      url: result.url,
      headers: headers,
      isGoogleVideo: result.isGoogleVideo,
    );
  }

  static bool _looksLikeDirectVideoUrl(String url) {
    return url.startsWith('http') &&
        (url.contains('.mp4') ||
            url.contains('.m3u8') ||
            url.contains('.mpd') ||
            url.contains('akumast.net') ||
            url.contains('/m.jpg') ||
            url.contains('googlevideo.com') ||
            url.contains('videoplayback') ||
            url.contains('googleusercontent.com'));
  }

  // Process Google Video URLs for native compatibility
  static Future<VideoStreamResult> _processGoogleVideoURL(
    String googleVideoUrl, {
    String? referer,
  }) async {
    try {
      debugPrint('Processing Google Video URL for playback: $googleVideoUrl');

      final originalUri = Uri.parse(googleVideoUrl);
      final sanitizedUri = _sanitizeGoogleVideoUri(originalUri);

      final httpClient = HttpClient();
      httpClient.userAgent = _googleVideoUserAgent;
      httpClient.connectionTimeout = const Duration(seconds: 12);

      final request = await httpClient.getUrl(sanitizedUri);
      request.followRedirects = true;
      request.headers
        ..set(HttpHeaders.acceptHeader, 'video/mp4,video/*;q=0.9,*/*;q=0.8')
        ..set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9')
        ..set(HttpHeaders.acceptEncodingHeader, 'identity')
        ..set(HttpHeaders.rangeHeader, 'bytes=0-1')
        ..set(HttpHeaders.refererHeader, referer ?? _bloggerReferer)
        ..set('Origin', _bloggerOrigin)
        ..set(HttpHeaders.connectionHeader, 'keep-alive');

      final response = await request.close();
      final effectiveUri = response.redirects.isNotEmpty
          ? response.redirects.last.location
          : sanitizedUri;
      final cookies = response.cookies;
      debugPrint('Google Video URL response status: ${response.statusCode}');
      await response.drain();
      httpClient.close(force: true);

      final cookieHeader = cookies.isEmpty
          ? ''
          : cookies
                .map((cookie) => '${cookie.name}=${cookie.value}')
                .join('; ');

      final headers = <String, String>{
        HttpHeaders.userAgentHeader: _googleVideoUserAgent,
        HttpHeaders.acceptHeader: 'video/mp4,video/*;q=0.9,*/*;q=0.8',
        HttpHeaders.acceptLanguageHeader: 'en-US,en;q=0.9',
        HttpHeaders.acceptEncodingHeader: 'identity',
        HttpHeaders.refererHeader: referer ?? _bloggerReferer,
        'Origin': _bloggerOrigin,
      };

      if (cookieHeader.isNotEmpty) {
        headers[HttpHeaders.cookieHeader] = cookieHeader;
      }

      final finalUrl = effectiveUri.toString();
      debugPrint('Cleaned Google Video URL: $finalUrl');

      return VideoStreamResult(
        url: finalUrl,
        headers: headers,
        isGoogleVideo: true,
      );
    } catch (e) {
      debugPrint('Error processing Google Video URL: $e');

      final fallbackHeaders = {
        HttpHeaders.userAgentHeader: _googleVideoUserAgent,
        HttpHeaders.refererHeader: referer ?? _bloggerReferer,
        'Origin': _bloggerOrigin,
      };

      return VideoStreamResult(
        url: googleVideoUrl,
        headers: fallbackHeaders,
        isGoogleVideo: true,
      );
    }
  }

  static Uri _sanitizeGoogleVideoUri(Uri uri) {
    final params = Map<String, String>.from(uri.queryParameters);
    params.removeWhere((key, value) => value.isEmpty);
    return uri.replace(queryParameters: params);
  }

  static String _treatAnimeName(String animeName) {
    return _normalizeAnimeFireSearchTitle(animeName).replaceAll(' ', '-');
  }

  static List<String> _buildSearchQueries(String animeName) {
    final queries = <String>[];

    void addQuery(String value) {
      final cleaned = value.trim();
      if (cleaned.isEmpty) return;
      if (!queries.contains(cleaned)) {
        queries.add(cleaned);
      }
    }

    final normalized = _normalizeAnimeTitle(animeName);
    addQuery(animeName);
    addQuery(_normalizeAnimeFireSearchTitle(animeName));
    addQuery(normalized);
    addQuery(normalized.replaceAll(':', ' '));

    final withoutSeason = normalized
        .replaceAll(
          RegExp(
            r'\b\d+(?:st|nd|rd|th)\s+season\b|\bseason\s+\d+\b|\btemporada\s+\d+\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    addQuery(withoutSeason);

    final withoutPart = withoutSeason
        .replaceAll(
          RegExp(r'\bpart\s+\d+\b|\bcour\s+\d+\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    addQuery(withoutPart);

    final shortTitle = withoutPart
        .replaceAll(
          RegExp(
            r'\s*\([^)]*\)|\s*\[[^\]]*\]|(?:dublado|legendado|dub|sub)',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    addQuery(shortTitle);

    return queries;
  }

  static String _normalizeAnimeFireSearchTitle(String title) {
    return title
        .toLowerCase()
        .replaceAll(
          RegExp(r'\s+\d+(\.\d+)?\s+a\d+\s*$', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'[\(\)\[\]]'), ' ')
        .replaceAll(
          RegExp(r'(?:todos os episodios|legendado|subbed|subtitle)'),
          ' ',
        )
        .replaceAll(RegExp(r'[^\w]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalizeAnimeTitle(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'\s*\([^)]*\)|\s*\[[^\]]*\]'), ' ')
        .replaceAll(
          RegExp(
            r'(?:dublado|legendado|dub|sub|subbed|subtitle|todos os episodios)',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(r'\s+\d+(\.\d+)?\s+A\d+\s*$', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'[^\w:]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int _scoreTitleMatch(String candidate, String query) {
    if (candidate.isEmpty || query.isEmpty) {
      return 0;
    }

    if (candidate == query) {
      return 1000;
    }

    if (candidate.startsWith(query) || query.startsWith(candidate)) {
      return 800;
    }

    if (candidate.contains(query) || query.contains(candidate)) {
      return 600;
    }

    final candidateTokens = candidate
        .split(' ')
        .where((token) => token.isNotEmpty);
    final queryTokens = query
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toSet();
    var overlap = 0;
    for (final token in candidateTokens) {
      if (queryTokens.contains(token)) {
        overlap++;
      }
    }

    final lengthPenalty = (candidate.length - query.length).abs().clamp(0, 40);
    return (overlap * 80) - lengthPenalty;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  Widget build(BuildContext context) {
    final localeService = Provider.of<LocaleService?>(context);

    return AnimatedBuilder(
      animation: _themeProvider,
      builder: (context, _) {
        return MaterialApp(
          title: 'NekoCast',
          debugShowCheckedModeBanner: false,
          locale: localeService?.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              secondary: AppColors.secondary,
              surface: Color(0xFFFFF7F0),
              error: AppColors.error,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: Color(0xFF2A1B14),
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFFFF7F0),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: AppColors.surface,
              contentTextStyle: const TextStyle(color: AppColors.textPrimary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: AppColors.primary,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.primary, width: 1.4),
              ),
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              secondary: AppColors.accent,
              surface: AppColors.surface,
              error: AppColors.error,
              onPrimary: Colors.white,
              onSecondary: Color(0xFF1F140E),
              onSurface: AppColors.textPrimary,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.background,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: AppColors.surfaceLight,
              contentTextStyle: const TextStyle(color: AppColors.textPrimary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: AppColors.primary,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.primary, width: 1.4),
              ),
            ),
          ),
          themeMode: _themeProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const MainNavigationScreen(),
        );
      },
    );
  }
}

// Search Screen
class AnimeSearchScreen extends StatefulWidget {
  final ThemeProvider themeProvider;

  const AnimeSearchScreen({super.key, required this.themeProvider});

  @override
  State<AnimeSearchScreen> createState() => _AnimeSearchScreenState();
}

class _AnimeSearchScreenState extends State<AnimeSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Anime> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _searchAnime() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await AnimeService.searchAnime(
        _searchController.text.trim(),
      );
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });

      // Add anime names to database
      final animeNames = results.map((anime) => anime.name).toList();
      await DatabaseHelper.addAnimeNames(animeNames);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildSearchField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.14),
            ),
            color: colorScheme.surface.withValues(alpha: 0.7),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por tÃ­tulo, saga ou estÃºdio...',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsetsDirectional.only(start: 16, end: 12),
                child: Icon(Icons.search_rounded, color: colorScheme.primary),
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: _searchAnime,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Buscar'),
                      ),
              ),
            ),
            onSubmitted: (_) => _searchAnime(),
            textInputAction: TextInputAction.search,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_searchResults.isEmpty) {
      if (_isLoading) {
        return _buildLoadingState();
      }
      return _buildEmptyState();
    }

    return _buildResultsList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Procurando pelos melhores episÃ³dios...'),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.airplay_rounded, size: 64, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Explore o catÃ¡logo',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pesquise por tÃ­tulos populares, gÃªneros ou utilize sua lista de favoritos.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: colorScheme.errorContainer,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_rounded,
            size: 56,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(height: 16),
          Text(
            'NÃ£o foi possÃ­vel concluir sua busca',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onErrorContainer,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Tente novamente em instantes.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onErrorContainer.withValues(alpha: 0.85),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          FilledButton.tonalIcon(
            onPressed: _searchAnime,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
            style: FilledButton.styleFrom(
              foregroundColor: colorScheme.onErrorContainer,
              backgroundColor: colorScheme.onErrorContainer.withValues(
                alpha: 0.12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    final theme = Theme.of(context);
    final label =
        '${_searchResults.length} resultado${_searchResults.length == 1 ? '' : 's'} encontrados';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _searchResults.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final anime = _searchResults[index];
            return _AnimeResultCard(
              anime: anime,
              index: index,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnimeDetailScreen(anime: anime),
                  ),
                );
              },
              onEpisodesTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EpisodeListScreen(anime: anime),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 60),
              title: const Text(
                'NekoCast',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 3.0,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF04c6c5), Color(0xFF03a5a4)],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  widget.themeProvider.isDarkMode
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: () {
                  widget.themeProvider.toggleTheme();
                  HapticFeedback.lightImpact();
                },
                tooltip: widget.themeProvider.isDarkMode
                    ? 'Tema claro'
                    : 'Tema escuro',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comece uma nova maratona',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pesquise por tÃ­tulos, sagas ou estÃºdios para encontrar seu anime.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSearchField(context),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _buildSearchContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimeResultCard extends StatelessWidget {
  final Anime anime;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onEpisodesTap;

  const _AnimeResultCard({
    required this.anime,
    required this.index,
    required this.onTap,
    this.onEpisodesTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final indexLabel = (index + 1).toString().padLeft(2, '0');
    final hasImage = anime.imageUrl.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      splashColor: colorScheme.primary.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
              colorScheme.surface,
            ],
          ),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Anime Cover Image
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 80,
                  height: 110,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  ),
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: anime.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            return _buildPlaceholder(
                              colorScheme,
                              indexLabel,
                              theme,
                            );
                          },
                        )
                      : _buildPlaceholder(colorScheme, indexLabel, theme),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            anime.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: anime.source == AnimeSource.animeFire
                                ? Colors.orange.withValues(alpha: 0.2)
                                : Colors.purple.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: anime.source == AnimeSource.animeFire
                                  ? Colors.orange.withValues(alpha: 0.5)
                                  : Colors.purple.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            anime.sourceName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: anime.source == AnimeSource.animeFire
                                  ? Colors.orange.shade800
                                  : Colors.purple.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (anime.genres.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: anime.genres.take(2).map((genre) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              genre,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (anime.averageScore != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(anime.averageScore! / 10).toStringAsFixed(1)}/10',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.75,
                              ),
                            ),
                          ),
                          if (anime.episodeCount != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.movie_filter_rounded,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${anime.episodeCount} eps',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.75,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ] else
                      Text(
                        'Toque para ver episÃ³dios',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.72,
                          ),
                          letterSpacing: 0.1,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onEpisodesTap != null)
                InkWell(
                  onTap: onEpisodesTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: colorScheme.primary.withValues(alpha: 0.12),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(
    ColorScheme colorScheme,
    String indexLabel,
    ThemeData theme,
  ) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.8),
            colorScheme.secondaryContainer.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_rounded,
            size: 32,
            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 4),
          Text(
            '#$indexLabel',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Anime Detail Screen - Estilo Crunchyroll
class AnimeDetailScreen extends StatelessWidget {
  final Anime anime;

  const AnimeDetailScreen({super.key, required this.anime});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasBanner = anime.bannerUrl.isNotEmpty;
    final hasDescription = anime.description.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar com Banner
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Banner ou Gradiente
                  if (hasBanner)
                    CachedNetworkImage(
                      imageUrl: anime.bannerUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary,
                            ],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary,
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [colorScheme.primary, colorScheme.secondary],
                        ),
                      ),
                    ),
                  // Overlay Gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ConteÃºdo Principal
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header com Capa e Info Principal
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Capa
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: anime.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: anime.imageUrl,
                                width: 100,
                                height: 145,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 100,
                                  height: 145,
                                  color: colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 100,
                                  height: 145,
                                  color: colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.movie_rounded,
                                    size: 40,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : Container(
                                width: 100,
                                height: 145,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primaryContainer,
                                      colorScheme.secondaryContainer,
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.movie_rounded,
                                  size: 40,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),

                      // Info Principal
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anime.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),

                            // Rating
                            if (anime.averageScore != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade600,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      (anime.averageScore! / 10)
                                          .toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 10),

                            // InformaÃ§Ãµes secundÃ¡rias
                            _buildInfoRow(
                              context,
                              Icons.movie_filter_rounded,
                              anime.episodeCount != null
                                  ? '${anime.episodeCount} eps'
                                  : 'EpisÃ³dios variados',
                            ),
                            if (anime.status != null) ...[
                              const SizedBox(height: 5),
                              _buildInfoRow(
                                context,
                                Icons.radio_button_checked,
                                _translateStatus(anime.status!),
                              ),
                            ],
                            if (anime.aniListData?.format != null) ...[
                              const SizedBox(height: 5),
                              _buildInfoRow(
                                context,
                                Icons.category_rounded,
                                anime.aniListData!.format!.displayName,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // BotÃ£o "Assistir EpisÃ³dios"
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EpisodeListScreen(anime: anime),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text(
                        'Assistir EpisÃ³dios',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // GÃªneros
                if (anime.genres.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GÃªneros',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: anime.genres.map((genre) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.secondary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                genre,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // DescriÃ§Ã£o/Sinopse
                if (hasDescription) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sinopse',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _cleanDescription(anime.description),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                              fontSize: 14,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // InformaÃ§Ãµes Adicionais
                if (anime.aniListData != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'InformaÃ§Ãµes',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              if (anime.aniListData!.season != null &&
                                  anime.aniListData!.seasonYear != null)
                                _buildInfoTile(
                                  context,
                                  'Temporada',
                                  '${_translateSeason(anime.aniListData!.season!)} ${anime.aniListData!.seasonYear}',
                                ),
                              if (anime.anilistId != null)
                                _buildInfoTile(
                                  context,
                                  'AniList ID',
                                  anime.anilistId.toString(),
                                ),
                              if (anime.malId != null)
                                _buildInfoTile(
                                  context,
                                  'MyAnimeList ID',
                                  anime.malId.toString(),
                                ),
                              if (anime.aniListData!.popularity != null)
                                _buildInfoTile(
                                  context,
                                  'Popularidade',
                                  '#${anime.aniListData!.popularity}',
                                  isLast: true,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.primary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
    BuildContext context,
    String label,
    String value, {
    bool isLast = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: 10),
          Divider(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            height: 1,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  String _cleanDescription(String description) {
    // Remove HTML tags
    String cleaned = description.replaceAll(RegExp(r'<[^>]*>'), '');
    // Remove extra whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Decode HTML entities
    cleaned = cleaned
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#039;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&lsquo;', "'")
        .replaceAll('&rdquo;', '"')
        .replaceAll('&ldquo;', '"')
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n');
    return cleaned;
  }

  String _translateStatus(String status) {
    switch (status.toUpperCase()) {
      case 'FINISHED':
        return 'Finalizado';
      case 'RELEASING':
        return 'Em LanÃ§amento';
      case 'NOT_YET_RELEASED':
        return 'NÃ£o LanÃ§ado';
      case 'CANCELLED':
        return 'Cancelado';
      case 'HIATUS':
        return 'Em Hiato';
      default:
        return status;
    }
  }

  String _translateSeason(String season) {
    switch (season.toUpperCase()) {
      case 'WINTER':
        return 'Inverno';
      case 'SPRING':
        return 'Primavera';
      case 'SUMMER':
        return 'VerÃ£o';
      case 'FALL':
        return 'Outono';
      default:
        return season;
    }
  }
}

// Episode List Screen
class EpisodeListScreen extends StatefulWidget {
  final Anime anime;

  const EpisodeListScreen({super.key, required this.anime});

  @override
  State<EpisodeListScreen> createState() => _EpisodeListScreenState();
}

class _EpisodeListScreenState extends State<EpisodeListScreen> {
  List<Episode> _episodes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[EpisodeListScreen] initState - Anime: ${widget.anime.name}, '
      'Has aniListData: ${widget.anime.aniListData != null}, '
      'AniList ID: ${widget.anime.anilistId}, '
      'MAL ID: ${widget.anime.malId}',
    );
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final episodes = await AnimeService.getAnimeEpisodes(widget.anime);
      setState(() {
        _episodes = episodes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasEpisodes =
        !_isLoading && _errorMessage == null && _episodes.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            title: Text(
              widget.anime.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              titlePadding: EdgeInsets.zero,
              background: _buildFlexibleHeader(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _buildStatusContent(context),
              ),
            ),
          ),
          if (hasEpisodes)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final episode = _episodes[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _episodes.length - 1 ? 0 : 10,
                    ),
                    child: _EpisodeCard(
                      episode: episode,
                      index: index,
                      onTap: () => _openEpisode(episode),
                    ),
                  );
                }, childCount: _episodes.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFlexibleHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasBanner = widget.anime.bannerUrl.isNotEmpty;
    final hasImage = widget.anime.imageUrl.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background - Banner or Gradient
        if (hasBanner)
          CachedNetworkImage(
            imageUrl: widget.anime.bannerUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorScheme.primary, colorScheme.secondary],
                ),
              ),
            ),
            errorWidget: (context, url, error) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colorScheme.primary, colorScheme.secondary],
                  ),
                ),
              );
            },
          )
        else
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colorScheme.primary, colorScheme.secondary],
              ),
            ),
          ),
        // Overlay gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.65),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Cover image
                      if (hasImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: widget.anime.imageUrl,
                            width: 60,
                            height: 85,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 60,
                              height: 85,
                              color: Colors.white.withValues(alpha: 0.1),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              return Container(
                                width: 60,
                                height: 85,
                                color: Colors.white.withValues(alpha: 0.1),
                                child: const Icon(
                                  Icons.movie_rounded,
                                  size: 28,
                                  color: Colors.white54,
                                ),
                              );
                            },
                          ),
                        )
                      else
                        const LogoWidget(size: 32, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.anime.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            if (widget.anime.averageScore != null ||
                                widget.anime.episodeCount != null)
                              Row(
                                children: [
                                  if (widget.anime.averageScore != null) ...[
                                    Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: Colors.amber.shade400,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      (widget.anime.averageScore! / 10)
                                          .toStringAsFixed(1),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                    ),
                                  ],
                                  if (widget.anime.episodeCount != null) ...[
                                    if (widget.anime.averageScore != null)
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        width: 3,
                                        height: 3,
                                        decoration: const BoxDecoration(
                                          color: Colors.white54,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    Icon(
                                      Icons.movie_filter_rounded,
                                      size: 14,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${widget.anime.episodeCount} eps',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                    ),
                                  ],
                                ],
                              )
                            else
                              Text(
                                'EpisÃ³dios disponÃ­veis',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontSize: 12,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusContent(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState(context);
    }

    if (_errorMessage != null) {
      return _buildErrorState(context);
    }

    if (_episodes.isEmpty) {
      return _buildEmptyState(context);
    }

    return _buildEpisodesHeader(context);
  }

  Widget _buildLoadingState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('episode-loading'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surface.withValues(alpha: 0.8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            'Carregando episÃ³dios...',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('episode-error'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.errorContainer,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 40,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar episÃ³dios',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onErrorContainer,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Tente novamente em alguns instantes.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onErrorContainer.withValues(alpha: 0.8),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _loadEpisodes,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              'Tentar novamente',
              style: TextStyle(fontSize: 13),
            ),
            style: FilledButton.styleFrom(
              foregroundColor: colorScheme.onErrorContainer,
              backgroundColor: colorScheme.onErrorContainer.withValues(
                alpha: 0.12,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const ValueKey('episode-empty'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tv_off_rounded, size: 48, color: colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            'Nenhum episÃ³dio disponÃ­vel',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Volte mais tarde para novas atualizaÃ§Ãµes.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const ValueKey('episode-header'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surface.withValues(alpha: 0.85),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.playlist_play_rounded,
            color: colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_episodes.length} episÃ³dio${_episodes.length == 1 ? '' : 's'}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openEpisode(Episode episode) {
    HapticFeedback.lightImpact();
    debugPrint(
      '[EpisodeListScreen] Opening video - Anime: ${widget.anime.name}, '
      'Has aniListData: ${widget.anime.aniListData != null}, '
      'AniList ID: ${widget.anime.anilistId}, '
      'MAL ID: ${widget.anime.malId}',
    );
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ModernVideoPlayerScreen(
              episode: episode,
              animeTitle: widget.anime.name,
              anime: widget.anime, // Passar anime completo
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  final Episode episode;
  final int index;
  final VoidCallback onTap;

  const _EpisodeCard({
    required this.episode,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayTitle = episode.number.toLowerCase().contains('epis')
        ? episode.number
        : 'EpisÃ³dio ${episode.number}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      splashColor: colorScheme.primary.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.18),
              colorScheme.surface,
            ],
          ),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.09),
              blurRadius: 22,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colorScheme.primary, colorScheme.secondary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${index + 1}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Assista com qualidade estabilizada e sem travamentos.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BloggerWebViewScreen extends StatefulWidget {
  final String initialUrl;
  final String title;
  final Map<String, String> headers;

  const BloggerWebViewScreen({
    super.key,
    required this.initialUrl,
    required this.title,
    this.headers = const {},
  });

  @override
  State<BloggerWebViewScreen> createState() => _BloggerWebViewScreenState();
}

class _BloggerWebViewScreenState extends State<BloggerWebViewScreen> {
  WebViewController? _webViewController;
  Player? _mediaKitPlayer;
  VideoController? _mediaKitVideoController;
  BetterPlayerController? _betterPlayerController;
  GoogleVideoProxy? _streamProxy;
  bool _isDirectPlayer = false;
  bool _isPreparingVideo = true;
  String? _videoError;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    PlaybackWakeLock.acquire();
    _isDirectPlayer = _isDirectVideoUrl(widget.initialUrl);
    if (_isDirectPlayer) {
      _initializeDirectPlayer();
    } else {
      _loadWebView(widget.initialUrl);
    }
  }

  void _loadWebView(String url) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _progress = progress / 100.0;
              });
            }
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _progress = 0;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _progress = 1;
              });
            }
          },
          onNavigationRequest: (navigation) {
            return NavigationDecision.navigate;
          },
        ),
      );

    _webViewController = controller;
    controller.loadRequest(Uri.parse(url), headers: widget.headers);
  }

  Future<void> _initializeDirectPlayer() async {
    setState(() {
      _isPreparingVideo = true;
      _videoError = null;
    });

    try {
      final oldMediaKitPlayer = _mediaKitPlayer;
      _mediaKitPlayer = null;
      _mediaKitVideoController = null;
      await oldMediaKitPlayer?.dispose();
      _betterPlayerController?.dispose();
      _betterPlayerController = null;
      await _streamProxy?.stop();
      _streamProxy = null;

      final originalUrl = widget.initialUrl;
      final headers = _videoHeaders();
      var playbackUrl = originalUrl;
      var playbackHeaders = headers;

      if (!originalUrl.toLowerCase().contains('.m3u8')) {
        _streamProxy = GoogleVideoProxy(
          targetUri: Uri.parse(originalUrl),
          forwardHeaders: headers,
        );
        final proxyUri = await _streamProxy!.start();
        playbackUrl = proxyUri.toString();
        playbackHeaders = const {};
      }

      if (_usesMediaKitDirectPlayer) {
        _mediaKitPlayer = Player();
        _mediaKitVideoController = VideoController(_mediaKitPlayer!);
        _mediaKitPlayer!.stream.error.listen((error) {
          debugPrint('[AlternativePlayer] MediaKit error: $error');
          if (mounted) {
            setState(() {
              _videoError = 'Erro no player nativo: $error';
              _isPreparingVideo = false;
            });
          }
        });
        await _mediaKitPlayer!.open(
          Media(playbackUrl, httpHeaders: playbackHeaders),
          play: true,
        );
      } else {
        final dataSource = BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          playbackUrl,
          headers: playbackHeaders,
        );
        _betterPlayerController = BetterPlayerController(
          const BetterPlayerConfiguration(
            autoPlay: true,
            looping: false,
            allowedScreenSleep: false,
            fit: BoxFit.contain,
            handleLifecycle: true,
          ),
          betterPlayerDataSource: dataSource,
        );
      }

      if (!mounted) return;

      setState(() {
        _isPreparingVideo = false;
      });
    } catch (e) {
      debugPrint('[AlternativePlayer] Direct player failed: $e');
      if (!mounted) return;
      setState(() {
        _isPreparingVideo = false;
        _videoError = e.toString();
      });
    }
  }

  Map<String, String> _videoHeaders() {
    final headers = Map<String, String>.from(widget.headers);
    headers.putIfAbsent(
      HttpHeaders.userAgentHeader,
      () =>
          'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
    );
    headers.putIfAbsent(
      HttpHeaders.acceptHeader,
      () => 'video/mp4,video/*;q=0.9,*/*;q=0.8',
    );
    headers.putIfAbsent(HttpHeaders.acceptEncodingHeader, () => 'identity');
    return headers;
  }

  bool get _usesMediaKitDirectPlayer =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  bool _isDirectVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.m3u8') ||
        lower.contains('videoplayback') ||
        lower.contains('googlevideo') ||
        lower.contains('googleusercontent');
  }

  @override
  void dispose() {
    PlaybackWakeLock.release();
    _mediaKitPlayer?.dispose();
    _betterPlayerController?.dispose();
    _streamProxy?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (!_isDirectPlayer && _progress < 1)
            LinearProgressIndicator(
              value: _progress,
              minHeight: 3,
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Colors.white10,
            ),
          Expanded(
            child: _isDirectPlayer
                ? _buildDirectPlayerBody()
                : (_webViewController != null
                      ? WebViewWidget(controller: _webViewController!)
                      : const SizedBox.shrink()),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectPlayerBody() {
    if (_isPreparingVideo) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_videoError != null ||
        (_usesMediaKitDirectPlayer &&
            (_mediaKitPlayer == null || _mediaKitVideoController == null)) ||
        (!_usesMediaKitDirectPlayer && _betterPlayerController == null)) {
      return _buildDirectError(
        _videoError ?? 'Nao foi possivel abrir o video.',
      );
    }

    if (!_usesMediaKitDirectPlayer) {
      return BetterPlayer(controller: _betterPlayerController!);
    }

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: DesktopVideoPlayer(
          player: _mediaKitPlayer!,
          controller: _mediaKitVideoController!,
          title: widget.title,
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildDirectError(String message) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 46),
          const SizedBox(height: 16),
          const Text(
            'Erro no player alternativo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: _initializeDirectPlayer,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isDirectPlayer = false;
                    _progress = 0;
                  });
                  _loadWebView(widget.initialUrl);
                },
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Abrir como pagina'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
