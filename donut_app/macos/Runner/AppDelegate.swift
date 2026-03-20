import Cocoa
import Carbon.HIToolbox
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let channelName = "donut/file_open"
  private let themeChannelName = "donut/window_theme"
  private var fileChannel: FlutterMethodChannel?
  private var themeChannel: FlutterMethodChannel?
  private var pendingFilePaths: [String] = []
  private var isDartReadyForFileEvents = false
  private weak var flutterViewController: FlutterViewController?
  private var pendingNativeLogs: [String] = []

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    nativeLog("applicationDidFinishLaunching")
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleOpenDocumentsAppleEvent(_:withReplyEvent:)),
      forEventClass: AEEventClass(kCoreEventClass),
      andEventID: AEEventID(kAEOpenDocuments)
    )
    setupFileChannelIfNeeded()
    setupThemeChannelIfNeeded()
  }

  override func applicationDidBecomeActive(_ notification: Notification) {
    super.applicationDidBecomeActive(notification)
    nativeLog("applicationDidBecomeActive")
    setupFileChannelIfNeeded()
    setupThemeChannelIfNeeded()
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    nativeLog("application open(urls:) count=\(urls.count)")
    for url in urls {
      nativeLog("application open(urls:) url=\(url.path)")
      _ = handleExternalFile(url.path)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    nativeLog("openFile path=\(filename)")
    return handleExternalFile(filename)
  }

  override func application(_ application: NSApplication, openFiles filenames: [String]) {
    nativeLog("openFiles count=\(filenames.count)")
    let handled = filenames.reduce(false) { partialResult, path in
      handleExternalFile(path) || partialResult
    }
    application.reply(toOpenOrPrint: handled ? .success : .failure)
  }

  @objc private func handleOpenDocumentsAppleEvent(
    _ event: NSAppleEventDescriptor,
    withReplyEvent replyEvent: NSAppleEventDescriptor
  ) {
    let keyDirectObject = AEKeyword(keyDirectObject)
    guard let fileListDescriptor = event.paramDescriptor(forKeyword: keyDirectObject) else {
      nativeLog("appleEvent open-documents missing direct object")
      return
    }
    nativeLog("appleEvent open-documents items=\(fileListDescriptor.numberOfItems)")
    for index in 1...fileListDescriptor.numberOfItems {
      guard let item = fileListDescriptor.atIndex(index) else { continue }
      if let path = item.stringValue {
        nativeLog("appleEvent path(raw)=\(path)")
        _ = handleExternalFile(path)
      } else if let fileURL = item.fileURLValue {
        nativeLog("appleEvent url=\(fileURL.path)")
        _ = handleExternalFile(fileURL.path)
      } else {
        nativeLog("appleEvent item at \(index) not parseable")
      }
    }
  }

  private func setupFileChannelIfNeeded() {
    guard fileChannel == nil else { return }
    let viewController =
      flutterViewController ??
      (mainFlutterWindow?.contentViewController as? FlutterViewController)
    guard let viewController else {
      nativeLog("setupFileChannelIfNeeded: no FlutterViewController yet")
      return
    }
    flutterViewController = viewController
    nativeLog("setupFileChannelIfNeeded: creating channel")

    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: viewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      if call.method == "consumeInitialFile" {
        self.nativeLog("consumeInitialFile called pending=\(self.pendingFilePaths.count)")
        if self.pendingFilePaths.isEmpty {
          result(nil)
        } else {
          result(self.pendingFilePaths.removeFirst())
        }
      } else if call.method == "setDartReadyForFileOpenEvents" {
        self.nativeLog("Dart ready signal received")
        self.isDartReadyForFileEvents = true
        self.flushPendingFilePathsIfPossible()
        self.flushPendingNativeLogsIfPossible()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    fileChannel = channel
    nativeLog("setupFileChannelIfNeeded: channel ready")
    flushPendingNativeLogsIfPossible()
  }

  private func setupThemeChannelIfNeeded() {
    guard themeChannel == nil else { return }
    let viewController =
      flutterViewController ??
      (mainFlutterWindow?.contentViewController as? FlutterViewController)
    guard let viewController else {
      return
    }
    flutterViewController = viewController

    let channel = FlutterMethodChannel(
      name: themeChannelName,
      binaryMessenger: viewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      if call.method == "setThemeMode", let mode = call.arguments as? String {
        self.applyWindowTheme(mode: mode)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    themeChannel = channel
  }

  func onFlutterViewControllerReady(_ controller: FlutterViewController) {
    nativeLog("onFlutterViewControllerReady")
    flutterViewController = controller
    setupFileChannelIfNeeded()
    setupThemeChannelIfNeeded()
  }

  @discardableResult
  func handleExternalFile(_ path: String) -> Bool {
    return dispatchOpenFile(path)
  }

  private func dispatchOpenFile(_ path: String) -> Bool {
    nativeLog("dispatchOpenFile path=\(path)")
    guard isSupported(path) else { return false }
    setupFileChannelIfNeeded()
    if let fileChannel, isDartReadyForFileEvents {
      nativeLog("dispatchOpenFile immediate invoke path=\(path)")
      fileChannel.invokeMethod("openFile", arguments: path)
    } else {
      nativeLog("dispatchOpenFile queued path=\(path)")
      pendingFilePaths.append(path)
    }
    return true
  }

  private func flushPendingFilePathsIfPossible() {
    guard isDartReadyForFileEvents else { return }
    guard let fileChannel else { return }
    nativeLog("flushPendingFilePathsIfPossible count=\(pendingFilePaths.count)")
    while !pendingFilePaths.isEmpty {
      let nextPath = pendingFilePaths.removeFirst()
      fileChannel.invokeMethod("openFile", arguments: nextPath)
    }
  }

  private func nativeLog(_ message: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    let line = "[\(ts)][NATIVE] \(message)"
    if let fileChannel, isDartReadyForFileEvents {
      fileChannel.invokeMethod("debugLog", arguments: line)
    } else {
      pendingNativeLogs.append(line)
    }
  }

  private func flushPendingNativeLogsIfPossible() {
    guard isDartReadyForFileEvents else { return }
    guard let fileChannel else { return }
    while !pendingNativeLogs.isEmpty {
      fileChannel.invokeMethod("debugLog", arguments: pendingNativeLogs.removeFirst())
    }
  }

  private func isSupported(_ path: String) -> Bool {
    let lower = path.lowercased()
    return lower.hasSuffix(".pdf") || lower.hasSuffix(".dpdf")
  }

  private func applyWindowTheme(mode: String) {
    switch mode {
    case "dark":
      NSApp.appearance = NSAppearance(named: .darkAqua)
      mainFlutterWindow?.appearance = NSAppearance(named: .darkAqua)
    case "light":
      NSApp.appearance = NSAppearance(named: .aqua)
      mainFlutterWindow?.appearance = NSAppearance(named: .aqua)
    default:
      NSApp.appearance = nil
      mainFlutterWindow?.appearance = nil
    }
    nativeLog("applyWindowTheme mode=\(mode)")
  }
}
