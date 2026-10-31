import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var checkoutBridge: ShopifyCheckoutBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    checkoutBridge = ShopifyCheckoutBridge(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }

  // Offsite-payment return (Fase 5): Universal Links re-enter here. The URL
  // itself proves nothing about payment; the bridge forwards it to Flutter,
  // which validates host/path and re-presents through Checkout Kit.
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      checkoutBridge?.handleReturnLink(url: url)
      return true
    }
    return false
  }
}
