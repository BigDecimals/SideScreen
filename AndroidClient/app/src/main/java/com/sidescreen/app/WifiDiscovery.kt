package com.sidescreen.app

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import android.os.Handler
import android.os.Looper

class WifiDiscovery(private val context: Context) {

    data class DiscoveredHost(
        val name: String,      // e.g. "Jonathan's MacBook Pro"
        val host: String,      // resolved IP address
        val port: Int,         // e.g. 8888
        val txtRecords: Map<String, String>
    )

    private val nsdManager = context.getSystemService(NsdManager::class.java)
    private var discoveryListener: NsdManager.DiscoveryListener? = null

    var onHostFound: ((DiscoveredHost) -> Unit)? = null
    var onHostLost: ((String) -> Unit)? = null  // service name lost
    var onError: ((String) -> Unit)? = null

    fun startDiscovery() {
        stopDiscovery()

        discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                onError?.invoke("Discovery start failed: $errorCode")
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                // Non-fatal, log only
            }

            override fun onDiscoveryStarted(serviceType: String) {
                // Discovery active
            }

            override fun onDiscoveryStopped(serviceType: String) {
                // Discovery stopped
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                // Service found — must resolve to get IP + port
                resolveService(serviceInfo)
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                onHostLost?.invoke(serviceInfo.serviceName)
            }
        }

        nsdManager.discoverServices(
            SERVICE_TYPE,
            NsdManager.PROTOCOL_DNS_SD,
            discoveryListener
        )
    }

    private fun resolveService(serviceInfo: NsdServiceInfo) {
        // Android 12+ has a better resolve API; use legacy for max compatibility
        nsdManager.resolveService(serviceInfo, object : NsdManager.ResolveListener {
            override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                // Retry once — Android NsdManager has a known bug where resolve
                // fails if another resolve is in flight. Retry after 500ms.
                Handler(Looper.getMainLooper()).postDelayed({
                    resolveService(serviceInfo)
                }, 500)
            }

            override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                val host = serviceInfo.host?.hostAddress ?: return
                val port = serviceInfo.port
                val txtRecords = parseTxtRecords(serviceInfo)

                onHostFound?.invoke(DiscoveredHost(
                    name = serviceInfo.serviceName,
                    host = host,
                    port = port,
                    txtRecords = txtRecords
                ))
            }
        })
    }

    private fun parseTxtRecords(serviceInfo: NsdServiceInfo): Map<String, String> {
        // On Android 12+, NsdServiceInfo exposes attributes map directly
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return try {
                serviceInfo.attributes.mapValues { (_, v) ->
                    v?.let { String(it, Charsets.UTF_8) } ?: ""
                }
            } catch (e: Exception) {
                emptyMap()
            }
        } else {
             return emptyMap()
        }
    }

    fun stopDiscovery() {
        try {
            discoveryListener?.let { nsdManager.stopServiceDiscovery(it) }
        } catch (_: Exception) {}
        discoveryListener = null
    }

    companion object {
        const val SERVICE_TYPE = "_sidescreen._tcp."
    }
}
