import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var recovery: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(name: "app.hasta.mobile/device", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { call, result in
          guard call.method == "info" else { result(FlutterMethodNotImplemented); return }
          guard let id = UIDevice.current.identifierForVendor?.uuidString else {
            result(FlutterError(code: "device_unavailable", message: nil, details: nil))
            return
          }
          result(["raw_device_id": id, "platform": "ios", "os_version": UIDevice.current.systemVersion])
        }
      let channel = FlutterMethodChannel(name: "app.hasta.mobile/recovery",
                                         binaryMessenger: controller.binaryMessenger)
      recovery = channel
      channel.setMethodCallHandler { call, result in
        if call.method == "trustedRedirect" {
          let host = Bundle.main.object(forInfoDictionaryKey: "HastaRecoveryHost") as? String
          result(host.map { "https://\($0)/auth/recovery/callback" })
          return
        }
        guard call.method == "openConsent" else { result(FlutterMethodNotImplemented); return }
        guard let raw = call.arguments as? String, raw.utf8.count <= 8192,
              let url = URL(string: raw),
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "https", parts.host == "accounts.google.com",
              parts.port == nil || parts.port == 443,
              parts.percentEncodedPath == "/o/oauth2/v2/auth",
              parts.user == nil, parts.password == nil, parts.fragment == nil else {
          result(FlutterError(code: "recovery_browser_unavailable", message: nil, details: nil))
          return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
          result(opened ? nil : FlutterError(code: "recovery_browser_unavailable", message: nil, details: nil))
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let callback = userActivity.webpageURL, callback.absoluteString.utf8.count <= 8192,
       let host = Bundle.main.object(forInfoDictionaryKey: "HastaRecoveryHost") as? String,
       let parts = URLComponents(url: callback, resolvingAgainstBaseURL: false),
       parts.scheme == "https", parts.host == host,
       parts.port == nil || parts.port == 443,
       parts.percentEncodedPath == "/auth/recovery/callback",
       parts.user == nil, parts.password == nil, parts.fragment == nil {
      recovery?.invokeMethod("callback", arguments: callback.absoluteString)
      return true
    }
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }
}
