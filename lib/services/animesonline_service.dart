import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'backend_config.dart';

class AnimesOnlineShow {
  final String id;
  final String title;
  final String? image;
  final String url;
  
  AnimesOnlineShow({
    required this.id,
    required this.title,
    this.image,
    required this.url,
  });

  factory AnimesOnlineShow.fromJson(Map<String, dynamic> json) {
    return AnimesOnlineShow(
      id: json['id']?.toString() ?? '',
      title: json['name']?.toString() ?? '',
      image: json['imageUrl']?.toString(),
      url: json['url']?.toString() ?? '',
    );
  }
}

class AnimesOnlineEpisode {
  final String id;
  final String number;
  final String title;

  AnimesOnlineEpisode({
    required this.id,
    required this.number,
    required this.title,
  });

  factory AnimesOnlineEpisode.fromJson(Map<String, dynamic> json) {
    return AnimesOnlineEpisode(
      id: json['id']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
    );
  }
}

class AnimesOnlineVideoSource {
  final String url;
  final String quality;

  AnimesOnlineVideoSource({
    required this.url,
    required this.quality,
  });

  factory AnimesOnlineVideoSource.fromJson(Map<String, dynamic> json) {
    return AnimesOnlineVideoSource(
      url: json['url']?.toString() ?? '',
      quality: json['quality']?.toString() ?? 'auto',
    );
  }
}

class AnimesOnlineService {
  static Future<List<AnimesOnlineShow>> searchAnime(String query) async {
    final cleanQuery = Uri.encodeComponent(query.trim());
    if (cleanQuery.isEmpty) return [];

    try {
      final response = await BackendConfig.get('/api/animesonline/search?q=$cleanQuery');
      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((e) => AnimesOnlineShow.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('AnimesOnlineService search error: $e');
    }
    return [];
  }

  static Future<List<AnimesOnlineEpisode>> getEpisodes(String animeId) async {
    final cleanId = Uri.encodeComponent(animeId.trim());
    if (cleanId.isEmpty) return [];

    try {
      final response = await BackendConfig.get('/api/animesonline/info?id=$cleanId');
      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List episodes = data['episodes'] ?? [];
        final mapped = episodes.map((e) => AnimesOnlineEpisode.fromJson(e)).toList();
        return mapped.reversed.toList();
      }
    } catch (e) {
      debugPrint('AnimesOnlineService getEpisodes error: $e');
    }
    return [];
  }

  static Future<List<AnimesOnlineVideoSource>> getStreamSources(String episodeId) async {
    final cleanEpId = Uri.encodeComponent(episodeId.trim());
    if (cleanEpId.isEmpty) return [];

    try {
      final response = await BackendConfig.get('/api/animesonline/watch?episodeId=$cleanEpId');
      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List sources = data['sources'] ?? [];
        return sources.map((e) => AnimesOnlineVideoSource.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('AnimesOnlineService getStreamSources error: $e');
    }
    return [];
  }
}
