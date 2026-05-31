import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    for context in URLContexts {
      if context.url.isFileURL {
        SonarpadSharedMediaPlugin.shared.handleSharedUrl(context.url)
      }
    }
  }
}
