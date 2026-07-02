import UIKit

protocol TabsViewControllerDelegate: AnyObject {
    func tabsViewControllerDidRequestNewTab(_ controller: TabsViewController)
    func tabsViewController(_ controller: TabsViewController, didSelect tab: BrowserTab)
}

final class TabsViewController: UIViewController {
    weak var delegate: TabsViewControllerDelegate?

    private let tabStore: TabStore
    private let settings: AppSettings
    private let collectionView: UICollectionView

    init(tabStore: TabStore, settings: AppSettings) {
        self.tabStore = tabStore
        self.settings = settings

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.sectionInset = UIEdgeInsets(top: 18, left: 18, bottom: 24, right: 18)
        layout.minimumLineSpacing = 18
        layout.minimumInteritemSpacing = 14

        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(nibName: nil, bundle: nil)
        self.tabStore.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Tabs"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done)),
            UIBarButtonItem(title: "Close All", style: .plain, target: self, action: #selector(closeAll))
        ]
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(newTab))

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.alwaysBounceVertical = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(TabPreviewCell.self, forCellWithReuseIdentifier: TabPreviewCell.reuseIdentifier)

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func done() {
        dismiss(animated: true)
    }

    @objc private func newTab() {
        delegate?.tabsViewControllerDidRequestNewTab(self)
    }

    @objc private func closeAll() {
        TabPreviewStore.deleteAll()
        tabStore.closeAllAndCreateHome(url: settings.homeURL)
        if let tab = tabStore.currentTab {
            delegate?.tabsViewController(self, didSelect: tab)
        }
    }

    private func closeTab(_ tab: BrowserTab) {
        let wasCurrent = tab.id == tabStore.currentTabID
        TabPreviewStore.delete(for: tab.id)
        tabStore.deleteTab(id: tab.id, fallbackURL: settings.homeURL)

        if wasCurrent, let current = tabStore.currentTab {
            delegate?.tabsViewController(self, didSelect: current)
        } else {
            collectionView.reloadData()
        }
    }
}

extension TabsViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        tabStore.tabs.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let tab = tabStore.tabs[indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TabPreviewCell.reuseIdentifier, for: indexPath) as! TabPreviewCell

        cell.configure(
            tab: tab,
            preview: TabPreviewStore.image(for: tab.id),
            isSelected: tab.id == tabStore.currentTabID
        ) { [weak self] in
            self?.closeTab(tab)
        }

        return cell
    }
}

extension TabsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.tabsViewController(self, didSelect: tabStore.tabs[indexPath.item])
    }
}

extension TabsViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let layout = collectionViewLayout as? UICollectionViewFlowLayout
        let inset = layout?.sectionInset ?? .zero
        let spacing = layout?.minimumInteritemSpacing ?? 14
        let availableWidth = collectionView.bounds.width - inset.left - inset.right

        let columns = max(1, Int(availableWidth / 260))
        let totalSpacing = CGFloat(columns - 1) * spacing
        let width = floor((availableWidth - totalSpacing) / CGFloat(columns))
        let height = max(220, min(290, width * 1.08))

        return CGSize(width: width, height: height)
    }
}

extension TabsViewController: TabStoreDelegate {
    func tabStoreDidChange(_ store: TabStore) {
        collectionView.reloadData()
    }
}

final class TabPreviewCell: UICollectionViewCell {
    static let reuseIdentifier = "TabPreviewCell"

