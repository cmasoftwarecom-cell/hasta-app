package app.hasta.mobile

import io.flutter.embedding.android.FlutterActivity
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.hasta.mobile/device")
            .setMethodCallHandler { call, result ->
                if (call.method != "info") {
                    result.notImplemented()
                } else {
                    val id = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    if (id.isNullOrEmpty()) result.error("device_unavailable", null, null)
                    else result.success(mapOf("raw_device_id" to id, "platform" to "android",
                        "os_version" to Build.VERSION.SDK_INT.toString()))
                }
            }
    }
}
