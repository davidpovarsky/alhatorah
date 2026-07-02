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
        case shareDiagnosticLog
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
        title = AppLocalization.text("settings.title", "Settings")
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: AppLocalization.text("settings.done", "Done"), style: .done, target: self, action: #selector(done))

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
        case .website: return AppLocalization.text("settings.section.website", "Website")
        case .behavior: return AppLocalization.text("settings.section.behavior", "Behavior")
        case .spotlight: return AppLocalization.text("settings.section.spotlight", "Spotlight")
        case .data: return AppLocalization.text("settings.section.data", "Data")
        case .links: return AppLocalization.text("settings.section.links", "Deep Links")
        case .about: return AppLocalization.text("settings.section.about", "About")
        case .none: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .website:
            return AppLocalization.text("settings.footer.website", "Edit the app home page and allowed domains directly here. One domain per line. A root domain such as alhatorah.org includes subdomains such as shas.alhatorah.org.")
        case .behavior:
            return AppLocalization.text("settings.footer.behavior", "External website links open in a native Safari view inside this app when enabled.")
        case .spotlight:
            return AppLocalization.text("settings.footer.spotlight", "Downloads ref.php at most once a week, builds the book index locally, and updates iOS Spotlight in the background.")
        case .links:
            return AppLocalization.text("settings.footer.links", "Universal Links require control of the website domain and Apple Associated Domains. The custom URL scheme works immediately.")
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
            cell.textLabel?.text = AppLocalization.text("settings.about.title", "AlHaTorah")
            cell.detailTextLabel?.text = AppLocalization.text("settings.about.detail", "Native UIKit browser for alhatorah.org")
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
                title: AppLocalization.text("settings.website.home_url", "Home URL"),
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
                title: AppLocalization.text("settings.website.allowed_domains", "Allowed Domains"),
                text: settingsStore.settings.allowedDomains.joined(separator: "\n"),
                helpText: AppLocalization.text("settings.website.allowed_domains_help", "One domain or URL per line."),
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
            cell.textLabel?.text = AppLocalization.text("settings.behavior.external_links", "External links in Safari view")
            cell.detailTextLabel?.text = AppLocalization.text("settings.behavior.external_links_detail", "Open outside domains in an in-app Safari sheet.")
            cell.accessoryView = makeSwitch(isOn: settingsStore.settings.openExternalLinksInSafariView, action: #selector(toggleExternalLinks(_:)))

        case .toolbarAutoHide:
            cell.textLabel?.text = AppLocalization.text("settings.behavior.toolbar_auto_hide", "Hide toolbar on scroll")
            cell.detailTextLabel?.text = AppLocalization.text("settings.behavior.toolbar_auto_hide_detail", "Toolbar hides while scrolling down.")
            cell.accessoryView = makeSwitch(isOn: settingsStore.settings.hideToolbarOnScroll, action: #selector(toggleToolbarAutoHide(_:)))

        case .desktopMode:
            cell.textLabel?.text = AppLocalization.text("settings.behavior.desktop_mode", "Desktop site mode")
            cell.detailTextLabel?.text = AppLocalization.text("settings.behavior.desktop_mode_detail", "Request a desktop Safari user agent.")
            cell.accessoryView = makeSwitch(isOn: settingsStore.settings.preferDesktopUserAgent, action: #selector(toggleDesktopMode(_:)))

        case .none:
            break
        }
    }

    private func configureSpotlight(_ cell: UITableViewCell, row: SpotlightRow?) {
        cell.accessoryType = .disclosureIndicator

        switch row {
        case .updateIndex:
            cell.textLabel?.text = AppLocalization.text("settings.spotlight.update_index", "Update Spotlight Index")
            cell.detailTextLabel?.text = AppLocalization.text("settings.spotlight.update_index_detail", "Download ref.php if needed, rebuild the book index, and index books.")

        case .deleteIndex:
            cell.textLabel?.text = AppLocalization.text("settings.spotlight.delete_index", "Delete Spotlight Index")
            cell.detailTextLabel?.text = AppLocalization.text("settings.spotlight.delete_index_detail", "Remove AlHaTorah books from iOS Spotlight.")

        case .shareDiagnosticLog:
            cell.textLabel?.text = AppLocalization.text("settings.spotlight.share_log", "Share Diagnostic Log")
            cell.detailTextLabel?.text = AppLocalization.text("settings.spotlight.share_log_detail", "Export the app log file for debugging.")

        case .none:
            break
        }
    }

    private func handleSpotlight(row: SpotlightRow?) {
        switch row {
        case .updateIndex:
            runSpotlightRefresh(force: false)
        case .deleteIndex:
            deleteSpotlightIndex()
        case .shareDiagnosticLog:
            shareDiagnosticLog()
        case .none:
            break
        }
    }

    private func runSpotlightRefresh(force: Bool) {
        AppLogger.shared.log("Manual Spotlight refresh requested; force=\(force)")
        let progress = UIAlertController(
            title: AppLocalization.text("settings.spotlight.progress_title", "Spotlight"),
            message: AppLocalization.text("settings.spotlight.progress_message", "Updating the AlHaTorah book index. The first build can take a few minutes. You can dismiss this and export the diagnostic log from Settings."),
            preferredStyle: .alert
        )
        progress.addAction(UIAlertAction(title: AppLocalization.text("settings.spotlight.keep_running", "Keep Running"), style: .cancel) { _ in
            AppLogger.shared.log("Spotlight progress dialog dismissed; refresh continues")
        })
        present(progress, animated: true)

        SpotlightIndexManager.shared.refreshIfNeeded(force: force) { [weak self] result in
            DispatchQueue.main.async {
                let finish = {
                    switch result {
                    case .success(let summary):
                        AppLogger.shared.log("Manual Spotlight refresh succeeded; items=\(summary.itemCount), indexed=\(summary.indexedCount), skipped=\(summary.skipped), source=\(summary.source.rawValue)")
                        let title = self?.spotlightResultTitle(for: summary) ?? AppLocalization.text("settings.spotlight.updated", "Spotlight updated")
                        let message = self?.spotlightResultMessage(for: summary)
                        self?.showMessage(title, message: message)
                    case .failure(let error):
                        AppLogger.shared.log("Manual Spotlight refresh failed: \(error.localizedDescription)")
                        self?.showMessage(AppLocalization.text("settings.spotlight.failed", "Spotlight update failed"), message: error.localizedDescription)
                    }
                }

                if progress.presentingViewController != nil {
                    progress.dismiss(animated: true, completion: finish)
                } else {
                    finish()
                }
            }
        }
    }

    private func spotlightResultTitle(for summary: SpotlightRefreshSummary) -> String {
        if summary.signature == "in-progress" {
            return AppLocalization.text("settings.spotlight.in_progress", "Spotlight indexing is already in progress")
        }
        return summary.skipped
            ? AppLocalization.text("settings.spotlight.already_updated", "Spotlight already updated")
            : AppLocalization.text("settings.spotlight.updated", "Spotlight updated")
    }

    private func spotlightResultMessage(for summary: SpotlightRefreshSummary) -> String {
        if summary.signature == "in-progress" {
            return AppLocalization.text("settings.spotlight.in_progress_message", "Another indexing run is already working. Please wait for it to finish.")
        }
        let template = AppLocalization.text("settings.spotlight.result_message", "Books: %@\nIndexed now: %@\nSource: %@")
        return String(format: template, "\(summary.itemCount)", "\(summary.indexedCount)", summary.source.rawValue)
    }
    private func deleteSpotlightIndex() {
        confirm(title: AppLocalization.text("settings.spotlight.delete_index", "Delete Spotlight Index"), message: AppLocalization.text("settings.spotlight.delete_confirm", "Remove AlHaTorah books from iOS Spotlight?"), actionTitle: AppLocalization.text("common.delete", "Delete")) { [weak self] in
            AppLogger.shared.log("Manual Spotlight delete requested")
            SpotlightIndexManager.shared.deleteAllSpotlightItems { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        AppLogger.shared.log("Manual Spotlight delete succeeded")
                        self?.showMessage(AppLocalization.text("settings.spotlight.deleted", "Spotlight index deleted"))
                    case .failure(let error):
                        AppLogger.shared.log("Manual Spotlight delete failed: \(error.localizedDescription)")
                        self?.showMessage(AppLocalization.text("settings.spotlight.delete_failed", "Could not delete Spotlight index"), message: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func shareDiagnosticLog() {
        AppLogger.shared.log("Sharing diagnostic log from Settings")
        let url = AppLogger.shared.logFileURL
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = view
        controller.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        present(controller, animated: true)
    }
    private func configureData(_ cell: UITableViewCell, row: DataRow?) {
        cell.accessoryType = .disclosureIndicator

        switch row {
        case .clearHistory:
            cell.textLabel?.text = AppLocalization.text("settings.data.clear_history", "Clear History")
            cell.detailTextLabel?.text = AppLocalization.text("settings.data.clear_history_detail", "Remove saved browsing history.")

        case .clearWebsiteData:
            cell.textLabel?.text = AppLocalization.text("settings.data.clear_website_data", "Clear Website Data")
            cell.detailTextLabel?.text = AppLocalization.text("settings.data.clear_website_data_detail", "Remove cookies, cache and website storage.")

        case .resetSettings:
            cell.textLabel?.text = AppLocalization.text("settings.data.reset_settings", "Reset Settings")
            cell.detailTextLabel?.text = AppLocalization.text("settings.data.reset_settings_detail", "Restore the default app settings.")

        case .none:
            break
        }
    }

    private func configureLinks(_ cell: UITableViewCell, row: LinksRow?) {
        cell.accessoryType = .disclosureIndicator

        switch row {
        case .customSchemeExample:
            cell.textLabel?.text = AppLocalization.text("settings.links.custom_scheme", "Custom URL Scheme")
            cell.detailTextLabel?.text = "nativeweb://open?url=https://alhatorah.org/"

        case .universalLinksNote:
            cell.textLabel?.text = AppLocalization.text("settings.links.universal_links", "Universal Links")
            cell.detailTextLabel?.text = AppLocalization.text("settings.links.universal_links_detail", "Requires Associated Domains on the website.")

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
            confirm(title: AppLocalization.text("settings.data.clear_history", "Clear History"), message: AppLocalization.text("settings.data.clear_history_confirm", "Delete all saved history items?"), actionTitle: AppLocalization.text("common.clear", "Clear")) { [weak self] in
                self?.historyStore.clear()
                self?.showMessage(AppLocalization.text("settings.data.history_cleared", "History cleared"))
            }

        case .clearWebsiteData:
            confirm(title: AppLocalization.text("settings.data.clear_website_data", "Clear Website Data"), message: AppLocalization.text("settings.data.clear_website_confirm", "Delete cookies, cache and website storage?"), actionTitle: AppLocalization.text("common.clear", "Clear")) { [weak self] in
                let store = WKWebsiteDataStore.default()
                store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {
                    DispatchQueue.main.async {
                        self?.showMessage(AppLocalization.text("settings.data.website_data_cleared", "Website data cleared"))
                    }
                }
            }

        case .resetSettings:
            confirm(title: AppLocalization.text("settings.data.reset_settings", "Reset Settings"), message: AppLocalization.text("settings.data.reset_confirm", "Restore default settings?"), actionTitle: AppLocalization.text("common.reset", "Reset")) { [weak self] in
                self?.settingsStore.reset()
                self?.tableView.reloadData()
                self?.showMessage(AppLocalization.text("settings.data.settings_reset", "Settings reset"))
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
            text = AppLocalization.text("settings.links.universal_links_note", "Universal Links need apple-app-site-association on the website domain.")
        case .none:
            return
        }

        UIPasteboard.general.string = text
        showMessage(AppLocalization.text("common.copied", "Copied"), message: text)
    }

    private func makeSwitch(isOn: Bool, action: Selector) -> UISwitch {
        let control = UISwitch()
        control.isOn = isOn
        control.addTarget(self, action: action, for: .valueChanged)
        return control
    }

    private func confirm(title: String, message: String?, actionTitle: String, onConfirm: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: AppLocalization.text("common.cancel", "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: actionTitle, style: .destructive) { _ in
            onConfirm()
        })
        present(alert, animated: true)
    }

    private func showMessage(_ title: String, message: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: AppLocalization.text("common.ok", "OK"), style: .default))
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