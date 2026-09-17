import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WatchHistoryItem {
  final String animeTitle;
  final String animeImageUrl;
  final String episodeNumber;
  final String episodeTitle;
  final String episodeUrl;
  final int positionSeconds;
  final int durationSeconds;
  final DateTime lastWatchedAt;
  final String? animeSourceUrl;

  WatchHistoryItem({
    required this.animeTitle,
    required this.animeImageUrl,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.episodeUrl,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.lastWatchedAt,
    this.animeSourceUrl,
  });

  double get progress {
    if (durationSeconds <= 0) return 0.0;
    final p = positionSeconds / durationSeconds;
    return p.clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'animeTitle': animeTitle,
        'animeImageUrl': animeImageUrl,
        'episodeNumber': episodeNumber,
        'episodeTitle': episodeTitle,
        'episodeUrl': episodeUrl,
        'positionSeconds': positionSeconds,
        'durationSeconds': durationSeconds,
        'lastWatchedAt': lastWatchedAt.toIso8601String(),
        'animeSourceUrl': animeSourceUrl,
      };

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) =>
      WatchHistoryItem(
        animeTitle: json['animeTitle'] ?? '',
        animeImageUrl: json['animeImageUrl'] ?? '',
        episodeNumber: json['episodeNumber'] ?? '',
        episodeTitle: json['episodeTitle'] ?? '',
        episodeUrl: json['episodeUrl'] ?? '',
        positionSeconds: json['positionSeconds'] ?? 0,
        durationSeconds: json['durationSeconds'] ?? 0,
        lastWatchedAt: DateTime.tryParse(json['lastWatchedAt'] ?? '') ??
            DateTime.now(),
        animeSourceUrl: json['animeSourceUrl'],
      );
}

class WatchHistoryService extends ChangeNotifier {
  static const String _storageKey = 'nekocast_watch_history_v1';
  static final WatchHistoryService _instance = WatchHistoryService._internal();

  factory WatchHistoryService() => _instance;

  WatchHistoryService._internal();

  List<WatchHistoryItem> _items = [];
  bool _isLoaded = false;

  List<WatchHistoryItem> get items => List.unmodifiable(_items);

  Future<List<WatchHistoryItem>> getHistory() async {
    if (!_isLoaded) {
      await load();
    }
    return _items;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        _items = list
            .map((e) => WatchHistoryItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _items.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
      }
    } catch (e) {
      debugPrint('[WatchHistoryService] Error loading history: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> saveProgress({
    required String animeTitle,
    required String animeImageUrl,
    required String episodeNumber,
    required String episodeTitle,
    required String episodeUrl,
    required int positionSeconds,
    required int durationSeconds,
    String? animeSourceUrl,
  }) async {
    final cleanTitle = animeTitle.trim();
    if (cleanTitle.isEmpty) return;

    final existingIndex = _items.indexWhere(
      (item) => item.animeTitle.toLowerCase() == cleanTitle.toLowerCase(),
    );

    final newItem = WatchHistoryItem(
      animeTitle: cleanTitle,
      animeImageUrl: animeImageUrl.isNotEmpty
          ? animeImageUrl
          : (existingIndex >= 0 ? _items[existingIndex].animeImageUrl : ''),
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      episodeUrl: episodeUrl,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
      lastWatchedAt: DateTime.now(),
      animeSourceUrl: animeSourceUrl ??
          (existingIndex >= 0 ? _items[existingIndex].animeSourceUrl : null),
    );

    if (existingIndex >= 0) {
      _items.removeAt(existingIndex);
    }
    _items.insert(0, newItem);

    // Keep max 50 recent items
    if (_items.length > 50) {
      _items = _items.sublist(0, 50);
    }

    notifyListeners();
    await _persist();
  }

  Future<void> removeItem(String animeTitle) async {
    _items.removeWhere(
      (item) => item.animeTitle.toLowerCase() == animeTitle.toLowerCase(),
    );
    notifyListeners();
    await _persist();
  }

  Future<void> clearHistory() async {
    _items.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_items.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('[WatchHistoryService] Error persisting history: $e');
    }
  }
}
