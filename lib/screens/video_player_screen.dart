import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../google_video_proxy.dart';
import '../services/allanime_service.dart';
import '../services/hianime_service.dart';
import '../services/consumet_service.dart';
import '../services/sugoi_service.dart';
import '../services/anify_service.dart';
import '../services/animesonline_service.dart';
import '../services/animesorion_service.dart';
import '../services/animesdigital_service.dart';
import '../services/download_service.dart';
import '../services/player_service.dart';
import '../services/watch_history_service.dart';
import '../services/aniskip_service.dart';
import '../services/playback_wake_lock.dart';
import '../models/aniskip_models.dart';
import '../widgets/desktop_video_player.dart';
import '../widgets/skip_button.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'source_selection_screen.dart';

// Function to extract only episode number from full text
String _extractEpisodeNumber(String episodeText) {
  final patterns = [
    RegExp(r'Epis[oó]dio\s*(\d+)', caseSensitive: false),
    RegExp(r'Episode\s*(\d+)', caseSensitive: false),
    RegExp(r'Ep\.?\s*(\d+)', caseSensitive: false),
    RegExp(r'T\d+:\s*Ep\s*(\d+)', caseSensitive: false),
    RegExp(r'-\s*(\d+)$'),
    RegExp(r'(\d+)'),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(episodeText);
    if (match != null) {
      if (match.groupCount >= 1 && match.group(1) != null) {
        return match.group(1)!;
      }
      final g0 = match.group(0);
      if (g0 != null && g0.isNotEmpty) {
        return g0;
      }
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
  Player? _mediaKitPlayer;
  VideoController? _mediaKitVideoController;
  BetterPlayerController? _betterPlayerController;
  bool _useMediaKit = false;
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentVideoUrl;
  Map<String, String>? _currentVideoHeaders;
  // ignore: unused_field
  Map<String, String>? _fallbackVideoHeaders;
  bool _showWebViewOption = false;
  String? _bloggerVideoUrl;
  GoogleVideoProxy? _googleVideoProxy;
  bool _isGoogleStream = false;

  // Audio stream options (Dublado PT-BR / Legendado)
  List<EpisodeStreamOption> _availableAudioStreams = [];
  String? _currentAudioType;
  String? _manualAudioOverride;
  Duration? _pendingSeekPosition;

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
  int _playerLoadId = 0;

  // PC Keyboard Navigation & Shortcuts
  final FocusNode _keyboardFocusNode = FocusNode();
  String? _overlayNotificationText;
  Timer? _overlayNotificationTimer;

  void _showOverlayNotification(String text) {
    _overlayNotificationTimer?.cancel();
    setState(() {
      _overlayNotificationText = text;
    });
    _overlayNotificationTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _overlayNotificationText = null;
        });
      }
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;

    final isSelectKey = key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.keyK ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.gameButtonSelect;

    final isPlayPauseKey = isSelectKey || key == LogicalKeyboardKey.mediaPlayPause;
    final isPlayKey = key == LogicalKeyboardKey.mediaPlay;
    final isPauseKey = key == LogicalKeyboardKey.mediaPause;

    final isForwardKey = key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyL;

    final isBackwardKey = key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.keyJ;

    final isFastForwardKey = key == LogicalKeyboardKey.mediaFastForward;
    final isRewindKey = key == LogicalKeyboardKey.mediaRewind;

    final isVolumeUpKey = key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.audioVolumeUp;

    final isVolumeDownKey = key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.audioVolumeDown;

    final isBackKey = key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack;

    final isSkipKey = key == LogicalKeyboardKey.keyS;

    // Check if Skip Intro/Outro requested
    if ((isSkipKey || (isFastForwardKey && _showSkipButton)) && _showSkipButton) {
      _skipIntroOutro();
      _showOverlayNotification('Abertura pulada ⏩');
      return;
    }

    if (_useMediaKit && _mediaKitPlayer != null) {
      final player = _mediaKitPlayer!;
      if (isPlayPauseKey) {
        player.playOrPause();
        _showOverlayNotification(
          player.state.playing ? 'Pausado ⏸' : 'Reproduzindo ▶',
        );
      } else if (isPlayKey) {
        player.play();
        _showOverlayNotification('Reproduzindo ▶');
      } else if (isPauseKey) {
        player.pause();
        _showOverlayNotification('Pausado ⏸');
      } else if (isFastForwardKey) {
        final target = player.state.position + const Duration(seconds: 30);
        player.seek(target);
        _showOverlayNotification('+30s ⏩');
      } else if (isRewindKey) {
        final target = player.state.position - const Duration(seconds: 30);
        player.seek(target > Duration.zero ? target : Duration.zero);
        _showOverlayNotification('-30s ⏪');
      } else if (isForwardKey) {
        final target = player.state.position + const Duration(seconds: 10);
        player.seek(target);
        _showOverlayNotification('+10s ⏩');
      } else if (isBackwardKey) {
        final target = player.state.position - const Duration(seconds: 10);
        player.seek(target > Duration.zero ? target : Duration.zero);
        _showOverlayNotification('-10s ⏪');
      } else if (key == LogicalKeyboardKey.keyM) {
        if (player.state.volume > 0) {
          player.setVolume(0.0);
          _showOverlayNotification('Mudo 🔇');
        } else {
          player.setVolume(100.0);
          _showOverlayNotification('Som 🔊 100%');
        }
      } else if (isVolumeUpKey) {
        final newVol = (player.state.volume + 5.0).clamp(0.0, 100.0);
        player.setVolume(newVol);
        _showOverlayNotification('Volume 🔊 ${newVol.round()}%');
      } else if (isVolumeDownKey) {
        final newVol = (player.state.volume - 5.0).clamp(0.0, 100.0);
        player.setVolume(newVol);
        _showOverlayNotification('Volume 🔉 ${newVol.round()}%');
      } else if (isBackKey) {
        Navigator.of(context).pop();
      }
      return;
    }

    final controller = _betterPlayerController;
    if (controller == null) return;

    if (isPlayPauseKey) {
      if (controller.isPlaying() == true) {
        controller.pause();
        _showOverlayNotification('Pausado ⏸');
      } else {
        controller.play();
        _showOverlayNotification('Reproduzindo ▶');
      }
    } else if (isPlayKey) {
      controller.play();
      _showOverlayNotification('Reproduzindo ▶');
    } else if (isPauseKey) {
      controller.pause();
      _showOverlayNotification('Pausado ⏸');
    } else if (isFastForwardKey) {
      controller.videoPlayerController?.position.then((pos) {
        if (pos != null) {
          final target = pos + const Duration(seconds: 30);
          controller.seekTo(target);
          _showOverlayNotification('+30s ⏩');
        }
      });
    } else if (isRewindKey) {
      controller.videoPlayerController?.position.then((pos) {
        if (pos != null) {
          final target = pos - const Duration(seconds: 30);
          controller.seekTo(target > Duration.zero ? target : Duration.zero);
          _showOverlayNotification('-30s ⏪');
        }
      });
    } else if (isForwardKey) {
      controller.videoPlayerController?.position.then((pos) {
        if (pos != null) {
          final target = pos + const Duration(seconds: 10);
          controller.seekTo(target);
          _showOverlayNotification('+10s ⏩');
        }
      });
    } else if (isBackwardKey) {
      controller.videoPlayerController?.position.then((pos) {
        if (pos != null) {
          final target = pos - const Duration(seconds: 10);
          controller.seekTo(target > Duration.zero ? target : Duration.zero);
          _showOverlayNotification('-10s ⏪');
        }
      });
    } else if (key == LogicalKeyboardKey.keyF) {
      controller.toggleFullScreen();
      _showOverlayNotification('Tela Cheia ⛶');
    } else if (key == LogicalKeyboardKey.keyM) {
      final currentVol = controller.videoPlayerController?.value.volume ?? 1.0;
      if (currentVol > 0) {
        controller.setVolume(0.0);
        _showOverlayNotification('Mudo 🔇');
      } else {
        controller.setVolume(1.0);
        _showOverlayNotification('Som 🔊 100%');
      }
    } else if (isVolumeUpKey) {
      final currentVol = controller.videoPlayerController?.value.volume ?? 1.0;
      final newVol = (currentVol + 0.1).clamp(0.0, 1.0);
      controller.setVolume(newVol);
      _showOverlayNotification('Volume 🔊 ${(newVol * 100).toInt()}%');
    } else if (isVolumeDownKey) {
      final currentVol = controller.videoPlayerController?.value.volume ?? 1.0;
      final newVol = (currentVol - 0.1).clamp(0.0, 1.0);
      controller.setVolume(newVol);
      _showOverlayNotification('Volume 🔉 ${(newVol * 100).toInt()}%');
    } else if (isBackKey) {
      Navigator.of(context).pop();
    }
  }

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

  bool _isCurrentPlayerLoad(String? key, int loadId) {
    return _isActiveEpisode(key) && _playerLoadId == loadId;
  }

  @override
  void initState() {
    super.initState();
    PlaybackWakeLock.acquire();
    _initializeVideoPlayer();
  }

  @override
  void didUpdateWidget(covariant ModernVideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousKey = _buildEpisodeKey(oldWidget);
    final nextKey = _buildEpisodeKey(widget);

    if (previousKey != nextKey) {
      debugPrint(
        '[VideoPlayer] ðŸ”„ Episode context changed: $previousKey â†’ $nextKey',
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
      debugPrint('[AniSkip] â ­ï¸   Skipping load - episode changed.');
      return;
    }

    int? malId = widget.anime?.malId;
    int? anilistId = widget.anime?.anilistId;

    // Debug: Show anime info
    debugPrint('[AniSkip] 🔍 Checking anime data...');
    debugPrint('[AniSkip] Anime: ${widget.animeTitle}');
    debugPrint('[AniSkip] Source: ${widget.anime?.sourceName}');
    debugPrint(
      '[AniSkip] Has aniListData: ${widget.anime?.aniListData != null}',
    );
    debugPrint('[AniSkip] AniList ID: $anilistId');
    debugPrint('[AniSkip] MAL ID: $malId');

    // Dynamic resolution if IDs are missing
    if (malId == null && anilistId == null && widget.animeTitle.isNotEmpty) {
      debugPrint('[AniSkip] 🔍 Resolving IDs dynamically for: "${widget.animeTitle}"');
      final resolved = await AniSkipService.resolveIdsByTitle(widget.animeTitle);
      if (resolved.malId != null) {
        widget.anime?.malIdOverride = resolved.malId;
        malId = resolved.malId;
      }
      if (resolved.anilistId != null) {
        widget.anime?.anilistIdOverride = resolved.anilistId;
        anilistId = resolved.anilistId;
      }
      debugPrint('[AniSkip] 📋 Dynamic resolution result -> MAL: $malId, AniList: $anilistId');
    }

    if (malId == null && anilistId == null) {
      debugPrint(
        '[AniSkip] ⚠️  No MAL ID or AniList ID available after title lookup - skipping AniSkip',
      );
      return;
    }

    final episodeNumberStr = _extractEpisodeNumber(widget.episode.number);
    final episodeNumber = int.tryParse(episodeNumberStr);

    if (episodeNumber == null) {
      debugPrint(
        '[AniSkip] âš ï¸  Could not parse episode number: $episodeNumberStr',
      );
      return;
    }

    final resolvedEpisodeLength =
        episodeLengthSeconds ??
        (_useMediaKit
            ? _mediaKitPlayer?.state.duration.inSeconds
            : _betterPlayerController
                  ?.videoPlayerController
                  ?.value
                  .duration
                  ?.inSeconds);

    if (resolvedEpisodeLength == null || resolvedEpisodeLength <= 0) {
      debugPrint(
        '[AniSkip] âš ï¸  Episode length unavailable (got: $resolvedEpisodeLength).',
      );
      if (_skipTimesRetryCount < _maxSkipTimesRetries) {
        _skipTimesRetryCount++;
        debugPrint(
          '[AniSkip] ðŸ” Retrying to load skip times (#$_skipTimesRetryCount)â€¦',
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (!_isActiveEpisode(requestKey)) {
            return;
          }
          if (mounted) {
            _loadSkipTimes(
              episodeLengthSeconds: _useMediaKit
                  ? _mediaKitPlayer?.state.duration.inSeconds
                  : _betterPlayerController
                        ?.videoPlayerController
                        ?.value
                        .duration
                        ?.inSeconds,
            );
          }
        });
      } else {
        debugPrint(
          '[AniSkip] âŒ Gave up retrying skip times due to missing duration.',
        );
      }
      return;
    }

    _skipTimesRetryCount = 0;

    debugPrint(
      '[AniSkip] ðŸ” Fetching skip times for Episode: $episodeNumber',
    );
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
        animeTitle: widget.animeTitle,
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
            debugPrint('[AniSkip] âœ… Skip times loaded successfully!');
            if (skipTimes.op != null) {
              final opShowStart = (skipTimes.op!.start - _skipLeadSeconds)
                  .clamp(0, double.infinity);
              final opShowEnd = skipTimes.op!.end + _skipHoldSeconds;
              debugPrint(
                '[AniSkip] ðŸ“º Opening: ${skipTimes.op!.start.toStringAsFixed(1)}s - ${skipTimes.op!.end.toStringAsFixed(1)}s',
              );
              debugPrint(
                '[AniSkip] ðŸ“º Button will show: ${opShowStart.toStringAsFixed(1)}s - ${opShowEnd.toStringAsFixed(1)}s (${(opShowEnd - opShowStart).toStringAsFixed(1)}s window)',
              );
            }
            if (skipTimes.ed != null) {
              final edShowStart = (skipTimes.ed!.start - _skipLeadSeconds)
                  .clamp(0, double.infinity);
              final edShowEnd = skipTimes.ed!.end + _skipHoldSeconds;
              debugPrint(
                '[AniSkip] ðŸŽ¬ Ending: ${skipTimes.ed!.start.toStringAsFixed(1)}s - ${skipTimes.ed!.end.toStringAsFixed(1)}s',
              );
              debugPrint(
                '[AniSkip] ðŸŽ¬ Button will show: ${edShowStart.toStringAsFixed(1)}s - ${edShowEnd.toStringAsFixed(1)}s (${(edShowEnd - edShowStart).toStringAsFixed(1)}s window)',
              );
            }
            // Always start timer when we have skip times
            _startPositionTimer();

            // Immediately check if we should show the button
            _checkSkipButtonVisibility();
          } else {
            debugPrint(
              '[AniSkip] â„¹ï¸  No skip times found for this episode',
            );
            _startPositionTimer();
          }
        }
      }
    } catch (e) {
      debugPrint('[AniSkip] âŒ Error loading skip times: $e');
    }
  }

  /// Start timer to check video position and show skip button
  void _startPositionTimer() {
    _positionTimer?.cancel();
    final timerKey = _activeEpisodeKey;
    debugPrint(
      '[AniSkip] â–¶ï¸  Starting position timer for episode: $timerKey',
    );

    int tickCount = 0;
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      tickCount++;

      if (!_isActiveEpisode(timerKey)) {
        debugPrint(
          '[AniSkip] â¹ï¸  Timer cancelled: episode changed (after $tickCount ticks)',
        );
        timer.cancel();
        return;
      }

      int posSeconds = 0;
      bool isReady = false;

      if (_useMediaKit && _mediaKitPlayer != null) {
        posSeconds = _mediaKitPlayer!.state.position.inSeconds;
        isReady = true;
      } else if (_betterPlayerController?.isVideoInitialized() == true) {
        posSeconds =
            _betterPlayerController
                ?.videoPlayerController
                ?.value
                .position
                .inSeconds ??
            0;
        isReady = true;
      }

      if (!isReady) {
        return;
      }

      if (_skipTimes == null || _skipTimes?.hasSkipTimes != true) {
        return;
      }

      // Save progress and log periodically
      if (tickCount % 20 == 0) {
        debugPrint(
          '[AniSkip] â±ï¸  Timer active (tick $tickCount, position: ${posSeconds}s)',
        );
        _saveWatchProgress();
      }

      _checkSkipButtonVisibility();
    });
  }

  /// Check if skip button should be visible based on current position
  void _checkSkipButtonVisibility() {
    Duration? position;
    bool isPlaying = false;

    if (_useMediaKit && _mediaKitPlayer != null) {
      position = _mediaKitPlayer!.state.position;
      isPlaying = _mediaKitPlayer!.state.playing;
    } else if (_betterPlayerController?.isVideoInitialized() == true) {
      final controller = _betterPlayerController?.videoPlayerController;
      if (controller != null) {
        position = controller.value.position;
        isPlaying = controller.value.isPlaying;
      }
    }

    if (position == null) {
      return;
    }

    // Don't show button when video is paused (prevents infinite loop in landscape)
    if (!isPlaying) {
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
        '[AniSkip] ðŸ” Position: ${currentSeconds.toStringAsFixed(1)}s | Op window: $inOpWindow | Ed window: $inEdWindow | Dismissed: $_skipButtonDismissed | Showing: $_showSkipButton',
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
        '[AniSkip] ðŸ”„ Resetting dismissal flag (exited all skip windows at ${currentSeconds.toStringAsFixed(1)}s)',
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
          '[AniSkip] ðŸŽ¯ Segment transition: $previousSegment â†’ $activeSegment at ${currentSeconds.toStringAsFixed(1)}s (dismissed: $_skipButtonDismissed)',
        );
        _skipButtonDismissed = false;
        _lastAutoHideTime = null;
      }
    }

    // Handle visibility based on current state
    if (activeSegment == null) {
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
      if (_showSkipButton) {
        debugPrint(
          '[AniSkip] ðŸ™ˆ Hiding button (dismissed) at ${currentSeconds.toStringAsFixed(1)}s',
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
        if (_showSkipButton) {
          setState(() {
            _showSkipButton = false;
            _skipButtonLabel = '';
          });
        }
        return;
      } else {
        _lastAutoHideTime = null;
      }
    }

    if (!_showSkipButton || label != _skipButtonLabel) {
      debugPrint(
        '[AniSkip] âœ¨ Showing skip button: $label at ${currentSeconds.toStringAsFixed(1)}s (segment: $activeSegment, dismissed: $_skipButtonDismissed)',
      );
      setState(() {
        _showSkipButton = true;
        _skipButtonLabel = label;
      });
      _scheduleSkipButtonAutoHide(activeSegment);
    }
  }

  void _scheduleSkipButtonAutoHide(String segmentKey) {
    _skipButtonAutoHideTimer?.cancel();
    final episodeKey = _activeEpisodeKey;
    _skipButtonAutoHideTimer = Timer(_skipAutoHideDuration, () {
      if (!_isActiveEpisode(episodeKey) ||
          _skipButtonActiveSegment != segmentKey ||
          !mounted) {
        return;
      }
      _lastAutoHideTime = DateTime.now();
      setState(() {
        _showSkipButton = false;
        _skipButtonLabel = '';
      });
    });
  }

  bool _isWithinSkipWindow(Skip? skip, double currentSeconds) {
    if (skip == null) return false;
    final startBoundary = (skip.start - _skipLeadSeconds).clamp(
      0.0,
      double.infinity,
    );
    final endBoundary = skip.end + _skipHoldSeconds;
    return currentSeconds >= startBoundary && currentSeconds <= endBoundary;
  }

  void _skipIntroOutro() {
    Duration? position;
    if (_useMediaKit && _mediaKitPlayer != null) {
      position = _mediaKitPlayer!.state.position;
    } else {
      position = _betterPlayerController?.videoPlayerController?.value.position;
    }

    if (position == null || _skipTimes == null) return;

    final currentSeconds = position.inMilliseconds / 1000.0;
    Duration? skipToPosition;
    String skipType = '';

    if (_isWithinSkipWindow(_skipTimes!.op, currentSeconds)) {
      final targetSeconds = _skipTimes!.op!.end;
      skipToPosition = Duration(milliseconds: (targetSeconds * 1000).round());
      skipType = 'intro';
    } else if (_isWithinSkipWindow(_skipTimes!.ed, currentSeconds)) {
      final targetSeconds = _skipTimes!.ed!.end;
      skipToPosition = Duration(milliseconds: (targetSeconds * 1000).round());
      skipType = 'outro';
    } else {
      return;
    }

    if (_useMediaKit && _mediaKitPlayer != null) {
      _mediaKitPlayer!.seek(skipToPosition);
    } else {
      _betterPlayerController?.seekTo(skipToPosition);
    }

    _skipButtonAutoHideTimer?.cancel();
    _skipButtonDismissed = true;
    setState(() {
      _showSkipButton = false;
    });

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

  String _resolveWebPageFallbackUrl() {
    String fallbackUrl = _bloggerVideoUrl ?? widget.episode.url;
    if (fallbackUrl.contains('api.animefire.') &&
        fallbackUrl.contains('/episode/')) {
      final epId = fallbackUrl.split('/episode/').last.split('?').first.trim();
      if (epId.isNotEmpty) {
        return 'https://animefire.one/video/$epId';
      }
    }
    return fallbackUrl;
  }

  void _copyStreamLink() {
    final url = _currentVideoUrl ?? _bloggerVideoUrl ?? _resolveWebPageFallbackUrl();
    Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copiado!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _copyYtDlpCommand() async {
    String? resolvedUrl;
    Map<String, String>? resolvedHeaders;

    // 1. Prefer authentic remote stream if available
    if (_bloggerVideoUrl != null &&
        !_bloggerVideoUrl!.contains('127.0.0.1') &&
        !_bloggerVideoUrl!.contains('localhost')) {
      resolvedUrl = _bloggerVideoUrl;
      resolvedHeaders = _fallbackVideoHeaders;
    } else if (_googleVideoProxy?.targetUri != null) {
      resolvedUrl = _googleVideoProxy!.targetUri.toString();
      resolvedHeaders = _googleVideoProxy!.forwardHeaders;
    } else if (_currentVideoUrl != null &&
        !_currentVideoUrl!.contains('127.0.0.1') &&
        !_currentVideoUrl!.contains('localhost')) {
      resolvedUrl = _currentVideoUrl;
      resolvedHeaders = _currentVideoHeaders;
    }

    // 2. If no direct remote stream has been resolved yet, resolve on-demand
    if (resolvedUrl == null ||
        resolvedUrl.contains('api.animefire.') ||
        resolvedUrl.contains('/video/')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Obtendo link direto do vídeo para o yt-dlp...'),
            duration: Duration(seconds: 1),
            backgroundColor: Color(0xFF1E1E2C),
          ),
        );
      }

      try {
        final videoSrc = await AnimeService.extractVideoURL(widget.episode.url);
        final actual = await AnimeService.extractActualVideoURL(
          videoSrc,
          referer: 'https://animefire.one/',
          fallbackHeaders: {
            'Referer': 'https://animefire.one/',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          },
        );
        if (actual.url.isNotEmpty && !actual.url.contains('/video/')) {
          resolvedUrl = actual.url;
          resolvedHeaders = actual.headers;
        }
      } catch (e) {
        debugPrint(
          '[VideoPlayer] On-demand stream extraction for yt-dlp error: $e',
        );
      }
    }

    final targetUrl = resolvedUrl ?? _bloggerVideoUrl ?? widget.episode.url;
    final headers =
        resolvedHeaders ?? _fallbackVideoHeaders ?? _currentVideoHeaders;
    final referer = headers?['referer'] ?? headers?['Referer'];

    final cmd = DownloadService.generateYtDlpCommand(
      videoUrl: targetUrl,
      referer: referer,
      outputName:
          '${widget.animeTitle}_EP${_extractEpisodeNumber(widget.episode.number)}',
    );

    await Clipboard.setData(ClipboardData(text: cmd));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Comando yt-dlp copiado!\n$cmd',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: AppColors.primary,
          action: Platform.isWindows
              ? SnackBarAction(
                  label: 'Baixar Agora',
                  textColor: Colors.white,
                  onPressed: () => _executeYtDlpDownload(cmd),
                )
              : null,
        ),
      );
    }
  }

  void _executeYtDlpDownload(String cmd) {
    if (!Platform.isWindows) return;
    try {
      Process.start('cmd.exe', [
        '/c',
        'start',
        'cmd.exe',
        '/k',
        'cd /d "%USERPROFILE%\\Downloads" && $cmd',
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Terminal iniciado! O download será salvo em Downloads.',
            ),
            duration: Duration(seconds: 3),
            backgroundColor: Color(0xFF238636),
          ),
        );
      }
    } catch (e) {
      debugPrint('[VideoPlayer] Failed to launch yt-dlp terminal: $e');
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (!mounted) return;

    final episodeKey = _buildEpisodeKey(widget);
    final loadId = ++_playerLoadId;
    debugPrint(
      '[VideoPlayer] ðŸŽ¬ Initializing player for episode: $episodeKey',
    );

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
      _bloggerVideoUrl = widget.episode.url;
      _skipTimes = null;
      _showSkipButton = false;
      _skipButtonLabel = '';
    });

    try {
      await _cleanupControllers();
      if (!_isCurrentPlayerLoad(episodeKey, loadId)) {
        debugPrint('[VideoPlayer] Initialization aborted (episode changed).');
        return;
      }

      String videoSrc;
      final isAllAnimeSource = widget.anime?.source == AnimeSource.allAnime;
      final isHiAnimeSource = widget.anime?.source == AnimeSource.hiAnime;
      final isConsumetSource = widget.anime?.source == AnimeSource.consumet;
      final isSugoiSource = widget.anime?.source == AnimeSource.sugoi;
      final isAnifySource = widget.anime?.source == AnimeSource.anify;
      final isAnimesOnlineSource =
          widget.anime?.source == AnimeSource.animesOnline;
      final isAnimesOrionSource =
          widget.anime?.source == AnimeSource.animesOrion;
      final isAnimesDigitalSource =
          widget.anime?.source == AnimeSource.animesDigital;

      if (isHiAnimeSource) {
        debugPrint('[VideoPlayer] Getting HiAnime episode URL');
        final episodeId = widget.episode.url;
        final hiAnimeUrl = await HiAnimeService.getEpisodeStreamUrl(episodeId);

        if (!_isCurrentPlayerLoad(episodeKey, loadId)) {
          debugPrint('[VideoPlayer] HiAnime fetch ignored (episode changed).');
          return;
        }

        if (hiAnimeUrl == null || hiAnimeUrl.isEmpty) {
          throw Exception('Video URL not found on HiAnime');
        }

        videoSrc = hiAnimeUrl;
        debugPrint('[VideoPlayer] HiAnime video URL: $videoSrc');
      } else if (isAllAnimeSource) {
        debugPrint('[VideoPlayer] Getting AllAnime episode URL');

        final animeId = widget.anime!.allAnimeId ?? widget.anime!.url;
        final episodeNo = widget.episode.url;

        final allAnimeUrl = await AllAnimeService.getEpisodeURL(
          animeId,
          episodeNo,
        );

        if (!_isCurrentPlayerLoad(episodeKey, loadId)) {
          debugPrint('[VideoPlayer] AllAnime fetch ignored (episode changed).');
          return;
        }

        if (allAnimeUrl == null || allAnimeUrl.isEmpty) {
          throw Exception('Video URL not found on AllAnime');
        }

        videoSrc = allAnimeUrl;
        debugPrint('[VideoPlayer] AllAnime video URL: $videoSrc');
      } else if (isConsumetSource) {
        debugPrint('[VideoPlayer] Getting Consumet episode URL');
        final sources = await ConsumetService.getStreamSources(
          widget.episode.url,
        );
        if (!_isCurrentPlayerLoad(episodeKey, loadId)) return;
        if (sources.isEmpty) {
          throw Exception('Video URL not found on Consumet');
        }
        videoSrc = sources.first.url;
        debugPrint('[VideoPlayer] Consumet video URL: $videoSrc');
      } else if (isSugoiSource) {
        debugPrint('[VideoPlayer] Getting Sugoi episode URL');
        final url =
            await SugoiService.getStreamUrl(widget.episode.url) ??
            widget.episode.url;
        if (!_isCurrentPlayerLoad(episodeKey, loadId)) return;
        videoSrc = url;
        debugPrint('[VideoPlayer] Sugoi video URL: $videoSrc');
      } else if (isAnifySource) {
        debugPrint('[VideoPlayer] Getting Anify episode URL');
        final sources = await AnifyService.getStreamSources(widget.episode.url);
        if (!_isCurrentPlayerLoad(episodeKey, loadId)) return;
        if (sources.isEmpty) {
          throw Exception('Video URL not found on Anify');
        }
        videoSrc = sources.first.url;
        debugPrint('[VideoPlayer] Anify video URL: $videoSrc');
      } else if (isAnimesOnlineSource) {
        debugPrint('[VideoPlayer] Getting AnimesOnline episode URL');
        final sources = await AnimesOnlineService.getStreamSources(
          widget.episode.url,
        );
        if (!_isCurrentPlayerLoad(episodeKey, loadId)) return;
        if (sources.isEmpty) {
          throw Exception('Video URL not found on AnimesOnline');
        }
        videoSrc = sources.first.url;
        debugPrint('[VideoPlayer] AnimesOnline video URL: $videoSrc');
      } else if (isAnimesOrionSource) {
        debugPrint('[VideoPlayer] Getting AnimesOrion episode URL');
        final sources = await AnimesOrionService.getStreamSources(
          widget.episode.url,
        );
        if (!_isCurrentPlayerLoad(episodeKey, loadId)) return;
        if (sources.isEmpty) {
          throw Exception('Video URL not found on AnimesOrion');
        }
        videoSrc = sources.first.url;
        debugPrint('[VideoPlayer] AnimesOrion video URL: $videoSrc');
      } else if (isAnimesDigitalSource) {
        debugPrint('[VideoPlayer] Getting AnimesDigital episode URL');
        final sources = await AnimesDigitalService.getStreamSources(
          widget.episode.url,
        );
        if (!_isCurrentPlayerLoad(episodeKey, loadId)) return;
        if (sources.isEmpty) {
          throw Exception('Video URL not found on AnimesDigital');
        }
        videoSrc = sources.first.url;
        debugPrint('[VideoPlayer] AnimesDigital video URL: $videoSrc');
      } else {
        debugPrint('[VideoPlayer] Getting AnimeFire episode URL & streams');
        if (!mounted) return;
        final playerService =
            Provider.of<PlayerService>(context, listen: false);
        final preferredAudio = _manualAudioOverride ??
            (playerService.isDubbedPreferred ? 'dublado' : 'legendado');

        final streamResult = await AnimeService.getEpisodeStreams(
          widget.episode.url,
          animeTitle: widget.anime?.name ?? widget.animeTitle,
          preferredAudio: preferredAudio,
        );

        if (!_isCurrentPlayerLoad(episodeKey, loadId)) {
          debugPrint(
            '[VideoPlayer] AnimeFire fetch ignored (episode changed).',
          );
          return;
        }

        if (streamResult.selectedStream == null ||
            streamResult.selectedStream!.streamUrl.isEmpty) {
          throw Exception('Video URL not found on page');
        }

        videoSrc = streamResult.selectedStream!.streamUrl;
        _availableAudioStreams = streamResult.availableStreams;
        _currentAudioType = streamResult.selectedStream!.audioType;
        debugPrint(
          '[VideoPlayer] Selected audio: $_currentAudioType, available: ${_availableAudioStreams.map((s) => s.audioType).toList()}',
        );
      }

      final reqReferer = isAllAnimeSource
          ? 'https://allanime.to/'
          : widget.episode.url;

      final baseHeaders = <String, String>{
        HttpHeaders.userAgentHeader:
            'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
        HttpHeaders.acceptHeader: 'video/mp4,video/*;q=0.9,*/*;q=0.8',
        HttpHeaders.refererHeader: reqReferer,
      };

      final actualVideo = await AnimeService.extractActualVideoURL(
        videoSrc,
        referer: reqReferer,
        fallbackHeaders: baseHeaders,
      );
      if (actualVideo.url.isEmpty) {
        throw Exception('Video URL could not be extracted from API');
      }

      if (actualVideo.url.contains('animefire.plus/video/')) {
        debugPrint(
          '[VideoPlayer] AnimeFire returned iframe URL. Auto-opening episode page in Web Player.',
        );
        if (mounted) {
          setState(() {
            _showWebViewOption = true;
            _isLoading = false;
          });
          // Open the episode page directly â€” the AnimeFire JS player will handle video loading
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BloggerWebViewScreen(
                initialUrl: widget.episode.url,
                title: '${widget.animeTitle} - Ep ${widget.episode.number}',
                headers: const {
                  'Referer': 'https://animefire.one/',
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
                },
              ),
            ),
          );
        }
        return;
      }

      _bloggerVideoUrl = actualVideo.url;

      if (!_isCurrentPlayerLoad(episodeKey, loadId)) {
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

      if (actualVideo.url.contains('lightspeedst.net') ||
          actualVideo.url.contains('animefire')) {
        controllerHeaders.putIfAbsent('Referer', () => 'https://animefire.one/');
        controllerHeaders.putIfAbsent(
          'User-Agent',
          () =>
              'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
        );
      }

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

        if (!_isCurrentPlayerLoad(episodeKey, loadId)) {
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

      if (!mounted) return;

      final playerService = Provider.of<PlayerService>(context, listen: false);
      _useMediaKit =
          playerService.isMediaKit ||
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

      if (playerService.isExternalApp) {
        setState(() {
          _isLoading = false;
          _showWebViewOption = true;
        });
        await _openExternalPlayer();
        return;
      }

      if (_useMediaKit) {
        try {
          _mediaKitPlayer = Player();
          _mediaKitVideoController = VideoController(_mediaKitPlayer!);

          _mediaKitPlayer!.stream.error.listen((error) {
            debugPrint('[MediaKit] Player error: $error');
            if (mounted) {
              setState(() {
                _errorMessage = 'Player error: $error';
                _showWebViewOption = _bloggerVideoUrl != null;
                _isLoading = false;
              });
            }
          });

          _mediaKitPlayer!.stream.duration.listen((dur) {
            if (dur > Duration.zero &&
                _isCurrentPlayerLoad(episodeKey, loadId)) {
              _loadSkipTimes(episodeLengthSeconds: dur.inSeconds);
            }
          });

          await _mediaKitPlayer!.open(
            Media(resolvedVideoUrl, httpHeaders: controllerHeaders),
            play: true,
          );

          if (_pendingSeekPosition != null &&
              _pendingSeekPosition! > Duration.zero) {
            final seekTarget = _pendingSeekPosition!;
            _pendingSeekPosition = null;
            await _mediaKitPlayer!.seek(seekTarget);
          }

          if (!_isCurrentPlayerLoad(episodeKey, loadId)) {
            debugPrint(
              '[VideoPlayer] MediaKit init ignored (episode changed).',
            );
            _mediaKitPlayer?.dispose();
            _mediaKitPlayer = null;
            _mediaKitVideoController = null;
            return;
          }

          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _startPositionTimer();
            _saveWatchProgress();
          }
        } catch (err) {
          debugPrint('[VideoPlayer] MediaKit initialization failed: $err');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage =
                  'Erro ao inicializar o player nativo do Windows: $err';
              _showWebViewOption = true;
            });
          }
          return;
        }
      } else {
        final dataSource = BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          resolvedVideoUrl,
          headers: controllerHeaders,
          videoFormat: _isDashUrl(resolvedVideoUrl)
              ? BetterPlayerVideoFormat.dash
              : (_isHlsUrl(resolvedVideoUrl)
                  ? BetterPlayerVideoFormat.hls
                  : BetterPlayerVideoFormat.other),
        );

        try {
          _betterPlayerController = BetterPlayerController(
            BetterPlayerConfiguration(
              autoPlay: true,
              looping: false,
              allowedScreenSleep: false,
              aspectRatio: _calculateAspectRatio(),
              fit: BoxFit.contain,
              errorBuilder: (context, errorMessage) {
                return _buildErrorWidget('Player error: $errorMessage');
              },
              controlsConfiguration: const BetterPlayerControlsConfiguration(
                enablePlaybackSpeed: true,
                enableSkips: true,
                enableFullscreen: true,
                enableMute: true,
                enableProgressBar: true,
                enableProgressText: true,
                enableOverflowMenu: true,
              ),
            ),
            betterPlayerDataSource: dataSource,
          );

          _betterPlayerController!.addEventsListener(_videoPlayerListener);

          if (_pendingSeekPosition != null &&
              _pendingSeekPosition! > Duration.zero) {
            final seekTarget = _pendingSeekPosition!;
            _pendingSeekPosition = null;
            _betterPlayerController!.seekTo(seekTarget);
          }
        } catch (err) {
          debugPrint('[VideoPlayer] Controller initialization failed: $err');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage =
                  'O reprodutor integrado encontrou um erro no ambiente atual. Clique abaixo para abrir no reprodutor externo (VLC / Navegador).';
              _showWebViewOption = true;
            });
          }
          return;
        }

        if (!_isCurrentPlayerLoad(episodeKey, loadId)) {
          debugPrint(
            '[VideoPlayer] Controller init ignored (episode changed).',
          );
          _betterPlayerController?.dispose();
          _betterPlayerController = null;
          return;
        }

        if (!mounted) return;

        if (mounted) {
          if (!_isCurrentPlayerLoad(episodeKey, loadId)) {
            debugPrint(
              '[VideoPlayer] Skipped final state update (episode changed).',
            );
            return;
          }
          setState(() {
            _isLoading = false;
          });
          _saveWatchProgress();
        }

        final videoDurationSeconds =
            _betterPlayerController
                ?.videoPlayerController
                ?.value
                .duration
                ?.inSeconds ??
            0;
        debugPrint('[VideoPlayer] Duration (s): $videoDurationSeconds');
        if (_isCurrentPlayerLoad(episodeKey, loadId)) {
          await _loadSkipTimes(episodeLengthSeconds: videoDurationSeconds);
        }
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (!_isCurrentPlayerLoad(episodeKey, loadId)) return;
      await _googleVideoProxy?.stop();
      _googleVideoProxy = null;
      _isGoogleStream = false;
      if (mounted) {
        String displayError = e.toString().replaceAll('Exception: ', '').trim();
        if (displayError.contains('No AnimeFire API stream found') ||
            displayError.contains('indisponível no servidor do AnimeFire') ||
            displayError.contains('Nenhum stream de vídeo disponível')) {
          displayError =
              'Este episódio está temporariamente indisponível nos servidores do AnimeFire.';
        }
        setState(() {
          _isLoading = false;
          _errorMessage = displayError;
          _showWebViewOption = true;
        });
      }
    }
  }

  void _videoPlayerListener(BetterPlayerEvent event) {
    if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
      final error =
          _betterPlayerController
              ?.videoPlayerController
              ?.value
              .errorDescription ??
          'Unknown error';
      debugPrint('Video player error: $error');
      if (mounted) {
        final isBloggerError =
            error.contains('OSStatus error -12847') == true ||
            error.contains('media format is not supported') == true ||
            error.contains('CoreMediaErrorDomain error -12939') == true;

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

  void _switchAudio(EpisodeStreamOption option) {
    if (_currentAudioType == option.audioType) return;

    Duration? currentPosition;
    if (_useMediaKit && _mediaKitPlayer != null) {
      currentPosition = _mediaKitPlayer!.state.position;
    } else if (_betterPlayerController != null) {
      currentPosition =
          _betterPlayerController!.videoPlayerController?.value.position;
    }

    setState(() {
      _pendingSeekPosition = currentPosition;
      _manualAudioOverride = option.audioType;
      _currentAudioType = option.audioType;
    });

    final playerService = Provider.of<PlayerService>(context, listen: false);
    playerService.setPreferredAudio(
      option.isDubbed ? PreferredAudio.dubbed : PreferredAudio.subbed,
    );

    _showOverlayNotification('Áudio: ${option.label}');
    _initializeVideoPlayer();
  }

  bool _isHlsUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') ||
        lower.contains('akumast.net') ||
        lower.contains('/m.jpg') ||
        lower.contains('/h.jpg') ||
        lower.contains('/p.jpg');
  }

  bool _isDashUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mpd');
  }

  bool _shouldUseLocalProxy(
    String url,
    Map<String, String> headers,
    bool isGoogleVideo,
  ) {
    if (GoogleVideoProxy.disableProxy) {
      return false;
    }

    // akumast.net uses HLS playlists/fMP4 disguised with .jpg extensions
    // that must be served via local proxy with .m3u8 extension & headers
    if (url.contains('akumast.net') ||
        url.contains('/m.jpg') ||
        url.contains('/h.jpg') ||
        url.contains('/p.jpg')) {
      return true;
    }

    if (_isHlsUrl(url)) {
      return false;
    }

    if (isGoogleVideo) {
      return true;
    }

    if (url.contains('lightspeedst.net')) {
      return true;
    }

    final headerNames = headers.keys.map((key) => key.toLowerCase()).toSet();

    return headerNames.contains('cookie') ||
        headerNames.contains('origin') ||
        headerNames.contains('referer') ||
        url.contains('blogger') ||
        url.contains('googleusercontent.com');
  }

  void _openWebViewFallback() {
    final fallbackUrl = _resolveWebPageFallbackUrl();
    if (fallbackUrl.isEmpty) return;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalApplication);
      return;
    }

    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
      'Referer': 'https://animefire.one/',
    };

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BloggerWebViewScreen(
          initialUrl: fallbackUrl,
          title: '${widget.animeTitle} - Ep ${widget.episode.number}',
          headers: headers,
        ),
      ),
    );
  }

  Future<void> _openExternalPlayer() async {
    String targetUrl = _currentVideoUrl ?? _bloggerVideoUrl ?? '';
    if (targetUrl.isEmpty || targetUrl.contains('api.animefire.')) {
      targetUrl = _resolveWebPageFallbackUrl();
    }
    if (targetUrl.isEmpty) return;

    if (targetUrl.contains('lightspeedst.net') ||
        targetUrl.contains('animefire')) {
      try {
        final headers = Map<String, String>.from(
          _currentVideoHeaders ?? const {},
        );
        headers.putIfAbsent('Referer', () => 'https://animefire.one/');
        headers.putIfAbsent(
          'User-Agent',
          () =>
              'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
        );

        if (_googleVideoProxy == null) {
          _googleVideoProxy = GoogleVideoProxy(
            targetUri: Uri.parse(targetUrl),
            forwardHeaders: headers,
          );
          final proxyUri = await _googleVideoProxy!.start();
          targetUrl = proxyUri.toString();
        } else if (_googleVideoProxy!.localUri != null) {
          targetUrl = _googleVideoProxy!.localUri!.toString();
        }
      } catch (e) {
        debugPrint('Error starting proxy for external player: $e');
      }
    }

    final uri = Uri.parse(targetUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _copyStreamLink();
      }
    } catch (e) {
      debugPrint('Error launching external player: $e');
      if (mounted) {
        _copyStreamLink();
      }
    }
  }

  double _calculateAspectRatio() {
    if (_useMediaKit) {
      return 16 / 9;
    }
    if (_betterPlayerController?.isVideoInitialized() == true) {
      final size = _betterPlayerController!.videoPlayerController?.value.size;
      if (size != null && size.width > 0 && size.height > 0) {
        return size.width / size.height;
      }
    }
    return 16 / 9;
  }

  Future<void> _cleanupControllers() async {
    _positionTimer?.cancel();
    _skipButtonAutoHideTimer?.cancel();
    _betterPlayerController?.removeEventsListener(_videoPlayerListener);
    _betterPlayerController?.dispose();
    _betterPlayerController = null;

    final oldMediaKitPlayer = _mediaKitPlayer;
    _mediaKitPlayer = null;
    _mediaKitVideoController = null;
    await oldMediaKitPlayer?.dispose();

    _currentVideoHeaders = null;
    _currentVideoUrl = null;
    _fallbackVideoHeaders = null;
    _isGoogleStream = false;

    if (_googleVideoProxy != null) {
      await _googleVideoProxy!.stop();
      _googleVideoProxy = null;
    }
  }

  void _saveWatchProgress() {
    try {
      int pos = 0;
      int dur = 0;
      if (_useMediaKit && _mediaKitPlayer != null) {
        pos = _mediaKitPlayer!.state.position.inSeconds;
        dur = _mediaKitPlayer!.state.duration.inSeconds;
      } else {
        final controller = _betterPlayerController?.videoPlayerController;
        pos = controller?.value.position.inSeconds ?? 0;
        dur = controller?.value.duration?.inSeconds ?? 0;
      }

      if (pos > 0 || dur > 0) {
        WatchHistoryService().saveProgress(
          animeTitle: widget.animeTitle,
          animeImageUrl: widget.anime?.imageUrl ?? '',
          episodeNumber: widget.episode.number,
          episodeTitle: widget.episode.title ?? '',
          episodeUrl: widget.episode.url,
          positionSeconds: pos,
          durationSeconds: dur,
          animeSourceUrl: widget.anime?.url,
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    PlaybackWakeLock.release();
    _saveWatchProgress();
    _positionTimer?.cancel();
    _overlayNotificationTimer?.cancel();
    _keyboardFocusNode.dispose();
    _cleanupControllers();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Widget _buildErrorWidget(String message) {
    final isOfflineError = message.contains('AnimeFire') ||
        message.contains('indisponível') ||
        message.contains('offline');
    final hasActiveStream =
        _currentVideoUrl != null && _currentVideoUrl!.isNotEmpty;
    final fallbackUrl = _resolveWebPageFallbackUrl();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isOfflineError ? Colors.amber : Colors.red)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (isOfflineError ? Colors.amber : Colors.red)
                          .withValues(alpha: 0.2),
                      (isOfflineError ? Colors.amber : Colors.red)
                          .withValues(alpha: 0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOfflineError ? Icons.cloud_off_rounded : Icons.error_outline,
                  color: isOfflineError ? Colors.amber : Colors.red,
                  size: 36,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isOfflineError
                    ? 'Episódio Indisponível no AnimeFire'
                    : AppLocalizations.of(context).playerError,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isOfflineError
                    ? 'Este episódio está temporariamente marcado como offline nos servidores do AnimeFire. Experimente trocar a versão/fonte do anime.'
                    : message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              // Botão Principal: Trocar Fonte / Versão
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SourceSelectionScreen(
                        animeTitle: widget.animeTitle,
                        imageUrl: widget.anime?.imageUrl ??
                            widget.episode.thumbnail ??
                            '',
                        myAnimeListUrl: widget.anime?.malId != null
                            ? 'https://myanimelist.net/anime/${widget.anime!.malId}'
                            : '',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                label: const Text(
                  'Trocar Fonte / Versão',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (fallbackUrl.isNotEmpty) ...[
                ElevatedButton.icon(
                  onPressed: _openWebViewFallback,
                  icon: const Icon(Icons.open_in_browser, size: 20),
                  label: Text(AppLocalizations.of(context).alternativePlayer),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (hasActiveStream) ...[
                ElevatedButton.icon(
                  onPressed: _openExternalPlayer,
                  icon: const Icon(Icons.smart_display, size: 20),
                  label: const Text('Abrir em Player Externo (VLC / MX)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E86AB),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _copyStreamLink,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copiar Link do Vídeo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    minimumSize: const Size(double.infinity, 40),
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              ElevatedButton.icon(
                onPressed: _copyYtDlpCommand,
                icon: const Icon(Icons.terminal, size: 20),
                label: const Text('Copiar Comando yt-dlp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _initializeVideoPlayer,
                icon: const Icon(Icons.refresh, size: 20),
                label: Text(AppLocalizations.of(context).retry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white12,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldContent = Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
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
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                color: const Color(0xFF1E1E2C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'webview') {
                    _openWebViewFallback();
                  } else if (value == 'external') {
                    _openExternalPlayer();
                  } else if (value == 'copy') {
                    _copyStreamLink();
                  } else if (value == 'copy_ytdlp') {
                    _copyYtDlpCommand();
                  } else if (value == 'switch_player') {
                    final playerService = Provider.of<PlayerService>(
                      context,
                      listen: false,
                    );
                    final newEngine = _useMediaKit
                        ? PlayerEngine.betterPlayer
                        : PlayerEngine.mediaKit;
                    playerService.setEngine(newEngine);
                    setState(() {
                      _useMediaKit = !_useMediaKit;
                    });
                    _initializeVideoPlayer();
                  } else if (value == 'toggle_legacy_error') {
                    GoogleVideoProxy.simulateLegacyError =
                        !GoogleVideoProxy.simulateLegacyError;
                    final active = GoogleVideoProxy.simulateLegacyError;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          active
                              ? 'Modo Legado ATIVADO: Redirecionamentos vÃ£o simular erro 401/403.'
                              : 'Modo Legado DESATIVADO: Proxy corrigido com preservaÃ§Ã£o de cabeÃ§alhos.',
                        ),
                        backgroundColor: active
                            ? Colors.redAccent
                            : Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    _initializeVideoPlayer();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'switch_player',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.swap_horiz_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _useMediaKit
                              ? 'Alternar para BetterPlayer'
                              : 'Alternar para Neko Player (MPV)',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'webview',
                    child: Row(
                      children: [
                        Icon(
                          Icons.open_in_browser,
                          color: Color(0xFFFF6B35),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Player Web Integrado',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'external',
                    child: Row(
                      children: [
                        Icon(
                          Icons.smart_display,
                          color: Color(0xFF2E86AB),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Player Externo (VLC/MX)',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(Icons.copy, color: Colors.white70, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Copiar Link do VÃ­deo',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy_ytdlp',
                    child: Row(
                      children: [
                        Icon(Icons.terminal, color: AppColors.accent, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Copiar Comando yt-dlp',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle_legacy_error',
                    child: Row(
                      children: [
                        Icon(
                          Icons.bug_report,
                          color: GoogleVideoProxy.simulateLegacyError
                              ? Colors.redAccent
                              : Colors.orangeAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          GoogleVideoProxy.simulateLegacyError
                              ? 'Desativar Teste (Modo Normal)'
                              : 'Simular Erro 401/403 (Modo Legado)',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
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

          // ConteÃºdo
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

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          scaffoldContent,
          if (_overlayNotificationText != null)
            Positioned(
              top: 80,
              right: 30,
              child: AnimatedOpacity(
                opacity: _overlayNotificationText != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Text(
                    _overlayNotificationText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
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
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
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
        // â”€â”€ Video Player + Skip Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                    child:
                        _useMediaKit &&
                            _mediaKitPlayer != null &&
                            _mediaKitVideoController != null
                        ? DesktopVideoPlayer(
                            player: _mediaKitPlayer!,
                            controller: _mediaKitVideoController!,
                            title: widget.animeTitle,
                            subtitle:
                                'Episódio ${_extractEpisodeNumber(widget.episode.number)}',
                            onBack: () => Navigator.pop(context),
                            showSkipButton: _showSkipButton,
                            skipButtonLabel: _skipButtonLabel,
                            onSkipIntroOutro: _skipIntroOutro,
                            skipTimes: _skipTimes,
                            onPositionChanged: (_) => _saveWatchProgress(),
                            availableAudioTracks: _availableAudioStreams
                                .map((s) => s.label)
                                .toList(),
                            currentAudioTrack: _availableAudioStreams
                                    .any((s) => s.audioType == _currentAudioType)
                                ? _availableAudioStreams
                                    .firstWhere(
                                        (s) => s.audioType == _currentAudioType)
                                    .label
                                : null,
                            onAudioTrackSelected: (index) {
                              if (index >= 0 &&
                                  index < _availableAudioStreams.length) {
                                _switchAudio(_availableAudioStreams[index]);
                              }
                            },
                          )
                        : (_betterPlayerController != null
                              ? BetterPlayer(
                                  controller: _betterPlayerController!,
                                )
                              : Container(color: Colors.black)),
                  ),
                ),
              ),
              if (!_useMediaKit)
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

        // â”€â”€ Info Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                    top: Radius.circular(20),
                  ),
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
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
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
                                  horizontal: 10,
                                  vertical: 4,
                                ),
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
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.play_circle_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
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

                    if (_availableAudioStreams.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.audiotrack_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Áudio:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _availableAudioStreams.map((stream) {
                                final isSelected =
                                    stream.audioType == _currentAudioType;
                                return InkWell(
                                  onTap: () => _switchAudio(stream),
                                  borderRadius: BorderRadius.circular(16),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: isSelected
                                          ? (stream.isDubbed
                                              ? const LinearGradient(
                                                  colors: [
                                                    Color(0xFF2E7D32),
                                                    Color(0xFF43A047),
                                                  ],
                                                )
                                              : AppColors.getPrimaryGradient())
                                          : null,
                                      color: isSelected
                                          ? null
                                          : Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? (stream.isDubbed
                                                ? const Color(0xFF66BB6A)
                                                : AppColors.primary)
                                            : Colors.white.withValues(alpha: 0.15),
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          stream.label,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white70,
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.check_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Server Info
                    if (_currentVideoUrl != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
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
                              child: const Icon(
                                Icons.dns_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
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
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
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
                              icon: const Icon(
                                Icons.copy_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              tooltip: l10n.copyLink,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
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
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: _ActionButton(
                        icon: Icons.terminal_rounded,
                        label: 'Copiar Comando yt-dlp',
                        onTap: _copyYtDlpCommand,
                        outlined: true,
                      ),
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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// _ActionButton â€“ pill button with gradient or outlined style
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                          colors: [Color(0xFF2A1F1A), Color(0xFF2A1F1A)],
                        )),
            borderRadius: BorderRadius.circular(14),
            border: widget.outlined
                ? Border.all(
                    color: enabled ? AppColors.primary : AppColors.textDisabled,
                    width: 1.5,
                  )
                : null,
            boxShadow: (!widget.outlined && enabled)
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// _LoadingSteps â€“ animated step dots
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _LoadingSteps extends StatefulWidget {
  @override
  State<_LoadingSteps> createState() => _LoadingStepsState();
}

class _LoadingStepsState extends State<_LoadingSteps>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _animation;

  static const _steps = [
    'Obtendo URL do episÃ³dio',
    'Extraindo stream de vÃ­deo',
    'Configurando player',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _animation = Tween<double>(
      begin: 0,
      end: _steps.length.toDouble(),
    ).animate(_ctrl);
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
