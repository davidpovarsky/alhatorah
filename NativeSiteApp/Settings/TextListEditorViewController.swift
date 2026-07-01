import UIKit

final class TextListEditorViewController: UIViewController {
    private let textView = UITextView()
    private let footerLabel = UILabel()
    private let initialText: String
    private let helpText: String
    private let onSave: (String) -> Void

    init(title: String, text: String, helpText: String, onSave: @escaping (String) -> Void) {
        self.initialText = text
        self.helpText = helpText
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.keyboardType = .URL
        textView.text = initialText

        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        footerLabel.textColor = .secondaryLabel
        footerLabel.numberOfLines = 0
        footerLabel.text = helpText

        view.addSubview(textView)
        view.addSubview(footerLabel)

        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),

            footerLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            footerLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor),
            footerLabel.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 12),
            footerLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }

    @objc private func save() {
        onSave(textView.text)
        dismiss(animated: true)
    }
}
