import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TvModeService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.nekocast/device_info');
  static const String _prefTvMode = 'nekocast_tv_mode_enabled';
  static const String _prefOverscan = 'nekocast_tv_overscan_enabled';

  bool _isTvMode = false;
  bool _isAutoDetectedTv = false;
  bool _overscanCompensation = true;
  bool _isInitialized = false;

  bool get isTvMode => _isTvMode;
  bool get isAutoDetectedTv => _isAutoDetectedTv;
  bool get overscanCompensation => _overscanCompensation;
  bool get isInitialized => _isInitialized;

  EdgeInsets get tvSafePadding => (_isTvMode && _overscanCompensation)
      ? const EdgeInsets.symmetric(horizontal: 28, vertical: 18)
      : EdgeInsets.zero;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _overscanCompensation = prefs.getBool(_prefOverscan) ?? true;

      // 1. Check auto-detection via MethodChannel (Android / Fire OS)
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final isTv = await _channel.invokeMethod<bool>('isTvDevice');
          _isAutoDetectedTv = isTv ?? false;
        } catch (e) {
          debugPrint('[TvModeService] Error detecting TV device: $e');
          _isAutoDetectedTv = false;
        }
      }

      // 2. Check saved preference or fallback to auto-detected status
      final savedTvMode = prefs.getBool(_prefTvMode);
      if (savedTvMode != null) {
        _isTvMode = savedTvMode;
      } else {
        _isTvMode = _isAutoDetectedTv;
      }

      // 3. Apply orientation if TV mode is active
      _applyOrientationLock();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[TvModeService] Failed to initialize TvModeService: $e');
      _isInitialized = true;
    }
  }

  Future<void> setTvMode(bool enabled) async {
    if (_isTvMode == enabled) return;
    _isTvMode = enabled;
    _applyOrientationLock();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefTvMode, enabled);
    } catch (e) {
      debugPrint('[TvModeService] Error saving TV mode preference: $e');
    }
  }

  Future<void> setOverscanCompensation(bool enabled) async {
    if (_overscanCompensation == enabled) return;
    _overscanCompensation = enabled;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefOverscan, enabled);
    } catch (e) {
      debugPrint('[TvModeService] Error saving overscan preference: $e');
    }
  }

  void _applyOrientationLock() {
    if (kIsWeb) return;
    if (Platform.isAndroid || Platform.isIOS) {
      if (_isTvMode) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    }
  }
}
