package com.abhishekrazy.exalere.torrent

import android.util.Log
import java.io.BufferedOutputStream
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.io.RandomAccessFile
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.URLDecoder
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

/**
 * Everything the streaming server needs from the torrent engine.
 *
 * Kept as an interface so the HTTP layer has no dependency on libtorrent and can
 * be reasoned about (and tested) on its own.
 */
interface TorrentStreamSource {
    /** Absolute path of the file backing [fileIndex], or null when unknown. */
    fun mediaFile(infoHash: String, fileIndex: Int): File?

    /** Size in bytes of the file backing [fileIndex], or -1 when unknown. */
    fun mediaFileSize(infoHash: String, fileIndex: Int): Long

    /**
     * Blocks until bytes [start]..[endInclusive] of [fileIndex] exist on disk,
     * promoting the pieces that cover them. Returns false on timeout.
     */
    fun awaitRange(
        infoHash: String,
        fileIndex: Int,
        start: Long,
        endInclusive: Long,
        timeoutMs: Long,
    ): Boolean
}

/**
 * Loopback HTTP server that exposes an in-progress torrent as a seekable media
 * URL so an ordinary video player can stream it.
 *
 * Players drive playback with HTTP Range requests. Each request is translated
 * into the torrent pieces covering that byte span, those pieces are promoted to
 * top priority, and the response body is written only once the bytes are on
 * disk. Nothing downloads until a player asks for it, which is what makes this
 * streaming rather than downloading.
 *
 * The server binds to 127.0.0.1 on an ephemeral port, so it is reachable only
 * from the device itself.
 */
class TorrentStreamServer(private val source: TorrentStreamSource) {

    companion object {
        private const val TAG = "TorrentStreamServer"
        private const val MAX_HEADER_BYTES = 8 * 1024

        /// The first request has to wait for peers and metadata, later ones do not.
        private const val FIRST_RANGE_TIMEOUT_MS = 90_000L
        private const val RANGE_TIMEOUT_MS = 60_000L
    }

    private var serverSocket: ServerSocket? = null
    private val running = AtomicBoolean(false)
    private val pool = Executors.newFixedThreadPool(4)
    private var servedFirstRange = false

    @Volatile
    var listeningPort: Int = 0
        private set

    val isRunning: Boolean get() = running.get()

    fun start() {
        if (running.get()) return
        val socket = ServerSocket(0, 16, InetAddress.getByName("127.0.0.1"))
        serverSocket = socket
        listeningPort = socket.localPort
        running.set(true)
        Log.d(TAG, "Stream server listening on 127.0.0.1:$listeningPort")

        thread(name = "ExalereTorrentAccept", isDaemon = true) {
            while (running.get()) {
                val client = try {
                    socket.accept()
                } catch (e: IOException) {
                    if (running.get()) Log.w(TAG, "accept() failed", e)
                    null
                } ?: continue
                pool.execute { handle(client) }
            }
        }
    }

    fun stop() {
        running.set(false)
        try {
            serverSocket?.close()
        } catch (_: IOException) {
        }
        serverSocket = null
        pool.shutdownNow()
    }

    /** Local URL a player can open for [fileIndex] of [infoHash]. */
    fun streamUrl(infoHash: String, fileIndex: Int, fileName: String): String {
        val encoded = try {
            java.net.URLEncoder.encode(fileName, "UTF-8").replace("+", "%20")
        } catch (_: Exception) {
            "video"
        }
        return "http://127.0.0.1:$listeningPort/stream/$infoHash/$fileIndex/$encoded"
    }

    // ---------------------------------------------------------------------
    // Request handling
    // ---------------------------------------------------------------------

    private fun handle(client: Socket) {
        try {
            client.soTimeout = RANGE_TIMEOUT_MS.toInt()
            val header = readHeader(client.getInputStream())
            if (header == null) {
                client.close()
                return
            }

            val requestLine = header.lineSequence().firstOrNull()?.trim().orEmpty()
            val parts = requestLine.split(' ')
            if (parts.size < 2) {
                writeStatus(client, 400, "Bad Request")
                return
            }
            val method = parts[0].uppercase()
            val rawPath = parts[1]
            val rangeHeader = header.lineSequence()
                .firstOrNull { it.lowercase().startsWith("range:") }
                ?.substringAfter(':')
                ?.trim()

            val parsed = parseStreamPath(rawPath)
            if (parsed == null) {
                writeStatus(client, 404, "Not Found")
                return
            }
            val (infoHash, fileIndex) = parsed

            val file = source.mediaFile(infoHash, fileIndex)
            val size = source.mediaFileSize(infoHash, fileIndex)
            if (file == null || size <= 0L) {
                Log.w(TAG, "No media file for $infoHash/$fileIndex")
                writeStatus(client, 404, "Torrent file not ready")
                return
            }

            val span = parseRange(rangeHeader, size)
            val isFirst = !servedFirstRange
            val timeout = if (isFirst) FIRST_RANGE_TIMEOUT_MS else RANGE_TIMEOUT_MS

            val ready = source.awaitRange(
                infoHash,
                fileIndex,
                span.start,
                span.endInclusive,
                timeout,
            )
            servedFirstRange = true

            if (!ready) {
                Log.w(TAG, "Timed out waiting for bytes ${span.start}-${span.endInclusive}")
                writeStatus(client, 503, "Pieces not available yet")
                return
            }

            if (method == "HEAD") {
                writeHeaders(client, 200, size, 0L, size - 1, file.name)
                return
            }

            writeHeaders(client, 206, size, span.start, span.endInclusive, file.name)
            copyRange(client, file, span.start, span.length)
        } catch (e: IOException) {
            // Players cancel requests constantly while seeking; this is normal.
            Log.d(TAG, "Client stream ended: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Stream request failed", e)
        } finally {
            try {
                client.close()
            } catch (_: IOException) {
            }
        }
    }

