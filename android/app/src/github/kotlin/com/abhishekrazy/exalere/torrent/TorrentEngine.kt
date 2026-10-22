package com.abhishekrazy.exalere.torrent

import android.content.Context
import android.util.Log
import org.libtorrent4j.AlertListener
import org.libtorrent4j.FileStorage
import org.libtorrent4j.Priority
import org.libtorrent4j.SessionManager
import org.libtorrent4j.SessionParams
import org.libtorrent4j.SettingsPack
import org.libtorrent4j.Sha1Hash
import org.libtorrent4j.TorrentFlags
import org.libtorrent4j.TorrentHandle
import org.libtorrent4j.TorrentStatus
import org.libtorrent4j.alerts.AddTorrentAlert
import org.libtorrent4j.alerts.Alert
import org.libtorrent4j.alerts.MetadataFailedAlert
import org.libtorrent4j.alerts.MetadataReceivedAlert
import org.libtorrent4j.swig.settings_pack
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * In-app BitTorrent engine backed by libtorrent (through libtorrent4j).
 *
 * Playback is streaming rather than downloading: only the byte ranges a player
 * actually asks for are promoted, so opening a 60 GB torrent does not start a
 * 60 GB download. The opening window and the file tail are promoted up front
 * because container metadata lives at the end for MKV (cues) and often for MP4
 * (`moov`), and players read it before they will start.
 */
class TorrentEngine(private val appContext: Context) : TorrentStreamSource {

    companion object {
        private const val TAG = "TorrentEngine"

        /** Promoted before playback so the player has a running start. */
        private const val STARTUP_BYTES = 8L * 1024 * 1024

        /** Promoted up front: MKV cues / trailing MP4 moov live here. */
        private const val TAIL_BYTES = 2L * 1024 * 1024

        /** Resuming starts mid-file, so only the container header is needed. */
        private const val RESUME_HEADER_BYTES = 2L * 1024 * 1024

        private const val PREPARE_TIMEOUT_MS = 60_000L
        private const val METADATA_TIMEOUT_SECONDS = 45L

        /**
         * Magnets from providers frequently carry no trackers, which leaves peer
         * discovery to the DHT alone. These public trackers find peers in seconds.
         */
        private val PUBLIC_TRACKERS = listOf(
            "udp://tracker.opentrackr.org:1337/announce",
            "udp://open.demonii.com:1337/announce",
            "udp://open.stealth.si:80/announce",
            "udp://tracker.torrent.eu.org:451/announce",
            "udp://exodus.desync.com:6969/announce",
            "udp://explodie.org:6969/announce",
            "udp://tracker.tiny-vps.com:6969/announce",
            "udp://tracker.openbittorrent.com:6969/announce",
        )
    }

    private var sessionManager: SessionManager? = null
    private var streamServer: TorrentStreamServer? = null

    private val handles = ConcurrentHashMap<String, TorrentHandle>()
    private val saveDirs = ConcurrentHashMap<String, File>()
    private val selectedFiles = ConcurrentHashMap<String, Int>()
    private val outputNames = ConcurrentHashMap<String, String>()

    // ---------------------------------------------------------------------
    // Lifecycle
    // ---------------------------------------------------------------------

    @Synchronized
    fun ensureSession(): SessionManager {
        sessionManager?.let { if (it.isRunning) return it }

        val manager = SessionManager(false)
        val settings = SettingsPack()
        settings.setEnableDht(true)
        settings.setEnableLsd(true)
        settings.listenInterfaces("0.0.0.0:6881,0.0.0.0:6891")
        settings.setDhtBootstrapNodes(
            "router.bittorrent.com:6881,dht.transmissionbt.com:6881," +
                "router.utorrent.com:6881,dht.aelitis.com:6881",
        )
        // Streaming waits on individual pieces, so a slow peer must not hold a
        // block for libtorrent's default 20 s piece / 60 s request timeout
        // before it is re-requested from someone else.
        settings.setInteger(settings_pack.int_types.piece_timeout.swigValue(), 6)
        settings.setInteger(settings_pack.int_types.request_timeout.swigValue(), 12)
        settings.setInteger(settings_pack.int_types.peer_connect_timeout.swigValue(), 7)
        // Connect to more peers immediately so the first pieces arrive sooner.
        settings.setInteger(settings_pack.int_types.torrent_connect_boost.swigValue(), 60)
        settings.setInteger(settings_pack.int_types.connection_speed.swigValue(), 60)
        settings.setBoolean(settings_pack.bool_types.strict_end_game_mode.swigValue(), false)
        settings.setBoolean(settings_pack.bool_types.announce_to_all_trackers.swigValue(), true)
        settings.setBoolean(settings_pack.bool_types.announce_to_all_tiers.swigValue(), true)

        manager.start(SessionParams(settings))
        sessionManager = manager
        Log.d(TAG, "Session started, running=${manager.isRunning}")
        return manager
    }

