import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/jikan_models.dart';

/// Cache entry com timestamp para expiração
class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;

  _CacheEntry(this.data) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp).inMinutes > 30;
}

/// Resultado do carregamento da Home com todos os dados
class HomeData {
  final List<JikanAnime> seasonAnimes;
  final List<JikanAnime> topAnimes;
  final List<JikanAnime> actionAnimes;
  final List<JikanAnime> romanceAnimes;
  final List<JikanAnime> comedyAnimes;
  final List<JikanAnime> fantasyAnimes;
  final DateTime loadedAt;

  HomeData({
    required this.seasonAnimes,
    required this.topAnimes,
    required this.actionAnimes,
    required this.romanceAnimes,
    required this.comedyAnimes,
    required this.fantasyAnimes,
    DateTime? loadedAt,
  }) : loadedAt = loadedAt ?? DateTime.now();

  bool get isExpired => DateTime.now().difference(loadedAt).inMinutes > 30;

  bool get hasContent =>
      seasonAnimes.isNotEmpty &&
      topAnimes.isNotEmpty &&
      actionAnimes.isNotEmpty &&
      romanceAnimes.isNotEmpty &&
      comedyAnimes.isNotEmpty &&
      fantasyAnimes.isNotEmpty;

  /// Serializa para JSON para persistência
  Map<String, dynamic> toJson() => {
    'seasonAnimes': seasonAnimes.map((a) => a.toJson()).toList(),
    'topAnimes': topAnimes.map((a) => a.toJson()).toList(),
    'actionAnimes': actionAnimes.map((a) => a.toJson()).toList(),
    'romanceAnimes': romanceAnimes.map((a) => a.toJson()).toList(),
    'comedyAnimes': comedyAnimes.map((a) => a.toJson()).toList(),
    'fantasyAnimes': fantasyAnimes.map((a) => a.toJson()).toList(),
    'loadedAt': loadedAt.toIso8601String(),
  };

  /// Deserializa do JSON
  factory HomeData.fromJson(Map<String, dynamic> json) {
    final cachedAt = DateTime.tryParse(json['loadedAt']?.toString() ?? '');
    return HomeData(
      seasonAnimes: (json['seasonAnimes'] as List? ?? [])
          .map((j) => JikanAnime.fromJson(j))
          .toList(),
      topAnimes: (json['topAnimes'] as List? ?? [])
          .map((j) => JikanAnime.fromJson(j))
          .toList(),
      actionAnimes: (json['actionAnimes'] as List? ?? [])
          .map((j) => JikanAnime.fromJson(j))
          .toList(),
      romanceAnimes: (json['romanceAnimes'] as List? ?? [])
          .map((j) => JikanAnime.fromJson(j))
          .toList(),
      comedyAnimes: (json['comedyAnimes'] as List? ?? [])
          .map((j) => JikanAnime.fromJson(j))
          .toList(),
      fantasyAnimes: (json['fantasyAnimes'] as List? ?? [])
          .map((j) => JikanAnime.fromJson(j))
          .toList(),
      loadedAt: cachedAt,
    );
  }
}

class JikanService {
  static const String baseUrl = 'https://api.jikan.moe/v4';
  static const String _homeDataCacheKey = 'jikan_home_data_cache';

  // Cache em memória singleton para toda a app
  static HomeData? _homeDataCache;
  static final Map<String, _CacheEntry<List<JikanAnime>>> _cache = {};
  static const int _maxCacheSize = 50;
  static bool _isLoadingHome = false;

  /// Limpa cache expirado
  static void _cleanExpiredCache() {
    _cache.removeWhere((key, entry) => entry.isExpired);
    if (_cache.length > _maxCacheSize) {
      final keysToRemove = _cache.keys
          .take(_cache.length - _maxCacheSize)
          .toList();
      for (final key in keysToRemove) {
        _cache.remove(key);
      }
    }
  }

