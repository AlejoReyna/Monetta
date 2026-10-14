import Flutter
import ShopifyCheckoutSheetKit
import UIKit

final class ShopifyCheckoutBridge: NSObject, CheckoutDelegate {
  private static let channelName = "mx.monetta.checkout_kit"

  private let channel: FlutterMethodChannel
  private var pendingResult: FlutterResult?

  // Offsite-payment return link (Fase 5). The OS delivers the Universal Link
  // while Dart may not be listening yet (cold start), so the link stays
  // pending until the push or the `drainReturnLink` pull delivers it.
  private var pendingReturnLink: String?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: messenger
    )
    super.init()
    ShopifyCheckoutSheetKit.configure { configuration in
      configuration.logLevel = .none
    }
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "preload":
      guard let url = checkoutURL(from: call.arguments) else {
        result(FlutterError(code: "invalid_checkout", message: nil, details: nil))
        return
      }
      ShopifyCheckoutSheetKit.preload(checkout: url)
      result(nil)
    case "present":
      guard pendingResult == nil else {
        result(failed(code: "unavailable"))
        return
      }
      guard
        let url = checkoutURL(from: call.arguments),
        let presenter = topViewController()
      else {
        result(failed(code: "configuration"))
        return
      }
      pendingResult = result
      ShopifyCheckoutSheetKit.present(checkout: url, from: presenter, delegate: self)
    case "invalidate":
      ShopifyCheckoutSheetKit.invalidate()
      result(nil)
    case "drainReturnLink":
      let pending = pendingReturnLink
      pendingReturnLink = nil
      if let pending {
        result(["url": pending])
      } else {
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Forwards an OS-delivered Universal Link to Flutter for policy routing.
  /// Validation lives in Dart (`CheckoutReturnPolicy`); anything unexpected
  /// is rejected there. Overlong values are dropped before crossing.
  func handleReturnLink(url: URL) {
    let raw = url.absoluteString
    guard raw.count <= 4096 else { return }
    pendingReturnLink = raw
    channel.invokeMethod("onReturnLink", arguments: ["url": raw]) { [weak self] result in
      // Dart routes the link and answers void (nil). Anything else (a
      // FlutterError, or the not-implemented sentinel when Dart is not
      // listening yet on a cold start) keeps the link pending for the
      // `drainReturnLink` pull.
      if result == nil, self?.pendingReturnLink == raw {
        self?.pendingReturnLink = nil
      }
    }
  }

  private func checkoutURL(from arguments: Any?) -> URL? {
    guard
      let values = arguments as? [String: Any],
      let raw = values["url"] as? String,
      raw.count <= 4096,
      !raw.contains(where: { character in
        character == "\\" || character == "\r" || character == "\n" ||
          character == "\0" || character.isWhitespace
      }),
      !hasAuthorityUserInfoMarker(raw),
      let components = URLComponents(string: raw),
      components.scheme == "https",
      components.host != nil,
      components.user == nil,
      components.password == nil,
      components.fragment == nil,
      components.port == nil,
      !components.path.isEmpty,
      components.path != "/",
      let url = components.url
    else {
      return nil
    }
    return url
  }

  private func hasAuthorityUserInfoMarker(_ raw: String) -> Bool {
    guard let schemeEnd = raw.range(of: "://") else { return false }
    let authorityStart = schemeEnd.upperBound
    let remainder = raw[authorityStart...]
    let authorityEnd = remainder.firstIndex {
      $0 == "/" || $0 == "?" || $0 == "#" || $0 == "\\"
    }
    let authority = remainder[..<(authorityEnd ?? remainder.endIndex)]
    return authority.contains("@")
  }

  private func topViewController() -> UIViewController? {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController
    var current = root
    while let presented = current?.presentedViewController {
      current = presented
    }
    return current
  }

  private func finish(_ value: [String: String]) {
    guard let result = pendingResult else { return }
    pendingResult = nil
    result(value)
  }

  private func failed(code: String) -> [String: String] {
    ["status": "failed", "code": code]
  }

  func checkoutDidComplete(event _: CheckoutCompletedEvent) {
    finish(["status": "completed"])
  }

  func checkoutDidCancel() {
    finish(["status": "cancelled"])
  }

  func checkoutDidFail(error: CheckoutError) {
    let code: String
    switch error {
    case let .checkoutExpired(_, checkoutCode, _):
      code = checkoutCode.rawValue
    case .configurationError:
      code = "configuration"
    case .checkoutUnavailable:
      code = "unavailable"
    case .sdkError:
      code = "unknown"
    }
    finish(failed(code: code))
  }

  func shouldRecoverFromError(error _: CheckoutError) -> Bool {
    false
  }

  func checkoutDidClickLink(url _: URL) {
    // External links remain denied until the audited return-link phase.
  }

  func checkoutDidEmitWebPixelEvent(event _: PixelEvent) {
    // Payment/customer behavior never crosses the Flutter boundary.
  }
}