    @Synchronized
    fun ensureServer(): TorrentStreamServer {
        streamServer?.let { return it }
        val server = TorrentStreamServer(this)
        server.start()
        streamServer = server
        Log.d(TAG, "Stream server on port ${server.listeningPort}")
        return server
    }

    val streamPort: Int get() = ensureServer().listeningPort

    fun isSessionRunning(): Boolean = sessionManager?.isRunning == true

    /** Stops everything and releases native resources. */
    @Synchronized
    fun shutdown() {
        streamServer?.stop()
        streamServer = null
        try {
            sessionManager?.stop()
        } catch (e: Exception) {
            Log.w(TAG, "Session stop failed", e)
        }
        sessionManager = null
        handles.clear()
        saveDirs.clear()
        selectedFiles.clear()
        outputNames.clear()
    }

    // ---------------------------------------------------------------------
    // Adding torrents
    // ---------------------------------------------------------------------

    private fun withPublicTrackers(magnet: String): String {
        val builder = StringBuilder(magnet)
        for (tracker in PUBLIC_TRACKERS) {
            val encoded = java.net.URLEncoder.encode(tracker, "UTF-8")
            if (!magnet.contains(encoded) && !magnet.contains(tracker)) {
                builder.append("&tr=").append(encoded)
            }
        }
        return builder.toString()
    }

    private fun infoHashOf(magnet: String): String? =
        Regex("btih:([a-fA-F0-9]{40})", RegexOption.IGNORE_CASE)
            .find(magnet)
            ?.groupValues
            ?.get(1)
            ?.lowercase()

