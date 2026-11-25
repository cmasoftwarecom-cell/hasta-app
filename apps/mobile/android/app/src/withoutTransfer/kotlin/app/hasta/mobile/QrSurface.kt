@file:Suppress("UNUSED_PARAMETER")

package app.hasta.mobile

import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger

// These variants neither register the channel nor include the scanner SDK.
internal class QrSurface(activity: MainActivity) {
    fun register(messenger: BinaryMessenger) = Unit
    fun receive(intent: Intent) = Unit
    fun detach() = Unit
    fun onResult(requestCode: Int, resultCode: Int, data: Intent?) = false
}
