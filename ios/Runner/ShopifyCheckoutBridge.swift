import Flutter
import ShopifyCheckoutSheetKit
import UIKit
import WebKit

final class ShopifyCheckoutBridge: NSObject, CheckoutDelegate {
  private static let channelName = "mx.monetta.checkout_kit"

  private let channel: FlutterMethodChannel
  private var pendingResult: FlutterResult?
  private weak var checkoutSheet: CheckoutViewController?
  private var checkoutNavigation: StagingCheckoutNavigation?

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
      let sheet = ShopifyCheckoutSheetKit.present(checkout: url, from: presenter, delegate: self)
      checkoutSheet = sheet
      if let arguments = call.arguments as? [String: Any],
         arguments["resumeAfterStorefrontPassword"] as? Bool == true,
         let page = sheet.topViewController,
         let webView = page.view.subviews.compactMap({ $0 as? WKWebView }).first {
        checkoutNavigation = StagingCheckoutNavigation(
          webView: webView,
          page: page,
          checkoutURL: url,
          onStorefront: { [weak self] in
            guard let self else { return }
            ShopifyCheckoutSheetKit.invalidate()
            self.finish(self.failed(code: "storefront_instead_of_checkout"), dismiss: true)
          }
        )
      }
    case "invalidate":
      ShopifyCheckoutSheetKit.invalidate()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
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

  private func finish(_ value: [String: String], dismiss: Bool = false) {
    guard let result = pendingResult else { return }
    pendingResult = nil
    checkoutNavigation = nil
    let sheet = checkoutSheet
    checkoutSheet = nil
    if dismiss, let sheet, sheet.presentingViewController != nil, !sheet.isBeingDismissed {
      sheet.dismiss(animated: true) { result(value) }
    } else {
      result(value)
    }
  }

  private func failed(code: String) -> [String: String] {
    ["status": "failed", "code": code]
  }

  func checkoutDidComplete(event _: CheckoutCompletedEvent) {
    finish(["status": "completed"])
  }

  func checkoutDidCancel() {
    finish(["status": "cancelled"], dismiss: true)
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

/// Keeps the password form and the checkout in the same WebKit session.
/// Shopify sends successful storefront logins to the shop home.
private final class StagingCheckoutNavigation {
  private var urlObservation: NSKeyValueObservation?
  private var loadingObservation: NSKeyValueObservation?
  private var sawPasswordPage = false
  private var resumed = false
  private let checkoutURL: URL
  private weak var page: UIViewController?
  private let onStorefront: () -> Void

  init(webView: WKWebView, page: UIViewController, checkoutURL: URL, onStorefront: @escaping () -> Void) {
    self.page = page
    self.checkoutURL = checkoutURL
    self.onStorefront = onStorefront
    urlObservation = webView.observe(\.url, options: [.new]) { [weak self] view, _ in
      self?.update(view)
    }
    loadingObservation = webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in
      self?.update(view)
    }
    DispatchQueue.main.async { [weak self, weak webView] in
      if let webView { self?.update(webView) }
    }
  }

  private func update(_ webView: WKWebView) {
    guard let url = webView.url, url.scheme == "https", url.host == checkoutURL.host else { return }
    let route = url.pathComponents.dropFirst().first ?? ""
    if route == "password" {
      sawPasswordPage = true
      page?.navigationItem.title = "Contraseña de staging"
      return
    }
    if route == "checkouts" || route == "checkout" {
      page?.navigationItem.title = ShopifyCheckoutSheetKit.configuration.title
      return
    }
    guard !webView.isLoading, ["", "collections", "products", "pages"].contains(route) else { return }
    if sawPasswordPage && !resumed {
      resumed = true
      // Reuse Shopify's exact cart URL so it can read the password session cookie.
      webView.load(URLRequest(url: checkoutURL))
    } else {
      onStorefront()
    }
  }
}
