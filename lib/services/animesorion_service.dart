import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'backend_config.dart';

class AnimesOrionShow {
  final String id;
  final String title;
  final String? image;
  final String url;
  
  AnimesOrionShow({
    required this.id,
    required this.title,
    this.image,
    required this.url,
  });

  factory AnimesOrionShow.fromJson(Map<String, dynamic> json) {
    return AnimesOrionShow(
      id: json['id']?.toString() ?? '',
      title: json['name']?.toString() ?? '',
      image: json['imageUrl']?.toString(),
      url: json['url']?.toString() ?? '',
    );
  }
}

class AnimesOrionEpisode {
  final String id;
  final String number;
  final String title;

  AnimesOrionEpisode({
    required this.id,
    required this.number,
    required this.title,
  });

  factory AnimesOrionEpisode.fromJson(Map<String, dynamic> json) {
    return AnimesOrionEpisode(
      id: json['id']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
    );
  }
}

class AnimesOrionVideoSource {
  final String url;
  final String quality;

  AnimesOrionVideoSource({
    required this.url,
    required this.quality,
  });

  factory AnimesOrionVideoSource.fromJson(Map<String, dynamic> json) {
    return AnimesOrionVideoSource(
      url: json['url']?.toString() ?? '',
      quality: json['quality']?.toString() ?? 'auto',
    );
  }
}

class AnimesOrionService {
  static Future<List<AnimesOrionShow>> searchAnime(String query) async {
    final cleanQuery = Uri.encodeComponent(query.trim());
    if (cleanQuery.isEmpty) return [];

    try {
      final response = await BackendConfig.get('/api/animesorion/search?q=$cleanQuery');
      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((e) => AnimesOrionShow.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('AnimesOrionService search error: $e');
    }
    return [];
  }

  static Future<List<AnimesOrionEpisode>> getEpisodes(String animeId) async {
    final cleanId = Uri.encodeComponent(animeId.trim());
    if (cleanId.isEmpty) return [];

    try {
      final response = await BackendConfig.get('/api/animesorion/info?id=$cleanId');
      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List episodes = data['episodes'] ?? [];
        final mapped = episodes.map((e) => AnimesOrionEpisode.fromJson(e)).toList();
        return mapped.reversed.toList();
      }
    } catch (e) {
      debugPrint('AnimesOrionService getEpisodes error: $e');
    }
    return [];
  }

  static Future<List<AnimesOrionVideoSource>> getStreamSources(String episodeId) async {
    final cleanEpId = Uri.encodeComponent(episodeId.trim());
    if (cleanEpId.isEmpty) return [];

    try {
      final response = await BackendConfig.get('/api/animesorion/watch?episodeId=$cleanEpId');
      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List sources = data['sources'] ?? [];
        return sources.map((e) => AnimesOrionVideoSource.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('AnimesOrionService getStreamSources error: $e');
    }
    return [];
  }
}
