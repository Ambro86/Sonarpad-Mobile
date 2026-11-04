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

  // Regression: swiping an effect slider inserts the amount control and a
  // following slot. The original adjustable cell must not be replaced, nor
  // should the neighboring slider be altered or assigned the wrong id.
  func testMediaCutterEffectSlidersKeepIndependentCellsOnInsertion() throws {
    let messenger = TestMessenger()
    func model(first: Int, second: Int? = nil) -> [String: Any] {
      let names = ["None", "Echo", "Chorus"]
      let options: [[String: Any]] = names.enumerated().map { index, label in
        ["value": index, "label": label]
      }
      func effect(_ id: String, _ value: Int) -> [String: Any] {
        ["id": id, "kind": "slider", "title": id,
         "sliderValue": Double(value), "sliderMin": 0.0,
         "sliderMax": 2.0, "sliderStep": 1.0,
         "value": names[value], "valueLabel": names[value], "options": options]
      }
      var rows: [[String: Any]] = [
        ["id": "volume", "kind": "slider", "title": "Volume",
         "sliderValue": 80.0, "sliderMin": 0.0, "sliderMax": 200.0,
         "sliderStep": 10.0, "valueLabel": "80%"],
        effect("effect_0", first),
      ]
      if first > 0 {
        rows.append(["id": "amount_0", "kind": "slider", "title": "Amount 1",
                     "sliderValue": 50.0, "sliderMin": 0.0,
                     "sliderMax": 100.0, "sliderStep": 10.0, "valueLabel": "50%"])
        rows.append(effect("effect_1", second ?? 0))
        if let second = second, second > 0 {
          rows.append(["id": "amount_1", "kind": "slider", "title": "Amount 2",
                       "sliderValue": 70.0, "sliderMin": 0.0,
                       "sliderMax": 100.0, "sliderStep": 10.0, "valueLabel": "70%"])
          rows.append(effect("effect_2", 0))
        }
      }
      rows.append(["id": "preview", "kind": "button", "title": "Preview"])
      return ["sections": [["rows": rows]], "transientRowIds":
                ["effect_0", "effect_1", "effect_2", "effect_3",
                 "amount_0", "amount_1", "amount_2", "amount_3"]]
    }
    let native = SonarpadNativeListView(
      frame: CGRect(x: 0, y: 0, width: 390, height: 800),
      viewIdentifier: 43, arguments: model(first: 0), messenger: messenger
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
    let first = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 1, section: 0)))
    let firstAccessory = try XCTUnwrap(first.accessoryView)
    let volumeAccessory = try XCTUnwrap(volume.accessoryView)
    let receive = try XCTUnwrap(messenger.handlers["sonarpad/native_accessible_list/43"])
    func apply(_ data: [String: Any]) {
      let call = FlutterMethodCall(methodName: "setData", arguments: data)
      receive(FlutterStandardMethodCodec.sharedInstance().encode(call)) { _ in }
      table.layoutIfNeeded()
    }
    messenger.calls.removeAll()
    first.accessibilityIncrement()
    var event = try XCTUnwrap(messenger.calls.last { $0.method == "event" })
    var args = try XCTUnwrap(event.arguments as? [String: Any])
    XCTAssertEqual(args["id"] as? String, "effect_0")
    XCTAssertEqual(args["value"] as? Double, 1.0)

    apply(model(first: 1))
    XCTAssertEqual(table.numberOfRows(inSection: 0), 5)
    XCTAssertTrue(table.cellForRow(at: IndexPath(row: 0, section: 0)) === volume)
    XCTAssertTrue(volume.accessoryView === volumeAccessory)
    XCTAssertTrue(table.cellForRow(at: IndexPath(row: 1, section: 0)) === first)
    XCTAssertTrue(first.accessoryView === firstAccessory)
    XCTAssertEqual(first.accessibilityValue, "Echo")
    let amount = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 2, section: 0)))
    let second = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 3, section: 0)))
    let secondAccessory = try XCTUnwrap(second.accessoryView)
    messenger.calls.removeAll()
    second.accessibilityIncrement()
    event = try XCTUnwrap(messenger.calls.last { $0.method == "event" })
    args = try XCTUnwrap(event.arguments as? [String: Any])
    XCTAssertEqual(args["id"] as? String, "effect_1")
    XCTAssertEqual(args["value"] as? Double, 1.0)
    XCTAssertEqual(first.accessibilityValue, "Echo")

    apply(model(first: 1, second: 2))
    XCTAssertEqual(table.numberOfRows(inSection: 0), 7)
    XCTAssertTrue(table.cellForRow(at: IndexPath(row: 0, section: 0)) === volume)
    XCTAssertTrue(table.cellForRow(at: IndexPath(row: 1, section: 0)) === first)
    XCTAssertTrue(table.cellForRow(at: IndexPath(row: 2, section: 0)) === amount)
    XCTAssertTrue(table.cellForRow(at: IndexPath(row: 3, section: 0)) === second)
    XCTAssertTrue(second.accessoryView === secondAccessory)
    XCTAssertEqual(first.accessibilityValue, "Echo")
    XCTAssertEqual(second.accessibilityValue, "Chorus")
    XCTAssertEqual(volume.accessibilityValue, "80%")
  }
}
