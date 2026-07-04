import UIKit

final class SiteProfilesViewController: UITableViewController {
    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = AppLocalization.text("settings.sites.title", "Sites")
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addSite))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SiteCell")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        AppLocalization.text("settings.sites.footer", "Tap a site to edit its name, home URL, and allowed domains. Links to configured domains are handled inside the app instead of being treated as ordinary external links.")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        settingsStore.settings.siteProfiles.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "SiteCell")
        let site = settingsStore.settings.siteProfiles[indexPath.row]
        cell.textLabel?.text = site.name
        cell.detailTextLabel?.text = site.homeURL.absoluteString
        cell.accessoryType = site.id == settingsStore.settings.defaultSiteID ? .checkmark : .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let site = settingsStore.settings.siteProfiles[indexPath.row]
        navigationController?.pushViewController(SiteProfileEditorViewController(settingsStore: settingsStore, siteID: site.id), animated: true)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        settingsStore.settings.siteProfiles.count > 1
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        let site = settingsStore.settings.siteProfiles[indexPath.row]
        settingsStore.update { $0.deleteSiteProfile(id: site.id) }
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }

    @objc private func addSite() {
        let suggestedURL = URL(string: "https://example.com/")!
        let newSite = SiteProfile(
            name: AppLocalization.text("settings.sites.new_site", "New Site"),
            homeURLString: suggestedURL.absoluteString,
            allowedDomains: [suggestedURL.host ?? "example.com"]
        )

        settingsStore.update { settings in
            settings.upsertSiteProfile(newSite)
        }

        navigationController?.pushViewController(SiteProfileEditorViewController(settingsStore: settingsStore, siteID: newSite.id), animated: true)
    }
}

