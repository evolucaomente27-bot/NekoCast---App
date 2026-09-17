import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/aniskip_models.dart';

/// Resolved IDs from anime title lookups
class ResolvedAnimeIds {
  final int? malId;
  final int? anilistId;

  const ResolvedAnimeIds({this.malId, this.anilistId});

  bool get hasId => malId != null || anilistId != null;

  @override
  String toString() => 'ResolvedAnimeIds(malId: $malId, anilistId: $anilistId)';
}

class AniSkipService {
  static const String baseUrl = 'https://api.aniskip.com/v2';

  static final Map<String, ResolvedAnimeIds> _resolvedIdsCache = {};

  /// Cleans anime title by stripping release tags, language markers and normalizing season terms
  static String cleanAnimeTitle(String title) {
    String cleaned = title;

    // Remove source tags like [AnimeFire], [Sugoi], [AllAnime], etc.
    cleaned = cleaned.replaceAll(RegExp(r'\[[^\]]*\]'), '');

    // Normalize Portuguese season terms to English or numbers for better database matching
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(\d+)[ªº]\s*Temporada', caseSensitive: false),
      (m) => 'Season ${m[1]}',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'Temporada\s*(\d+)', caseSensitive: false),
      (m) => 'Season ${m[1]}',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'Parte\s*(\d+)', caseSensitive: false),
      (m) => 'Part ${m[1]}',
    );

    // Remove language indicators
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s*\([^)]*(?:dublado|legendado|dub|sub|audio|áudio|pt-br|pt|br)[^)]*\)',
        caseSensitive: false,
      ),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:dublado|legendado|dub|sub|pt-br)\b', caseSensitive: false),
      '',
    );

    // Remove "Todos os Episodios" and similar phrases
    cleaned = cleaned.replaceAll(
      RegExp(r'todos\s+os\s+epis[oó]dios', caseSensitive: false),
      '',
    );

    // Remove episode ranges or counts like "(01-12)", "(12 eps)", "(Episódio 01)"
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s*\(\s*\d+\s*(?:episodes?|eps|epis[oó]dios?)?\s*\)',
        caseSensitive: false,
      ),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\s*\(\s*\d+\s*-\s*\d+\s*\)', caseSensitive: false),
      '',
    );

    // Remove trailing hyphens or colons
    cleaned = cleaned.replaceAll(RegExp(r'[-–—:]\s*$'), '');

    // Normalize whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  /// Resolves MAL and/or AniList IDs from an anime title
  /// Strategy 1: Kitsu API mappings (fast, reliable, no rate-limits)
  /// Strategy 2: Jikan API search fallback
  static Future<ResolvedAnimeIds> resolveIdsByTitle(String rawTitle) async {
    final title = cleanAnimeTitle(rawTitle);
    if (title.isEmpty) {
      return const ResolvedAnimeIds();
    }

    final cacheKey = title.toLowerCase();
    if (_resolvedIdsCache.containsKey(cacheKey)) {
      debugPrint('[AniSkip] ⚡ Cache hit for "$cacheKey": ${_resolvedIdsCache[cacheKey]}');
      return _resolvedIdsCache[cacheKey]!;
    }

    int? malId;
    int? anilistId;

    // Strategy 1: Kitsu mapping lookup
    try {
      final uri = Uri.parse(
        'https://kitsu.io/api/edge/anime?filter[text]=${Uri.encodeComponent(title)}&include=mappings&page[limit]=1',
      );
      debugPrint('[AniSkip] 🌐 Kitsu mapping lookup for "$title": $uri');
      final res = await http.get(
        uri,
        headers: {'Accept': 'application/vnd.api+json'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final included = data['included'] as List?;
        if (included != null) {
          for (final item in included) {
            final attrs = item['attributes'];
            if (attrs is Map) {
              final site = attrs['externalSite'] as String?;
              final extIdStr = attrs['externalId']?.toString();
              if (site == 'myanimelist/anime' && extIdStr != null) {
                malId ??= int.tryParse(extIdStr);
              } else if (site == 'anilist/anime' && extIdStr != null) {
                anilistId ??= int.tryParse(extIdStr);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AniSkip] ⚠️ Kitsu mapping lookup error: $e');
    }

    // Strategy 2: Jikan Search fallback if MAL ID is still missing
    if (malId == null) {
      try {
        final uri = Uri.parse(
          'https://api.jikan.moe/v4/anime?q=${Uri.encodeComponent(title)}&limit=1',
        );
        debugPrint('[AniSkip] 🌐 Jikan fallback lookup for "$title": $uri');
        final res = await http.get(
          uri,
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final list = data['data'] as List?;
          if (list != null && list.isNotEmpty) {
            final item = list[0];
            final jikanMalId = item['mal_id'];
            if (jikanMalId is int) {
              malId = jikanMalId;
            }
          }
        }
      } catch (e) {
        debugPrint('[AniSkip] ⚠️ Jikan fallback lookup error: $e');
      }
    }

    debugPrint('[AniSkip] 🎯 Resolved IDs for "$rawTitle" -> MAL: $malId, AniList: $anilistId');
    final result = ResolvedAnimeIds(malId: malId, anilistId: anilistId);
    _resolvedIdsCache[cacheKey] = result;
    return result;
  }

  /// Fetches skip times data trying multiple strategies
  /// 1. Try with MAL ID if available
  /// 2. Try with AniList ID if MAL ID fails
  /// 3. Try resolving IDs by animeTitle if both are missing or fail
  static Future<SkipTimes> getSkipTimesMultiStrategy({
    int? malId,
    int? anilistId,
    String? animeTitle,
    required int episodeNumber,
    int? episodeLengthSeconds,
  }) async {
    if (episodeLengthSeconds == null || episodeLengthSeconds <= 0) {
      debugPrint(
        '[AniSkip] ⚠️  Invalid episode length provided to service: '
        '$episodeLengthSeconds. Skipping API call.',
      );
      return SkipTimes.empty();
    }

    int? effectiveMalId = malId;
    int? effectiveAnilistId = anilistId;

    // If both IDs are missing, attempt resolution by animeTitle
    if (effectiveMalId == null && effectiveAnilistId == null && animeTitle != null && animeTitle.isNotEmpty) {
      debugPrint('[AniSkip] 🔍 Resolving anime IDs by title: "$animeTitle"');
      final resolved = await resolveIdsByTitle(animeTitle);
      effectiveMalId = resolved.malId;
      effectiveAnilistId = resolved.anilistId;
      debugPrint('[AniSkip] 📋 Resolved IDs: MAL=$effectiveMalId, AniList=$effectiveAnilistId');
    }

    // Strategy 1: Try MAL ID first
    if (effectiveMalId != null) {
      debugPrint('[AniSkip] 🎯 Strategy 1: Trying with MAL ID: $effectiveMalId');
      final result = await _fetchSkipTimes(
        animeId: effectiveMalId,
        episodeNumber: episodeNumber,
        idType: 'MAL',
        episodeLengthSeconds: episodeLengthSeconds,
      );
      if (result.hasSkipTimes) {
        return result;
      }
    }

    // Strategy 2: Try AniList ID
    if (effectiveAnilistId != null) {
      debugPrint('[AniSkip] 🎯 Strategy 2: Trying with AniList ID: $effectiveAnilistId');
      final result = await _fetchSkipTimes(
        animeId: effectiveAnilistId,
        episodeNumber: episodeNumber,
        idType: 'AniList',
        episodeLengthSeconds: episodeLengthSeconds,
      );
      if (result.hasSkipTimes) {
        return result;
      }
    }

    // Strategy 3: Fallback title resolution if provided IDs failed and title wasn't resolved yet
    if (animeTitle != null &&
        animeTitle.isNotEmpty &&
        effectiveMalId == malId &&
        effectiveAnilistId == anilistId) {
      debugPrint('[AniSkip] 🔄 Trying title resolution fallback for: "$animeTitle"');
      final resolved = await resolveIdsByTitle(animeTitle);
      if (resolved.malId != null && resolved.malId != effectiveMalId) {
        final result = await _fetchSkipTimes(
          animeId: resolved.malId!,
          episodeNumber: episodeNumber,
          idType: 'MAL (fallback)',
          episodeLengthSeconds: episodeLengthSeconds,
        );
        if (result.hasSkipTimes) return result;
      }
      if (resolved.anilistId != null && resolved.anilistId != effectiveAnilistId) {
        final result = await _fetchSkipTimes(
          animeId: resolved.anilistId!,
          episodeNumber: episodeNumber,
          idType: 'AniList (fallback)',
          episodeLengthSeconds: episodeLengthSeconds,
        );
        if (result.hasSkipTimes) return result;
      }
    }

    debugPrint('[AniSkip] ❌ No skip times found with any strategy');
    return SkipTimes.empty();
  }

  /// Fetches skip times data for a given anime ID and episode number
  static Future<SkipTimes> _fetchSkipTimes({
    required int animeId,
    required int episodeNumber,
    required String idType,
    required int episodeLengthSeconds,
  }) async {
    try {
      // Build URL - AniSkip API expects types as array parameters
      // Format: ?types[]=op&types[]=ed
      final uri = Uri.https(
        'api.aniskip.com',
        '/v2/skip-times/$animeId/$episodeNumber',
        {
          'types[]': ['op', 'ed'],
          'episodeLength': episodeLengthSeconds.toString(),
        },
      );

      debugPrint('[AniSkip API] 🌐 Request ($idType): $uri');

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('[AniSkip API] ⏱️  Request timeout after 10s');
              throw Exception('Request timeout');
            },
          );

      debugPrint('[AniSkip API] 📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('[AniSkip API] 📄 Response body: ${response.body}');
        final jsonData = json.decode(response.body);
        final skipResponse = SkipTimesResponse.fromJson(jsonData);

        if (skipResponse.found) {
          debugPrint(
            '[AniSkip API] ✅ Found ${skipResponse.results.length} skip time(s) using $idType ID',
          );
          return skipResponse.toSkipTimes();
        } else {
          debugPrint(
            '[AniSkip API] ℹ️  API returned found=false for $idType ID',
          );
        }
      } else if (response.statusCode == 404) {
        debugPrint(
          '[AniSkip API] 404 - No skip times found for $idType ID: $animeId',
        );
        return SkipTimes.empty();
      } else {
        debugPrint(
          '[AniSkip API] ❌ Request failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[AniSkip API] ❌ Exception with $idType ID: $e');
    }

    return SkipTimes.empty();
  }

  /// Legacy method for backward compatibility
  /// Use [getSkipTimesMultiStrategy] instead for better fallback support
  @Deprecated('Use getSkipTimesMultiStrategy for better fallback support')
  static Future<SkipTimes> getSkipTimes(
    int malId,
    int episodeNumber, {
    int? episodeLengthSeconds,
  }) async {
    return getSkipTimesMultiStrategy(
      malId: malId,
      episodeNumber: episodeNumber,
      episodeLengthSeconds: episodeLengthSeconds,
    );
  }

  /// Rounds a time value to the specified precision
  static double roundTime(double timeValue, int precision) {
    final multiplier = 1.0 * (10 ^ precision);
    return (timeValue * multiplier).round() / multiplier;
  }
}
