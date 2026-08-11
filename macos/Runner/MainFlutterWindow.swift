import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Height of the app's own title bar, drawn in Flutter (DesktopTitleBar).
  private let gwTitleBarHeight: CGFloat = 46

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  /// Centres the traffic lights in the app's title bar.
  ///
  /// With a hidden title bar, macOS still lays the buttons out for its own
  /// standard 28pt bar, so against a 46pt one they sit too high and slightly
  /// too far left. Their container is resized to match, which moves all three
  /// together and keeps the spacing macOS chose — hand-placing each button
  /// tends to drift from the system look.
  private func positionTrafficLights() {
    guard let close = standardWindowButton(.closeButton),
          let container = close.superview else { return }

    var frame = container.frame
    guard frame.height != gwTitleBarHeight else { return }

    frame.size.height = gwTitleBarHeight
    // The container is pinned to the top of the window, and NSView origins are
    // bottom-left, so growing it downward means moving the origin down too.
    frame.origin.y = self.frame.height - gwTitleBarHeight
    container.frame = frame
  }

  // Re-applied on every layout: macOS puts the buttons back at their default
  // positions after a resize, a full-screen toggle, or a theme change.
  override func layoutIfNeeded() {
    super.layoutIfNeeded()
    positionTrafficLights()
  }

  override func setFrame(_ frameRect: NSRect, display flag: Bool) {
    super.setFrame(frameRect, display: flag)
    positionTrafficLights()
  }
}
