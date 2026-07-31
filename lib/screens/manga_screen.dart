import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/manga_service.dart';
import '../theme/app_colors.dart';
import 'manga_reader_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MangaScreen – search + grid
// ─────────────────────────────────────────────────────────────────────────────
class MangaScreen extends StatefulWidget {
  const MangaScreen({super.key});

  @override
  State<MangaScreen> createState() => _MangaScreenState();
}

class _MangaScreenState extends State<MangaScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  late Future<List<MangaTitle>> _resultsFuture;
  late AnimationController _animationController;
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _focusNode.addListener(() {
      setState(() => _searchFocused = _focusNode.hasFocus);
    });
    _resultsFuture = context.read<MangaService>().search('one piece');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _search() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    _focusNode.unfocus();
    setState(() {
      _resultsFuture = context.read<MangaService>().search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: AppColors.getPrimaryGradient(),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.menu_book_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Mangás',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.background,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Search Bar ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _searchFocused
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.08),
                    width: _searchFocused ? 1.5 : 1,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.surface.withValues(alpha: 0.9),
                      AppColors.surfaceLight.withValues(alpha: 0.7),
                    ],
                  ),
                  boxShadow: _searchFocused
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Pesquisar mangás...',
                    hintStyle: const TextStyle(
                        color: AppColors.textTertiary, fontSize: 15),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.textSecondary),
                    suffixIcon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _searchController.text.isNotEmpty
                          ? Row(
                              key: const ValueKey('btns'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.clear_rounded,
                                      color: AppColors.textSecondary, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                ),
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.getPrimaryGradient(),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: GestureDetector(
                                    onTap: _search,
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.search_rounded,
                                            color: Colors.white, size: 16),
                                        SizedBox(width: 4),
                                        Text('Buscar',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Icon(
                              key: ValueKey('empty'),
                              Icons.arrow_forward_rounded,
                              color: AppColors.textTertiary,
                            ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          ),

          // ── Results Grid ─────────────────────────────────────────────────
          FutureBuilderSliver(future: _resultsFuture),
        ],
      ),
    );
  }
}

class FutureBuilderSliver extends StatelessWidget {
  final Future<List<MangaTitle>> future;

  const FutureBuilderSliver({super.key, required this.future});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SliverFillRemaining(
      child: FutureBuilder<List<MangaTitle>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _MangaGridShimmer();
          }
          if (snapshot.hasError) {
            return _MangaMessage(
              icon: Icons.error_outline_rounded,
              title: l10n.error,
              message: snapshot.error.toString(),
            );
          }
          final results = snapshot.data ?? const [];
          if (results.isEmpty) {
            return _MangaMessage(
              icon: Icons.menu_book_outlined,
              title: l10n.noResultsFound,
              message: l10n.tryDifferentKeywords,
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: 14,
              crossAxisSpacing: 12,
              childAspectRatio: 0.58,
            ),
            itemCount: results.length,
            itemBuilder: (context, index) {
              return _MangaCard(manga: results[index]);
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MangaCard – premium cover card with gradient overlay
// ─────────────────────────────────────────────────────────────────────────────
class _MangaCard extends StatefulWidget {
  final MangaTitle manga;
  const _MangaCard({required this.manga});

  @override
  State<_MangaCard> createState() => _MangaCardState();
}

class _MangaCardState extends State<_MangaCard> {
  bool _hovered = false;

  Color _statusColor(String status) {
    return switch (status.toLowerCase()) {
      'ongoing' => const Color(0xFF4CAF50),
      'completed' => const Color(0xFF2196F3),
      'hiatus' => const Color(0xFFFFC107),
      'cancelled' => const Color(0xFFF44336),
      _ => AppColors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(widget.manga.status);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, animation, _) => FadeTransition(
              opacity: animation,
              child: MangaDetailsScreen(manga: widget.manga),
            ),
            transitionDuration: const Duration(milliseconds: 350),
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Cover image
                widget.manga.coverUrl == null
                    ? Container(
                        color: AppColors.surface,
                        child: const Icon(Icons.menu_book,
                            color: AppColors.textSecondary, size: 42),
                      )
                    : CachedNetworkImage(
                        imageUrl: widget.manga.coverUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: AppColors.surface,
                          child: const Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary),
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: AppColors.surface,
                          child: const Icon(Icons.broken_image,
                              color: AppColors.textSecondary),
                        ),
                      ),

                // Gradient overlay bottom
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.45, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),
                ),

