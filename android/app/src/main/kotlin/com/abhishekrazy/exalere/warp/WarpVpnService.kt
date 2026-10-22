package com.abhishekrazy.exalere.warp

import android.content.Intent
import android.os.IBinder
import android.util.Log
import com.wireguard.android.backend.GoBackend

/**
 * VpnService that hosts the WireGuard tunnel.
 *
 * It extends [GoBackend.VpnService] because the WireGuard backend requires a
 * service of that exact type: the library uses the service's descriptor to build
 * the tun interface, and a plain `VpnService` subclass would be rejected.
 *
 * The service is started on demand by [WarpChannel] and keeps a static reference
 * so the channel can hand it to the backend. It holds no tunnel state itself —
 * [WarpChannel] owns that.
 */
class WarpVpnService : GoBackend.VpnService() {

    override fun onBind(intent: Intent?): IBinder? {
        // Returning the backend's binder is what lets GoBackend drive the tunnel.
        return super.onBind(intent)
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.i(TAG, "WarpVpnService created")
    }

    override fun onDestroy() {
        if (instance === this) {
            instance = null
        }
        Log.i(TAG, "WarpVpnService destroyed")
        super.onDestroy()
    }

    companion object {
        private const val TAG = "WarpVpnService"

        /** Live service instance, or null when it is not running. */
        @Volatile
        var instance: WarpVpnService? = null
            private set
    }
}
