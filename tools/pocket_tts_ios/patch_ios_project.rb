#!/usr/bin/env ruby
# Prepara e collega il bridge iOS di Pocket TTS.
#
# Modalità sicura:
# - se PocketTTS.xcframework non è presente, genera un bridge stub: la build iOS continua
#   e Flutter vede Pocket TTS come non disponibile.
# - se il workflow ha scaricato PocketTTS.xcframework e pocket_tts_ios.swift, li collega
#   al target Runner e genera un bridge reale Flutter -> Swift -> PocketTTS.

require 'xcodeproj'
require 'fileutils'

project_path = Dir.glob('ios/*.xcodeproj').first
abort 'Progetto Xcode iOS non trovato. Esegui prima flutter create --platforms=ios .' unless project_path

runner_dir = File.join('ios', 'Runner')
framework_dir = File.join('ios', 'Frameworks', 'PocketTTS.xcframework')
bindings_path = File.join(runner_dir, 'pocket_tts_ios.swift')
bridge_path = File.join(runner_dir, 'SonarpadPocketTtsBridge.swift')

FileUtils.mkdir_p(runner_dir)

native_ready = Dir.exist?(framework_dir) && File.exist?(bindings_path)

def swift_bridge_source(native_ready)
  unless native_ready
    return <<~SWIFT
      import Foundation
      import Flutter

      final class SonarpadPocketTtsBridge: NSObject {
        static let ttsChannelName = "sonarpad/pocket_tts"
        static let modelChannelName = "sonarpad/pocket_tts_model"

        static func register(with messenger: FlutterBinaryMessenger) {
          let instance = SonarpadPocketTtsBridge()

          let ttsChannel = FlutterMethodChannel(name: ttsChannelName, binaryMessenger: messenger)
          ttsChannel.setMethodCallHandler { call, result in
            instance.handleTts(call, result: result)
          }

          let modelChannel = FlutterMethodChannel(name: modelChannelName, binaryMessenger: messenger)
          modelChannel.setMethodCallHandler { call, result in
            instance.handleModel(call, result: result)
          }
        }

        private func handleTts(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
          switch call.method {
          case "isAvailable":
            result(false)
          case "synthesizeToFile":
            result(FlutterError(
              code: "pocket_tts_unavailable",
              message: "Pocket TTS non è collegato in questa build iOS.",
              details: nil
            ))
          default:
            result(FlutterMethodNotImplemented)
          }
        }

        private func handleModel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
          switch call.method {
          case "excludeFromBackup":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String,
                  !path.isEmpty else {
              result(FlutterError(code: "invalid_path", message: "Percorso modello non valido.", details: nil))
              return
            }
            var url = URL(fileURLWithPath: path)
            do {
              var values = URLResourceValues()
              values.isExcludedFromBackup = true
              try url.setResourceValues(values)
              result(nil)
            } catch {
              result(FlutterError(code: "exclude_backup_failed", message: error.localizedDescription, details: nil))
            }
          default:
            result(FlutterMethodNotImplemented)
          }
        }
      }
    SWIFT
  end

  <<~SWIFT
    import Foundation
    import Flutter

    final class SonarpadPocketTtsBridge: NSObject {
      static let ttsChannelName = "sonarpad/pocket_tts"
      static let modelChannelName = "sonarpad/pocket_tts_model"

      private var engine: PocketTtsEngine?
      private var engineModelPath: String?

      static func register(with messenger: FlutterBinaryMessenger) {
        let instance = SonarpadPocketTtsBridge()

        let ttsChannel = FlutterMethodChannel(name: ttsChannelName, binaryMessenger: messenger)
        ttsChannel.setMethodCallHandler { call, result in
          instance.handleTts(call, result: result)
        }

        let modelChannel = FlutterMethodChannel(name: modelChannelName, binaryMessenger: messenger)
        modelChannel.setMethodCallHandler { call, result in
          instance.handleModel(call, result: result)
        }
      }

      private func handleTts(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
          let args = call.arguments as? [String: Any]
          let modelPath = (args?["modelPath"] as? String) ?? ""
          result(isUsableModelDirectory(modelPath))

        case "synthesizeToFile":
          synthesizeToFile(call, result: result)

        default:
          result(FlutterMethodNotImplemented)
        }
      }

      private func handleModel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "excludeFromBackup":
          guard let args = call.arguments as? [String: Any],
                let path = args["path"] as? String,
                !path.isEmpty else {
            result(FlutterError(code: "invalid_path", message: "Percorso modello non valido.", details: nil))
            return
          }
          var url = URL(fileURLWithPath: path)
          do {
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try url.setResourceValues(values)
            result(nil)
          } catch {
            result(FlutterError(code: "exclude_backup_failed", message: error.localizedDescription, details: nil))
          }

        default:
          result(FlutterMethodNotImplemented)
        }
      }

      private func isUsableModelDirectory(_ modelPath: String) -> Bool {
        guard !modelPath.isEmpty else { return false }
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: modelPath, isDirectory: &isDir), isDir.boolValue else {
          return false
        }
        let requiredFiles = [
          "model.safetensors",
          "tokenizer.model",
          "voices/alba.safetensors"
        ]
        return requiredFiles.allSatisfy { fm.fileExists(atPath: (modelPath as NSString).appendingPathComponent($0)) }
      }

      private func voiceIndex(for rawVoice: String?) -> UInt32 {
        switch rawVoice?.lowercased() {
        case "marius": return 1
        case "javert": return 2
        case "jean": return 3
        case "fantine": return 4
        case "cosette": return 5
        case "eponine", "éponine": return 6
        case "azelma": return 7
        case "alba", nil: return 0
        default: return 0
        }
      }

      private func cachedEngine(modelPath: String) throws -> PocketTtsEngine {
        if let engine = engine, engineModelPath == modelPath {
          return engine
        }
        let newEngine = try PocketTtsEngine(modelPath: modelPath)
        engine = newEngine
        engineModelPath = modelPath
        return newEngine
      }

      private func synthesizeToFile(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "invalid_args", message: "Argomenti Pocket TTS mancanti.", details: nil))
          return
        }

        let text = (args["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let modelPath = (args["modelPath"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let voice = args["voice"] as? String
        let language = args["language"] as? String ?? "auto"
        let speed = args["speed"] as? Double ?? 1.0

        guard !text.isEmpty else {
          result(FlutterError(code: "empty_text", message: "Testo vuoto per Pocket TTS.", details: nil))
          return
        }
        guard isUsableModelDirectory(modelPath) else {
          result(FlutterError(code: "model_missing", message: "Modello Pocket TTS non scaricato o incompleto.", details: nil))
          return
        }

        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let hadCachedEngine = self.engine != nil && self.engineModelPath == modelPath
            NSLog("Sonarpad Pocket TTS: synthesize native start chars=%d voice=%@ language=%@ speed=%.2f cachedEngine=%@", text.count, voice ?? "default", language, speed, hadCachedEngine ? "true" : "false")
            let engine = try self.cachedEngine(modelPath: modelPath)
            let config = TtsConfig(
              voiceIndex: self.voiceIndex(for: voice),
              temperature: 0.7,
              topP: 0.9,
              speed: Float(max(0.5, min(speed, 2.0))),
              consistencySteps: 2,
              useFixedSeed: false,
              seed: 42
            )
            try engine.configure(config: config)
            let synthesis = try engine.synthesize(text: text)
            let audioData = Data(synthesis.audioData)
            guard !audioData.isEmpty else {
              throw NSError(domain: "SonarpadPocketTts", code: 10, userInfo: [NSLocalizedDescriptionKey: "Pocket TTS non ha prodotto audio."])
            }

            let outURL = URL(fileURLWithPath: NSTemporaryDirectory())
              .appendingPathComponent("sonarpad_pocket_tts_\(UUID().uuidString).wav")
            try audioData.write(to: outURL, options: .atomic)

            DispatchQueue.main.async {
              result([
                "path": outURL.path,
                "cachedEngine": hadCachedEngine,
                "audioBytes": audioData.count,
                "sampleRate": synthesis.sampleRate,
                "durationSeconds": synthesis.durationSeconds,
                "language": language
              ])
            }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "synthesis_failed", message: error.localizedDescription, details: nil))
            }
          }
        }
      }
    }
  SWIFT