private final class SiteProfileEditorViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case details
        case options
        case links
        case danger
    }

    private enum DetailRow: Int, CaseIterable {
        case name
        case homeURL
        case allowedDomains
    }

    private enum OptionRow: Int, CaseIterable {
        case defaultSite
    }

    private enum LinkRow: Int, CaseIterable {
        case copyDeepLink
    }

    private enum DangerRow: Int, CaseIterable {
        case delete
    }

    private let settingsStore: SettingsStore
    private let siteID: String

    init(settingsStore: SettingsStore, siteID: String) {
        self.settingsStore = settingsStore
        self.siteID = siteID
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var site: SiteProfile {
        settingsStore.settings.siteProfile(withID: siteID) ?? settingsStore.settings.defaultSite
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = site.name
        tableView.keyboardDismissMode = .interactive
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 82
        tableView.register(SiteInlineTextFieldCell.self, forCellReuseIdentifier: SiteInlineTextFieldCell.reuseIdentifier)
        tableView.register(SiteInlineTextViewCell.self, forCellReuseIdentifier: SiteInlineTextViewCell.reuseIdentifier)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .details: return AppLocalization.text("settings.sites.details", "Details")
        case .options: return AppLocalization.text("settings.sites.options", "Options")
        case .links: return AppLocalization.text("settings.section.links", "Deep Links")
        case .danger: return settingsStore.settings.siteProfiles.count > 1 ? AppLocalization.text("settings.sites.danger", "Danger") : nil
        case .none: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .details:
            return AppLocalization.text("settings.sites.details_footer", "Allowed domains can be domains or full URLs, one per line. A root domain includes its subdomains.")
        case .links:
            return AppLocalization.text("settings.sites.links_footer", "This example opens the site's home URL through the app URL scheme and requests a new iPad window when available.")
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .details: return DetailRow.allCases.count
        case .options: return OptionRow.allCases.count
        case .links: return LinkRow.allCases.count
        case .danger: return settingsStore.settings.siteProfiles.count > 1 ? DangerRow.allCases.count : 0
        case .none: return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .details:
            return detailCell(row: DetailRow(rawValue: indexPath.row), indexPath: indexPath)
        case .options:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            configureOption(cell, row: OptionRow(rawValue: indexPath.row))
            return cell
        case .links:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            configureLink(cell, row: LinkRow(rawValue: indexPath.row))
            return cell
        case .danger:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = AppLocalization.text("settings.sites.delete", "Delete Site")
            cell.textLabel?.textColor = .systemRed
            return cell
        case .none:
            return UITableViewCell()
        }
    }

    private func detailCell(row: DetailRow?, indexPath: IndexPath) -> UITableViewCell {
        switch row {
        case .name:
            let cell = tableView.dequeueReusableCell(withIdentifier: SiteInlineTextFieldCell.reuseIdentifier, for: indexPath) as! SiteInlineTextFieldCell
            cell.configure(
                title: AppLocalization.text("settings.sites.name", "Name"),
                text: site.name,
                placeholder: "My Site",
                keyboardType: .default
            ) { [weak self] text in
                self?.updateSite { $0.name = text }
                self?.title = self?.site.name
            }
            return cell

        case .homeURL:
            let cell = tableView.dequeueReusableCell(withIdentifier: SiteInlineTextFieldCell.reuseIdentifier, for: indexPath) as! SiteInlineTextFieldCell
            cell.configure(
                title: AppLocalization.text("settings.website.home_url", "Home URL"),
                text: site.homeURLString,
                placeholder: "https://example.com/",
                keyboardType: .URL
            ) { [weak self] text in
                self?.updateSite { $0.homeURLString = text }
            }
            return cell

        case .allowedDomains:
            let cell = tableView.dequeueReusableCell(withIdentifier: SiteInlineTextViewCell.reuseIdentifier, for: indexPath) as! SiteInlineTextViewCell
            cell.configure(
                title: AppLocalization.text("settings.website.allowed_domains", "Allowed Domains"),
                text: site.allowedDomains.joined(separator: "\n"),
                helpText: AppLocalization.text("settings.website.allowed_domains_help", "One domain or URL per line."),
                minimumHeight: 112
            ) { [weak self] text in
                let domains = text
                    .split(whereSeparator: { $0.isNewline })
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                self?.updateSite { $0.allowedDomains = domains }
            }
            return cell

        case .none:
            return UITableViewCell()
        }
    }

    private func configureOption(_ cell: UITableViewCell, row: OptionRow?) {
        cell.selectionStyle = .none
        switch row {
        case .defaultSite:
            cell.textLabel?.text = AppLocalization.text("settings.sites.default", "Default Site")
            cell.detailTextLabel?.text = AppLocalization.text("settings.sites.default_detail", "Used for the Home button when no site is specified.")
            let control = UISwitch()
            control.isOn = settingsStore.settings.defaultSiteID == siteID
            control.addTarget(self, action: #selector(toggleDefaultSite(_:)), for: .valueChanged)
            cell.accessoryView = control
        case .none:
            break
        }
    }

    private func configureLink(_ cell: UITableViewCell, row: LinkRow?) {
        cell.accessoryType = .disclosureIndicator
        switch row {
        case .copyDeepLink:
            cell.textLabel?.text = AppLocalization.text("settings.sites.copy_deep_link", "Copy URL Scheme Example")
            cell.detailTextLabel?.text = deepLinkText()
        case .none:
            break
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Section(rawValue: indexPath.section) {
        case .links:
            UIPasteboard.general.string = deepLinkText()
            showMessage(AppLocalization.text("common.copied", "Copied"), message: deepLinkText())
        case .danger:
            confirmDelete()
        default:
            break
        }
    }

    private func updateSite(_ mutate: (inout SiteProfile) -> Void) {
        var updated = site
        mutate(&updated)
        settingsStore.update { $0.upsertSiteProfile(updated) }
    }

    private func deepLinkText() -> String {
        DeepLinkParser.exampleURL(for: site.homeURL, siteID: site.id, prefersNewWindow: true)?.absoluteString
            ?? "nativeweb://open?url=\(site.homeURL.absoluteString)"
    }

    @objc private func toggleDefaultSite(_ sender: UISwitch) {
        if sender.isOn {
            settingsStore.update { $0.setDefaultSiteID(siteID) }
        }
        tableView.reloadData()
    }

    private func confirmDelete() {
        guard settingsStore.settings.siteProfiles.count > 1 else { return }
        let alert = UIAlertController(
            title: AppLocalization.text("settings.sites.delete", "Delete Site"),
            message: site.name,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: AppLocalization.text("common.cancel", "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: AppLocalization.text("common.delete", "Delete"), style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.settingsStore.update { $0.deleteSiteProfile(id: self.siteID) }
            self.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    private func showMessage(_ title: String, message: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: AppLocalization.text("common.ok", "OK"), style: .default))
        present(alert, animated: true)
    }
}

private final class SiteInlineTextFieldCell: UITableViewCell, UITextFieldDelegate {
    static let reuseIdentifier = "SiteInlineTextFieldCell"

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

    func configure(title: String, text: String, placeholder: String, keyboardType: UIKeyboardType, onChange: @escaping (String) -> Void) {
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

private final class SiteInlineTextViewCell: UITableViewCell, UITextViewDelegate {
    static let reuseIdentifier = "SiteInlineTextViewCell"

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

    func configure(title: String, text: String, helpText: String, minimumHeight: CGFloat, onChange: @escaping (String) -> Void) {
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
