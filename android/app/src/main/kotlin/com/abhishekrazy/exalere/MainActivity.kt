package com.abhishekrazy.exalere

import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.exalere/tv_mode"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isTv") {
                val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
                val isTv = uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
                           packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
                           packageManager.hasSystemFeature("android.hardware.type.television") ||
                           packageManager.hasSystemFeature("android.software.leanback")
                result.success(isTv)
            } else {
                result.notImplemented()
            }
        }
    }
}