end

File.write(bridge_path, swift_bridge_source(native_ready))

app_delegate_path = File.join(runner_dir, 'AppDelegate.swift')
if File.exist?(app_delegate_path)
  app_delegate = File.read(app_delegate_path)
  unless app_delegate.include?('SonarpadPocketTtsBridge.register')
    marker = 'GeneratedPluginRegistrant.register(with: self)'
    registration = <<~SWIFT.chomp
      if let controller = window?.rootViewController as? FlutterViewController {
        SonarpadPocketTtsBridge.register(with: controller.binaryMessenger)
      }
      #{marker}
    SWIFT
    if app_delegate.include?(marker)
      app_delegate = app_delegate.sub(marker, registration)
    else
      app_delegate = app_delegate.sub(
        'return super.application(application, didFinishLaunchingWithOptions: launchOptions)',
        "if let controller = window?.rootViewController as? FlutterViewController {\n    SonarpadPocketTtsBridge.register(with: controller.binaryMessenger)\n  }\n  return super.application(application, didFinishLaunchingWithOptions: launchOptions)"
      )
    end
    File.write(app_delegate_path, app_delegate)
  end
end

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' }
abort 'Target Runner non trovato' unless target

runner_group = project.main_group.find_subpath('Runner', true)

# Bridge Flutter sempre aggiunto alle sorgenti, anche quando il framework non è presente.
bridge_ref = runner_group.files.find { |f| f.path == 'SonarpadPocketTtsBridge.swift' } || runner_group.new_file('SonarpadPocketTtsBridge.swift')
unless target.source_build_phase.files_references.include?(bridge_ref)
  target.source_build_phase.add_file_reference(bridge_ref)
