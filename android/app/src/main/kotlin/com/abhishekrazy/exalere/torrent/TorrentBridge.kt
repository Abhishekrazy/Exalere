package com.abhishekrazy.exalere.torrent

/**
 * Flavour seam for the bundled P2P engine.
 *
 * The `github` build ships libtorrent; the `play` build ships no torrent code at
 * all. `MainActivity` lives in the shared `main` source set, so it can only refer
 * to this interface and to [TorrentBridgeFactory] — never to `TorrentChannel`
 * directly, which would not compile for the flavour that omits it.
 */
interface TorrentBridge {
    fun dispose()
}
