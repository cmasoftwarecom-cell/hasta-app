import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
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
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
