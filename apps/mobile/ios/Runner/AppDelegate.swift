import Flutter
import LocalAuthentication
import Security
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var recovery: FlutterMethodChannel?
  private let transferQueue = DispatchQueue(label: "app.hasta.mobile.transfer_approval")
  private let transferTag = Data("app.hasta.mobile.transfer_approval.v1".utf8)

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(name: "app.hasta.mobile/transfer_approval", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { [weak self] call, result in
          guard let self = self else { return result(FlutterMethodNotImplemented) }
          guard call.method == "publicKey" || call.method == "approve" else {
            return result(FlutterMethodNotImplemented)
          }
          let challenge = call.arguments as? String
          self.transferQueue.async {
            let reply = call.method == "publicKey"
              ? self.transferPublicKey()
              : self.approveTransfer(challenge)
            DispatchQueue.main.async {
              if let reply = reply { result(reply) }
              else { result(FlutterError(code: "transfer_approval_unavailable", message: nil, details: nil)) }
            }
          }
        }
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

  private func lookupTransferKey(_ context: LAContext? = nil) -> (OSStatus, SecKey?) {
    var query: [String: Any] = [
      kSecClass as String: kSecClassKey, kSecAttrApplicationTag as String: transferTag,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom, kSecReturnRef as String: true,
    ]
    if let context = context { query[kSecUseAuthenticationContext as String] = context }
    var found: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &found)
    guard status == errSecSuccess, let value = found, CFGetTypeID(value) == SecKeyGetTypeID()
    else { return (status, nil) }
    return (status, (value as! SecKey))
  }

  private func transferPublicKey() -> String? {
    let (status, existing) = lookupTransferKey()
    var privateKey = existing
    if status == errSecItemNotFound {
      guard let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        [.privateKeyUsage, .userPresence], nil) else { return nil }
      privateKey = SecKeyCreateRandomKey([
        kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        kSecAttrKeySizeInBits as String: 256, kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
        kSecPrivateKeyAttrs as String: [
          kSecAttrIsPermanent as String: true, kSecAttrApplicationTag as String: transferTag,
          kSecAttrAccessControl as String: access,
        ],
      ] as CFDictionary, nil)
    }
    guard let key = privateKey, let publicKey = SecKeyCopyPublicKey(key),
          let point = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?,
          point.count == 65, point.first == 4 else { return nil }
    // DER SubjectPublicKeyInfo prefix for an uncompressed P-256 point.
    let spki = Data([48, 89, 48, 19, 6, 7, 42, 134, 72, 206, 61, 2, 1, 6, 8, 42, 134, 72, 206,
                     61, 3, 1, 7, 3, 66, 0]) + point
    return urlSafe(spki)
  }

  private func approveTransfer(_ challenge: String?) -> String? {
    guard let challenge = challenge, challenge.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
    else { return nil }
    let auth = LAContext()
    auth.touchIDAuthenticationAllowableReuseDuration = 0
    let code = challenge.prefix(8).uppercased()
    auth.localizedReason = Locale.preferredLanguages.first?.hasPrefix("my") == true
      ? "စက်အသစ်တွင် \(code) ပြမှသာ အတည်ပြုပါ" : "Approve only if the new device shows \(code)."
    defer { auth.invalidate() }
    guard let key = lookupTransferKey(auth).1,
          let signature = SecKeyCreateSignature(key, .ecdsaSignatureMessageX962SHA256,
            Data(challenge.utf8) as CFData, nil) as Data? else { return nil }
    return urlSafe(signature)
  }

  private func urlSafe(_ bytes: Data) -> String {
    bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
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
