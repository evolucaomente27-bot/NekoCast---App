import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../main.dart' show Episode, Anime, AnimeService;
import '../services/watch_history_service.dart';
import 'video_player_screen.dart';
import 'episode_list_screen.dart';
import '../l10n/app_localizations.dart';
import '../models/jikan_models.dart';
import '../services/jikan_service.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/brand_logo.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/tv_focusable.dart';
import 'genre_animes_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'source_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final JikanService _jikanService = JikanService();
  final ScrollController _scrollController = ScrollController();

  late final AnimationController _fabAnimationController;
  late final PageController _bannerPageController;
  Timer? _bannerRotationTimer;

  bool _showFab = false;
  double _headerOpacity = 0.0;
  bool _isLoading = true;

  List<JikanAnime> _seasonAnimes = [];
  List<JikanAnime> _topAnimes = [];
  List<JikanAnime> _actionAnimes = [];
  List<JikanAnime> _romanceAnimes = [];
  List<JikanAnime> _comedyAnimes = [];
  List<JikanAnime> _fantasyAnimes = [];
  List<Anime> _dubbedAnimes = [];

  int _currentBannerIndex = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bannerPageController = PageController();
    _scrollController.addListener(_onScroll);
    _loadAllData();
    _startBannerRotation();
  }

  @override
  void dispose() {
    _bannerRotationTimer?.cancel();
    _fabAnimationController.dispose();
    _bannerPageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final shouldShowFab = offset > 280;
    final nextOpacity = (offset / 120).clamp(0.0, 1.0);

    if (shouldShowFab != _showFab) {
      setState(() => _showFab = shouldShowFab);
      shouldShowFab
          ? _fabAnimationController.forward()
          : _fabAnimationController.reverse();
    }

    if ((nextOpacity - _headerOpacity).abs() > 0.01) {
      setState(() => _headerOpacity = nextOpacity);
    }
  }

  void _startBannerRotation() {
    _bannerRotationTimer?.cancel();
    _bannerRotationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_bannerPageController.hasClients) {
        return;
      }

      final bannerCount = _seasonAnimes.length > 5 ? 5 : _seasonAnimes.length;
      if (bannerCount < 2) {
        return;
      }

      final nextIndex = (_currentBannerIndex + 1) % bannerCount;
      _bannerPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadAllData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);

    try {
      final homeDataFuture = _jikanService.loadHomeData(
        forceRefresh: forceRefresh,
      );
      final dubbedAnimesFuture = AnimeService.getDubbedAnimes();

      final homeData = await homeDataFuture;
      final dubbedAnimes = await dubbedAnimesFuture;

      if (!mounted) {
        return;
      }

      setState(() {
        _seasonAnimes = homeData.seasonAnimes;
        _topAnimes = homeData.topAnimes;
        _actionAnimes = homeData.actionAnimes;
        _romanceAnimes = homeData.romanceAnimes;
        _comedyAnimes = homeData.comedyAnimes;
        _fantasyAnimes = homeData.fantasyAnimes;
        _dubbedAnimes = dubbedAnimes;
        _isLoading = false;
        if (_currentBannerIndex >= _seasonAnimes.length &&
            _seasonAnimes.isNotEmpty) {
          _currentBannerIndex = 0;
        }
      });

      _precacheBannerImages();
    } catch (e) {
      debugPrint('Error loading home data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _precacheBannerImages() {
    for (final anime in _seasonAnimes.take(5)) {
      final imageUrl = anime.largImageUrl ?? anime.imageUrl;
      if (imageUrl.isNotEmpty && mounted) {
        precacheImage(CachedNetworkImageProvider(imageUrl), context).catchError(
          (e) {
            debugPrint('[HomeScreen] Banner image precache silent catch: $e');
          },
        );
      }
    }
  }

  void _onAnimeTap(JikanAnime anime) {
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
    super.build(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () => _loadAllData(forceRefresh: true),
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 96),
                  if (_seasonAnimes.isNotEmpty)
                    _buildHeroBannerCarousel()
                  else if (_isLoading)
                    _buildBannerLoadingState()
                  else
                    _buildBannerEmptyState(l10n),
                  _buildContinueWatchingSection(),
                  const SizedBox(height: 8),
                  if (_dubbedAnimes.isNotEmpty || _isLoading)
                    _buildDubbedSection(),
                  _buildModernSection(
                    title: l10n.seasonHighlights,
                    icon: Ionicons.sparkles_outline,
                    gradient: AppColors.getHeroGradient(),
                    animes: _seasonAnimes,
                    isLoading: _isLoading && _seasonAnimes.isEmpty,
                    sectionId: 'season',
                  ),
                  _buildModernSection(
                    title: l10n.topAnime,
                    icon: LucideIcons.trophy,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF3C96A), Color(0xFFE67B2D)],
                    ),
                    animes: _topAnimes,
                    isLoading: _isLoading && _topAnimes.isEmpty,
                    sectionId: 'top',
                  ),
                  _buildModernSection(
                    title: l10n.action,
                    icon: LucideIcons.swords,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFBF5D2F), Color(0xFF7B3020)],
                    ),
                    animes: _actionAnimes,
                    isLoading: _isLoading && _actionAnimes.isEmpty,
                    sectionId: 'action',
                    genreId: JikanGenreIds.action,
                  ),
                  _buildModernSection(
                    title: l10n.romance,
                    icon: LucideIcons.heart,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD8705B), Color(0xFFA94846)],
                    ),
                    animes: _romanceAnimes,
                    isLoading: _isLoading && _romanceAnimes.isEmpty,
                    sectionId: 'romance',
                    genreId: JikanGenreIds.romance,
                  ),
                  _buildModernSection(
                    title: l10n.comedy,
                    icon: LucideIcons.laugh,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF0A84B), Color(0xFFD3762E)],
                    ),
                    animes: _comedyAnimes,
                    isLoading: _isLoading && _comedyAnimes.isEmpty,
                    sectionId: 'comedy',
                    genreId: JikanGenreIds.comedy,
                  ),
                  _buildModernSection(
                    title: l10n.fantasy,
                    icon: LucideIcons.wand2,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA56A43), Color(0xFF6D4328)],
                    ),
                    animes: _fantasyAnimes,
                    isLoading: _isLoading && _fantasyAnimes.isEmpty,
                    sectionId: 'fantasy',
                    genreId: JikanGenreIds.fantasy,
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _showFab
          ? ScaleTransition(
              scale: _fabAnimationController,
              child: FloatingActionButton(
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                  );
                },
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                child: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background.withValues(
        alpha: 0.78 * _headerOpacity,
      ),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 72,
      titleSpacing: 16,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(height: 34),
            const SizedBox(width: 8),
            const Text(
              'NekoCast',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      centerTitle: false,
      actions: [
        _buildHeaderAction(
          icon: Icons.search_rounded,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            );
          },
        ),
        const SizedBox(width: 8),
        _buildHeaderAction(
          icon: Icons.settings_outlined,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
        const SizedBox(width: 14),
      ],
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TvFocusable(
        onPressed: onPressed,
        focusScale: 1.1,
        borderRadius: BorderRadius.circular(14),
        showFocusBorder: true,
        showFocusGlow: true,
        builder: (context, hasFocus, isHovered) {
          return Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hasFocus
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : AppColors.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasFocus ? AppColors.primary : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Icon(
              icon,
              color: hasFocus ? AppColors.primaryLight : AppColors.textPrimary,
              size: 22,
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroBannerCarousel() {
    final bannerAnimes = _seasonAnimes.take(5).toList();
    final bannerHeight = Responsive.getBannerHeight(context);
    final padding = Responsive.getHorizontalPadding(context);

    return Container(
      height: bannerHeight,
      margin: const EdgeInsets.only(bottom: 20),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  Responsive.value(context, phone: 24.0, tablet: 28.0),
                ),
                child: PageView.builder(
                  controller: _bannerPageController,
                  itemCount: bannerAnimes.length,
                  onPageChanged: (index) {
                    setState(() => _currentBannerIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return _BannerCard(
                      anime: bannerAnimes[index],
                      onTap: () => _onAnimeTap(bannerAnimes[index]),
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                bannerAnimes.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: _currentBannerIndex == index ? 20 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _currentBannerIndex == index
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerLoadingState() {
    final padding = Responsive.getHorizontalPadding(context);
    final bannerHeight = Responsive.getBannerHeight(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Container(
        height: bannerHeight,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildBannerEmptyState(AppLocalizations l10n) {
    final padding = Responsive.getHorizontalPadding(context);
    final bannerHeight = Responsive.getBannerHeight(context) * 0.72;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Container(
        height: bannerHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.surfaceLight, AppColors.surface],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BrandLogo(height: 86),
            const SizedBox(height: 18),
            Text(
              l10n.noAnimeFound,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Puxe para atualizar e carregar os destaques do catálogo.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueWatchingSection() {
    return Consumer<WatchHistoryService>(
      builder: (context, historyService, _) {
        final items = historyService.items;
        if (items.isEmpty) return const SizedBox.shrink();

        final horizontalPadding = Responsive.getHorizontalPadding(context);

        return Container(
          margin: const EdgeInsets.only(bottom: 24, top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF9F1C)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Continuar Assistindo',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final progress = item.progress;

                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: TvFocusable(
                        focusScale: 1.05,
                        borderRadius: BorderRadius.circular(14),
                        showFocusBorder: true,
                        showFocusGlow: true,
                        onPressed: () {
                          final episode = Episode(
                            number: item.episodeNumber,
                            title: item.episodeTitle.isNotEmpty
                                ? item.episodeTitle
                                : 'Episódio ${item.episodeNumber}',
                            url: item.episodeUrl,
                          );

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ModernVideoPlayerScreen(
                                episode: episode,
                                animeTitle: item.animeTitle,
                                anime: Anime(
                                  name: item.animeTitle,
                                  url: item.animeSourceUrl ?? item.episodeUrl,
                                  fallbackImageUrl: item.animeImageUrl,
                                ),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 220,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cover with play icon and progress
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(14),
                                      ),
                                      child: item.animeImageUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: item.animeImageUrl,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, _, _) =>
                                                  const Icon(Icons.movie,
                                                      color: Colors.white24),
                                            )
                                          : const Icon(Icons.movie,
                                              color: Colors.white24),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.7),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white70,
                                            width: 1,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: AppColors.accent,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: LinearProgressIndicator(
                                        value: progress > 0 ? progress : 0.05,
                                        minHeight: 4,
                                        backgroundColor: Colors.white24,
                                        valueColor: const AlwaysStoppedAnimation(
                                          AppColors.accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.animeTitle,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Episódio ${item.episodeNumber}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernSection({
    required String title,
    required IconData icon,
    required Gradient gradient,
    required List<JikanAnime> animes,
    required bool isLoading,
    String? sectionId,
    int? genreId,
  }) {
    final l10n = AppLocalizations.of(context);
    final horizontalPadding = Responsive.getHorizontalPadding(context);
    final sectionHeight = Responsive.getSectionHeight(context);
    final titleSize = Responsive.getSectionTitleSize(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(
                    Responsive.value(context, phone: 9.0, tablet: 11.0),
                  ),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: Responsive.value(context, phone: 18.0, tablet: 21.0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                TvFocusable(
                  focusScale: 1.08,
                  borderRadius: BorderRadius.circular(18),
                  showFocusBorder: true,
                  showFocusGlow: true,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GenreAnimesScreen(
                          title: title,
                          icon: icon,
                          gradient: gradient,
                          genreId: genreId,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.seeAll,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: sectionHeight,
            child: isLoading
                ? _buildLoadingCards()
                : animes.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    itemCount: animes.length,
                    cacheExtent: 500,
                    itemBuilder: (context, index) {
                      return _HomeAnimeCard(
                        anime: animes[index],
                        heroTag:
                            'home_${sectionId ?? title}_${animes[index].malId}_$index',
                        onTap: () => _onAnimeTap(animes[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCards() {
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeight(context);
    final spacing = Responsive.getCardSpacing(context);
    final padding = Responsive.getHorizontalPadding(context);

    return ShimmerAnimeList(
      itemWidth: cardWidth,
      itemHeight: cardHeight,
      spacing: spacing,
      padding: EdgeInsets.symmetric(horizontal: padding),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Text(
        l10n.noAnimeFound,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildDubbedSection() {
    final horizontalPadding = Responsive.getHorizontalPadding(context);
    final sectionHeight = Responsive.getSectionHeight(context);
    final titleSize = Responsive.getSectionTitleSize(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(
                    Responsive.value(context, phone: 9.0, tablet: 11.0),
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C853), Color(0xFF1B5E20)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '🇧🇷',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Animes Dublados',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Em português do Brasil (PT-BR)',
                        style: TextStyle(
                          color: Color(0xFF69F0AE),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                TvFocusable(
                  focusScale: 1.08,
                  borderRadius: BorderRadius.circular(18),
                  showFocusBorder: true,
                  showFocusGlow: true,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SearchScreen(
                          initialFilterDubbed: true,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF00C853).withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ver todos',
                          style: TextStyle(
                            color: Color(0xFF00E676),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Color(0xFF00E676),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: sectionHeight,
            child: _isLoading && _dubbedAnimes.isEmpty
                ? _buildLoadingCards()
                : _dubbedAnimes.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    itemCount: _dubbedAnimes.length,
                    cacheExtent: 500,
                    itemBuilder: (context, index) {
                      final anime = _dubbedAnimes[index];
                      return _DubbedAnimeCard(
                        anime: anime,
                        heroTag: 'home_dubbed_${anime.url}_$index',
                        onTap: () => _onDubbedAnimeTap(anime),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _onDubbedAnimeTap(Anime anime) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModernEpisodeListScreen(
          anime: anime,
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final JikanAnime anime;
  final VoidCallback onTap;

  const _BannerCard({required this.anime, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onPressed: onTap,
      focusScale: 1.02,
      borderRadius: BorderRadius.circular(24),
      showFocusBorder: true,
      showFocusGlow: true,
      borderWidth: 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: anime.largImageUrl ?? anime.imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: AppColors.surface,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: AppColors.surface,
              child: const Icon(Icons.error, color: Colors.white54),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.18),
                  Colors.black.withValues(alpha: 0.68),
                ],
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: const Text(
                'NekoCast Picks',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  anime.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (anime.score != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Score ${anime.score!.toStringAsFixed(1)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.getPrimaryGradient(),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Assistir agora',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAnimeCard extends StatelessWidget {
  final JikanAnime anime;
  final String heroTag;
  final VoidCallback onTap;

  const _HomeAnimeCard({
    required this.anime,
    required this.heroTag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeight(context);
    final spacing = Responsive.getCardSpacing(context);

    return TvFocusable(
      onPressed: onTap,
      focusScale: 1.07,
      borderRadius: BorderRadius.circular(18),
      showFocusBorder: false,
      showFocusGlow: false,
      builder: (context, hasFocus, isHovered) {
        final isHighlighted = hasFocus || isHovered;

        return RepaintBoundary(
          child: Container(
            width: cardWidth,
            margin: EdgeInsets.only(right: spacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: heroTag,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: cardHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: hasFocus ? AppColors.primary : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: hasFocus
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : (isHovered
                                  ? AppColors.primary.withValues(alpha: 0.22)
                                  : Colors.black.withValues(alpha: 0.28)),
                          blurRadius: hasFocus ? 20 : (isHovered ? 18 : 10),
                          spreadRadius: hasFocus ? 2 : 0,
                          offset: Offset(0, isHighlighted ? 8 : 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: anime.largImageUrl ?? anime.imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: (cardWidth * 2).toInt(),
                            memCacheHeight: (cardHeight * 2).toInt(),
                            placeholder: (context, url) => Container(
                              color: AppColors.surface,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.surface,
                              child: const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.74),
                                ],
                                stops: const [0.55, 1.0],
                              ),
                            ),
                          ),
                          if (anime.score != null)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.14),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      color: Colors.amber,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      anime.score!.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Row(
                              children: [
                                if (anime.episodes != null)
                                  Expanded(
                                    child: Text(
                                      '${anime.episodes} eps',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: hasFocus ? AppColors.primary : Colors.white,
                                  size: hasFocus ? 22 : 18,
                                ),
                              ],
                            ),
                          ),
                          if (isHighlighted)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.45,
                                    ),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  anime.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasFocus ? AppColors.primaryLight : AppColors.textPrimary,
                    fontSize: Responsive.value(
                      context,
                      phone: 13.0,
                      tablet: 14.0,
                    ),
                    fontWeight: FontWeight.w700,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DubbedAnimeCard extends StatelessWidget {
  final Anime anime;
  final String heroTag;
  final VoidCallback onTap;

  const _DubbedAnimeCard({
    required this.anime,
    required this.heroTag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeight(context);
    final spacing = Responsive.getCardSpacing(context);

    return TvFocusable(
      onPressed: onTap,
      focusScale: 1.07,
      borderRadius: BorderRadius.circular(18),
      showFocusBorder: false,
      showFocusGlow: false,
      builder: (context, hasFocus, isHovered) {
        final isHighlighted = hasFocus || isHovered;

        return RepaintBoundary(
          child: Container(
            width: cardWidth,
            margin: EdgeInsets.only(right: spacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: heroTag,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: cardHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: hasFocus ? const Color(0xFF00E676) : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: hasFocus
                              ? const Color(0xFF00C853).withValues(alpha: 0.5)
                              : (isHovered
                                  ? const Color(0xFF00C853).withValues(alpha: 0.22)
                                  : Colors.black.withValues(alpha: 0.28)),
                          blurRadius: hasFocus ? 20 : (isHovered ? 18 : 10),
                          spreadRadius: hasFocus ? 2 : 0,
                          offset: Offset(0, isHighlighted ? 8 : 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (anime.imageUrl.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: anime.imageUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: (cardWidth * 2).toInt(),
                              memCacheHeight: (cardHeight * 2).toInt(),
                              placeholder: (context, url) => Container(
                                color: AppColors.surface,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF00C853),
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.surface,
                                child: const Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.white54,
                                ),
                              ),
                            )
                          else
                            Container(
                              color: AppColors.surface,
                              child: const Icon(
                                Icons.movie_outlined,
                                color: Colors.white54,
                              ),
                            ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.74),
                                ],
                                stops: const [0.55, 1.0],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C853),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('🇧🇷', style: TextStyle(fontSize: 10)),
                                  SizedBox(width: 4),
                                  Text(
                                    'DUB',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Dublado PT-BR',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Color(0xFFB9F6CA),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: hasFocus ? const Color(0xFF00E676) : Colors.white,
                                  size: hasFocus ? 22 : 18,
                                ),
                              ],
                            ),
                          ),
                          if (isHighlighted)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C853).withValues(
                                    alpha: 0.08,
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFF00C853).withValues(
                                      alpha: 0.45,
                                    ),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  anime.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasFocus ? const Color(0xFF69F0AE) : AppColors.textPrimary,
                    fontSize: Responsive.value(
                      context,
                      phone: 13.0,
                      tablet: 14.0,
                    ),
                    fontWeight: FontWeight.w700,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


