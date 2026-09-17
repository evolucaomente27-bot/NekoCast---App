import 'dart:convert';
import 'package:http/http.dart' as http;
import 'backend_config.dart';

/// Model for HiAnime search results
class HiAnimeShow {
  final String id;
  final String title;
  final String? image;
  final String? releaseDate;
  final int episodeCount;

  HiAnimeShow({
    required this.id,
    required this.title,
    this.image,
    this.releaseDate,
    this.episodeCount = 0,
  });

  factory HiAnimeShow.fromJson(Map<String, dynamic> json) {
    final showId = json['id']?.toString() ??
        json['animeId']?.toString() ??
        json['url']?.toString() ??
        '';
    final showTitle = json['title']?.toString() ??
        json['name']?.toString() ??
        json['animeTitle']?.toString() ??
        '';
    final showImage = json['image']?.toString() ??
        json['poster']?.toString() ??
        json['animeImg']?.toString() ??
        json['cover']?.toString();

    int epCount = 0;
    if (json['sub'] is int) {
      epCount = json['sub'];
    } else if (json['totalEpisodes'] is int) {
      epCount = json['totalEpisodes'];
    } else if (json['episodes'] is int) {
      epCount = json['episodes'];
    }

    return HiAnimeShow(
      id: showId,
      title: showTitle,
      image: showImage,
      releaseDate: json['releaseDate']?.toString() ?? json['year']?.toString(),
      episodeCount: epCount,
    );
  }
}

/// Model for HiAnime episode item
class HiAnimeEpisode {
  final String id;
  final String episodeNumber;
  final String? title;

  HiAnimeEpisode({
    required this.id,
    required this.episodeNumber,
    this.title,
  });

  factory HiAnimeEpisode.fromJson(Map<String, dynamic> json) {
    return HiAnimeEpisode(
      id: json['id']?.toString() ?? json['episodeId']?.toString() ?? '',
      episodeNumber: json['number']?.toString() ??
          json['episodeNumber']?.toString() ??
          json['episode']?.toString() ??
          '',
      title: json['title']?.toString() ?? json['name']?.toString(),
    );
  }
}

/// Service to handle HiAnime / Gogoanime API calls
/// Uses backend with failover
class HiAnimeService {
  static const List<String> _externalMirrors = [
    'https://consumet-api-clone.vercel.app/anime/gogoanime',
    'https://consumet-api.vercel.app/anime/gogoanime',
    'https://api.consumet.org/anime/gogoanime',
  ];

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

