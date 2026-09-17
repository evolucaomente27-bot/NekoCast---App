import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PreferredAudio {
  dubbed,
  subbed,
}

enum PlayerEngine {
  mediaKit,
  betterPlayer,
  externalApp,
}

class PlayerService extends ChangeNotifier {
  static const String _prefKey = 'nekocast_player_engine';
  static const String _prefAudioKey = 'nekocast_preferred_audio';

  PlayerEngine _currentEngine = (kIsWeb || (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS))
      ? PlayerEngine.betterPlayer
      : PlayerEngine.mediaKit;

  PreferredAudio _preferredAudio = PreferredAudio.dubbed;

  PlayerEngine get currentEngine => _currentEngine;
  PreferredAudio get preferredAudio => _preferredAudio;

  bool get isMediaKit => _currentEngine == PlayerEngine.mediaKit;
  bool get isBetterPlayer => _currentEngine == PlayerEngine.betterPlayer;
  bool get isExternalApp => _currentEngine == PlayerEngine.externalApp;
  bool get isDubbedPreferred => _preferredAudio == PreferredAudio.dubbed;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedValue = prefs.getString(_prefKey);
      final savedAudio = prefs.getString(_prefAudioKey);

      if (savedAudio != null) {
        if (savedAudio == PreferredAudio.dubbed.name) {
          _preferredAudio = PreferredAudio.dubbed;
        } else if (savedAudio == PreferredAudio.subbed.name) {
          _preferredAudio = PreferredAudio.subbed;
        }
      }

      if (savedValue != null) {
        if (savedValue == PlayerEngine.mediaKit.name) {
          _currentEngine = PlayerEngine.mediaKit;
        } else if (savedValue == PlayerEngine.betterPlayer.name) {
          _currentEngine = PlayerEngine.betterPlayer;
        } else if (savedValue == PlayerEngine.externalApp.name) {
          _currentEngine = PlayerEngine.externalApp;
        }
      } else {
        // Default engine by platform
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          _currentEngine = PlayerEngine.mediaKit;
        } else {
          _currentEngine = PlayerEngine.betterPlayer;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[PlayerService] Error loading preferences: $e');
    }
  }

  Future<void> setPreferredAudio(PreferredAudio audio) async {
    if (_preferredAudio == audio) return;
    _preferredAudio = audio;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefAudioKey, audio.name);
      debugPrint('[PlayerService] Saved preferred audio: ${audio.name}');
    } catch (e) {
      debugPrint('[PlayerService] Error saving preferred audio: $e');
    }
  }

  Future<void> setEngine(PlayerEngine engine) async {
    if (_currentEngine == engine) return;
    _currentEngine = engine;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, engine.name);
      debugPrint('[PlayerService] Saved player engine: ${engine.name}');
    } catch (e) {
      debugPrint('[PlayerService] Error saving player engine preference: $e');
    }
  }

  String getAudioDisplayName(PreferredAudio audio, {bool isPt = true}) {
    switch (audio) {
      case PreferredAudio.dubbed:
        return isPt ? 'Dublado (PT-BR)' : 'Dubbed';
      case PreferredAudio.subbed:
        return isPt ? 'Legendado (Original)' : 'Subbed';
    }
  }

  String getEngineDisplayName(PlayerEngine engine, {bool isPt = true}) {
    switch (engine) {
      case PlayerEngine.mediaKit:
        return 'Neko Native Player (MediaKit / MPV)';
      case PlayerEngine.betterPlayer:
        return 'BetterPlayer (Mobile)';
      case PlayerEngine.externalApp:
        return isPt ? 'Player Externo (VLC / MPC-HC)' : 'External Player (VLC / MPC-HC)';
    }
  }

  String getEngineDescription(PlayerEngine engine, {bool isPt = true}) {
    switch (engine) {
      case PlayerEngine.mediaKit:
        return isPt
            ? 'Motor nativo com aceleração por GPU (DirectX), suporte a 4K, atalhos de teclado e alta fluidez no Windows/Desktop.'
            : 'Native engine with GPU acceleration (DirectX), 4K support, keyboard shortcuts and smooth playback on Windows/Desktop.';
      case PlayerEngine.betterPlayer:
        return isPt
            ? 'Reprodutor leve com foco em compatibilidade mobile (Android/iOS).'
            : 'Lightweight player focused on mobile compatibility (Android/iOS).';
      case PlayerEngine.externalApp:
        return isPt
            ? 'Abre o link do vídeo diretamente no aplicativo padrão do sistema (VLC, MPC-HC, etc).'
            : 'Opens the video stream directly in the default system app (VLC, MPC-HC, etc).';
    }
  }
}
