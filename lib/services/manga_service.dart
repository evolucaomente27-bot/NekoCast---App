import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class MangaTitle {
  final String id;
  final String title;
  final String description;
  final String? coverUrl;
  final String status;
  final List<String> tags;

  const MangaTitle({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.status,
    required this.tags,
  });
}

class MangaChapter {
  final String id;
  final String title;
  final String chapter;
  final String language;
  final DateTime? publishedAt;

  const MangaChapter({
    required this.id,
    required this.title,
    required this.chapter,
    required this.language,
    required this.publishedAt,
  });

  String get displayTitle {
    final prefix = chapter.isEmpty ? 'Chapter' : 'Chapter $chapter';
    return title.isEmpty ? prefix : '$prefix - $title';
  }
}

class MangaDownloadItem {
  final String id;
  final String mangaTitle;
  final String chapterTitle;
  final String directoryPath;
  final int pageCount;
  final DateTime completedAt;

  const MangaDownloadItem({
    required this.id,
    required this.mangaTitle,
    required this.chapterTitle,
    required this.directoryPath,
    required this.pageCount,
    required this.completedAt,
  });
}

class MangaChapterPages {
  final String chapterId;
  final List<String> pageUrls;

  const MangaChapterPages({required this.chapterId, required this.pageUrls});
}

class MangaDownloadProgress {
  final String chapterId;
  final int completed;
  final int total;

  const MangaDownloadProgress({
    required this.chapterId,
    required this.completed,
    required this.total,
  });

  double get progress => total == 0 ? 0 : completed / total;
}

class MangaService extends ChangeNotifier {
  static const _apiBase = 'https://api.mangadex.org';
  static const _atHomeBase = 'https://api.mangadex.org/at-home/server';
  static const _coverBase = 'https://uploads.mangadex.org/covers';

  final http.Client _client;
  final Map<String, MangaDownloadProgress> _progress = {};

  MangaService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, MangaDownloadProgress> get progress => Map.unmodifiable(_progress);

  Future<List<MangaTitle>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final uri = Uri.parse('$_apiBase/manga').replace(
      queryParameters: {
        'title': trimmed,
        'limit': '24',
        'includes[]': 'cover_art',
        'contentRating[]': 'safe',
        'order[relevance]': 'desc',
      },
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Manga search failed: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'] as List? ?? const [];
    return data.map((item) => _parseManga(item)).toList();
  }

