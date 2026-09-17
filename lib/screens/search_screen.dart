import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/jikan_models.dart';
import '../services/jikan_service.dart';
import '../services/search_history_service.dart';
import '../services/tv_mode_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/tv_focusable.dart';
import '../main.dart';
import 'source_selection_screen.dart';

class SearchScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  final bool initialFilterDubbed;

  const SearchScreen({
    super.key,
    this.onBackPressed,
    this.initialFilterDubbed = false,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final JikanService _jikanService = JikanService();
  final FocusNode _searchFocusNode = FocusNode();

  late AnimationController _animationController;
  Timer? _debounce;

  List<String> _searchHistory = [];
  List<String> _suggestions = [];
  List<JikanAnime> _trendingAnimes = [];
  List<JikanAnime> _searchResults = [];
  List<JikanAnime> _recentSearchResults = [];

  bool _isLoadingTrending = true;
  bool _isSearching = false;
  bool _showHistory = true;
  int _searchRequestId = 0;
  String? _searchError;

  // Filtros
  int? _selectedGenre;
  bool _filterDubbedOnly = false;

  List<Map<String, dynamic>> _getGenres() {
    final l10n = AppLocalizations.of(context);
    return [
      {'id': JikanGenreIds.action, 'name': l10n.action, 'icon': Icons.flash_on},
      {
        'id': JikanGenreIds.adventure,
        'name': l10n.adventure,
        'icon': Icons.explore,
      },
      {
        'id': JikanGenreIds.comedy,
        'name': l10n.comedy,
        'icon': Icons.emoji_emotions,
      },
      {
        'id': JikanGenreIds.drama,
        'name': l10n.drama,
        'icon': Icons.theater_comedy,
      },
      {
        'id': JikanGenreIds.fantasy,
        'name': l10n.fantasy,
        'icon': Icons.auto_awesome,
      },
      {
        'id': JikanGenreIds.horror,
        'name': l10n.horror,
        'icon': Icons.dark_mode,
      },
      {'id': JikanGenreIds.mystery, 'name': l10n.mystery, 'icon': Icons.search},
      {
        'id': JikanGenreIds.romance,
        'name': l10n.romance,
        'icon': Icons.favorite,
      },
      {
        'id': JikanGenreIds.sciFi,
        'name': l10n.sciFi,
        'icon': Icons.rocket_launch,
      },
      {
        'id': JikanGenreIds.sliceOfLife,
        'name': l10n.sliceOfLife,
        'icon': Icons.wb_sunny,
      },
      {
        'id': JikanGenreIds.sports,
        'name': l10n.sports,
        'icon': Icons.sports_soccer,
      },
      {
        'id': JikanGenreIds.supernatural,
        'name': l10n.supernatural,
        'icon': Icons.auto_fix_high,
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();

    _loadSearchHistory();
    _loadTrendingAnimes();
    _loadRecentSearches();

    if (widget.initialFilterDubbed) {
      _filterDubbedOnly = true;
      _showHistory = false;
      _performSearch('');
    }

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final query = _searchController.text.trim();

    if (query.isEmpty) {
      _searchRequestId++;
      if (_filterDubbedOnly) {
        _performSearch('');
        return;
      }
      setState(() {
        _showHistory = true;
        _suggestions = [];
        _searchResults = [];
        _searchError = null;
        _isSearching = false;
      });
      return;
    }

    setState(() => _showHistory = false);

    // Busca sugestões no histórico
    _loadSuggestions(query);

    // Debounce para busca na API
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _loadSearchHistory() async {
    final history = await SearchHistoryService.getSearchHistory();
    if (mounted) setState(() => _searchHistory = history);
  }

  Future<void> _loadSuggestions(String query) async {
    final suggestions = await SearchHistoryService.getSuggestions(query);
    if (mounted && _searchController.text.trim() == query) {
      setState(() => _suggestions = suggestions);
    }
  }

  Future<void> _loadTrendingAnimes() async {
    setState(() => _isLoadingTrending = true);
    try {
      var animes = await _jikanService.getCurrentSeasonAnimes(limit: 12);
      if (animes.isEmpty) {
        animes = await _jikanService.getTopAnimes(limit: 12);
      }
      if (mounted) {
        setState(() {
          _trendingAnimes = animes;
          _isLoadingTrending = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading trending animes: $e');
      if (mounted) setState(() => _isLoadingTrending = false);
    }
  }

  Future<void> _loadRecentSearches() async {
    final history = await SearchHistoryService.getSearchHistory();
    if (history.isEmpty) return;

    // Busca os últimos 3 animes do histórico
    final recentSearches = history.take(3).toList();
    final List<JikanAnime> results = [];

    for (final query in recentSearches) {
      try {
        await Future.delayed(const Duration(milliseconds: 400)); // Rate limit
        final searchResults = await _jikanService.searchAnimes(query, limit: 1);
        if (searchResults.isNotEmpty) {
          results.add(searchResults.first);
        }
      } catch (e) {
        debugPrint('Error loading recent search: $e');
      }
    }

    if (mounted) {
      setState(() => _recentSearchResults = results);
    }
  }

  Future<void> _performSearch(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty && _selectedGenre == null && !_filterDubbedOnly) return;

    final requestId = ++_searchRequestId;

    setState(() {
      _isSearching = true;
      _searchError = null;
      _showHistory = false;
    });

    try {
      List<JikanAnime> results;

      if (_filterDubbedOnly) {
        final List<Anime> afAnimes;
        if (normalizedQuery.isNotEmpty) {
          afAnimes = await AnimeService.searchAnimeFireOnly('$normalizedQuery dublado');
        } else {
          afAnimes = await AnimeService.getDubbedAnimes();
        }
        results = afAnimes.map((af) => JikanAnime(
          malId: 0,
          title: af.name,
          titleEnglish: af.name,
          titleJapanese: af.name,
          imageUrl: af.imageUrl,
          largImageUrl: af.imageUrl,
          score: null,
          status: 'Dublado PT-BR',
          synopsis: 'Disponível com dublagem brasileira no AnimeFire',
          genres: [
            JikanGenre(
              malId: 0,
              name: 'Dublado PT-BR',
              type: 'genre',
            ),
          ],
        )).toList();
      } else if (normalizedQuery.isNotEmpty) {
        results = await _jikanService.searchAnimes(
          normalizedQuery,
          limit: 20,
          genreId: _selectedGenre,
        );
      } else if (_selectedGenre != null) {
        results = await _jikanService.getAnimesByGenre(_selectedGenre!);
      } else {
        results = [];
      }

      if (mounted && requestId == _searchRequestId) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
          _suggestions = [];
        });
      }
    } catch (e) {
      debugPrint('Error searching animes: $e');
      if (mounted && requestId == _searchRequestId) {
        setState(() {
          _isSearching = false;
          _searchError = e.toString();
        });
      }
    }
  }

  Future<void> _selectSearchQuery(String query) async {
    final cleanedQuery = query.trim();
    if (cleanedQuery.isEmpty) return;
    _searchController.text = cleanedQuery;
    _searchFocusNode.unfocus();

    // Salva no histórico
    await SearchHistoryService.saveSearch(cleanedQuery);
    await _loadSearchHistory();

    // Realiza a busca
    _performSearch(cleanedQuery);
  }

  Future<void> _submitSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty && _selectedGenre == null && !_filterDubbedOnly) return;
    _searchFocusNode.unfocus();
    if (query.isNotEmpty) {
      await SearchHistoryService.saveSearch(query);
      await _loadSearchHistory();
    }
    _performSearch(query);
  }

  Future<void> _removeHistoryItem(String query) async {
    await SearchHistoryService.removeSearchItem(query);
    await _loadSearchHistory();
  }

  Future<void> _clearHistory() async {
    await SearchHistoryService.clearHistory();
    await _loadSearchHistory();
    setState(() => _recentSearchResults = []);
  }

  void _selectGenre(int? genreId) {
    setState(() {
      _selectedGenre = genreId;
      if (genreId != null) {
        _filterDubbedOnly = false;
      }
    });

    if (_searchController.text.isNotEmpty || _selectedGenre != null || _filterDubbedOnly) {
      _performSearch(_searchController.text);
    } else {
      setState(() {
        _showHistory = true;
        _searchResults = [];
      });
    }
  }

  Future<void> _onAnimeTap(JikanAnime anime) async {
    // Salva no histórico
    await SearchHistoryService.saveSearch(anime.title);

    // Navega para tela de seleção de fonte
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SourceSelectionScreen(
          animeTitle: anime.title,
          imageUrl: anime.imageUrl,
          myAnimeListUrl: 'https://myanimelist.net/anime/${anime.malId}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            _buildSearchHeader(canPop),

            // Genre Filters
            if (!_showHistory) _buildGenreFilters(),

            // Content
            Expanded(
              child: _showHistory
                  ? _buildHistoryAndTrending()
                  : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(bool canPop) {
    final isTv = context.watch<TvModeService?>()?.isTvMode ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.background, AppColors.backgroundLight],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Back button
              TvFocusable(
                onPressed: () {
                  if (canPop) {
                    Navigator.pop(context);
                  } else if (widget.onBackPressed != null) {
                    widget.onBackPressed!();
                  }
                },
                borderRadius: BorderRadius.circular(24),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),

              // Search field (otimizado - sem BackdropFilter)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: !isTv,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _submitSearch,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Search animes...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.primary,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Suggestions
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(suggestion),
                      labelStyle: const TextStyle(color: Colors.white),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                      onPressed: () => _selectSearchQuery(suggestion),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenreFilters() {
    final l10n = AppLocalizations.of(context);
    final genres = _getGenres();

    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: genres.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isAllSelected = _selectedGenre == null && !_filterDubbedOnly;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(l10n.allGenres),
                labelStyle: TextStyle(
                  color: isAllSelected ? Colors.white : Colors.white70,
                  fontWeight: isAllSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                selected: isAllSelected,
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                onSelected: (_) {
                  setState(() {
                    _filterDubbedOnly = false;
                    _selectedGenre = null;
                  });
                  _performSearch(_searchController.text);
                },
              ),
            );
          }

          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: const Text('🇧🇷', style: TextStyle(fontSize: 14)),
                label: const Text('Dublados (PT-BR)'),
                labelStyle: TextStyle(
                  color: _filterDubbedOnly ? Colors.white : Colors.white70,
                  fontWeight: _filterDubbedOnly
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                selected: _filterDubbedOnly,
                selectedColor: const Color(0xFF2E7D32),
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                onSelected: (selected) {
                  setState(() {
                    _filterDubbedOnly = selected;
                    if (selected) {
                      _selectedGenre = null;
                    }
                  });
                  _performSearch(_searchController.text);
                },
              ),
            );
          }

          final genre = genres[index - 2];
          final isSelected = _selectedGenre == genre['id'] && !_filterDubbedOnly;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                genre['icon'] as IconData,
                color: isSelected ? Colors.white : Colors.white70,
                size: 18,
              ),
              label: Text(genre['name'] as String),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              onSelected: (_) => _selectGenre(genre['id'] as int),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryAndTrending() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Recent Searches (with results)
        if (_recentSearchResults.isNotEmpty) ...[
          _buildSectionHeader('Recent Searches', Icons.history),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recentSearchResults.length,
              itemBuilder: (context, index) {
                return _buildAnimeCard(_recentSearchResults[index]);
              },
            ),
          ),
          const SizedBox(height: 32),
        ],

        // Search History
        if (_searchHistory.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('History', Icons.schedule),
              TextButton(
                onPressed: _clearHistory,
                child: const Text(
                  'Clear',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._searchHistory.take(8).map((query) {
            return ListTile(
              leading: const Icon(Icons.history, color: AppColors.primary),
              title: Text(query, style: const TextStyle(color: Colors.white)),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => _removeHistoryItem(query),
              ),
              onTap: () => _selectSearchQuery(query),
            );
          }),
          const SizedBox(height: 32),
        ],

        // Trending
        _buildSectionHeader('Trending Now', Icons.local_fire_department),
        const SizedBox(height: 16),
        if (_isLoadingTrending)
          const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Responsive.getGridColumns(context),
              childAspectRatio: 0.6,
              crossAxisSpacing: Responsive.getCardSpacing(context),
              mainAxisSpacing: Responsive.getCardSpacing(context),
            ),
            itemCount: _trendingAnimes.length,
            itemBuilder: (context, index) {
              return _buildGridAnimeCard(_trendingAnimes[index]);
            },
          ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_searchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 14),
              const Text(
                'Não foi possível concluir a busca.',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _performSearch(_searchController.text),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noResultsFound,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(Responsive.getHorizontalPadding(context)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.getGridColumns(context),
        childAspectRatio: 0.6,
        crossAxisSpacing: Responsive.getCardSpacing(context),
        mainAxisSpacing: Responsive.getCardSpacing(context),
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildGridAnimeCard(_searchResults[index]);
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimeCard(JikanAnime anime) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: TvFocusable(
        onPressed: () => _onAnimeTap(anime),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 130,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    _AnimeCover(
                      imageUrls: anime.availableCoverImageUrls,
                      width: 130,
                      height: 155,
                    ),
                    if (anime.score != null)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                anime.score!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (anime.title.toLowerCase().contains('dublado') ||
                        anime.genres.any((g) => g.name.toLowerCase().contains('dublado')))
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Text(
                            'DUB',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                anime.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridAnimeCard(JikanAnime anime) {
    return TvFocusable(
      onPressed: () => _onAnimeTap(anime),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  _AnimeCover(
                    imageUrls: anime.availableCoverImageUrls,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  if (anime.score != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 10,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              anime.score!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (anime.title.toLowerCase().contains('dublado') ||
                      anime.genres.any((g) => g.name.toLowerCase().contains('dublado')))
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Text(
                          'DUB',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            anime.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimeCover extends StatefulWidget {
  final List<String> imageUrls;
  final double width;
  final double height;

  const _AnimeCover({
    required this.imageUrls,
    required this.width,
    required this.height,
  });

  @override
  State<_AnimeCover> createState() => _AnimeCoverState();
}

class _AnimeCoverState extends State<_AnimeCover> {
  var _imageIndex = 0;

  @override
  void didUpdateWidget(covariant _AnimeCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls != widget.imageUrls) _imageIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_imageIndex >= widget.imageUrls.length) return _errorCover();
    return CachedNetworkImage(
      key: ValueKey(widget.imageUrls[_imageIndex]),
      imageUrl: widget.imageUrls[_imageIndex],
      width: widget.width,
      height: widget.height,
      fit: BoxFit.cover,
      memCacheWidth: widget.width.isFinite ? (widget.width * 2).round() : null,
      placeholder: (_, _) => Container(
        color: AppColors.surface,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      errorWidget: (_, _, _) {
        if (_imageIndex + 1 < widget.imageUrls.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _imageIndex++);
          });
          return Container(color: AppColors.surface);
        }
        return _errorCover();
      },
    );
  }

  Widget _errorCover() => Container(
    width: widget.width,
    height: widget.height,
    color: AppColors.surface,
    child: const Icon(
      Icons.image_not_supported_outlined,
      color: Colors.white54,
    ),
  );
}
