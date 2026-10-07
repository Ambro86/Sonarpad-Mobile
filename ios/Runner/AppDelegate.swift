import Flutter
import UIKit
import MediaPlayer
import AVFoundation
import PhotosUI
import MobileCoreServices

class SonarpadTTSPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SonarpadTTSPlugin()
    
    let commandsChannel = FlutterMethodChannel(name: "sonarpad/tts_commands", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: commandsChannel)
    
    let eventsChannel = FlutterEventChannel(name: "sonarpad/tts_events", binaryMessenger: registrar.messenger())
    eventsChannel.setStreamHandler(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "setupMagicTap" {
      setupMagicTap(title: call.arguments as? String ?? "Lettura Documento")
      result(nil)
    } else if call.method == "setMagicTapPlaying" {
      setMagicTapPlaying(call.arguments as? Bool ?? false)
      result(nil)
    } else if call.method == "clearMagicTap" {
      clearMagicTap()
      result(nil)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  private func setupMagicTap(title: String) {
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Failed to set audio session category.")
    }

    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.togglePlayPauseCommand.removeTarget(self, action: #selector(handleTogglePlayPause))
    commandCenter.playCommand.removeTarget(self, action: #selector(handleTogglePlayPause))
    commandCenter.pauseCommand.removeTarget(self, action: #selector(handleTogglePlayPause))

    commandCenter.togglePlayPauseCommand.isEnabled = true
    commandCenter.togglePlayPauseCommand.addTarget(self, action: #selector(handleTogglePlayPause))

    commandCenter.playCommand.isEnabled = true
    commandCenter.playCommand.addTarget(self, action: #selector(handleTogglePlayPause))

    commandCenter.pauseCommand.isEnabled = true
    commandCenter.pauseCommand.addTarget(self, action: #selector(handleTogglePlayPause))

    var nowPlayingInfo = [String : Any]()
    nowPlayingInfo[MPMediaItemPropertyTitle] = title
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }

  private func setMagicTapPlaying(_ isPlaying: Bool) {
    var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }

  private func clearMagicTap() {
    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.togglePlayPauseCommand.removeTarget(self, action: #selector(handleTogglePlayPause))
    commandCenter.playCommand.removeTarget(self, action: #selector(handleTogglePlayPause))
    commandCenter.pauseCommand.removeTarget(self, action: #selector(handleTogglePlayPause))
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }

  @objc private func handleTogglePlayPause(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
    self.eventSink?("toggle")
    return .success
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}

class SonarpadSharedMediaPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let shared = SonarpadSharedMediaPlugin()

  private var eventSink: FlutterEventSink?
  private var pendingPath: String?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SonarpadSharedMediaPlugin.shared

    let methodChannel = FlutterMethodChannel(
      name: "sonarpad/shared_media",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: methodChannel)

    let eventChannel = FlutterEventChannel(
      name: "sonarpad/shared_media_events",
      binaryMessenger: registrar.messenger()
    )
    eventChannel.setStreamHandler(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "getInitialSharedFile" {
      let path = pendingPath
      pendingPath = nil
      result(path)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  func handleSharedUrl(_ url: URL) {
    DispatchQueue.global(qos: .userInitiated).async {
      guard let path = self.copySharedFile(url) else { return }
      DispatchQueue.main.async {
        if let eventSink = self.eventSink {
          eventSink(path)
        } else {
          self.pendingPath = path
        }
      }
    }
  }

  private func copySharedFile(_ url: URL) -> String? {
    let didAccess = url.startAccessingSecurityScopedResource()
    defer {
      if didAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let fileManager = FileManager.default
      let cacheDir = try fileManager.url(
        for: .cachesDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      )
      let targetDir = cacheDir.appendingPathComponent("shared_media", isDirectory: true)
      try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)

      let originalName = url.lastPathComponent.isEmpty ? "shared_media" : url.lastPathComponent
      let safeName = originalName.replacingOccurrences(of: "/", with: "_")
      let target = targetDir.appendingPathComponent("\(UUID().uuidString)_\(safeName)")

      if fileManager.fileExists(atPath: target.path) {
        try fileManager.removeItem(at: target)
      }
      try fileManager.copyItem(at: url, to: target)
      return target.path
    } catch {
      print("SonarpadSharedMediaPlugin: failed to copy shared file: \(error)")
      return nil
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    if let pendingPath = pendingPath {
      events(pendingPath)
      self.pendingPath = nil
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}


@available(iOS 14.0, *)
class SonarpadPhotoLibraryImportPlugin: NSObject, FlutterPlugin, PHPickerViewControllerDelegate {
  private var pendingResult: FlutterResult?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SonarpadPhotoLibraryImportPlugin()
    let channel = FlutterMethodChannel(
      name: "sonarpad/photo_library_import",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "pickVideos" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard pendingResult == nil else {
      result(FlutterError(code: "picker_busy", message: "Photo picker already open", details: nil))
      return
    }
    guard let presenter = Self.topViewController() else {
      result(FlutterError(code: "no_presenter", message: "Unable to present Photos picker", details: nil))
      return
    }

    pendingResult = result
    let arguments = call.arguments as? [String: Any]
    let allowMultiple = arguments?["allowMultiple"] as? Bool ?? true
    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .videos
    configuration.selectionLimit = allowMultiple ? 0 : 1
    configuration.preferredAssetRepresentationMode = .current
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    presenter.present(picker, animated: true)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let callback = pendingResult else { return }
    pendingResult = nil
    if results.isEmpty {
      callback([])
      return
    }

    let group = DispatchGroup()
    let lock = NSLock()
    let importSession = UUID().uuidString
    var paths: [String] = []
    var firstError: Error?

    for item in results {
      let provider = item.itemProvider
      let typeIdentifier = kUTTypeMovie as String
      guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else { continue }
      group.enter()
      provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
        defer { group.leave() }
        if let error = error {
          lock.lock(); if firstError == nil { firstError = error }; lock.unlock()
          return
        }
        guard let url = url else { return }
        do {
          let fileManager = FileManager.default
          let targetDir = fileManager.temporaryDirectory
            .appendingPathComponent("sonarpad_photo_import", isDirectory: true)
            .appendingPathComponent(importSession, isDirectory: true)
          try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
          let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
          let suggestedName = provider.suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines)
          let rawBase = (suggestedName?.isEmpty == false ? suggestedName! : "video")
          let base = URL(fileURLWithPath: rawBase).deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "/", with: "_")
          var target = targetDir.appendingPathComponent("\(base).\(ext)")
          if fileManager.fileExists(atPath: target.path) {
            target = targetDir.appendingPathComponent("\(base)_\(UUID().uuidString).\(ext)")
          }
          try fileManager.copyItem(at: url, to: target)
          lock.lock(); paths.append(target.path); lock.unlock()
        } catch {
          lock.lock(); if firstError == nil { firstError = error }; lock.unlock()
        }
      }
    }

    group.notify(queue: .main) {
      if !paths.isEmpty {
        callback(paths)
      } else if let error = firstError {
        callback(FlutterError(code: "photo_import_failed", message: error.localizedDescription, details: nil))
      } else {
        callback([])
      }
    }
  }

  private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
    let root: UIViewController?
    if let base = base {
      root = base
    } else {
      root = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first(where: { $0.isKeyWindow })?.rootViewController
    }
    if let navigation = root as? UINavigationController {
      return topViewController(base: navigation.visibleViewController)
    }
    if let tab = root as? UITabBarController {
      return topViewController(base: tab.selectedViewController)
    }
    if let presented = root?.presentedViewController {
      return topViewController(base: presented)
    }
    return root
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    if url.isFileURL {
      SonarpadSharedMediaPlugin.shared.handleSharedUrl(url)
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    SonarpadTTSPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "SonarpadTTSPlugin")!)
    SonarpadRaiPlayerPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "SonarpadRaiPlayerPlugin")!)
    SonarpadSharedMediaPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "SonarpadSharedMediaPlugin")!)
    if #available(iOS 14.0, *) {
      SonarpadPhotoLibraryImportPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "SonarpadPhotoLibraryImportPlugin")!)
    }
    engineBridge.pluginRegistry.registerSonarpadNativeAccessibleViews()
  }
}
