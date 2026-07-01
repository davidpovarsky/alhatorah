import UIKit

protocol HistoryViewControllerDelegate: AnyObject {
    func historyViewController(_ controller: HistoryViewController, didSelect item: HistoryItem)
}

final class HistoryViewController: UITableViewController {
    weak var delegate: HistoryViewControllerDelegate?

    private let historyStore: HistoryStore
    private let reuseIdentifier = "HistoryCell"
    private let searchController = UISearchController(searchResultsController: nil)
    private var filteredItems: [HistoryItem] = []

    private var visibleItems: [HistoryItem] {
        searchController.isActive ? filteredItems : historyStore.items
    }

    init(historyStore: HistoryStore) {
        self.historyStore = historyStore
        super.init(style: .insetGrouped)
        self.historyStore.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "History"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .done, target: self, action: #selector(done))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearHistory))

        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "Search history"
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        visibleItems.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = visibleItems[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = item.title
        content.secondaryText = "\(item.urlString)\n\(DateFormatting.short.string(from: item.visitedAt))"
        content.image = UIImage(systemName: "clock")
        content.textProperties.numberOfLines = 1
        content.secondaryTextProperties.numberOfLines = 2
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.historyViewController(self, didSelect: visibleItems[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = visibleItems[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.historyStore.remove(id: item.id)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }

    @objc private func done() {
        dismiss(animated: true)
    }

    @objc private func clearHistory() {
        let alert = AlertFactory.confirm(title: "Clear History?", message: nil, actionTitle: "Clear") { [weak self] in
            self?.historyStore.clear()
        }
        present(alert, animated: true)
    }
}

extension HistoryViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !query.isEmpty else {
            filteredItems = historyStore.items
            tableView.reloadData()
            return
        }

        filteredItems = historyStore.items.filter { item in
            item.title.lowercased().contains(query) || item.urlString.lowercased().contains(query)
        }
        tableView.reloadData()
    }
}

extension HistoryViewController: HistoryStoreDelegate {
    func historyStoreDidChange(_ store: HistoryStore) {
        updateSearchResults(for: searchController)
        tableView.reloadData()
    }
}
