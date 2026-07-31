import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../models/jikan_models.dart';
import '../services/jikan_service.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/brand_logo.dart';
import '../widgets/shimmer_loading.dart';
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
      final homeData = await _jikanService.loadHomeData(
        forceRefresh: forceRefresh,
      );

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
      if (imageUrl.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(imageUrl), context);
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
                  const SizedBox(height: 8),
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
    return Container(
      width: 44,
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.textPrimary, size: 22),
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
              'Puxe para atualizar e carregar os destaques do catalogo.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
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
}

class _BannerCard extends StatelessWidget {
  final JikanAnime anime;
  final VoidCallback onTap;

  const _BannerCard({required this.anime, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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

class _HomeAnimeCard extends StatefulWidget {
  final JikanAnime anime;
  final String heroTag;
  final VoidCallback onTap;

  const _HomeAnimeCard({
    required this.anime,
    required this.heroTag,
    required this.onTap,
  });

  @override
  State<_HomeAnimeCard> createState() => _HomeAnimeCardState();
}

class _HomeAnimeCardState extends State<_HomeAnimeCard> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeight(context);
    final spacing = Responsive.getCardSpacing(context);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: cardWidth,
            margin: EdgeInsets.only(right: spacing),
            transform: Matrix4.diagonal3Values(
              _isPressed ? 0.97 : (_isHovered ? 1.02 : 1.0),
              _isPressed ? 0.97 : (_isHovered ? 1.02 : 1.0),
              1.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: widget.heroTag,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: cardHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: _isHovered
                              ? AppColors.primary.withValues(alpha: 0.22)
                              : Colors.black.withValues(alpha: 0.28),
                          blurRadius: _isHovered ? 18 : 10,
                          offset: Offset(0, _isHovered ? 8 : 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl:
                                widget.anime.largImageUrl ??
                                widget.anime.imageUrl,
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
                          if (widget.anime.score != null)
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
                                      widget.anime.score!.toStringAsFixed(1),
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
                                if (widget.anime.episodes != null)
                                  Expanded(
                                    child: Text(
                                      '${widget.anime.episodes} eps',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                const Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                          if (_isHovered)
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
                                  borderRadius: BorderRadius.circular(18),
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
                  widget.anime.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
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
        ),
      ),
    );
  }
}
