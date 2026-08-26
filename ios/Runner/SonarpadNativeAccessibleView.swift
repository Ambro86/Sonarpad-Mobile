import Flutter
import UIKit
import ObjectiveC

private struct SonarpadNativeOption {
  let value: Any
  let label: String
}

private struct SonarpadNativeAction {
  let id: String
  let label: String
}

private struct SonarpadNativeVisualAction {
  let id: String
  let label: String
  let icon: String
}

private struct SonarpadNativeRow {
  let id: String
  var title: String
  var subtitle: String?
  var value: String?
  var valueLabel: String?
  var accessibilityLabel: String?
  var hint: String?
  var kind: String
  var enabled: Bool
  var selected: Bool
  var accessibilityButtonTrait: Bool
  var toggleValue: Bool
  var sliderValue: Double
  var sliderMin: Double
  var sliderMax: Double
  var sliderStep: Double
  var sliderIncreasedValueLabel: String?
  var sliderDecreasedValueLabel: String?
  var nativeSliderAccessibilityElement: Bool
  var secure: Bool
  var placeholder: String?
  var submitOnReturn: Bool
  var textInputAction: String?
  var stabilizeTextFieldFocusOnBegin: Bool
  var options: [SonarpadNativeOption]
  var actions: [SonarpadNativeAction]
  var visualActions: [SonarpadNativeVisualAction]
  var visualActionId: String?
  var visualActionIcon: String?

  var effectiveAccessibilityLabel: String {
    if let accessibilityLabel = accessibilityLabel {
      return accessibilityLabel
    }
    guard let subtitle = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines),
          !subtitle.isEmpty,
          subtitle.caseInsensitiveCompare(title.trimmingCharacters(in: .whitespacesAndNewlines)) != .orderedSame else {
      return title
    }
    return "\(title), \(subtitle)"
  }

  init(_ map: [String: Any]) {
    id = map["id"] as? String ?? UUID().uuidString
    title = map["title"] as? String ?? ""
    subtitle = map["subtitle"] as? String
    value = map["value"] as? String
    valueLabel = map["valueLabel"] as? String
    accessibilityLabel = map["accessibilityLabel"] as? String
    hint = map["hint"] as? String
    kind = map["kind"] as? String ?? "action"
    enabled = map["enabled"] as? Bool ?? true
    selected = map["selected"] as? Bool ?? false
    accessibilityButtonTrait = map["accessibilityButtonTrait"] as? Bool ?? true
    toggleValue = map["toggleValue"] as? Bool ?? false
    sliderValue = (map["sliderValue"] as? NSNumber)?.doubleValue ?? 0
    sliderMin = (map["sliderMin"] as? NSNumber)?.doubleValue ?? 0
    sliderMax = (map["sliderMax"] as? NSNumber)?.doubleValue ?? 1
    sliderStep = max((map["sliderStep"] as? NSNumber)?.doubleValue ?? 0.1, 0.000001)
    sliderIncreasedValueLabel = map["sliderIncreasedValueLabel"] as? String
    sliderDecreasedValueLabel = map["sliderDecreasedValueLabel"] as? String
    nativeSliderAccessibilityElement = map["nativeSliderAccessibilityElement"] as? Bool ?? false
    secure = map["secure"] as? Bool ?? false
    placeholder = map["placeholder"] as? String
    submitOnReturn = map["submitOnReturn"] as? Bool ?? false
    textInputAction = map["textInputAction"] as? String
    stabilizeTextFieldFocusOnBegin =
      map["stabilizeNativeTextFieldFocusOnBegin"] as? Bool ?? false
    options = (map["options"] as? [[String: Any]] ?? []).map {
      SonarpadNativeOption(value: $0["value"] as Any, label: $0["label"] as? String ?? String(describing: $0["value"] ?? ""))
    }
    actions = (map["actions"] as? [[String: Any]] ?? []).compactMap {
      guard let id = $0["id"] as? String, let label = $0["label"] as? String else { return nil }
      return SonarpadNativeAction(id: id, label: label)
    }
    visualActions = (map["visualActions"] as? [[String: Any]] ?? []).compactMap {
      guard let id = $0["id"] as? String,
            let label = $0["label"] as? String,
            let icon = $0["icon"] as? String else { return nil }
      return SonarpadNativeVisualAction(id: id, label: label, icon: icon)
    }
    visualActionId = map["visualActionId"] as? String
    visualActionIcon = map["visualActionIcon"] as? String
  }
}

private struct SonarpadNativeSection {
  let header: String?
  let footer: String?
  var rows: [SonarpadNativeRow]

  init(_ map: [String: Any]) {
    header = map["header"] as? String
    footer = map["footer"] as? String
    rows = (map["rows"] as? [[String: Any]] ?? []).map(SonarpadNativeRow.init)
  }
}

private func sonarpadValuesEqual(_ lhs: Any, _ rhs: Any) -> Bool {
  if let left = lhs as? NSObject, let right = rhs as? NSObject {
    return left.isEqual(right)
  }
  return String(describing: lhs) == String(describing: rhs)
}

private func sonarpadRowsEqual(_ lhs: SonarpadNativeRow, _ rhs: SonarpadNativeRow) -> Bool {
  guard lhs.id == rhs.id,
        lhs.title == rhs.title,
        lhs.subtitle == rhs.subtitle,
        lhs.value == rhs.value,
        lhs.valueLabel == rhs.valueLabel,
        lhs.accessibilityLabel == rhs.accessibilityLabel,
        lhs.hint == rhs.hint,
        lhs.kind == rhs.kind,
        lhs.enabled == rhs.enabled,
        lhs.selected == rhs.selected,
        lhs.accessibilityButtonTrait == rhs.accessibilityButtonTrait,
        lhs.toggleValue == rhs.toggleValue,
        lhs.sliderValue == rhs.sliderValue,
        lhs.sliderMin == rhs.sliderMin,
        lhs.sliderMax == rhs.sliderMax,
        lhs.sliderStep == rhs.sliderStep,
        lhs.sliderIncreasedValueLabel == rhs.sliderIncreasedValueLabel,
        lhs.sliderDecreasedValueLabel == rhs.sliderDecreasedValueLabel,
        lhs.nativeSliderAccessibilityElement == rhs.nativeSliderAccessibilityElement,
        lhs.secure == rhs.secure,
        lhs.placeholder == rhs.placeholder,
        lhs.submitOnReturn == rhs.submitOnReturn,
        lhs.textInputAction == rhs.textInputAction,
        lhs.stabilizeTextFieldFocusOnBegin == rhs.stabilizeTextFieldFocusOnBegin,
        lhs.options.count == rhs.options.count,
        lhs.actions.count == rhs.actions.count,
        lhs.visualActions.count == rhs.visualActions.count,
        lhs.visualActionId == rhs.visualActionId,
        lhs.visualActionIcon == rhs.visualActionIcon else { return false }

  for (left, right) in zip(lhs.options, rhs.options) {
    if left.label != right.label || !sonarpadValuesEqual(left.value, right.value) { return false }
  }
  for (left, right) in zip(lhs.actions, rhs.actions) {
    if left.id != right.id || left.label != right.label { return false }
  }
  for (left, right) in zip(lhs.visualActions, rhs.visualActions) {
    if left.id != right.id || left.label != right.label || left.icon != right.icon { return false }
  }
  return true
}

private func sonarpadRowsHaveSameStructure(_ lhs: SonarpadNativeRow, _ rhs: SonarpadNativeRow) -> Bool {
  // UITableView only needs a full reload when the identity or the native cell
  // class changes. Text, bookmark decoration, traits, values and custom
  // actions are dynamic row state and can be reapplied to the existing cell.
  // Keeping those changes in-place is essential for VoiceOver: reloadData()
  // destroys the focused accessibility element and resets the document offset.
  guard lhs.id == rhs.id, lhs.kind == rhs.kind else { return false }
  return true
}

private func sonarpadSectionsHaveSameStructure(_ lhs: [SonarpadNativeSection], _ rhs: [SonarpadNativeSection]) -> Bool {
  guard lhs.count == rhs.count else { return false }
  for (leftSection, rightSection) in zip(lhs, rhs) {
    guard leftSection.header == rightSection.header,
          leftSection.footer == rightSection.footer,
          leftSection.rows.count == rightSection.rows.count else { return false }
    for (leftRow, rightRow) in zip(leftSection.rows, rightSection.rows) {
      if !sonarpadRowsHaveSameStructure(leftRow, rightRow) { return false }
    }
  }
  return true
}

private func sonarpadSectionsEqual(_ lhs: [SonarpadNativeSection], _ rhs: [SonarpadNativeSection]) -> Bool {
  guard lhs.count == rhs.count else { return false }
  for (leftSection, rightSection) in zip(lhs, rhs) {
    guard leftSection.header == rightSection.header,
          leftSection.footer == rightSection.footer,
          leftSection.rows.count == rightSection.rows.count else { return false }
    for (leftRow, rightRow) in zip(leftSection.rows, rightSection.rows) {
      if !sonarpadRowsEqual(leftRow, rightRow) { return false }
    }
  }
  return true
}

private final class SonarpadAccessibleSlider: UISlider {
  var rowId = ""
  var incrementHandler: (() -> Void)?
  var decrementHandler: (() -> Void)?
  var accessibilityFocusHandler: ((String) -> Void)?

  override func accessibilityIncrement() {
    if let incrementHandler = incrementHandler { incrementHandler() } else { super.accessibilityIncrement() }
  }

  override func accessibilityDecrement() {
    if let decrementHandler = decrementHandler { decrementHandler() } else { super.accessibilityDecrement() }
  }

  override func accessibilityElementDidBecomeFocused() {
    super.accessibilityElementDidBecomeFocused()
    if !rowId.isEmpty { accessibilityFocusHandler?(rowId) }
  }
}

private final class SonarpadAccessibleTableCell: UITableViewCell {
  var rowId = ""
  var activationHandler: (() -> Void)?
  var incrementHandler: (() -> Void)?
  var decrementHandler: (() -> Void)?
  var accessibilityFocusHandler: ((String) -> Void)?

  override func accessibilityActivate() -> Bool {
    guard let activationHandler = activationHandler else { return super.accessibilityActivate() }
    activationHandler()
    return true
  }

  override func accessibilityIncrement() {
    if let incrementHandler = incrementHandler { incrementHandler() } else { super.accessibilityIncrement() }
  }

  override func accessibilityDecrement() {
    if let decrementHandler = decrementHandler { decrementHandler() } else { super.accessibilityDecrement() }
  }

  override func accessibilityElementDidBecomeFocused() {
    super.accessibilityElementDidBecomeFocused()
    if !rowId.isEmpty { accessibilityFocusHandler?(rowId) }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    rowId = ""
    activationHandler = nil
    incrementHandler = nil
    decrementHandler = nil
    accessibilityFocusHandler = nil
    accessoryView = nil
    accessibilityCustomActions = nil
    accessibilityTraits = []
  }
}

private final class SonarpadTextFieldCell: UITableViewCell, UITextFieldDelegate {
  let field = UITextField(frame: .zero)
  var rowId = ""
  var submitOnReturn = false
  var stabilizeFocusOnBegin = false
  var onChanged: ((String, String) -> Void)?
  var onSubmitted: ((String, String) -> Void)?
  var onFocusStabilized: ((String, String) -> Void)?

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    field.translatesAutoresizingMaskIntoConstraints = false
    field.borderStyle = .roundedRect
    field.clearButtonMode = .whileEditing
    field.returnKeyType = .done
    field.delegate = self
    contentView.addSubview(field)
    NSLayoutConstraint.activate([
      field.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
      field.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
      field.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
      field.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
      field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
    ])
    field.addTarget(self, action: #selector(valueChanged), for: .editingChanged)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardDidShow),
      name: UIResponder.keyboardDidShowNotification,
      object: nil
    )
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  private func focusDiagnosticSummary(_ phase: String) -> String {
    let focused = UIAccessibility.focusedElement(using: .notificationVoiceOver)
    let focusedObject = focused as? NSObject
    let focusedType = focused.map { String(describing: type(of: $0)) } ?? "nil"
    let rawLabel = focusedObject?.accessibilityLabel ?? "nil"
    let focusedLabel = rawLabel
      .replacingOccurrences(of: "\r", with: "\\r")
      .replacingOccurrences(of: "\n", with: "\\n")
    let fieldFrameWindow = field.window != nil
      ? field.convert(field.bounds, to: nil)
      : .zero
    return
      "phase=\(phase) firstResponder=\(field.isFirstResponder) fieldWindow=\(field.window != nil) " +
      "cellWindow=\(window != nil) fieldBounds=\(NSCoder.string(for: field.bounds)) " +
      "fieldFrameWindow=\(NSCoder.string(for: fieldFrameWindow)) " +
      "textLength=\((field.text ?? "").count) focusedType=\(focusedType) " +
      "focusedLabel=\(String(focusedLabel.prefix(120)))"
  }

  @objc private func valueChanged() {
    if stabilizeFocusOnBegin {
      onFocusStabilized?(rowId, focusDiagnosticSummary("editingChanged"))
    }
    onChanged?(rowId, field.text ?? "")
  }

  func textFieldDidBeginEditing(_ textField: UITextField) {
    guard stabilizeFocusOnBegin else { return }
    onFocusStabilized?(rowId, focusDiagnosticSummary("didBeginEditing.beforeAsync"))
    // Keep the initial double-tap attached to the real editable control while
    // iOS starts presenting the keyboard. The keyboardDidShow notification
    // below is the authoritative handoff point; this next-runloop post covers
    // the case where a hardware/existing keyboard produces no new show event.
    DispatchQueue.main.async { [weak self, weak textField] in
      guard let self = self, let textField = textField,
            self.stabilizeFocusOnBegin, textField.isFirstResponder else { return }
      self.onFocusStabilized?(self.rowId, self.focusDiagnosticSummary("didBeginEditing.beforeLayoutChanged"))
      UIAccessibility.post(notification: .layoutChanged, argument: textField)
      self.onFocusStabilized?(self.rowId, self.focusDiagnosticSummary("didBeginEditing.afterLayoutChanged"))
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
        guard let self = self, self.stabilizeFocusOnBegin else { return }
        self.onFocusStabilized?(self.rowId, self.focusDiagnosticSummary("didBeginEditing.after80ms"))
      }
    }
  }

  @objc private func keyboardDidShow() {
    guard stabilizeFocusOnBegin else { return }
    onFocusStabilized?(rowId, focusDiagnosticSummary("keyboardDidShow.beforeGuard"))
    guard field.isFirstResponder else { return }
    onFocusStabilized?(rowId, focusDiagnosticSummary("keyboardDidShow.beforeLayoutChanged"))
    UIAccessibility.post(notification: .layoutChanged, argument: field)
    onFocusStabilized?(rowId, focusDiagnosticSummary("keyboardDidShow.afterLayoutChanged"))
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
      guard let self = self, self.stabilizeFocusOnBegin else { return }
      self.onFocusStabilized?(self.rowId, self.focusDiagnosticSummary("keyboardDidShow.after80ms"))
    }
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    if stabilizeFocusOnBegin {
      onFocusStabilized?(rowId, focusDiagnosticSummary("shouldReturn"))
    }
    let value = textField.text ?? ""
    // Keep Dart's model synchronized with the exact final value before the
    // logical submit callback runs. This restores Flutter's onSubmitted
    // behavior for native UIKit text fields instead of merely dismissing the
    // keyboard.
    onChanged?(rowId, value)
    if submitOnReturn {
      onSubmitted?(rowId, value)
    }
    textField.resignFirstResponder()
    return true
  }
}

