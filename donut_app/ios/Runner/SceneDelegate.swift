import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private let channelName = "donut/file_open"
  private var fileChannel: FlutterMethodChannel?
  private var pendingFilePath: String?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    setupFileChannelIfNeeded()
    if let url = connectionOptions.urlContexts.first?.url {
      handleIncomingURL(url)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    setupFileChannelIfNeeded()
    for context in URLContexts {
      handleIncomingURL(context.url)
    }
  }

  private func setupFileChannelIfNeeded() {
    guard fileChannel == nil else { return }
    guard let flutterViewController = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: flutterViewController.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      if call.method == "consumeInitialFile" {
        result(self.pendingFilePath)
        self.pendingFilePath = nil
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    fileChannel = channel
  }

  private func handleIncomingURL(_ url: URL) {
    guard url.isFileURL else { return }
    let path = url.path
    guard isSupported(path) else { return }
    if let fileChannel {
      fileChannel.invokeMethod("openFile", arguments: path)
    } else {
      pendingFilePath = path
    }
  }

  private func isSupported(_ path: String) -> Bool {
    let lower = path.lowercased()
    return lower.hasSuffix(".pdf") || lower.hasSuffix(".dpdf")
  }
}
