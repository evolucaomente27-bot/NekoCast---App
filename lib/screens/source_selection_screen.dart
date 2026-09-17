import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';
import '../theme/app_colors.dart';
import '../widgets/tv_focusable.dart';
import '../services/player_service.dart';
import 'episode_list_screen.dart';

/// Direct AnimeFire Source and Version Selection Screen
class SourceSelectionScreen extends StatefulWidget {
  final String animeTitle;
  final String imageUrl;
  final String myAnimeListUrl;

  const SourceSelectionScreen({
    super.key,
    required this.animeTitle,
    required this.imageUrl,
    required this.myAnimeListUrl,
  });

  @override
  State<SourceSelectionScreen> createState() => _SourceSelectionScreenState();
}

class _SourceSelectionScreenState extends State<SourceSelectionScreen> {
  bool _isSearching = true;
  String? _errorMessage;
  List<Anime> _animeFireResults = [];
  final TextEditingController _customSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _customSearchController.text = widget.animeTitle;
    _searchAnimeFire(widget.animeTitle);
  }

  @override
  void dispose() {
    _customSearchController.dispose();
    super.dispose();
  }

  List<String> _buildSearchQueries(String title) {
    final queries = <String>[];

    void addQuery(String value) {
      final cleaned = value.trim();
      if (cleaned.isEmpty) return;
      if (!queries.contains(cleaned)) {
        queries.add(cleaned);
      }
    }

    addQuery(title);

    final noSpaces = title.replaceAll(' ', '');
    addQuery(noSpaces);

    final hyphenated = title.replaceAll(RegExp(r'\s+'), '-');
    addQuery(hyphenated);

    final noSymbols = title
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    addQuery(noSymbols);

    // First two words
    final words = noSymbols.split(' ').where((w) => w.length > 1).toList();
    if (words.length >= 2) {
      addQuery(words.take(2).join(' '));
      addQuery(words.take(2).join(''));
    }

    return queries;
  }

  int _scoreTextMatch(String candidate, String query) {
    final normalizedCandidate = candidate.toLowerCase().trim();
    final normalizedQuery = query.toLowerCase().trim();

    if (normalizedCandidate == normalizedQuery) return 1000;
    if (normalizedCandidate.startsWith(normalizedQuery) ||
        normalizedQuery.startsWith(normalizedCandidate)) {
      return 800;
    }
    if (normalizedCandidate.contains(normalizedQuery) ||
        normalizedQuery.contains(normalizedCandidate)) {
      return 600;
    }

    final queryTokens =
        normalizedQuery.split(' ').where((e) => e.isNotEmpty).toSet();
    var overlap = 0;
    for (final token in normalizedCandidate.split(' ')) {
      if (queryTokens.contains(token)) {
        overlap++;
      }
    }

    return (overlap * 80) -
        (normalizedCandidate.length - normalizedQuery.length).abs();
  }

  Future<void> _searchAnimeFire(String searchTitle) async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _animeFireResults = [];
    });

    try {
      final queries = _buildSearchQueries(searchTitle);
      final animeMap = <String, Anime>{};

      for (final query in queries) {
        final results = await AnimeService.searchAnimeFireOnly(query);
        for (final anime in results) {
          animeMap.putIfAbsent(anime.url, () => anime);
        }

        if (animeMap.length >= 6) {
          break;
        }
      }

      if (!mounted) return;
      final playerService =
          Provider.of<PlayerService>(context, listen: false);
      final preferDub = playerService.isDubbedPreferred;

      final results = animeMap.values.toList()
        ..sort((a, b) {
          final scoreB = _scoreTextMatch(b.name, searchTitle);
          final scoreA = _scoreTextMatch(a.name, searchTitle);
          // If scores are relatively close, prefer user audio preference
          if ((scoreA - scoreB).abs() <= 200) {
            if (preferDub && a.isDubbed != b.isDubbed) {
              return a.isDubbed ? -1 : 1;
            } else if (!preferDub && a.isDubbed != b.isDubbed) {
              return a.isDubbed ? 1 : -1;
            }
          }
          return scoreB.compareTo(scoreA);
        });

      if (!mounted) return;

      if (results.isNotEmpty) {
        // If exact single match, directly navigate!
        if (results.length == 1) {
          final singleMatch = results.first;
          await AnimeService.enrichAnimeWithAniList(singleMatch);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ModernEpisodeListScreen(anime: singleMatch),
            ),
          );
          return;
        }

        setState(() {
          _animeFireResults = results;
          _isSearching = false;
        });
      } else {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Nenhum resultado encontrado no AnimeFire';
        });
      }
    } catch (e) {
      debugPrint('Error searching AnimeFire: $e');
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _errorMessage = 'Erro ao buscar no AnimeFire';
      });
    }
  }

  Future<void> _openAnime(Anime anime) async {
    await AnimeService.enrichAnimeWithAniList(anime);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ModernEpisodeListScreen(anime: anime),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          widget.animeTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isSearching
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 20),
                  Text(
                    'Carregando AnimeFire...',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.animeTitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : _errorMessage != null && _animeFireResults.isEmpty
              ? _buildNotFoundView()
              : _buildResultsList(),
    );
  }

  Widget _buildNotFoundView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off, color: Colors.redAccent, size: 54),
            ),
            const SizedBox(height: 20),
            const Text(
              'Anime não encontrado no AnimeFire',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tente buscar por outro termo ou nome alternativo:',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _customSearchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Digite o nome do anime...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppColors.surface,
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: () => _searchAnimeFire(_customSearchController.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (val) => _searchAnimeFire(val),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _searchAnimeFire(_customSearchController.text),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFF6B35), width: 0.8),
              ),
              child: const Text(
                'AnimeFire Direto',
                style: TextStyle(
                  color: Color(0xFFFF6B35),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${_animeFireResults.length} versões encontradas',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Results
        ..._animeFireResults.map((anime) {
          final isDubbed = anime.isDubbed;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TvFocusable(
              onPressed: () => _openAnime(anime),
              focusScale: 1.03,
              borderRadius: BorderRadius.circular(14),
              showFocusBorder: true,
              showFocusGlow: true,
              builder: (context, hasFocus, isHovered) {
                return Container(
                  decoration: BoxDecoration(
                    color: hasFocus
                        ? AppColors.primary.withValues(alpha: 0.18)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasFocus
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 50,
                        height: 65,
                        child: anime.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: anime.imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => const Icon(
                                  Icons.movie,
                                  color: Colors.white24,
                                ),
                              )
                            : (widget.imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: widget.imageUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => const Icon(
                                      Icons.movie,
                                      color: Colors.white24,
                                    ),
                                  )
                                : const Icon(Icons.movie, color: Colors.white24)),
                      ),
                    ),
                    title: Text(
                      anime.name,
                      style: TextStyle(
                        color: hasFocus ? AppColors.primaryLight : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDubbed
                                  ? const Color(0xFF2E7D32).withValues(alpha: 0.25)
                                  : Colors.blue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDubbed
                                    ? const Color(0xFF4CAF50)
                                    : Colors.blue,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              isDubbed ? '🇧🇷 Dublado' : '🇯🇵 Legendado',
                              style: TextStyle(
                                color: isDubbed
                                    ? const Color(0xFF81C784)
                                    : Colors.lightBlueAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'AnimeFire',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    trailing: Icon(
                      Icons.play_circle_fill,
                      color: hasFocus ? AppColors.primaryLight : AppColors.primary,
                      size: 32,
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}