private final class SonarpadFocusProxyView: UIView {
  var onAccessibilityFocused: (() -> Void)?

  override func accessibilityElementDidBecomeFocused() {
    super.accessibilityElementDidBecomeFocused()
    onAccessibilityFocused?()
  }
}

private final class SonarpadFocusHandoffState {
  var completed = false
  var observer: NSObjectProtocol?
  var timeoutWorkItem: DispatchWorkItem?
}

private final class SonarpadNativeListView: NSObject, FlutterPlatformView, UITableViewDataSource, UITableViewDelegate {
  private let rootView: UIView
  private let tableView: UITableView
  private let channel: FlutterMethodChannel
  private var sections: [SonarpadNativeSection] = []
  private var refreshControl: UIRefreshControl?
  private var refreshEnabled = false
  private var lastInitialFocusId: String?
  private var debugTag: String?
  private var currentRendererGeneration = 0
  private var currentFocusRequestId = 0
  private var currentRequestedFocusRowId: String?
  private var focusTraceExpectedRowId: String?
  private var globalFocusTraceObserver: NSObjectProtocol?
  private var focusTraceSequence = 0

  private func emitDebug(_ message: String) {
    guard debugTag?.isEmpty == false else { return }
    let line = "DOC_NATIVE_SWIFT \(message)"
    print(line)
    channel.invokeMethod("event", arguments: ["type": "debug", "message": line])
  }

  private func focusTraceText(_ value: String?) -> String {
    let normalized = (value ?? "nil")
      .replacingOccurrences(of: "\r", with: "\\r")
      .replacingOccurrences(of: "\n", with: "\\n")
    return String(normalized.prefix(160))
  }

  private func focusTraceAccessibilityContainer(of element: Any?) -> Any? {
    if let accessibilityElement = element as? UIAccessibilityElement {
      return accessibilityElement.accessibilityContainer
    }
    // UIView does not expose UIAccessibilityElement.accessibilityContainer.
    // For trace purposes, its superview is the useful UIKit containment step.
    if let view = element as? UIView { return view.superview }
    return nil
  }

  private func focusTraceContainerChain(_ element: Any?) -> String {
    guard element != nil else { return "nil" }
    var parts: [String] = []
    var current = element
    var seen: Set<ObjectIdentifier> = []
    var depth = 0

    while let value = current, depth < 10 {
      let object = value as AnyObject
      let identifier = ObjectIdentifier(object)
      if seen.contains(identifier) {
        parts.append("<cycle>")
        break
      }
      seen.insert(identifier)
      parts.append(String(describing: type(of: value)))
      current = focusTraceAccessibilityContainer(of: value)
      depth += 1
    }

    return parts.joined(separator: ">")
  }

  private func focusTraceUIViewChain(_ element: Any?) -> String {
    guard let startView = element as? UIView else { return "nonUIView" }
    var parts: [String] = []
    var current: UIView? = startView
    var depth = 0
    while let view = current, depth < 10 {
      parts.append(String(describing: type(of: view)))
      current = view.superview
      depth += 1
    }
    return parts.joined(separator: ">")
  }

  private func installGlobalFocusTraceObserver() {
    guard globalFocusTraceObserver == nil else { return }
    globalFocusTraceObserver = NotificationCenter.default.addObserver(
      forName: UIAccessibility.elementFocusedNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self = self,
            let tag = self.debugTag,
            ["document", "letter_jump", "podcast_episodes", "raiplaysound", "settings", "media_cutter_effects"].contains(tag) else {
        return
      }

      self.focusTraceSequence += 1
      let element = notification.userInfo?[UIAccessibility.focusedElementUserInfoKey]
      let elementType = element.map { String(describing: type(of: $0)) } ?? "nil"
      let isUIView = element is UIView
      let isAccessibilityElement = element is UIAccessibilityElement
      let object = element as? NSObject
      let label = self.focusTraceText(object?.accessibilityLabel)
      let rawAccessibilityIdentifier: String?
      if let identifiable = element as? UIAccessibilityIdentification {
        rawAccessibilityIdentifier = identifiable.accessibilityIdentifier
      } else {
        rawAccessibilityIdentifier = nil
      }
      let accessibilityIdentifier = self.focusTraceText(rawAccessibilityIdentifier)
      let container = self.focusTraceAccessibilityContainer(of: element)
      let containerType = container.map { String(describing: type(of: $0)) } ?? "nil"
      let viewInRoot: Bool
      if let view = element as? UIView {
        viewInRoot = view === self.rootView || view.isDescendant(of: self.rootView)
      } else {
        viewInRoot = false
      }
      let nativeClassifier = self.accessibilityElementIsInNativeSubtree(element)

      var equalsExpectedTarget = false
      if let expectedId = self.focusTraceExpectedRowId,
         let expectedIndexPath = self.indexPath(forRowId: expectedId),
         let expectedTarget = self.accessibilityTarget(at: expectedIndexPath),
         let focusedObject = element as AnyObject? {
        equalsExpectedTarget = focusedObject === (expectedTarget as AnyObject)
      }

      let line =
        "FOCUS_TRACE seq=\(self.focusTraceSequence) tag=\(tag) " +
        "expected=\(self.focusTraceExpectedRowId ?? "nil") type=\(elementType) " +
        "isUIView=\(isUIView) isA11yElement=\(isAccessibilityElement) " +
        "label=\(label) identifier=\(accessibilityIdentifier) container=\(containerType) " +
        "viewInRoot=\(viewInRoot) nativeClassifier=\(nativeClassifier) " +
        "equalsExpectedTarget=\(equalsExpectedTarget) " +
        "containerChain=\(self.focusTraceContainerChain(element)) " +
        "viewChain=\(self.focusTraceUIViewChain(element))"
      print("DOC_NATIVE_SWIFT \(line)")
      self.emitDebug(line)
    }
  }