  /// Obtém do cache se disponível e não expirado
  List<JikanAnime>? _getFromCache(String key) {
    _cleanExpiredCache();
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      debugPrint('[JikanService] Cache hit: $key');
      return entry.data;
    }
    return null;
  }

  /// Salva no cache
  void _saveToCache(String key, List<JikanAnime> data) {
    _cache[key] = _CacheEntry(data);
  }

  /// Carrega cache persistente do SharedPreferences
  Future<HomeData?> _loadPersistedHomeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_homeDataCacheKey);
      if (jsonStr != null) {
        final data = HomeData.fromJson(json.decode(jsonStr));

        // Check if cached data is the broken/repeated 5-item fallback
        final isDuplicatedFallback = data.seasonAnimes.isNotEmpty &&
            data.topAnimes.isNotEmpty &&
            data.seasonAnimes.first.title == data.topAnimes.first.title &&
            data.seasonAnimes.length <= 5;

        if (isDuplicatedFallback) {
          debugPrint('[JikanService] Discarding outdated duplicated fallback cache.');
          await prefs.remove(_homeDataCacheKey);
          return null;
        }

        if (!data.isExpired && data.hasContent) {
          debugPrint('[JikanService] Loaded home data from persistent cache');
          return data;
        }
      }
    } catch (e) {
      debugPrint('[JikanService] Error loading persisted cache: $e');
    }
    return null;
  }

  /// Salva cache persistente no SharedPreferences
  Future<void> _persistHomeData(HomeData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_homeDataCacheKey, json.encode(data.toJson()));
      debugPrint('[JikanService] Home data persisted to cache');
    } catch (e) {
      debugPrint('[JikanService] Error persisting cache: $e');
    }
  }

  /// MÉTODO PRINCIPAL: Carrega TODOS os dados da Home de uma vez
  Future<HomeData> loadHomeData({bool forceRefresh = false}) async {
    if (!forceRefresh && _homeDataCache != null && !_homeDataCache!.isExpired) {
      debugPrint('[JikanService] Returning memory cached home data');
      return _homeDataCache!;
    }

    if (_isLoadingHome) {
      debugPrint('[JikanService] Already loading, waiting...');
      while (_isLoadingHome) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_homeDataCache != null) return _homeDataCache!;
    }

    if (!forceRefresh) {
      final persisted = await _loadPersistedHomeData();
      if (persisted != null) {
        _homeDataCache = persisted;
        return persisted;
      }
    }

    _isLoadingHome = true;
    debugPrint('[JikanService] Loading all home data in parallel...');

    try {
      final stopwatch = Stopwatch()..start();

      final batch1 = await Future.wait([
        _fetchHomeWithFallback('$baseUrl/seasons/now?limit=15'),
        _fetchHomeWithFallback('$baseUrl/top/anime?limit=15'),
        _fetchHomeWithFallback(
          '$baseUrl/anime?genres=${JikanGenreIds.action}&limit=15&order_by=score&sort=desc',
        ),
      ]);

      await Future.delayed(const Duration(milliseconds: 300));

      final batch2 = await Future.wait([
        _fetchHomeWithFallback(
          '$baseUrl/anime?genres=${JikanGenreIds.romance}&limit=15&order_by=score&sort=desc',
        ),
        _fetchHomeWithFallback(
          '$baseUrl/anime?genres=${JikanGenreIds.comedy}&limit=15&order_by=score&sort=desc',
        ),
        _fetchHomeWithFallback(
          '$baseUrl/anime?genres=${JikanGenreIds.fantasy}&limit=15&order_by=score&sort=desc',
        ),
      ]);

      stopwatch.stop();
      debugPrint(
        '[JikanService] Jikan batch loaded in ${stopwatch.elapsedMilliseconds}ms',
      );

      var season = _parseAnimeList(batch1[0]);
      var top = _parseAnimeList(batch1[1]);
      var action = _parseAnimeList(batch1[2]);
      var romance = _parseAnimeList(batch2[0]);
      var comedy = _parseAnimeList(batch2[1]);
      var fantasy = _parseAnimeList(batch2[2]);

      // If Jikan missed categories, try AniList multi-query
      if (season.isEmpty ||
          top.isEmpty ||
          action.isEmpty ||
          romance.isEmpty ||
          comedy.isEmpty ||
          fantasy.isEmpty) {
        debugPrint('[JikanService] Incomplete Jikan categories, attempting AniList fallback...');
        final aniListHome = await _fetchAllCategoriesViaAniList();
        if (aniListHome != null) {
          if (season.isEmpty) season = aniListHome.seasonAnimes;
          if (top.isEmpty) top = aniListHome.topAnimes;
          if (action.isEmpty) action = aniListHome.actionAnimes;
          if (romance.isEmpty) romance = aniListHome.romanceAnimes;
          if (comedy.isEmpty) comedy = aniListHome.comedyAnimes;
          if (fantasy.isEmpty) fantasy = aniListHome.fantasyAnimes;
        }
      }

      // If categories are still missing (e.g. AniList 403 or down), fetch via Kitsu
      if (season.isEmpty ||
          top.isEmpty ||
          action.isEmpty ||
          romance.isEmpty ||
          comedy.isEmpty ||
          fantasy.isEmpty) {
        debugPrint('[JikanService] Incomplete categories after AniList, attempting Kitsu fallback...');
        final kitsuHome = await _fetchAllCategoriesViaKitsu();
        if (kitsuHome != null) {
          if (season.isEmpty) season = kitsuHome.seasonAnimes;
          if (top.isEmpty) top = kitsuHome.topAnimes;
          if (action.isEmpty) action = kitsuHome.actionAnimes;
          if (romance.isEmpty) romance = kitsuHome.romanceAnimes;
          if (comedy.isEmpty) comedy = kitsuHome.comedyAnimes;
          if (fantasy.isEmpty) fantasy = kitsuHome.fantasyAnimes;
        }
      }

      final homeData = HomeData(
        seasonAnimes: season.isNotEmpty ? season : top,
        topAnimes: top.isNotEmpty ? top : season,
        actionAnimes: action,
        romanceAnimes: romance,
        comedyAnimes: comedy,
        fantasyAnimes: fantasy,
      );

      if (!homeData.hasContent) {
        final kitsuHome = await _fetchAllCategoriesViaKitsu();
        if (kitsuHome != null && kitsuHome.hasContent) {
          _homeDataCache = kitsuHome;
          _persistHomeData(kitsuHome);
          return kitsuHome;
        }
        final fallback = _fallbackHomeData();
        _homeDataCache = fallback;
        return fallback;
      }

      _homeDataCache = homeData;
      _persistHomeData(homeData);

      return homeData;
    } catch (e) {
      debugPrint('[JikanService] Error loading home data: $e. Trying AniList/Kitsu fallbacks...');
      final aniListHome = await _fetchAllCategoriesViaAniList();
      if (aniListHome != null && aniListHome.hasContent) {
        _homeDataCache = aniListHome;
        _persistHomeData(aniListHome);
        return aniListHome;
      }
      final kitsuHome = await _fetchAllCategoriesViaKitsu();
      if (kitsuHome != null && kitsuHome.hasContent) {
        _homeDataCache = kitsuHome;
        _persistHomeData(kitsuHome);
        return kitsuHome;
      }
      final fallback = _fallbackHomeData();
      _homeDataCache = fallback;
      return fallback;
    } finally {
      _isLoadingHome = false;
    }
  }

  static Future<HomeData?> _fetchAllCategoriesViaAniList() async {
    try {
      const gqlQuery = '''
        query {
          season: Page(page: 1, perPage: 15) {
            media(type: ANIME, sort: TRENDING_DESC) {
              id
              idMal
              title { romaji english native }
              coverImage { extraLarge large medium }
              description
              episodes
              status
              averageScore
              genres
              seasonYear
              season
            }
          }
          top: Page(page: 1, perPage: 15) {
            media(type: ANIME, sort: SCORE_DESC) {
              id
              idMal
              title { romaji english native }
              coverImage { extraLarge large medium }
              description
              episodes
              status
              averageScore
              genres
              seasonYear
              season
            }
          }
          action: Page(page: 1, perPage: 15) {
            media(type: ANIME, genre: "Action", sort: POPULARITY_DESC) {
              id
              idMal
              title { romaji english native }
              coverImage { extraLarge large medium }
              description
              episodes
              status
              averageScore
              genres
              seasonYear
              season
            }
          }
          romance: Page(page: 1, perPage: 15) {
            media(type: ANIME, genre: "Romance", sort: POPULARITY_DESC) {
              id
              idMal
              title { romaji english native }
              coverImage { extraLarge large medium }
              description
              episodes
              status
              averageScore
              genres
              seasonYear
              season
            }
          }
          comedy: Page(page: 1, perPage: 15) {
            media(type: ANIME, genre: "Comedy", sort: POPULARITY_DESC) {
              id
              idMal
              title { romaji english native }
              coverImage { extraLarge large medium }
              description
              episodes
              status
              averageScore
              genres
              seasonYear
              season
            }
          }
          fantasy: Page(page: 1, perPage: 15) {
            media(type: ANIME, genre: "Fantasy", sort: POPULARITY_DESC) {
              id
              idMal
              title { romaji english native }
              coverImage { extraLarge large medium }
              description
              episodes
              status
              averageScore
              genres
              seasonYear
              season
            }
          }
        }
      ''';

      final response = await http
          .post(
            Uri.parse('https://graphql.anilist.co'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'query': gqlQuery}),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body);
        final data = jsonMap['data'] as Map<String, dynamic>? ?? {};

        List<JikanAnime> parseList(String key) {
          final list = data[key]?['media'] as List? ?? [];
          return list
              .map((item) => _convertAniListToJikan(item as Map<String, dynamic>))
              .toList();
        }

        final season = parseList('season');
        final top = parseList('top');
        final action = parseList('action');
        final romance = parseList('romance');
        final comedy = parseList('comedy');
        final fantasy = parseList('fantasy');

        return HomeData(
          seasonAnimes: season.isNotEmpty ? season : top,
          topAnimes: top,
          actionAnimes: action,
          romanceAnimes: romance,
          comedyAnimes: comedy,
          fantasyAnimes: fantasy,
        );
      }
    } catch (e) {
      debugPrint('[JikanService] AniList full home query error: $e');
    }
    return null;
  }

  static Future<HomeData?> _fetchAllCategoriesViaKitsu() async {
    try {
      final headers = {
        'Accept': 'application/vnd.api+json',
        'User-Agent': 'NekoCast/1.0',
      };
      final results = await Future.wait([
        http
            .get(
              Uri.parse(
                'https://kitsu.io/api/edge/anime?filter[status]=current&sort=-userCount&page[limit]=15',
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 8)),
        http
            .get(
              Uri.parse(
                'https://kitsu.io/api/edge/anime?sort=-averageRating&page[limit]=15',
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 8)),
        http
            .get(
              Uri.parse(
                'https://kitsu.io/api/edge/anime?filter[categories]=action&sort=-userCount&page[limit]=15',
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 8)),
        http
            .get(
              Uri.parse(
                'https://kitsu.io/api/edge/anime?filter[categories]=romance&sort=-userCount&page[limit]=15',
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 8)),
        http
            .get(
              Uri.parse(
                'https://kitsu.io/api/edge/anime?filter[categories]=comedy&sort=-userCount&page[limit]=15',
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 8)),
        http
            .get(
              Uri.parse(
                'https://kitsu.io/api/edge/anime?filter[categories]=fantasy&sort=-userCount&page[limit]=15',
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 8)),
      ]);

      List<JikanAnime> parseKitsuList(http.Response res) {
        if (res.statusCode != 200) return [];
        try {
          final json = jsonDecode(res.body);
          final data = json['data'] as List? ?? [];
          return data
              .map((item) => _convertKitsuToJikan(item as Map<String, dynamic>))
              .where((a) => a.imageUrl.isNotEmpty)
              .toList();
        } catch (_) {
          return [];
        }
      }

      final season = parseKitsuList(results[0]);
      final top = parseKitsuList(results[1]);
      final action = parseKitsuList(results[2]);
      final romance = parseKitsuList(results[3]);
      final comedy = parseKitsuList(results[4]);
      final fantasy = parseKitsuList(results[5]);

      if (season.isNotEmpty || top.isNotEmpty) {
        debugPrint(
          '[JikanService] Successfully loaded complete home catalog from Kitsu: '
          'season: ${season.length}, top: ${top.length}, action: ${action.length}, '
          'romance: ${romance.length}, comedy: ${comedy.length}, fantasy: ${fantasy.length}',
        );
        return HomeData(
          seasonAnimes: season.isNotEmpty ? season : top,
          topAnimes: top.isNotEmpty ? top : season,
          actionAnimes: action,
          romanceAnimes: romance,
          comedyAnimes: comedy,
          fantasyAnimes: fantasy,
        );
      }
    } catch (e) {
      debugPrint('[JikanService] Kitsu full home query error: $e');
    }
    return null;
  }

  Future<http.Response> _fetchHomeWithFallback(String url) async {
    try {
      return await _fetchWithRetry(url, maxRetries: 0);
    } catch (e) {
      return http.Response('{"data":[]}', 200);
    }
  }

  HomeData _fallbackHomeData() {
    final seasonFallback = [
      JikanAnime(
        malId: 52991,
        title: 'Sousou no Frieren',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1015/138006.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/1015/138006.jpg',
        score: 9.3,
      ),
      JikanAnime(
        malId: 52299,
        title: 'Solo Leveling',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1867/140026.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/1867/140026.jpg',
        score: 8.4,
      ),
      JikanAnime(
        malId: 51009,
        title: 'Jujutsu Kaisen 2nd Season',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1792/138042.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/1792/138042.jpg',
        score: 8.8,
      ),
      JikanAnime(
        malId: 55701,
        title: 'Kimetsu no Yaiba: Hashira Geiko-hen',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1798/142475.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/1798/142475.jpg',
        score: 8.3,
      ),
      JikanAnime(
        malId: 52034,
        title: '[Oshi no Ko]',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1813/135372.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/1813/135372.jpg',
        score: 8.7,
      ),
      JikanAnime(
        malId: 54790,
        title: 'Chainsaw Man',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1806/126216.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/1806/126216.jpg',
        score: 8.5,
      ),
    ];

    final topFallback = [
      JikanAnime(
        malId: 5114,
        title: 'Fullmetal Alchemist: Brotherhood',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1223/96541.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/1223/96541.jpg',
        score: 9.1,
      ),
      JikanAnime(
        malId: 9253,
        title: 'Steins;Gate',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1935/127974.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/1935/127974.jpg',
        score: 9.0,
      ),
      JikanAnime(
        malId: 11061,
        title: 'Hunter x Hunter (2011)',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1337/99013.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/1337/99013.jpg',
        score: 9.0,
      ),
      JikanAnime(
        malId: 41467,
        title: 'Bleach: Sennen Kessen-hen',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1764/126627.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/1764/126627.jpg',
        score: 9.0,
      ),
      JikanAnime(
        malId: 9969,
        title: "Gintama'",
        imageUrl: 'https://cdn.myanimelist.net/images/anime/4/50331.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/4/50331.jpg',
        score: 9.0,
      ),
      JikanAnime(
        malId: 1535,
        title: 'Death Note',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/9/9453.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/9/9453.jpg',
        score: 8.6,
      ),
    ];

    final actionFallback = [
      JikanAnime(
        malId: 16498,
        title: 'Shingeki no Kyojin',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/10/47347.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/10/47347.jpg',
        score: 8.5,
      ),
      JikanAnime(
        malId: 30276,
        title: 'One Punch Man',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/12/76049.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/12/76049.jpg',
        score: 8.5,
      ),
      JikanAnime(
        malId: 31964,
        title: 'Boku no Hero Academia',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/10/78745.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/10/78745.jpg',
        score: 7.9,
      ),
      JikanAnime(
        malId: 37521,
        title: 'Vinland Saga',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1500/103005.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/1500/103005.jpg',
        score: 8.7,
      ),
      JikanAnime(
        malId: 32182,
        title: 'Mob Psycho 100',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/8/80356.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/8/80356.jpg',
        score: 8.5,
      ),
      JikanAnime(
        malId: 22319,
        title: 'Tokyo Ghoul',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/5/64449.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/5/64449.jpg',
        score: 7.8,
      ),
    ];

    final romanceFallback = [
      JikanAnime(
        malId: 32281,
        title: 'Kimi no Na wa.',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/5/87048.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/5/87048.jpg',
        score: 8.8,
      ),
      JikanAnime(
        malId: 23273,
        title: 'Shigatsu wa Kimi no Uso',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/3/67177.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/3/67177.jpg',
        score: 8.6,
      ),
      JikanAnime(
        malId: 28851,
        title: 'Koe no Katachi',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1122/96442.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/1122/96442.jpg',
        score: 8.9,
      ),
      JikanAnime(
        malId: 37999,
        title: 'Kaguya-sama wa Kokurasetai',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/3/95786.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/3/95786.jpg',
        score: 8.4,
      ),
      JikanAnime(
        malId: 4224,
        title: 'Toradora!',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/13/22123.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/13/22123.jpg',
        score: 8.1,
      ),
      JikanAnime(
        malId: 42897,
        title: 'Horimiya',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1695/111486.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/1695/111486.jpg',
        score: 8.2,
      ),
    ];

    final comedyFallback = [
      JikanAnime(
        malId: 30831,
        title: 'KonoSuba',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/8/77831.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/8/77831.jpg',
        score: 8.1,
      ),
      JikanAnime(
        malId: 50265,
        title: 'Spy x Family',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1441/122795.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/1441/122795.jpg',
        score: 8.5,
      ),
      JikanAnime(
        malId: 33255,
        title: 'Saiki Kusuo no Psi-nan',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/12/81180.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/12/81180.jpg',
        score: 8.4,
      ),
      JikanAnime(
        malId: 47917,
        title: 'Bocchi the Rock!',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1448/127956.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/1448/127956.jpg',
        score: 8.8,
      ),
      JikanAnime(
        malId: 918,
        title: 'Gintama',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/10/73249.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/10/73249.jpg',
        score: 8.9,
      ),
      JikanAnime(
        malId: 10165,
        title: 'Nichijou',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/3/75617.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/3/75617.jpg',
        score: 8.5,
      ),
    ];

    final fantasyFallback = [
      JikanAnime(
        malId: 31240,
        title: 'Re:Zero kara Hajimeru Isekai Seikatsu',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/11/79410.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/11/79410.jpg',
        score: 8.2,
      ),
      JikanAnime(
        malId: 39535,
        title: 'Mushoku Tensei: Isekai Ittara Honki Dasu',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1530/117776.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/1530/117776.jpg',
        score: 8.4,
      ),
      JikanAnime(
        malId: 11757,
        title: 'Sword Art Online',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/11/39717.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/11/39717.jpg',
        score: 7.2,
      ),
      JikanAnime(
        malId: 29803,
        title: 'Overlord',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/7/88019.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/7/88019.jpg',
        score: 7.9,
      ),
      JikanAnime(
        malId: 35790,
        title: 'Tate no Yuusha no Nariagari',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1490/101365.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/1490/101365.jpg',
        score: 8.0,
      ),
      JikanAnime(
        malId: 34599,
        title: 'Made in Abyss',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/6/86733.jpg',
        largImageUrl: 'https://cdn.myanimelist.net/images/anime/6/86733.jpg',
        score: 8.7,
      ),
    ];

    return HomeData(
      seasonAnimes: seasonFallback,
      topAnimes: topFallback,
      actionAnimes: actionFallback,
      romanceAnimes: romanceFallback,
      comedyAnimes: comedyFallback,
      fantasyAnimes: fantasyFallback,
    );
  }

  Future<http.Response> _fetchWithRetry(
    String url, {
    int maxRetries = 1,
  }) async {
    for (int i = 0; i <= maxRetries; i++) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          return response;
        } else if (response.statusCode == 429 || response.statusCode == 504) {
          throw Exception('HTTP ${response.statusCode}');
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        if (i == maxRetries) rethrow;
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    throw Exception('Max retries exceeded');
  }

  /// Parse da lista de animes de uma resposta HTTP
  List<JikanAnime> _parseAnimeList(http.Response response) {
    try {
      final jsonData = json.decode(response.body);
      final jikanResponse = JikanResponse<JikanAnime>.fromJson(
        jsonData,
        (json) => JikanAnime.fromJson(json),
      );
      return jikanResponse.data;
    } catch (e) {
      debugPrint('[JikanService] Error parsing anime list: $e');
      return [];
    }
  }

  // Rate limiting para métodos individuais
  static DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(milliseconds: 400);

  /// Aguarda o intervalo mínimo entre requisições
  Future<void> _waitForRateLimit() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _minRequestInterval) {
        await Future.delayed(_minRequestInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  /// Métodos individuais (usados pela SearchScreen e outras telas)

  /// Busca os top animes
  Future<List<JikanAnime>> getTopAnimes({int page = 1, int limit = 20}) async {
    final cacheKey = 'top_${page}_$limit';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse('$baseUrl/top/anime?page=$page&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final result = _parseAnimeList(response);
        _saveToCache(cacheKey, result);
        return result;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching top animes: $e');
      return [];
    }
  }

  /// Busca animes da temporada atual
  Future<List<JikanAnime>> getCurrentSeasonAnimes({
    int page = 1,
    int limit = 20,
  }) async {
    final cacheKey = 'season_${page}_$limit';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse('$baseUrl/seasons/now?page=$page&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final result = _parseAnimeList(response);
        _saveToCache(cacheKey, result);
        return result;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching current season animes: $e');
      return [];
    }
  }



  /// Busca animes por gênero
  /// Gêneros disponíveis:
  /// - Action: 1
  /// - Adventure: 2
  /// - Comedy: 4
  /// - Drama: 8
  /// - Fantasy: 10
  /// - Horror: 14
  /// - Mystery: 7
  /// - Romance: 22
  /// - Sci-Fi: 24
  /// - Slice of Life: 36
  /// - Sports: 30
  /// - Supernatural: 37
  Future<List<JikanAnime>> getAnimesByGenre(
    int genreId, {
    int page = 1,
    int limit = 20,
  }) async {
    final cacheKey = 'genre_${genreId}_${page}_$limit';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/anime?genres=$genreId&page=$page&limit=$limit&order_by=score&sort=desc',
        ),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final jikanResponse = JikanResponse<JikanAnime>.fromJson(
          jsonData,
          (json) => JikanAnime.fromJson(json),
        );
        _saveToCache(cacheKey, jikanResponse.data);
        return jikanResponse.data;
      } else {
        throw Exception(
          'Failed to load animes by genre: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching animes by genre: $e');
      return [];
    }
  }

  /// Busca animes populares (ordenados por membros)
  Future<List<JikanAnime>> getPopularAnimes({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/anime?order_by=members&sort=desc&page=$page&limit=$limit',
        ),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final jikanResponse = JikanResponse<JikanAnime>.fromJson(
          jsonData,
          (json) => JikanAnime.fromJson(json),
        );
        return jikanResponse.data;
      } else {
        throw Exception(
          'Failed to load popular animes: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching popular animes: $e');
      return [];
    }
  }

  /// Busca recomendações de animes
  Future<List<JikanAnime>> getRecommendedAnimes({int page = 1}) async {
    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse('$baseUrl/recommendations/anime?page=$page'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List<dynamic> data = jsonData['data'] ?? [];

        final List<JikanAnime> animes = [];
        for (var item in data.take(20)) {
          if (item['entry'] != null && item['entry'].isNotEmpty) {
            for (var entry in item['entry']) {
              try {
                animes.add(JikanAnime.fromJson(entry));
              } catch (e) {
                debugPrint('Error parsing recommendation entry: $e');
              }
            }
          }
        }

        final uniqueAnimes = <int, JikanAnime>{};
        for (var anime in animes) {
          uniqueAnimes[anime.malId] = anime;
        }

        return uniqueAnimes.values.toList();
      } else {
        throw Exception(
          'Failed to load recommended animes: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching recommended animes: $e');
      return [];
    }
  }

  /// Busca anime por ID
  Future<JikanAnime?> getAnimeById(int malId) async {
    try {
      await _waitForRateLimit();
      final response = await http.get(Uri.parse('$baseUrl/anime/$malId'));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['data'] != null) {
          return JikanAnime.fromJson(jsonData['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching anime by id: $e');
      return null;
    }
  }

  /// Busca animes por termo de pesquisa com fallback para AniList e Kitsu
  Future<List<JikanAnime>> searchAnimes(
    String query, {
    int page = 1,
    int limit = 20,
    int? genreId,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return [];

    final cacheKey =
        'search_${_normalizeSearchText(normalizedQuery)}_${page}_${limit}_${genreId ?? 'all'}';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    try {
      await _waitForRateLimit();
      final queryParameters = <String, String>{
        'q': normalizedQuery,
        'page': '$page',
        'limit': '$limit',
        'order_by': 'members',
        'sort': 'desc',
        'sfw': 'true',
      };
      if (genreId != null) queryParameters['genres'] = '$genreId';

      final response = await _fetchWithRetry(
        Uri.parse(
          '$baseUrl/anime',
        ).replace(queryParameters: queryParameters).toString(),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final jikanResponse = JikanResponse<JikanAnime>.fromJson(
          jsonData,
          (json) => JikanAnime.fromJson(json),
        );
        final results = _sortBySearchRelevance(
          jikanResponse.data,
          normalizedQuery,
        );
        if (results.isNotEmpty) {
          _saveToCache(cacheKey, results);
          return results;
        }
      }
    } catch (e) {
      debugPrint('Error searching animes on Jikan: $e. Trying AniList/Kitsu fallbacks...');
    }

    // Fallback 1: AniList GraphQL API
    final aniListResults = await _searchAniListFallback(
      normalizedQuery,
      limit: limit,
      genre: _getGenreNameById(genreId),
    );
    if (aniListResults.isNotEmpty) {
      final sorted = _sortBySearchRelevance(aniListResults, normalizedQuery);
      _saveToCache(cacheKey, sorted);
      return sorted;
    }

    // Fallback 2: Kitsu REST API
    final kitsuResults = await _searchKitsuFallback(
      normalizedQuery,
      limit: limit,
    );
    if (kitsuResults.isNotEmpty) {
      final sorted = _sortBySearchRelevance(kitsuResults, normalizedQuery);
      _saveToCache(cacheKey, sorted);
      return sorted;
    }

    return [];
  }

  static String? _getGenreNameById(int? genreId) {
    if (genreId == null) return null;
    switch (genreId) {
      case 1:
        return 'Action';
      case 2:
        return 'Adventure';
      case 4:
        return 'Comedy';
      case 8:
        return 'Drama';
      case 10:
        return 'Fantasy';
      case 14:
        return 'Horror';
      case 7:
        return 'Mystery';
      case 22:
        return 'Romance';
      case 24:
        return 'Sci-Fi';
      case 36:
        return 'Slice of Life';
      case 30:
        return 'Sports';
      case 37:
        return 'Supernatural';
      default:
        return null;
    }
  }

  static Future<List<JikanAnime>> _searchAniListFallback(
    String query, {
    int limit = 20,
    String? genre,
  }) async {
    try {
      debugPrint('[JikanService] Falling back to AniList search for: $query');
      const gqlQuery = '''
        query (\$search: String, \$page: Int, \$perPage: Int, \$genre: String) {
          Page(page: \$page, perPage: \$perPage) {
            media(search: \$search, genre: \$genre, type: ANIME, sort: [POPULARITY_DESC]) {
              id
              idMal
              title { romaji english native }
              coverImage { extraLarge large medium }
              description
              episodes
              status
              averageScore
              genres
              seasonYear
              season
            }
          }
        }
      ''';

      final response = await http
          .post(
            Uri.parse('https://graphql.anilist.co'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'query': gqlQuery,
              'variables': {
                if (query.trim().isNotEmpty) 'search': query.trim(),
                if (genre != null && genre.isNotEmpty) 'genre': genre,
                'page': 1,
                'perPage': limit,
              },
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data']?['Page']?['media'] as List? ?? [];
        return list
            .map(
              (item) => _convertAniListToJikan(item as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('[JikanService] AniList fallback error: $e');
    }
    return [];
  }

  static Future<List<JikanAnime>> _searchKitsuFallback(
    String query, {
    int limit = 20,
  }) async {
    try {
      debugPrint('[JikanService] Falling back to Kitsu search for: $query');
      final uri = Uri.parse('https://kitsu.io/api/edge/anime').replace(
        queryParameters: {
          'filter[text]': query.trim(),
          'page[limit]': limit.toString(),
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] as List? ?? [];
        return list
            .map((item) => _convertKitsuToJikan(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[JikanService] Kitsu fallback error: $e');
    }
    return [];
  }

  static JikanAnime _convertAniListToJikan(Map<String, dynamic> item) {
    final titleObj = item['title'] as Map<String, dynamic>? ?? {};
    final romaji = titleObj['romaji'] as String?;
    final english = titleObj['english'] as String?;
    final native = titleObj['native'] as String?;
    final title = romaji ?? english ?? native ?? 'Unknown';

    final coverObj = item['coverImage'] as Map<String, dynamic>? ?? {};
    final extraLarge = coverObj['extraLarge'] as String?;
    final large = coverObj['large'] as String?;
    final medium = coverObj['medium'] as String?;

    final coverUrls = <String>[
      if (extraLarge != null && extraLarge.isNotEmpty) extraLarge,
      if (large != null && large.isNotEmpty) large,
      if (medium != null && medium.isNotEmpty) medium,
    ];

    final scoreRaw = item['averageScore'];
    final double? score =
        scoreRaw != null ? (scoreRaw as num).toDouble() / 10.0 : null;

    final genreList = (item['genres'] as List? ?? [])
        .map((g) => JikanGenre(malId: 0, name: g.toString(), type: 'anime'))
        .toList();

    return JikanAnime(
      malId: item['idMal'] is int
          ? item['idMal']
          : (item['id'] is int ? item['id'] : 0),
      title: title,
      titleEnglish: english,
      titleJapanese: native,
      imageUrl: medium ?? large ?? extraLarge ?? '',
      largImageUrl: extraLarge ?? large,
      coverImageUrls: coverUrls,
      synopsis: item['description'],
      score: score,
      episodes: item['episodes'] is int ? item['episodes'] : null,
      status: item['status']?.toString(),
      genres: genreList,
      year: item['seasonYear'] is int ? item['seasonYear'] : null,
      season: item['season']?.toString().toLowerCase(),
    );
  }

  static JikanAnime _convertKitsuToJikan(Map<String, dynamic> item) {
    final id = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
    final attr = item['attributes'] as Map<String, dynamic>? ?? {};
    final title =
        attr['canonicalTitle'] ?? attr['en'] ?? attr['ja_jp'] ?? 'Unknown';
    final poster = attr['posterImage'] as Map<String, dynamic>? ?? {};
    final large = poster['large'] as String?;
    final medium = poster['medium'] as String?;
    final original = poster['original'] as String?;

    final coverUrls = <String>[
      if (original != null && original.isNotEmpty) original,
      if (large != null && large.isNotEmpty) large,
      if (medium != null && medium.isNotEmpty) medium,
    ];

    final ratingRaw = attr['averageRating'];
    final double? score = ratingRaw != null
        ? (double.tryParse(ratingRaw.toString()) ?? 0.0) / 10.0
        : null;

    int? year;
    final startDate = attr['startDate'] as String?;
    if (startDate != null && startDate.length >= 4) {
      year = int.tryParse(startDate.substring(0, 4));
    }

    return JikanAnime(
      malId: id,
      title: title,
      titleEnglish: attr['en_jp'] ?? attr['en'],
      titleJapanese: attr['ja_jp'],
      imageUrl: medium ?? large ?? original ?? '',
      largImageUrl: large ?? original,
      coverImageUrls: coverUrls,
      synopsis: attr['synopsis'],
      score: score,
      episodes: attr['episodeCount'] is int ? attr['episodeCount'] : null,
      status: attr['status']?.toString(),
      genres: [],
      year: year,
    );
  }

  List<JikanAnime> _sortBySearchRelevance(
    List<JikanAnime> animes,
    String query,
  ) {
    final normalizedQuery = _normalizeSearchText(query);
    final queryWords = normalizedQuery
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toSet();

    int score(JikanAnime anime) {
      final titles = [anime.title, anime.titleEnglish, anime.titleJapanese]
          .whereType<String>()
          .map(_normalizeSearchText)
          .where((title) => title.isNotEmpty)
          .toList();
      var best = 0;
      for (final title in titles) {
        if (title == normalizedQuery) best = best < 10000 ? 10000 : best;
        if (title.startsWith(normalizedQuery)) {
          best = best < 7000 ? 7000 : best;
        }
        if (title.contains(normalizedQuery)) {
          best = best < 5000 ? 5000 : best;
        }
        final matchingWords = queryWords.where(title.contains).length;
        best = best < matchingWords * 500 ? matchingWords * 500 : best;
      }
      return best;
    }

    final indexed = animes.indexed.toList()
      ..sort((a, b) {
        final relevance = score(b.$2).compareTo(score(a.$2));
        return relevance != 0 ? relevance : a.$1.compareTo(b.$1);
      });
    return indexed.map((entry) => entry.$2).toList();
  }

  String _normalizeSearchText(String value) {
    const accents = 'áàâãäåéèêëíìîïóòôõöúùûüçñ';
    const plain = 'aaaaaaeeeeiiiiooooouuuucn';
    final buffer = StringBuffer();
    for (final rune in value.toLowerCase().runes) {
      final character = String.fromCharCode(rune);
      final accentIndex = accents.indexOf(character);
      buffer.write(accentIndex >= 0 ? plain[accentIndex] : character);
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}

// IDs de gêneros mais populares
class JikanGenreIds {
  static const int action = 1;
  static const int adventure = 2;
  static const int comedy = 4;
  static const int drama = 8;
  static const int fantasy = 10;
  static const int horror = 14;
  static const int mystery = 7;
  static const int romance = 22;
  static const int sciFi = 24;
  static const int sliceOfLife = 36;
  static const int sports = 30;
  static const int supernatural = 37;
}
