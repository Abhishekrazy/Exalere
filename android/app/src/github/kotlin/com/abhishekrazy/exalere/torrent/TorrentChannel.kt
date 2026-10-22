package com.abhishekrazy.exalere.torrent

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * MethodChannel front end for the torrent engine.
 *
 * Every libtorrent call blocks (waiting for metadata, for pieces, for a flush),
 * so nothing here runs on the platform thread. Results are posted back to the
 * main thread because that is where Flutter's [MethodChannel.Result] must be
 * completed.
 */
class TorrentChannel(private val appContext: Context) {

    companion object {
        const val CHANNEL = "com.exalere/torrent"
        private const val TAG = "TorrentChannel"
    }

    private val engine = TorrentEngine(appContext)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "ExalereTorrentIO").apply { isDaemon = true }
    }

    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        val methodChannel = MethodChannel(messenger, CHANNEL)
        channel = methodChannel
        methodChannel.setMethodCallHandler { call, result -> handle(call, result) }
    }

    fun dispose() {
        channel?.setMethodCallHandler(null)
        channel = null
        executor.execute {
            try {
                engine.shutdown()
            } catch (e: Exception) {
                Log.w(TAG, "Shutdown failed", e)
            }
        }
        executor.shutdown()
    }

    // ---------------------------------------------------------------------

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(true)

            "init" -> background(result) {
                val running = engine.ensureSession().isRunning
                mapOf("running" to running, "port" to engine.streamPort)
            }

            "addMagnet" -> background(result) {
                val magnet = call.argument<String>("magnet")
                    ?: throw IllegalArgumentException("magnet is required")
                val folder = call.argument<String>("outputFolder")
                val name = call.argument<String>("name")
                engine.addTorrent(magnet, folder, name)
            }

            "prepare" -> background(result) {
                val infoHash = call.argument<String>("infoHash")
                    ?: throw IllegalArgumentException("infoHash is required")
                val fileIndex = call.argument<Int>("fileIndex") ?: 0
                val resuming = call.argument<Boolean>("resuming") ?: false
                engine.prepare(infoHash, fileIndex, resuming)
            }

            "getStreamUrl" -> background(result) {
                val infoHash = call.argument<String>("infoHash")
                    ?: throw IllegalArgumentException("infoHash is required")
                val fileIndex = call.argument<Int>("fileIndex") ?: 0
                val fileName = engine.mediaFile(infoHash, fileIndex)?.name ?: "video"
                engine.ensureServer().streamUrl(infoHash, fileIndex, fileName)
            }

            "stats" -> background(result) {
                val infoHash = call.argument<String>("infoHash")
                    ?: throw IllegalArgumentException("infoHash is required")
                engine.stats(infoHash)
            }

            "stop" -> background(result) {
                val infoHash = call.argument<String>("infoHash")
                    ?: throw IllegalArgumentException("infoHash is required")
                engine.stop(infoHash, call.argument<Boolean>("deleteFiles") ?: true)
                null
            }

            "shutdown" -> background(result) {
                engine.shutdown()
                null
            }

            else -> result.notImplemented()
        }
    }

    /** Runs [block] off the platform thread and completes [result] on the main one. */
    private fun background(
        result: MethodChannel.Result,
        block: () -> Any?,
    ) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: Throwable) {
                Log.e(TAG, "Torrent call failed", e)
                val message = e.message ?: e.javaClass.simpleName
                mainHandler.post {
                    result.error("TORRENT_ERROR", message, null)
                }
            }
        }
    }
}
