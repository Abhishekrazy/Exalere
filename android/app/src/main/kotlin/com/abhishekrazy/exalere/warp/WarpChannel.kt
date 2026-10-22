package com.abhishekrazy.exalere.warp

import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.util.Log
import com.wireguard.android.backend.Backend
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import com.wireguard.config.Interface
import com.wireguard.config.Peer
import com.wireguard.crypto.Key
import com.wireguard.crypto.KeyPair
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Bridges Flutter to a Cloudflare WARP WireGuard tunnel.
 *
 * Flutter owns registration, persistence and UI; this class owns the tunnel. The
 * split is deliberate: the Cloudflare round-trip is testable in Dart, and only the
 * part that genuinely needs the platform lives here.
 *
 * All libwireguard work runs on a dedicated thread because `setState` blocks while
 * it brings the interface up or down.
 */
class WarpChannel(
    private val appContext: Context,
    private val requestVpnConsent: ((Boolean) -> Unit) -> Unit,
) {
    companion object {
        private const val TAG = "WarpChannel"
        private const val CHANNEL = "com.exalere/warp"
    }

    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "ExalereWarpIO")
    }

    private val tunnel = WarpTunnel()
    private var backend: Backend? = null
    private var lastError: String? = null

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(true)

                "generateKeyPair" -> {
                    try {
                        val keyPair = KeyPair()
                        result.success(
                            mapOf(
                                "privateKey" to keyPair.privateKey.toBase64(),
                                "publicKey" to keyPair.publicKey.toBase64(),
                            )
                        )
                    } catch (e: Throwable) {
                        Log.e(TAG, "key generation failed", e)
                        result.error("WARP_KEYPAIR", e.message, null)
                    }
                }

                "start" -> startTunnel(
                    privateKey = call.argument<String>("privateKey"),
                    peerPublicKey = call.argument<String>("peerPublicKey"),
                    endpointHost = call.argument<String>("endpointHost"),
                    endpointPort = call.argument<Int>("endpointPort"),
                    ipv4 = call.argument<String>("ipv4"),
                    ipv6 = call.argument<String>("ipv6"),
                    result = result,
                )

                "stop" -> stopTunnel(result)

                "status" -> result.success(
                    mapOf(
                        "running" to isUp(),
                        "error" to lastError,
                    )
                )

                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        try {
            backend?.setState(tunnel, Tunnel.State.DOWN, null)
        } catch (e: Throwable) {
            Log.w(TAG, "dispose stop failed: ${e.message}")
        }
        executor.shutdownNow()
    }

    // -----------------------------------------------------------------
    // Tunnel
    // -----------------------------------------------------------------

    private fun startTunnel(
        privateKey: String?,
        peerPublicKey: String?,
        endpointHost: String?,
        endpointPort: Int?,
        ipv4: String?,
        ipv6: String?,
        result: MethodChannel.Result,
    ) {
        if (privateKey.isNullOrBlank() || peerPublicKey.isNullOrBlank() ||
            endpointHost.isNullOrBlank() || ipv4.isNullOrBlank()
        ) {
            result.success(false)
            return
        }

        // Android requires explicit user consent before an app may create a VPN.
        val consent = VpnService.prepare(appContext)
        if (consent != null) {
            requestVpnConsent { granted ->
                if (!granted) {
                    lastError = "VPN permission was denied"
                    result.success(false)
                    return@requestVpnConsent
                }
                launchTunnel(
                    privateKey, peerPublicKey, endpointHost,
                    endpointPort ?: 2408, ipv4, ipv6, result,
                )
            }
            return
        }

        launchTunnel(
            privateKey, peerPublicKey, endpointHost,
            endpointPort ?: 2408, ipv4, ipv6, result,
        )
    }

    private fun launchTunnel(
        privateKey: String,
        peerPublicKey: String,
        endpointHost: String,
        endpointPort: Int,
        ipv4: String,
        ipv6: String?,
        result: MethodChannel.Result,
    ) {
        // The backend needs a live service instance, so start it first.
        try {
            appContext.startService(Intent(appContext, WarpVpnService::class.java))
        } catch (e: Throwable) {
            Log.e(TAG, "could not start WarpVpnService", e)
            lastError = e.message
            result.success(false)
            return
        }

        executor.execute {
            try {
                // startService is asynchronous, so onCreate may not have run yet.
                // Wait briefly rather than failing the first connect on a race that
                // resolves itself in milliseconds.
                var service = WarpVpnService.instance
                var waited = 0
                while (service == null && waited < 2000) {
                    Thread.sleep(50)
                    waited += 50
                    service = WarpVpnService.instance
                }
                if (service == null) {
                    lastError = "VPN service did not start"
                    postResult(result, false)
                    return@execute
                }

                val config = buildConfig(
                    privateKey, peerPublicKey, endpointHost, endpointPort, ipv4, ipv6,
                )

                val activeBackend = backend ?: GoBackend(service).also { backend = it }
                activeBackend.setState(tunnel, Tunnel.State.UP, config)

                val up = activeBackend.getState(tunnel) == Tunnel.State.UP
                lastError = if (up) null else "Tunnel did not come up"
                Log.i(TAG, "tunnel up=$up")
                postResult(result, up)
            } catch (e: Throwable) {
                lastError = e.message ?: e.toString()
                Log.e(TAG, "start failed", e)
                postResult(result, false)
            }
        }
    }

    private fun stopTunnel(result: MethodChannel.Result) {
        executor.execute {
            try {
                backend?.setState(tunnel, Tunnel.State.DOWN, null)
                lastError = null
                postResult(result, true)
            } catch (e: Throwable) {
                lastError = e.message ?: e.toString()
                Log.e(TAG, "stop failed", e)
                postResult(result, false)
            }
            try {
                appContext.stopService(Intent(appContext, WarpVpnService::class.java))
            } catch (_: Throwable) {
            }
        }
    }

    private fun isUp(): Boolean = try {
        backend?.getState(tunnel) == Tunnel.State.UP
    } catch (e: Throwable) {
        false
    }

    private fun buildConfig(
        privateKey: String,
        peerPublicKey: String,
        endpointHost: String,
        endpointPort: Int,
        ipv4: String,
        ipv6: String?,
    ): Config {
        val addresses = mutableListOf("$ipv4/32")
        if (!ipv6.isNullOrBlank()) {
            addresses.add("$ipv6/128")
        }

        // These builders take space-separated CharSequences, not lists.
        val interfaceBuilder = Interface.Builder()
            .parseAddresses(addresses.joinToString(" "))
            // Cloudflare's resolver, and the same one the DNS setting offers.
            .parseDnsServers("1.1.1.1 1.0.0.1")
            .parsePrivateKey(privateKey)

        val peerBuilder = Peer.Builder()
            .parseEndpoint("$endpointHost:$endpointPort")
            .setPublicKey(Key.fromBase64(peerPublicKey))
            .parseAllowedIPs("0.0.0.0/0, ::/0")
            .setPersistentKeepalive(25)

        return Config.Builder()
            .setInterface(interfaceBuilder.build())
            .addPeer(peerBuilder.build())
            .build()
    }

    /** Posts a result back on the main thread, as the channel requires. */
    private fun postResult(result: MethodChannel.Result, value: Any?) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            result.success(value)
        }
    }

    /** Tunnel identity handed to the backend. */
    private class WarpTunnel : Tunnel {
        override fun getName(): String = "warp"

        override fun onStateChange(newState: Tunnel.State) {
            Log.i(TAG, "tunnel state -> $newState")
        }
    }
}
