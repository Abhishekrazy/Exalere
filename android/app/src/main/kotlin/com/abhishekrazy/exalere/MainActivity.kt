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
import android.os.Environment
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
    private val EXTERNAL_PLAYER_CHANNEL = "com.exalere/external_player"
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
                    val hasTelevisionMode = uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
                    val hasLeanbackFeature = packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
                               packageManager.hasSystemFeature("android.software.leanback")
                    val hasTvFeature = packageManager.hasSystemFeature("android.hardware.type.television") ||
                               packageManager.hasSystemFeature("amazon.hardware.fire_tv")
                    val hasNoTouchScreen = !packageManager.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)
                    val isTv = hasTelevisionMode || hasLeanbackFeature || hasTvFeature || hasNoTouchScreen
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
                "getVideoCacheDir" -> {
                    try {
                        val cache = externalCacheDir ?: cacheDir
                        val videoCacheDir = File(cache, "exalere_video_cache")
                        if (!videoCacheDir.exists()) {
                            videoCacheDir.mkdirs()
                        }
                        result.success(videoCacheDir.absolutePath)
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", e.message, null)
                    }
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
                "getDownloadsStorageDir" -> {
                    try {
                        val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                        val appDownloads = File(downloadsDir, "Exalere")
                        if (!appDownloads.exists()) {
                            appDownloads.mkdirs()
                        }
                        result.success(appDownloads.absolutePath)
                    } catch (e: Exception) {
                        val fallback = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir
                        val fallbackDir = File(fallback, "downloads")
                        if (!fallbackDir.exists()) {
                            fallbackDir.mkdirs()
                        }
                        result.success(fallbackDir.absolutePath)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EXTERNAL_PLAYER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "detectPlayers" -> {
                    try {
                        val detected = mutableListOf<String>()
                        val knownPackages = listOf(
                            "org.videolan.vlc" to "VLC",
                            "com.brouken.player" to "Just Player",
                            "com.mxtech.videoplayer.ad" to "MX Player",
                            "com.mxtech.videoplayer.pro" to "MX Player Pro",
                            "org.courville.nova" to "Nova Video Player",
                            "org.xbmc.kodi" to "Kodi",
                            "dev.anilbeesetti.nextplayer" to "Next Player",
                            "net.gtvbox.videoplayer" to "Vimu Player",
                            "ru.yourok.torrserve" to "TorrServe"
                        )
                        for ((pkg, name) in knownPackages) {
                            if (isPackageInstalled(pkg) && !detected.contains(name)) {
                                detected.add(name)
                            }
                        }
                        result.success(detected)
                    } catch (e: Exception) {
                        result.error("DETECT_ERROR", e.message, null)
                    }
                }
                "launchPlayer" -> {
                    try {
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank()) {
                            result.error("INVALID_URL", "URL must not be null or blank", null)
                            return@setMethodCallHandler
                        }
                        val title = call.argument<String>("title")
                        val headers = call.argument<Map<String, String>>("headers")
                        val startSeconds = call.argument<Int>("startSeconds") ?: 0
                        val preferred = call.argument<String>("preferredPlayer")

                        val isMagnet = url.startsWith("magnet:", ignoreCase = true)
                        val uri = Uri.parse(url)
                        val intent = Intent(Intent.ACTION_VIEW)

                        if (isMagnet) {
                            intent.data = uri
                        } else {
                            val lower = url.lowercase()
                            val mimeType = when {
                                lower.contains(".mp4") -> "video/mp4"
                                lower.contains(".mkv") -> "video/x-matroska"
                                lower.contains(".webm") -> "video/webm"
                                else -> "video/*"
                            }
                            intent.setDataAndType(uri, mimeType)
                        }

                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION

                        if (!title.isNullOrBlank()) {
                            intent.putExtra("title", title)
                            intent.putExtra("android.intent.extra.TITLE", title)
                        }
                        if (startSeconds > 0) {
                            intent.putExtra("position", startSeconds * 1000)
                            intent.putExtra("return_result", true)
                        }

                        if (headers != null && headers.isNotEmpty()) {
                            val headerList = arrayListOf<String>()
                            for ((k, v) in headers) {
                                headerList.add(k)
                                headerList.add(v)
                            }
                            intent.putExtra("headers", headerList.toTypedArray())
                        }

                        var targetPackage: String? = null
                        if (!preferred.isNullOrBlank()) {
                            val p = preferred.lowercase()
                            targetPackage = when {
                                p.contains("vlc") -> "org.videolan.vlc"
                                p.contains("just") -> "com.brouken.player"
                                p.contains("mx") -> {
                                    if (isPackageInstalled("com.mxtech.videoplayer.pro")) "com.mxtech.videoplayer.pro"
                                    else if (isPackageInstalled("com.mxtech.videoplayer.ad")) "com.mxtech.videoplayer.ad"
                                    else null
                                }
                                p.contains("nova") -> "org.courville.nova"
                                p.contains("kodi") -> "org.xbmc.kodi"
                                p.contains("torrserve") -> "ru.yourok.torrserve"
                                else -> null
                            }
                        }

                        if (targetPackage == null) {
                            val knownPackages = listOf(
                                "com.brouken.player",
                                "org.videolan.vlc",
                                "com.mxtech.videoplayer.pro",
                                "com.mxtech.videoplayer.ad",
                                "org.courville.nova",
                                "dev.anilbeesetti.nextplayer",
                                "net.gtvbox.videoplayer",
                                "org.xbmc.kodi",
                                "ru.yourok.torrserve"
                            )
                            for (pkg in knownPackages) {
                                if (isPackageInstalled(pkg)) {
                                    targetPackage = pkg
                                    break
                                }
                            }
                        }

                        if (targetPackage != null && isPackageInstalled(targetPackage)) {
                            intent.setPackage(targetPackage)
                            startActivity(intent)
                            result.success(true)
                            return@setMethodCallHandler
                        }

                        val resolved = packageManager.queryIntentActivities(intent, 0)
                        if (resolved.isNotEmpty()) {
                            val chooser = Intent.createChooser(intent, "Play with External Player").apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(chooser)
                            result.success(true)
                        } else {
                            val fallbackIntent = Intent(Intent.ACTION_VIEW, uri).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            if (fallbackIntent.resolveActivity(packageManager) != null) {
                                startActivity(fallbackIntent)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        }
                    } catch (e: Exception) {
                        result.error("LAUNCH_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isPackageInstalled(pkg: String): Boolean {
        return try {
            packageManager.getPackageInfo(pkg, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
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
