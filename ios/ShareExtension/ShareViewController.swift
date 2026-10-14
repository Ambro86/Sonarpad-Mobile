import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
  private let status = UILabel()
  private let done = UIButton(type: .system)
  private var started = false

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    status.numberOfLines = 0
    status.font = .preferredFont(forTextStyle: .body)
    status.adjustsFontForContentSizeCategory = true
    status.text = NSLocalizedString("Importing", comment: "Video import progress")
    done.setTitle(NSLocalizedString("Done", comment: "Close share sheet"), for: .normal)
    done.titleLabel?.font = .preferredFont(forTextStyle: .headline)
    done.titleLabel?.adjustsFontForContentSizeCategory = true
    done.isHidden = true
    done.addTarget(self, action: #selector(finish), for: .touchUpInside)
    let stack = UIStackView(arrangedSubviews: [status, done])
    stack.axis = .vertical
    stack.spacing = 24
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
      stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32)
    ])
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !started else { return }
    started = true
    let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
      .flatMap { $0.attachments ?? [] }
      .filter { $0.hasItemConformingToTypeIdentifier(UTType.movie.identifier) }
    guard providers.count == 1, let provider = providers.first else {
      showResult(success: false)
      return
    }
    // File representations avoid loading the whole video into extension memory.
    provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
      guard let url = url, error == nil else { self?.showResult(success: false); return }
      do {
        try SharedVideoInbox.store(url, suggestedName: provider.suggestedName)
        self?.showResult(success: true)
      } catch {
        NSLog("Sonarpad share import failed: %@", error.localizedDescription)
        self?.showResult(success: false)
      }
    }
  }

  private func showResult(success: Bool) {
    DispatchQueue.main.async {
      self.status.text = NSLocalizedString(success ? "Saved" : "Failed", comment: "Share result")
      self.done.isHidden = false
      UIAccessibility.post(notification: .screenChanged, argument: self.status)
    }
  }

  @objc private func finish() {
    extensionContext?.completeRequest(returningItems: nil)
  }
}
