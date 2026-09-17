import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../l10n/app_localizations.dart';
import '../services/download_service.dart';
import '../services/playback_wake_lock.dart';
import '../services/manga_service.dart';
import '../services/player_service.dart';
import '../services/watch_history_service.dart';
import '../theme/app_colors.dart';
import '../widgets/desktop_video_player.dart';
import 'manga_reader_screen.dart';
import 'video_player_screen.dart';
import '../main.dart' show Episode, Anime;

/// Downloads and Library screen - Animes in progress, Anime downloads, and Manga downloads
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          l10n.downloads,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.textPrimary),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(
              icon: Icon(Icons.play_circle_outline, size: 20),
              text: 'Assistindo',
            ),
            Tab(
              icon: Icon(Icons.video_library_outlined, size: 20),
              text: 'Animes',
            ),
            Tab(
              icon: Icon(Icons.menu_book_outlined, size: 20),
              text: 'Mangás',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _WatchingAnimesTab(),
          _AnimeDownloadsTab(),
          _MangaDownloadsTab(),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final downloadService = context.read<DownloadService>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Configurações de Download',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Downloads Simultâneos',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              ),
              subtitle: Slider(
                value: downloadService.maxConcurrentDownloads.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                activeColor: AppColors.accent,
                label: downloadService.maxConcurrentDownloads.toString(),
                onChanged: (value) {
                  downloadService.maxConcurrentDownloads = value.toInt();
                },
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                downloadService.clearCompleted();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_sweep, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              label: const Text('Limpar Concluídos da Lista'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Watching Animes Tab (Animes que o usuário está vendo)
// ─────────────────────────────────────────────────────────────────────────────
class _WatchingAnimesTab extends StatelessWidget {
  const _WatchingAnimesTab();

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WatchHistoryService>(
      builder: (context, historyService, _) {
        final items = historyService.items;

        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.movie_creation_outlined,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhum anime em andamento',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Os episódios que você assistir aparecerão aqui automaticamente para você continuar de onde parou.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final progress = item.progress;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _resumeEpisode(context, item),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Thumbnail with play badge
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 90,
                              height: 65,
                              color: Colors.black26,
                              child: item.animeImageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: item.animeImageUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => const Icon(
                                        Icons.movie,
                                        color: Colors.white24,
                                      ),
                                    )
                                  : const Icon(Icons.movie, color: Colors.white24),
                            ),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white54, width: 1),
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: AppColors.accent,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.animeTitle,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Episódio ${item.episodeNumber}${item.episodeTitle.isNotEmpty && item.episodeTitle != item.episodeNumber ? ' • ${item.episodeTitle}' : ''}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            // Progress bar
                            if (progress > 0) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 4,
                                  backgroundColor: Colors.white12,
                                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_formatDuration(item.positionSeconds)} / ${_formatDuration(item.durationSeconds)} (${(progress * 100).toInt()}%)',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                        tooltip: 'Remover do histórico',
                        onPressed: () {
                          context.read<WatchHistoryService>().removeItem(item.animeTitle);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _resumeEpisode(BuildContext context, WatchHistoryItem item) {
    final episode = Episode(
      number: item.episodeNumber,
      title: item.episodeTitle.isNotEmpty ? item.episodeTitle : 'Episódio ${item.episodeNumber}',
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Anime Downloads Tab (Downloads de Vídeos de Anime)
// ─────────────────────────────────────────────────────────────────────────────
class _AnimeDownloadsTab extends StatelessWidget {
  const _AnimeDownloadsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadService>(
      builder: (context, downloadService, _) {
        final activeDownloads = downloadService.activeDownloads;
        final completed = downloadService.completedDownloads;
        final Map<String, List<DownloadItem>> completedGrouped = {};
        for (final item in completed) {
          completedGrouped.putIfAbsent(item.animeName, () => []).add(item);
        }

        if (activeDownloads.isEmpty && completedGrouped.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.file_download_outlined,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhum anime baixado',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Baixe episódios no AnimeFire para assistir quando estiver offline!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            // Active downloads section if any
            if (activeDownloads.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.downloading, color: AppColors.accent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Baixando Agora (${activeDownloads.length})',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ActiveDownloadCard(item: activeDownloads[index]),
                  childCount: activeDownloads.length,
                ),
              ),
            ],

            // Completed downloads section if any
            if (completedGrouped.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Disponíveis Offline (${completedGrouped.values.fold(0, (sum, l) => sum + l.length)} episódios)',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final animeName = completedGrouped.keys.elementAt(index);
                    final episodes = completedGrouped[animeName]!;
                    return _CompletedAnimeGroup(animeName: animeName, episodes: episodes);
                  },
                  childCount: completedGrouped.length,
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      },
    );
  }
}

class _ActiveDownloadCard extends StatelessWidget {
  final DownloadItem item;

  const _ActiveDownloadCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final downloadService = context.read<DownloadService>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.animeName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
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
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.status == DownloadStatus.downloading)
                IconButton(
                  icon: const Icon(Icons.pause_circle_filled, color: AppColors.accent),
                  onPressed: () => downloadService.pauseDownload(item.id),
                )
              else if (item.status == DownloadStatus.paused)
                IconButton(
                  icon: const Icon(Icons.play_circle_filled, color: Colors.green),
                  onPressed: () => downloadService.resumeDownload(item.id),
                ),
              IconButton(
                icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                onPressed: () => downloadService.cancelDownload(item.id),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.progress,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(
                item.status == DownloadStatus.paused ? Colors.orange : AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(item.progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              Text(
                '${downloadService.formatBytes(item.bytesDownloaded)} / ${downloadService.formatBytes(item.totalBytes)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletedAnimeGroup extends StatelessWidget {
  final String animeName;
  final List<DownloadItem> episodes;

  const _CompletedAnimeGroup({required this.animeName, required this.episodes});

  @override
  Widget build(BuildContext context) {
    final first = episodes.first;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 50,
            height: 65,
            child: first.thumbnailUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: first.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const Icon(Icons.movie, color: Colors.white24),
                  )
                : const Icon(Icons.movie, color: Colors.white24),
          ),
        ),
        title: Text(
          animeName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${episodes.length} episódios baixados',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        children: episodes.map((ep) => _CompletedEpisodeTile(episode: ep)).toList(),
      ),
    );
  }
}

class _CompletedEpisodeTile extends StatelessWidget {
  final DownloadItem episode;

  const _CompletedEpisodeTile({required this.episode});

  @override
  Widget build(BuildContext context) {
    final downloadService = context.read<DownloadService>();

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        'Episódio ${episode.episodeNumber}',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
      ),
      subtitle: Text(
        downloadService.formatBytes(episode.totalBytes),
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_circle_fill, color: AppColors.accent, size: 28),
            onPressed: () {
              if (episode.filePath == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _LocalVideoPlayerScreen(
                    filePath: episode.filePath!,
                    episodeTitle: '${episode.animeName} - Ep ${episode.episodeNumber}',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            onPressed: () => downloadService.deleteDownload(episode.id),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Manga Downloads Tab (Capítulos de Mangá Baixados)
// ─────────────────────────────────────────────────────────────────────────────
class _MangaDownloadsTab extends StatefulWidget {
  const _MangaDownloadsTab();

  @override
  State<_MangaDownloadsTab> createState() => _MangaDownloadsTabState();
}

class _MangaDownloadsTabState extends State<_MangaDownloadsTab> {
  late Future<List<MangaDownloadItem>> _mangaFuture;

  @override
  void initState() {
    super.initState();
    _loadManga();
  }

  void _loadManga() {
    setState(() {
      _mangaFuture = context.read<MangaService>().getDownloadedMangas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mangaService = context.watch<MangaService>();

    return FutureBuilder<List<MangaDownloadItem>>(
      future: _mangaFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }

        final chapters = snapshot.data ?? [];

        if (chapters.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.menu_book_outlined,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhum mangá baixado',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Baixe capítulos na aba Mangás para ler offline com imagens salvas no seu aparelho.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        // Group chapters by manga title
        final Map<String, List<MangaDownloadItem>> grouped = {};
        for (final item in chapters) {
          grouped.putIfAbsent(item.mangaTitle, () => []).add(item);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final mangaTitle = grouped.keys.elementAt(index);
            final mangaChapters = grouped[mangaTitle]!;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: ExpansionTile(
                initiallyExpanded: index == 0,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.book, color: AppColors.accent),
                ),
                title: Text(
                  mangaTitle,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${mangaChapters.length} capítulos baixados',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                children: mangaChapters.map((ch) {
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    title: Text(
                      ch.chapterTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      '${ch.pageCount} páginas salvas',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MangaReaderScreen(
                                  manga: MangaTitle(
                                    id: '',
                                    title: ch.mangaTitle,
                                    description: '',
                                    coverUrl: null,
                                    status: '',
                                    tags: const [],
                                  ),
                                  chapter: MangaChapter(
                                    id: ch.id,
                                    title: ch.chapterTitle,
                                    chapter: '',
                                    language: 'pt-br',
                                    publishedAt: ch.completedAt,
                                  ),
                                  service: mangaService,
                                  localDirectory: ch.directoryPath,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chrome_reader_mode, size: 16),
                          label: const Text('Ler', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: const Size(60, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () async {
                            await mangaService.deleteDownloadedChapter(ch.directoryPath);
                            _loadManga();
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Local Video Player Screen (BetterPlayer for downloaded files)
// ─────────────────────────────────────────────────────────────────────────────
class _LocalVideoPlayerScreen extends StatefulWidget {
  final String filePath;
  final String episodeTitle;

  const _LocalVideoPlayerScreen({
    required this.filePath,
    required this.episodeTitle,
  });

  @override
  State<_LocalVideoPlayerScreen> createState() => _LocalVideoPlayerScreenState();
}

class _LocalVideoPlayerScreenState extends State<_LocalVideoPlayerScreen> {
  Player? _mediaKitPlayer;
  VideoController? _mediaKitVideoController;
  BetterPlayerController? _betterPlayerController;
  bool _isInitialized = false;
  bool _useMediaKit = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    PlaybackWakeLock.acquire();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final playerService = Provider.of<PlayerService>(context, listen: false);
      _useMediaKit = playerService.isMediaKit || (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

      if (_useMediaKit) {
        _mediaKitPlayer = Player();
        _mediaKitVideoController = VideoController(_mediaKitPlayer!);
        await _mediaKitPlayer!.open(
          Media(widget.filePath),
          play: true,
        );
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
        return;
      }

      final dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.file,
        widget.filePath,
      );
      _betterPlayerController = BetterPlayerController(
        const BetterPlayerConfiguration(
          autoPlay: true,
          looping: false,
          allowedScreenSleep: false,
          aspectRatio: 16 / 9,
          fit: BoxFit.contain,
          controlsConfiguration: BetterPlayerControlsConfiguration(
            enablePlaybackSpeed: true,
            enableSkips: true,
            enableFullscreen: true,
            enableMute: true,
          ),
        ),
        betterPlayerDataSource: dataSource,
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    PlaybackWakeLock.release();
    _betterPlayerController?.dispose();
    _mediaKitPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: Text(
            widget.episodeTitle,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              Text(
                'Erro ao reproduzir: $_errorMessage',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_useMediaKit && _mediaKitPlayer != null && _mediaKitVideoController != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: DesktopVideoPlayer(
            player: _mediaKitPlayer!,
            controller: _mediaKitVideoController!,
            title: widget.episodeTitle,
            subtitle: 'Download Local',
            onBack: () => Navigator.pop(context),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          widget.episodeTitle,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _isInitialized && _betterPlayerController != null
            ? BetterPlayer(controller: _betterPlayerController!)
            : const CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
