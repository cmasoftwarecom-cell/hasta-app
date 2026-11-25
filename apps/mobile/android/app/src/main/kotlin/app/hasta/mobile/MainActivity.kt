package app.hasta.mobile

import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private var recovery: MethodChannel? = null
    private val debugBuild get() = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    private val recoveryHost: String? by lazy {
        packageManager.getActivityInfo(componentName, PackageManager.GET_META_DATA)
            .metaData?.getString("app.hasta.mobile.recovery_host")
    }

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
        recovery = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.hasta.mobile/recovery")
        recovery?.setMethodCallHandler { call, result ->
            val text = call.arguments as? String
            val uri = text?.takeIf { it.length <= 8192 }?.let(Uri::parse)
            when {
                call.method == "trustedRedirect" ->
                    result.success(recoveryHost?.let { "https://$it/auth/recovery/callback" })
                call.method == "openConsent" && uri != null && uri.scheme == "https" &&
                    uri.host == "accounts.google.com" && (uri.port == -1 || uri.port == 443) &&
                    uri.encodedUserInfo == null && uri.path == "/o/oauth2/v2/auth" && uri.fragment == null ->
                    openBrowser(uri, result)
                call.method == "openLocalRecoveryFixture" && debugBuild && uri != null &&
                    uri.scheme == "http" && uri.host == "127.0.0.1" && uri.port > 0 &&
                    uri.encodedUserInfo == null && uri.path == "/_native/recovery/consent" && uri.fragment == null ->
                    openBrowser(uri, result)
                else -> result.error("recovery_browser_unavailable", null, null)
            }
        }
        // A cold start cannot finish a consent initiated in a dead process.
        if (isRecoveryCallback(intent?.data)) intent?.data = null
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        recovery?.setMethodCallHandler(null)
        recovery = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        val uri = intent.data
        if (intent.action == Intent.ACTION_VIEW && isRecoveryCallback(uri)) {
            intent.data = null
            super.onNewIntent(intent)
            recovery?.invokeMethod("callback", uri.toString())
            return
        }
        super.onNewIntent(intent)
    }

    private fun isRecoveryCallback(uri: Uri?): Boolean {
        if (uri == null || uri.toString().length > 8192 || uri.encodedUserInfo != null || uri.fragment != null) return false
        return (uri.scheme == "https" && uri.host == recoveryHost &&
            (uri.port == -1 || uri.port == 443) && uri.encodedPath == "/auth/recovery/callback") ||
            (debugBuild && uri.scheme == "hasta-recovery-qa" && uri.host == "callback" &&
                uri.port == -1 && uri.encodedPath == "/complete")
    }

    private fun openBrowser(uri: Uri, result: MethodChannel.Result) {
        try {
            startActivity(Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE))
            result.success(null)
        } catch (_: android.content.ActivityNotFoundException) {
            result.error("recovery_browser_unavailable", null, null)
        } catch (_: SecurityException) {
            result.error("recovery_browser_unavailable", null, null)
        }
    }
}
