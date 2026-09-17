import 'dart:convert';
import 'package:http/http.dart' as http;

/// Modelo de resultados de pesquisa do Anify
class AnifyShow {
  final String id;
  final String title;
  final String? coverImage;
  final String? bannerImage;
  final int episodeCount;
  final String format;

  AnifyShow({
    required this.id,
    required this.title,
    this.coverImage,
    this.bannerImage,
    this.episodeCount = 0,
    this.format = 'TV',
  });

  factory AnifyShow.fromJson(Map<String, dynamic> json) {
    final titleMap = json['title'];
    String displayTitle = '';
    if (titleMap is Map) {
      displayTitle = titleMap['english'] ?? titleMap['userPreferred'] ?? titleMap['romaji'] ?? '';
    } else if (titleMap is String) {
      displayTitle = titleMap;
    }

    int epTotal = 0;
    if (json['totalEpisodes'] is int) {
      epTotal = json['totalEpisodes'];
    } else if (json['episodes'] is Map && json['episodes']['latest'] != null) {
      epTotal = int.tryParse(json['episodes']['latest']?['updated']?.toString() ?? '') ?? 0;
    }

    return AnifyShow(
      id: json['id']?.toString() ?? '',
      title: displayTitle.isNotEmpty ? displayTitle : (json['name']?.toString() ?? ''),
      coverImage: json['coverImage']?.toString() ?? json['artwork']?.toString(),
      bannerImage: json['bannerImage']?.toString(),
      episodeCount: epTotal,
      format: json['format']?.toString() ?? 'TV',
    );
  }
}

/// Modelo de episódio do Anify
class AnifyEpisode {
  final String id;
  final String number;
  final String? title;
  final String? image;

  AnifyEpisode({
    required this.id,
    required this.number,
    this.title,
    this.image,
  });

  factory AnifyEpisode.fromJson(Map<String, dynamic> json) {
    return AnifyEpisode(
      id: json['id']?.toString() ?? json['episodeId']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      title: json['title']?.toString(),
      image: json['img']?.toString() ?? json['image']?.toString(),
    );
  }
}

/// Modelo de fonte de vídeo do Anify
class AnifyStreamSource {
  final String url;
  final String quality;
  final bool isM3u8;

  AnifyStreamSource({
    required this.url,
    required this.quality,
    this.isM3u8 = false,
  });

  factory AnifyStreamSource.fromJson(Map<String, dynamic> json) {
    final link = json['url']?.toString() ?? json['file']?.toString() ?? '';
    final q = json['quality']?.toString() ?? 'default';
    return AnifyStreamSource(
      url: link,
      quality: q,
      isM3u8: json['isM3u8'] == true || link.contains('.m3u8'),
    );
  }
}

class AnifyService {
  static const List<String> _baseUrls = [
    'https://anify-api.vercel.app',
    'https://api.anify.tv',
  ];

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

  static Future<List<AnifyShow>> searchAnime(String query) async {
    final cleanQuery = Uri.encodeComponent(query.trim());
    if (cleanQuery.isEmpty) return [];

    for (final baseUrl in _baseUrls) {
      try {
        final url = Uri.parse('$baseUrl/search/anime/$cleanQuery');
        final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200 && response.body.trim().startsWith('[')) {
          final List list = json.decode(response.body);
          return list
              .map((item) => AnifyShow.fromJson(item))
              .where((show) => show.id.isNotEmpty && show.title.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    return [];
  }

  static Future<List<AnifyEpisode>> getEpisodes(String animeId) async {
    final cleanId = Uri.encodeComponent(animeId.trim());
    if (cleanId.isEmpty) return [];

    for (final baseUrl in _baseUrls) {
      try {
        final url = Uri.parse('$baseUrl/info/$cleanId');
        final response = await http.get(url).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200 && response.body.trim().startsWith('{')) {
          final data = json.decode(response.body);
          final episodesData = data['episodes'] as List? ?? [];
          final List<AnifyEpisode> epList = [];

          for (final item in episodesData) {
            final eps = item['episodes'] as List? ?? [];
            for (final ep in eps) {
              epList.add(AnifyEpisode.fromJson(ep));
            }
          }
          return epList;
        }
      } catch (_) {}
    }
    return [];
  }

  static Future<List<AnifyStreamSource>> getStreamSources(String episodeId, {String providerId = 'gogoanime', int episodeNumber = 1}) async {
    for (final baseUrl in _baseUrls) {
      try {
        final url = Uri.parse('$baseUrl/sources?providerId=$providerId&watchId=${Uri.encodeComponent(episodeId)}&episodeNumber=$episodeNumber&id=$episodeId&subType=sub');
        final response = await http.get(url).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200 && response.body.trim().startsWith('{')) {
          final data = json.decode(response.body);
          final sources = data['sources'] as List? ?? [];
          return sources
              .map((item) => AnifyStreamSource.fromJson(item))
              .where((src) => src.url.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    return [];
  }
}
