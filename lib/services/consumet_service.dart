import 'dart:convert';
import 'package:http/http.dart' as http;
import 'backend_config.dart';

/// Modelo de resultados de pesquisa do Consumet
class ConsumetShow {
  final String id;
  final String title;
  final String? image;
  final String? releaseDate;
  final int episodeCount;
  final bool hasSub;
  final bool hasDub;
  final String provider; // 'gogoanime', 'zoro', 'animepahe', etc.

  ConsumetShow({
    required this.id,
    required this.title,
    this.image,
    this.releaseDate,
    this.episodeCount = 0,
    this.hasSub = true,
    this.hasDub = false,
    this.provider = 'gogoanime',
  });

  factory ConsumetShow.fromJson(Map<String, dynamic> json, {String provider = 'anilist'}) {
    final showId = json['id']?.toString() ?? '';
    
    String showTitle = '';
    final titleRaw = json['title'];
    if (titleRaw is String) {
      showTitle = titleRaw;
    } else if (titleRaw is Map) {
      showTitle = titleRaw['english']?.toString() ??
          titleRaw['userPreferred']?.toString() ??
          titleRaw['romaji']?.toString() ??
          titleRaw['native']?.toString() ??
          '';
    } else if (titleRaw != null) {
      showTitle = titleRaw.toString();
    }

    final showImage = json['image']?.toString() ?? json['cover']?.toString();
    final epCount = json['totalEpisodes'] is int
        ? json['totalEpisodes'] as int
        : int.tryParse(json['totalEpisodes']?.toString() ?? '') ?? 0;
    final hasDub = json['hasDub'] == true || (showTitle.toLowerCase().contains('(dub)'));

    return ConsumetShow(
      id: showId,
      title: showTitle,
      image: showImage,
      releaseDate: json['releaseDate']?.toString() ?? json['year']?.toString(),
      episodeCount: epCount,
      hasSub: json['hasSub'] ?? true,
      hasDub: hasDub,
      provider: provider,
    );
  }
}

/// Modelo de episódio do Consumet
class ConsumetEpisode {
  final String id;
  final String number;
  final String? title;
  final String? image;

  ConsumetEpisode({
    required this.id,
    required this.number,
    this.title,
    this.image,
  });

  factory ConsumetEpisode.fromJson(Map<String, dynamic> json) {
    return ConsumetEpisode(
      id: json['id']?.toString() ?? json['episodeId']?.toString() ?? '',
      number: json['number']?.toString() ?? json['episodeNumber']?.toString() ?? '',
      title: json['title']?.toString() ?? json['name']?.toString(),
      image: json['image']?.toString() ?? json['thumbnail']?.toString(),
    );
  }
}

/// Modelo de fonte de vídeo do Consumet
class ConsumetVideoSource {
  final String url;
  final String quality;
  final bool isM3u8;

  ConsumetVideoSource({
    required this.url,
    required this.quality,
    this.isM3u8 = false,
  });

  factory ConsumetVideoSource.fromJson(Map<String, dynamic> json) {
    final videoUrl = json['url']?.toString() ?? json['file']?.toString() ?? '';
    final qual = json['quality']?.toString() ?? 'default';
    return ConsumetVideoSource(
      url: videoUrl,
      quality: qual,
      isM3u8: json['isM3u8'] == true || videoUrl.contains('.m3u8'),
    );
  }
}

class ConsumetService {
  static const List<String> _externalMirrors = [
    'https://consumet-api-clone.vercel.app',
    'https://consumet-api.vercel.app',
    'https://api.consumet.org',
  ];

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

  static Future<List<ConsumetShow>> searchAnime(String query, {String provider = 'anilist'}) async {
    final cleanQuery = Uri.encodeComponent(query.trim());
    if (cleanQuery.isEmpty) return [];

    final providersToTry = [provider, if (provider != 'anilist') 'anilist'];

    for (final prov in providersToTry) {
      // 1. Try BackendConfig
      try {
        final res = await BackendConfig.get('/anime/$prov/$cleanQuery');
        if (res != null && res.statusCode == 200) {
          final data = json.decode(res.body);
          final results = data['results'] as List? ?? [];
          final shows = results
              .map((item) => ConsumetShow.fromJson(item, provider: prov))
              .where((show) => show.id.isNotEmpty && show.title.isNotEmpty)
              .toList();
          if (shows.isNotEmpty) return shows;
        }
      } catch (_) {}

      // 2. Try external mirrors with quick timeout
      for (final baseUrl in _externalMirrors) {
        try {
          final url = Uri.parse('$baseUrl/anime/$prov/$cleanQuery');
          final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 3));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final results = data['results'] as List? ?? [];
            final shows = results
                .map((item) => ConsumetShow.fromJson(item, provider: prov))
                .where((show) => show.id.isNotEmpty && show.title.isNotEmpty)
                .toList();

            if (shows.isNotEmpty) return shows;
          }
        } catch (_) {}
      }
    }
    return [];
  }

  static Future<List<ConsumetEpisode>> getEpisodes(String animeId, {String provider = 'anilist'}) async {
    final cleanId = Uri.encodeComponent(animeId.trim());
    if (cleanId.isEmpty) return [];

    final providersToTry = [provider, if (provider != 'anilist') 'anilist', if (provider != 'gogoanime') 'gogoanime'];

    for (final prov in providersToTry) {
      try {
        final res = await BackendConfig.get('/anime/$prov/info/$cleanId');
        if (res != null && res.statusCode == 200) {
          final data = json.decode(res.body);
          final episodes = data['episodes'] as List? ?? [];
          final resultList = episodes
              .map((item) => ConsumetEpisode.fromJson(item))
              .where((ep) => ep.id.isNotEmpty)
              .toList();
          if (resultList.isNotEmpty) return resultList;
        }
      } catch (_) {}

      for (final baseUrl in _externalMirrors) {
        try {
          final url = Uri.parse('$baseUrl/anime/$prov/info/$cleanId');
          final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 4));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final episodes = data['episodes'] as List? ?? [];
            final resultList = episodes
                .map((item) => ConsumetEpisode.fromJson(item))
                .where((ep) => ep.id.isNotEmpty)
                .toList();
            if (resultList.isNotEmpty) return resultList;
          }
        } catch (_) {}
      }
    }
    return [];
  }

  static Future<List<ConsumetVideoSource>> getStreamSources(String episodeId, {String provider = 'anilist'}) async {
    final cleanEpId = Uri.encodeComponent(episodeId.trim());
    if (cleanEpId.isEmpty) return [];

    final providersToTry = [provider, if (provider != 'anilist') 'anilist', if (provider != 'gogoanime') 'gogoanime'];

    for (final prov in providersToTry) {
      try {
        final res = await BackendConfig.get('/anime/$prov/watch/$cleanEpId');
        if (res != null && res.statusCode == 200) {
          final data = json.decode(res.body);
          final sources = data['sources'] as List? ?? [];
          final resultList = sources
              .map((item) => ConsumetVideoSource.fromJson(item))
              .where((s) => s.url.isNotEmpty)
              .toList();
          if (resultList.isNotEmpty) return resultList;
        }
      } catch (_) {}

      for (final baseUrl in _externalMirrors) {
        try {
          final url = Uri.parse('$baseUrl/anime/$prov/watch/$cleanEpId');
          final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 4));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final sources = data['sources'] as List? ?? [];
            final resultList = sources
                .map((item) => ConsumetVideoSource.fromJson(item))
                .where((s) => s.url.isNotEmpty)
                .toList();
            if (resultList.isNotEmpty) return resultList;
          }
        } catch (_) {}
      }
    }
    return [];
  }
}
