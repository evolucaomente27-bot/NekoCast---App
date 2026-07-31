import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/manga_service.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reading mode enum
// ─────────────────────────────────────────────────────────────────────────────
enum _ReadingMode { vertical, horizontal }

// ─────────────────────────────────────────────────────────────────────────────
// MangaReaderScreen
// ─────────────────────────────────────────────────────────────────────────────
class MangaReaderScreen extends StatefulWidget {
  final MangaTitle manga;
  final MangaChapter chapter;
  final MangaService service;
  final String? localDirectory;

  const MangaReaderScreen({
    super.key,
    required this.manga,
    required this.chapter,
    required this.service,
    this.localDirectory,
  });

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen> {
  late Future<List<String>> _pagesFuture;
  _ReadingMode _mode = _ReadingMode.vertical;
  bool _fitWidth = true;
  bool _barsVisible = true;
  int _currentPage = 0;

  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pagesFuture = _loadPages();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<List<String>> _loadPages() async {
    if (widget.localDirectory != null) {
      final directory = Directory(widget.localDirectory!);
      final files = await directory
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      files.sort((a, b) => a.path.compareTo(b.path));
      return files.map((file) => file.path).toList();
    }
    final pages = await widget.service.getChapterPages(widget.chapter.id);
    return pages.pageUrls;
  }

  void _toggleBars() => setState(() => _barsVisible = !_barsVisible);

  Widget _buildImage(String page, {BoxFit? fit}) {
    final effectiveFit = fit ?? (_fitWidth ? BoxFit.fitWidth : BoxFit.contain);
    if (page.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: page,
        fit: effectiveFit,
        placeholder: (_, _) => const _PagePlaceholder(),
        errorWidget: (_, _, _) => const _PageError(),
      );
    }
    return Image.file(File(page), fit: effectiveFit);
  }

  void _switchMode(List<String> pages) {
    setState(() {
      if (_mode == _ReadingMode.vertical) {
        _mode = _ReadingMode.horizontal;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_currentPage);
          }
        });
      } else {
        _mode = _ReadingMode.vertical;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<List<String>>(
        future: _pagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _ReaderLoading();
          }
          if (snapshot.hasError) {
            return _ReaderError(
              message: snapshot.error.toString(),
              onRetry: () => setState(() => _pagesFuture = _loadPages()),
            );
          }
          final pages = snapshot.data ?? const [];
          if (pages.isEmpty) {
            return const _ReaderError(
              message: 'Nenhuma página encontrada para este capítulo.',
            );
          }
          return _buildReaderStack(pages);
        },
      ),
    );
  }

  Widget _buildReaderStack(List<String> pages) {
    return Stack(
      children: [
        // ── Page content ──────────────────────────────────────────────────
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleBars,
          child: _mode == _ReadingMode.vertical
              ? ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  itemCount: pages.length,
                  itemBuilder: (_, i) => InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    child: SizedBox(
                      width: double.infinity,
                      child: _buildImage(pages[i]),
                    ),
                  ),
                )
              : PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: pages.length,
                  itemBuilder: (_, i) => InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    child: Center(child: _buildImage(pages[i], fit: BoxFit.contain)),
                  ),
                ),
        ),

        // ── Top AppBar ────────────────────────────────────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: _barsVisible ? 0 : -130,
          left: 0,
          right: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.88),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 8, 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.manga.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                widget.chapter.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Fit width toggle
                        _TopBarButton(
                          icon: _fitWidth
                              ? Icons.fit_screen_rounded
                              : Icons.width_full_rounded,
                          tooltip: _fitWidth ? 'Ajustar página' : 'Ajustar largura',
                          onTap: () => setState(() => _fitWidth = !_fitWidth),
                        ),
                        const SizedBox(width: 4),
                        // Reading mode toggle
                        _TopBarButton(
                          icon: _mode == _ReadingMode.vertical
                              ? Icons.swap_horiz_rounded
                              : Icons.swap_vert_rounded,
                          tooltip: _mode == _ReadingMode.vertical
                              ? 'Modo horizontal'
                              : 'Modo vertical',
                          onTap: () => _switchMode(pages),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Bottom Controls ───────────────────────────────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          bottom: _barsVisible ? 0 : -160,
          left: 0,
          right: 0,
          child: _BottomControls(
            currentPage: _currentPage,
            totalPages: pages.length,
            mode: _mode,
            onPageChanged: _mode == _ReadingMode.horizontal
                ? (value) {
                    final page = ((value) * (pages.length - 1)).round();
                    _pageController.jumpToPage(page);
                    setState(() => _currentPage = page);
                  }
                : null,
          ),
        ),

        // ── Floating page indicator (when bars hidden) ────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: _barsVisible ? -60 : 52,
          right: 16,
          child: _PageIndicatorChip(
            current: _currentPage + 1,
            total: pages.length,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TopBarButton
// ─────────────────────────────────────────────────────────────────────────────
class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopBarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Icon(icon, color: Colors.white70, size: 18),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BottomControls – slider + page info
// ─────────────────────────────────────────────────────────────────────────────
class _BottomControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final _ReadingMode mode;
  final ValueChanged<double>? onPageChanged;

  const _BottomControls({
    required this.currentPage,
    required this.totalPages,
    required this.mode,
    this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages == 0) return const SizedBox.shrink();

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.88),
                Colors.black.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mode label
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          mode == _ReadingMode.vertical
                              ? Icons.swap_vert_rounded
                              : Icons.swap_horiz_rounded,
                          color: Colors.white60,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          mode == _ReadingMode.vertical
                              ? 'Rolagem vertical'
                              : 'Modo horizontal',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Page slider (horizontal mode only)
                  if (mode == _ReadingMode.horizontal && totalPages > 1)
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor:
                            Colors.white.withValues(alpha: 0.2),
                        thumbColor: AppColors.primary,
                        overlayColor:
                            AppColors.primary.withValues(alpha: 0.2),
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7),
                      ),
                      child: Slider(
                        value: totalPages <= 1
                            ? 0.0
                            : currentPage / (totalPages - 1).toDouble(),
                        onChanged: onPageChanged,
                      ),
                    ),
                  // Page counter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Página',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${currentPage + 1}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'de $totalPages',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageIndicatorChip extends StatelessWidget {
  final int current;
  final int total;

  const _PageIndicatorChip({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(
        '$current / $total',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _PagePlaceholder extends StatelessWidget {
  const _PagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      color: const Color(0xFF0A0A0A),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5),
          const SizedBox(height: 12),
          Text(
            'Carregando página...',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PageError extends StatelessWidget {
  const _PageError();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_rounded,
              color: Colors.white38, size: 42),
          const SizedBox(height: 8),
          Text(
            'Falha ao carregar imagem',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ReaderLoading extends StatelessWidget {
  const _ReaderLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          const Text(
            'Carregando capítulo...',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ReaderError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ReaderError({required this.message, this.onRetry});

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
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
