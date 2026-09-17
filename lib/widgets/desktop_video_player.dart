import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../theme/app_colors.dart';
import '../models/aniskip_models.dart';
import '../services/playback_wake_lock.dart';
import 'skip_button.dart';

class DesktopVideoPlayer extends StatefulWidget {
  final Player player;
  final VideoController controller;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPreviousEpisode;
  final bool hasNextEpisode;
  final bool hasPreviousEpisode;
  final SkipTimes? skipTimes;
  final VoidCallback? onSkipIntroOutro;
  final bool showSkipButton;
  final String skipButtonLabel;
  final Widget? extraActions;
  final ValueChanged<Duration>? onPositionChanged;
  final ValueChanged<Duration>? onDurationChanged;
  final VoidCallback? onCompleted;
  final List<String>? availableAudioTracks;
  final String? currentAudioTrack;
  final ValueChanged<int>? onAudioTrackSelected;

  const DesktopVideoPlayer({
    super.key,
    required this.player,
    required this.controller,
    required this.title,
    this.subtitle,
    this.onBack,
    this.onNextEpisode,
    this.onPreviousEpisode,
    this.hasNextEpisode = false,
    this.hasPreviousEpisode = false,
    this.skipTimes,
    this.onSkipIntroOutro,
    this.showSkipButton = false,
    this.skipButtonLabel = '',
    this.extraActions,
    this.onPositionChanged,
    this.onDurationChanged,
    this.onCompleted,
    this.availableAudioTracks,
    this.currentAudioTrack,
    this.onAudioTrackSelected,
  });

  @override
  State<DesktopVideoPlayer> createState() => _DesktopVideoPlayerState();
}

class _DesktopVideoPlayerState extends State<DesktopVideoPlayer> {
  bool _isPlaying = true;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  double _volume = 100.0;
  double _playbackRate = 1.0;
  double _previousVolume = 100.0;
  BoxFit _videoFit = BoxFit.contain;
  bool _isFullscreen = false;

  bool _showControls = true;
  Timer? _controlsTimer;

  bool _isDraggingSeek = false;
  double _dragPositionSeconds = 0;

  final FocusNode _focusNode = FocusNode();
  String? _overlayMessage;
  IconData? _overlayIcon;
  Timer? _overlayTimer;

