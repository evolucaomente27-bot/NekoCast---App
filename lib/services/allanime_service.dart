import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// AllAnime API Service - Integração com AllAnime.day
class AllAnimeService {
  static const String _allAnimeReferer = 'https://allanime.to';
  static const String _allAnimeBase = 'allanime.day';
  static const List<String> _allAnimeAPIs = [
    'https://api.allanime.day/api',
  ];
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0';

  /// Busca animes no AllAnime (Sub e Dub)
  static Future<AllAnimeSearchResponse?> searchAnime(String query) async {
    final results = await Future.wait([
      _searchAnimeWithTranslation(query, 'sub'),
      _searchAnimeWithTranslation(query, 'dub'),
    ]);

    final subResponse = results[0];
    final dubResponse = results[1];

    final Map<String, AllAnimeShow> merged = {};
    if (subResponse != null) {
      for (final show in subResponse.shows) {
        merged[show.id] = show;
      }
    }
    if (dubResponse != null) {
      for (final show in dubResponse.shows) {
        if (!merged.containsKey(show.id)) {
          merged[show.id] = show;
        } else {
          final existing = merged[show.id]!;
          final combinedEpMap = Map<String, dynamic>.from(existing.availableEpisodes ?? {});
          if (show.availableEpisodes != null) {
            combinedEpMap.addAll(show.availableEpisodes!);
          }
          merged[show.id] = AllAnimeShow(
            id: existing.id,
            name: existing.name,
            englishName: existing.englishName,
            availableEpisodes: combinedEpMap,
            thumbnail: existing.thumbnail ?? show.thumbnail,
          );
        }
      }
    }

    if (merged.isEmpty) return null;
    return AllAnimeSearchResponse(shows: merged.values.toList());
  }

  static Future<AllAnimeSearchResponse?> _searchAnimeWithTranslation(
    String query,
    String translationType,
  ) async {
    try {
      debugPrint('[AllAnime] Searching for: $query ($translationType)');

      // GraphQL query com thumbnail
      const searchGql = '''
        query(\$search: SearchInput, \$limit: Int, \$page: Int, \$translationType: VaildTranslationTypeEnumType, \$countryOrigin: VaildCountryOriginEnumType) {
          shows(search: \$search, limit: \$limit, page: \$page, translationType: \$translationType, countryOrigin: \$countryOrigin) {
            edges {
              _id
              name
              englishName
              availableEpisodes
              thumbnail
              __typename
            }
          }
        }
      ''';

      // Variáveis da query
      final variables = {
        'search': {'allowAdult': false, 'allowUnknown': false, 'query': query},
        'limit': 40,
        'page': 1,
        'translationType': translationType,
        'countryOrigin': 'ALL',
      };

      final variablesJson = jsonEncode(variables);

      for (final apiBase in _allAnimeAPIs) {
        try {
          final url = Uri.parse(
            '$apiBase?variables=${Uri.encodeComponent(variablesJson)}&query=${Uri.encodeComponent(searchGql)}',
          );

          final response = await http
              .get(
                url,
                headers: {'User-Agent': _userAgent, 'Referer': _allAnimeReferer},
              )
              .timeout(const Duration(seconds: 8));

          if (response.statusCode == 200 && response.body.trim().startsWith('{')) {
            final data = jsonDecode(response.body);
            final showsData = data['data']?['shows']?['edges'] as List?;
            if (showsData != null) {
              final shows = showsData
                  .map((e) => AllAnimeShow.fromJson(e as Map<String, dynamic>))
                  .toList();
              return AllAnimeSearchResponse(shows: shows);
            }
          }
        } catch (e) {
          debugPrint('[AllAnime] Search error on $apiBase: $e');
        }
      }
    } catch (e) {
      debugPrint('[AllAnime] Search error: $e');
    }
    return null;
  }