    /**
     * Adds a magnet URI and waits for metadata. Returns a map describing the
     * torrent, or throws so the channel can report a useful error.
     */
    fun addTorrent(magnet: String, outputFolder: String?, rename: String?): Map<String, Any?> {
        val expectedHash = infoHashOf(magnet)
            ?: throw IllegalArgumentException("Not a magnet URI with a btih hash")

        val manager = ensureSession()
        val server = ensureServer()

        val downloadDir = File(outputFolder ?: defaultDownloadDir().absolutePath)
        if (!downloadDir.exists() && !downloadDir.mkdirs()) {
            throw IllegalStateException("Cannot create ${downloadDir.absolutePath}")
        }

        // Already added and ready: reuse it.
        handles[expectedHash]?.let { existing ->
            if (existing.isValid) {
                try {
                    if (existing.status().hasMetadata()) {
                        selectedFiles.putIfAbsent(expectedHash, largestFileIndex(existing))
                        server.streamUrl(expectedHash, selectedFiles[expectedHash] ?: 0, "video")
                        return describeTorrent(existing)
                    }
                } catch (_: Exception) {
                    handles.remove(expectedHash)
                }
            }
        }

        var addError: String? = null
        val metadataLatch = CountDownLatch(1)

        val listener = object : AlertListener {
            override fun types(): IntArray? = null

            override fun alert(alert: Alert<*>) {
                when (alert) {
                    is AddTorrentAlert -> {
                        if (alert.error().isError) {
                            addError = alert.error().toString()
                            metadataLatch.countDown()
                            return
                        }
                        val handle = alert.handle()
                        val hash = try {
                            handle.infoHash().toHex()
                        } catch (_: Exception) {
                            return
                        }
                        if (hash != expectedHash) return
                        try {
                            handles[hash] = handle
                            saveDirs[hash] = downloadDir
                            if (handle.status().hasMetadata()) metadataLatch.countDown()
                        } catch (_: Exception) {
                        }
                    }

                    is MetadataReceivedAlert -> {
                        val hash = try {
                            alert.handle().infoHash().toHex()
                        } catch (_: Exception) {
                            return
                        }
                        if (hash == expectedHash) metadataLatch.countDown()
                    }

                    is MetadataFailedAlert -> {
                        val hash = try {
                            alert.handle().infoHash().toHex()
                        } catch (_: Exception) {
                            return
                        }
                        if (hash == expectedHash) {
                            addError = "Failed to fetch torrent metadata"
                            metadataLatch.countDown()
                        }
                    }

                    else -> Unit
                }
            }
        }

        manager.addListener(listener)
        try {
            Log.d(TAG, "Adding torrent $expectedHash -> ${downloadDir.absolutePath}")
            manager.download(
                withPublicTrackers(magnet),
                downloadDir,
                TorrentFlags.AUTO_MANAGED,
            )

            val gotMetadata = metadataLatch.await(
                METADATA_TIMEOUT_SECONDS,
                TimeUnit.SECONDS,
            )
            if (addError != null) throw IllegalStateException(addError)
            if (!gotMetadata) {
                throw IllegalStateException(
                    "Timed out waiting for torrent metadata (no peers found)",
                )
            }
        } finally {
            manager.removeListener(listener)
        }

        val handle = manager.find(Sha1Hash.parseHex(expectedHash))
        if (handle == null || !handle.isValid) {
            throw IllegalStateException("Torrent handle became invalid after adding")
        }

        handles[expectedHash] = handle
        saveDirs[expectedHash] = downloadDir

        val fileIndex = largestFileIndex(handle)
        selectedFiles[expectedHash] = fileIndex

        if (!rename.isNullOrBlank()) {
            try {
                val original = handle.torrentFile().files().filePath(fileIndex)
                val ext = original.substringAfterLast('.', "")
                val newName = if (ext.isNotEmpty()) "$rename.$ext" else rename
                handle.renameFile(fileIndex, newName)
                outputNames[expectedHash] = newName
            } catch (e: Exception) {
                Log.w(TAG, "Could not rename torrent file", e)
            }
        }

        return describeTorrent(handle)
    }

    /** The biggest file in a torrent is the feature; the rest are usually extras. */
    private fun largestFileIndex(handle: TorrentHandle): Int {
        val files = handle.torrentFile().files()
        var best = 0
        var bestSize = 0L
        for (i in 0 until files.numFiles()) {
            val size = files.fileSize(i)
            if (size > bestSize) {
                bestSize = size
                best = i
            }
        }
        return best
    }

    private fun describeTorrent(handle: TorrentHandle): Map<String, Any?> {
        val result = HashMap<String, Any?>()
        val infoHash = try {
            handle.infoHash().toHex()
        } catch (_: Exception) {
            ""
        }
        result["infoHash"] = infoHash

        val status = try {
            handle.status()
        } catch (_: Exception) {
            null
        }
        val hasMetadata = status?.hasMetadata() == true
        result["hasMetadata"] = hasMetadata
        if (!hasMetadata) return result

        val torrentInfo = handle.torrentFile()
        result["name"] = torrentInfo.name()
        result["totalSize"] = torrentInfo.totalSize()

        val files = torrentInfo.files()
        val list = ArrayList<Map<String, Any?>>(files.numFiles())
        for (i in 0 until files.numFiles()) {
            list.add(
                mapOf(
                    "index" to i,
                    "name" to files.fileName(i),
                    "path" to files.filePath(i),
                    "size" to files.fileSize(i),
                ),
            )
        }
        result["files"] = list
        result["selectedFileIndex"] = selectedFiles[infoHash] ?: 0
        return result
    }

