package app.hasta.mobile

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.client.android.Intents
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.journeyapps.barcodescanner.CaptureActivity
import com.journeyapps.barcodescanner.ScanOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class SecureQrCaptureActivity : CaptureActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }
}

internal class QrSurface(private val activity: MainActivity) {
    private val action = "app.hasta.mobile.qa.RECEIVE_TRANSFER"
    private val request = 28028
    private var pendingLaunch = false
    private var armed = false
    private var channel: MethodChannel? = null
    private var scan: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        activity.intent?.let { receive(it) }
        channel = MethodChannel(messenger, "app.hasta.mobile/qr_surface")
        channel?.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "arm" -> {
                        check(Build.VERSION.SDK_INT >= 30)
                        publishShortcut()
                        armed = true
                        result.success(pendingLaunch.also { pendingLaunch = false })
                    }
                    "protect" -> {
                        check(armed)
                        activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        check(isProtected())
                        result.success(true)
                    }
                    "encode" -> {
                        check(armed && isProtected())
                        val payload = call.arguments as? String
                        check(payload != null && payload.matches(Regex("""\{"v":1,"token":"tt_[A-Za-z0-9_-]{43}"\}""")))
                        val matrix = QRCodeWriter().encode(payload, BarcodeFormat.QR_CODE, 1, 1,
                            mapOf(EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.M, EncodeHintType.MARGIN to 4))
                        result.success(mapOf("size" to matrix.width,
                            "modules" to ByteArray(matrix.width * matrix.height) { i ->
                                if (matrix[i % matrix.width, i / matrix.width]) 1 else 0
                            }))
                    }
                    "scan" -> {
                        check(armed && isProtected() && scan == null)
                        if (!activity.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
                            return@setMethodCallHandler result.error("transfer_camera_unavailable", null, null)
                        }
                        val options = ScanOptions().setCaptureActivity(SecureQrCaptureActivity::class.java)
                            .setDesiredBarcodeFormats(ScanOptions.QR_CODE).setPrompt(activity.getString(R.string.hasta_transfer_scan))
                            .setBeepEnabled(false).setBarcodeImageEnabled(false).setTimeout(120_000L)
                        activity.startActivityForResult(options.createScanIntent(activity), request)
                        scan = result
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("transfer_surface_unavailable", null, null)
            }
        }
    }

    fun receive(intent: Intent) {
        if (intent.action != action || intent.data != null) return
        intent.action = null
        if (armed) channel?.invokeMethod("receive", null)
        else pendingLaunch = true
    }

    fun detach() {
        scan?.success(null)
        scan = null
        armed = false
        channel?.setMethodCallHandler(null)
        channel = null
    }

    fun onResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != request) return false
        val waiter = scan ?: return true
        scan = null
        if (data?.getBooleanExtra(Intents.Scan.MISSING_CAMERA_PERMISSION, false) == true) {
            waiter.error("transfer_camera_denied", null, null)
        } else if (resultCode == Activity.RESULT_OK) {
            val value = data?.getStringExtra(Intents.Scan.RESULT)
            if (value != null && value.length <= 128) waiter.success(value)
            else waiter.error("transfer_qr_invalid", null, null)
        } else {
            waiter.success(null)
        }
        return true
    }

    private fun isProtected() =
        (activity.window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE) != 0

    @android.annotation.TargetApi(25)
    private fun publishShortcut() {
        val manager = activity.getSystemService(ShortcutManager::class.java) ?: return
        val shortcut = ShortcutInfo.Builder(activity, "receive_qr_qa")
            .setShortLabel(activity.getString(R.string.hasta_transfer_receive))
            .setIntent(Intent(activity, MainActivity::class.java).setAction(action))
            .build()
        manager.addDynamicShortcuts(listOf(shortcut))
    }
}
