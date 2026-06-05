import Flutter
import UIKit
import MediaPlayer
import AVFoundation

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
    SonarpadSharedMediaPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "SonarpadSharedMediaPlugin")!)
  }
}
