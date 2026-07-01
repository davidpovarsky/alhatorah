import UIKit

protocol TabsViewControllerDelegate: AnyObject {
    func tabsViewControllerDidRequestNewTab(_ controller: TabsViewController)
    func tabsViewController(_ controller: TabsViewController, didSelect tab: BrowserTab)
}

final class TabsViewController: UITableViewController {
    weak var delegate: TabsViewControllerDelegate?

    private let tabStore: TabStore
    private let settings: AppSettings
    private let reuseIdentifier = "TabCell"

    init(tabStore: TabStore, settings: AppSettings) {
        self.tabStore = tabStore
        self.settings = settings
        super.init(style: .insetGrouped)
        self.tabStore.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tabs"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .done, target: self, action: #selector(done))
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(systemItem: .add, target: self, action: #selector(newTab)),
            UIBarButtonItem(title: "Close All", style: .plain, target: self, action: #selector(closeAll))
        ]
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tabStore.tabs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        let tab = tabStore.tabs[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = tab.title
        content.secondaryText = tab.urlString
        content.image = UIImage(systemName: tab.id == tabStore.currentTabID ? "checkmark.circle.fill" : "globe")
        content.textProperties.numberOfLines = 1
        content.secondaryTextProperties.numberOfLines = 2
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.tabsViewController(self, didSelect: tabStore.tabs[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let tab = tabStore.tabs[indexPath.row]
        let close = UIContextualAction(style: .destructive, title: "Close") { [weak self] _, _, completion in
            guard let self else { return }
            self.tabStore.deleteTab(id: tab.id, fallbackURL: self.settings.homeURL)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [close])
    }

    @objc private func done() {
        dismiss(animated: true)
    }

    @objc private func newTab() {
        delegate?.tabsViewControllerDidRequestNewTab(self)
    }

    @objc private func closeAll() {
        let alert = AlertFactory.confirm(
            title: "Close All Tabs?",
            message: "This keeps one new Home tab open.",
            actionTitle: "Close All"
        ) { [weak self] in
            guard let self else { return }
            self.tabStore.closeAllAndCreateHome(url: self.settings.homeURL)
            self.tableView.reloadData()
        }
        present(alert, animated: true)
    }
}

extension TabsViewController: TabStoreDelegate {
    func tabStoreDidChange(_ store: TabStore) {
        tableView.reloadData()
    }
}
