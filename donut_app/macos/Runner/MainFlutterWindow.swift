import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    (NSApp.delegate as? AppDelegate)?.onFlutterViewControllerReady(flutterViewController)
    registerForDraggedTypes([.fileURL])

    super.awakeFromNib()
  }

  @objc func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard !extractSupportedPaths(from: sender).isEmpty else {
      return []
    }
    return .copy
  }

  @objc func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let paths = extractSupportedPaths(from: sender)
    guard !paths.isEmpty else { return false }
    guard let delegate = NSApp.delegate as? AppDelegate else { return false }
    var handled = false
    for path in paths {
      handled = delegate.handleExternalFile(path) || handled
    }
    return handled
  }

  private func extractSupportedPaths(from sender: NSDraggingInfo) -> [String] {
    let classes = [NSURL.self]
    let options: [NSPasteboard.ReadingOptionKey: Any] = [
      .urlReadingFileURLsOnly: true,
    ]
    guard
      let urls = sender.draggingPasteboard.readObjects(
        forClasses: classes,
        options: options
      ) as? [URL]
    else {
      return []
    }

    return urls.map(\.path).filter { path in
      let lower = path.lowercased()
      return lower.hasSuffix(".pdf") || lower.hasSuffix(".dpdf")
    }
  }
}
