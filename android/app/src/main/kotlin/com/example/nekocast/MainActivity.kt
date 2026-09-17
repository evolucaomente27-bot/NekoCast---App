package com.example.nekocast

import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.nekocast/device_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTvDevice" -> {
                    try {
                        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
                        val isTelevisionUi = uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
                        val hasLeanback = packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
                        val isFireTv = Build.MANUFACTURER.equals("Amazon", ignoreCase = true) &&
                            (Build.MODEL.contains("AFT", ignoreCase = true) || packageManager.hasSystemFeature("amazon.hardware.fire_tv"))
                        val hasNoTouch = !packageManager.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)

                        result.success(isTelevisionUi || hasLeanback || isFireTv || hasNoTouch)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
