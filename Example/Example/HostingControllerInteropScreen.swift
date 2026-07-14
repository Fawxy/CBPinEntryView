import CBPinEntryView
import SwiftUI
import UIKit

struct HostingControllerInteropScreen: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PinHostingViewController {
        PinHostingViewController()
    }

    func updateUIViewController(_ uiViewController: PinHostingViewController, context: Context) {}
}

final class PinHostingViewController: UIViewController {
    private var pin = ""
    private var isError = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit interop"
        view.backgroundColor = .systemBackground

        let pinBinding = Binding(
            get: { [weak self] in self?.pin ?? "" },
            set: { [weak self] in self?.pin = $0 }
        )
        let errorBinding = Binding(
            get: { [weak self] in self?.isError ?? false },
            set: { [weak self] in self?.isError = $0 }
        )

        let pinView = PinEntryView(pin: pinBinding, length: 4, isError: errorBinding) { pin in
            print("Completed from UIKit host: \(pin)")
        }

        let hosting = UIHostingController(rootView: pinView)
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            hosting.view.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            hosting.view.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            hosting.view.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24)
        ])
        hosting.didMove(toParent: self)
    }
}
