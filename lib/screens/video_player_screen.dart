import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../main.dart';
import '../google_video_proxy.dart';
import '../services/allanime_service.dart';
import '../services/aniskip_service.dart';
import '../models/aniskip_models.dart';
import '../widgets/skip_button.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

// Function to extract only episode number from full text
String _extractEpisodeNumber(String episodeText) {
  // Try to extract number from text (e.g.: "Dandadan - Episódio 5" -> "5")
  final patterns = [
    RegExp(r'Episódio\s*(\d+)', caseSensitive: false),
    RegExp(r'Episode\s*(\d+)', caseSensitive: false),
    RegExp(r'Ep\.?\s*(\d+)', caseSensitive: false),
    RegExp(r'-\s*(\d+)$'),
    RegExp(r'\d+'),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(episodeText);
    if (match != null) {
      return match.group(1) ?? match.group(0) ?? episodeText;
    }
  }

  return episodeText;
}

class ModernVideoPlayerScreen extends StatefulWidget {
  final Episode episode;
  final String animeTitle;
  final Anime? anime;

  const ModernVideoPlayerScreen({
    super.key,
    required this.episode,
    required this.animeTitle,
    this.anime,
  });

  @override
  State<ModernVideoPlayerScreen> createState() =>
      _ModernVideoPlayerScreenState();
}