  init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, messenger: FlutterBinaryMessenger) {
    rootView = UIView(frame: frame)
    tableView = UITableView(frame: .zero, style: .insetGrouped)
    channel = FlutterMethodChannel(name: "sonarpad/native_accessible_list/\(viewId)", binaryMessenger: messenger)
    super.init()

    rootView.backgroundColor = .systemBackground
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.backgroundColor = .systemBackground
    tableView.estimatedRowHeight = 64
    tableView.rowHeight = UITableView.automaticDimension
    tableView.keyboardDismissMode = .interactive
    tableView.dataSource = self
    tableView.delegate = self
    rootView.addSubview(tableView)
    NSLayoutConstraint.activate([
      tableView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
      tableView.topAnchor.constraint(equalTo: rootView.topAnchor),
      tableView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
    ])

    apply(arguments: args)
    installGlobalFocusTraceObserver()

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      // Unconditional transport-level trace before any parsing/switch branch.
      // print() is deliberate here: it does not depend on a reverse channel
      // callback succeeding while this inbound MethodChannel call is active.
      print("DOC_NATIVE_SWIFT NATIVE_METHOD_RECEIVED method=\(call.method)")
      switch call.method {
      case "setData":
        self.apply(arguments: call.arguments)
        result(nil)
      case "refreshAccessibilityRow":
        if let map = call.arguments as? [String: Any], let id = map["id"] as? String {
          self.refreshAccessibilityRow(id: id)
        }
        result(nil)
      case "endRefresh":
        self.refreshControl?.endRefreshing()
        result(nil)
      case "scrollTo":
        if let map = call.arguments as? [String: Any], let id = map["id"] as? String {
          let animated = map["animated"] as? Bool ?? true
          self.emitDebug("method scrollTo id=\(id) animated=\(animated) window=\(self.rootView.window != nil)")
          self.scrollToRow(id: id, animated: animated)
        }
        result(nil)
      case "setRendererGeneration":
        if let map = call.arguments as? [String: Any],
           let generation = map["rendererGeneration"] as? Int {
          let oldGeneration = self.currentRendererGeneration
          self.currentRendererGeneration = generation
          self.currentFocusRequestId = 0
          self.emitDebug("FOCUS_GEN_BUMP reason=attach old=\(oldGeneration) new=\(generation)")
        }
        result(nil)
      case "prepareAccessibleFocus":
        guard let map = call.arguments as? [String: Any],
              let id = map["id"] as? String,
              let requestId = map["requestId"] as? Int,
              let rendererGeneration = map["rendererGeneration"] as? Int else {
          result(false)
          break
        }
        let animated = map["animated"] as? Bool ?? false
        guard rendererGeneration == self.currentRendererGeneration,
              requestId >= self.currentFocusRequestId else {
          self.emitDebug(
            "NATIVE_PREPARE_REJECT id=\(id) requestId=\(requestId) " +
            "currentRequestId=\(self.currentFocusRequestId) rendererGeneration=\(rendererGeneration) " +
            "currentRendererGeneration=\(self.currentRendererGeneration)"
          )
          result(false)
          break
        }
        self.currentFocusRequestId = requestId
        self.emitDebug(
          "NATIVE_PREPARE id=\(id) requestId=\(requestId) " +
          "rendererGeneration=\(rendererGeneration) window=\(self.rootView.window != nil)"
        )
        self.prepareAccessibleFocus(
          id: id,
          animated: animated,
          requestId: requestId,
          rendererGeneration: rendererGeneration,
          completion: { prepared in result(prepared) }
        )
      case "waitForForeignFocusClear":
        guard let map = call.arguments as? [String: Any],
              let id = map["id"] as? String,
              let requestId = map["requestId"] as? Int,
              let rendererGeneration = map["rendererGeneration"] as? Int else {
          result(["cleared": false, "reason": "invalidArguments"])
          break
        }
        let timeoutMs = map["timeoutMs"] as? Int ?? 2400
        self.waitForForeignNativeVoiceOverFocusToClear(
          id: id,
          requestId: requestId,
          rendererGeneration: rendererGeneration,
          timeoutMs: timeoutMs,
          completion: { outcome in result(outcome) }
        )
      case "focusAccessibleRow":
        // Backward-compatible alias for builds that still dispatch the newer
        // method name. Report the terminal outcome of the actual native attempt
        // rather than acknowledging receipt before the async post executes.
        guard let map = call.arguments as? [String: Any],
              let id = map["id"] as? String,
              let mode = map["mode"] as? String,
              let requestId = map["requestId"] as? Int,
              let rendererGeneration = map["rendererGeneration"] as? Int else {
          result(["posted": false, "reason": "invalidArguments"])
          break
        }
        let animated = map["animated"] as? Bool ?? false
        let useFocusProxy = map["useFocusProxy"] as? Bool ?? false
        let postFocusDiagnostics = map["postFocusDiagnostics"] as? Bool ?? false
        self.focusAccessibleRow(
          id: id,
          mode: mode,
          animated: animated,
          requestId: requestId,
          rendererGeneration: rendererGeneration,
          useFocusProxy: useFocusProxy,
          completion: { outcome in
            result(outcome)
            if useFocusProxy || postFocusDiagnostics {
              self.schedulePostFocusDiagnostics(
                id: id,
                requestId: requestId,
                rendererGeneration: rendererGeneration,
                phase: "focusAccessibleRow"
              )
            }
          }
        )
      case "focusInitial":
        if let map = call.arguments as? [String: Any], let id = map["id"] as? String {
          let animated = map["animated"] as? Bool ?? false
          if let requestId = map["requestId"] as? Int,
             let rendererGeneration = map["rendererGeneration"] as? Int {
            let mode = map["mode"] as? String ?? "screenEntry"
            let useFocusProxy = map["useFocusProxy"] as? Bool ?? false
            let postFocusDiagnostics = map["postFocusDiagnostics"] as? Bool ?? false
            self.emitDebug(
              "NATIVE_RECEIVED id=\(id) method=focusInitial mode=\(mode) requestId=\(requestId) " +
              "rendererGeneration=\(rendererGeneration) useFocusProxy=\(useFocusProxy) " +
              "postFocusDiagnostics=\(postFocusDiagnostics)"
            )
            self.focusAccessibleRow(
              id: id,
              mode: mode,
              animated: animated,
              requestId: requestId,
              rendererGeneration: rendererGeneration,
              useFocusProxy: useFocusProxy,
              completion: { outcome in
                result(outcome)
                if useFocusProxy || postFocusDiagnostics {
                  self.schedulePostFocusDiagnostics(
                    id: id,
                    requestId: requestId,
                    rendererGeneration: rendererGeneration,
                    phase: "focusInitial"
                  )
                }
              }
            )
          } else {
            self.emitDebug("method focusInitial compatibility id=\(id) window=\(self.rootView.window != nil)")
            self.focusRow(id: id, animated: false, maxAttempts: 0, screenChanged: true)
            result(true)
          }
        } else {
          result(false)
        }
      case "focusScreenEntry":
        if let map = call.arguments as? [String: Any], let id = map["id"] as? String {
          let animated = map["animated"] as? Bool ?? false
          self.emitDebug("method focusScreenEntry compatibility id=\(id) animated=\(animated)")
          self.focusRow(id: id, animated: animated, maxAttempts: 0, screenChanged: true)
          result(true)
        } else {
          result(false)
        }
      case "focusTo":
        if let map = call.arguments as? [String: Any], let id = map["id"] as? String {
          let animated = map["animated"] as? Bool ?? false
          if let requestId = map["requestId"] as? Int,
             let rendererGeneration = map["rendererGeneration"] as? Int {
            let mode = map["mode"] as? String ?? "inPlaceJump"
            let useFocusProxy = map["useFocusProxy"] as? Bool ?? false
            let postFocusDiagnostics = map["postFocusDiagnostics"] as? Bool ?? false
            self.emitDebug(
              "NATIVE_RECEIVED id=\(id) method=focusTo mode=\(mode) requestId=\(requestId) " +
              "rendererGeneration=\(rendererGeneration) useFocusProxy=\(useFocusProxy) " +
              "postFocusDiagnostics=\(postFocusDiagnostics)"
            )
            self.focusAccessibleRow(
              id: id,
              mode: mode,
              animated: animated,
              requestId: requestId,
              rendererGeneration: rendererGeneration,
              useFocusProxy: useFocusProxy,
              completion: { outcome in
                result(outcome)
                if useFocusProxy || postFocusDiagnostics {
                  self.schedulePostFocusDiagnostics(
                    id: id,
                    requestId: requestId,
                    rendererGeneration: rendererGeneration,
                    phase: "focusTo"
                  )
                }
              }
            )
          } else {
            self.emitDebug("method focusTo compatibility id=\(id) animated=\(animated)")
            self.focusRow(id: id, animated: animated, maxAttempts: 0, screenChanged: false)
            result(true)
          }
        } else {
          result(false)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  deinit {
    if let observer = globalFocusTraceObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  func view() -> UIView { rootView }

  private func apply(arguments: Any?) {
    guard let map = arguments as? [String: Any] else { return }
    debugTag = map["debugTag"] as? String
    let rawSections = map["sections"] as? [[String: Any]] ?? []
    let newSections = rawSections.map(SonarpadNativeSection.init)
    let focusedRowBeforeReload = voiceOverFocusedRowId()
    let sectionsChanged = !sonarpadSectionsEqual(sections, newSections)
    let sameStructureDynamicChange =
      sectionsChanged && sonarpadSectionsHaveSameStructure(sections, newSections)
    sections = newSections
    let rowCount = newSections.reduce(0) { $0 + $1.rows.count }
    let focusedBeforeLabel = focusedRowBeforeReload ?? "nil"
    let initialFocusLabel = (map["initialFocusId"] as? String) ?? "nil"
    emitDebug("apply rows=\(rowCount) sectionsChanged=\(sectionsChanged) sameStructureDynamicChange=\(sameStructureDynamicChange) focusedBefore=\(focusedBeforeLabel) initialFocus=\(initialFocusLabel) window=\(rootView.window != nil)")

    let wantsRefresh = map["refreshEnabled"] as? Bool ?? false
    if wantsRefresh != refreshEnabled {
      refreshEnabled = wantsRefresh
      if wantsRefresh {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(refreshRequested), for: .valueChanged)
        tableView.refreshControl = control
        refreshControl = control
      } else {
        tableView.refreshControl = nil
        refreshControl = nil
      }
    }

    if sameStructureDynamicChange {
      emitDebug("apply updateVisibleRowsFromModel visible=\(tableView.indexPathsForVisibleRows?.count ?? 0)")
      updateVisibleRowsFromModel()
    } else if sectionsChanged {
      emitDebug("apply reloadData begin contentOffsetY=\(tableView.contentOffset.y)")
      tableView.reloadData()
      tableView.layoutIfNeeded()
      emitDebug("apply reloadData end visible=\(tableView.indexPathsForVisibleRows?.count ?? 0) contentOffsetY=\(tableView.contentOffset.y)")
    }

    let requestedInitialFocusId = map["initialFocusId"] as? String
    if requestedInitialFocusId != lastInitialFocusId {
      lastInitialFocusId = requestedInitialFocusId
      if let id = requestedInitialFocusId, !id.isEmpty {
        // Same behaviour for every screen, including Document Reader:
        // position the row first, then UniversalAccessibleList performs the
        // same Flutter -> UIKit focus handoff already proven by Calendar.
        emitDebug("apply initialFocusId changed -> generic scroll id=\(id)")
        scrollToRow(id: id, animated: false)
      }
    }

    if sectionsChanged && !sameStructureDynamicChange,
       let id = focusedRowBeforeReload,
       indexPath(forRowId: id) != nil {
      restoreFocusRow(id: id)
    }
  }

  @objc private func refreshRequested() {
    channel.invokeMethod("event", arguments: ["type": "refresh"])
  }

  func numberOfSections(in tableView: UITableView) -> Int { sections.count }
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].rows.count }
  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].header }
  func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { sections[section].footer }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    let row = sections[indexPath.section].rows[indexPath.row]
    if row.kind == "textField" { return 64 }
    return UITableView.automaticDimension
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let row = sections[indexPath.section].rows[indexPath.row]
    if row.kind == "textField" {
      let identifier = "SonarpadTextFieldCell"
      let cell = (tableView.dequeueReusableCell(withIdentifier: identifier) as? SonarpadTextFieldCell)
        ?? SonarpadTextFieldCell(style: .default, reuseIdentifier: identifier)
      cell.rowId = row.id
      cell.field.text = row.value ?? ""
      cell.field.placeholder = row.placeholder
      cell.field.accessibilityLabel = row.effectiveAccessibilityLabel
      cell.field.accessibilityHint = row.hint
      cell.field.isSecureTextEntry = row.secure
      cell.field.isEnabled = row.enabled
      cell.submitOnReturn = row.submitOnReturn
      cell.stabilizeFocusOnBegin = row.stabilizeTextFieldFocusOnBegin
      switch row.textInputAction {
      case "search": cell.field.returnKeyType = .search
      case "next": cell.field.returnKeyType = .next
      default: cell.field.returnKeyType = .done
      }
      cell.onChanged = { [weak self] id, value in
        self?.channel.invokeMethod("event", arguments: ["type": "textChanged", "id": id, "value": value])
      }
      cell.onSubmitted = { [weak self] id, value in
        self?.channel.invokeMethod("event", arguments: ["type": "textSubmitted", "id": id, "value": value])
      }
      cell.onFocusStabilized = { [weak self] id, diagnostic in
        self?.emitDebug("TEXTFIELD_DIAGNOSTIC id=\(id) \(diagnostic)")
      }
      return cell
    }

    let identifier = "SonarpadAccessibleTableCell"
    let cell = (tableView.dequeueReusableCell(withIdentifier: identifier) as? SonarpadAccessibleTableCell)
      ?? SonarpadAccessibleTableCell(style: .subtitle, reuseIdentifier: identifier)
    configure(cell: cell, with: row, at: indexPath)
    return cell
  }

  private func configure(cell: SonarpadAccessibleTableCell, with row: SonarpadNativeRow, at indexPath: IndexPath) {
    cell.rowId = row.id
    cell.accessibilityFocusHandler = { [weak self] id in
      self?.handleAccessibilityFocus(id)
    }
    cell.isAccessibilityElement = true
    cell.textLabel?.isAccessibilityElement = false
    cell.detailTextLabel?.isAccessibilityElement = false
    cell.textLabel?.text = row.title
    cell.textLabel?.numberOfLines = 0
    cell.textLabel?.font = UIFont.preferredFont(forTextStyle: row.kind == "header" ? .headline : .body)
    cell.detailTextLabel?.text = row.subtitle ?? row.value
    cell.detailTextLabel?.numberOfLines = 0
    cell.detailTextLabel?.textColor = .secondaryLabel
    cell.selectionStyle = row.enabled && row.kind != "text" && row.accessibilityButtonTrait ? .default : .none
    cell.isUserInteractionEnabled = row.enabled
    // A visible sighted-only accessory may be reconfigured in place without
    // cell reuse, so clear any previous accessory before applying this row.
    cell.accessoryView = nil
    cell.accessoryType = row.accessibilityButtonTrait && (row.kind == "action" || row.kind == "picker" || row.kind == "button") ? .disclosureIndicator : .none
    cell.isAccessibilityElement = true
    cell.accessibilityLabel = row.effectiveAccessibilityLabel
    cell.accessibilityHint = row.hint
    cell.accessibilityValue = row.valueLabel ?? row.value
    var traits: UIAccessibilityTraits = []
    if row.accessibilityButtonTrait && (row.kind == "action" || row.kind == "picker" || row.kind == "button" || row.kind == "toggle") { traits.insert(.button) }
    if row.kind == "slider" { traits.insert(.adjustable) }
    if row.kind == "header" { traits.insert(.header) }
    if row.selected { traits.insert(.selected) }
    if !row.enabled { traits.insert(.notEnabled) }
    cell.accessibilityTraits = traits
    cell.incrementHandler = nil
    cell.decrementHandler = nil

    switch row.kind {
    case "toggle":
      let toggle = UISwitch()
      toggle.isOn = row.toggleValue
      toggle.isEnabled = row.enabled
      toggle.isAccessibilityElement = true
      toggle.accessibilityLabel = row.effectiveAccessibilityLabel
      toggle.accessibilityHint = row.hint
      objc_setAssociatedObject(toggle, &AssociatedKeys.rowId, row.id, .OBJC_ASSOCIATION_COPY_NONATOMIC)
      toggle.addTarget(self, action: #selector(toggleControlChanged(_:)), for: .valueChanged)
      cell.accessoryView = toggle
      cell.isAccessibilityElement = false
      cell.activationHandler = nil
    case "slider":
      let slider = SonarpadAccessibleSlider(frame: CGRect(x: 0, y: 0, width: 140, height: 32))
      slider.rowId = row.id
      slider.minimumValue = Float(row.sliderMin)
      slider.maximumValue = Float(row.sliderMax)
      slider.value = Float(row.sliderValue)
      slider.isEnabled = row.enabled
      slider.isUserInteractionEnabled = row.enabled
      let exposeNativeSlider = row.nativeSliderAccessibilityElement
      // Keep the established cell-based slider semantics by default. Media
      // Cutter effect controls opt into the real UISlider as the single
      // VoiceOver element so standard adjustable swipe up/down gestures stay
      // on the control and announce the updated percentage immediately.
      slider.isAccessibilityElement = exposeNativeSlider
      slider.accessibilityLabel = row.effectiveAccessibilityLabel
      slider.accessibilityHint = row.hint
      slider.accessibilityValue = row.valueLabel ?? row.value ?? formatSliderValue(row.sliderValue)
      slider.accessibilityTraits = row.enabled ? [.adjustable] : [.adjustable, .notEnabled]
      if exposeNativeSlider {
        slider.accessibilityFocusHandler = { [weak self] id in
          self?.handleAccessibilityFocus(id)
        }
      } else {
        slider.accessibilityFocusHandler = nil
      }
      slider.incrementHandler = row.enabled ? { [weak self] in
        self?.emitDebug(
          "SLIDER_GESTURE source=accessoryUISlider direction=increment id=\(row.id) " +
          "modelValue=\(row.sliderValue) step=\(row.sliderStep)"
        )
        self?.adjustSlider(at: indexPath, delta: row.sliderStep)
      } : nil
      slider.decrementHandler = row.enabled ? { [weak self] in
        self?.emitDebug(
          "SLIDER_GESTURE source=accessoryUISlider direction=decrement id=\(row.id) " +
          "modelValue=\(row.sliderValue) step=\(row.sliderStep)"
        )
        self?.adjustSlider(at: indexPath, delta: -row.sliderStep)
      } : nil
      slider.addTarget(self, action: #selector(sliderControlChanged(_:)), for: .valueChanged)
      cell.accessoryView = slider
      cell.isAccessibilityElement = !exposeNativeSlider
      cell.accessibilityLabel = row.effectiveAccessibilityLabel
      cell.accessibilityHint = row.hint
      cell.accessibilityValue = row.valueLabel ?? row.value ?? formatSliderValue(row.sliderValue)
      cell.selectionStyle = .none
      cell.activationHandler = nil
      cell.incrementHandler = row.enabled ? { [weak self] in
        self?.emitDebug(
          "SLIDER_GESTURE source=adjustableCell direction=increment id=\(row.id) " +
          "modelValue=\(row.sliderValue) step=\(row.sliderStep)"
        )
        self?.adjustSlider(at: indexPath, delta: row.sliderStep)
      } : nil
      cell.decrementHandler = row.enabled ? { [weak self] in
        self?.emitDebug(
          "SLIDER_GESTURE source=adjustableCell direction=decrement id=\(row.id) " +
          "modelValue=\(row.sliderValue) step=\(row.sliderStep)"
        )
        self?.adjustSlider(at: indexPath, delta: -row.sliderStep)
      } : nil
    case "picker":
      cell.activationHandler = { [weak self] in self?.presentPicker(for: indexPath) }
    case "action", "button":
      cell.activationHandler = { [weak self] in self?.sendActivation(at: indexPath) }
    default:
      cell.activationHandler = nil
    }

    if !row.visualActions.isEmpty && row.enabled {
      let stack = UIStackView()
      stack.axis = .horizontal
      stack.alignment = .center
      stack.distribution = .fillProportionally
      stack.spacing = 0
      stack.isAccessibilityElement = false
      stack.accessibilityElementsHidden = true

      for action in row.visualActions {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: visualActionSymbol(action.icon)), for: .normal)
        button.isAccessibilityElement = false
        button.accessibilityElementsHidden = true
        button.accessibilityLabel = nil
        button.accessibilityHint = nil
        button.accessibilityIdentifier = nil
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
        objc_setAssociatedObject(button, &AssociatedKeys.rowId, row.id, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        objc_setAssociatedObject(button, &AssociatedKeys.actionId, action.id, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        button.addTarget(self, action: #selector(handleVisualAction(_:)), for: .touchUpInside)
        stack.addArrangedSubview(button)
      }
      cell.accessoryView = stack
    } else if let visualActionId = row.visualActionId, !visualActionId.isEmpty, row.enabled {
      let button = UIButton(type: .system)
      button.setImage(UIImage(systemName: visualActionSymbol(row.visualActionIcon)), for: .normal)
      button.isAccessibilityElement = false
      button.accessibilityElementsHidden = true
      objc_setAssociatedObject(button, &AssociatedKeys.rowId, row.id, .OBJC_ASSOCIATION_COPY_NONATOMIC)
      objc_setAssociatedObject(button, &AssociatedKeys.actionId, visualActionId, .OBJC_ASSOCIATION_COPY_NONATOMIC)
      button.addTarget(self, action: #selector(handleVisualAction(_:)), for: .touchUpInside)
      cell.accessoryView = button
    }

    if !row.actions.isEmpty {
      cell.accessibilityCustomActions = row.actions.map { action in
        UIAccessibilityCustomAction(name: action.label, target: self, selector: #selector(handleCustomAction(_:)))
      }
      cell.accessibilityCustomActions?.forEach { action in
        objc_setAssociatedObject(action, &AssociatedKeys.rowId, row.id, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        if let matching = row.actions.first(where: { $0.label == action.name }) {
          objc_setAssociatedObject(action, &AssociatedKeys.actionId, matching.id, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
      }
    } else {
      cell.accessibilityCustomActions = nil
    }
  }

  private func visualActionSymbol(_ icon: String?) -> String {
    switch icon {
    case "save": return "square.and.arrow.down"
    case "download": return "arrow.down.circle"
    case "favorite": return "heart"
    case "favorite_filled": return "heart.fill"
    case "share": return "square.and.arrow.up"
    case "channel": return "person.crop.circle"
    case "comments": return "bubble.left"
    case "transcript": return "text.alignleft"
    case "podcast_add": return "dot.radiowaves.left.and.right"
    case "remove": return "trash"
    case "record": return "record.circle"
    default: return "ellipsis.circle"
    }
  }

  private struct AssociatedKeys {
    static var rowId: UInt8 = 0
    static var actionId: UInt8 = 0
  }

  @objc private func handleVisualAction(_ sender: UIButton) {
    guard let rowId = objc_getAssociatedObject(sender, &AssociatedKeys.rowId) as? String,
          let actionId = objc_getAssociatedObject(sender, &AssociatedKeys.actionId) as? String else { return }
    channel.invokeMethod("event", arguments: ["type": "customAction", "id": rowId, "action": actionId])
  }

  @objc private func handleCustomAction(_ action: UIAccessibilityCustomAction) -> Bool {
    guard let rowId = objc_getAssociatedObject(action, &AssociatedKeys.rowId) as? String,
          let actionId = objc_getAssociatedObject(action, &AssociatedKeys.actionId) as? String else { return false }
    channel.invokeMethod("event", arguments: ["type": "customAction", "id": rowId, "action": actionId])
    return true
  }

  private func refreshAccessibilityRow(id: String) {
    guard let indexPath = indexPath(forRowId: id),
          indexPath.section < sections.count,
          indexPath.row < sections[indexPath.section].rows.count,
          let cell = tableView.cellForRow(at: indexPath) as? SonarpadAccessibleTableCell else {
      emitDebug("A11Y_ROW_REFRESH id=\(id) visible=false")
      return
    }
    let wasFocused = cell.accessibilityElementIsFocused()
    let row = sections[indexPath.section].rows[indexPath.row]
    configure(cell: cell, with: row, at: indexPath)
    emitDebug("A11Y_ROW_REFRESH id=\(id) visible=true focused=\(wasFocused) actions=\(row.actions.map { $0.label }.joined(separator: ","))")
    if wasFocused && UIAccessibility.isVoiceOverRunning {
      UIAccessibility.post(notification: .layoutChanged, argument: cell)
    }
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let row = sections[indexPath.section].rows[indexPath.row]
    guard row.enabled else { return }
    switch row.kind {
    case "toggle": toggleRow(at: indexPath)
    case "picker": presentPicker(for: indexPath)
    case "action", "button": sendActivation(at: indexPath)
    default: break
    }
  }

  private func sendActivation(at indexPath: IndexPath) {
    let row = sections[indexPath.section].rows[indexPath.row]
    channel.invokeMethod("event", arguments: ["type": "activate", "id": row.id])
  }

  @objc private func toggleControlChanged(_ sender: UISwitch) {
    guard let rowId = objc_getAssociatedObject(sender, &AssociatedKeys.rowId) as? String,
          let indexPath = indexPath(forRowId: rowId),
          sections.indices.contains(indexPath.section),
          sections[indexPath.section].rows.indices.contains(indexPath.row) else { return }
    sections[indexPath.section].rows[indexPath.row].toggleValue = sender.isOn
    let row = sections[indexPath.section].rows[indexPath.row]
    channel.invokeMethod("event", arguments: ["type": "toggle", "id": row.id, "value": row.toggleValue])
  }

  @objc private func sliderControlChanged(_ sender: SonarpadAccessibleSlider) {
    guard let indexPath = indexPath(forRowId: sender.rowId),
          sections.indices.contains(indexPath.section),
          sections[indexPath.section].rows.indices.contains(indexPath.row) else { return }
    var row = sections[indexPath.section].rows[indexPath.row]
    emitDebug(
      "SLIDER_CONTROL_CHANGED_BEGIN source=valueChanged id=\(row.id) senderValue=\(sender.value) " +
      "modelValue=\(row.sliderValue) \(sliderFocusSnapshot(at: indexPath))"
    )
    let raw = min(max(Double(sender.value), row.sliderMin), row.sliderMax)
    let steps = ((raw - row.sliderMin) / row.sliderStep).rounded()
    row.sliderValue = min(max(row.sliderMin + steps * row.sliderStep, row.sliderMin), row.sliderMax)
    sender.value = Float(row.sliderValue)
    if let cell = tableView.cellForRow(at: indexPath) as? SonarpadAccessibleTableCell {
      cell.accessibilityValue = row.valueLabel ?? row.value ?? formatSliderValue(row.sliderValue)
    }
    sections[indexPath.section].rows[indexPath.row] = row
    emitDebug(
      "SLIDER_CONTROL_CHANGED_SYNC id=\(row.id) newValue=\(row.sliderValue) " +
      "cellValue=\((tableView.cellForRow(at: indexPath) as? SonarpadAccessibleTableCell)?.accessibilityValue ?? "nil") " +
      "\(sliderFocusSnapshot(at: indexPath))"
    )
    channel.invokeMethod(
      "event",
      arguments: ["type": "slider", "id": row.id, "value": row.sliderValue],
      result: { [weak self] result in
        self?.emitDebug(
          "SLIDER_DART_ACK source=valueChanged id=\(row.id) value=\(row.sliderValue) " +
          "result=\(String(describing: result))"
        )
      }
    )
  }

  private func toggleRow(at indexPath: IndexPath) {
    guard sections.indices.contains(indexPath.section), sections[indexPath.section].rows.indices.contains(indexPath.row) else { return }
    sections[indexPath.section].rows[indexPath.row].toggleValue.toggle()
    let row = sections[indexPath.section].rows[indexPath.row]
    channel.invokeMethod("event", arguments: ["type": "toggle", "id": row.id, "value": row.toggleValue])
    tableView.reloadRows(at: [indexPath], with: .none)
    UIAccessibility.post(notification: .layoutChanged, argument: tableView.cellForRow(at: indexPath))
  }

  private func recoverAdjustedSliderFocusIfNeeded(
    at indexPath: IndexPath,
    rowId: String,
    value: Double,
    phase: String
  ) {
    guard UIAccessibility.isVoiceOverRunning,
          sections.indices.contains(indexPath.section),
          sections[indexPath.section].rows.indices.contains(indexPath.row),
          sections[indexPath.section].rows[indexPath.row].id == rowId,
          let cell = tableView.cellForRow(at: indexPath) as? SonarpadAccessibleTableCell,
          cell.window != nil else { return }

    let focused = UIAccessibility.focusedElement(using: .notificationVoiceOver)
    let focusedObject = focused as AnyObject?
    if let focusedObject = focusedObject {
      if focusedObject === (cell as AnyObject) {
        emitDebug(
          "SLIDER_FOCUS_RECOVERY phase=\(phase) id=\(rowId) action=keep reason=cellStillFocused value=\(value)"
        )
        return
      }
      if let slider = cell.accessoryView as? SonarpadAccessibleSlider,
         focusedObject === (slider as AnyObject) {
        emitDebug(
          "SLIDER_FOCUS_RECOVERY phase=\(phase) id=\(rowId) action=keep reason=sliderStillFocused value=\(value)"
        )
        return
      }
      if accessibilityElementIsInNativeSubtree(focused) {
        emitDebug(
          "SLIDER_FOCUS_RECOVERY phase=\(phase) id=\(rowId) action=skip reason=otherNativeElement value=\(value) " +
          "focusedType=\(String(describing: type(of: focusedObject)))"
        )
        return
      }
    }

    let focusedType = focused.map { String(describing: type(of: $0)) } ?? "nil"
    let focusedLabel = (focused as? NSObject)?.accessibilityLabel ?? "nil"
    emitDebug(
      "SLIDER_FOCUS_RECOVERY phase=\(phase) id=\(rowId) action=restore value=\(value) " +
      "focusedType=\(focusedType) focusedLabel=\(focusedLabel) cellValue=\(cell.accessibilityValue ?? "nil")"
    )
    UIAccessibility.post(notification: .layoutChanged, argument: cell)
  }

  private func liveSliderSpokenValue(
    for row: SonarpadNativeRow,
    newValue: Double,
    fallback: String?
  ) -> String {
    let current = row.valueLabel ?? row.value ?? ""
    if current.hasSuffix("%") {
      if abs(newValue.rounded() - newValue) < 0.00001 {
        return "\(Int(newValue.rounded()))%"
      }
      return "\(String(format: "%.1f", newValue))%"
    }
    if current.hasSuffix("x") {
      return "\(String(format: "%.1f", newValue))x"
    }
    return fallback ?? formatSliderValue(newValue)
  }

  private func adjustSlider(at indexPath: IndexPath, delta: Double) {
    guard sections.indices.contains(indexPath.section), sections[indexPath.section].rows.indices.contains(indexPath.row) else { return }
    var row = sections[indexPath.section].rows[indexPath.row]
    let oldValue = row.sliderValue
    let announcedValue = delta >= 0 ? row.sliderIncreasedValueLabel : row.sliderDecreasedValueLabel
    emitDebug(
      "SLIDER_ADJUST_BEGIN id=\(row.id) direction=\(delta >= 0 ? "increment" : "decrement") " +
      "delta=\(delta) oldValue=\(oldValue) step=\(row.sliderStep) min=\(row.sliderMin) max=\(row.sliderMax) " +
      "candidateAnnouncement=\(announcedValue ?? "nil") \(sliderFocusSnapshot(at: indexPath))"
    )
    let raw = min(max(row.sliderValue + delta, row.sliderMin), row.sliderMax)
    let steps = ((raw - row.sliderMin) / row.sliderStep).rounded()
    row.sliderValue = min(max(row.sliderMin + steps * row.sliderStep, row.sliderMin), row.sliderMax)
    let spokenValue = liveSliderSpokenValue(
      for: row,
      newValue: row.sliderValue,
      fallback: announcedValue
    )
    row.value = spokenValue
    row.valueLabel = spokenValue
    sections[indexPath.section].rows[indexPath.row] = row

    // VoiceOver is focused on the table cell, which is the single
    // adjustable element. Update that same object synchronously and keep the
    // visual UISlider in sync without reloading the row.
    if let cell = tableView.cellForRow(at: indexPath) as? SonarpadAccessibleTableCell {
      cell.accessibilityValue = spokenValue
      if let slider = cell.accessoryView as? SonarpadAccessibleSlider {
        slider.value = Float(row.sliderValue)
        slider.accessibilityValue = spokenValue
      }
    }
    emitDebug(
      "SLIDER_ADJUST_SYNC id=\(row.id) oldValue=\(oldValue) newValue=\(row.sliderValue) " +
      "spokenValue=\(spokenValue) \(sliderFocusSnapshot(at: indexPath))"
    )
    channel.invokeMethod(
      "event",
      arguments: ["type": "slider", "id": row.id, "value": row.sliderValue],
      result: { [weak self] result in
        guard let self = self else { return }
        self.emitDebug(
          "SLIDER_DART_ACK source=accessibilityAdjust id=\(row.id) value=\(row.sliderValue) " +
          "result=\(String(describing: result)) \(self.sliderFocusSnapshot(at: indexPath))"
        )
      }
    )

    // A Flutter AlertDialog and an embedded UiKitView live in two distinct
    // accessibility subtrees. On iOS 27 VoiceOver can briefly leave the
    // adjustable native cell after the MethodChannel hop and land on a Flutter
    // semantics object. Check shortly after the hop and restore only when the
    // focus actually escaped the native subtree; never fight navigation inside
    // the UITableView itself.
    for (phase, delaySeconds) in [("bridge20ms", 0.02), ("bridge80ms", 0.08)] {
      DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) { [weak self] in
        self?.recoverAdjustedSliderFocusIfNeeded(
          at: indexPath,
          rowId: row.id,
          value: row.sliderValue,
          phase: phase
        )
      }
    }

    for (delayMs, delaySeconds) in [(0, 0.0), (50, 0.05), (250, 0.25), (750, 0.75)] {
      DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) { [weak self] in
        guard let self = self else { return }
        self.emitDebug(
          "SLIDER_FOCUS_AFTER id=\(row.id) delayMs=\(delayMs) modelValue=\(row.sliderValue) " +
          "\(self.sliderFocusSnapshot(at: indexPath))"
        )
      }
    }
  }

  private func sliderFocusSnapshot(at indexPath: IndexPath) -> String {
    let focused = UIAccessibility.focusedElement(using: .notificationVoiceOver)
    let focusedType = focused.map { String(describing: type(of: $0)) } ?? "nil"
    let focusedObject = focused as AnyObject?
    let cell = tableView.cellForRow(at: indexPath) as? SonarpadAccessibleTableCell
    let slider = cell?.accessoryView as? SonarpadAccessibleSlider
    let focusedIsCell: Bool
    if let focusedObject = focusedObject, let cellObject = cell as AnyObject? {
      focusedIsCell = focusedObject === cellObject
    } else {
      focusedIsCell = false
    }
    let focusedIsSlider: Bool
    if let focusedObject = focusedObject, let sliderObject = slider as AnyObject? {
      focusedIsSlider = focusedObject === sliderObject
    } else {
      focusedIsSlider = false
    }
    return
      "focusedType=\(focusedType) focusedRow=\(voiceOverFocusedRowId() ?? "nil") " +
      "focusedIsCell=\(focusedIsCell) focusedIsSlider=\(focusedIsSlider) " +
      "cellA11y=\(cell?.isAccessibilityElement ?? false) cellValue=\(cell?.accessibilityValue ?? "nil") " +
      "sliderA11y=\(slider?.isAccessibilityElement ?? false) sliderValue=\(slider?.value ?? -1) " +
      "cellWindow=\(cell?.window != nil) sliderWindow=\(slider?.window != nil)"
  }

  private func formatSliderValue(_ value: Double) -> String {
    if abs(value.rounded() - value) < 0.00001 { return String(Int(value.rounded())) }
    return String(format: "%.1f", value)
  }

  private func presentPicker(for indexPath: IndexPath) {
    let row = sections[indexPath.section].rows[indexPath.row]
    guard !row.options.isEmpty, let controller = rootView.sonarpadViewController else {
      sendActivation(at: indexPath)
      return
    }
    let picker = SonarpadNativePickerController(title: row.title, options: row.options, selectedValue: row.value) { [weak self] option in
      guard let self = self else { return }
      self.sections[indexPath.section].rows[indexPath.row].value = String(describing: option.value)
      self.sections[indexPath.section].rows[indexPath.row].valueLabel = option.label
      self.tableView.reloadRows(at: [indexPath], with: .none)
      self.channel.invokeMethod("event", arguments: ["type": "picker", "id": row.id, "value": option.value])
    }
    let nav = UINavigationController(rootViewController: picker)
    nav.modalPresentationStyle = .pageSheet
    controller.present(nav, animated: true)
  }


  private func updateVisibleSlidersFromModel() {
    guard let visible = tableView.indexPathsForVisibleRows else { return }
    for indexPath in visible {
      guard sections.indices.contains(indexPath.section),
            sections[indexPath.section].rows.indices.contains(indexPath.row) else { continue }
      let row = sections[indexPath.section].rows[indexPath.row]
      guard row.kind == "slider",
            let cell = tableView.cellForRow(at: indexPath),
            let slider = cell.accessoryView as? SonarpadAccessibleSlider else { continue }
      cell.textLabel?.text = row.title
      cell.detailTextLabel?.text = row.subtitle ?? row.value
      cell.accessibilityLabel = row.effectiveAccessibilityLabel
      cell.accessibilityHint = row.hint
      cell.accessibilityValue = row.valueLabel ?? row.value ?? formatSliderValue(row.sliderValue)
      slider.minimumValue = Float(row.sliderMin)
      slider.maximumValue = Float(row.sliderMax)
      slider.value = Float(row.sliderValue)
      slider.isEnabled = row.enabled
      slider.isUserInteractionEnabled = row.enabled
      slider.isAccessibilityElement = row.nativeSliderAccessibilityElement
      slider.accessibilityLabel = row.effectiveAccessibilityLabel
      slider.accessibilityHint = row.hint
      slider.accessibilityValue = row.valueLabel ?? row.value ?? formatSliderValue(row.sliderValue)
      slider.accessibilityTraits = row.enabled ? [.adjustable] : [.adjustable, .notEnabled]
      cell.isAccessibilityElement = !row.nativeSliderAccessibilityElement
    }
  }

  private func updateVisibleRowsFromModel() {
    guard let visible = tableView.indexPathsForVisibleRows else { return }

    for indexPath in visible {
      guard sections.indices.contains(indexPath.section),
            sections[indexPath.section].rows.indices.contains(indexPath.row) else { continue }

      let row = sections[indexPath.section].rows[indexPath.row]

      if row.kind == "textField" {
        guard let cell = tableView.cellForRow(at: indexPath) as? SonarpadTextFieldCell else { continue }
        cell.rowId = row.id
        if cell.field.text != (row.value ?? "") && !cell.field.isFirstResponder {
          cell.field.text = row.value ?? ""
        }
        cell.field.placeholder = row.placeholder
        cell.field.accessibilityLabel = row.effectiveAccessibilityLabel
        cell.field.accessibilityHint = row.hint
        cell.field.isSecureTextEntry = row.secure
        cell.field.isEnabled = row.enabled
        cell.submitOnReturn = row.submitOnReturn
        cell.stabilizeFocusOnBegin = row.stabilizeTextFieldFocusOnBegin
        switch row.textInputAction {
        case "search": cell.field.returnKeyType = .search
        case "next": cell.field.returnKeyType = .next
        default: cell.field.returnKeyType = .done
        }
        continue
      }

      guard let cell = tableView.cellForRow(at: indexPath) as? SonarpadAccessibleTableCell else { continue }

      if row.kind == "slider" {
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = row.subtitle ?? row.value
        cell.accessibilityLabel = row.effectiveAccessibilityLabel
        cell.accessibilityHint = row.hint
        cell.accessibilityValue = row.valueLabel ?? row.value ?? formatSliderValue(row.sliderValue)
        if let slider = cell.accessoryView as? SonarpadAccessibleSlider {
          slider.minimumValue = Float(row.sliderMin)
          slider.maximumValue = Float(row.sliderMax)
          slider.value = Float(row.sliderValue)
          slider.isEnabled = row.enabled
          slider.isUserInteractionEnabled = row.enabled
          slider.isAccessibilityElement = row.nativeSliderAccessibilityElement
          slider.accessibilityLabel = row.effectiveAccessibilityLabel
          slider.accessibilityHint = row.hint
          slider.accessibilityValue = row.valueLabel ?? row.value ?? formatSliderValue(row.sliderValue)
          slider.accessibilityTraits = row.enabled ? [.adjustable] : [.adjustable, .notEnabled]
          cell.isAccessibilityElement = !row.nativeSliderAccessibilityElement
        }
        continue
      }

      if row.kind == "toggle" {
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = row.subtitle ?? row.value
        if let toggle = cell.accessoryView as? UISwitch {
          toggle.isOn = row.toggleValue
          toggle.isEnabled = row.enabled
          toggle.accessibilityLabel = row.effectiveAccessibilityLabel
          toggle.accessibilityHint = row.hint
        }
        continue
      }

      // Reconfigure the existing cell object instead of reloading it. This
      // updates text, bookmark decoration and custom actions while preserving
      // the accessibility element VoiceOver is currently focused on.
      configure(cell: cell, with: row, at: indexPath)
    }
  }

  private func handleAccessibilityFocus(_ id: String) {
    let expected = currentRequestedFocusRowId
    let matchesTarget = expected == id
    let visibleIndexPaths = sortedVisibleIndexPaths()
    let visibleIds = visibleIndexPaths.compactMap { rowId(at: $0) }
    let targetIndexPath = expected.flatMap { indexPath(forRowId: $0) }
    let target = targetIndexPath.flatMap { accessibilityTarget(at: $0) }
    let targetView = target as? UIView
    let targetFrameRoot = targetView.map { $0.convert($0.bounds, to: rootView) } ?? .zero
    let payload: [String: Any] = [
      "type": "focus",
      "id": id,
      "expected": expected ?? "nil",
      "matchesTarget": matchesTarget,
      "offsetY": Double(tableView.contentOffset.y),
      "visibleFirst": visibleIds.first ?? "nil",
      "visibleLast": visibleIds.last ?? "nil",
      "visibleIds": visibleIds.prefix(24).joined(separator: ","),
      "targetVisible": targetIndexPath.map { visibleIndexPaths.contains($0) } ?? false,
      "targetExists": target != nil,
      "targetFrameRoot": NSCoder.string(for: targetFrameRoot),
      "rootWindow": rootView.window != nil,
      "tableWindow": tableView.window != nil
    ]
    if matchesTarget { currentRequestedFocusRowId = nil }
    channel.invokeMethod("event", arguments: payload)
  }

  private func accessibilityTarget(at indexPath: IndexPath) -> Any? {
    guard let cell = tableView.cellForRow(at: indexPath) else { return nil }
    return cell
  }

  private func voiceOverFocusedRowId() -> String? {
    guard let focused = UIAccessibility.focusedElement(using: .notificationVoiceOver) else { return nil }
    if let cell = focused as? SonarpadAccessibleTableCell, !cell.rowId.isEmpty {
      return cell.rowId
    }
    if let view = focused as? UIView {
      var current: UIView? = view
      while let candidate = current {
        if let cell = candidate as? SonarpadAccessibleTableCell, !cell.rowId.isEmpty {
          return cell.rowId
        }
        current = candidate.superview
      }
    }
    return nil
  }

  private func rowId(at indexPath: IndexPath) -> String? {
    guard sections.indices.contains(indexPath.section),
          sections[indexPath.section].rows.indices.contains(indexPath.row) else {
      return nil
    }
    return sections[indexPath.section].rows[indexPath.row].id
  }

  private func sortedVisibleIndexPaths() -> [IndexPath] {
    (tableView.indexPathsForVisibleRows ?? []).sorted { left, right in
      if left.section != right.section { return left.section < right.section }
      return left.row < right.row
    }
  }

  private func focusDiagnosticSnapshot(
    id: String,
    requestId: Int,
    rendererGeneration: Int,
    phase: String,
    delayMs: Int
  ) -> [String: Any] {
    tableView.layoutIfNeeded()
    let visibleIndexPaths = sortedVisibleIndexPaths()
    let visibleIds = visibleIndexPaths.compactMap { rowId(at: $0) }
    let firstVisibleId = visibleIds.first ?? "nil"
    let lastVisibleId = visibleIds.last ?? "nil"
    let visibleIdList = visibleIds.prefix(24).joined(separator: ",")

    let targetIndexPath = indexPath(forRowId: id)
    let targetVisible = targetIndexPath.map { visibleIndexPaths.contains($0) } ?? false
    let target = targetIndexPath.flatMap { accessibilityTarget(at: $0) }
    let targetView = target as? UIView
    let targetFrameRoot = targetView.map { $0.convert($0.bounds, to: rootView) } ?? .zero
    let targetFrameWindow = targetView.flatMap { view -> CGRect? in
      guard let window = rootView.window else { return nil }
      return view.convert(view.bounds, to: window)
    } ?? .zero

    let focused = UIAccessibility.focusedElement(using: .notificationVoiceOver)
    let focusedObject = focused as? NSObject
    let focusedType = focused.map { String(describing: type(of: $0)) } ?? "nil"
    let focusedLabel = focusTraceText(focusedObject?.accessibilityLabel)
    let focusedRow = voiceOverFocusedRowId() ?? "nil"
    let focusedEqualsTarget: Bool
    if let focusedObjectIdentity = focused as AnyObject?, let targetObject = target as AnyObject? {
      focusedEqualsTarget = focusedObjectIdentity === targetObject
    } else {
      focusedEqualsTarget = false
    }

    return [
      "type": "focusDiagnostic",
      "phase": phase,
      "id": id,
      "requestId": requestId,
      "rendererGeneration": rendererGeneration,
      "delayMs": delayMs,
      "tokensCurrent": focusTokensAreCurrent(
        requestId: requestId,
        rendererGeneration: rendererGeneration
      ),
      "voiceOverRunning": UIAccessibility.isVoiceOverRunning,
      "offsetY": Double(tableView.contentOffset.y),
      "contentSizeHeight": Double(tableView.contentSize.height),
      "boundsHeight": Double(tableView.bounds.height),
      "adjustedInsetTop": Double(tableView.adjustedContentInset.top),
      "adjustedInsetBottom": Double(tableView.adjustedContentInset.bottom),
      "visibleCount": visibleIndexPaths.count,
      "visibleFirst": firstVisibleId,
      "visibleLast": lastVisibleId,
      "visibleIds": visibleIdList,
      "targetIndexPath": targetIndexPath.map { "s\($0.section)r\($0.row)" } ?? "nil",
      "targetVisible": targetVisible,
      "targetExists": target != nil,
      "targetWindow": targetView?.window != nil,
      "targetInRoot": targetView?.isDescendant(of: rootView) ?? false,
      "targetFrameRoot": NSCoder.string(for: targetFrameRoot),
      "targetFrameWindow": NSCoder.string(for: targetFrameWindow),
      "focusedRow": focusedRow,
      "focusedType": focusedType,
      "focusedLabel": focusedLabel,
      "focusedEqualsTarget": focusedEqualsTarget,
      "rootWindow": rootView.window != nil,
      "tableWindow": tableView.window != nil
    ]
  }

  private func schedulePostFocusDiagnostics(
    id: String,
    requestId: Int,
    rendererGeneration: Int,
    phase: String
  ) {
    let delaysMs = [0, 50, 150, 350, 650, 1000, 1500, 2200, 3000]
    for delayMs in delaysMs {
      DispatchQueue.main.asyncAfter(deadline: .now() + (Double(delayMs) / 1000.0)) { [weak self] in
        guard let self = self else { return }
        let payload = self.focusDiagnosticSnapshot(
          id: id,
          requestId: requestId,
          rendererGeneration: rendererGeneration,
          phase: phase,
          delayMs: delayMs
        )
        self.channel.invokeMethod("event", arguments: payload)
      }
    }
  }

  private func restoreFocusRow(id: String, attempt: Int = 0) {
    guard let indexPath = indexPath(forRowId: id) else {
      emitDebug("restoreFocusRow id=\(id) attempt=\(attempt) indexPath NOT FOUND")
      return
    }
    emitDebug("restoreFocusRow id=\(id) attempt=\(attempt) indexPath=\(indexPath)")
    tableView.scrollToRow(at: indexPath, at: .none, animated: false)
    tableView.layoutIfNeeded()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
      guard let self = self else { return }
      if let target = self.accessibilityTarget(at: indexPath) {
        self.emitDebug("restoreFocusRow POST id=\(id) attempt=\(attempt) targetType=\(String(describing: type(of: target)))")
        UIAccessibility.post(notification: .layoutChanged, argument: target)
      } else if attempt < 12 {
        self.restoreFocusRow(id: id, attempt: attempt + 1)
      }
    }
  }

  private func foreignFocusedNativeRowSummary() -> (isForeign: Bool, rowId: String, type: String, label: String) {
    guard let focused = UIAccessibility.focusedElement(using: .notificationVoiceOver) else {
      return (false, "nil", "nil", "nil")
    }

    let object = focused as? NSObject
    let typeName = String(describing: type(of: focused))
    let label = focusTraceText(object?.accessibilityLabel)

    if let view = focused as? UIView {
      var current: UIView? = view
      while let candidate = current {
        if let cell = candidate as? SonarpadAccessibleTableCell, !cell.rowId.isEmpty {
          return (!cell.isDescendant(of: rootView), cell.rowId, typeName, label)
        }
        if let slider = candidate as? SonarpadAccessibleSlider, !slider.rowId.isEmpty {
          return (!slider.isDescendant(of: rootView), slider.rowId, typeName, label)
        }
        current = candidate.superview
      }
    }

    // The alphabet picker itself is deliberately Flutter/non-lazy now. During
    // its dismissal VoiceOver can keep the selected one-letter semantics node
    // ("H", "I", "L", ...) focused for ~0.8 s even though the parent UIKit
    // table is already visible. If we treat that as "clear" too early, iOS may
    // subsequently transfer focus to the parent's initial select_letter row and
    // reset its contentOffset to zero. This gate is only requested by the
    // letter-jump screen, so a one-grapheme FlutterSemanticsObject is the exact
    // stale picker focus we need to wait out; other Flutter controls remain
    // non-blocking.
    if typeName == "FlutterSemanticsObject", label != "nil", label.count == 1 {
      return (true, "flutterLetter:\(label)", typeName, label)
    }

    return (false, "nil", typeName, label)
  }

  private func waitForForeignNativeVoiceOverFocusToClear(
    id: String,
    requestId: Int,
    rendererGeneration: Int,
    timeoutMs: Int,
    attempt: Int = 0,
    clearSamples: Int = 0,
    completion: @escaping ([String: Any]) -> Void
  ) {
    guard focusTokensAreCurrent(
      requestId: requestId,
      rendererGeneration: rendererGeneration
    ) else {
      completion([
        "cleared": false,
        "reason": "staleRequest",
        "attempt": attempt
      ])
      return
    }

    let summary = foreignFocusedNativeRowSummary()
    let elapsedMs = attempt * 50
    emitDebug(
      "FOREIGN_FOCUS_GATE_CHECK id=\(id) attempt=\(attempt) elapsedMs=\(elapsedMs) " +
      "foreign=\(summary.isForeign) foreignRow=\(summary.rowId) focusedType=\(summary.type) " +
      "focusedLabel=\(summary.label) clearSamples=\(clearSamples) offsetY=\(tableView.contentOffset.y)"
    )

    if !summary.isForeign {
      // Once the one-letter picker semantics has disappeared and VoiceOver is
      // already on an ordinary Flutter element (typically the parent route's
      // Back button), the dismissed picker is no longer the focused owner.
      // Do not hold that harmless parent focus for an extra sample: on-device
      // logs show the extra 50 ms is enough for VoiceOver to start announcing
      // "Back" before the real row focus arrives.
      let stableParentFlutterFocus =
        summary.type == "FlutterSemanticsObject" && summary.label != "nil" && summary.label.count > 1
      if stableParentFlutterFocus || clearSamples >= 1 {
        completion([
          "cleared": true,
          "reason": stableParentFlutterFocus ? "parentFlutterFocusReady" : "foreignNativeFocusCleared",
          "waitedMs": elapsedMs,
          "focusedType": summary.type,
          "focusedLabel": summary.label,
          "offsetY": Double(tableView.contentOffset.y)
        ])
        return
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
        guard let self = self else {
          completion(["cleared": false, "reason": "selfReleased"])
          return
        }
        self.waitForForeignNativeVoiceOverFocusToClear(
          id: id,
          requestId: requestId,
          rendererGeneration: rendererGeneration,
          timeoutMs: timeoutMs,
          attempt: attempt + 1,
          clearSamples: clearSamples + 1,
          completion: completion
        )
      }
      return
    }

    if elapsedMs >= timeoutMs {
      emitDebug(
        "FOREIGN_FOCUS_GATE_TIMEOUT id=\(id) waitedMs=\(elapsedMs) " +
        "foreignRow=\(summary.rowId) focusedType=\(summary.type) focusedLabel=\(summary.label)"
      )
      completion([
        "cleared": false,
        "reason": "foreignNativeFocusTimeout",
        "waitedMs": elapsedMs,
        "foreignRow": summary.rowId,
        "focusedType": summary.type,
        "focusedLabel": summary.label,
        "offsetY": Double(tableView.contentOffset.y)
      ])
      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
      guard let self = self else {
        completion(["cleared": false, "reason": "selfReleased"])
        return
      }
      self.waitForForeignNativeVoiceOverFocusToClear(
        id: id,
        requestId: requestId,
        rendererGeneration: rendererGeneration,
        timeoutMs: timeoutMs,
        attempt: attempt + 1,
        clearSamples: 0,
        completion: completion
      )
    }
  }

  private func focusTokensAreCurrent(
    requestId: Int,
    rendererGeneration: Int
  ) -> Bool {
    requestId == currentFocusRequestId &&
      rendererGeneration == currentRendererGeneration &&
      rootView.window != nil
  }

  private func prepareAccessibleFocus(
    id: String,
    animated: Bool,
    requestId: Int,
    rendererGeneration: Int,
    attempt: Int = 0,
    completion: @escaping (Bool) -> Void
  ) {
    guard requestId == currentFocusRequestId,
          rendererGeneration == currentRendererGeneration else {
      emitDebug(
        "NATIVE_PREPARE_CANCEL id=\(id) attempt=\(attempt) requestId=\(requestId) " +
        "currentRequestId=\(currentFocusRequestId) rendererGeneration=\(rendererGeneration) " +
        "currentRendererGeneration=\(currentRendererGeneration)"
      )
      completion(false)
      return
    }
    guard let indexPath = indexPath(forRowId: id) else {
      emitDebug("NATIVE_PREPARE_FAIL id=\(id) reason=indexPathNotFound")
      completion(false)
      return
    }

    tableView.layoutIfNeeded()
    tableView.scrollToRow(at: indexPath, at: .middle, animated: animated)
    let delay: TimeInterval = animated ? 0.40 : 0.03
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      guard let self = self else {
        completion(false)
        return
      }
      guard requestId == self.currentFocusRequestId,
            rendererGeneration == self.currentRendererGeneration else {
        self.emitDebug("NATIVE_PREPARE_CANCEL id=\(id) attempt=\(attempt) reason=superseded")
        completion(false)
        return
      }

      self.tableView.layoutIfNeeded()
      let visible = self.tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false
      let cellExists = self.tableView.cellForRow(at: indexPath) != nil
      let windowReady = self.rootView.window != nil
      self.emitDebug(
        "NATIVE_PREPARED_CHECK id=\(id) attempt=\(attempt) visible=\(visible) " +
        "cellExists=\(cellExists) window=\(windowReady) offsetY=\(self.tableView.contentOffset.y)"
      )

      if visible && cellExists && windowReady {
        completion(true)
        return
      }
      if attempt < 12 {
        self.prepareAccessibleFocus(
          id: id,
          animated: false,
          requestId: requestId,
          rendererGeneration: rendererGeneration,
          attempt: attempt + 1,
          completion: completion
        )
      } else {
        completion(false)
      }
    }
  }

  private func accessibilityElementIsInNativeSubtree(_ element: Any?) -> Bool {
    guard let element = element else { return false }
    if let view = element as? UIView {
      return view === rootView || view.isDescendant(of: rootView)
    }
    if let accessibilityElement = element as? UIAccessibilityElement {
      var container: AnyObject? = accessibilityElement.accessibilityContainer
      var depth = 0
      while let current = container, depth < 16 {
        if let view = current as? UIView,
           view === rootView || view.isDescendant(of: rootView) {
          return true
        }
        if let parentElement = current as? UIAccessibilityElement {
          container = parentElement.accessibilityContainer
        } else {
          break
        }
        depth += 1
      }
    }
    return false
  }

  private func performInPlaceTwoStageHandoff(
    id: String,
    requestId: Int,
    rendererGeneration: Int,
    completion: @escaping ([String: Any]) -> Void
  ) {
    let state = SonarpadFocusHandoffState()

    func finish(_ outcome: [String: Any]) {
      guard !state.completed else { return }
      state.completed = true
      if let observer = state.observer {
        NotificationCenter.default.removeObserver(observer)
        state.observer = nil
      }
      state.timeoutWorkItem?.cancel()
      state.timeoutWorkItem = nil
      completion(outcome)
    }

    state.observer = NotificationCenter.default.addObserver(
      forName: UIAccessibility.elementFocusedNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self = self, !state.completed else { return }
      let focusedElement = notification.userInfo?[UIAccessibility.focusedElementUserInfoKey]
      let focusedType = focusedElement.map { String(describing: type(of: $0)) } ?? "nil"
      let inNativeSubtree = self.accessibilityElementIsInNativeSubtree(focusedElement)
      let focusLine =
        "NATIVE_FOCUS_NOTIFICATION id=\(id) focusedType=\(focusedType) " +
        "inNativeSubtree=\(inNativeSubtree) requestId=\(requestId)"
      print("DOC_NATIVE_SWIFT \(focusLine)")
      self.emitDebug(focusLine)
      guard inNativeSubtree else { return }

      guard self.focusTokensAreCurrent(
        requestId: requestId,
        rendererGeneration: rendererGeneration
      ) else {
        self.emitDebug("NATIVE_HANDOFF_STALE id=\(id) phase=entryAck")
        finish(["posted": false, "reason": "staleAfterEntryAck", "entryAck": true])
        return
      }

      self.emitDebug("NATIVE_SUBTREE_ENTERED id=\(id) requestId=\(requestId)")
      print("DOC_NATIVE_SWIFT NATIVE_SUBTREE_ENTERED id=\(id) requestId=\(requestId)")

      DispatchQueue.main.async { [weak self] in
        guard let self = self else {
          finish(["posted": false, "reason": "selfReleasedAfterEntryAck", "entryAck": true])
          return
        }
        guard self.focusTokensAreCurrent(
          requestId: requestId,
          rendererGeneration: rendererGeneration
        ) else {
          self.emitDebug("NATIVE_HANDOFF_STALE id=\(id) phase=specificPost")
          finish(["posted": false, "reason": "staleBeforeSpecificPost", "entryAck": true])
          return
        }
        guard let liveIndexPath = self.indexPath(forRowId: id),
              let target = self.accessibilityTarget(at: liveIndexPath) else {
          self.emitDebug("NATIVE_HANDOFF_TARGET_LOST id=\(id) phase=specificPost")
          finish(["posted": false, "reason": "targetLostBeforeSpecificPost", "entryAck": true])
          return
        }
        self.currentRequestedFocusRowId = id
        let specificLine =
          "ACCESSIBILITY_POST id=\(id) mode=inPlaceJump notification=screenChanged " +
          "phase=specific requestId=\(requestId) indexPath=\(liveIndexPath)"
        print("DOC_NATIVE_SWIFT \(specificLine)")
        self.emitDebug(specificLine)
        UIAccessibility.post(notification: .screenChanged, argument: target)
        finish([
          "posted": true,
          "reason": "specificPostedAfterEntryAck",
          "notification": "screenChanged",
          "entryAck": true
        ])
      }
    }

    let timeout = DispatchWorkItem { [weak self] in
      guard let self = self, !state.completed else { return }
      self.emitDebug("NATIVE_SUBTREE_ENTRY_TIMEOUT id=\(id) requestId=\(requestId)")
      print("DOC_NATIVE_SWIFT NATIVE_SUBTREE_ENTRY_TIMEOUT id=\(id) requestId=\(requestId)")
      finish([
        "posted": false,
        "reason": "subtreeEntryTimeout",
        "notification": "screenChanged",
        "entryAck": false
      ])
    }
    state.timeoutWorkItem = timeout

    let resetLine =
      "ACCESSIBILITY_POST id=\(id) mode=inPlaceJump notification=screenChanged " +
      "phase=entryReset argument=nil requestId=\(requestId) rendererGeneration=\(rendererGeneration)"
    print("DOC_NATIVE_SWIFT \(resetLine)")
    emitDebug(resetLine)
    UIAccessibility.post(notification: .screenChanged, argument: nil)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.40, execute: timeout)
  }

  private func postVerifiedDirectFocusAfterProxy(
    id: String,
    requestId: Int,
    rendererGeneration: Int,
    attempt: Int = 0,
    completion: @escaping ([String: Any]) -> Void
  ) {
    guard focusTokensAreCurrent(
      requestId: requestId,
      rendererGeneration: rendererGeneration
    ) else {
      completion([
        "posted": false,
        "reason": "proxyFallbackStale",
        "proxy": true
      ])
      return
    }

    guard let indexPath = indexPath(forRowId: id) else {
      completion([
        "posted": false,
        "reason": "proxyFallbackIndexPathMissing",
        "proxy": true
      ])
      return
    }

    tableView.layoutIfNeeded()
    var visible = tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false
    if !visible {
      let beforeOffset = tableView.contentOffset.y
      emitDebug(
        "PROXY_FALLBACK_SCROLL id=\(id) attempt=\(attempt) indexPath=\(indexPath) " +
        "beforeOffsetY=\(beforeOffset)"
      )
      tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
      tableView.layoutIfNeeded()
      visible = tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false
    }

    let cell = tableView.cellForRow(at: indexPath)
    let target = accessibilityTarget(at: indexPath)
    let targetView = target as? UIView
    let cellWindow = cell?.window != nil
    let targetWindow = targetView?.window != nil
    let rootWindow = rootView.window != nil
    let targetInRoot = targetView?.isDescendant(of: rootView) ?? false
    let ready = visible && cell != nil && target != nil && rootWindow && cellWindow && targetWindow && targetInRoot

    emitDebug(
      "PROXY_FALLBACK_VERIFY id=\(id) attempt=\(attempt) indexPath=\(indexPath) " +
      "visible=\(visible) cellExists=\(cell != nil) cellWindow=\(cellWindow) " +
      "targetWindow=\(targetWindow) rootWindow=\(rootWindow) targetInRoot=\(targetInRoot) " +
      "offsetY=\(tableView.contentOffset.y) ready=\(ready)"
    )

    guard ready, let liveTarget = target else {
      if attempt < 6 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
          guard let self = self else {
            completion([
              "posted": false,
              "reason": "proxyFallbackSelfReleased",
              "proxy": true
            ])
            return
          }
          self.postVerifiedDirectFocusAfterProxy(
            id: id,
            requestId: requestId,
            rendererGeneration: rendererGeneration,
            attempt: attempt + 1,
            completion: completion
          )
        }
      } else {
        completion([
          "posted": false,
          "reason": "proxyFallbackTargetNotReady",
          "notification": "screenChanged",
          "proxy": true,
          "visible": visible,
          "cellExists": cell != nil,
          "cellWindow": cellWindow,
          "targetWindow": targetWindow,
          "rootWindow": rootWindow,
          "targetInRoot": targetInRoot
        ])
      }
      return
    }

    currentRequestedFocusRowId = id
    let line =
      "ACCESSIBILITY_POST id=\(id) mode=screenEntry notification=screenChanged " +
      "phase=proxyVerifiedFallback requestId=\(requestId) indexPath=\(indexPath) " +
      "visible=\(visible) cellExists=\(cell != nil) cellWindow=\(cellWindow) " +
      "targetWindow=\(targetWindow) rootWindow=\(rootWindow) targetInRoot=\(targetInRoot) " +
      "offsetY=\(tableView.contentOffset.y)"
    emitDebug(line)
    print("DOC_NATIVE_SWIFT \(line)")
    let visibleIds = sortedVisibleIndexPaths().compactMap { rowId(at: $0) }
    let targetFrameRoot = targetView.map { $0.convert($0.bounds, to: rootView) } ?? .zero
    UIAccessibility.post(notification: .screenChanged, argument: liveTarget)
    completion([
      "posted": true,
      "reason": "proxyTimeoutVerifiedDirectFallback",
      "notification": "screenChanged",
      "proxy": true,
      "visible": visible,
      "cellExists": cell != nil,
      "cellWindow": cellWindow,
      "targetWindow": targetWindow,
      "rootWindow": rootWindow,
      "targetInRoot": targetInRoot,
      "offsetY": Double(tableView.contentOffset.y),
      "visibleFirst": visibleIds.first ?? "nil",
      "visibleLast": visibleIds.last ?? "nil",
      "targetFrameRoot": NSCoder.string(for: targetFrameRoot)
    ])
  }

  private func performVerifiedProxyFirstFocusHandoff(
    id: String,
    requestId: Int,
    rendererGeneration: Int,
    attempt: Int = 0,
    completion: @escaping ([String: Any]) -> Void
  ) {
    guard focusTokensAreCurrent(
      requestId: requestId,
      rendererGeneration: rendererGeneration
    ) else {
      completion(["posted": false, "reason": "proxyPrecheckStale", "proxy": true])
      return
    }

    guard let indexPath = indexPath(forRowId: id) else {
      completion(["posted": false, "reason": "proxyPrecheckIndexPathMissing", "proxy": true])
      return
    }

    tableView.layoutIfNeeded()
    var visible = tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false
    if !visible {
      tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
      tableView.layoutIfNeeded()
      visible = tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false
    }

    let cell = tableView.cellForRow(at: indexPath)
    let target = accessibilityTarget(at: indexPath)
    let targetView = target as? UIView
    let cellWindow = cell?.window != nil
    let targetWindow = targetView?.window != nil
    let rootWindow = rootView.window != nil
    let targetInRoot = targetView?.isDescendant(of: rootView) ?? false
    let frame = targetView.map { $0.convert($0.bounds, to: rootView) } ?? .zero
    let frameValid = !frame.isNull && !frame.isEmpty && frame.width > 0 && frame.height > 0
    let ready = visible && cell != nil && target != nil && cellWindow && targetWindow &&
      rootWindow && targetInRoot && frameValid

    emitDebug(
      "PROXY_PRECHECK_VERIFY id=\(id) attempt=\(attempt) indexPath=\(indexPath) " +
      "visible=\(visible) cellExists=\(cell != nil) cellWindow=\(cellWindow) " +
      "targetWindow=\(targetWindow) rootWindow=\(rootWindow) targetInRoot=\(targetInRoot) " +
      "frame=\(frame) frameValid=\(frameValid) offsetY=\(tableView.contentOffset.y) ready=\(ready)"
    )

    if ready, let liveTarget = target {
      performProxyFirstFocusHandoff(
        id: id,
        target: liveTarget,
        requestId: requestId,
        rendererGeneration: rendererGeneration,
        completion: completion
      )
      return
    }

    if attempt < 6 {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
        guard let self = self else {
          completion(["posted": false, "reason": "proxyPrecheckSelfReleased", "proxy": true])
          return
        }
        self.performVerifiedProxyFirstFocusHandoff(
          id: id,
          requestId: requestId,
          rendererGeneration: rendererGeneration,
          attempt: attempt + 1,
          completion: completion
        )
      }
      return
    }

    // If the proxy itself cannot be placed on a verified in-window target, do
    // not create it with a stale/off-screen frame. Fall back to the existing
    // verified direct path, which performs its own scroll/materialization gate.
    postVerifiedDirectFocusAfterProxy(
      id: id,
      requestId: requestId,
      rendererGeneration: rendererGeneration,
      completion: completion
    )
  }

  private func performProxyFirstFocusHandoff(
    id: String,
    target: Any,
    requestId: Int,
    rendererGeneration: Int,
    completion: @escaping ([String: Any]) -> Void
  ) {
    guard let targetView = target as? UIView else {
      emitDebug("PROXY_HANDOFF_SKIP id=\(id) reason=targetNotUIView")
      postVerifiedDirectFocusAfterProxy(
        id: id,
        requestId: requestId,
        rendererGeneration: rendererGeneration,
        completion: completion
      )
      return
    }

    let state = SonarpadFocusHandoffState()
    let proxy = SonarpadFocusProxyView(frame: targetView.convert(targetView.bounds, to: rootView))
    proxy.isAccessibilityElement = true
    proxy.isUserInteractionEnabled = false
    proxy.backgroundColor = .clear
    proxy.accessibilityLabel = targetView.accessibilityLabel
    proxy.accessibilityHint = targetView.accessibilityHint
    proxy.accessibilityValue = targetView.accessibilityValue
    proxy.accessibilityTraits = targetView.accessibilityTraits

    func restoreNaturalOrder() {
      proxy.onAccessibilityFocused = nil
      proxy.removeFromSuperview()
      // nil hands traversal ownership straight back to UITableView/UIKit.
      rootView.accessibilityElements = nil
    }

    func finish(_ outcome: [String: Any]) {
      guard !state.completed else { return }
      state.completed = true
      if let observer = state.observer {
        NotificationCenter.default.removeObserver(observer)
        state.observer = nil
      }
      state.timeoutWorkItem?.cancel()
      state.timeoutWorkItem = nil
      restoreNaturalOrder()
      completion(outcome)
    }

    // Use a real UIView for the one-shot anchor. UIAccessibilityElement-only
    // proxies were announced by VoiceOver on iOS 27 but never became the
    // focused object, so the handoff always timed out. A real view has the same
    // UIKit/container-chain shape as the table cells that are known to focus.
    rootView.addSubview(proxy)
    rootView.bringSubviewToFront(proxy)
    rootView.accessibilityElements = [proxy, tableView]
    emitDebug(
      "PROXY_HANDOFF_BEGIN id=\(id) requestId=\(requestId) " +
      "rendererGeneration=\(rendererGeneration) proxyType=UIView frame=\(proxy.frame)"
    )
    print("DOC_NATIVE_SWIFT PROXY_HANDOFF_BEGIN id=\(id) requestId=\(requestId) proxyType=UIView")

    proxy.onAccessibilityFocused = { [weak self, weak proxy] in
      guard let self = self, let proxy = proxy, !state.completed else { return }
      self.emitDebug("PROXY_HANDOFF_FOCUSED id=\(id) requestId=\(requestId) proxyType=UIView")
      print("DOC_NATIVE_SWIFT PROXY_HANDOFF_FOCUSED id=\(id) requestId=\(requestId) proxyType=UIView")

      state.timeoutWorkItem?.cancel()
      state.timeoutWorkItem = nil
      proxy.onAccessibilityFocused = nil
      proxy.removeFromSuperview()
      self.rootView.accessibilityElements = nil

      DispatchQueue.main.async { [weak self] in
        guard let self = self else {
          finish(["posted": false, "reason": "selfReleasedAfterProxy", "proxy": true])
          return
        }
        guard self.focusTokensAreCurrent(
          requestId: requestId,
          rendererGeneration: rendererGeneration
        ) else {
          self.emitDebug("PROXY_HANDOFF_STALE id=\(id) phase=realTarget")
          finish(["posted": false, "reason": "staleAfterProxy", "proxy": true])
          return
        }
        guard let liveIndexPath = self.indexPath(forRowId: id) else {
          self.emitDebug("PROXY_HANDOFF_TARGET_LOST id=\(id) reason=indexPath")
          finish(["posted": false, "reason": "targetLostAfterProxy", "proxy": true])
          return
        }

        self.tableView.layoutIfNeeded()
        let visible = self.tableView.indexPathsForVisibleRows?.contains(liveIndexPath) ?? false
        let cell = self.tableView.cellForRow(at: liveIndexPath)
        guard visible, let liveCell = cell,
              liveCell.window != nil,
              let liveTarget = self.accessibilityTarget(at: liveIndexPath),
              let liveTargetView = liveTarget as? UIView,
              liveTargetView.window != nil,
              liveTargetView.isDescendant(of: self.rootView) else {
          self.emitDebug(
            "PROXY_HANDOFF_TARGET_LOST id=\(id) reason=notReady visible=\(visible) " +
            "cellExists=\(cell != nil) cellWindow=\(cell?.window != nil)"
          )
          self.postVerifiedDirectFocusAfterProxy(
            id: id,
            requestId: requestId,
            rendererGeneration: rendererGeneration,
            completion: finish
          )
          return
        }

        self.currentRequestedFocusRowId = id
        let line =
          "ACCESSIBILITY_POST id=\(id) mode=screenEntry notification=layoutChanged " +
          "phase=proxyToReal requestId=\(requestId) indexPath=\(liveIndexPath) " +
          "visible=true cellExists=true cellWindow=true targetWindow=true targetInRoot=true"
        self.emitDebug(line)
        print("DOC_NATIVE_SWIFT \(line)")
        UIAccessibility.post(notification: .layoutChanged, argument: liveTarget)
        finish([
          "posted": true,
          "reason": "proxyUIViewFocusedThenRealPosted",
          "notification": "layoutChanged",
          "proxy": true,
          "visible": true,
          "cellExists": true,
          "cellWindow": true,
          "targetWindow": true,
          "rootWindow": self.rootView.window != nil,
          "targetInRoot": true
        ])

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.50) { [weak self] in
          guard let self = self else { return }
          if self.currentRequestedFocusRowId == id {
            self.emitDebug("FOCUS_TIMEOUT id=\(id) requestId=\(requestId) via=proxyUIView")
            self.currentRequestedFocusRowId = nil
          }
        }
      }
    }

    let timeout = DispatchWorkItem { [weak self] in
      guard let self = self, !state.completed else { return }
      self.emitDebug("PROXY_HANDOFF_TIMEOUT id=\(id) requestId=\(requestId) proxyType=UIView")
      print("DOC_NATIVE_SWIFT PROXY_HANDOFF_TIMEOUT id=\(id) requestId=\(requestId) proxyType=UIView")
      proxy.onAccessibilityFocused = nil
      proxy.removeFromSuperview()
      self.rootView.accessibilityElements = nil

      // No accessibility retry storm: after one proxy attempt, verify the real
      // cell is actually materialized/in-window, then perform one direct post.
      self.postVerifiedDirectFocusAfterProxy(
        id: id,
        requestId: requestId,
        rendererGeneration: rendererGeneration,
        completion: finish
      )
    }
    state.timeoutWorkItem = timeout

    UIAccessibility.post(notification: .screenChanged, argument: proxy)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: timeout)
  }

  private func focusAccessibleRow(
    id: String,
    mode: String,
    animated: Bool,
    requestId: Int,
    rendererGeneration: Int,
    useFocusProxy: Bool,
    completion: @escaping ([String: Any]) -> Void
  ) {
    focusTraceExpectedRowId = id
    print(
      "DOC_NATIVE_SWIFT NATIVE_FOCUS_ENTER id=\(id) mode=\(mode) " +
      "requestId=\(requestId) rendererGeneration=\(rendererGeneration)"
    )

    guard focusTokensAreCurrent(
      requestId: requestId,
      rendererGeneration: rendererGeneration
    ) else {
      let reason = "tokenOrWindowMismatch"
      print(
        "DOC_NATIVE_SWIFT NATIVE_GUARD_TOKENS result=fail id=\(id) " +
        "requestId=\(requestId) currentRequestId=\(currentFocusRequestId) " +
        "rendererGeneration=\(rendererGeneration) currentRendererGeneration=\(currentRendererGeneration) " +
        "window=\(rootView.window != nil)"
      )
      emitDebug(
        "NATIVE_GUARD_TOKENS result=fail id=\(id) requestId=\(requestId) " +
        "currentRequestId=\(currentFocusRequestId) rendererGeneration=\(rendererGeneration) " +
        "currentRendererGeneration=\(currentRendererGeneration) window=\(rootView.window != nil)"
      )
      completion(["posted": false, "reason": reason])
      return
    }
    print("DOC_NATIVE_SWIFT NATIVE_GUARD_TOKENS result=pass id=\(id)")

    guard let indexPath = indexPath(forRowId: id) else {
      print("DOC_NATIVE_SWIFT NATIVE_GUARD_INDEXPATH result=fail id=\(id)")
      emitDebug("NATIVE_GUARD_INDEXPATH result=fail id=\(id)")
      completion(["posted": false, "reason": "indexPathNotFound"])
      return
    }
    print("DOC_NATIVE_SWIFT NATIVE_GUARD_INDEXPATH result=pass id=\(id) indexPath=\(indexPath)")

    tableView.layoutIfNeeded()
    if !(tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false) {
      tableView.scrollToRow(at: indexPath, at: .middle, animated: animated)
      tableView.layoutIfNeeded()
    }
    guard accessibilityTarget(at: indexPath) != nil else {
      print("DOC_NATIVE_SWIFT NATIVE_GUARD_TARGET_PREASYNC result=fail id=\(id) indexPath=\(indexPath)")
      emitDebug("NATIVE_GUARD_TARGET_PREASYNC result=fail id=\(id) indexPath=\(indexPath)")
      completion(["posted": false, "reason": "targetUnavailableBeforeAsync"])
      return
    }
    print("DOC_NATIVE_SWIFT NATIVE_GUARD_TARGET_PREASYNC result=pass id=\(id) indexPath=\(indexPath)")
    print("DOC_NATIVE_SWIFT NATIVE_DISPATCH_SCHEDULED queue=main.async id=\(id)")
    emitDebug("NATIVE_DISPATCH_SCHEDULED queue=main.async id=\(id)")

    // Defer the UIAccessibility notification to the next run-loop turn so
    // UIKit/VoiceOver can observe the fully committed table/accessibility tree.
    DispatchQueue.main.async { [weak self] in
      print("DOC_NATIVE_SWIFT NATIVE_ASYNC_ENTERED id=\(id)")
      guard let self = self else {
        print("DOC_NATIVE_SWIFT NATIVE_GUARD_SELF result=fail id=\(id)")
        completion(["posted": false, "reason": "selfReleased"])
        return
      }
      self.emitDebug("NATIVE_ASYNC_ENTERED id=\(id)")
      print("DOC_NATIVE_SWIFT NATIVE_GUARD_SELF result=pass id=\(id)")

      guard self.focusTokensAreCurrent(
        requestId: requestId,
        rendererGeneration: rendererGeneration
      ) else {
        print(
          "DOC_NATIVE_SWIFT NATIVE_GUARD_GENERATION result=fail id=\(id) " +
          "requestId=\(requestId) currentRequestId=\(self.currentFocusRequestId) " +
          "rendererGeneration=\(rendererGeneration) currentRendererGeneration=\(self.currentRendererGeneration) " +
          "window=\(self.rootView.window != nil)"
        )
        self.emitDebug(
          "NATIVE_GUARD_GENERATION result=fail id=\(id) requestId=\(requestId) " +
          "currentRequestId=\(self.currentFocusRequestId) rendererGeneration=\(rendererGeneration) " +
          "currentRendererGeneration=\(self.currentRendererGeneration) window=\(self.rootView.window != nil)"
        )
        completion(["posted": false, "reason": "generationMismatchAfterAsync"])
        return
      }
      print("DOC_NATIVE_SWIFT NATIVE_GUARD_GENERATION result=pass id=\(id)")

      guard let liveIndexPath = self.indexPath(forRowId: id) else {
        print("DOC_NATIVE_SWIFT NATIVE_GUARD_INDEXPATH_ASYNC result=fail id=\(id)")
        self.emitDebug("NATIVE_GUARD_INDEXPATH_ASYNC result=fail id=\(id)")
        completion(["posted": false, "reason": "indexPathLostAfterAsync"])
        return
      }
      self.tableView.layoutIfNeeded()
      let visible = self.tableView.indexPathsForVisibleRows?.contains(liveIndexPath) ?? false
      let cell = self.tableView.cellForRow(at: liveIndexPath)
      guard let target = self.accessibilityTarget(at: liveIndexPath) else {
        print(
          "DOC_NATIVE_SWIFT NATIVE_GUARD_CELL result=fail id=\(id) indexPath=\(liveIndexPath) " +
          "visible=\(visible) cellExists=\(cell != nil)"
        )
        self.emitDebug(
          "NATIVE_GUARD_CELL result=fail id=\(id) indexPath=\(liveIndexPath) " +
          "visible=\(visible) cellExists=\(cell != nil)"
        )
        completion(["posted": false, "reason": "targetUnavailableAfterAsync"])
        return
      }
      print(
        "DOC_NATIVE_SWIFT NATIVE_GUARD_CELL result=pass id=\(id) indexPath=\(liveIndexPath) " +
        "visible=\(visible) cellExists=\(cell != nil)"
      )

      let targetView = target as? UIView
      let cellWindow = cell?.window != nil
      let targetWindow = targetView?.window != nil
      let rootWindow = self.rootView.window != nil
      guard rootWindow else {
        print(
          "DOC_NATIVE_SWIFT NATIVE_GUARD_WINDOW result=fail id=\(id) " +
          "cellWindow=\(cellWindow) targetWindow=\(targetWindow) rootWindow=\(rootWindow)"
        )
        self.emitDebug(
          "NATIVE_GUARD_WINDOW result=fail id=\(id) cellWindow=\(cellWindow) " +
          "targetWindow=\(targetWindow) rootWindow=\(rootWindow)"
        )
        completion(["posted": false, "reason": "windowMissingAfterAsync"])
        return
      }
      print(
        "DOC_NATIVE_SWIFT NATIVE_GUARD_WINDOW result=pass id=\(id) " +
        "cellWindow=\(cellWindow) targetWindow=\(targetWindow) rootWindow=\(rootWindow)"
      )

      let targetInRoot = targetView?.isDescendant(of: self.rootView) ?? false

      let eligibleForProxy = mode == "screenEntry" || mode == "routeReturnJump"
      if useFocusProxy && eligibleForProxy {
        self.performVerifiedProxyFirstFocusHandoff(
          id: id,
          requestId: requestId,
          rendererGeneration: rendererGeneration,
          completion: completion
        )
        return
      }

      // Keep ordinary in-place jumps (for example Document slider jumps) on
      // their established direct path. For a fresh route-return renderer there
      // are two distinct real-device states:
      // 1) VoiceOver is still outside this UITableView (for example on the
      //    Flutter Back button): screenChanged is the correct entry post.
      // 2) VoiceOver has already entered this exact UITableView on select_letter
      //    or another wrong row: posting screenChanged races UIKit's current-row
      //    ownership and can snap the table back to the top. In that state the
      //    target is an in-subtree correction, so use one layoutChanged instead.
      let usesScreenChanged = mode == "screenEntry" || mode == "routeReturnJump"
      let focusedRowBeforePost = self.voiceOverFocusedRowId()
      let correctingWrongRowInCurrentTable =
        usesScreenChanged && focusedRowBeforePost != nil && focusedRowBeforePost != id
      let notification: UIAccessibility.Notification = correctingWrongRowInCurrentTable
        ? .layoutChanged
        : (usesScreenChanged ? .screenChanged : .layoutChanged)
      let notificationName = correctingWrongRowInCurrentTable
        ? "layoutChanged"
        : (usesScreenChanged ? "screenChanged" : "layoutChanged")
      let postPhase = correctingWrongRowInCurrentTable ? "currentTableCorrection" : "direct"
      self.currentRequestedFocusRowId = id
      let postLine =
        "ACCESSIBILITY_POST id=\(id) mode=\(mode) notification=\(notificationName) " +
        "phase=\(postPhase) requestId=\(requestId) rendererGeneration=\(rendererGeneration) " +
        "focusedRowBeforePost=\(focusedRowBeforePost ?? "nil") " +
        "indexPath=\(liveIndexPath) visible=\(visible) cellExists=\(cell != nil) " +
        "cellWindow=\(cellWindow) targetWindow=\(targetWindow) rootWindow=\(rootWindow) " +
        "targetInRoot=\(targetInRoot) targetType=\(String(describing: type(of: target))) " +
        "offsetY=\(self.tableView.contentOffset.y)"
      print("DOC_NATIVE_SWIFT \(postLine)")
      self.emitDebug(postLine)
      UIAccessibility.post(notification: notification, argument: target)

      completion([
        "posted": true,
        "reason": correctingWrongRowInCurrentTable ? "postedCurrentTableCorrection" : "posted",
        "notification": notificationName,
        "visible": visible,
        "cellExists": cell != nil,
        "cellWindow": cellWindow,
        "targetWindow": targetWindow,
        "rootWindow": rootWindow,
        "targetInRoot": targetInRoot
      ])

      // The golden Document trace shows VoiceOver may confirm the target
      // roughly 0.86 s after the post. Keep diagnostics alive beyond that real
      // device latency so a slow but valid focus is not mislabeled as failure.
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.50) { [weak self] in
        guard let self = self else { return }
        if self.currentRequestedFocusRowId == id {
          self.emitDebug("FOCUS_TIMEOUT id=\(id) requestId=\(requestId)")
          print("DOC_NATIVE_SWIFT FOCUS_TIMEOUT id=\(id) requestId=\(requestId)")
          self.currentRequestedFocusRowId = nil
        }
      }
    }
  }

  private func scrollToRow(id: String, animated: Bool, attempt: Int = 0) {
    guard let indexPath = indexPath(forRowId: id) else {
      emitDebug("scrollToRow id=\(id) attempt=\(attempt) indexPath NOT FOUND rows=\(sections.reduce(0) { $0 + $1.rows.count })")
      return
    }
    emitDebug("scrollToRow id=\(id) attempt=\(attempt) indexPath=\(indexPath) animated=\(animated) beforeOffsetY=\(tableView.contentOffset.y) visible=\(tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false)")
    tableView.layoutIfNeeded()
    tableView.scrollToRow(at: indexPath, at: .middle, animated: animated)

    let delay: TimeInterval = animated ? 0.40 : 0.03
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      guard let self = self else { return }
      self.tableView.layoutIfNeeded()
      let isVisible = self.tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false
      self.emitDebug("scrollToRow verify id=\(id) attempt=\(attempt) visible=\(isVisible) offsetY=\(self.tableView.contentOffset.y) cellExists=\(self.tableView.cellForRow(at: indexPath) != nil)")
      if !isVisible && attempt < 12 {
        self.scrollToRow(id: id, animated: false, attempt: attempt + 1)
      }
    }
  }

  private func focusRow(
    id: String,
    animated: Bool,
    attempt: Int = 0,
    maxAttempts: Int = 4,
    screenChanged: Bool = false
  ) {
    focusTraceExpectedRowId = id
    guard let indexPath = indexPath(forRowId: id) else {
      emitDebug("focusRow id=\(id) attempt=\(attempt) indexPath NOT FOUND rows=\(sections.reduce(0) { $0 + $1.rows.count })")
      return
    }
    let focusedBefore = voiceOverFocusedRowId() ?? "nil"
    emitDebug("focusRow id=\(id) attempt=\(attempt) indexPath=\(indexPath) animated=\(animated) window=\(rootView.window != nil) beforeFocused=\(focusedBefore) beforeOffsetY=\(tableView.contentOffset.y)")
    tableView.scrollToRow(at: indexPath, at: .middle, animated: animated)
    tableView.layoutIfNeeded()

    let delay: TimeInterval = animated ? 0.45 : 0.05
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      guard let self = self else { return }
      self.tableView.layoutIfNeeded()

      guard self.rootView.window != nil,
            let target = self.accessibilityTarget(at: indexPath) else {
        if attempt < maxAttempts {
          self.emitDebug("focusRow target unavailable id=\(id) attempt=\(attempt) -> retry")
          self.focusRow(
            id: id,
            animated: false,
            attempt: attempt + 1,
            maxAttempts: maxAttempts,
            screenChanged: screenChanged
          )
        }
        return
      }

      let notification: UIAccessibility.Notification = screenChanged ? .screenChanged : .layoutChanged
      let notificationName = screenChanged ? "screenChanged" : "layoutChanged"
      self.emitDebug("focusRow POST id=\(id) attempt=\(attempt) notification=\(notificationName) offsetY=\(self.tableView.contentOffset.y)")
      UIAccessibility.post(notification: notification, argument: target)

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
        guard let self = self else { return }
        let focusedAfter = self.voiceOverFocusedRowId()
        self.emitDebug("focusRow VERIFY id=\(id) attempt=\(attempt) focusedAfter=\(focusedAfter ?? "nil") expected=\(id)")
        if focusedAfter != id && attempt < maxAttempts {
          self.focusRow(
            id: id,
            animated: false,
            attempt: attempt + 1,
            maxAttempts: maxAttempts,
            screenChanged: screenChanged
          )
        }
      }
    }
  }

  private func indexPath(forRowId id: String) -> IndexPath? {
    for (sectionIndex, section) in sections.enumerated() {
      if let rowIndex = section.rows.firstIndex(where: { $0.id == id }) {
        return IndexPath(row: rowIndex, section: sectionIndex)
      }
    }
    return nil
  }
}

