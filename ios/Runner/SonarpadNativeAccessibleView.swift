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
  var toggleValue: Bool
  var sliderValue: Double
  var sliderMin: Double
  var sliderMax: Double
  var sliderStep: Double
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
    toggleValue = map["toggleValue"] as? Bool ?? false
    sliderValue = (map["sliderValue"] as? NSNumber)?.doubleValue ?? 0
    sliderMin = (map["sliderMin"] as? NSNumber)?.doubleValue ?? 0
    sliderMax = (map["sliderMax"] as? NSNumber)?.doubleValue ?? 1
    sliderStep = max((map["sliderStep"] as? NSNumber)?.doubleValue ?? 0.1, 0.000001)
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

private final class SonarpadAccessibleTableCell: UITableViewCell {
  var activationHandler: (() -> Void)?
  var incrementHandler: (() -> Void)?
  var decrementHandler: (() -> Void)?

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

  override func prepareForReuse() {
    super.prepareForReuse()
    activationHandler = nil
    incrementHandler = nil
    decrementHandler = nil
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
          self.scrollToRow(id: id, animated: map["animated"] as? Bool ?? true)
        }
        result(nil)
      case "focusTo":
        if let map = call.arguments as? [String: Any], let id = map["id"] as? String {
          self.focusRow(id: id, animated: map["animated"] as? Bool ?? false)
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
    let rawSections = map["sections"] as? [[String: Any]] ?? []
    sections = rawSections.map(SonarpadNativeSection.init)

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
    tableView.reloadData()

    let requestedInitialFocusId = map["initialFocusId"] as? String
    if requestedInitialFocusId != lastInitialFocusId {
      lastInitialFocusId = requestedInitialFocusId
      if let id = requestedInitialFocusId, !id.isEmpty {
        focusRow(id: id, animated: false)
      }
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
    if row.kind == "action" || row.kind == "picker" || row.kind == "button" || row.kind == "toggle" { traits.insert(.button) }
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
      let slider = UISlider(frame: CGRect(x: 0, y: 0, width: 120, height: 32))
      slider.minimumValue = Float(row.sliderMin)
      slider.maximumValue = Float(row.sliderMax)
      slider.value = Float(row.sliderValue)
      slider.isUserInteractionEnabled = false
      slider.isAccessibilityElement = false
      cell.accessoryView = slider
      cell.activationHandler = nil
      cell.incrementHandler = { [weak self] in self?.adjustSlider(at: indexPath, delta: row.sliderStep) }
      cell.decrementHandler = { [weak self] in self?.adjustSlider(at: indexPath, delta: -row.sliderStep) }
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
    let raw = min(max(row.sliderValue + delta, row.sliderMin), row.sliderMax)
    let steps = ((raw - row.sliderMin) / row.sliderStep).rounded()
    row.sliderValue = min(max(row.sliderMin + steps * row.sliderStep, row.sliderMin), row.sliderMax)
    row.value = formatSliderValue(row.sliderValue)
    row.valueLabel = row.value
    sections[indexPath.section].rows[indexPath.row] = row
    channel.invokeMethod("event", arguments: ["type": "slider", "id": row.id, "value": row.sliderValue])
    tableView.reloadRows(at: [indexPath], with: .none)
    UIAccessibility.post(notification: .layoutChanged, argument: tableView.cellForRow(at: indexPath))
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


  private func scrollToRow(id: String, animated: Bool) {
    guard let indexPath = indexPath(forRowId: id) else { return }
    tableView.scrollToRow(at: indexPath, at: .middle, animated: animated)
  }

  private func focusRow(id: String, animated: Bool, attempt: Int = 0) {
    guard let indexPath = indexPath(forRowId: id) else { return }
    tableView.scrollToRow(at: indexPath, at: .middle, animated: animated)
    tableView.layoutIfNeeded()

    let delay: TimeInterval = animated ? 0.45 : 0.05
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      guard let self = self else { return }
      self.tableView.layoutIfNeeded()
      if self.rootView.window != nil, let cell = self.tableView.cellForRow(at: indexPath) {
        UIAccessibility.post(notification: .screenChanged, argument: cell)
      } else if attempt < 20 {
        self.focusRow(id: id, animated: false, attempt: attempt + 1)
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
