import Flutter
import UIKit
import XCTest
@testable import Runner

private final class TestMessenger: NSObject, FlutterBinaryMessenger {
  var handlers: [String: FlutterBinaryMessageHandler] = [:]
  var calls: [FlutterMethodCall] = []
  private var connection: FlutterBinaryMessengerConnection = 0

  func send(onChannel channel: String, message: Data?) {
    if let message = message {
      calls.append(FlutterStandardMethodCodec.sharedInstance().decodeMethodCall(message))
    }
  }

  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {
    send(onChannel: channel, message: message)
    callback?(FlutterStandardMethodCodec.sharedInstance().encodeSuccessEnvelope(nil))
  }

  func setMessageHandlerOnChannel(
    _ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?
  ) -> FlutterBinaryMessengerConnection {
    handlers[channel] = handler
    connection += 1
    return connection
  }

  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}

class RunnerTests: XCTestCase {
  // Exercise the actual UIKit cells. Flutter semantics-node tests cannot
  // detect a UITableView reload replacing the object focused by VoiceOver.
  func testPreviewTransitionsPreserveNativeSliders() throws {
    let messenger = TestMessenger()
    func model(_ preview: String?, title: String = "Pause") -> [String: Any] {
      var rows: [[String: Any]] = [
        ["id": "source_volume", "title": "Movie volume", "kind": "slider",
         "sliderValue": 1.0, "sliderMin": 0.0, "sliderMax": 2.0, "sliderStep": 0.05],
      ]
      if let preview = preview {
        rows.append(["id": preview, "title": title,
                     "kind": preview == "mix_preview" ? "action" : "text"])
      }
      rows.append(["id": "trailing_slider", "title": "Other control", "kind": "slider",
                   "sliderValue": 1.0, "sliderMin": 0.0, "sliderMax": 2.0, "sliderStep": 0.1])
      return ["sections": [["rows": rows]],
              "transientRowIds": ["mix_preview", "mix_preview_status"]]
    }

    let native = SonarpadNativeListView(
      frame: CGRect(x: 0, y: 0, width: 390, height: 800),
      viewIdentifier: 42, arguments: model(nil), messenger: messenger
    )
    let host = UIViewController()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
    window.rootViewController = host
    host.view.addSubview(native.view())
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    host.view.layoutIfNeeded()
    let table = try XCTUnwrap(native.view().subviews.compactMap { $0 as? UITableView }.first)
    table.layoutIfNeeded()
    let volume = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 0, section: 0)))
    let volumeSlider = try XCTUnwrap(volume.accessoryView)
    let trailing = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 1, section: 0)))
    let trailingSlider = try XCTUnwrap(trailing.accessoryView)
    let receive = try XCTUnwrap(messenger.handlers["sonarpad/native_accessible_list/42"])

    let transitions: [(String?, String)] = [
      ("mix_preview_status", "Preparing"), ("mix_preview", "Pause"),
      ("mix_preview", "Resume"), ("mix_preview_status", "Preparing"),
      ("mix_preview", "Pause"), (nil, ""),
      ("mix_preview_status", "Error"), (nil, ""),
    ]
    for (preview, title) in transitions {
      let call = FlutterMethodCall(methodName: "setData", arguments: model(preview, title: title))
      receive(FlutterStandardMethodCodec.sharedInstance().encode(call)) { _ in }
      table.layoutIfNeeded()
      XCTAssertEqual(table.numberOfRows(inSection: 0), preview == nil ? 2 : 3)
      XCTAssertTrue(table.cellForRow(at: IndexPath(row: 0, section: 0)) === volume)
      XCTAssertTrue(volume.accessoryView === volumeSlider)
      XCTAssertTrue(table.cellForRow(at: IndexPath(row: preview == nil ? 1 : 2, section: 0)) === trailing)
      XCTAssertTrue(trailing.accessoryView === trailingSlider)
      // The retained control must resolve its current row, not its old index.
      messenger.calls.removeAll()
      trailing.accessibilityIncrement()
      let event = try XCTUnwrap(messenger.calls.last { $0.method == "event" })
      let arguments = try XCTUnwrap(event.arguments as? [String: Any])
      XCTAssertEqual(arguments["id"] as? String, "trailing_slider")
      XCTAssertEqual(arguments["value"] as? Double, 1.1)
    }
  }
}