private final class SonarpadNativePickerController: UITableViewController {
  private let options: [SonarpadNativeOption]
  private let selectedValue: String?
  private let onSelected: (SonarpadNativeOption) -> Void

  init(title: String, options: [SonarpadNativeOption], selectedValue: String?, onSelected: @escaping (SonarpadNativeOption) -> Void) {
    self.options = options
    self.selectedValue = selectedValue
    self.onSelected = onSelected
    super.init(style: .insetGrouped)
    self.title = title
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))
    tableView.estimatedRowHeight = 52
    tableView.rowHeight = UITableView.automaticDimension
  }

  @objc private func close() { dismiss(animated: true) }
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { options.count }
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "option") ?? UITableViewCell(style: .default, reuseIdentifier: "option")
    let option = options[indexPath.row]
    cell.textLabel?.text = option.label
    cell.textLabel?.numberOfLines = 0
    cell.isAccessibilityElement = true
    cell.textLabel?.isAccessibilityElement = false
    cell.accessibilityLabel = option.label
    cell.accessibilityValue = nil
    let isSelected = String(describing: option.value) == selectedValue
    cell.accessoryType = isSelected ? .checkmark : .none
    if isSelected {
      cell.accessibilityTraits.insert(.selected)
    } else {
      cell.accessibilityTraits.remove(.selected)
    }
    return cell
  }
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let option = options[indexPath.row]
    onSelected(option)
    dismiss(animated: true)
  }
}

