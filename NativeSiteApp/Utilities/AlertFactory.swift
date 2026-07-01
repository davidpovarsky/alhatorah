import UIKit

enum AlertFactory {
    static func textInput(
        title: String,
        message: String?,
        currentText: String,
        placeholder: String,
        keyboardType: UIKeyboardType = .URL,
        onSave: @escaping (String) -> Void
    ) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = currentText
            textField.placeholder = placeholder
            textField.keyboardType = keyboardType
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            onSave(alert.textFields?.first?.text ?? "")
        })
        return alert
    }

    static func confirm(title: String, message: String?, actionTitle: String, onConfirm: @escaping () -> Void) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: actionTitle, style: .destructive) { _ in onConfirm() })
        return alert
    }
}

extension AlertFactory {
    static func showMessage(_ title: String, message: String? = nil, in viewController: UIViewController) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }
}