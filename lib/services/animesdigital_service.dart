import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'backend_config.dart';

class AnimesDigitalShow {
  final String id;
  final String title;
  final String? image;
  final String url;

  AnimesDigitalShow({
    required this.id,
    required this.title,
    this.image,
    required this.url,
  });

  factory AnimesDigitalShow.fromJson(Map<String, dynamic> json) {
    return AnimesDigitalShow(
      id: json['id']?.toString() ?? '',
      title: json['name']?.toString() ?? '',
      image: json['imageUrl']?.toString(),
      url: json['url']?.toString() ?? '',
    );
  }
}

class AnimesDigitalEpisode {
  final String id;
  final String number;
  final String title;
  final String url;

  AnimesDigitalEpisode({
    required this.id,
    required this.number,
    required this.title,
    required this.url,
  });

  factory AnimesDigitalEpisode.fromJson(Map<String, dynamic> json) {
    return AnimesDigitalEpisode(
      id: json['id']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }
}

class AnimesDigitalVideoSource {
  final String url;
  final String quality;
  final bool isM3U8;
  final Map<String, String>? headers;

  AnimesDigitalVideoSource({
    required this.url,
    required this.quality,
    this.isM3U8 = false,
    this.headers,
  });

  factory AnimesDigitalVideoSource.fromJson(Map<String, dynamic> json) {
    Map<String, String>? headersMap;
    if (json['headers'] != null && json['headers'] is Map) {
      headersMap = (json['headers'] as Map).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }

    return AnimesDigitalVideoSource(
      url: json['url']?.toString() ?? '',
      quality: json['quality']?.toString() ?? 'auto',
      isM3U8: json['isM3U8'] == true || (json['url']?.toString().contains('.m3u8') ?? false),
      headers: headersMap,
    );
  }
}

class AnimesDigitalService {
  static Future<List<AnimesDigitalShow>> searchAnime(String query) async {
    final cleanQuery = Uri.encodeComponent(query.trim());
    if (cleanQuery.isEmpty) return [];

    try {
      final response = await BackendConfig.get('/api/animesdigital/search?q=$cleanQuery');
      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((e) => AnimesDigitalShow.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('AnimesDigitalService search error: $e');
    }
    return [];
  }

  static Future<List<AnimesDigitalEpisode>> getEpisodes(String animeUrlOrId) async {
    final cleanParam = Uri.encodeComponent(animeUrlOrId.trim());
    if (cleanParam.isEmpty) return [];

    try {
      final isUrl = animeUrlOrId.startsWith('http');
      final queryParam = isUrl ? 'url=$cleanParam' : 'id=$cleanParam';
      final response = await BackendConfig.get('/api/animesdigital/info?$queryParam');
      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List episodes = data['episodes'] ?? [];
        return episodes.map((e) => AnimesDigitalEpisode.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('AnimesDigitalService getEpisodes error: $e');
    }
    return [];
  }

  static Future<List<AnimesDigitalVideoSource>> getStreamSources(String episodeUrlOrId) async {
    final cleanParam = Uri.encodeComponent(episodeUrlOrId.trim());
    if (cleanParam.isEmpty) return [];

    try {
      final isUrl = episodeUrlOrId.startsWith('http');
      final queryParam = isUrl ? 'url=$cleanParam' : 'episodeId=$cleanParam';
      final response = await BackendConfig.get('/api/animesdigital/watch?$queryParam');
      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List sources = data['sources'] ?? [];
        return sources.map((e) => AnimesDigitalVideoSource.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('AnimesDigitalService getStreamSources error: $e');
    }
    return [];
  }
}