    private fun defaultDownloadDir(): File {
        // Streaming scratch space: the platform may evict it instead of letting
        // torrent data grow without bound. Stopping a torrent removes its files.
        val dir = File(appContext.cacheDir, "torrents")
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    // ---------------------------------------------------------------------
    // Playback preparation
    // ---------------------------------------------------------------------

    /**
     * Selects [fileIndex], promotes the opening window plus the file tail, and
     * waits until the first piece is on disk.
     */
    fun prepare(infoHash: String, fileIndex: Int, resuming: Boolean): Boolean {
        val handle = sessionManager?.find(Sha1Hash.parseHex(infoHash)) ?: return false
        if (!handle.isValid) return false

        val status = try {
            handle.status()
        } catch (_: Exception) {
            return false
        }
        if (!status.hasMetadata()) return false

        val torrentInfo = handle.torrentFile()
        val files = torrentInfo.files()
        if (fileIndex < 0 || fileIndex >= files.numFiles()) return false

        selectedFiles[infoHash] = fileIndex

        handle.unsetFlags(TorrentFlags.SEQUENTIAL_DOWNLOAD)

        // The chosen file stays DEFAULT rather than IGNORE: a file set to IGNORE
        // has its pieces parked in libtorrent's part file instead of the real
        // file the stream server reads.
        val filePriorities = Priority.array(Priority.IGNORE, files.numFiles())
        filePriorities[fileIndex] = Priority.DEFAULT
        applyFilePriorities(handle, filePriorities)

        // Only the pieces promoted below are wanted, so playback of one range
        // never drags the whole torrent down with it.
        handle.prioritizePieces(Priority.array(Priority.IGNORE, torrentInfo.numPieces()))

        val pieceLength = torrentInfo.pieceLength()
        val fileOffset = files.fileOffset(fileIndex)
        val fileSize = files.fileSize(fileIndex)
        if (fileSize <= 0L) return false

        val startupBytes = minOf(
            fileSize,
            if (resuming) RESUME_HEADER_BYTES else STARTUP_BYTES,
        )
        val startPiece = (fileOffset / pieceLength).toInt()
        val startupEndPiece =
            ((fileOffset + startupBytes - 1) / pieceLength).toInt()

        promote(handle, startPiece, startupEndPiece, 1000, 250)

        val endPiece = ((fileOffset + fileSize - 1) / pieceLength).toInt()
        val tailStartPiece = maxOf(
            startupEndPiece + 1,
            ((fileOffset + maxOf(0L, fileSize - TAIL_BYTES)) / pieceLength).toInt(),
        )
        promote(handle, tailStartPiece, endPiece, 2000, 0)

        Log.d(
            TAG,
            "prepare: file=$fileIndex pieces=$startPiece-$startupEndPiece " +
                "tail=$tailStartPiece-$endPiece startupBytes=$startupBytes resuming=$resuming",
        )

        if (handle.havePiece(startPiece)) return true

        val deadline = System.currentTimeMillis() + PREPARE_TIMEOUT_MS
        while (System.currentTimeMillis() < deadline) {
            if (!handle.isValid) return false
            if (handle.havePiece(startPiece)) return true
            Thread.sleep(100)
        }
        return false
    }

    private fun promote(
        handle: TorrentHandle,
        firstPiece: Int,
        lastPiece: Int,
        baseDeadlineMs: Int,
        stepMs: Int,
    ) {
        if (lastPiece < firstPiece) return
        for (piece in firstPiece..lastPiece) {
            try {
                if (handle.havePiece(piece)) continue
                handle.piecePriority(piece, Priority.TOP_PRIORITY)
                val deadline = if (stepMs > 0) {
                    baseDeadlineMs + (piece - firstPiece) * stepMs
                } else {
                    baseDeadlineMs
                }
                handle.setPieceDeadline(piece, deadline)
            } catch (e: Exception) {
                Log.w(TAG, "Could not promote piece $piece", e)
                return
            }
        }
    }

    /**
     * libtorrent applies file priorities on its disk thread and then recomputes
     * every piece priority from them, so piece priorities set before that
     * finishes are silently lost.
     */
    private fun applyFilePriorities(handle: TorrentHandle, priorities: Array<Priority>) {
        if (handle.filePriorities().contentEquals(priorities)) return
        handle.prioritizeFiles(priorities)
        var spins = 0
        while (spins < 30 && !handle.filePriorities().contentEquals(priorities)) {
            Thread.sleep(100)
            spins++
        }
    }

    // ---------------------------------------------------------------------
    // TorrentStreamSource
    // ---------------------------------------------------------------------

    override fun mediaFile(infoHash: String, fileIndex: Int): File? {
        val handle = sessionManager?.find(Sha1Hash.parseHex(infoHash)) ?: return null
        if (!handle.isValid) return null
        val dir = saveDirs[infoHash] ?: return null
        return try {
            val files = handle.torrentFile().files()
            if (fileIndex < 0 || fileIndex >= files.numFiles()) return null
            val relative = outputNames[infoHash]
                ?.takeIf { selectedFiles[infoHash] == fileIndex }
                ?: files.filePath(fileIndex)
            File(dir, relative)
        } catch (e: Exception) {
            Log.w(TAG, "mediaFile failed", e)
            null
        }
    }

    override fun mediaFileSize(infoHash: String, fileIndex: Int): Long {
        val handle = sessionManager?.find(Sha1Hash.parseHex(infoHash)) ?: return -1L
        if (!handle.isValid) return -1L
        return try {
            handle.torrentFile().files().fileSize(fileIndex)
        } catch (_: Exception) {
            -1L
        }
    }

    override fun awaitRange(
        infoHash: String,
        fileIndex: Int,
        start: Long,
        endInclusive: Long,
        timeoutMs: Long,
    ): Boolean {
        val handle = sessionManager?.find(Sha1Hash.parseHex(infoHash)) ?: return false
        if (!handle.isValid) return false

        val torrentInfo = handle.torrentFile()
        val files = torrentInfo.files()
        val pieceLength = torrentInfo.pieceLength()
        val fileOffset = files.fileOffset(fileIndex)

        val firstPiece = ((fileOffset + start) / pieceLength).toInt()
        val lastPiece = ((fileOffset + endInclusive) / pieceLength).toInt()

        promote(handle, firstPiece, lastPiece, 500, 50)

        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            if (!handle.isValid) return false
            var allPresent = true
            for (piece in firstPiece..lastPiece) {
                if (!handle.havePiece(piece)) {
                    allPresent = false
                    break
                }
            }
            if (allPresent) {
                // havePiece() reflects the hash check; flushCache() is what puts
                // the bytes in the file this server reads from.
                try {
                    handle.flushCache()
                } catch (e: Exception) {
                    Log.w(TAG, "flushCache failed", e)
                }
                Thread.sleep(120)
                return true
            }
            Thread.sleep(100)
        }
        return false
    }