private final class SonarpadNativeListFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger; super.init() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    SonarpadNativeListView(frame: frame, viewIdentifier: viewId, arguments: args, messenger: messenger)
  }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
}

private struct SonarpadGridItem {
  let id: String
  let title: String
  let subtitle: String?
  let accessibilityLabel: String?
  let hint: String?
  let enabled: Bool
  init(_ map: [String: Any]) {
    id = map["id"] as? String ?? UUID().uuidString
    title = map["title"] as? String ?? ""
    subtitle = map["subtitle"] as? String
    accessibilityLabel = map["accessibilityLabel"] as? String
    hint = map["hint"] as? String
    enabled = map["enabled"] as? Bool ?? true
  }
}

private final class SonarpadGridCell: UICollectionViewCell {
  let titleLabel = UILabel()
  let subtitleLabel = UILabel()
  var activationHandler: (() -> Void)?
  override init(frame: CGRect) {
    super.init(frame: frame)
    contentView.backgroundColor = .secondarySystemGroupedBackground
    contentView.layer.cornerRadius = 12
    titleLabel.font = UIFont.preferredFont(forTextStyle: .body)
    titleLabel.textAlignment = .center
    titleLabel.numberOfLines = 0
    subtitleLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
    subtitleLabel.textColor = .secondaryLabel
    subtitleLabel.textAlignment = .center
    subtitleLabel.numberOfLines = 0
    let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
    stack.axis = .vertical
    stack.spacing = 4
    stack.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
      stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
      stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
    ])
    isAccessibilityElement = true
    accessibilityTraits = .button
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override func accessibilityActivate() -> Bool { activationHandler?(); return activationHandler != nil }
}

