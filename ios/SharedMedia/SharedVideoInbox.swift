import Foundation

/// Shared by the app and its extension. Publishing the directory is atomic, so
/// the app never sees a partially copied (potentially very large) movie.
enum SharedVideoInbox {
  static let groupIdentifier = "group.com.ambro86.sonarpad"

  static func root() throws -> URL {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: groupIdentifier
    ) else {
      throw NSError(domain: "SonarpadShare", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Shared storage unavailable"])
    }
    let directory = container.appendingPathComponent("SharedVideos", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  static func store(_ source: URL, suggestedName: String?) throws {
    let fm = FileManager.default
    let directory = try root()
    let id = UUID().uuidString
    let staging = directory.appendingPathComponent(".\(id)", isDirectory: true)
    try fm.createDirectory(at: staging, withIntermediateDirectories: false)
    do {
      let base = URL(fileURLWithPath: suggestedName ?? "video").deletingPathExtension().lastPathComponent
      let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
      let target = staging.appendingPathComponent("\(base.isEmpty ? "video" : base).\(ext)")
      try fm.copyItem(at: source, to: target)
      try Data(target.lastPathComponent.utf8).write(to: staging.appendingPathComponent("pending"), options: .atomic)
      try fm.moveItem(at: staging, to: directory.appendingPathComponent(id, isDirectory: true))
    } catch {
      try? fm.removeItem(at: staging)
      throw error
    }
  }

  static func pendingPaths() throws -> [String] {
    let directories = try FileManager.default.contentsOfDirectory(
      at: root(), includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
    return directories.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { directory in
      guard let name = try? String(contentsOf: directory.appendingPathComponent("pending"), encoding: .utf8),
            !name.isEmpty, name == URL(fileURLWithPath: name).lastPathComponent else { return nil }
      let file = directory.appendingPathComponent(name)
      return FileManager.default.fileExists(atPath: file.path) ? file.path : nil
    }
  }

  static func acknowledge(_ path: String) throws {
    let file = URL(fileURLWithPath: path).standardizedFileURL
    let directory = file.deletingLastPathComponent()
    guard directory.deletingLastPathComponent() == (try root()).standardizedFileURL else { return }
    let marker = directory.appendingPathComponent("pending")
    if FileManager.default.fileExists(atPath: marker.path) {
      // Keep the movie: the player and saved AD projects may still reference it.
      try FileManager.default.removeItem(at: marker)
    }
  }
}