                // Status badge top-left
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: color.withValues(alpha: 0.6), width: 0.8),
                    ),
                    child: Text(
                      widget.manga.status.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                // Hover glow overlay
                if (_hovered)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                // Title bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.manga.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            shadows: [
                              Shadow(blurRadius: 6, color: Colors.black),
                            ],
                          ),
                        ),
                        if (widget.manga.tags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.manga.tags.take(2).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// MangaDetailsScreen – details + chapters
// ─────────────────────────────────────────────────────────────────────────────
class MangaDetailsScreen extends StatefulWidget {
  final MangaTitle manga;
  const MangaDetailsScreen({super.key, required this.manga});

  @override
  State<MangaDetailsScreen> createState() => _MangaDetailsScreenState();
}

class _MangaDetailsScreenState extends State<MangaDetailsScreen> {
  late Future<List<MangaChapter>> _chaptersFuture;
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    _chaptersFuture = _loadChapters();
  }

  Future<List<MangaChapter>> _loadChapters() {
    return context.read<MangaService>().getChapters(
          widget.manga.id,
          language: _language,
        );
  }

  void _changeLanguage(String language) {
    setState(() {
      _language = language;
      _chaptersFuture = _loadChapters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<MangaService>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<List<MangaChapter>>(
        future: _chaptersFuture,
        builder: (context, snapshot) {
          final chapters = snapshot.data ?? const <MangaChapter>[];

          return CustomScrollView(
            slivers: [
              // ── Collapsible cover header ─────────────────────────────────
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: _MangaHeroHeader(manga: widget.manga),
                  collapseMode: CollapseMode.parallax,
                ),
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: BackButton(color: Colors.white, onPressed: () => Navigator.pop(context)),
                ),
              ),

              // ── Info card ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _MangaInfoCard(
                  manga: widget.manga,
                  selectedLanguage: _language,
                  onLanguageChanged: _changeLanguage,
                  onReadFirst: chapters.isNotEmpty
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MangaReaderScreen(
                                manga: widget.manga,
                                chapter: chapters.first,
                                service: service,
                              ),
                            ),
                          )
                      : null,
                ),
              ),

              // ── Chapter header ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: AppColors.getPrimaryGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Capítulos',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (snapshot.data != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${chapters.length}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Chapters list ─────────────────────────────────────────────
              if (snapshot.connectionState != ConnectionState.done)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(
                  child: _MangaMessage(
                    icon: Icons.error_outline_rounded,
                    title: l10n.error,
                    message: snapshot.error.toString(),
                  ),
                )
              else if (chapters.isEmpty)
                SliverFillRemaining(
                  child: _MangaMessage(
                    icon: Icons.menu_book_outlined,
                    title: 'Nenhum capítulo encontrado',
                    message: l10n.tryDifferentKeywords,
                  ),
                )
              else
                SliverList.separated(
                  itemCount: chapters.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.04),
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    final progress = service.progress[chapter.id];
                    return _ChapterTile(
                      manga: widget.manga,
                      chapter: chapter,
                      progress: progress,
                      index: index,
                    );
                  },
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MangaHeroHeader – full blurred banner background
// ─────────────────────────────────────────────────────────────────────────────
class _MangaHeroHeader extends StatelessWidget {
  final MangaTitle manga;
  const _MangaHeroHeader({required this.manga});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred background
        if (manga.coverUrl != null)
          CachedNetworkImage(
            imageUrl: manga.coverUrl!,
            fit: BoxFit.cover,
          ),
        // Blur layer
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
        // Bottom gradient fade
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.4, 1.0],
                colors: [
                  Colors.transparent,
                  AppColors.background,
                ],
              ),
            ),
          ),
        ),
        // Centered cover + title
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Cover
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 110,
                    height: 165,
                    child: manga.coverUrl == null
                        ? Container(
                            color: AppColors.surface,
                            child: const Icon(Icons.menu_book, size: 42),
                          )
                        : CachedNetworkImage(
                            imageUrl: manga.coverUrl!,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Title + tags
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(blurRadius: 8, color: Colors.black),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (manga.tags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: manga.tags
                            .take(4)
                            .map((tag) => _TagChip(tag: tag))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MangaInfoCard – description + language + action button
// ─────────────────────────────────────────────────────────────────────────────
class _MangaInfoCard extends StatefulWidget {
  final MangaTitle manga;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback? onReadFirst;

  const _MangaInfoCard({
    required this.manga,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.onReadFirst,
  });

  @override
  State<_MangaInfoCard> createState() => _MangaInfoCardState();
}

class _MangaInfoCardState extends State<_MangaInfoCard> {
  bool _expanded = false;

  Color _statusColor(String status) {
    return switch (status.toLowerCase()) {
      'ongoing' => const Color(0xFF4CAF50),
      'completed' => const Color(0xFF2196F3),
      'hiatus' => const Color(0xFFFFC107),
      'cancelled' => const Color(0xFFF44336),
      _ => AppColors.textSecondary,
    };
  }

  String _statusLabel(String status) {
    return switch (status.toLowerCase()) {
      'ongoing' => 'Em andamento',
      'completed' => 'Completo',
      'hiatus' => 'Em pausa',
      'cancelled' => 'Cancelado',
      _ => status,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(widget.manga.status);
    final hasDescription = widget.manga.description.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _statusLabel(widget.manga.status),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Language selector
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('EN', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 'pt-br', label: Text('PT-BR', style: TextStyle(fontSize: 11))),
                ],
                selected: {widget.selectedLanguage},
                onSelectionChanged: (v) => widget.onLanguageChanged(v.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.primary.withValues(alpha: 0.3);
                    }
                    return AppColors.surface;
                  }),
                  side: WidgetStateProperty.all(
                    BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ],
          ),

          // Description (if any)
          if (hasDescription) ...[
            const SizedBox(height: 14),
            AnimatedCrossFade(
              firstChild: Text(
                widget.manga.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              secondChild: Text(
                widget.manga.description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _expanded ? 'Ver menos' : 'Ver mais',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Read button
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onReadFirst,
              icon: const Icon(Icons.chrome_reader_mode_rounded, size: 18),
              label: const Text('Ler Capítulo 1'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.surface,
                disabledForegroundColor: AppColors.textTertiary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChapterTile – premium tile with index, date and download
// ─────────────────────────────────────────────────────────────────────────────
class _ChapterTile extends StatefulWidget {
  final MangaTitle manga;
  final MangaChapter chapter;
  final MangaDownloadProgress? progress;
  final int index;

  const _ChapterTile({
    required this.manga,
    required this.chapter,
    required this.progress,
    required this.index,
  });

  @override
  State<_ChapterTile> createState() => _ChapterTileState();
}

class _ChapterTileState extends State<_ChapterTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final service = context.read<MangaService>();
    final hasProgress = widget.progress != null;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MangaReaderScreen(
              manga: widget.manga,
              chapter: widget.chapter,
              service: service,
            ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _pressed
            ? AppColors.surfaceHover.withValues(alpha: 0.5)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Chapter number badge
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: hasProgress
                        ? null
                        : LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.2),
                              AppColors.primaryDark.withValues(alpha: 0.1),
                            ],
                          ),
                    color: hasProgress ? AppColors.surface : null,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasProgress
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: hasProgress
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            value: widget.progress!.progress,
                            strokeWidth: 2.5,
                            color: AppColors.primary,
                          ),
                        )
                      : Text(
                          widget.chapter.chapter.isEmpty
                              ? '${widget.index + 1}'
                              : widget.chapter.chapter,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                // Chapter info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.chapter.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.language_rounded,
                            size: 11,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            widget.chapter.language.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                          if (widget.chapter.publishedAt != null) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.calendar_today_rounded,
                                size: 11, color: AppColors.textTertiary),
                            const SizedBox(width: 3),
                            Text(
                              _formatDate(widget.chapter.publishedAt!),
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Download button
                _DownloadButton(
                  isDownloading: hasProgress,
                  onTap: hasProgress
                      ? null
                      : () => _download(context, service),
                ),
              ],
            ),
            // Download progress bar
            if (hasProgress) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.progress!.progress,
                  backgroundColor: AppColors.surface,
                  color: AppColors.primary,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.progress!.completed} / ${widget.progress!.total} páginas',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  Future<void> _download(BuildContext context, MangaService service) async {
    try {
      final item = await service.downloadChapter(
          manga: widget.manga, chapter: widget.chapter);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download concluído: ${item.chapterTitle}'),
          action: SnackBarAction(
            label: 'Ler',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MangaReaderScreen(
                  manga: widget.manga,
                  chapter: widget.chapter,
                  service: service,
                  localDirectory: item.directoryPath,
                ),
              ),
            ),
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _DownloadButton extends StatefulWidget {
  final bool isDownloading;
  final VoidCallback? onTap;

  const _DownloadButton({required this.isDownloading, required this.onTap});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hovered && !widget.isDownloading
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered && !widget.isDownloading
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: widget.isDownloading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                )
              : Icon(
                  Icons.download_rounded,
                  size: 18,
                  color: _hovered
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _MangaGridShimmer extends StatelessWidget {
  const _MangaGridShimmer();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 0.58,
      ),
      itemCount: 12,
      itemBuilder: (_, _) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _MangaMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MangaMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.textSecondary, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}
