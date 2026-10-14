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
  private var activeRequestId: String?
  private var requestStartedAt = 0.0
  private var selectionReceived = false

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
      if let picker = activePicker, let requestId = activeRequestId {
        afterPickerDismissal(picker) {
          self.finish(nil, requestId: requestId)
        }
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
    let requestId = args["requestId"] as? String ?? UUID().uuidString
    activeRequestId = requestId
    selectionReceived = false
    requestStartedAt = ProcessInfo.processInfo.systemUptime
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
    picker.delegate = self
    picker.allowsMultipleSelection = args["allowMultiple"] as? Bool ?? false
    activePicker = picker
    presenter.present(picker, animated: true) {
      self.publish(["stage": "picker_presented"], requestId: requestId)
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard activePicker === controller, let requestId = activeRequestId else { return }
    cancellationLock.lock(); cancelled = true; cancellationLock.unlock()
    afterPickerDismissal(controller) {
      self.finish(nil, requestId: requestId)
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard activePicker === controller, let requestId = activeRequestId else { return }
    guard !selectionReceived else { return }
    selectionReceived = true
    // This is the FIRST callback carrying selected URLs. Files may already have
    // downloaded iCloud/provider data. Do not call this a download-start event.
    publish(["stage": "selection_received", "fileCount": urls.count], requestId: requestId)
    afterPickerDismissal(controller) {
      guard self.activeRequestId == requestId, self.pendingResult != nil else { return }
      self.activePicker = nil
      self.publish(["stage": "picker_dismissed"], requestId: requestId)
      if self.isCancelled() || urls.isEmpty {
        self.finish(nil, requestId: requestId)
        return
      }
      self.beginCopy(urls, requestId: requestId)
    }
  }

  private func afterPickerDismissal(_ controller: UIDocumentPickerViewController,
                                    completion: @escaping () -> Void) {
    if controller.isBeingDismissed, let transition = controller.transitionCoordinator {
      let registered = transition.animate(alongsideTransition: nil) { context in
        if context.isCancelled {
          controller.dismiss(animated: false, completion: completion)
        } else {
          completion()
        }
      }
      if registered { return }
    }
    if controller.presentingViewController != nil {
      controller.dismiss(animated: true, completion: completion)
    } else {
      DispatchQueue.main.async(execute: completion)
    }
  }

  private func beginCopy(_ urls: [URL], requestId: String) {
    publish(["stage": "preparing", "copied": 0, "total": -1], requestId: requestId)
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
          let size = try self.copyCoordinatedFile(from: source, to: target, requestId: requestId)
          results.append(["path": target.path, "name": fileName, "size": size])
        }
        DispatchQueue.main.async {
          if self.isCancelled() {
            for file in copiedFiles { try? FileManager.default.removeItem(at: file) }
            self.finish(nil, requestId: requestId)
          } else { self.finish(results, requestId: requestId) }
        }
      } catch {
        for file in copiedFiles { try? FileManager.default.removeItem(at: file) }
        DispatchQueue.main.async {
          if self.isCancelled() { self.finish(nil, requestId: requestId) }
          else { self.finish(FlutterError(code: "cloud_file_error", message: error.localizedDescription, details: nil), requestId: requestId) }
        }
      }
    }
  }

  private func copyCoordinatedFile(from source: URL, to target: URL, requestId: String) throws -> Int64 {
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
        self.publish(["stage": "copying", "copied": 0, "total": fileSize], requestId: requestId)
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
            self.publish(["stage": "copying", "copied": bytesCopied, "total": fileSize], requestId: requestId)
          }
        }
        if fileSize > 0 && bytesCopied != fileSize {
          throw CloudCopyError.incomplete
        }
        self.publish(["stage": "copying", "copied": bytesCopied, "total": bytesCopied], requestId: requestId)
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

  private func publish(_ data: [String: Any], requestId: String) {
    DispatchQueue.main.async {
      guard self.activeRequestId == requestId, self.pendingResult != nil else { return }
      var event = data
      event["requestId"] = requestId
      event["elapsedMs"] = Int((ProcessInfo.processInfo.systemUptime - self.requestStartedAt) * 1000)
      self.eventSink?(event)
    }
  }

  private func finish(_ value: Any?, requestId: String) {
    // A late dismissal/cancel callback must never finish a newer import.
    guard activeRequestId == requestId else { return }
    let callback = pendingResult
    pendingResult = nil
    activePicker = nil
    activeRequestId = nil
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
