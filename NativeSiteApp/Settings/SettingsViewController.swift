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
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .done, target: self, action: #selector(done))
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
        switch Section(rawValue: indexPath.section) {
        case .website:
            return websiteCell(for: indexPath)
        case .behavior:
            return behaviorCell(for: indexPath)
        case .data:
            return dataCell(for: indexPath)
        case .links:
            return linksCell(for: indexPath)
        case .about:
            var content = UIListContentConfiguration.valueCell()
            content.text = "Native Site App"
            content.secondaryText = "UIKit + WKWebView"
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.contentConfiguration = content
            cell.selectionStyle = .none
            return cell
        case .none:
            return UITableViewCell()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Section(rawValue: indexPath.section) {
        case .website:
            handleWebsiteSelection(indexPath)
        case .data:
            handleDataSelection(indexPath)
        case .links:
            handleLinksSelection(indexPath)
        default:
            break
        }
    }

    private func websiteCell(for indexPath: IndexPath) -> UITableViewCell {
        let row = WebsiteRow(rawValue: indexPath.row)
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        var content = UIListContentConfiguration.valueCell()
        cell.accessoryType = .disclosureIndicator

        switch row {
        case .homeURL:
            content.text = "Home Page"
            content.secondaryText = settingsStore.settings.homeURLString
        case .allowedDomains:
            content.text = "Allowed Domains"
            content.secondaryText = "\(settingsStore.settings.allowedDomains.count)"
        case .none:
            break
        }
        cell.contentConfiguration = content
        return cell
    }

    private func behaviorCell(for indexPath: IndexPath) -> UITableViewCell {
        let row = BehaviorRow(rawValue: indexPath.row)
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = UIListContentConfiguration.cell()
        let toggle = UISwitch()

        switch row {
        case .externalLinks:
            content.text = "External Links in Safari View"
            toggle.isOn = settingsStore.settings.openExternalLinksInSafariView
            toggle.addTarget(self, action: #selector(externalLinksChanged(_:)), for: .valueChanged)
        case .toolbarAutoHide:
            content.text = "Hide Toolbar on Scroll"
            toggle.isOn = settingsStore.settings.hideToolbarOnScroll
            toggle.addTarget(self, action: #selector(toolbarAutoHideChanged(_:)), for: .valueChanged)
        case .desktopMode:
            content.text = "Request Desktop Site"
            toggle.isOn = settingsStore.settings.preferDesktopUserAgent
            toggle.addTarget(self, action: #selector(desktopModeChanged(_:)), for: .valueChanged)
        case .none:
            break
        }

        cell.contentConfiguration = content
        cell.accessoryView = toggle
        cell.selectionStyle = .none
        return cell
    }

    private func dataCell(for indexPath: IndexPath) -> UITableViewCell {
        let row = DataRow(rawValue: indexPath.row)
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = UIListContentConfiguration.cell()

        switch row {
        case .clearHistory:
            content.text = "Clear History"
            content.textProperties.color = .systemRed
        case .clearWebsiteData:
            content.text = "Clear Website Data"
            content.textProperties.color = .systemRed
        case .resetSettings:
            content.text = "Reset Settings"
            content.textProperties.color = .systemRed
        case .none:
            break
        }

        cell.contentConfiguration = content
        return cell
    }

    private func linksCell(for indexPath: IndexPath) -> UITableViewCell {
        let row = LinksRow(rawValue: indexPath.row)
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var content = UIListContentConfiguration.subtitleCell()
        cell.accessoryType = .disclosureIndicator

        switch row {
        case .customSchemeExample:
            content.text = "Copy Custom URL Scheme Example"
            content.secondaryText = DeepLinkParser.exampleURL(for: settingsStore.settings.homeURL)?.absoluteString
        case .universalLinksNote:
            content.text = "Universal Links Setup Note"
            content.secondaryText = "Requires Associated Domains and apple-app-site-association on the website."
        case .none:
            break
        }

        content.secondaryTextProperties.numberOfLines = 2
        cell.contentConfiguration = content
        return cell
    }

    private func handleWebsiteSelection(_ indexPath: IndexPath) {
        switch WebsiteRow(rawValue: indexPath.row) {
        case .homeURL:
            let alert = AlertFactory.textInput(
                title: "Home Page",
                message: "Enter the default URL loaded by the app.",
                currentText: settingsStore.settings.homeURLString,
                placeholder: "https://alhatorah.org/"
            ) { [weak self] text in
                guard let self, let url = URL(string: text), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return }
                self.settingsStore.update { $0.homeURLString = url.absoluteString }
                self.tableView.reloadData()
            }
            present(alert, animated: true)

        case .allowedDomains:
            let text = settingsStore.settings.allowedDomains.joined(separator: "\n")
            let editor = TextListEditorViewController(
                title: "Allowed Domains",
                text: text,
                helpText: "One domain or full URL per line. Use alhatorah.org to include all subdomains such as shas.alhatorah.org."
            ) { [weak self] rawText in
                let domains = DomainNormalizer.normalizeList(rawText)
                self?.settingsStore.update { $0.allowedDomains = domains.isEmpty ? AppSettings.defaults.allowedDomains : domains }
                self?.tableView.reloadData()
            }
            let navigation = UINavigationController(rootViewController: editor)
            present(navigation, animated: true)

        case .none:
            break
        }
    }

    private func handleDataSelection(_ indexPath: IndexPath) {
        switch DataRow(rawValue: indexPath.row) {
        case .clearHistory:
            let alert = AlertFactory.confirm(title: "Clear History?", message: nil, actionTitle: "Clear") { [weak self] in
                self?.historyStore.clear()
            }
            present(alert, animated: true)

        case .clearWebsiteData:
            let alert = AlertFactory.confirm(title: "Clear Website Data?", message: "This clears cookies, cache, local storage and other WKWebView website data.", actionTitle: "Clear") {
                let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
                WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: .distantPast) {}
            }
            present(alert, animated: true)

        case .resetSettings:
            let alert = AlertFactory.confirm(title: "Reset Settings?", message: nil, actionTitle: "Reset") { [weak self] in
                self?.settingsStore.reset()
                self?.tableView.reloadData()
            }
            present(alert, animated: true)

        case .none:
            break
        }
    }

    private func handleLinksSelection(_ indexPath: IndexPath) {
        switch LinksRow(rawValue: indexPath.row) {
        case .customSchemeExample:
            let example = DeepLinkParser.exampleURL(for: settingsStore.settings.homeURL)?.absoluteString ?? "nativeweb://open?url=https://alhatorah.org/"
            UIPasteboard.general.string = example
            let alert = UIAlertController(title: "Copied", message: example, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)

        case .universalLinksNote:
            let alert = UIAlertController(
                title: "Universal Links",
                message: "To open normal https links directly in this app, the website must host an apple-app-site-association file and the Xcode project must enable Associated Domains for that exact domain.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)

        case .none:
            break
        }
    }

    @objc private func externalLinksChanged(_ sender: UISwitch) {
        settingsStore.update { $0.openExternalLinksInSafariView = sender.isOn }
    }

    @objc private func toolbarAutoHideChanged(_ sender: UISwitch) {
        settingsStore.update { $0.hideToolbarOnScroll = sender.isOn }
    }

    @objc private func desktopModeChanged(_ sender: UISwitch) {
        settingsStore.update { $0.preferDesktopUserAgent = sender.isOn }
    }

    @objc private func done() {
        dismiss(animated: true)
    }
}