  List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    PlaybackWakeLock.acquire();
    _bindPlayer(widget.player);
    _startControlsTimer();
  }

  @override
  void didUpdateWidget(covariant DesktopVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      _bindPlayer(widget.player);
    }
  }

  void _bindPlayer(Player player) {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions = [];

    _isPlaying = player.state.playing;
    _volume = player.state.volume;
    _playbackRate = player.state.rate;
    _position = player.state.position;
    _duration = player.state.duration;
    _buffer = player.state.buffer;
    _isBuffering = player.state.buffering;

    _subscriptions = [
      player.stream.playing.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      }),
      player.stream.position.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
          widget.onPositionChanged?.call(position);
        }
      }),
      player.stream.duration.listen((duration) {
        if (mounted) {
          setState(() => _duration = duration);
          widget.onDurationChanged?.call(duration);
        }
      }),
      player.stream.buffer.listen((buffer) {
        if (mounted) setState(() => _buffer = buffer);
      }),
      player.stream.buffering.listen((buffering) {
        if (mounted) setState(() => _isBuffering = buffering);
      }),
      player.stream.volume.listen((volume) {
        if (mounted) setState(() => _volume = volume);
      }),
      player.stream.rate.listen((rate) {
        if (mounted) setState(() => _playbackRate = rate);
      }),
      player.stream.completed.listen((completed) {
        if (completed && mounted) {
          widget.onCompleted?.call();
        }
      }),
    ];
  }

  @override
  void dispose() {
    PlaybackWakeLock.release();
    _controlsTimer?.cancel();
    _overlayTimer?.cancel();
    _focusNode.dispose();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions = [];
    super.dispose();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying && !_isDraggingSeek) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _onUserInteraction() {
    if (!_showControls) {
      setState(() {
        _showControls = true;
      });
    }
    _startControlsTimer();
  }

  void _showNotification(String message, IconData icon) {
    _overlayTimer?.cancel();
    setState(() {
      _overlayMessage = message;
      _overlayIcon = icon;
    });
    _overlayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _overlayMessage = null;
          _overlayIcon = null;
        });
      }
    });
  }

  void _togglePlayPause() {
    widget.player.playOrPause();
    if (_isPlaying) {
      _showNotification('Pausado', Icons.pause_rounded);
    } else {
      _showNotification('Reproduzindo', Icons.play_arrow_rounded);
    }
    _onUserInteraction();
  }

  void _seekRelative(int seconds) {
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration ? _duration : target);
    widget.player.seek(clamped);
    if (seconds > 0) {
      _showNotification('+$seconds s', Icons.fast_forward_rounded);
    } else {
      _showNotification('$seconds s', Icons.fast_rewind_rounded);
    }
    _onUserInteraction();
  }

  void _adjustVolume(double delta) {
    final newVol = (_volume + delta).clamp(0.0, 100.0);
    widget.player.setVolume(newVol);
    _showNotification(
      'Volume: ${newVol.round()}%',
      newVol == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
    );
    _onUserInteraction();
  }

  void _toggleMute() {
    if (_volume > 0) {
      _previousVolume = _volume;
      widget.player.setVolume(0.0);
      _showNotification('Mudo', Icons.volume_off_rounded);
    } else {
      final restore = _previousVolume > 0 ? _previousVolume : 80.0;
      widget.player.setVolume(restore);
      _showNotification('Volume: ${restore.round()}%', Icons.volume_up_rounded);
    }
    _onUserInteraction();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    _showNotification(
      _isFullscreen ? 'Tela Cheia' : 'Modo Janela',
      _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
    );
    _onUserInteraction();
  }

  void _cycleFit() {
    setState(() {
      if (_videoFit == BoxFit.contain) {
        _videoFit = BoxFit.cover;
        _showNotification('Ajuste: Preencher (Cover)', Icons.aspect_ratio_rounded);
      } else if (_videoFit == BoxFit.cover) {
        _videoFit = BoxFit.fill;
        _showNotification('Ajuste: Esticar (Fill)', Icons.aspect_ratio_rounded);
      } else {
        _videoFit = BoxFit.contain;
        _showNotification('Ajuste: Proporção Original', Icons.aspect_ratio_rounded);
      }
    });
    _onUserInteraction();
  }

  void _setPlaybackRate(double rate) {
    widget.player.setRate(rate);
    _showNotification('Velocidade: ${rate}x', Icons.speed_rounded);
    _onUserInteraction();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      _togglePlayPause();
    } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyL) {
      _seekRelative(10);
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) {
      _seekRelative(-10);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _adjustVolume(5);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _adjustVolume(-5);
    } else if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
    } else if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
    } else if (key == LogicalKeyboardKey.escape) {
      if (_isFullscreen) {
        _toggleFullscreen();
      } else if (widget.onBack != null) {
        widget.onBack!();
      }
    } else if (key == LogicalKeyboardKey.digit0) {
      widget.player.seek(Duration.zero);
      _showNotification('0%', Icons.fast_rewind_rounded);
    } else if (key == LogicalKeyboardKey.digit1) {
      widget.player.seek(_duration * 0.1);
      _showNotification('10%', Icons.fast_forward_rounded);
    } else if (key == LogicalKeyboardKey.digit5) {
      widget.player.seek(_duration * 0.5);
      _showNotification('50%', Icons.fast_forward_rounded);
    } else if (key == LogicalKeyboardKey.digit9) {
      widget.player.seek(_duration * 0.9);
      _showNotification('90%', Icons.fast_forward_rounded);
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDuration = _duration.inMilliseconds > 0 ? _duration : const Duration(seconds: 1);
    final effectivePosition = _isDraggingSeek
        ? Duration(milliseconds: (_dragPositionSeconds * 1000).round())
        : _position;

    final progressValue = (_position.inMilliseconds / effectiveDuration.inMilliseconds).clamp(0.0, 1.0);
    final bufferValue = (_buffer.inMilliseconds / effectiveDuration.inMilliseconds).clamp(0.0, 1.0);

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        onHover: (_) => _onUserInteraction(),
        onEnter: (_) => _onUserInteraction(),
        child: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Native Video Rendering ────────────────────────────────────
              Center(
                child: Video(
                  controller: widget.controller,
                  fit: _videoFit,
                  controls: NoVideoControls,
                ),
              ),

              // ── Click & Gesture Area ─────────────────────────────────────
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _focusNode.requestFocus();
                  _onUserInteraction();
                },
                onDoubleTapDown: (details) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final width = box.size.width;
                  final dx = details.localPosition.dx;
                  if (dx < width * 0.35) {
                    _seekRelative(-10);
                  } else if (dx > width * 0.65) {
                    _seekRelative(10);
                  } else {
                    _toggleFullscreen();
                  }
                },
                child: Container(color: Colors.transparent),
              ),

              // ── Buffering Indicator ──────────────────────────────────────
              if (_isBuffering)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                  ),
                ),

              // ── AniSkip Skip Button Overlay ──────────────────────────────
              if (widget.showSkipButton)
                Positioned(
                  bottom: _showControls ? 96 : 32,
                  right: 24,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 250),
                    offset: Offset.zero,
                    child: SkipButton(
                      onSkip: widget.onSkipIntroOutro ?? () {},
                      label: widget.skipButtonLabel,
                      show: widget.showSkipButton,
                    ),
                  ),
                ),

              // ── Center Notifications (Volume, Seek, State) ───────────────
              if (_overlayMessage != null)
                Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _overlayMessage != null ? 1.0 : 0.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_overlayIcon != null) ...[
                            Icon(_overlayIcon, color: AppColors.primary, size: 24),
                            const SizedBox(width: 12),
                          ],
                          Text(
                            _overlayMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Animated Controls Overlay ─────────────────────────────────
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Stack(
                    children: [
                      // Top Gradient Bar
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.85),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              if (widget.onBack != null)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                                    onPressed: widget.onBack,
                                    tooltip: 'Voltar (Esc)',
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (widget.subtitle != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.subtitle!,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.7),
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (widget.extraActions != null) widget.extraActions!,
                              IconButton(
                                icon: const Icon(Icons.keyboard_outlined, color: Colors.white70),
                                tooltip: 'Atalhos de Teclado',
                                onPressed: _showKeyboardShortcutsDialog,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Center Big Play/Pause Button
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.hasPreviousEpisode)
                              IconButton(
                                iconSize: 36,
                                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white70),
                                tooltip: 'Episódio Anterior',
                                onPressed: widget.onPreviousEpisode,
                              ),
                            const SizedBox(width: 16),
                            IconButton(
                              iconSize: 44,
                              icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                              tooltip: 'Retroceder 10s (← / J)',
                              onPressed: () => _seekRelative(-10),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.getPrimaryGradient(),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                iconSize: 48,
                                icon: Icon(
                                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                ),
                                tooltip: _isPlaying ? 'Pausar (Espaço / K)' : 'Reproduzir (Espaço / K)',
                                onPressed: _togglePlayPause,
                              ),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              iconSize: 44,
                              icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                              tooltip: 'Avançar 10s (→ / L)',
                              onPressed: () => _seekRelative(10),
                            ),
                            const SizedBox(width: 16),
                            if (widget.hasNextEpisode)
                              IconButton(
                                iconSize: 36,
                                icon: const Icon(Icons.skip_next_rounded, color: Colors.white70),
                                tooltip: 'Próximo Episódio',
                                onPressed: widget.onNextEpisode,
                              ),
                          ],
                        ),
                      ),

                      // Bottom Gradient Bar & Controls
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.95),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Progress bar / Slider
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  activeTrackColor: AppColors.primary,
                                  inactiveTrackColor: Colors.white24,
                                  secondaryActiveTrackColor: Colors.white38,
                                  thumbColor: AppColors.primaryLight,
                                  overlayColor: AppColors.primary.withValues(alpha: 0.25),
                                ),
                                child: Slider(
                                  value: _isDraggingSeek ? _dragPositionSeconds : progressValue,
                                  secondaryTrackValue: bufferValue,
                                  onChanged: (val) {
                                    setState(() {
                                      _isDraggingSeek = true;
                                      _dragPositionSeconds = val;
                                    });
                                    _onUserInteraction();
                                  },
                                  onChangeEnd: (val) {
                                    _isDraggingSeek = false;
                                    final target = Duration(
                                      milliseconds: (val * effectiveDuration.inMilliseconds).round(),
                                    );
                                    widget.player.seek(target);
                                    _onUserInteraction();
                                  },
                                ),
                              ),

                              // Bottom Controls Row
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                    ),
                                    onPressed: _togglePlayPause,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_formatDuration(effectivePosition)} / ${_formatDuration(_duration)}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Volume Slider & Button
                                  IconButton(
                                    icon: Icon(
                                      _volume == 0
                                          ? Icons.volume_off_rounded
                                          : (_volume < 50
                                              ? Icons.volume_down_rounded
                                              : Icons.volume_up_rounded),
                                      color: Colors.white,
                                    ),
                                    tooltip: 'Mudo (M)',
                                    onPressed: _toggleMute,
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 3,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                                        activeTrackColor: Colors.white,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: Colors.white,
                                      ),
                                      child: Slider(
                                        value: _volume,
                                        min: 0.0,
                                        max: 100.0,
                                        onChanged: (val) {
                                          widget.player.setVolume(val);
                                          _onUserInteraction();
                                        },
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  // Playback Speed Menu
                                  PopupMenuButton<double>(
                                    icon: Text(
                                      '${_playbackRate}x',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    tooltip: 'Velocidade de Reprodução',
                                    color: const Color(0xFF1E1E2C),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    initialValue: _playbackRate,
                                    onSelected: _setPlaybackRate,
                                    itemBuilder: (context) => [
                                      for (final rate in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                                        PopupMenuItem(
                                          value: rate,
                                          child: Row(
                                            children: [
                                              if (_playbackRate == rate)
                                                const Icon(Icons.check, color: AppColors.primary, size: 18)
                                              else
                                                const SizedBox(width: 18),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${rate}x',
                                                style: TextStyle(
                                                  color: _playbackRate == rate ? AppColors.primary : Colors.white,
                                                  fontWeight: _playbackRate == rate ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                   if (widget.availableAudioTracks != null &&
                                       widget.availableAudioTracks!.length > 1) ...[
                                     const SizedBox(width: 6),
                                     PopupMenuButton<int>(
                                       tooltip: 'Áudio (Dublado / Legendado)',
                                       color: const Color(0xFF1E1E2C),
                                       shape: RoundedRectangleBorder(
                                         borderRadius: BorderRadius.circular(12),
                                       ),
                                       initialValue: widget.availableAudioTracks!
                                           .indexOf(widget.currentAudioTrack ?? ''),
                                       onSelected: widget.onAudioTrackSelected,
                                       itemBuilder: (context) => [
                                         for (int i = 0; i < widget.availableAudioTracks!.length; i++)
                                           PopupMenuItem(
                                             value: i,
                                             child: Row(
                                               children: [
                                                 if (widget.availableAudioTracks![i] == widget.currentAudioTrack)
                                                   const Icon(Icons.check, color: AppColors.primary, size: 18)
                                                 else
                                                   const SizedBox(width: 18),
                                                 const SizedBox(width: 8),
                                                 Text(
                                                   widget.availableAudioTracks![i],
                                                   style: TextStyle(
                                                     color: widget.availableAudioTracks![i] == widget.currentAudioTrack
                                                         ? AppColors.primary
                                                         : Colors.white,
                                                     fontWeight: FontWeight.bold,
                                                   ),
                                                 ),
                                               ],
                                             ),
                                           ),
                                       ],
                                       child: Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                         decoration: BoxDecoration(
                                           color: AppColors.primary.withValues(alpha: 0.2),
                                           borderRadius: BorderRadius.circular(8),
                                           border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                                         ),
                                         child: Row(
                                           mainAxisSize: MainAxisSize.min,
                                           children: [
                                             const Icon(Icons.audiotrack_rounded, color: AppColors.primary, size: 15),
                                             const SizedBox(width: 5),
                                             Text(
                                               widget.currentAudioTrack ?? 'Áudio',
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
                                   ],
                                   const SizedBox(width: 4),
                                   // Aspect Ratio / Fit Button
                                  IconButton(
                                    icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white),
                                    tooltip: 'Ajuste de Tela',
                                    onPressed: _cycleFit,
                                  ),
                                  const SizedBox(width: 4),
                                  // Fullscreen Button
                                  IconButton(
                                    icon: Icon(
                                      _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                                      color: Colors.white,
                                    ),
                                    tooltip: 'Tela Cheia (F)',
                                    onPressed: _toggleFullscreen,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showKeyboardShortcutsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.keyboard_outlined, color: AppColors.primary),
            SizedBox(width: 12),
            Text(
              'Atalhos de Teclado (PC)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildShortcutRow('Espaço / K', 'Play / Pausar'),
              _buildShortcutRow('Seta Direita / L', 'Avançar 10 segundos'),
              _buildShortcutRow('Seta Esquerda / J', 'Retroceder 10 segundos'),
              _buildShortcutRow('Seta Cima / Baixo', 'Aumentar / Diminuir Volume'),
              _buildShortcutRow('M', 'Mutar / Desmutar Áudio'),
              _buildShortcutRow('F', 'Alternar Tela Cheia'),
              _buildShortcutRow('0 - 9', 'Saltar para 0% até 90% do vídeo'),
              _buildShortcutRow('Esc', 'Sair de Tela Cheia / Voltar'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutRow(String keys, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              keys,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              action,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
