import AVFoundation
import Flutter
import UIKit

/// Native Rai HLS player for iOS.
///
/// RaiPlay uses AVPlayer/AVFoundation and native media selection for its HLS
/// streams. Sonarpad follows the same architecture here only for Rai channels;
/// all other TV/radio playback engines remain untouched.
final class SonarpadRaiPlayerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let shared = SonarpadRaiPlayerPlugin()

  private var eventSink: FlutterEventSink?
  private var player: AVPlayer?
  private var playerItem: AVPlayerItem?
  private var preferAudioDescription = true
  private var videoEnabled = false
  private var currentURL: URL?

  private var playerTimeControlObservation: NSKeyValueObservation?
  private var itemStatusObservation: NSKeyValueObservation?
  private var itemLikelyToKeepUpObservation: NSKeyValueObservation?
  private var itemBufferEmptyObservation: NSKeyValueObservation?
  private var periodicTimeObserver: Any?
  private var stalledObserver: NSObjectProtocol?
  private var failedToEndObserver: NSObjectProtocol?

  private let views = NSHashTable<SonarpadRaiPlayerPlatformView>.weakObjects()

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SonarpadRaiPlayerPlugin.shared

    let methodChannel = FlutterMethodChannel(
      name: "sonarpad/rai_player",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: methodChannel)

    let eventChannel = FlutterEventChannel(
      name: "sonarpad/rai_player_events",
      binaryMessenger: registrar.messenger()
    )
    eventChannel.setStreamHandler(instance)

    registrar.register(
      SonarpadRaiPlayerViewFactory(plugin: instance),
      withId: "sonarpad/rai_player_view"
    )
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "open":
      guard
        let arguments = call.arguments as? [String: Any],
        let rawURL = arguments["url"] as? String,
        let url = URL(string: rawURL)
      else {
        result(FlutterError(code: "invalid_arguments", message: "Invalid Rai stream URL.", details: nil))
        return
      }

      let rawHeaders = arguments["headers"] as? [String: Any] ?? [:]
      var headers: [String: String] = [:]
      for (key, value) in rawHeaders {
        if let stringValue = value as? String, !stringValue.isEmpty {
          headers[key] = stringValue
        }
      }

      let preferAD = arguments["preferAudioDescription"] as? Bool ?? true
      let showVideo = arguments["videoEnabled"] as? Bool ?? false
      let volume = (arguments["volume"] as? NSNumber)?.floatValue ?? 1.0
      open(
        url: url,
        headers: headers,
        preferAudioDescription: preferAD,
        videoEnabled: showVideo,
        volume: min(max(volume, 0), 1)
      )
      result(nil)

    case "play":
      player?.play()
      emitState(reason: "play")
      result(nil)

    case "pause":
      player?.pause()
      emitState(reason: "pause")
      result(nil)

    case "stop":
      player?.pause()
      if let player = player {
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
      }
      emitState(reason: "stop")
      result(nil)

    case "dispose":
      disposePlayer()
      result(nil)

    case "setVolume":
      if let number = call.arguments as? NSNumber {
        player?.volume = min(max(number.floatValue, 0), 1)
      }
      result(nil)

    case "setVideoEnabled":
      videoEnabled = call.arguments as? Bool ?? false
      updateViews()
      emit(["type": "video", "enabled": videoEnabled])
      result(nil)

    case "setPreferAudioDescription":
      preferAudioDescription = call.arguments as? Bool ?? true
      selectPreferredAudioTrack()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func open(
    url: URL,
    headers: [String: String],
    preferAudioDescription: Bool,
    videoEnabled: Bool,
    volume: Float
  ) {
    disposePlayer(emitDisposed: false)
    self.preferAudioDescription = preferAudioDescription
    self.videoEnabled = videoEnabled
    currentURL = url

    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .moviePlayback, options: [])
      try session.setActive(true)
    } catch {
      emitLog("audio_session_error", message: error.localizedDescription)
    }

    // AVFoundation keeps the same HTTP stack for the HLS master, its child
    // playlists and segment requests. This mirrors the official Rai player
    // architecture more closely than opening rendition playlists with FFmpeg.
    var options: [String: Any] = [:]
    // AVURLAssetHTTPHeaderFieldsKey is not a supported public API. Use the
    // documented User-Agent option and let AVFoundation own the HLS session.
    if #available(iOS 16.0, *),
       let userAgent = headers["User-Agent"],
       !userAgent.isEmpty {
      options[AVURLAssetHTTPUserAgentKey] = userAgent
    }
    options[AVURLAssetAllowsCellularAccessKey] = true
    if #available(iOS 13.0, *) {
      options[AVURLAssetAllowsExpensiveNetworkAccessKey] = true
      options[AVURLAssetAllowsConstrainedNetworkAccessKey] = true
    }

    let asset = AVURLAsset(url: url, options: options)
    let item = AVPlayerItem(asset: asset)
    item.preferredForwardBufferDuration = 2
    item.canUseNetworkResourcesForLiveStreamingWhilePaused = true

    let newPlayer = AVPlayer(playerItem: item)
    // VoiceOver can make AVPlayer prefer accessibility audio automatically.
    // Disable automatic media-selection criteria so Sonarpad's explicit
    // "prefer audio description" setting remains authoritative.
    newPlayer.appliesMediaSelectionCriteriaAutomatically = false
    newPlayer.volume = volume
    newPlayer.automaticallyWaitsToMinimizeStalling = true

    playerItem = item
    player = newPlayer
    updateViews()
    attachObservers(player: newPlayer, item: item)

    emit([
      "type": "opened",
      "url": safeURL(url),
      "preferAudioDescription": preferAudioDescription,
      "videoEnabled": videoEnabled,
      "headerNames": Array(headers.keys).sorted(),
    ])

    newPlayer.play()
  }

  private func attachObservers(player: AVPlayer, item: AVPlayerItem) {
    playerTimeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
      DispatchQueue.main.async {
        self?.emitState(reason: "time_control")
      }
    }

    itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
      DispatchQueue.main.async {
        guard let self = self else { return }
        switch item.status {
        case .readyToPlay:
          self.selectPreferredAudioTrack()
          self.emit(["type": "ready"])
          self.emitState(reason: "ready")
        case .failed:
          self.emitError(item.error ?? NSError(
            domain: "SonarpadRaiPlayer",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "AVPlayerItem failed"]
          ))
        case .unknown:
          self.emitState(reason: "loading")
        @unknown default:
          self.emitState(reason: "unknown")
        }
      }
    }

    itemLikelyToKeepUpObservation = item.observe(\.isPlaybackLikelyToKeepUp, options: [.initial, .new]) { [weak self] _, _ in
      DispatchQueue.main.async {
        self?.emitState(reason: "likely_to_keep_up")
      }
    }

    itemBufferEmptyObservation = item.observe(\.isPlaybackBufferEmpty, options: [.initial, .new]) { [weak self] _, _ in
      DispatchQueue.main.async {
        self?.emitState(reason: "buffer_empty")
      }
    }

    periodicTimeObserver = player.addPeriodicTimeObserver(
      forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
      queue: .main
    ) { [weak self] time in
      guard let self = self else { return }
      let positionMs = self.milliseconds(time)
      let durationMs = self.milliseconds(item.duration)
      self.emit([
        "type": "position",
        "positionMs": positionMs,
        "durationMs": durationMs,
      ])
    }

    stalledObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemPlaybackStalled,
      object: item,
      queue: .main
    ) { [weak self] _ in
      self?.emit(["type": "stalled"])
      self?.emitState(reason: "stalled")
    }

    failedToEndObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemFailedToPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] notification in
      let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
      self?.emitError(error ?? NSError(
        domain: "SonarpadRaiPlayer",
        code: -2,
        userInfo: [NSLocalizedDescriptionKey: "AVPlayer failed to play the Rai stream"]
      ))
    }
  }

  private func selectPreferredAudioTrack() {
    guard let item = playerItem else { return }
    let asset = item.asset
    guard let group = asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
      emit(["type": "audio_tracks", "tracks": [], "selected": NSNull()])
      return
    }

    var described: AVMediaSelectionOption?
    var italian: AVMediaSelectionOption?
    var tracks: [[String: Any]] = []

    for option in group.options {
      let displayName = option.displayName
      let localeIdentifier = option.locale?.identifier ?? ""
      let languageCode = option.locale?.languageCode ?? ""
      let normalizedName = displayName.lowercased()
      let normalizedLocale = localeIdentifier.lowercased()
      let normalizedLanguage = languageCode.lowercased()
      let describesVideo = option.hasMediaCharacteristic(.describesVideoForAccessibility)

      let isDescription = describesVideo ||
        normalizedLanguage == "des" ||
        normalizedLocale == "des" ||
        normalizedName.contains("audiodescri") ||
        normalizedName.contains("audio descri") ||
        normalizedName.contains("descrizione")

      let isItalian = normalizedLanguage == "it" ||
        normalizedLanguage == "ita" ||
        normalizedLocale == "it" ||
        normalizedLocale.hasPrefix("it-") ||
        normalizedName.contains("italiano") ||
        normalizedName == "italian"

      if described == nil && isDescription {
        described = option
      }
      if italian == nil && isItalian && !isDescription {
        italian = option
      }

      tracks.append([
        "name": displayName,
        "locale": localeIdentifier,
        "language": languageCode,
        "describesVideo": describesVideo,
        "isAudioDescription": isDescription,
        "isItalian": isItalian,
      ])
    }

    let selected: AVMediaSelectionOption?
    if preferAudioDescription {
      selected = described ?? italian
    } else {
      selected = italian
    }

    if let selected = selected {
      item.select(selected, in: group)
    }

    emit([
      "type": "audio_tracks",
      "tracks": tracks,
      "preferAudioDescription": preferAudioDescription,
      "selected": selected?.displayName ?? NSNull(),
      "selectedLocale": selected?.locale?.identifier ?? NSNull(),
      "selectedIsAudioDescription": described.map { describedOption in
        selected?.isEqual(describedOption) ?? false
      } ?? false,
    ])
  }

  private func emitState(reason: String) {
    guard let player = player else { return }
    let item = player.currentItem
    let playing = player.timeControlStatus == .playing
    let buffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate ||
      (item?.isPlaybackBufferEmpty ?? false)
    emit([
      "type": "state",
      "reason": reason,
      "playing": playing,
      "buffering": buffering,
      "likelyToKeepUp": item?.isPlaybackLikelyToKeepUp ?? false,
      "rate": player.rate,
      "positionMs": milliseconds(player.currentTime()),
      "durationMs": milliseconds(item?.duration ?? .invalid),
    ])
  }

  private func emitError(_ error: Error) {
    let nsError = error as NSError
    emit([
      "type": "error",
      "domain": nsError.domain,
      "code": nsError.code,
      "message": nsError.localizedDescription,
      "url": currentURL.map(safeURL) ?? NSNull(),
    ])
  }

  private func emitLog(_ category: String, message: String) {
    emit([
      "type": "log",
      "category": category,
      "message": message,
    ])
  }

  private func milliseconds(_ time: CMTime) -> Int64 {
    guard time.isValid && time.isNumeric else { return 0 }
    let seconds = CMTimeGetSeconds(time)
    guard seconds.isFinite && seconds >= 0 else { return 0 }
    return Int64(seconds * 1000)
  }

  private func safeURL(_ url: URL) -> String {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return url.host ?? "rai-stream"
    }
    if components.query != nil {
      components.query = "<redacted>"
    }
    return components.string ?? (url.host ?? "rai-stream")
  }

  private func disposePlayer(emitDisposed: Bool = true) {
    if let observer = periodicTimeObserver, let player = player {
      player.removeTimeObserver(observer)
    }
    periodicTimeObserver = nil

    playerTimeControlObservation?.invalidate()
    itemStatusObservation?.invalidate()
    itemLikelyToKeepUpObservation?.invalidate()
    itemBufferEmptyObservation?.invalidate()
    playerTimeControlObservation = nil
    itemStatusObservation = nil
    itemLikelyToKeepUpObservation = nil
    itemBufferEmptyObservation = nil

    if let observer = stalledObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    if let observer = failedToEndObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    stalledObserver = nil
    failedToEndObserver = nil

    player?.pause()
    player?.replaceCurrentItem(with: nil)
    player = nil
    playerItem = nil
    currentURL = nil
    updateViews()
    if emitDisposed {
      emit(["type": "disposed"])
    }
  }

  fileprivate func attach(view: SonarpadRaiPlayerPlatformView) {
    views.add(view)
    view.setPlayer(player, videoEnabled: videoEnabled)
  }

  fileprivate func detach(view: SonarpadRaiPlayerPlatformView) {
    views.remove(view)
  }

  private func updateViews() {
    for view in views.allObjects {
      view.setPlayer(player, videoEnabled: videoEnabled)
    }
  }

  private func emit(_ value: [String: Any]) {
    guard let eventSink = eventSink else { return }
    if Thread.isMainThread {
      eventSink(value)
    } else {
      DispatchQueue.main.async {
        self.eventSink?(value)
      }
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    emitState(reason: "listen")
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

final class SonarpadRaiPlayerViewFactory: NSObject, FlutterPlatformViewFactory {
  private weak var plugin: SonarpadRaiPlayerPlugin?

  init(plugin: SonarpadRaiPlayerPlugin) {
    self.plugin = plugin
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    SonarpadRaiPlayerPlatformView(
      frame: frame,
      viewId: viewId,
      plugin: plugin ?? SonarpadRaiPlayerPlugin.shared
    )
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class SonarpadRaiPlayerPlatformView: NSObject, FlutterPlatformView {
  private let container: SonarpadRaiPlayerContainerView
  private weak var plugin: SonarpadRaiPlayerPlugin?

  init(frame: CGRect, viewId: Int64, plugin: SonarpadRaiPlayerPlugin) {
    container = SonarpadRaiPlayerContainerView(frame: frame)
    self.plugin = plugin
    super.init()
    plugin.attach(view: self)
  }

  deinit {
    plugin?.detach(view: self)
  }

  func view() -> UIView {
    container
  }

  fileprivate func setPlayer(_ player: AVPlayer?, videoEnabled: Bool) {
    container.playerLayer.player = player
    container.playerLayer.isHidden = !videoEnabled
  }
}

final class SonarpadRaiPlayerContainerView: UIView {
  override class var layerClass: AnyClass {
    AVPlayerLayer.self
  }

  var playerLayer: AVPlayerLayer {
    layer as! AVPlayerLayer
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .black
    playerLayer.videoGravity = .resizeAspect
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    backgroundColor = .black
    playerLayer.videoGravity = .resizeAspect
  }
}