    // ---------------------------------------------------------------------
    // Stats / teardown
    // ---------------------------------------------------------------------

    fun stats(infoHash: String): Map<String, Any?> {
        val handle = sessionManager?.find(Sha1Hash.parseHex(infoHash))
            ?: return mapOf("found" to false)
        if (!handle.isValid) return mapOf("found" to false)

        val status: TorrentStatus = handle.status()
        return mapOf(
            "found" to true,
            "state" to stateName(status.state()),
            "progress" to status.progress().toDouble(),
            "downloadRate" to status.downloadRate(),
            "uploadRate" to status.uploadRate(),
            "numPeers" to status.numPeers(),
            "numSeeds" to status.numSeeds(),
            "totalDone" to status.totalDone(),
            "totalWanted" to status.totalWanted(),
            "hasMetadata" to status.hasMetadata(),
        )
    }

    private fun stateName(state: TorrentStatus.State): String = when (state) {
        TorrentStatus.State.CHECKING_FILES -> "checking"
        TorrentStatus.State.DOWNLOADING_METADATA -> "metadata"
        TorrentStatus.State.DOWNLOADING -> "downloading"
        TorrentStatus.State.FINISHED -> "finished"
        TorrentStatus.State.SEEDING -> "seeding"
        TorrentStatus.State.CHECKING_RESUME_DATA -> "checking"
        else -> "unknown"
    }

    fun stop(infoHash: String, deleteFiles: Boolean) {
        val manager = sessionManager
        val handle = manager?.find(Sha1Hash.parseHex(infoHash))
        val dir = saveDirs[infoHash]

        if (handle != null && handle.isValid) {
            try {
                handle.pause()
            } catch (_: Exception) {
            }
            try {
                manager.remove(handle)
            } catch (e: Exception) {
                Log.w(TAG, "remove failed", e)
            }
        }

        handles.remove(infoHash)
        selectedFiles.remove(infoHash)
        outputNames.remove(infoHash)
        saveDirs.remove(infoHash)

        if (deleteFiles && dir != null) {
            try {
                dir.deleteRecursively()
            } catch (e: Exception) {
                Log.w(TAG, "Could not delete ${dir.absolutePath}", e)
            }
        }
    }
}