class _ModernVideoPlayerScreenState extends State<ModernVideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentVideoUrl;
  Map<String, String>? _currentVideoHeaders;
  Map<String, String>? _fallbackVideoHeaders;
  bool _showWebViewOption = false;
  String? _bloggerVideoUrl;
  GoogleVideoProxy? _googleVideoProxy;
  bool _isGoogleStream = false;

  // AniSkip related variables
  SkipTimes? _skipTimes;
  bool _showSkipButton = false;
  String _skipButtonLabel = '';
  Timer? _positionTimer;
  Timer? _skipButtonAutoHideTimer;
  int _skipTimesRetryCount = 0;
  static const int _maxSkipTimesRetries = 3;
  static const double _skipLeadSeconds = 3.0;
  static const double _skipHoldSeconds = 2.0;
  static const Duration _skipAutoHideDuration = Duration(seconds: 15);
  String? _skipButtonActiveSegment;
  bool _skipButtonDismissed = false;
  DateTime? _lastAutoHideTime;
  String? _activeEpisodeKey;

  String _buildEpisodeKey(ModernVideoPlayerScreen target) {
    final anime = target.anime;
    final buffer = StringBuffer()
      ..write(target.animeTitle)
      ..write('::')
      ..write(target.episode.number)
      ..write('::')
      ..write(target.episode.url);

    if (anime != null) {
      final identifiers = <String?>[
        anime.anilistId?.toString(),
        anime.malId?.toString(),
        anime.allAnimeId,
        anime.url,
      ];

      final extraIdentifier = identifiers.firstWhere(
        (value) => value != null && value.isNotEmpty,
        orElse: () => null,
      );

      if (extraIdentifier != null) {
        buffer
          ..write('::')
          ..write(extraIdentifier);
      }
    }

    return buffer.toString();
  }

  bool _isActiveEpisode(String? key) {
    if (key == null) {
      return false;
    }
    return mounted && _activeEpisodeKey == key;
  }

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  @override
  void didUpdateWidget(covariant ModernVideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousKey = _buildEpisodeKey(oldWidget);
    final nextKey = _buildEpisodeKey(widget);

    if (previousKey != nextKey) {
      debugPrint(
        '[VideoPlayer] 🔄 Episode context changed: $previousKey → $nextKey',
      );
      debugPrint('[VideoPlayer] Reinitializing player for new episode...');

      // Force a clean reinitialization
      _positionTimer?.cancel();
      _skipButtonAutoHideTimer?.cancel();
      _skipButtonActiveSegment = null;
      _skipButtonDismissed = false;
      _lastAutoHideTime = null;
      _skipTimes = null;
      _showSkipButton = false;
      _skipButtonLabel = '';

      _initializeVideoPlayer();
    }
  }

  /// Load skip times from AniSkip API using multiple strategies
  Future<void> _loadSkipTimes({int? episodeLengthSeconds}) async {
    final requestKey = _activeEpisodeKey;
    if (!_isActiveEpisode(requestKey)) {
      debugPrint('[AniSkip] ⏭️  Skipping load - episode changed.');
      return;
    }

    final malId = widget.anime?.malId;
    final anilistId = widget.anime?.anilistId;

    // Debug: Show anime info
    debugPrint('[AniSkip] 🔍 Checking anime data...');
    debugPrint('[AniSkip] Anime: ${widget.animeTitle}');
    debugPrint('[AniSkip] Source: ${widget.anime?.sourceName}');
    debugPrint(
      '[AniSkip] Has aniListData: ${widget.anime?.aniListData != null}',
    );
    debugPrint('[AniSkip] AniList ID: $anilistId');
    debugPrint('[AniSkip] MAL ID: $malId');

    if (malId == null && anilistId == null) {
      debugPrint(
        '[AniSkip] ⚠️  No MAL ID or AniList ID available - skipping AniSkip',
      );
      debugPrint(
        '[AniSkip] 💡 Tip: This anime needs to have at least one ID in AniList database',
      );
      return;
    }

    final episodeNumberStr = _extractEpisodeNumber(widget.episode.number);
    final episodeNumber = int.tryParse(episodeNumberStr);

    if (episodeNumber == null) {
      debugPrint(
        '[AniSkip] ⚠️  Could not parse episode number: $episodeNumberStr',
      );
      return;
    }

    final resolvedEpisodeLength =
        episodeLengthSeconds ??
        _videoPlayerController?.value.duration.inSeconds;

    if (resolvedEpisodeLength == null || resolvedEpisodeLength <= 0) {
      debugPrint(
        '[AniSkip] ⚠️  Episode length unavailable (got: $resolvedEpisodeLength).',
      );
      if (_skipTimesRetryCount < _maxSkipTimesRetries) {
        _skipTimesRetryCount++;
        debugPrint(
          '[AniSkip] 🔁 Retrying to load skip times (#$_skipTimesRetryCount)…',
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (!_isActiveEpisode(requestKey)) {
            return;
          }
          if (mounted) {
            _loadSkipTimes(
              episodeLengthSeconds:
                  _videoPlayerController?.value.duration.inSeconds,
            );
          }
        });
      } else {
        debugPrint(
          '[AniSkip] ❌ Gave up retrying skip times due to missing duration.',
        );
      }
      return;
    }

    _skipTimesRetryCount = 0;

    debugPrint('[AniSkip] 🔍 Fetching skip times for Episode: $episodeNumber');
    debugPrint('[AniSkip] Episode length (s): $resolvedEpisodeLength');
    if (malId != null) {
      debugPrint('[AniSkip] Will try MAL ID: $malId');
    }
    if (anilistId != null) {
      debugPrint('[AniSkip] Will try AniList ID: $anilistId');
    }

    try {
      final skipTimes = await AniSkipService.getSkipTimesMultiStrategy(
        malId: malId,
        anilistId: anilistId,
        episodeNumber: episodeNumber,
        episodeLengthSeconds: resolvedEpisodeLength,
      );

      if (mounted && _isActiveEpisode(requestKey)) {
        _skipButtonAutoHideTimer?.cancel();
        setState(() {
          _skipTimes = skipTimes;
          _skipButtonActiveSegment = null;
          _skipButtonDismissed = false;
          _lastAutoHideTime = null;
          _showSkipButton = false;
          _skipButtonLabel = '';
        });

        if (_isActiveEpisode(requestKey)) {
          if (skipTimes.hasSkipTimes) {
            debugPrint('[AniSkip] ✅ Skip times loaded successfully!');
            if (skipTimes.op != null) {
              final opShowStart = (skipTimes.op!.start - _skipLeadSeconds)
                  .clamp(0, double.infinity);
              final opShowEnd = skipTimes.op!.end + _skipHoldSeconds;
              debugPrint(
                '[AniSkip] 📺 Opening: ${skipTimes.op!.start.toStringAsFixed(1)}s - ${skipTimes.op!.end.toStringAsFixed(1)}s',
              );
              debugPrint(
                '[AniSkip] 📺 Button will show: ${opShowStart.toStringAsFixed(1)}s - ${opShowEnd.toStringAsFixed(1)}s (${(opShowEnd - opShowStart).toStringAsFixed(1)}s window)',
              );
            }
            if (skipTimes.ed != null) {
              final edShowStart = (skipTimes.ed!.start - _skipLeadSeconds)
                  .clamp(0, double.infinity);
              final edShowEnd = skipTimes.ed!.end + _skipHoldSeconds;
              debugPrint(
                '[AniSkip] 🎬 Ending: ${skipTimes.ed!.start.toStringAsFixed(1)}s - ${skipTimes.ed!.end.toStringAsFixed(1)}s',
              );
              debugPrint(
                '[AniSkip] 🎬 Button will show: ${edShowStart.toStringAsFixed(1)}s - ${edShowEnd.toStringAsFixed(1)}s (${(edShowEnd - edShowStart).toStringAsFixed(1)}s window)',
              );
            }
            // Always start timer when we have skip times
            _startPositionTimer();

            // Immediately check if we should show the button
            if (_videoPlayerController?.value.isInitialized == true) {
              final currentPos = _videoPlayerController?.value.position;
              if (currentPos != null) {
                debugPrint(
                  '[AniSkip] 🔍 Initial position check at ${currentPos.inSeconds}s',
                );
              }
              _checkSkipButtonVisibility();
            }
          } else {
            debugPrint('[AniSkip] ℹ️  No skip times found for this episode');
            // Still start timer in case skip times are added later
            _startPositionTimer();
          }
        }
      }
    } catch (e) {
      debugPrint('[AniSkip] ❌ Error loading skip times: $e');
    }
  }

  /// Start timer to check video position and show skip button
  void _startPositionTimer() {
    _positionTimer?.cancel();
    final timerKey = _activeEpisodeKey;
    debugPrint('[AniSkip] ▶️  Starting position timer for episode: $timerKey');

    int tickCount = 0;
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      tickCount++;

      if (!_isActiveEpisode(timerKey)) {
        debugPrint(
          '[AniSkip] ⏹️  Timer cancelled: episode changed (after $tickCount ticks)',
        );
        timer.cancel();
        return;
      }

      final controller = _videoPlayerController;
      if (controller == null) {
        if (tickCount % 10 == 0) {
          debugPrint('[AniSkip] ⚠️  Controller is null (tick $tickCount)');
        }
        return;
      }

      final value = controller.value;
      if (!value.isInitialized) {
        if (tickCount % 10 == 0) {
          debugPrint(
            '[AniSkip] ⚠️  Controller not initialized (tick $tickCount)',
          );
        }
        return;
      }

      if (_skipTimes == null || _skipTimes?.hasSkipTimes != true) {
        if (tickCount % 20 == 0) {
          debugPrint('[AniSkip] ⚠️  No skip times available (tick $tickCount)');
        }
        return;
      }

      // Log every 10 seconds to confirm timer is running
      if (tickCount % 20 == 0) {
        final pos = value.position.inSeconds;
        debugPrint(
          '[AniSkip] ⏱️  Timer active (tick $tickCount, position: ${pos}s)',
        );
      }

      _checkSkipButtonVisibility();
    });
  }

  /// Check if skip button should be visible based on current position
  void _checkSkipButtonVisibility() {
    final controller = _videoPlayerController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final position = controller.value.position;

    // Don't show button when video is paused (prevents infinite loop in landscape)
    if (!controller.value.isPlaying) {
      if (_showSkipButton) {
        setState(() {
          _showSkipButton = false;
          _skipButtonLabel = '';
        });
      }
      return;
    }

    final currentSeconds = position.inMilliseconds / 1000.0;

    // Determine which segment (if any) we're currently in
    String? activeSegment;
    String label = '';

    final inOpWindow =
        _skipTimes?.op != null &&
        _isWithinSkipWindow(_skipTimes?.op, currentSeconds);
    final inEdWindow =
        _skipTimes?.ed != null &&
        _isWithinSkipWindow(_skipTimes?.ed, currentSeconds);

    // Debug: Log window checks periodically
    if (currentSeconds.toInt() % 10 == 0 && currentSeconds.toInt() > 0) {
      debugPrint(
        '[AniSkip] 🔍 Position: ${currentSeconds.toStringAsFixed(1)}s | Op window: $inOpWindow | Ed window: $inEdWindow | Dismissed: $_skipButtonDismissed | Showing: $_showSkipButton',
      );
    }

    if (inOpWindow) {
      activeSegment = 'op';
      label = AppLocalizations.of(context).skipIntro;
    } else if (inEdWindow) {
      activeSegment = 'ed';
      label = AppLocalizations.of(context).skipOutro;
    }

    // Reset dismissal when we exit ALL skip windows
    if (_skipButtonDismissed && !inOpWindow && !inEdWindow) {
      debugPrint(
        '[AniSkip] 🔄 Resetting dismissal flag (exited all skip windows at ${currentSeconds.toStringAsFixed(1)}s)',
      );
      _skipButtonDismissed = false;
      _skipButtonActiveSegment = null;
    }

    // When entering a new segment, reset the dismissal and timer
    if (_skipButtonActiveSegment != activeSegment) {
      _skipButtonAutoHideTimer?.cancel();
      final previousSegment = _skipButtonActiveSegment;
      _skipButtonActiveSegment = activeSegment;

      if (activeSegment != null) {
        debugPrint(
          '[AniSkip] 🎯 Segment transition: $previousSegment → $activeSegment at ${currentSeconds.toStringAsFixed(1)}s (dismissed: $_skipButtonDismissed)',
        );
        // Reset dismissal and auto-hide time when entering a new segment
        _skipButtonDismissed = false;
        _lastAutoHideTime = null;
      }
    }

    // Handle visibility based on current state
    if (activeSegment == null) {
      // Not in any skip window
      if (_showSkipButton || _skipButtonLabel.isNotEmpty) {
        setState(() {
          _showSkipButton = false;
          _skipButtonLabel = '';
        });
      }
      return;
    }

    // In a skip window
    if (_skipButtonDismissed) {
      // Button was manually dismissed or skipped for this segment
      if (_showSkipButton) {
        debugPrint(
          '[AniSkip] 🙈 Hiding button (dismissed) at ${currentSeconds.toStringAsFixed(1)}s',
        );
        setState(() {
          _showSkipButton = false;
          _skipButtonLabel = '';
        });
      }
      return;
    }

    // Check if we're in cooldown period after auto-hide (30 seconds)
    if (_lastAutoHideTime != null) {
      final timeSinceAutoHide = DateTime.now().difference(_lastAutoHideTime!);
      if (timeSinceAutoHide.inSeconds < 30) {
        // Still in cooldown, don't show button yet
        if (_showSkipButton) {
          setState(() {
            _showSkipButton = false;
            _skipButtonLabel = '';
          });
        }
        return;
      } else {
        // Cooldown expired, clear the timestamp
        _lastAutoHideTime = null;
      }
    }

    // Show the button
    if (!_showSkipButton || label != _skipButtonLabel) {
      debugPrint(
        '[AniSkip] ✨ Showing skip button: $label at ${currentSeconds.toStringAsFixed(1)}s (segment: $activeSegment, dismissed: $_skipButtonDismissed)',
      );
      setState(() {
        _showSkipButton = true;
        _skipButtonLabel = label;
      });
      _scheduleSkipButtonAutoHide(activeSegment);
    }
  }

  /// Skip to the end of the current intro/outro
  void _skipIntroOutro() {
    final position = _videoPlayerController?.value.position;
    if (position == null) {
      debugPrint('[AniSkip] ❌ Cannot skip: video position unavailable');
      return;
    }

    if (_skipTimes == null) {
      debugPrint('[AniSkip] ❌ Cannot skip: no skip times loaded');
      return;
    }

    final currentSeconds = position.inMilliseconds / 1000.0;
    Duration? skipToPosition;
    String skipType = '';

    // If in opening, skip to end of opening
    if (_isWithinSkipWindow(_skipTimes!.op, currentSeconds)) {
      final targetSeconds = _skipTimes!.op!.end;
      skipToPosition = Duration(milliseconds: (targetSeconds * 1000).round());
      skipType = 'intro';
      debugPrint(
        '[AniSkip] ⏭️  Skipping intro: ${currentSeconds.toStringAsFixed(1)}s -> ${targetSeconds.toStringAsFixed(1)}s',
      );
    }
    // If in ending, skip to end of ending
    else if (_isWithinSkipWindow(_skipTimes!.ed, currentSeconds)) {
      final targetSeconds = _skipTimes!.ed!.end;
      skipToPosition = Duration(milliseconds: (targetSeconds * 1000).round());
      skipType = 'outro';
      debugPrint(
        '[AniSkip] ⏭️  Skipping outro: ${currentSeconds.toStringAsFixed(1)}s -> ${targetSeconds.toStringAsFixed(1)}s',
      );
    } else {
      debugPrint(
        '[AniSkip] ⚠️  Not in skip range (current: ${currentSeconds.toStringAsFixed(1)}s)',
      );
      return;
    }

    // Perform the skip
    _videoPlayerController?.seekTo(skipToPosition);

    // Hide button after skip
    _skipButtonAutoHideTimer?.cancel();
    _skipButtonDismissed = true;
    setState(() {
      _showSkipButton = false;
    });

    debugPrint('[AniSkip] ✅ Successfully skipped $skipType!');

    // Show a brief feedback to user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            skipType == 'intro' ? 'Intro pulada!' : 'Encerramento pulado!',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
        ),
      );
    }
  }

  bool _isWithinSkipWindow(Skip? skip, double currentSeconds) {
    if (skip == null) return false;
    final startBoundary = (skip.start - _skipLeadSeconds).clamp(
      0,
      double.infinity,
    );
    final endBoundary = skip.end + _skipHoldSeconds;
    final isInWindow =
        currentSeconds >= startBoundary && currentSeconds <= endBoundary;

    // Debug: Log when entering window
    if (isInWindow &&
        currentSeconds >= startBoundary &&
        currentSeconds < startBoundary + 1) {
      debugPrint(
        '[AniSkip] 🚪 Entering skip window: ${currentSeconds.toStringAsFixed(1)}s (boundary: ${startBoundary.toStringAsFixed(1)}s - ${endBoundary.toStringAsFixed(1)}s)',
      );
    }

    return isInWindow;
  }

  void _scheduleSkipButtonAutoHide(String segmentKey) {
    _skipButtonAutoHideTimer?.cancel();
    final episodeKey = _activeEpisodeKey;
    debugPrint(
      '[AniSkip] ⏲️  Scheduled auto-hide for segment: $segmentKey in ${_skipAutoHideDuration.inSeconds}s',
    );
    _skipButtonAutoHideTimer = Timer(_skipAutoHideDuration, () {
      if (!_isActiveEpisode(episodeKey) ||
          _skipButtonActiveSegment != segmentKey ||
          !mounted) {
        debugPrint(
          '[AniSkip] ⏲️  Auto-hide cancelled (episode/segment changed)',
        );
        return;
      }
      debugPrint(
        '[AniSkip] ⏲️  Auto-hiding button for segment: $segmentKey (will reappear after 30s cooldown)',
      );
      _lastAutoHideTime = DateTime.now();
      setState(() {
        _showSkipButton = false;
        _skipButtonLabel = '';
      });
      // Don't set _skipButtonDismissed = true here!
      // Button can reappear after cooldown period
    });
  }

  Future<void> _initializeVideoPlayer() async {
    if (!mounted) return;

    final episodeKey = _buildEpisodeKey(widget);
    debugPrint('[VideoPlayer] 🎬 Initializing player for episode: $episodeKey');

    _activeEpisodeKey = episodeKey;
    _positionTimer?.cancel();
    _skipButtonAutoHideTimer?.cancel();
    _skipButtonActiveSegment = null;
    _skipButtonDismissed = false;
    _skipTimesRetryCount = 0;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showWebViewOption = false;
      _bloggerVideoUrl = null;
      _skipTimes = null;
      _showSkipButton = false;
      _skipButtonLabel = '';
    });

    try {
      await _cleanupControllers();
      if (!_isActiveEpisode(episodeKey)) {
        debugPrint('[VideoPlayer] Initialization aborted (episode changed).');
        return;
      }

      String videoSrc;
      final isAllAnimeSource = widget.anime?.source == AnimeSource.allAnime;

      if (isAllAnimeSource) {
        debugPrint('[VideoPlayer] Getting AllAnime episode URL');

        final animeId = widget.anime!.allAnimeId ?? widget.anime!.url;
        final episodeNo = widget.episode.url;

        final allAnimeUrl = await AllAnimeService.getEpisodeURL(
          animeId,
          episodeNo,
        );

        if (!_isActiveEpisode(episodeKey)) {
          debugPrint('[VideoPlayer] AllAnime fetch ignored (episode changed).');
          return;
        }

        if (allAnimeUrl == null || allAnimeUrl.isEmpty) {
          throw Exception('Video URL not found on AllAnime');
        }

        videoSrc = allAnimeUrl;
        debugPrint('[VideoPlayer] AllAnime video URL: $videoSrc');
      } else {
        debugPrint('[VideoPlayer] Getting AnimeFire episode URL');
        videoSrc = await AnimeService.extractVideoURL(widget.episode.url);

        if (!_isActiveEpisode(episodeKey)) {
          debugPrint(
            '[VideoPlayer] AnimeFire fetch ignored (episode changed).',
          );
          return;
        }

        if (videoSrc.isEmpty) {
          throw Exception('Video URL not found on page');
        }
      }

      _bloggerVideoUrl = videoSrc;

      final baseHeaders = <String, String>{
        HttpHeaders.userAgentHeader:
            'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
        HttpHeaders.acceptHeader: 'video/mp4,video/*;q=0.9,*/*;q=0.8',
        HttpHeaders.refererHeader: isAllAnimeSource
            ? 'https://allanime.to/'
            : 'https://animefire.plus/',
      };

      final actualVideo = await AnimeService.extractActualVideoURL(
        videoSrc,
        referer: baseHeaders[HttpHeaders.refererHeader],
        fallbackHeaders: baseHeaders,
      );
      if (actualVideo.url.isEmpty) {
        throw Exception('Video URL could not be extracted from API');
      }

      _bloggerVideoUrl = actualVideo.url;

      if (!_isActiveEpisode(episodeKey)) {
        debugPrint(
          '[VideoPlayer] Actual video extraction ignored (episode changed).',
        );
        return;
      }

      String resolvedVideoUrl = actualVideo.url;
      _fallbackVideoHeaders = Map<String, String>.from(actualVideo.headers);
      Map<String, String> controllerHeaders = Map<String, String>.from(
        actualVideo.headers,
      );
      _isGoogleStream = actualVideo.isGoogleVideo;

      if (_shouldUseLocalProxy(
        actualVideo.url,
        controllerHeaders,
        actualVideo.isGoogleVideo,
      )) {
        final forwardedHeaders = Map<String, String>.from(controllerHeaders);
        _googleVideoProxy = GoogleVideoProxy(
          targetUri: Uri.parse(actualVideo.url),
          forwardHeaders: forwardedHeaders,
        );
        final proxyUri = await _googleVideoProxy!.start();

        if (!_isActiveEpisode(episodeKey)) {
          debugPrint('[VideoPlayer] Proxy start ignored (episode changed).');
          return;
        }

        resolvedVideoUrl = proxyUri.toString();
        controllerHeaders = {};
        debugPrint('Using local proxy for playback: $resolvedVideoUrl');
        debugPrint('Forwarding remote headers: $forwardedHeaders');
      }

      _currentVideoUrl = resolvedVideoUrl;
      _currentVideoHeaders = controllerHeaders;
      debugPrint('Using playback headers: $_currentVideoHeaders');

      final isHls = _isHlsUrl(resolvedVideoUrl);

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(resolvedVideoUrl),
        httpHeaders: controllerHeaders,
        formatHint: isHls ? VideoFormat.hls : null,
      );

      _videoPlayerController!.addListener(_videoPlayerListener);
      await _videoPlayerController!.initialize();

      if (!_isActiveEpisode(episodeKey)) {
        debugPrint('[VideoPlayer] Controller init ignored (episode changed).');
        return;
      }

      if (!mounted) return;

      if (_videoPlayerController!.value.hasError) {
        throw Exception(
          'Initialization error: ${_videoPlayerController!.value.errorDescription}',
        );
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        playbackSpeeds: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
        aspectRatio: _calculateAspectRatio(),
        errorBuilder: (context, errorMessage) {
          return _buildErrorWidget('Player error: $errorMessage');
        },
      );

      if (mounted) {
        if (!_isActiveEpisode(episodeKey)) {
          debugPrint(
            '[VideoPlayer] Skipped final state update (episode changed).',
          );
          return;
        }
        setState(() {
          _isLoading = false;
        });
      }

      final videoDurationSeconds =
          _videoPlayerController?.value.duration.inSeconds ?? 0;
      debugPrint('[VideoPlayer] Duration (s): $videoDurationSeconds');
      await _loadSkipTimes(episodeLengthSeconds: videoDurationSeconds);
    } catch (e) {
      debugPrint('Error initializing video: $e');
      await _googleVideoProxy?.stop();
      _googleVideoProxy = null;
      _isGoogleStream = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
          _showWebViewOption = _bloggerVideoUrl != null;
        });
      }
    }
  }

  void _videoPlayerListener() {
    if (_videoPlayerController?.value.hasError == true) {
      final error = _videoPlayerController!.value.errorDescription;
      debugPrint('Video player error: $error');
      if (mounted) {
        final isBloggerError =
            error?.contains('OSStatus error -12847') == true ||
            error?.contains('media format is not supported') == true ||
            error?.contains('CoreMediaErrorDomain error -12939') == true;

        setState(() {
          if (isBloggerError) {
            _errorMessage =
                'Compatibility error detected. Try using the alternative web player.';
            _showWebViewOption = _bloggerVideoUrl != null;
          } else {
            _errorMessage = 'Player error: $error';
            _showWebViewOption = _bloggerVideoUrl != null;
          }
          _isLoading = false;
        });
      }
    }
  }

  bool _isHlsUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8');
  }

  bool _shouldUseLocalProxy(
    String url,
    Map<String, String> headers,
    bool isGoogleVideo,
  ) {
    if (_isHlsUrl(url)) {
      return false;
    }

    if (isGoogleVideo) {
      return true;
    }

    final headerNames = headers.keys.map((key) => key.toLowerCase()).toSet();
    if (url.contains('lightspeedst.net')) {
      return false;
    }

    return headerNames.contains('cookie') ||
        headerNames.contains('origin') ||
        url.contains('blogger') ||
        url.contains('googleusercontent.com');
  }

  void _openWebViewFallback() {
    final fallbackUrl = _bloggerVideoUrl ?? _currentVideoUrl;
    if (fallbackUrl == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BloggerWebViewScreen(
          initialUrl: fallbackUrl,
          title: '${widget.animeTitle} - Ep ${widget.episode.number}',
          headers: _fallbackVideoHeaders ?? _currentVideoHeaders ?? const {},
        ),
      ),
    );
  }

  double _calculateAspectRatio() {
    if (_videoPlayerController?.value.isInitialized == true) {
      final size = _videoPlayerController!.value.size;
      if (size.width > 0 && size.height > 0) {
        return size.width / size.height;
      }
    }
    return 16 / 9;
  }

  Future<void> _cleanupControllers() async {
    _positionTimer?.cancel();
    _skipButtonAutoHideTimer?.cancel();
    _videoPlayerController?.removeListener(_videoPlayerListener);
    await _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
    _currentVideoHeaders = null;
    _currentVideoUrl = null;
    _fallbackVideoHeaders = null;
    _isGoogleStream = false;

    if (_googleVideoProxy != null) {
      await _googleVideoProxy!.stop();
      _googleVideoProxy = null;
    }
  }

  void _copyStreamLink() {
    if (_currentVideoUrl == null) return;
    Clipboard.setData(ClipboardData(text: _currentVideoUrl!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).linkCopied),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.withValues(alpha: 0.2),
                  Colors.red.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: Colors.red, size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context).playerError,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          if (_showWebViewOption && _bloggerVideoUrl != null) ...[
            ElevatedButton.icon(
              onPressed: _openWebViewFallback,
              icon: const Icon(Icons.open_in_browser),
              label: Text(AppLocalizations.of(context).alternativePlayer),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            onPressed: _initializeVideoPlayer,
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context).retry),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _cleanupControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Glassmorphism SliverAppBar ─────────────────────────────────
          SliverAppBar(
            expandedHeight: 72,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.background.withValues(alpha: 0.92),
                        AppColors.background.withValues(alpha: 0.7),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.animeTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'EP ${_extractEpisodeNumber(widget.episode.number)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Conteúdo
          SliverToBoxAdapter(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                ? _buildErrorState()
                : _buildLoadedContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing glow ring
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1.0),
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              builder: (_, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(opacity: value, child: child),
                );
              },
              onEnd: () {},
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.getPrimaryGradient(),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Title
            Text(
              widget.animeTitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            // Episode badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Text(
                'Episódio ${_extractEpisodeNumber(widget.episode.number)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Status text
            Text(
              AppLocalizations.of(context).loadingStream,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).preparingServer,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 32),
            // Step indicators
            _LoadingSteps(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: MediaQuery.of(context).size.height - 200,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: _buildErrorWidget(
          _errorMessage ?? AppLocalizations.of(context).error,
        ),
      ),
    );
  }

  Widget _buildLoadedContent() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // ── Video Player + Skip Button ─────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 30,
                      spreadRadius: 5,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: _calculateAspectRatio(),
                    child: _chewieController != null
                        ? Chewie(controller: _chewieController!)
                        : Container(color: Colors.black),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_showSkipButton,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24, right: 16),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: SkipButton(
                          onSkip: _skipIntroOutro,
                          label: _skipButtonLabel,
                          show: _showSkipButton,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Info Card ─────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(12, 16, 12, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surface.withValues(alpha: 0.9),
                AppColors.surfaceLight.withValues(alpha: 0.7),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header gradient band
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.18),
                      AppColors.primaryDark.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.animeTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: AppColors.getPrimaryGradient(),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Episódio ${_extractEpisodeNumber(widget.episode.number)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.play_circle_rounded,
                          color: AppColors.primary, size: 28),
                    ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quality Tags
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTag(
                          l10n.dynamicQuality,
                          const Color(0xFF9C27B0),
                          Icons.high_quality_rounded,
                        ),
                        _buildTag(
                          l10n.optimizedPlayer,
                          const Color(0xFF2196F3),
                          Icons.offline_bolt_rounded,
                        ),
                        if (_isGoogleStream)
                          _buildTag(
                            l10n.googleVideo,
                            const Color(0xFF4CAF50),
                            Icons.cloud_done_rounded,
                          ),
                      ],
                    ),

                    // Server Info
                    if (_currentVideoUrl != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                gradient: AppColors.getPrimaryGradient(),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.dns_rounded,
                                  color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.serverInUse,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    Uri.parse(_currentVideoUrl!).host,
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.5),
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _copyStreamLink,
                              icon: const Icon(Icons.copy_rounded,
                                  color: AppColors.primary, size: 18),
                              tooltip: l10n.copyLink,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Action Buttons
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.refresh_rounded,
                            label: l10n.syncStream,
                            onTap: _initializeVideoPlayer,
                            gradient: AppColors.getPrimaryGradient(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.link_rounded,
                            label: l10n.copyLink,
                            onTap: _currentVideoUrl == null
                                ? null
                                : _copyStreamLink,
                            outlined: true,
                          ),
                        ),
                      ],
                    ),

                    if (_showWebViewOption && _bloggerVideoUrl != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: _ActionButton(
                          icon: Icons.open_in_browser_rounded,
                          label: l10n.alternativePlayer,
                          onTap: _openWebViewFallback,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTag(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.9), size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.95),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActionButton – pill button with gradient or outlined style
// ─────────────────────────────────────────────────────────────────────────────
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final LinearGradient? gradient;
  final bool outlined;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.gradient,
    this.outlined = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            gradient: widget.outlined
                ? null
                : (enabled
                    ? widget.gradient
                    : const LinearGradient(
                        colors: [Color(0xFF2A1F1A), Color(0xFF2A1F1A)]))
                  ,
            borderRadius: BorderRadius.circular(14),
            border: widget.outlined
                ? Border.all(
                    color: enabled
                        ? AppColors.primary
                        : AppColors.textDisabled,
                    width: 1.5)
                : null,
            boxShadow: (!widget.outlined && enabled)
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.outlined
                    ? (enabled ? AppColors.primary : AppColors.textDisabled)
                    : Colors.white,
              ),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.outlined
                      ? (enabled ? AppColors.primary : AppColors.textDisabled)
                      : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LoadingSteps – animated step dots
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingSteps extends StatefulWidget {
  @override
  State<_LoadingSteps> createState() => _LoadingStepsState();
}

class _LoadingStepsState extends State<_LoadingSteps>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _animation;

  static const _steps = [
    'Obtendo URL do episódio',
    'Extraindo stream de vídeo',
    'Configurando player',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _animation = Tween<double>(begin: 0, end: _steps.length.toDouble())
        .animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) {
        final active = _animation.value.floor() % _steps.length;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_steps.length, (i) {
            final isActive = i == active;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _steps[i],
                    style: TextStyle(
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}