    private let cardView = UIView()
    private let previewContainer = UIView()
    private let imageView = UIImageView()
    private let placeholderStack = UIStackView()
    private let placeholderIcon = UIImageView()
    private let placeholderLabel = UILabel()
    private let titleLabel = UILabel()
    private let urlLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    private var onClose: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        onClose = nil
    }

    func configure(tab: BrowserTab, preview: UIImage?, isSelected: Bool, onClose: @escaping () -> Void) {
        titleLabel.text = tab.title.isEmpty ? "Untitled" : tab.title
        urlLabel.text = tab.urlString
        imageView.image = preview
        imageView.isHidden = preview == nil
        placeholderStack.isHidden = preview != nil
        self.onClose = onClose

        let borderColor = isSelected ? tintColor.cgColor : UIColor.separator.cgColor
        cardView.layer.borderColor = borderColor
        cardView.layer.borderWidth = isSelected ? 2 : 1
    }

    private func configureLayout() {
        contentView.backgroundColor = .clear

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .secondarySystemGroupedBackground
        cardView.layer.cornerRadius = 18
        cardView.layer.cornerCurve = .continuous
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.12
        cardView.layer.shadowRadius = 12
        cardView.layer.shadowOffset = CGSize(width: 0, height: 5)
        cardView.clipsToBounds = false

        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.backgroundColor = .systemBackground
        previewContainer.layer.cornerRadius = 14
        previewContainer.layer.cornerCurve = .continuous
        previewContainer.layer.masksToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        placeholderIcon.translatesAutoresizingMaskIntoConstraints = false
        placeholderIcon.image = UIImage(systemName: "globe")
        placeholderIcon.tintColor = .tertiaryLabel
        placeholderIcon.contentMode = .scaleAspectFit

        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.text = "No Preview Yet"
        placeholderLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        placeholderLabel.textColor = .secondaryLabel
        placeholderLabel.textAlignment = .center

        placeholderStack.translatesAutoresizingMaskIntoConstraints = false
        placeholderStack.axis = .vertical
        placeholderStack.alignment = .center
        placeholderStack.spacing = 8
        placeholderStack.addArrangedSubview(placeholderIcon)
        placeholderStack.addArrangedSubview(placeholderLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontForContentSizeCategory = true

        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        urlLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        urlLabel.textColor = .secondaryLabel
        urlLabel.numberOfLines = 1
        urlLabel.adjustsFontForContentSizeCategory = true

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.backgroundColor = .systemBackground
        closeButton.layer.cornerRadius = 14
        closeButton.layer.cornerCurve = .continuous
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        contentView.addSubview(cardView)
        cardView.addSubview(previewContainer)
        previewContainer.addSubview(imageView)
        previewContainer.addSubview(placeholderStack)
        cardView.addSubview(titleLabel)
        cardView.addSubview(urlLabel)
        cardView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            previewContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 10),
            previewContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
            previewContainer.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
            previewContainer.heightAnchor.constraint(equalTo: cardView.heightAnchor, multiplier: 0.64),

            imageView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),

            placeholderStack.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            placeholderStack.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),
            placeholderIcon.widthAnchor.constraint(equalToConstant: 34),
            placeholderIcon.heightAnchor.constraint(equalToConstant: 34),

            closeButton.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -8),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: 10),

            urlLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            urlLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            urlLabel.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -12)
        ])
    }

    @objc private func closeTapped() {
        onClose?()
    }
}

enum TabPreviewStore {
    private static var directoryURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("tab_previews", isDirectory: true)
    }

    private static func fileURL(for id: UUID) -> URL {
        directoryURL.appendingPathComponent(id.uuidString).appendingPathExtension("jpg")
    }

    static func image(for id: UUID) -> UIImage? {
        UIImage(contentsOfFile: fileURL(for: id).path)
    }

    static func save(image: UIImage, for id: UUID) {
        let resized = image.resizedForTabPreview(maxWidth: 700)
        guard let data = resized.jpegData(compressionQuality: 0.72) else { return }

        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try? data.write(to: fileURL(for: id), options: .atomic)
    }

    static func delete(for id: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

private extension UIImage {
    func resizedForTabPreview(maxWidth: CGFloat) -> UIImage {
        guard size.width > maxWidth else { return self }

        let scale = maxWidth / size.width
        let targetSize = CGSize(width: maxWidth, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}