import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var layoutBridge: SystemLayoutBridge?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      layoutBridge = SystemLayoutBridge(controller: controller)
    }
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    layoutBridge?.dispose()
    layoutBridge = nil
    super.sceneDidDisconnect(scene)
  }
}

/// One scene, one existing engine, and no UIKit navigation containers. The
/// channel reports preferred bar context; Flutter explicitly renders its bar.
private final class SystemLayoutBridge: NSObject, FlutterStreamHandler {
  private weak var controller: FlutterViewController?
  private let channel: FlutterEventChannel
  private var probe: SystemLayoutProbe?
  private var sink: FlutterEventSink?
  private var sequence = 0
  private var lastSnapshot: NSDictionary?

  init(controller: FlutterViewController) {
    self.controller = controller
    channel = FlutterEventChannel(
      name: "mx.monetta/system_layout", binaryMessenger: controller.binaryMessenger)
    super.init()
    channel.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError? {
    sink = events
    lastSnapshot = nil
    guard let view = controller?.view else { return nil }
    let probe = SystemLayoutProbe(frame: view.bounds)
    probe.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    probe.isUserInteractionEnabled = false
    probe.accessibilityElementsHidden = true
    probe.onChange = { [weak self, weak view] probe in
      guard let self, let view else { return }
      self.publish(probe: probe, host: view)
    }
    view.addSubview(probe)
    self.probe = probe
    probe.setNeedsUpdateConstraints()
    probe.setNeedsLayout()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    probe?.detach()
    probe?.removeFromSuperview()
    probe = nil
    sink = nil
    lastSnapshot = nil
    return nil
  }

  func dispose() {
    _ = onCancel(withArguments: nil)
    channel.setStreamHandler(nil)
  }

  private func publish(probe: SystemLayoutProbe, host: UIView) {
    let insets = host.safeAreaInsets
    var snapshot: [String: Any] = [
      "supported": false,
      "width": host.bounds.width, "height": host.bounds.height,
      "safeInsets": ["left": insets.left, "top": insets.top,
                     "right": insets.right, "bottom": insets.bottom],
      "horizontalSizeClass": host.traitCollection.horizontalSizeClass.rawValue,
      "verticalSizeClass": host.traitCollection.verticalSizeClass.rawValue,
      "barEdge": "none", "divisions": [], "occlusions": [],
    ]
    // UIView.ReservedRegion and verticalBarEdge exist only in the iOS 27.1
    // SDK (Xcode 27, Swift 6.4). An older Xcode builds without the bridge and
    // reports "supported": false, which Dart treats as an unsupported host.
    #if compiler(>=6.4)
    if #available(iOS 27.1, *) {
      snapshot["supported"] = true
      switch host.traitCollection.verticalBarEdge {
      case .leading: snapshot["barEdge"] = "left"
      case .trailing: snapshot["barEdge"] = "right"
      default: break
      }
      func encode(_ regions: [UIView.ReservedRegion]) -> [[String: Any]] {
        regions.map { region in
          // UIKit points and Flutter logical pixels share this host's basis.
          // Convert from the probe, even though it currently fills the host.
          // The frame includes interactive margins; never expand it again.
          let frame = probe.convert(region.frame, to: host)
          return ["x": frame.minX, "y": frame.minY,
                  "width": frame.width, "height": frame.height,
                  "active": region.isActive,
                  "margins": ["left": region.margins.left,
                              "top": region.margins.top,
                              "right": region.margins.right,
                              "bottom": region.margins.bottom]]
        }
      }
      snapshot["divisions"] = encode(probe.divisions)
      snapshot["occlusions"] = encode(probe.occlusions)
    }
    #endif
    let value = snapshot as NSDictionary
    guard value != lastSnapshot else { return }
    lastSnapshot = value
    sequence += 1
    snapshot["sequence"] = sequence
    sink?(snapshot)
  }
}

/// UIKit tracks reserved-region reads in updateConstraints and invalidates
/// this view when they change. No polling, guessed hinge dimensions, or
/// notification observers survive a canceled Dart listener.
private final class SystemLayoutProbe: UIView {
  var onChange: ((SystemLayoutProbe) -> Void)?
  private var queued = false
  private var registration: Any?
  #if compiler(>=6.4)
  @available(iOS 27.1, *) var divisions: [UIView.ReservedRegion] {
    reservedRegions(kind: .division, options: .includeInactive)
  }
  @available(iOS 27.1, *) var occlusions: [UIView.ReservedRegion] {
    reservedRegions(kind: .occlusion)
  }
  #endif

  override init(frame: CGRect) {
    super.init(frame: frame)
    #if compiler(>=6.4)
    if #available(iOS 27.1, *) {
      registration = registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) {
        (probe: SystemLayoutProbe, _: UITraitCollection) in probe.schedule()
      }
    }
    #endif
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

  override func updateConstraints() {
    #if compiler(>=6.4)
    if #available(iOS 27.1, *) {
      _ = divisions
      _ = occlusions
    }
    #endif
    super.updateConstraints()
    schedule()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    schedule()
  }

  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    schedule()
  }

  private func schedule() {
    guard !queued, onChange != nil else { return }
    queued = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.queued = false
      self.onChange?(self)
    }
  }

  func detach() {
    onChange = nil
    if #available(iOS 17.0, *), let registration = registration as? UITraitChangeRegistration {
      unregisterForTraitChanges(registration)
      self.registration = nil
    }
  }
}