    private data class StreamRequest(val infoHash: String, val fileIndex: Int)

    /** Parses `/stream/<infoHash>/<fileIndex>/<any name>`. */
    private fun parseStreamPath(rawPath: String): StreamRequest? {
        val path = rawPath.substringBefore('?')
        val segments = path.split('/').filter { it.isNotEmpty() }
        if (segments.size < 3 || segments[0] != "stream") return null
        val infoHash = segments[1]
        val fileIndex = segments[2].toIntOrNull() ?: return null
        if (infoHash.length != 40) return null
        return StreamRequest(infoHash.lowercase(), fileIndex)
    }

    private data class ByteSpan(val start: Long, val endInclusive: Long) {
        val length: Long get() = endInclusive - start + 1
    }

    /** Parses `bytes=start-end`, `bytes=start-` and `bytes=-suffix`. */
    private fun parseRange(header: String?, size: Long): ByteSpan {
        if (header == null || !header.lowercase().startsWith("bytes=")) {
            // No Range: hand back a bounded opening chunk rather than the whole
            // file, which is all a player needs to begin.
            val end = minOf(size - 1, 4L * 1024 * 1024 - 1)
            return ByteSpan(0L, end)
        }

        val spec = header.substringAfter('=').substringBefore(',').trim()
        val dash = spec.indexOf('-')
        if (dash < 0) return ByteSpan(0L, size - 1)

        val startRaw = spec.substring(0, dash).trim()
        val endRaw = spec.substring(dash + 1).trim()

        return when {
            startRaw.isEmpty() -> {
                // Suffix form: the last N bytes.
                val suffix = endRaw.toLongOrNull() ?: 0L
                val start = maxOf(0L, size - suffix)
                ByteSpan(start, size - 1)
            }

            endRaw.isEmpty() -> ByteSpan(startRaw.toLongOrNull() ?: 0L, size - 1)

            else -> {
                val start = startRaw.toLongOrNull() ?: 0L
                val end = endRaw.toLongOrNull() ?: (size - 1)
                ByteSpan(
                    start.coerceIn(0L, maxOf(0L, size - 1)),
                    end.coerceIn(0L, size - 1),
                )
            }
        }
    }

    private fun writeStatus(client: Socket, code: Int, message: String) {
        val body = "$code $message\n".toByteArray(Charsets.UTF_8)
        val head = buildString {
            append("HTTP/1.1 $code $message\r\n")
            append("Content-Type: text/plain; charset=utf-8\r\n")
            append("Content-Length: ${body.size}\r\n")
            append("Connection: close\r\n\r\n")
        }
        val out = client.getOutputStream()
        out.write(head.toByteArray(Charsets.US_ASCII))
        out.write(body)
        out.flush()
    }

    private fun writeHeaders(
        client: Socket,
        code: Int,
        totalSize: Long,
        start: Long,
        endInclusive: Long,
        fileName: String,
    ) {
        val length = endInclusive - start + 1
        val head = buildString {
            append("HTTP/1.1 $code ${if (code == 206) "Partial Content" else "OK"}\r\n")
            append("Content-Type: ${contentTypeFor(fileName)}\r\n")
            append("Accept-Ranges: bytes\r\n")
            if (code == 206) {
                append("Content-Range: bytes $start-$endInclusive/$totalSize\r\n")
            }
            append("Content-Length: $length\r\n")
            append("Connection: close\r\n\r\n")
        }
        client.getOutputStream().write(head.toByteArray(Charsets.US_ASCII))
    }

    private fun copyRange(client: Socket, file: File, start: Long, length: Long) {
        val out = BufferedOutputStream(client.getOutputStream(), 64 * 1024)
        RandomAccessFile(file, "r").use { raf ->
            raf.seek(start)
            val buffer = ByteArray(64 * 1024)
            var remaining = length
            while (remaining > 0) {
                val want = minOf(buffer.size.toLong(), remaining).toInt()
                val read = raf.read(buffer, 0, want)
                if (read <= 0) break
                out.write(buffer, 0, read)
                remaining -= read
            }
        }
        out.flush()
    }

    private fun contentTypeFor(fileName: String): String =
        when (fileName.substringAfterLast('.', "").lowercase()) {
            "mp4", "m4v" -> "video/mp4"
            "mkv" -> "video/x-matroska"
            "webm" -> "video/webm"
            "avi" -> "video/x-msvideo"
            "ts", "m2ts" -> "video/mp2t"
            "mov" -> "video/quicktime"
            else -> "application/octet-stream"
        }

    private fun readHeader(input: InputStream): String? {
        val sb = StringBuilder()
        while (sb.length < MAX_HEADER_BYTES) {
            val b = input.read()
            if (b < 0) break
            sb.append(b.toChar())
            if (sb.endsWith("\r\n\r\n") || sb.endsWith("\n\n")) break
        }
        return if (sb.isEmpty()) null else sb.toString()
    }

    @Suppress("unused")
    private fun decodeName(raw: String): String =
        try {
            URLDecoder.decode(raw, "UTF-8")
        } catch (_: Exception) {
            raw
        }
}
