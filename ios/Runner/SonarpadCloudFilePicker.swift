import Flutter
import UIKit
import UniformTypeIdentifiers

/// Provides byte-counted, cancellable copies of Files/iCloud/third-party
/// document-provider content. Does not synthesize a percentage while a file
/// provider is still resolving or downloading content for NSFileCoordinator.
@available(iOS 14.0, *)
final class SonarpadCloudFilePicker: NSObject, FlutterPlugin, FlutterStreamHandler, UIDocumentPickerDelegate {
  private var pendingResult: FlutterResult?
  private var eventSink: FlutterEventSink?
  private let cancellationLock = NSLock()
  private var cancelled = false
  private var activeCoordinator: NSFileCoordinator?
  private var activeInput: FileHandle?
  private var activePicker: UIDocumentPickerViewController?
  private var allowedExtensions: Set<String> = []

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = SonarpadCloudFilePicker()
    let channel = FlutterMethodChannel(name: "sonarpad/cloud_file_picker", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: channel)
    let events = FlutterEventChannel(name: "sonarpad/cloud_file_picker_progress", binaryMessenger: registrar.messenger())
    events.setStreamHandler(plugin)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "cancel" {
      cancellationLock.lock()
      cancelled = true
      let coordinator = activeCoordinator
      let input = activeInput
      cancellationLock.unlock()
      coordinator?.cancel()
      try? input?.close()
      if let picker = activePicker {
        picker.dismiss(animated: true)
        finish(nil)
      }
      result(nil)
      return
    }
    guard call.method == "pickFiles" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard pendingResult == nil else {
      result(FlutterError(code: "picker_busy", message: "Another document picker is active", details: nil))
      return
    }
    guard let presenter = topPresenter() else {
      result(FlutterError(code: "picker_unavailable", message: "No active window", details: nil))
      return
    }
    let args = call.arguments as? [String: Any] ?? [:]
    allowedExtensions = Set((args["allowedExtensions"] as? [String] ?? [])
      .map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) })
    let types: [UTType]
    if allowedExtensions.isEmpty {
      types = [.item]
    } else {
      let mapped = allowedExtensions.compactMap { UTType(filenameExtension: $0) }
      types = mapped.isEmpty ? [.item] : mapped
    }
    cancellationLock.lock(); cancelled = false; cancellationLock.unlock()
    pendingResult = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
    picker.delegate = self
    picker.allowsMultipleSelection = args["allowMultiple"] as? Bool ?? false
    activePicker = picker
    presenter.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    activePicker = nil
    finish(nil)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    activePicker = nil
    guard !urls.isEmpty else { finish(nil); return }
    // The document picker can still be animating out when the delegate runs.
    // Delay beginning the copy until the system sheet has cleared, otherwise
    // the Flutter progress dialog opens underneath it and goes unnoticed.
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(350)) {
      if self.isCancelled() { self.finish(nil); return }
      self.beginCopy(urls)
    }
  }

  private func beginCopy(_ urls: [URL]) {
    publish(["stage": "preparing", "copied": 0, "total": -1])
    let selectedExtensions = allowedExtensions
    DispatchQueue.global(qos: .userInitiated).async {
      var results = [[String: Any]]()
      var copiedFiles = [URL]()
      do {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("sonarpad_cloud_import", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for source in urls {
          if self.isCancelled() { throw CloudCopyError.cancelled }
          let fileName = source.lastPathComponent
          if !selectedExtensions.isEmpty && !selectedExtensions.contains(source.pathExtension.lowercased()) {
            throw CloudCopyError.unsupported
          }
          let safeName = fileName.replacingOccurrences(of: "/", with: "_")
          let target = destination.appendingPathComponent("\(UUID().uuidString)_\(safeName)")
          copiedFiles.append(target)
          let size = try self.copyCoordinatedFile(from: source, to: target)
          results.append(["path": target.path, "name": fileName, "size": size])
        }
        DispatchQueue.main.async {
          if self.isCancelled() {
            for file in copiedFiles { try? FileManager.default.removeItem(at: file) }
            self.finish(nil)
          } else { self.finish(results) }
        }
      } catch {
        for file in copiedFiles { try? FileManager.default.removeItem(at: file) }
        DispatchQueue.main.async {
          if self.isCancelled() { self.finish(nil) }
          else { self.finish(FlutterError(code: "cloud_file_error", message: error.localizedDescription, details: nil)) }
        }
      }
    }
  }

  private func copyCoordinatedFile(from source: URL, to target: URL) throws -> Int64 {
    let access = source.startAccessingSecurityScopedResource()
    defer { if access { source.stopAccessingSecurityScopedResource() } }
    let coordinator = NSFileCoordinator(filePresenter: nil)
    cancellationLock.lock(); activeCoordinator = coordinator; cancellationLock.unlock()
    defer { cancellationLock.lock(); activeCoordinator = nil; cancellationLock.unlock() }
    var coordinationError: NSError?
    var copyError: Error?
    var bytesCopied: Int64 = 0
    coordinator.coordinate(readingItemAt: source, options: [], error: &coordinationError) { coordinatedURL in
      do {
        if self.isCancelled() { throw CloudCopyError.cancelled }
        let fileSize = (try? coordinatedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? -1
        self.publish(["stage": "copying", "copied": 0, "total": fileSize])
        FileManager.default.createFile(atPath: target.path, contents: nil)
        let input = try FileHandle(forReadingFrom: coordinatedURL)
        cancellationLock.lock(); activeInput = input; cancellationLock.unlock()
        defer { cancellationLock.lock(); activeInput = nil; cancellationLock.unlock() }
        let output = try FileHandle(forWritingTo: target)
        defer { try? input.close(); try? output.close() }
        var lastReportedPercent = -1
        while true {
          if self.isCancelled() { throw CloudCopyError.cancelled }
          let data = try input.read(upToCount: 65536) ?? Data()
          if data.isEmpty { break }
          try output.write(contentsOf: data)
          bytesCopied += Int64(data.count)
          let percent = fileSize > 0 ? Int(bytesCopied * 100 / fileSize) : -1
          if percent != lastReportedPercent || (fileSize <= 0 && bytesCopied % 1048576 < 65536) {
            lastReportedPercent = percent
            self.publish(["stage": "copying", "copied": bytesCopied, "total": fileSize])
          }
        }
        if fileSize > 0 && bytesCopied != fileSize {
          throw CloudCopyError.incomplete
        }
        self.publish(["stage": "copying", "copied": bytesCopied, "total": bytesCopied])
      } catch { copyError = error }
    }
    if let error = coordinationError { throw error }
    if let error = copyError { throw error }
    if isCancelled() { throw CloudCopyError.cancelled }
    return bytesCopied
  }

  private func isCancelled() -> Bool {
    cancellationLock.lock(); defer { cancellationLock.unlock() }
    return cancelled
  }

  private func publish(_ data: [String: Any]) {
    DispatchQueue.main.async { self.eventSink?(data) }
  }

  private func finish(_ value: Any?) {
    let callback = pendingResult
    pendingResult = nil
    activePicker = nil
    callback?(value)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func topPresenter() -> UIViewController? {
    var controller = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first(where: { $0.isKeyWindow })?.rootViewController
    while let presented = controller?.presentedViewController { controller = presented }
    return controller
  }
}

private enum CloudCopyError: LocalizedError {
  case cancelled, unsupported, incomplete
  var errorDescription: String? {
    switch self {
    case .cancelled: return "Copy cancelled"
    case .unsupported: return "Selected file type is not supported"
    case .incomplete: return "The file was not copied completely"
    }
  }
}
