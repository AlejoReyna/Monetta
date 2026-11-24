import Flutter
import ImageIO
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var checkoutBridge: ShopifyCheckoutBridge?
  private var profilePhotoChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    checkoutBridge = ShopifyCheckoutBridge(
      messenger: messenger
    )
    let photoChannel = FlutterMethodChannel(name: "monetta/profile_photo", binaryMessenger: messenger)
    photoChannel.setMethodCallHandler { call, result in
      guard call.method == "convertHeic",
            let bytes = call.arguments as? FlutterStandardTypedData else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        let jpeg = Self.profilePhotoJPEG(bytes.data)
        DispatchQueue.main.async {
          result(jpeg.map { FlutterStandardTypedData(bytes: $0) })
        }
      }
    }
    profilePhotoChannel = photoChannel
  }

  private static func profilePhotoJPEG(_ data: Data) -> Data? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    let options = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: 384,
    ] as CFDictionary
    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
    let image = UIImage(cgImage: thumbnail)
    for quality: CGFloat in [0.72, 0.55, 0.4, 0.25] {
      // Base64 and the MIME prefix must fit the 60,000-character metafield.
      if let jpeg = image.jpegData(compressionQuality: quality), jpeg.count <= 44_980 {
        return jpeg
      }
    }
    return nil
  }
}
