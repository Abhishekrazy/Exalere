package com.abhishekrazy.exalere.torrent

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger

/**
 * `github` distribution: the bundled libtorrent engine is present, so the torrent
 * MethodChannel is registered and magnets can be resolved in-app.
 *
 * The `play` flavour compiles its own copy of this file that returns `null`, which
 * is what keeps torrent code out of the Play artefact entirely.
 */
object TorrentBridgeFactory {
    private const val TAG = "TorrentBridgeFactory"

    fun create(appContext: Context, messenger: BinaryMessenger): TorrentBridge? {
        return try {
            val channel = TorrentChannel(appContext)
            channel.attach(messenger)
            object : TorrentBridge {
                override fun dispose() = channel.dispose()
            }
        } catch (e: Throwable) {
            // A device without the native library must degrade to "no in-app P2P"
            // rather than taking the app down on startup.
            Log.w(TAG, "Bundled torrent engine unavailable", e)
            null
        }
    }
}
