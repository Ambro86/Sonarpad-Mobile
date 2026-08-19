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
  var secure: Bool
  var placeholder: String?
  var options: [SonarpadNativeOption]
  var actions: [SonarpadNativeAction]

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
    secure = map["secure"] as? Bool ?? false
    placeholder = map["placeholder"] as? String
    options = (map["options"] as? [[String: Any]] ?? []).map {
      SonarpadNativeOption(value: $0["value"] as Any, label: $0["label"] as? String ?? String(describing: $0["value"] ?? ""))
    }
    actions = (map["actions"] as? [[String: Any]] ?? []).compactMap {
      guard let id = $0["id"] as? String, let label = $0["label"] as? String else { return nil }
      return SonarpadNativeAction(id: id, label: label)
    }
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
        lhs.secure == rhs.secure,
        lhs.placeholder == rhs.placeholder,
        lhs.options.count == rhs.options.count,
        lhs.actions.count == rhs.actions.count else { return false }

  for (left, right) in zip(lhs.options, rhs.options) {
    if left.label != right.label || !sonarpadValuesEqual(left.value, right.value) { return false }
  }
  for (left, right) in zip(lhs.actions, rhs.actions) {
    if left.id != right.id || left.label != right.label { return false }
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
  var onChanged: ((String, String) -> Void)?

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
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  @objc private func valueChanged() {
    onChanged?(rowId, field.text ?? "")
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
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

  private func emitDebug(_ message: String) {
    guard debugTag?.isEmpty == false else { return }
    let line = "DOC_NATIVE_SWIFT \(message)"
    print(line)
    channel.invokeMethod("event", arguments: ["type": "debug", "message": line])
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

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "setData":
        self.apply(arguments: call.arguments)
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
      case "focusAccessibleRow":
        guard let map = call.arguments as? [String: Any],
              let id = map["id"] as? String,
              let mode = map["mode"] as? String,
              let requestId = map["requestId"] as? Int,
              let rendererGeneration = map["rendererGeneration"] as? Int else {
          result(nil)
          break
        }
        let animated = map["animated"] as? Bool ?? false
        self.emitDebug(
          "NATIVE_RECEIVED id=\(id) mode=\(mode) requestId=\(requestId) " +
          "rendererGeneration=\(rendererGeneration)"
        )
        self.focusAccessibleRow(
          id: id,
          mode: mode,
          animated: animated,
          requestId: requestId,
          rendererGeneration: rendererGeneration
        )
        result(nil)
      case "focusInitial":
        if let map = call.arguments as? [String: Any], let id = map["id"] as? String {
          self.emitDebug("method focusInitial compatibility id=\(id) window=\(self.rootView.window != nil)")
          self.focusRow(id: id, animated: false, maxAttempts: 0, screenChanged: true)
        }
        result(nil)
      case "focusScreenEntry":
        if let map = call.arguments as? [String: Any], let id = map["id"] as? String {
          let animated = map["animated"] as? Bool ?? false
          self.emitDebug("method focusScreenEntry compatibility id=\(id) animated=\(animated)")
          self.focusRow(id: id, animated: animated, maxAttempts: 0, screenChanged: true)
        }
        result(nil)
      case "focusTo":
        if let map = call.arguments as? [String: Any], let id = map["id"] as? String {
          let animated = map["animated"] as? Bool ?? false
          self.emitDebug("method focusTo compatibility id=\(id) animated=\(animated)")
          self.focusRow(id: id, animated: animated, maxAttempts: 0, screenChanged: false)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
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
      cell.field.placeholder = row.placeholder ?? row.title
      cell.field.accessibilityLabel = row.accessibilityLabel ?? row.title
      cell.field.accessibilityHint = row.hint
      cell.field.isSecureTextEntry = row.secure
      cell.field.isEnabled = row.enabled
      cell.onChanged = { [weak self] id, value in
        self?.channel.invokeMethod("event", arguments: ["type": "textChanged", "id": id, "value": value])
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
    cell.selectionStyle = row.enabled && row.kind != "text" ? .default : .none
    cell.isUserInteractionEnabled = row.enabled
    cell.accessoryType = (row.kind == "action" || row.kind == "picker" || row.kind == "button") ? .disclosureIndicator : .none
    cell.isAccessibilityElement = true
    cell.accessibilityLabel = row.accessibilityLabel ?? row.title
    cell.accessibilityHint = row.hint
    cell.accessibilityValue = row.valueLabel ?? row.value
    var traits: UIAccessibilityTraits = []
    if row.accessibilityButtonTrait && (row.kind == "action" || row.kind == "picker" || row.kind == "button" || row.kind == "toggle") { traits.insert(.button) }
    if row.kind == "slider" { traits.insert(.adjustable) }
    if row.kind == "header" { traits.insert(.header) }
    if row.selected { traits.insert(.selected) }
    if !row.enabled { traits.insert(.notEnabled) }
    cell.accessibilityTraits = traits

    switch row.kind {
    case "toggle":
      let toggle = UISwitch()
      toggle.isOn = row.toggleValue
      toggle.isEnabled = row.enabled
      toggle.isAccessibilityElement = true
      toggle.accessibilityLabel = row.accessibilityLabel ?? row.title
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
      slider.isAccessibilityElement = true
      slider.accessibilityLabel = row.accessibilityLabel ?? row.title
      slider.accessibilityHint = row.hint
      slider.accessibilityValue = row.valueLabel ?? row.value ?? formatSliderValue(row.sliderValue)
      slider.accessibilityFocusHandler = { [weak self] id in
        self?.channel.invokeMethod("event", arguments: ["type": "focus", "id": id])
      }
      slider.incrementHandler = { [weak self] in
        self?.adjustSlider(at: indexPath, delta: row.sliderStep)
      }
      slider.decrementHandler = { [weak self] in
        self?.adjustSlider(at: indexPath, delta: -row.sliderStep)
      }
      slider.addTarget(self, action: #selector(sliderControlChanged(_:)), for: .valueChanged)
      cell.accessoryView = slider
      cell.isAccessibilityElement = false
      cell.selectionStyle = .none
      cell.activationHandler = nil
      cell.incrementHandler = nil
      cell.decrementHandler = nil
    case "picker":
      cell.activationHandler = { [weak self] in self?.presentPicker(for: indexPath) }
    case "action", "button":
      cell.activationHandler = { [weak self] in self?.sendActivation(at: indexPath) }
    default:
      cell.activationHandler = nil
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

  private struct AssociatedKeys {
    static var rowId: UInt8 = 0
    static var actionId: UInt8 = 0
  }

  @objc private func handleCustomAction(_ action: UIAccessibilityCustomAction) -> Bool {
    guard let rowId = objc_getAssociatedObject(action, &AssociatedKeys.rowId) as? String,
          let actionId = objc_getAssociatedObject(action, &AssociatedKeys.actionId) as? String else { return false }
    channel.invokeMethod("event", arguments: ["type": "customAction", "id": rowId, "action": actionId])
    return true
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
    let raw = min(max(Double(sender.value), row.sliderMin), row.sliderMax)
    let steps = ((raw - row.sliderMin) / row.sliderStep).rounded()
    row.sliderValue = min(max(row.sliderMin + steps * row.sliderStep, row.sliderMin), row.sliderMax)
    sender.value = Float(row.sliderValue)
    sender.accessibilityValue = row.valueLabel ?? row.value ?? formatSliderValue(row.sliderValue)
    sections[indexPath.section].rows[indexPath.row] = row
    channel.invokeMethod("event", arguments: ["type": "slider", "id": row.id, "value": row.sliderValue])
  }

  private func toggleRow(at indexPath: IndexPath) {
    guard sections.indices.contains(indexPath.section), sections[indexPath.section].rows.indices.contains(indexPath.row) else { return }
    sections[indexPath.section].rows[indexPath.row].toggleValue.toggle()
    let row = sections[indexPath.section].rows[indexPath.row]
    channel.invokeMethod("event", arguments: ["type": "toggle", "id": row.id, "value": row.toggleValue])
    tableView.reloadRows(at: [indexPath], with: .none)
    UIAccessibility.post(notification: .layoutChanged, argument: tableView.cellForRow(at: indexPath))
  }

  private func adjustSlider(at indexPath: IndexPath, delta: Double) {
    guard sections.indices.contains(indexPath.section), sections[indexPath.section].rows.indices.contains(indexPath.row) else { return }
    var row = sections[indexPath.section].rows[indexPath.row]
    let announcedValue = delta >= 0 ? row.sliderIncreasedValueLabel : row.sliderDecreasedValueLabel
    let raw = min(max(row.sliderValue + delta, row.sliderMin), row.sliderMax)
    let steps = ((raw - row.sliderMin) / row.sliderStep).rounded()
    row.sliderValue = min(max(row.sliderMin + steps * row.sliderStep, row.sliderMin), row.sliderMax)
    let spokenValue = announcedValue ?? formatSliderValue(row.sliderValue)
    row.value = spokenValue
    row.valueLabel = spokenValue
    sections[indexPath.section].rows[indexPath.row] = row

    // VoiceOver is focused on the UISlider itself. Updating the same object
    // synchronously lets the adjustable gesture announce the new value while
    // keeping focus on the slider. Never reload the row for a value change.
    if let cell = tableView.cellForRow(at: indexPath),
       let slider = cell.accessoryView as? SonarpadAccessibleSlider {
      slider.value = Float(row.sliderValue)
      slider.accessibilityValue = spokenValue
    }
    channel.invokeMethod("event", arguments: ["type": "slider", "id": row.id, "value": row.sliderValue])
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
      slider.minimumValue = Float(row.sliderMin)
      slider.maximumValue = Float(row.sliderMax)
      slider.value = Float(row.sliderValue)
      slider.isEnabled = row.enabled
      slider.isUserInteractionEnabled = row.enabled
      slider.accessibilityLabel = row.accessibilityLabel ?? row.title
      slider.accessibilityHint = row.hint
      slider.accessibilityValue = row.valueLabel ?? row.value ?? formatSliderValue(row.sliderValue)
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
        cell.field.placeholder = row.placeholder ?? row.title
        cell.field.accessibilityLabel = row.accessibilityLabel ?? row.title
        cell.field.accessibilityHint = row.hint
        cell.field.isSecureTextEntry = row.secure
        cell.field.isEnabled = row.enabled
        continue
      }

      guard let cell = tableView.cellForRow(at: indexPath) as? SonarpadAccessibleTableCell else { continue }

      if row.kind == "slider" {
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = row.subtitle ?? row.value
        if let slider = cell.accessoryView as? SonarpadAccessibleSlider {
          slider.minimumValue = Float(row.sliderMin)
          slider.maximumValue = Float(row.sliderMax)
          slider.value = Float(row.sliderValue)
          slider.isEnabled = row.enabled
          slider.isUserInteractionEnabled = row.enabled
          slider.accessibilityLabel = row.accessibilityLabel ?? row.title
          slider.accessibilityHint = row.hint
          slider.accessibilityValue = row.valueLabel ?? row.value ?? formatSliderValue(row.sliderValue)
        }
        continue
      }

      if row.kind == "toggle" {
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = row.subtitle ?? row.value
        if let toggle = cell.accessoryView as? UISwitch {
          toggle.isOn = row.toggleValue
          toggle.isEnabled = row.enabled
          toggle.accessibilityLabel = row.accessibilityLabel ?? row.title
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
    emitDebug(
      "VOICEOVER_FOCUSED row=\(id) expected=\(expected ?? "nil") " +
      "matchesTarget=\(matchesTarget)"
    )
    if expected != nil { currentRequestedFocusRowId = nil }
    channel.invokeMethod("event", arguments: ["type": "focus", "id": id])
  }

  private func accessibilityTarget(at indexPath: IndexPath) -> Any? {
    guard let cell = tableView.cellForRow(at: indexPath) else { return nil }
    if sections.indices.contains(indexPath.section),
       sections[indexPath.section].rows.indices.contains(indexPath.row),
       sections[indexPath.section].rows[indexPath.row].kind == "slider",
       let slider = cell.accessoryView as? SonarpadAccessibleSlider {
      return slider
    }
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

  private func focusAccessibleRow(
    id: String,
    mode: String,
    animated: Bool,
    requestId: Int,
    rendererGeneration: Int
  ) {
    guard focusTokensAreCurrent(
      requestId: requestId,
      rendererGeneration: rendererGeneration
    ) else {
      emitDebug(
        "NATIVE_FOCUS_REJECT id=\(id) mode=\(mode) requestId=\(requestId) " +
        "currentRequestId=\(currentFocusRequestId) rendererGeneration=\(rendererGeneration) " +
        "currentRendererGeneration=\(currentRendererGeneration) window=\(rootView.window != nil)"
      )
      return
    }
    guard let indexPath = indexPath(forRowId: id) else {
      emitDebug("NATIVE_FOCUS_REJECT id=\(id) mode=\(mode) reason=indexPathNotFound")
      return
    }

    tableView.layoutIfNeeded()
    if !(tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false) {
      tableView.scrollToRow(at: indexPath, at: .middle, animated: animated)
      tableView.layoutIfNeeded()
    }
    guard accessibilityTarget(at: indexPath) != nil else {
      emitDebug("NATIVE_FOCUS_REJECT id=\(id) mode=\(mode) reason=targetUnavailable")
      return
    }

    // Defer the UIAccessibility notification to the next run-loop turn so
    // UIKit/VoiceOver can observe the fully committed table/accessibility tree.
    DispatchQueue.main.async { [weak self] in
      guard let self = self,
            self.focusTokensAreCurrent(
              requestId: requestId,
              rendererGeneration: rendererGeneration
            ),
            let target = self.accessibilityTarget(at: indexPath) else {
        return
      }

      let isScreenEntry = mode == "screenEntry"
      let notification: UIAccessibility.Notification = isScreenEntry ? .screenChanged : .layoutChanged
      let notificationName = isScreenEntry ? "screenChanged" : "layoutChanged"
      self.currentRequestedFocusRowId = id
      self.emitDebug(
        "ACCESSIBILITY_POST id=\(id) mode=\(mode) notification=\(notificationName) " +
        "requestId=\(requestId) rendererGeneration=\(rendererGeneration) " +
        "offsetY=\(self.tableView.contentOffset.y)"
      )
      UIAccessibility.post(notification: notification, argument: target)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) { [weak self] in
        guard let self = self else { return }
        if self.currentRequestedFocusRowId == id {
          self.emitDebug("FOCUS_TIMEOUT id=\(id) requestId=\(requestId)")
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
