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

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    SonarpadTTSPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "SonarpadTTSPlugin")!)
  }
}
