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

    // Without this the green button only zooms. A window with a hidden title
    // bar does not advertise full-screen support on its own, so macOS falls
    // back to zoom and the full-screen behaviour never appears.
    self.collectionBehavior.insert(.fullScreenPrimary)

    super.awakeFromNib()
  }

  /// Centres the traffic lights in the app's taller title bar.
  ///
  /// macOS lays the buttons out for its own 28pt bar, so against a 46pt one
  /// they sit hard against the top-left corner. Resizing their container moves
  /// all three together and keeps the spacing macOS chose — placing each
  /// button by hand drifts from the system look.
  private func positionTrafficLights() {
    guard let close = standardWindowButton(.closeButton),
          let container = close.superview,
          let parent = container.superview else { return }

    // Recomputed every time, never skipped. Guarding on height meant the
    // origin was only ever set once, so after a zoom or resize the container
    // kept a stale y and the buttons disappeared off the window.
    var frame = container.frame
    frame.size.height = gwTitleBarHeight
    frame.origin.y = parent.bounds.height - gwTitleBarHeight
    container.frame = frame
  }

  // Re-applied on every layout and resize: macOS restores the defaults after a
  // zoom, a full-screen toggle or a theme change.
  override func layoutIfNeeded() {
    super.layoutIfNeeded()
    positionTrafficLights()
  }

  override func setFrame(_ frameRect: NSRect, display flag: Bool) {
    super.setFrame(frameRect, display: flag)
    positionTrafficLights()
  }
}