private final class SonarpadNativeGridView: NSObject, FlutterPlatformView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
  private let rootView: UIView
  private let collectionView: UICollectionView
  private let channel: FlutterMethodChannel
  private var items: [SonarpadGridItem] = []
  private var columns = 2

  init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, messenger: FlutterBinaryMessenger) {
    rootView = UIView(frame: frame)
    let layout = UICollectionViewFlowLayout()
    layout.minimumInteritemSpacing = 12
    layout.minimumLineSpacing = 12
    layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    channel = FlutterMethodChannel(name: "sonarpad/native_accessible_grid/\(viewId)", binaryMessenger: messenger)
    super.init()
    rootView.backgroundColor = .systemBackground
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    collectionView.backgroundColor = .systemBackground
    collectionView.dataSource = self
    collectionView.delegate = self
    collectionView.register(SonarpadGridCell.self, forCellWithReuseIdentifier: "grid")
    rootView.addSubview(collectionView)
    NSLayoutConstraint.activate([
      collectionView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
      collectionView.topAnchor.constraint(equalTo: rootView.topAnchor),
      collectionView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
    ])
    apply(arguments: args)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "setData" { self?.apply(arguments: call.arguments); result(nil) }
      else { result(FlutterMethodNotImplemented) }
    }
  }
  func view() -> UIView { rootView }
  private func apply(arguments: Any?) {
    guard let map = arguments as? [String: Any] else { return }
    items = (map["items"] as? [[String: Any]] ?? []).map(SonarpadGridItem.init)
    columns = max(map["columns"] as? Int ?? 2, 1)
    collectionView.reloadData()
  }
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "grid", for: indexPath) as! SonarpadGridCell
    let item = items[indexPath.item]
    cell.titleLabel.text = item.title
    cell.subtitleLabel.text = item.subtitle
    cell.subtitleLabel.isHidden = item.subtitle?.isEmpty ?? true
    cell.accessibilityLabel = item.accessibilityLabel ?? item.title
    cell.accessibilityHint = item.hint
    cell.accessibilityTraits = item.enabled ? .button : [.button, .notEnabled]
    cell.activationHandler = { [weak self] in self?.sendActivation(item) }
    return cell
  }
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) { sendActivation(items[indexPath.item]) }
  private func sendActivation(_ item: SonarpadGridItem) {
    guard item.enabled else { return }
    channel.invokeMethod("event", arguments: ["type": "activate", "id": item.id])
  }
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let layout = collectionViewLayout as! UICollectionViewFlowLayout
    let totalSpacing = layout.sectionInset.left + layout.sectionInset.right + CGFloat(columns - 1) * layout.minimumInteritemSpacing
    let width = max((collectionView.bounds.width - totalSpacing) / CGFloat(columns), 80)
    return CGSize(width: width, height: 96)
  }
}

private final class SonarpadNativeGridFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger; super.init() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    SonarpadNativeGridView(frame: frame, viewIdentifier: viewId, arguments: args, messenger: messenger)
  }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
}

extension FlutterPluginRegistry {
  func registerSonarpadNativeAccessibleViews() {
    guard let registrar = registrar(forPlugin: "SonarpadNativeAccessibleViews") else { return }
    registrar.register(SonarpadNativeListFactory(messenger: registrar.messenger()), withId: "sonarpad/native_accessible_list")
    registrar.register(SonarpadNativeGridFactory(messenger: registrar.messenger()), withId: "sonarpad/native_accessible_grid")
  }
}

private extension UIView {
  var sonarpadViewController: UIViewController? {
    var responder: UIResponder? = self
    while let current = responder {
      if let controller = current as? UIViewController { return controller }
      responder = current.next
    }
    return nil
  }
}
