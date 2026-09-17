import 'dart:convert';
import 'package:http/http.dart' as http;

/// Modelo de animes no SugoiAPI / PT-BR
class SugoiShow {
  final String id;
  final String title;
  final String? image;
  final bool isDubbed;
  final int episodeCount;
  final String? url;

  SugoiShow({
    required this.id,
    required this.title,
    this.image,
    this.isDubbed = false,
    this.episodeCount = 0,
    this.url,
  });

  factory SugoiShow.fromJson(Map<String, dynamic> json) {
    final titleStr = json['title']?.toString() ?? json['name']?.toString() ?? '';
    final isDub = json['isDubbed'] == true ||
        json['audio'] == 'dublado' ||
        titleStr.toLowerCase().contains('dublado');

    return SugoiShow(
      id: json['id']?.toString() ?? json['slug']?.toString() ?? json['url']?.toString() ?? '',
      title: titleStr,
      image: json['image']?.toString() ?? json['poster']?.toString() ?? json['cover']?.toString(),
      isDubbed: isDub,
      episodeCount: json['episodesCount'] is int
          ? json['episodesCount']
          : int.tryParse(json['episodes']?.toString() ?? '') ?? 0,
      url: json['url']?.toString(),
    );
  }
}

/// Modelo de episódio do SugoiAPI
class SugoiEpisode {
  final String id;
  final String number;
  final String? title;
  final String? videoUrl;

  SugoiEpisode({
    required this.id,
    required this.number,
    this.title,
    this.videoUrl,
  });

  factory SugoiEpisode.fromJson(Map<String, dynamic> json) {
    return SugoiEpisode(
      id: json['id']?.toString() ?? json['episodeId']?.toString() ?? '',
      number: json['number']?.toString() ?? json['episode']?.toString() ?? '',
      title: json['title']?.toString(),
      videoUrl: json['url']?.toString() ?? json['videoUrl']?.toString() ?? json['streamUrl']?.toString(),
    );
  }
}

class SugoiService {
  static const List<String> _baseUrls = [
    'https://sugoi-api.vercel.app/api',
    'https://api-animes-br.vercel.app/api',
  ];

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

  static Future<List<SugoiShow>> searchAnime(String query) async {
    final cleanQuery = Uri.encodeComponent(query.trim());
    if (cleanQuery.isEmpty) return [];

    for (final baseUrl in _baseUrls) {
      try {
        final url = Uri.parse('$baseUrl/search?q=$cleanQuery');
        final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List list = data is List
              ? data
              : (data['results'] ?? data['animes'] ?? data['data'] ?? []);

          return list
              .map((item) => SugoiShow.fromJson(item))
              .where((show) => show.id.isNotEmpty && show.title.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    return [];
  }

  static Future<List<SugoiEpisode>> getEpisodes(String animeId) async {
    final cleanId = Uri.encodeComponent(animeId.trim());
    if (cleanId.isEmpty) return [];

    for (final baseUrl in _baseUrls) {
      try {
        final url = Uri.parse('$baseUrl/anime/$cleanId/episodes');
        final response = await http.get(url).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List list = data is List ? data : (data['episodes'] ?? []);
          return list
              .map((item) => SugoiEpisode.fromJson(item))
              .where((ep) => ep.id.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    return [];
  }

  static Future<String?> getStreamUrl(String episodeId) async {
    final cleanEpId = Uri.encodeComponent(episodeId.trim());
    if (cleanEpId.isEmpty) return null;

    for (final baseUrl in _baseUrls) {
      try {
        final url = Uri.parse('$baseUrl/episode/$cleanEpId');
        final response = await http.get(url).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final streamUrl = data['streamUrl'] ?? data['url'] ?? data['videoUrl'];
          if (streamUrl != null && streamUrl.toString().isNotEmpty) {
            return streamUrl.toString();
          }
        }
      } catch (_) {}
    }
    return null;
  }
}
