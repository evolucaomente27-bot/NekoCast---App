import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the device awake while one or more video screens are open.
class PlaybackWakeLock {
  PlaybackWakeLock._();

  static int _leases = 0;
  static bool _observerRegistered = false;
  static final _lifecycleObserver = _PlaybackLifecycleObserver();

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> acquire() async {
    _leases++;
    if (_leases == 1) {
      _registerObserver();
      await _setEnabled(true);
    }
  }

  static Future<void> release() async {
    if (_leases == 0) return;
    _leases--;
    if (_leases == 0) {
      _unregisterObserver();
      await _setEnabled(false);
    }
  }

  static void _registerObserver() {
    if (_observerRegistered) return;
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _observerRegistered = true;
  }

  static void _unregisterObserver() {
    if (!_observerRegistered) return;
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _observerRegistered = false;
  }

  static Future<void> _setEnabled(bool enabled) async {
    if (!_supported) return;
    try {
      await WakelockPlus.toggle(enable: enabled);
    } catch (error) {
      debugPrint('[PlaybackWakeLock] Could not set wake lock: $error');
    }
  }
}

class _PlaybackLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && PlaybackWakeLock._leases > 0) {
      unawaited(PlaybackWakeLock._setEnabled(true));
    }
  }
}