  /// Busca lista detalhada de episódios com thumbnails
  static Future<List<AllAnimeEpisode>> getEpisodesListDetailed(
    String animeId, {
    String mode = 'sub',
    String? showThumbnail,
  }) async {
    final primary = await _getEpisodesListDetailedForMode(
      animeId,
      mode: mode,
      showThumbnail: showThumbnail,
    );
    if (primary.isNotEmpty) {
      return primary;
    }

    final fallbackMode = mode == 'sub' ? 'dub' : 'sub';
    if (fallbackMode != mode) {
      return _getEpisodesListDetailedForMode(
        animeId,
        mode: fallbackMode,
        showThumbnail: showThumbnail,
      );
    }

    return primary;
  }

  static Future<List<AllAnimeEpisode>> _getEpisodesListDetailedForMode(
    String animeId, {
    String mode = 'sub',
    String? showThumbnail,
  }) async {
    try {
      debugPrint('[AllAnime] Getting detailed episodes for anime: $animeId');

      const episodesDetailGql = '''
        query (\$showId: String!) {
          show(_id: \$showId) {
            _id
            thumbnail
            episodeInfos
            availableEpisodesDetail
          }
        }
      ''';

      final variables = jsonEncode({'showId': animeId});
      
      for (final apiBase in _allAnimeAPIs) {
        try {
          final url = Uri.parse(
            '$apiBase?variables=${Uri.encodeComponent(variables)}&query=${Uri.encodeComponent(episodesDetailGql)}',
          );

          final response = await http
              .get(
                url,
                headers: {'User-Agent': _userAgent, 'Referer': _allAnimeReferer},
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200 && response.body.trim().startsWith('{')) {
            final data = jsonDecode(response.body);
            final show = data['data']?['show'];

            if (show != null) {
              final episodeInfos = show['episodeInfos'] as List? ?? [];
              final availableDetail = show['availableEpisodesDetail'];

              if (availableDetail != null && availableDetail[mode] != null) {
                final episodes = availableDetail[mode] as List;
                final result = <AllAnimeEpisode>[];

                for (var ep in episodes) {
                  final epString = ep.toString();
                  // Encontrar detalhes correspondentes no episodeInfos
                  Map<String, dynamic>? epInfo;
                  try {
                    epInfo = episodeInfos.firstWhere(
                      (info) => info['episodeIdNum']?.toString() == epString,
                    );
                  } catch (_) {}

                  result.add(
                    AllAnimeEpisode(
                      episodeNumber: epString,
                      thumbnail: epInfo?['thumbnails']?.first ?? showThumbnail,
                      title: epInfo?['notes'] ?? 'Episódio $epString',
                      description: epInfo?['description'],
                    ),
                  );
                }
                
                result.sort((a, b) {
                  final numA = double.tryParse(a.episodeNumber) ?? 0;
                  final numB = double.tryParse(b.episodeNumber) ?? 0;
                  return numB.compareTo(numA);
                });

                return result;
              }
            }
          }
        } catch (_) {}
      }


      debugPrint(
        '[AllAnime] Falling back to simple episode list with show thumbnail',
      );
      final simpleList = await getEpisodesList(animeId, mode: mode);
      return simpleList
          .map(
            (episodeNum) => AllAnimeEpisode(
              episodeNumber: episodeNum,
              thumbnail: showThumbnail,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('[AllAnime] Get detailed episodes error: $e');
      return [];
    }
  }

  /// Busca lista de episódios de um anime (versão simples)
  static Future<List<String>> getEpisodesList(
    String animeId, {
    String mode = 'sub',
  }) async {
    final primary = await _getEpisodesListForMode(animeId, mode: mode);
    if (primary.isNotEmpty) {
      return primary;
    }

    final fallbackMode = mode == 'sub' ? 'dub' : 'sub';
    if (fallbackMode != mode) {
      return _getEpisodesListForMode(animeId, mode: fallbackMode);
    }

    return primary;
  }

  static Future<List<String>> _getEpisodesListForMode(
    String animeId, {
    String mode = 'sub',
  }) async {
    try {
      debugPrint('[AllAnime] Getting episodes for anime: $animeId');

      const episodesListGql = '''
        query (\$showId: String!) {
          show(_id: \$showId) {
            _id
            availableEpisodesDetail
          }
        }
      ''';

      final variables = jsonEncode({'showId': animeId});
      
      for (final apiBase in _allAnimeAPIs) {
        try {
          final url = Uri.parse(
            '$apiBase?variables=${Uri.encodeComponent(variables)}&query=${Uri.encodeComponent(episodesListGql)}',
          );

          final response = await http
              .get(
                url,
                headers: {'User-Agent': _userAgent, 'Referer': _allAnimeReferer},
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200 && response.body.trim().startsWith('{')) {
            final data = jsonDecode(response.body);
            final availableEpisodesDetail = data['data']?['show']?['availableEpisodesDetail'];

            if (availableEpisodesDetail != null && availableEpisodesDetail[mode] != null) {
              final episodes = List<String>.from(availableEpisodesDetail[mode]);
              
              episodes.sort((a, b) {
                final numA = double.tryParse(a) ?? 0;
                final numB = double.tryParse(b) ?? 0;
                return numB.compareTo(numA);
              });
              
              debugPrint('[AllAnime] Found ${episodes.length} episodes');
              return episodes;
            }
          }
        } catch (_) {}
      }

      debugPrint('[AllAnime] No episodes found');
      return [];
    } catch (e) {
      debugPrint('[AllAnime] Get episodes error: $e');
      return [];
    }
  }

  /// Decodifica URL encoded do AllAnime (baseado no Curd)
  static String _decodeSourceURL(String encoded) {
    // Mapeamento de decodificação exato do Curd
    const replacements = {
      '01': '9',
      '08': '0',
      '05': '=',
      '0a': '2',
      '0b': '3',
      '0c': '4',
      '07': '?',
      '00': '8',
      '5c': 'd',
      '0f': '7',
      '5e': 'f',
      '17': '/',
      '54': 'l',
      '09': '1',
      '48': 'p',
      '4f': 'w',
      '0e': '6',
      '5b': 'c',
      '5d': 'e',
      '0d': '5',
      '53': 'k',
      '1e': '&',
      '5a': 'b',
      '59': 'a',
      '4a': 'r',
      '4c': 't',
      '4e': 'v',
      '57': 'o',
      '51': 'i',
    };

    final parts = encoded.split(':');
    final mainPart = parts[0];
    final port = parts.length > 1 ? ':${parts[1]}' : '';

    final regex = RegExp(r'..');
    final pairs = regex.allMatches(mainPart).map((m) => m.group(0)!).toList();

    for (int i = 0; i < pairs.length; i++) {
      if (replacements.containsKey(pairs[i])) {
        pairs[i] = replacements[pairs[i]]!;
      }
    }

    var result = pairs.join('') + port;
    result = result.replaceAll('/clock', '/clock.json');

    if (result.startsWith('/')) {
      result = 'https://$_allAnimeBase$result';
    }

    return result;
  }

  /// Extrai URLs de fonte da resposta da API
  static List<String> _extractSourceURLs(Map<String, dynamic> data) {
    final urls = <String>[];
    final sourceUrls = data['data']?['episode']?['sourceUrls'] as List?;

    if (sourceUrls != null) {
      for (final source in sourceUrls) {
        final sourceUrl = source['sourceUrl'] as String?;
        if (sourceUrl != null) {
          if (sourceUrl.startsWith('--')) {
            final encoded = sourceUrl.substring(2);
            final decoded = _decodeSourceURL(encoded);
            urls.add(decoded);
          } else {
            urls.add(sourceUrl);
          }
        }
      }
    }

    return urls;
  }

  /// Busca URL do episódio
  static Future<String?> getEpisodeURL(
    String animeId,
    String episodeNo, {
    String mode = 'sub',
  }) async {
    final primary = await _getEpisodeUrlForMode(animeId, episodeNo, mode: mode);
    if (primary != null && primary.isNotEmpty) {
      return primary;
    }

    final fallbackMode = mode == 'sub' ? 'dub' : 'sub';
    if (fallbackMode != mode) {
      return _getEpisodeUrlForMode(animeId, episodeNo, mode: fallbackMode);
    }

    return primary;
  }

  static Future<String?> _getEpisodeUrlForMode(
    String animeId,
    String episodeNo, {
    String mode = 'sub',
  }) async {
    try {
      debugPrint(
        '[AllAnime] Getting episode URL: $animeId - Episode $episodeNo',
      );

      const episodeEmbedGQL = '''
        query (\$showId: String!, \$translationType: VaildTranslationTypeEnumType!, \$episodeString: String!) {
          episode(showId: \$showId, translationType: \$translationType, episodeString: \$episodeString) {
            episodeString
            sourceUrls
          }
        }
      ''';

      final variables = jsonEncode({
        'showId': animeId,
        'translationType': mode,
        'episodeString': episodeNo,
      });

      for (final apiBase in _allAnimeAPIs) {
        try {
          final url = Uri.parse(
            '$apiBase?variables=${Uri.encodeComponent(variables)}&query=${Uri.encodeComponent(episodeEmbedGQL)}',
          );

          final response = await http
              .get(
                url,
                headers: {'User-Agent': _userAgent, 'Referer': _allAnimeReferer},
              )
              .timeout(const Duration(seconds: 15));

          if (response.statusCode == 200 && response.body.trim().startsWith('{')) {
            final data = jsonDecode(response.body);
            final sourceURLs = _extractSourceURLs(data);

            if (sourceURLs.isNotEmpty) {
              // Tentar obter o link de vídeo da primeira fonte
              for (final sourceURL in sourceURLs) {
                final videoURL = await _getVideoLink(sourceURL);
                if (videoURL != null && videoURL.isNotEmpty) {
                  debugPrint('[AllAnime] Found video URL: $videoURL');
                  return videoURL;
                }
              }
              // Fallback: se nenhuma fonte retornou vídeo direto, usar a primeira URL HTTP válida
              for (final sourceURL in sourceURLs) {
                if (sourceURL.startsWith('http')) {
                  debugPrint('[AllAnime] Fallback to raw source URL: $sourceURL');
                  return sourceURL;
                }
              }
            }
          }
        } catch (_) {}
      }

      debugPrint('[AllAnime] No video URL found');
      return null;
    } catch (e) {
      debugPrint('[AllAnime] Get episode URL error: $e');
      return null;
    }
  }

  /// Extrai link de vídeo da URL de fonte
  static Future<String?> _getVideoLink(String sourceURL) async {
    try {
      if (sourceURL.contains('.mp4') ||
          sourceURL.contains('.m3u8') ||
          sourceURL.contains('googlevideo.com') ||
          sourceURL.contains('videoplayback')) {
        return sourceURL;
      }

      final mirrors = <String>{
        sourceURL,
        sourceURL.replaceAll('allanime.day', 'allanime.to'),
        sourceURL.replaceAll('allanime.day', 'allani.me'),
        sourceURL.replaceAll('allanime.day', 'allanime.co'),
      };

      for (final urlCandidate in mirrors) {
        try {
          final response = await http
              .get(
                Uri.parse(urlCandidate),
                headers: {'User-Agent': _userAgent, 'Referer': _allAnimeReferer},
              )
              .timeout(const Duration(seconds: 8));

          if (response.statusCode == 200) {
            // Tentar parse como JSON primeiro
            try {
              final data = jsonDecode(response.body);
              if (data is Map && data['links'] != null) {
                final links = data['links'] as List;
                final candidates = <String>[];

                void addCandidate(String? value) {
                  if (value == null || value.isEmpty) return;
                  final cleaned = value.replaceAll(r'\', '').trim();
                  if (cleaned.isEmpty) return;
                  if (!candidates.contains(cleaned)) {
                    candidates.add(
                      cleaned.startsWith('//') ? 'https:$cleaned' : cleaned,
                    );
                  }
                }

                for (final link in links) {
                  if (link is! Map) continue;
                  addCandidate(link['link'] as String?);
                  addCandidate(link['file'] as String?);
                  addCandidate(link['src'] as String?);
                  addCandidate(link['hls'] as String?);
                }

                candidates.sort(
                  (a, b) =>
                      _scoreVideoCandidate(b).compareTo(_scoreVideoCandidate(a)),
                );
                if (candidates.isNotEmpty) {
                  return candidates.first;
                }
              }
            } catch (_) {
              // Conteúdo não é JSON; tentar extrair links por expressão regular do corpo HTML
            }

            // Fallback: extrair URL direta .mp4 ou .m3u8 por regex do corpo
            final mp4Regex = RegExp(
              r'''https?://[^\s<>"']+?\.(?:mp4|m3u8)(?:\?[^\s<>"']*)?''',
              caseSensitive: false,
            );
            final match = mp4Regex.firstMatch(response.body);
            if (match != null) {
              return match.group(0);
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[AllAnime] Get video link error: $e');
    }

    if (sourceURL.startsWith('http')) {
      return sourceURL;
    }
    return null;
  }

  static int _scoreVideoCandidate(String url) {
    if (url.contains('.mp4')) return 400;
    if (url.contains('googlevideo.com') || url.contains('videoplayback')) {
      return 350;
    }
    if (url.contains('.m3u8')) return 300;
    if (url.startsWith('http')) return 200;
    return 0;
  }
}

/// Resposta da busca do AllAnime
class AllAnimeSearchResponse {
  final List<AllAnimeShow> shows;

  AllAnimeSearchResponse({required this.shows});

  factory AllAnimeSearchResponse.fromJson(Map<String, dynamic> json) {
    final edges = json['data']?['shows']?['edges'] as List? ?? [];
    final shows = edges.map((edge) => AllAnimeShow.fromJson(edge)).toList();
    return AllAnimeSearchResponse(shows: shows);
  }
}

/// Informações de um anime do AllAnime
class AllAnimeShow {
  final String id;
  final String name;
  final String? englishName;
  final Map<String, dynamic>? availableEpisodes;
  final String? thumbnail;

  AllAnimeShow({
    required this.id,
    required this.name,
    this.englishName,
    this.availableEpisodes,
    this.thumbnail,
  });

  factory AllAnimeShow.fromJson(Map<String, dynamic> json) {
    return AllAnimeShow(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      englishName: json['englishName'],
      availableEpisodes: json['availableEpisodes'] as Map<String, dynamic>?,
      thumbnail: json['thumbnail'],
    );
  }

  String get displayName =>
      englishName?.isNotEmpty == true ? englishName! : name;

  int get subEpisodeCount {
    if (availableEpisodes != null) {
      final sub = availableEpisodes!['sub'];
      if (sub is num) return sub.toInt();
    }
    return 0;
  }

  int get dubEpisodeCount {
    if (availableEpisodes != null) {
      final dub = availableEpisodes!['dub'];
      if (dub is num) return dub.toInt();
    }
    return 0;
  }

  int get rawEpisodeCount {
    if (availableEpisodes != null) {
      final raw = availableEpisodes!['raw'];
      if (raw is num) return raw.toInt();
    }
    return 0;
  }

  int get episodeCount =>
      subEpisodeCount > 0 ? subEpisodeCount : (dubEpisodeCount > 0 ? dubEpisodeCount : rawEpisodeCount);
}

/// Episode information from AllAnime
class AllAnimeEpisode {
  final String episodeNumber;
  final String? thumbnail;
  final String? title;
  final String? description;

  AllAnimeEpisode({
    required this.episodeNumber,
    this.thumbnail,
    this.title,
    this.description,
  });

  /// Get episode thumbnail URL
  String? getImageUrl() {
    if (thumbnail == null || thumbnail!.isEmpty) return null;
    // Ensure thumbnail is a full URL
    if (thumbnail!.startsWith('http')) return thumbnail;
    return 'https://wp.youtube-anime.com/aln.youtube-anime.com/$thumbnail';
  }

  factory AllAnimeEpisode.fromJson(Map<String, dynamic> json) {
    return AllAnimeEpisode(
      episodeNumber: json['episodeNumber']?.toString() ?? '',
      thumbnail: json['thumbnail'] ?? json['thumbnails']?.first,
      title: json['title'] ?? json['notes'],
      description: json['description'],
    );
  }
}