  Future<List<MangaChapter>> getChapters(
    String mangaId, {
    String language = 'en',
  }) async {
    final uri = Uri.parse('$_apiBase/manga/$mangaId/feed').replace(
      queryParameters: {
        'limit': '100',
        'translatedLanguage[]': language,
        'order[chapter]': 'asc',
        'order[publishAt]': 'asc',
      },
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Chapter list failed: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'] as List? ?? const [];
    return data.map((item) => _parseChapter(item)).toList();
  }

  Future<MangaChapterPages> getChapterPages(String chapterId) async {
    final uri = Uri.parse('$_atHomeBase/$chapterId').replace(
      queryParameters: {'forcePort443': 'true'},
    );
    final response = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Chapter pages failed: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final baseUrl = payload['baseUrl'] as String? ?? '';
    final chapter = payload['chapter'] as Map<String, dynamic>? ?? const {};
    final hash = chapter['hash'] as String? ?? '';
    final pages = chapter['dataSaver'] as List? ?? chapter['data'] as List? ?? [];

    if (baseUrl.isEmpty || hash.isEmpty || pages.isEmpty) {
      throw Exception('No pages available for this chapter');
    }

    final urls = pages
        .whereType<String>()
        .map((file) => '$baseUrl/data-saver/$hash/$file')
        .toList();
    return MangaChapterPages(chapterId: chapterId, pageUrls: urls);
  }

  Future<MangaDownloadItem> downloadChapter({
    required MangaTitle manga,
    required MangaChapter chapter,
  }) async {
    final pages = await getChapterPages(chapter.id);
    final root = await _getMangaDirectory();
    final mangaDir = Directory(path.join(root.path, _safeName(manga.title)));
    final chapterDir = Directory(
      path.join(mangaDir.path, _safeName(chapter.displayTitle)),
    );
    await chapterDir.create(recursive: true);

    _progress[chapter.id] = MangaDownloadProgress(
      chapterId: chapter.id,
      completed: 0,
      total: pages.pageUrls.length,
    );
    notifyListeners();

    for (var i = 0; i < pages.pageUrls.length; i++) {
      final pageUrl = pages.pageUrls[i];
      final ext = path.extension(Uri.parse(pageUrl).path).isEmpty
          ? '.jpg'
          : path.extension(Uri.parse(pageUrl).path);
      final file = File(path.join(chapterDir.path, '${i + 1}'.padLeft(3, '0') + ext));
      if (!await file.exists()) {
        final response = await _client.get(Uri.parse(pageUrl));
        if (response.statusCode >= 400) {
          throw Exception('Failed page ${i + 1}: ${response.statusCode}');
        }
        await file.writeAsBytes(response.bodyBytes);
      }
      _progress[chapter.id] = MangaDownloadProgress(
        chapterId: chapter.id,
        completed: i + 1,
        total: pages.pageUrls.length,
      );
      notifyListeners();
    }

    _progress.remove(chapter.id);
    notifyListeners();

    return MangaDownloadItem(
      id: chapter.id,
      mangaTitle: manga.title,
      chapterTitle: chapter.displayTitle,
      directoryPath: chapterDir.path,
      pageCount: pages.pageUrls.length,
      completedAt: DateTime.now(),
    );
  }

  MangaTitle _parseManga(dynamic item) {
    final map = item as Map<String, dynamic>;
    final id = map['id'] as String;
    final attributes = map['attributes'] as Map<String, dynamic>? ?? const {};
    final titleMap = attributes['title'] as Map<String, dynamic>? ?? const {};
    final descriptionMap =
        attributes['description'] as Map<String, dynamic>? ?? const {};
    final tags = attributes['tags'] as List? ?? const [];

    String? coverFileName;
    for (final relation in map['relationships'] as List? ?? const []) {
      final rel = relation as Map<String, dynamic>;
      if (rel['type'] == 'cover_art') {
        final relAttrs = rel['attributes'] as Map<String, dynamic>? ?? const {};
        coverFileName = relAttrs['fileName'] as String?;
        break;
      }
    }

    return MangaTitle(
      id: id,
      title: _localizedText(titleMap),
      description: _localizedText(descriptionMap),
      coverUrl: coverFileName == null ? null : '$_coverBase/$id/$coverFileName.256.jpg',
      status: attributes['status']?.toString() ?? 'unknown',
      tags: tags
          .map((tag) {
            final tagAttrs =
                (tag as Map<String, dynamic>)['attributes'] as Map<String, dynamic>?;
            final names = tagAttrs?['name'] as Map<String, dynamic>? ?? const {};
            return _localizedText(names);
          })
          .where((tag) => tag.isNotEmpty)
          .take(4)
          .toList(),
    );
  }

  MangaChapter _parseChapter(dynamic item) {
    final map = item as Map<String, dynamic>;
    final attributes = map['attributes'] as Map<String, dynamic>? ?? const {};
    return MangaChapter(
      id: map['id'] as String,
      title: attributes['title']?.toString() ?? '',
      chapter: attributes['chapter']?.toString() ?? '',
      language: attributes['translatedLanguage']?.toString() ?? '',
      publishedAt: DateTime.tryParse(attributes['publishAt']?.toString() ?? ''),
    );
  }

  String _localizedText(Map<String, dynamic> values) {
    for (final key in const ['en', 'pt-br', 'pt']) {
      final value = values[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    for (final value in values.values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  Future<Directory> _getMangaDirectory() async {
    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      return Directory(path.join(directory!.path, 'NekoCast', 'Manga'));
    }
    final directory = await getApplicationDocumentsDirectory();
    return Directory(path.join(directory.path, 'Manga'));
  }

  String _safeName(String value) {
    return value
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
