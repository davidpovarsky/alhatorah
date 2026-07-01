import UIKit
import WebKit

final class SettingsViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case website
        case behavior
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
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .website: return "Website"
        case .behavior: return "Behavior"
        case .data: return "Data"
        case .links: return "Deep Links"
        case .about: return "About"
        case .none: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .website:
            return "Allowed domains can be root domains or full URLs. A root domain such as alhatorah.org automatically includes shas.alhatorah.org and other subdomains."
        case .behavior:
            return "External website links open in a native Safari view inside this app when enabled."
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
        case .data: return DataRow.allCases.count
        case .links: return LinksRow.allCases.count
        case .about: return 1
        case .none: return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.accessoryType = .disclosureIndicator

        switch Section(rawValue: indexPath.section) {
        case .website:
            configureWebsite(cell, row: WebsiteRow(rawValue: indexPath.row))
        case .behavior:
            configureBehavior(cell, row: BehaviorRow(rawValue: indexPath.row))
        case .data:
            configureData(cell, row: DataRow(rawValue: indexPath.row))
        case .links:
            configureLinks(cell, row: LinksRow(rawValue: indexPath.row))
        case .about:
            cell.textLabel?.text = "NativeSiteApp"
            cell.detailTextLabel?.text = "UIKit WebView wrapper for alhatorah.org"
            cell.accessoryType = .none
        case .none:
            break
        }
        return cell
    }

    private func configureWebsite(_ cell: UITableViewCell, row: WebsiteRow?) {
        switch row {
        case .homeURL:
            cell.textLabel?.text = "Home URL"
            cell.detailTextLabel?.text = settingsStore.settings.homeURLString
        case .allowedDomains:
            cell.textLabel?.text = "Allowed Domains"
            cell.detailTextLabel?.text = settingsStore.settings.allowedDomains.joined(separator: ", ")
        case .none:
            break
        }
    }

    private func configureBehavior(_ cell: UITableViewCell, row: BehaviorRow?) {
        cell.accessoryType = .none
        switch row {
        case .externalLinks:
            cell.textLabel?.text = "External links in Safari view"
            cell.accessoryView = makeSwitch(isOn: settingsStore.settings.openExternalLinksInSafariView, action: #selector(toggleExternalLinks(_:)))
        case .toolbarAutoHide:
            cell.textLabel?.text = "Hide toolbar on scroll"
            cell.accessoryView = makeSwitch(isOn: settingsStore.settings.hideToolbarOnScroll, action: #selector(toggleToolbarAutoHide(_:)))
        case .desktopMode:
            cell.textLabel?.text = "Desktop site mode"
            cell.accessoryView = makeSwitch(isOn: settingsStore.settings.preferDesktopUserAgent, action: #selector(toggleDesktopMode(_:)))
        case .none:
            break
        }
    }

    private func configureData(_ cell: UITableViewCell, row: DataRow?) {
        switch row {
        case .clearHistory:
            cell.textLabel?.text = "Clear History"
        case .clearWebsiteData:
            cell.textLabel?.text = "Clear Website Data"
        case .resetSettings:
            cell.textLabel?.text = "Reset Settings"
        case .none:
            break
        }
    }

    private func configureLinks(_ cell: UITableViewCell, row: LinksRow?) {
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
        case .website:
            handleWebsite(row: WebsiteRow(rawValue: indexPath.row))
        case .data:
            handleData(row: DataRow(rawValue: indexPath.row))
        case .links:
            handleLinks(row: LinksRow(rawValue: indexPath.row))
        default:
            break
        }
    }

    private func handleWebsite(row: WebsiteRow?) {
        switch row {
        case .homeURL:
            editText(title: "Home URL", text: settingsStore.settings.homeURLString, help: "Example: https://alhatorah.org/") { [weak self] text in
                self?.settingsStore.update { $0.homeURLString = text.trimmingCharacters(in: .whitespacesAndNewlines) }
                self?.tableView.reloadData()
            }
        case .allowedDomains:
            editText(title: "Allowed Domains", text: settingsStore.settings.allowedDomains.joined(separator: "\n"), help: "One domain or URL per line. alhatorah.org includes shas.alhatorah.org.") { [weak self] text in
                let domains = text.split(whereSeparator: { $0.isNewline }).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                self?.settingsStore.update { $0.allowedDomains = domains }
                self?.tableView.reloadData()
            }
        case .none:
            break
        }
    }

    private func handleData(row: DataRow?) {
        switch row {
        case .clearHistory:
            historyStore.clear()
            AlertFactory.showMessage("History cleared", in: self)
        case .clearWebsiteData:
            let store = WKWebsiteDataStore.default()
            store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {
                DispatchQueue.main.async { AlertFactory.showMessage("Website data cleared", in: self) }
            }
        case .resetSettings:
            settingsStore.reset()
            tableView.reloadData()
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
        AlertFactory.showMessage("Copied", message: text, in: self)
    }

    private func editText(title: String, text: String, help: String, onSave: @escaping (String) -> Void) {
        let controller = TextListEditorViewController(title: title, text: text, helpText: help, onSave: onSave)
        let navigation = UINavigationController(rootViewController: controller)
        present(navigation, animated: true)
    }

    private func makeSwitch(isOn: Bool, action: Selector) -> UISwitch {
        let control = UISwitch()
        control.isOn = isOn
        control.addTarget(self, action: action, for: .valueChanged)
        return control
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
        dismiss(animated: true)
    }
}
