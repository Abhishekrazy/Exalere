package com.abhishekrazy.exalere

import android.app.PictureInPictureParams
import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.media.AudioManager
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import android.util.Rational
import android.view.WindowManager
import androidx.core.content.FileProvider
import java.io.File
import kotlin.math.roundToInt
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.exalere/tv_mode"
    private val MULTICAST_CHANNEL = "com.exalere/multicast_lock"
    private val DEVICE_CONTROLS_CHANNEL = "com.exalere/device_controls"
    private val INSTALLER_CHANNEL = "com.exalere/app_installer"
    private val PIP_CHANNEL = "com.exalere/pip"
    private var multicastLock: WifiManager.MulticastLock? = null
    private var pipMethodChannel: MethodChannel? = null
    private var autoEnterPip: Boolean = false
    private var pipAspectRatio: Rational? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTv" -> {
                    val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
                    val isTv = uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
                               packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
                               packageManager.hasSystemFeature("android.hardware.type.television") ||
                               packageManager.hasSystemFeature("android.software.leanback")
                    result.success(isTv)
                }
                "getSupportedAbis" -> {
                    val abis = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        Build.SUPPORTED_ABIS.toList()
                    } else {
                        listOfNotNull(Build.CPU_ABI, Build.CPU_ABI2)
                    }
                    result.success(abis)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MULTICAST_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    try {
                        if (multicastLock == null) {
                            val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                            multicastLock = wifi?.createMulticastLock("ExalereMulticastLock")?.apply {
                                setReferenceCounted(true)
                            }
                        }
                        multicastLock?.acquire()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LOCK_ERROR", e.message, null)
                    }
                }
                "release" -> {
                    try {
                        if (multicastLock?.isHeld == true) {
                            multicastLock?.release()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LOCK_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CONTROLS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setBrightness" -> {
                    try {
                        val brightness = call.argument<Double>("brightness")?.toFloat() ?: -1.0f
                        val activity = this@MainActivity
                        activity.runOnUiThread {
                            val lp = activity.window.attributes
                            lp.screenBrightness = if (brightness < 0f) {
                                WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                            } else {
                                brightness.coerceIn(0.01f, 1.0f)
                            }
                            activity.window.attributes = lp
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BRIGHTNESS_ERROR", e.message, null)
                    }
                }
                "getBrightness" -> {
                    try {
                        val lp = window.attributes
                        var cur = lp.screenBrightness
                        if (cur < 0f) {
                            try {
                                val sys = android.provider.Settings.System.getInt(
                                    contentResolver,
                                    android.provider.Settings.System.SCREEN_BRIGHTNESS
                                )
                                cur = sys / 255.0f
                            } catch (_: Exception) {
                                cur = 0.5f
                            }
                        }
                        result.success(cur.toDouble())
                    } catch (e: Exception) {
                        result.success(0.5)
                    }
                }
                "resetBrightness" -> {
                    try {
                        val activity = this@MainActivity
                        activity.runOnUiThread {
                            val lp = activity.window.attributes
                            lp.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                            activity.window.attributes = lp
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("RESET_ERROR", e.message, null)
                    }
                }
                "setVolume" -> {
                    try {
                        val fraction = call.argument<Double>("volume") ?: 0.5
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                        if (audioManager != null) {
                            val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                            val targetVol = (fraction * maxVol).roundToInt().coerceIn(0, maxVol)
                            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVol, 0)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("VOLUME_ERROR", e.message, null)
                    }
                }
                "getVolume" -> {
                    try {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                        if (audioManager != null) {
                            val curVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                            val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                            val fraction = if (maxVol > 0) curVol.toDouble() / maxVol.toDouble() else 0.5
                            result.success(fraction)
                        } else {
                            result.success(0.5)
                        }
                    } catch (e: Exception) {
                        result.success(0.5)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    try {
                        val canInstall = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            packageManager.canRequestPackageInstalls()
                        } else {
                            true
                        }
                        result.success(canInstall)
                    } catch (e: Exception) {
                        result.error("PERMISSION_CHECK_ERROR", e.message, null)
                    }
                }
                "openInstallPermissionSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "getUpdateStorageDir" -> {
                    try {
                        val cache = externalCacheDir ?: cacheDir
                        val updateDir = File(cache, "updates")
                        if (!updateDir.exists()) {
                            updateDir.mkdirs()
                        }
                        result.success(updateDir.absolutePath)
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", e.message, null)
                    }
                }
                "installApk" -> {
                    try {
                        val filePath = call.argument<String>("filePath")
                        if (filePath.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "filePath must not be null or empty", null)
                            return@setMethodCallHandler
                        }
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "File does not exist at $filePath", null)
                            return@setMethodCallHandler
                        }
                        val apkUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            FileProvider.getUriForFile(
                                applicationContext,
                                "${applicationContext.packageName}.fileprovider",
                                file
                            )
                        } else {
                            Uri.fromFile(file)
                        }
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        pipMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPipSupported" -> {
                        val supported = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
                        } else {
                            false
                        }
                        result.success(supported)
                    }
                    "enterPip" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val num = call.argument<Int>("numerator") ?: 16
                            val den = call.argument<Int>("denominator") ?: 9
                            val rational = getSafePipRational(num, den)
                            val builder = PictureInPictureParams.Builder()
                                .setAspectRatio(rational)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                builder.setSeamlessResizeEnabled(true)
                            }
                            try {
                                val entered = enterPictureInPictureMode(builder.build())
                                result.success(entered)
                            } catch (e: Exception) {
                                result.error("PIP_ERROR", e.message, null)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    "setPipAutoEnterEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val num = call.argument<Int>("numerator") ?: 16
                        val den = call.argument<Int>("denominator") ?: 9
                        autoEnterPip = enabled
                        val rational = getSafePipRational(num, den)
                        pipAspectRatio = rational
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            try {
                                val builder = PictureInPictureParams.Builder()
                                    .setAspectRatio(rational)
                                    .setAutoEnterEnabled(enabled)
                                    .setSeamlessResizeEnabled(true)
                                setPictureInPictureParams(builder.build())
                            } catch (_: Exception) {}
                        }
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }
    }

    private fun getSafePipRational(num: Int, den: Int): Rational {
        if (den <= 0 || num <= 0) return Rational(16, 9)
        val ratio = num.toDouble() / den.toDouble()
        return when {
            ratio < 0.41841 -> Rational(1000, 2390)
            ratio > 2.3900 -> Rational(2390, 1000)
            else -> {
                val gcdVal = gcd(num, den)
                val sNum = (num / gcdVal).coerceIn(1, 10000)
                val sDen = (den / gcdVal).coerceIn(1, 10000)
                Rational(sNum, sDen)
            }
        }
    }

    private fun gcd(a: Int, b: Int): Int {
        var n1 = a
        var n2 = b
        while (n2 != 0) {
            val temp = n2
            n2 = n1 % n2
            n1 = temp
        }
        return if (n1 > 0) n1 else 1
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (autoEnterPip && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            try {
                val rational = pipAspectRatio ?: Rational(16, 9)
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(rational)
                    .build()
                enterPictureInPictureMode(params)
            } catch (_: Exception) {}
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipMethodChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }

    override fun onDestroy() {
        if (multicastLock?.isHeld == true) {
            multicastLock?.release()
        }
        try {
            val lp = window.attributes
            lp.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
            window.attributes = lp
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
