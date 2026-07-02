import UIKit
import WebKit

final class SettingsViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case website
        case behavior
        case spotlight
        case data
        case links
        case about
    }

    private enum WebsiteRow: Int, CaseIterable {
        case homeURL
        case allowedDomains
    }

    private enum BehaviorRow: Int, CaseIterable {
        case externalLinks
        case toolbarAutoHide
        case desktopMode
    }

    private enum SpotlightRow: Int, CaseIterable {
        case updateIndex
        case deleteIndex
    }

    private enum DataRow: Int, CaseIterable {
        case clearHistory
        case clearWebsiteData
        case resetSettings
    }

    private enum LinksRow: Int, CaseIterable {
        case customSchemeExample
        case universalLinksNote
    }

    private let settingsStore: SettingsStore
    private let historyStore: HistoryStore

    init(settingsStore: SettingsStore, historyStore: HistoryStore) {
        self.settingsStore = settingsStore
        self.historyStore = historyStore
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))

        tableView.keyboardDismissMode = .interactive
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 92
        tableView.register(InlineTextFieldCell.self, forCellReuseIdentifier: InlineTextFieldCell.reuseIdentifier)
        tableView.register(InlineTextViewCell.self, forCellReuseIdentifier: InlineTextViewCell.reuseIdentifier)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .website: return "Website"
        case .behavior: return "Behavior"
        case .spotlight: return "Spotlight"
        case .data: return "Data"
        case .links: return "Deep Links"
        case .about: return "About"
        case .none: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .website:
            return "Edit the app home page and allowed domains directly here. One domain per line. A root domain such as alhatorah.org includes subdomains such as shas.alhatorah.org."
        case .behavior:
            return "External website links open in a native Safari view inside this app when enabled."
        case .spotlight:
            return "Downloads ref.php at most once a week, builds the book index locally, and updates iOS Spotlight in the background."
        case .links:
            return "Universal Links require control of the website domain and Apple Associated Domains. The custom URL scheme works immediately."
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .website: return WebsiteRow.allCases.count
        case .behavior: return BehaviorRow.allCases.count
        case .spotlight: return SpotlightRow.allCases.count
        case .data: return DataRow.allCases.count
        case .links: return LinksRow.allCases.count
        case .about: return 1
        case .none: return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .website:
            return websiteCell(row: WebsiteRow(rawValue: indexPath.row), indexPath: indexPath)
        case .behavior:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            configureBehavior(cell, row: BehaviorRow(rawValue: indexPath.row))
            return cell
        case .spotlight:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            configureSpotlight(cell, row: SpotlightRow(rawValue: indexPath.row))
            return cell
        case .data:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            configureData(cell, row: DataRow(rawValue: indexPath.row))
            return cell
        case .links:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            configureLinks(cell, row: LinksRow(rawValue: indexPath.row))
            return cell
        case .about:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.textLabel?.text = "NativeSiteApp"
            cell.detailTextLabel?.text = "UIKit WebView wrapper for alhatorah.org"
            cell.selectionStyle = .none
            return cell
        case .none:
            return UITableViewCell()
        }
    }

    private func websiteCell(row: WebsiteRow?, indexPath: IndexPath) -> UITableViewCell {
        switch row {
        case .homeURL:
            let cell = tableView.dequeueReusableCell(withIdentifier: InlineTextFieldCell.reuseIdentifier, for: indexPath) as! InlineTextFieldCell
            cell.configure(
                title: "Home URL",
                text: settingsStore.settings.homeURLString,
                placeholder: "https://alhatorah.org/",
                keyboardType: .URL
            ) { [weak self] text in
                let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                self?.settingsStore.update {
                    $0.homeURLString = cleaned.isEmpty ? AppSettings.defaultHomeURLString : cleaned
                }
            }
            return cell

        case .allowedDomains:
            let cell = tableView.dequeueReusableCell(withIdentifier: InlineTextViewCell.reuseIdentifier, for: indexPath) as! InlineTextViewCell
            cell.configure(
                title: "Allowed Domains",
                text: settingsStore.settings.allowedDomains.joined(separator: "\n"),
                helpText: "One domain or URL per line.",
                minimumHeight: 92
            ) { [weak self] text in
                let domains = text
                    .split(whereSeparator: { $0.isNewline })
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                self?.settingsStore.update {
                    $0.allowedDomains = domains.isEmpty ? AppSettings.defaults.allowedDomains : domains
                }
            }
            return cell

        case .none:
            return UITableViewCell()
        }
    }

    private func configureBehavior(_ cell: UITableViewCell, row: BehaviorRow?) {
        cell.selectionStyle = .none
        cell.accessoryType = .none

        switch row {
        case .externalLinks:
            cell.textLabel?.text = "External links in Safari view"
            cell.detailTextLabel?.text = "Open outside domains in an in-app Safari sheet."
            cell.accessoryView = makeSwitch(isOn: settingsStore.settings.openExternalLinksInSafariView, action: #selector(toggleExternalLinks(_:)))

        case .toolbarAutoHide:
            cell.textLabel?.text = "Hide toolbar on scroll"
            cell.detailTextLabel?.text = "Toolbar hides while scrolling down."
            cell.accessoryView = makeSwitch(isOn: settingsStore.settings.hideToolbarOnScroll, action: #selector(toggleToolbarAutoHide(_:)))

        case .desktopMode:
            cell.textLabel?.text = "Desktop site mode"
            cell.detailTextLabel?.text = "Request a desktop Safari user agent."
            cell.accessoryView = makeSwitch(isOn: settingsStore.settings.preferDesktopUserAgent, action: #selector(toggleDesktopMode(_:)))

        case .none:
            break
        }
    }

    private func configureSpotlight(_ cell: UITableViewCell, row: SpotlightRow?) {
        cell.accessoryType = .disclosureIndicator

        switch row {
        case .updateIndex:
            cell.textLabel?.text = "Update Spotlight Index"
            cell.detailTextLabel?.text = "Download ref.php if needed, rebuild the book index, and index books."

        case .deleteIndex:
            cell.textLabel?.text = "Delete Spotlight Index"
            cell.detailTextLabel?.text = "Remove AlHaTorah books from iOS Spotlight."

        case .none:
            break
        }
    }

    private func handleSpotlight(row: SpotlightRow?) {
        switch row {
        case .updateIndex:
            runSpotlightRefresh(force: true)
        case .deleteIndex:
            deleteSpotlightIndex()
        case .none:
            break
        }
    }

    private func runSpotlightRefresh(force: Bool) {
        let progress = UIAlertController(title: "Spotlight", message: "×ž×¢×“×›×Ÿ ××ª ××™× ×“×§×¡ ×”×¡×¤×¨×™×â€¦", preferredStyle: .alert)
        present(progress, animated: true)

        SpotlightIndexManager.shared.refreshIfNeeded(force: force) { [weak self] result in
            DispatchQueue.main.async {
                progress.dismiss(animated: true) {
                    switch result {
                    case .success(let summary):
                        let title = summary.skipped ? "Spotlight already updated" : "Spotlight updated"
                        let message = "Books: \(summary.itemCount)\nIndexed now: \(summary.indexedCount)\nSource: \(summary.source.rawValue)"
                        self?.showMessage(title, message: message)
                    case .failure(let error):
                        self?.showMessage("Spotlight update failed", message: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func deleteSpotlightIndex() {
        confirm(title: "Delete Spotlight Index", message: "Remove AlHaTorah books from iOS Spotlight?", actionTitle: "Delete") { [weak self] in
            SpotlightIndexManager.shared.deleteAllSpotlightItems { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.showMessage("Spotlight index deleted")
                    case .failure(let error):
                        self?.showMessage("Could not delete Spotlight index", message: error.localizedDescription)
                    }
                }
            }
        }
    }
    private func configureData(_ cell: UITableViewCell, row: DataRow?) {
        cell.accessoryType = .disclosureIndicator

        switch row {
        case .clearHistory:
            cell.textLabel?.text = "Clear History"
            cell.detailTextLabel?.text = "Remove saved browsing history."

        case .clearWebsiteData:
            cell.textLabel?.text = "Clear Website Data"
            cell.detailTextLabel?.text = "Remove cookies, cache and website storage."

        case .resetSettings:
            cell.textLabel?.text = "Reset Settings"
            cell.detailTextLabel?.text = "Restore the default app settings."

        case .none:
            break
        }
    }

    private func configureLinks(_ cell: UITableViewCell, row: LinksRow?) {
        cell.accessoryType = .disclosureIndicator

        switch row {
        case .customSchemeExample:
            cell.textLabel?.text = "Custom URL Scheme"
            cell.detailTextLabel?.text = "nativeweb://open?url=https://alhatorah.org/"

        case .universalLinksNote:
            cell.textLabel?.text = "Universal Links"
            cell.detailTextLabel?.text = "Requires Associated Domains on the website."

        case .none:
            break
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Section(rawValue: indexPath.section) {
        case .spotlight:
            handleSpotlight(row: SpotlightRow(rawValue: indexPath.row))
        case .data:
            handleData(row: DataRow(rawValue: indexPath.row))
        case .links:
            handleLinks(row: LinksRow(rawValue: indexPath.row))
        default:
            break
        }
    }

    private func handleData(row: DataRow?) {
        switch row {
        case .clearHistory:
            confirm(title: "Clear History", message: "Delete all saved history items?", actionTitle: "Clear") { [weak self] in
                self?.historyStore.clear()
                self?.showMessage("History cleared")
            }

        case .clearWebsiteData:
            confirm(title: "Clear Website Data", message: "Delete cookies, cache and website storage?", actionTitle: "Clear") { [weak self] in
                let store = WKWebsiteDataStore.default()
                store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {
                    DispatchQueue.main.async {
                        self?.showMessage("Website data cleared")
                    }
                }
            }

        case .resetSettings:
            confirm(title: "Reset Settings", message: "Restore default settings?", actionTitle: "Reset") { [weak self] in
                self?.settingsStore.reset()
                self?.tableView.reloadData()
                self?.showMessage("Settings reset")
            }

        case .none:
            break
        }
    }

    private func handleLinks(row: LinksRow?) {
        let text: String

        switch row {
        case .customSchemeExample:
            text = "nativeweb://open?url=https://alhatorah.org/"
        case .universalLinksNote:
            text = "Universal Links need apple-app-site-association on the website domain."
        case .none:
            return
        }

        UIPasteboard.general.string = text
        showMessage("Copied", message: text)
    }

    private func makeSwitch(isOn: Bool, action: Selector) -> UISwitch {
        let control = UISwitch()
        control.isOn = isOn
        control.addTarget(self, action: action, for: .valueChanged)
        return control
    }

    private func confirm(title: String, message: String?, actionTitle: String, onConfirm: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: actionTitle, style: .destructive) { _ in
            onConfirm()
        })
        present(alert, animated: true)
    }

    private func showMessage(_ title: String, message: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func toggleExternalLinks(_ sender: UISwitch) {
        settingsStore.update { $0.openExternalLinksInSafariView = sender.isOn }
    }

    @objc private func toggleToolbarAutoHide(_ sender: UISwitch) {
        settingsStore.update { $0.hideToolbarOnScroll = sender.isOn }
    }

    @objc private func toggleDesktopMode(_ sender: UISwitch) {
        settingsStore.update { $0.preferDesktopUserAgent = sender.isOn }
    }

    @objc private func done() {
        view.endEditing(true)
        dismiss(animated: true)
    }
}

private final class InlineTextFieldCell: UITableViewCell, UITextFieldDelegate {
    static let reuseIdentifier = "InlineTextFieldCell"

    private let titleLabel = UILabel()
    private let textField = UITextField()
    private var onChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        title: String,
        text: String,
        placeholder: String,
        keyboardType: UIKeyboardType,
        onChange: @escaping (String) -> Void
    ) {
        titleLabel.text = title
        textField.text = text
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        self.onChange = onChange
    }

    private func configureLayout() {
        selectionStyle = .none
        accessoryType = .none

        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = .secondaryLabel
        titleLabel.adjustsFontForContentSizeCategory = true

        textField.borderStyle = .roundedRect
        textField.clearButtonMode = .whileEditing
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.returnKeyType = .done
        textField.delegate = self
        textField.addTarget(self, action: #selector(textFieldEditingDidEnd), for: .editingDidEnd)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        contentView.addSubview(textField)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),

            textField.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            textField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    @objc private func textFieldEditingDidEnd() {
        onChange?(textField.text ?? "")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

private final class InlineTextViewCell: UITableViewCell, UITextViewDelegate {
    static let reuseIdentifier = "InlineTextViewCell"

    private let titleLabel = UILabel()
    private let textView = UITextView()
    private let helpLabel = UILabel()
    private var heightConstraint: NSLayoutConstraint?
    private var onChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        title: String,
        text: String,
        helpText: String,
        minimumHeight: CGFloat,
        onChange: @escaping (String) -> Void
    ) {
        titleLabel.text = title
        textView.text = text
        helpLabel.text = helpText
        heightConstraint?.constant = minimumHeight
        self.onChange = onChange
    }

    private func configureLayout() {
        selectionStyle = .none
        accessoryType = .none

        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = .secondaryLabel
        titleLabel.adjustsFontForContentSizeCategory = true

        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.layer.cornerRadius = 8
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.backgroundColor = .secondarySystemGroupedBackground
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.keyboardType = .URL
        textView.isScrollEnabled = true
        textView.delegate = self

        helpLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        helpLabel.textColor = .secondaryLabel
        helpLabel.adjustsFontForContentSizeCategory = true
        helpLabel.numberOfLines = 0

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        contentView.addSubview(textView)
        contentView.addSubview(helpLabel)

        let height = textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 92)
        heightConstraint = height

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),

            textView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            height,

            helpLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            helpLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            helpLabel.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 6),
            helpLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    func textViewDidChange(_ textView: UITextView) {
        onChange?(textView.text)
    }
}