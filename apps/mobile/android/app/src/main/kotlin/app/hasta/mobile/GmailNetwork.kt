package app.hasta.mobile

import android.app.Activity
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

internal class GmailNetwork(private val activity: Activity, messenger: BinaryMessenger) :
    EventChannel.StreamHandler {
    private val channel = EventChannel(messenger, "app.hasta.mobile/gmail_network")
    private val manager = activity.getSystemService(ConnectivityManager::class.java)
    private var callback: ConnectivityManager.NetworkCallback? = null

    init {
        channel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        onCancel(null)
        val manager = manager ?: run {
            sink.error("gmail_network_unavailable", null, null)
            return
        }
        val listener = object : ConnectivityManager.NetworkCallback() {
            fun publish() {
                activity.runOnUiThread {
                    if (callback === this) {
                        val active = manager.getNetworkCapabilities(manager.activeNetwork)
                        sink.success(active?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true)
                    }
                }
            }
            override fun onAvailable(network: Network) = publish()
            override fun onLost(network: Network) = publish()
            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) = publish()
        }
        try {
            if (Build.VERSION.SDK_INT >= 24) {
                manager.registerDefaultNetworkCallback(listener)
            } else {
                val request = NetworkRequest.Builder()
                    .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET).build()
                manager.registerNetworkCallback(request, listener)
            }
            callback = listener
            listener.publish()
        } catch (_: SecurityException) {
            sink.error("gmail_network_unavailable", null, null)
        }
    }

    override fun onCancel(arguments: Any?) {
        val old = callback ?: return
        callback = null
        manager?.unregisterNetworkCallback(old)
    }

    fun detach() {
        onCancel(null)
        channel.setStreamHandler(null)
    }
}