end

# Binding Swift UniFFI aggiunto solo quando scaricato dal workflow.
# Non aggiungiamo i wrapper opzionali PocketTTSSwift.swift: il bridge Sonarpad usa
# direttamente pocket_tts_ios.swift, che espone PocketTtsEngine/TtsConfig.
if native_ready
  swift_files = ['SonarpadPocketTtsBridge.swift', 'pocket_tts_ios.swift']
  swift_files.each do |swift_file|
    ref = runner_group.files.find { |f| f.path == swift_file } || runner_group.new_file(swift_file)
    unless target.source_build_phase.files_references.include?(ref)
      target.source_build_phase.add_file_reference(ref)
    end
  end

  frameworks_group = project.main_group.find_subpath('Frameworks', true)
  frameworks_group.path ||= 'Frameworks'
  framework_ref = frameworks_group.files.find { |f| f.path == 'PocketTTS.xcframework' } || frameworks_group.new_file('PocketTTS.xcframework')
  framework_ref.last_known_file_type = 'wrapper.xcframework'
  framework_ref.source_tree = '<group>'

  unless target.frameworks_build_phase.files_references.include?(framework_ref)
    target.frameworks_build_phase.add_file_reference(framework_ref)
  end

  deployment_target = ENV.fetch('IOS_DEPLOYMENT_TARGET', '17.0')
  project.build_configurations.each do |config|
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = deployment_target
  end
  project.targets.each do |t|
    t.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = deployment_target
      search_paths = config.build_settings['FRAMEWORK_SEARCH_PATHS'] || ['$(inherited)']
      search_paths = [search_paths] if search_paths.is_a?(String)
      config.build_settings['FRAMEWORK_SEARCH_PATHS'] = (search_paths + ['$(PROJECT_DIR)/Frameworks']).uniq
    end
  end
end

project.save
if native_ready
  puts 'Pocket TTS iOS collegato: PocketTTS.xcframework + binding UniFFI aggiunti al target Runner.'
else
  puts 'Pocket TTS iOS bridge stub preparato: framework non presente, build sicura.'
end
