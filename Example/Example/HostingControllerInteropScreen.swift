import CBPinEntryView
import SwiftUI
import UIKit

struct HostingControllerInteropScreen: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PinHostingViewController {
        PinHostingViewController()
    }

    func updateUIViewController(_ uiViewController: PinHostingViewController, context: Context) {}
}

@Observable
final class PinHostingModel {
    var pin = ""
    var isError = false
}

final class PinHostingViewController: UIViewController {
    private let model = PinHostingModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit interop"
        view.backgroundColor = .systemBackground

        let pinBinding = Binding(
            get: { [model] in model.pin },
            set: { [model] in model.pin = $0 }
        )
        let errorBinding = Binding(
            get: { [model] in model.isError },
            set: { [model] in model.isError = $0 }
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
