package com.abhishekrazy.exalere.torrent

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger

/**
 * `play` distribution: this build intentionally contains **no torrent code and no
 * libtorrent binaries**.
 *
 * Google Play's Device and Network Abuse policy restricts apps that facilitate
 * unauthorised peer-to-peer streaming, so the Play artefact does not bundle a
 * BitTorrent engine at all. Peer-to-peer playback in this build comes from an
 * external engine the user installs themselves (a companion torrent service such
 * as TorrServe) reached over loopback HTTP — see `TorrentService` on the Dart side.
 */
object TorrentBridgeFactory {
    private const val TAG = "TorrentBridgeFactory"

    fun create(appContext: Context, messenger: BinaryMessenger): TorrentBridge? {
        Log.i(TAG, "Play build: bundled torrent engine is not included.")
        return null
    }
}
