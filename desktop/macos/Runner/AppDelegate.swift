import Cocoa
import FlutterMacOS

private let runtimeChannelName = "pi.dev/desktop_runtime"

@main
class AppDelegate: FlutterAppDelegate, NSWindowDelegate {
  private var statusItem: NSStatusItem?
  private var showInMenuBarEnabled = true

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let iconName = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
       let iconPath = Bundle.main.path(forResource: iconName, ofType: "icns"),
       let icon = NSImage(contentsOfFile: iconPath) {
      NSApplication.shared.applicationIconImage = icon
    }

    super.applicationDidFinishLaunching(notification)
    configureRuntimeBridge()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return !showInMenuBarEnabled
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    if !flag {
      showMainWindow()
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    guard showInMenuBarEnabled else {
      return true
    }

    sender.orderOut(nil)
    return false
  }

  private func configureRuntimeBridge() {
    guard let window = mainFlutterWindow,
          let flutterViewController = window.contentViewController as? FlutterViewController else {
      return
    }

    window.delegate = self

    let runtimeChannel = FlutterMethodChannel(
      name: runtimeChannelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    runtimeChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "runtime-unavailable", message: "App delegate released", details: nil))
        return
      }

      switch call.method {
      case "setShowInMenuBarEnabled":
        guard let arguments = call.arguments as? [String: Any],
              let enabled = arguments["enabled"] as? Bool else {
          result(
            FlutterError(
              code: "invalid-arguments",
              message: "Expected a boolean 'enabled' argument",
              details: call.arguments
            )
          )
          return
        }

        self.setShowInMenuBarEnabled(enabled)
        result(nil)
      case "quitApplication":
        result(nil)
        NSApplication.shared.terminate(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setShowInMenuBarEnabled(_ enabled: Bool) {
    showInMenuBarEnabled = enabled

    if enabled {
      ensureStatusItem()
    } else {
      removeStatusItem()
    }
  }

  private func ensureStatusItem() {
    guard statusItem == nil else {
      return
    }

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let button = item.button {
      if let image = NSApplication.shared.applicationIconImage.copy() as? NSImage {
        image.size = NSSize(width: 18, height: 18)
        button.image = image
      } else {
        button.title = "Pi"
      }
      button.target = self
      button.action = #selector(handleStatusItemPressed)
      button.toolTip = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Pi App"
    }

    statusItem = item
  }

  private func removeStatusItem() {
    guard let statusItem else {
      return
    }

    NSStatusBar.system.removeStatusItem(statusItem)
    self.statusItem = nil
  }

  @objc private func handleStatusItemPressed() {
    showMainWindow()
  }

  private func showMainWindow() {
    guard let window = mainFlutterWindow else {
      return
    }

    NSApp.activate(ignoringOtherApps: true)
    if window.isMiniaturized {
      window.deminiaturize(nil)
    }
    window.makeKeyAndOrderFront(nil)
  }
}
