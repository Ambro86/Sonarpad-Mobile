import Flutter
import UIKit
import SwiftyDropbox

/// Only authorization uses the SDK; Dart retains file import and token refresh.
final class SonarpadDropboxAuth: NSObject, FlutterPlugin {
  static let shared = SonarpadDropboxAuth()
  private static var configured = false
  private var pendingResult: FlutterResult?
  private var handlingRedirect = false

  static func setup() {
    guard !configured else { return }
    DropboxClientsManager.setupWithAppKey("q39vgbb6gks3474")
    configured = true
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    setup()
    let channel = FlutterMethodChannel(name: "sonarpad/dropbox_auth", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(shared, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "authenticate" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard pendingResult == nil else {
      result(FlutterError(code: "auth_in_progress", message: "Dropbox authorization already in progress", details: nil))
      return
    }
    guard let presenter = topPresenter() else {
      result(FlutterError(code: "auth_unavailable", message: "Unable to present Dropbox authorization", details: nil))
      return
    }
    pendingResult = result
    handlingRedirect = false
    DropboxClientsManager.authorizeFromControllerV2(
      UIApplication.shared,
      controller: presenter,
      loadingStatusDelegate: nil,
      openURL: { url in
        // SDK-generated cancellation URLs can be handled without reopening the app.
        if url.scheme == "db-q39vgbb6gks3474" {
          _ = self.handleRedirect(url)
        } else {
          UIApplication.shared.open(url, options: [:]) { opened in
            if !opened {
              self.finish(FlutterError(code: "auth_unavailable", message: "Unable to open Dropbox authorization", details: nil))
            }
          }
        }
      },
      scopeRequest: ScopeRequest(
        scopeType: .user,
        scopes: ["files.metadata.read", "files.content.read"],
        includeGrantedScopes: false
      )
    )
  }

  @discardableResult
  func handleRedirect(_ url: URL) -> Bool {
    guard url.scheme == "db-q39vgbb6gks3474" else { return false }
    // A scene and app callback must not exchange the same authorization code twice.
    guard pendingResult != nil, !handlingRedirect else { return true }
    handlingRedirect = true
    let handled = DropboxClientsManager.handleRedirectURL(url, includeBackgroundClient: false) { outcome in
      DispatchQueue.main.async {
        switch outcome {
        case .success(let token):
          var credential: [String: String] = ["access_token": token.accessToken]
          if let refresh = token.refreshToken { credential["refresh_token"] = refresh }
          self.finish(credential)
        case .cancel, .none:
          self.finish(nil)
        case .error:
          self.finish(FlutterError(code: "auth_failed", message: "Unable to complete Dropbox authorization", details: nil))
        }
        // Do not leave a second credential store after transferring to the existing service.
        DropboxClientsManager.unlinkClients()
      }
    }
    if !handled { handlingRedirect = false }
    return handled
  }

  private func finish(_ value: Any?) {
    let result = pendingResult
    pendingResult = nil
    handlingRedirect = false
    result?(value)
  }

  private func topPresenter() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    var controller = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
    while let presented = controller?.presentedViewController { controller = presented }
    return controller
  }
}
