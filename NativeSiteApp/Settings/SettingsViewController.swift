import UIKit
import WebKit

final class SettingsViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case sites
        case behavior
        case data
        case links
        case about
    }

    private enum SitesRow: Int, CaseIterable {
        case manageSites
    }

    private enum BehaviorRow: Int, CaseIterable {
        case configuredSiteWindows
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
        title = AppLocalization.text("settings.title", "Settings")
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: AppLocalization.text("settings.done", "Done"), style: .done, target: self, action: #selector(done))

        tableView.keyboardDismissMode = .interactive
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 76
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .sites: return AppLocalization.text("settings.section.sites", "Sites")
        case .behavior: return AppLocalization.text("settings.section.behavior", "Behavior")
        case .data: return AppLocalization.text("settings.section.data", "Data")
        case .links: return AppLocalization.text("settings.section.links", "Deep Links")
        case .about: return AppLocalization.text("settings.section.about", "About")
        case .none: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .sites:
            return AppLocalization.text("settings.footer.sites", "Add multiple website profiles. Each profile has its own home URL and allowed domains. On iPad, configured sites can open in their own app window.")
        case .behavior:
            return AppLocalization.text("settings.footer.behavior", "External website links open in a native Safari view inside this app when enabled. Configured website links can open as separate iPad windows.")
        case .links:
            return AppLocalization.text("settings.footer.links", "The custom URL scheme works for any configured site. Universal Links require control of the website domain and Apple Associated Domains.")
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .sites: return SitesRow.allCases.count
        case .behavior: return BehaviorRow.allCases.count
        case .data: return DataRow.allCases.count
        case .links: return LinksRow.allCases.count
        case .about: return 1
        case .none: return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .sites:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            configureSites(cell, row: SitesRow(rawValue: indexPath.row))
            return cell
        case .behavior:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            configureBehavior(cell, row: BehaviorRow(rawValue: indexPath.row))
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
            cell.textLabel?.text = AppLocalization.text("settings.about.title", "Native Site App")
            cell.detailTextLabel?.text = AppLocalization.text("settings.about.detail", "Native UIKit multi-site browser with WKWebView windows")
            cell.selectionStyle = .none
            return cell
        case .none:
            return UITableViewCell()
        }
    }

    private func configureSites(_ cell: UITableViewCell, row: SitesRow?) {
        cell.accessoryType = .disclosureIndicator
        switch row {
        case .manageSites:
            let settings = settingsStore.settings
            let defaultSite = settings.defaultSite
            cell.textLabel?.text = AppLocalization.text("settings.sites.manage", "Manage Sites")
            cell.detailTextLabel?.text = "\(settings.siteProfiles.count) site(s) • Default: \(defaultSite.name)"
        case .none:
            break
        }
    }

    private func configureBehavior(_ cell: UITableViewCell, row: BehaviorRow?) {
        cell.selectionStyle = .none
        cell.accessoryType = .none

        switch row {
        case .configuredSiteWindows:
            cell.textLabel?.text = AppLocalization.text("settings.behavior.site_windows", "Open configured sites in new windows")
            cell.detailTextLabel?.text = AppLocalization.text("settings.behavior.site_windows_detail", "On iPad, links to another configured site open in that site's own app window.")
            cell.accessoryView = makeSwitch(isOn: settingsStore.settings.openConfiguredSitesInNewWindows, action: #selector(toggleConfiguredSiteWindows(_:)))

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
            cell.detailTextLabel?.text = deepLinkExampleText()

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
        case .sites:
            handleSites(row: SitesRow(rawValue: indexPath.row))
        case .data:
            handleData(row: DataRow(rawValue: indexPath.row))
        case .links:
            handleLinks(row: LinksRow(rawValue: indexPath.row))
        default:
            break
        }
    }

    private func handleSites(row: SitesRow?) {
        switch row {
        case .manageSites:
            let controller = SiteProfilesViewController(settingsStore: settingsStore)
            navigationController?.pushViewController(controller, animated: true)
        case .none:
            break
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
            text = deepLinkExampleText()
        case .universalLinksNote:
            text = AppLocalization.text("settings.links.universal_links_note", "Universal Links need apple-app-site-association on the website domain.")
        case .none:
            return
        }

        UIPasteboard.general.string = text
        showMessage(AppLocalization.text("common.copied", "Copied"), message: text)
    }

    private func deepLinkExampleText() -> String {
        let site = settingsStore.settings.defaultSite
        return DeepLinkParser.exampleURL(for: site.homeURL, siteID: site.id, prefersNewWindow: true)?.absoluteString
            ?? "nativeweb://open?url=\(site.homeURL.absoluteString)"
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

    @objc private func toggleConfiguredSiteWindows(_ sender: UISwitch) {
        settingsStore.update { $0.openConfiguredSitesInNewWindows = sender.isOn }
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