  /// Normalize a title for better API matching
  static String _normalizeTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'\(.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?\]', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'(dublado|legendado|todos os episodios|season|temporada)',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'[áàãâä]', caseSensitive: false), 'a')
        .replaceAll(RegExp(r'[éèêë]', caseSensitive: false), 'e')
        .replaceAll(RegExp(r'[íìîï]', caseSensitive: false), 'i')
        .replaceAll(RegExp(r'[óòõôö]', caseSensitive: false), 'o')
        .replaceAll(RegExp(r'[úùûü]', caseSensitive: false), 'u')
        .replaceAll(RegExp(r'[ç]', caseSensitive: false), 'c')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Generate search query candidates from a raw title
  static List<String> _buildQueries(String rawTitle) {
    final normalized = _normalizeTitle(rawTitle);
    final words = normalized.split(' ').where((w) => w.isNotEmpty).toList();
    final queries = <String>{};

    if (normalized.isNotEmpty) queries.add(normalized);
    if (words.length >= 2) queries.add(words.take(3).join(' '));

    return queries.toList();
  }

  /// Searches for animes
  static Future<List<HiAnimeShow>> searchAnime(String query) async {
    final candidates = _buildQueries(query);

    for (final candidate in candidates) {
      final encodedQuery = Uri.encodeComponent(candidate);

      // 1. Try Backend
      try {
        final res = await BackendConfig.get('/anime/gogoanime/$encodedQuery');
        if (res != null && res.statusCode == 200) {
          final data = json.decode(res.body);
          final results = _extractResults(data);
          if (results.isNotEmpty) return results;
        }
      } catch (_) {}

      // 2. Try external mirrors with quick timeout
      for (final base in _externalMirrors) {
        try {
          final url = Uri.parse('$base/$encodedQuery');
          final response = await http
              .get(url, headers: _headers)
              .timeout(const Duration(seconds: 3));

          if (response.statusCode == 200) {
            final body = response.body.trim();
            if (body.isEmpty || body.startsWith('<')) continue;

            final data = json.decode(body);
            final results = _extractResults(data);
            if (results.isNotEmpty) return results;
          }
        } catch (_) {}
      }
    }

    return [];
  }

  static List<HiAnimeShow> _extractResults(dynamic data) {
    List? raw;
    if (data is List) {
      raw = data;
    } else if (data is Map) {
      raw = data['results'] as List? ??
          data['animes'] as List? ??
          data['data'] as List? ??
          (data['data'] is Map ? data['data']['animes'] as List? : null) ??
          (data['data'] is Map ? data['data']['results'] as List? : null);
    }
    if (raw == null) return [];

    return raw
        .whereType<Map<String, dynamic>>()
        .map((e) => HiAnimeShow.fromJson(e))
        .where((s) => s.id.isNotEmpty && s.title.isNotEmpty)
        .toList();
  }

  /// Gets episode list for a show
  static Future<List<HiAnimeEpisode>> getEpisodesList(String animeId) async {
    final encodedId = Uri.encodeComponent(animeId.trim());

    // 1. Try Backend
    try {
      final res = await BackendConfig.get('/anime/gogoanime/info/$encodedId');
      if (res != null && res.statusCode == 200) {
        final data = json.decode(res.body);
        final episodesList = data['episodes'] as List? ??
            (data['data'] is Map ? data['data']['episodes'] as List? : null);
        if (episodesList != null && episodesList.isNotEmpty) {
          return episodesList
              .whereType<Map<String, dynamic>>()
              .map((e) => HiAnimeEpisode.fromJson(e))
              .where((ep) => ep.id.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {}

    // 2. Try external mirrors
    for (final base in _externalMirrors) {
      try {
        final url = Uri.parse('$base/info/$encodedId');
        final response = await http
            .get(url, headers: _headers)
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final body = response.body.trim();
          if (body.isEmpty || body.startsWith('<')) continue;

          final data = json.decode(body);
          final episodesList = data['episodes'] as List? ??
              (data['data'] is Map ? data['data']['episodes'] as List? : null);

          if (episodesList != null && episodesList.isNotEmpty) {
            return episodesList
                .whereType<Map<String, dynamic>>()
                .map((e) => HiAnimeEpisode.fromJson(e))
                .where((ep) => ep.id.isNotEmpty)
                .toList();
          }
        }
      } catch (_) {}
    }

    return [];
  }

  /// Gets direct stream URL for an episode ID
  static Future<String?> getEpisodeStreamUrl(String episodeId) async {
    final encodedId = Uri.encodeComponent(episodeId.trim());

    // 1. Try Backend
    try {
      final res = await BackendConfig.get('/anime/gogoanime/watch/$encodedId');
      if (res != null && res.statusCode == 200) {
        final data = json.decode(res.body);
        final sources = data['sources'] as List? ??
            (data['data'] is Map ? data['data']['sources'] as List? : null);
        if (sources != null) {
          String? best;
          for (final src in sources) {
            if (src is Map && src['url'] != null) {
              final u = src['url'].toString();
              if (u.contains('.m3u8')) return u;
              best ??= u;
            }
          }
          if (best != null) return best;
        }
      }
    } catch (_) {}

    // 2. Try external mirrors
    for (final base in _externalMirrors) {
      try {
        final url = Uri.parse('$base/watch/$encodedId');
        final response = await http
            .get(url, headers: _headers)
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final body = response.body.trim();
          if (body.isEmpty || body.startsWith('<')) continue;

          final data = json.decode(body);
          final sources = data['sources'] as List? ??
              (data['data'] is Map ? data['data']['sources'] as List? : null);
          if (sources != null) {
            String? best;
            for (final src in sources) {
              if (src is Map && src['url'] != null) {
                final u = src['url'].toString();
                if (u.contains('.m3u8')) return u;
                best ??= u;
              }
            }
            if (best != null) return best;
          }
        }
      } catch (_) {}
    }

    return null;
  }
}
