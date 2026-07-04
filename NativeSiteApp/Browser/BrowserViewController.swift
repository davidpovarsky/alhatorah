import UIKit
import WebKit
import SafariServices

final class BrowserMenuCoordinator {
    static weak var activeBrowser: BrowserViewController?
}

final class BrowserViewController: UIViewController {
    private let settingsStore: SettingsStore
    private let tabStore: TabStore
    private let historyStore: HistoryStore
    private let bookmarkStore = BookmarkStore()
    private var siteID: String
    private let initialURL: URL?

    private var webView: WKWebView!
    private let toolbar = UIToolbar()
    private var toolbarBottomConstraint: NSLayoutConstraint!
    private var toolbarHeightConstraint: NSLayoutConstraint!

    private var backItem: UIBarButtonItem!
    private var forwardItem: UIBarButtonItem!
    private var reloadItem: UIBarButtonItem!
    private var homeItem: UIBarButtonItem!
    private var shareItem: UIBarButtonItem!
    private var safariViewItem: UIBarButtonItem!
    private var historyItem: UIBarButtonItem!
    private var tabsItem: UIBarButtonItem!
    private var settingsItem: UIBarButtonItem!

    private var toolbarVisible = true
    private var lastScrollOffsetY: CGFloat = 0
    private var isLoadingObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?
    private var urlObservation: NSKeyValueObservation?

    init(settingsStore: SettingsStore, tabStore: TabStore, historyStore: HistoryStore, siteID: String? = nil, initialURL: URL? = nil) {
        self.settingsStore = settingsStore
        self.tabStore = tabStore
        self.historyStore = historyStore
        self.siteID = siteID ?? settingsStore.settings.defaultSiteID
        self.initialURL = initialURL
        super.init(nibName: nil, bundle: nil)
        self.settingsStore.delegate = self
        self.tabStore.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        updateSiteWindowIdentity()
        configureWebView()
        configureToolbar()
        configureGestures()
        configureObservers()
        loadInitialPage()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateSiteWindowIdentity()
        AppLogger.shared.log("BrowserViewController viewDidAppear; activating browser siteID=\(siteID) siteName=\(currentSite.name)")
        BrowserMenuCoordinator.activeBrowser = self
        becomeFirstResponder()
        rebuildMainMenu()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if BrowserMenuCoordinator.activeBrowser === self {
            AppLogger.shared.log("BrowserViewController viewDidDisappear; clearing active browser siteID=\(siteID) siteName=\(currentSite.name)")
            BrowserMenuCoordinator.activeBrowser = nil
            rebuildMainMenu()
        }
    }

    func buildNativeMainMenu(with builder: UIMenuBuilder) {
        AppLogger.shared.logSync("buildNativeMainMenu started; siteID=\(siteID); siteName=\(currentSite.name)")
        builder.remove(menu: NativeMenuIdentifier.site)
        builder.remove(menu: NativeMenuIdentifier.history)
        builder.remove(menu: NativeMenuIdentifier.bookmarks)
        builder.remove(menu: NativeMenuIdentifier.windows)
        builder.remove(menu: NativeMenuIdentifier.help)

        builder.remove(menu: .file)
        builder.remove(menu: .edit)
        builder.remove(menu: .format)
        builder.remove(menu: .view)
        builder.remove(menu: .window)
        builder.remove(menu: .help)

        let siteMenu = makeSiteMenu()
        let historyMenu = makeHistoryMenu()
        let bookmarksMenu = makeBookmarksMenu()
        let windowsMenu = makeWindowsMenu()
        let helpMenu = makeHelpMenu()

        builder.insertSibling(siteMenu, afterMenu: .application)
        builder.insertSibling(historyMenu, afterMenu: NativeMenuIdentifier.site)
        builder.insertSibling(bookmarksMenu, afterMenu: NativeMenuIdentifier.history)
        builder.insertSibling(windowsMenu, afterMenu: NativeMenuIdentifier.bookmarks)
        builder.insertSibling(helpMenu, afterMenu: NativeMenuIdentifier.windows)
        AppLogger.shared.logSync("buildNativeMainMenu inserted site/history/bookmarks/windows/help")
    }

    private var currentSite: SiteProfile {
        settingsStore.settings.siteProfile(withID: siteID) ?? settingsStore.settings.defaultSite
    }

    private var currentPageURL: URL? {
        webView?.url ?? tabStore.currentTab?.url ?? currentSite.homeURL
    }

    func openIncomingURL(_ url: URL) {
        openIncomingURL(url, preferredSiteID: nil, forceNewWindow: false, inNewTab: false)
    }

    func openIncomingURL(_ url: URL, preferredSiteID: String?, forceNewWindow: Bool) {
        openIncomingURL(url, preferredSiteID: preferredSiteID, forceNewWindow: forceNewWindow, inNewTab: false)
    }

    func openIncomingURLInNewTab(_ url: URL) {
        openIncomingURL(url, preferredSiteID: nil, forceNewWindow: false, inNewTab: true)
    }

    private func openIncomingURL(_ url: URL, preferredSiteID: String?, forceNewWindow: Bool, inNewTab: Bool) {
        let resolvedSiteID = preferredSiteID ?? settingsStore.settings.matchingSite(for: url)?.id

        if let resolvedSiteID, resolvedSiteID == siteID {
            loadInternally(url, inNewTab: inNewTab)
            return
        }

        if forceNewWindow, UIApplication.shared.supportsMultipleScenes {
            openURLInSiteWindow(url, siteID: resolvedSiteID ?? siteID)
            return
        }

        let policy = URLPolicy(settings: settingsStore.settings, currentSiteID: siteID)
        switch policy.decision(for: url) {
        case .internalWeb:
            loadInternally(url, inNewTab: inNewTab)
        case .configuredSite(let targetSiteID):
            if targetSiteID == siteID {
                loadInternally(url, inNewTab: inNewTab)
            } else {
                openURLInSiteWindow(url, siteID: resolvedSiteID ?? targetSiteID)
            }
        case .externalWeb:
            presentSafariView(for: url)
        case .systemExternal:
            openSystemURL(url)
        }
    }

    private func loadInternally(_ url: URL, inNewTab: Bool) {
        if inNewTab {
            captureCurrentTabSnapshot { [weak self] in
                guard let self else { return }
                self.tabStore.createTab(title: AppLocalization.text("tabs.new", "New Tab"), url: url, select: true)
                self.load(url)
            }
        } else {
            tabStore.updateCurrentTab(title: nil, url: url)
            load(url)
        }
    }

    private func openURLInSiteWindow(_ url: URL, siteID targetSiteID: String) {
        guard UIApplication.shared.supportsMultipleScenes else {
            loadInternally(url, inNewTab: true)
            return
        }

        let request = SceneLaunchRequest(siteID: targetSiteID, url: url, prefersNewWindow: true)
        let activity = request.makeUserActivity(settings: settingsStore.settings)
        let existingSession = SiteSceneRegistry.shared.session(for: targetSiteID, excluding: view.window?.windowScene?.session)

        UIApplication.shared.requestSceneSessionActivation(existingSession, userActivity: activity, options: nil) { [weak self] error in
            DispatchQueue.main.async {
                self?.showSceneError(error, fallbackURL: url)
            }
        }
    }

    private func showSceneError(_ error: Error, fallbackURL: URL) {
        AppLogger.shared.log("Could not open site scene: \(error.localizedDescription)")
        loadInternally(fallbackURL, inNewTab: true)
    }

    private func updateSiteWindowIdentity() {
        title = currentSite.name
        view.window?.windowScene?.title = currentSite.name
        if let session = view.window?.windowScene?.session {
            SiteSceneRegistry.shared.register(siteID: siteID, session: session)
        }
    }

    private func configureWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.delegate = self
        webView.allowsBackForwardNavigationGestures = true
        applyUserAgentPreference()

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureToolbar() {
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.isTranslucent = true
        view.addSubview(toolbar)

        toolbarBottomConstraint = toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        toolbarHeightConstraint = toolbar.heightAnchor.constraint(equalToConstant: 50)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbarBottomConstraint,
            toolbarHeightConstraint
        ])

        backItem = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), style: .plain, target: self, action: #selector(goBack))
        forwardItem = UIBarButtonItem(image: UIImage(systemName: "chevron.forward"), style: .plain, target: self, action: #selector(goForward))
        reloadItem = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(reloadOrStop))
        homeItem = UIBarButtonItem(image: UIImage(systemName: "house"), style: .plain, target: self, action: #selector(goHome))
        shareItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareCurrentPage))
        safariViewItem = UIBarButtonItem(image: UIImage(systemName: "safari"), style: .plain, target: self, action: #selector(openCurrentPageInSafariView))
        historyItem = UIBarButtonItem(image: UIImage(systemName: "clock.arrow.circlepath"), style: .plain, target: self, action: #selector(showCurrentSiteHistory))
        tabsItem = UIBarButtonItem(image: UIImage(systemName: "square.on.square"), style: .plain, target: self, action: #selector(showTabs))
        settingsItem = UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(showSettings))

        toolbar.items = [
            backItem,
            forwardItem,
            reloadItem,
            homeItem,
            UIBarButtonItem(systemItem: .flexibleSpace),
            shareItem,
            safariViewItem,
            historyItem,
            tabsItem,
            settingsItem
        ]
        updateToolbarItems()
        updateScrollInsets()
    }

    private func configureGestures() {
        let edgeGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleBottomEdgeGesture(_:)))
        edgeGesture.edges = .bottom
        view.addGestureRecognizer(edgeGesture)

        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(toggleToolbarFromGesture))
        twoFingerTap.numberOfTouchesRequired = 2
        view.addGestureRecognizer(twoFingerTap)
    }

    private func configureObservers() {
        isLoadingObservation = webView.observe(\.isLoading, options: [.new]) { [weak self] _, _ in
            self?.updateToolbarItems()
        }
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] _, _ in
            self?.syncCurrentTabFromWebView()
        }
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] _, _ in
            self?.syncCurrentTabFromWebView()
        }
    }

    private func loadInitialPage() {
        if let initialURL {
            tabStore.updateCurrentTab(title: nil, url: initialURL)
            load(initialURL)
        } else if let tabURL = tabStore.currentTab?.url {
            load(tabURL)
        } else {
            load(currentSite.homeURL)
        }
    }

    private func load(_ url: URL) {
        let request = URLRequest(url: url)
        webView.load(request)
        updateSiteWindowIdentity()
        showToolbar(animated: true)
        rebuildMainMenu()
    }

    private func applyUserAgentPreference() {
        if settingsStore.settings.preferDesktopUserAgent {
            webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        } else {
            webView.customUserAgent = nil
        }
    }

    private func syncCurrentTabFromWebView() {
        let pageTitle = webView.title
        let pageURL = webView.url
        tabStore.updateCurrentTab(title: pageTitle, url: pageURL)
        updateSiteWindowIdentity()
        updateToolbarItems()
        rebuildMainMenu()
    }

    private func updateToolbarItems() {
        backItem?.isEnabled = webView?.canGoBack ?? false
        forwardItem?.isEnabled = webView?.canGoForward ?? false
        let imageName = webView?.isLoading == true ? "xmark" : "arrow.clockwise"
        reloadItem?.image = UIImage(systemName: imageName)
        safariViewItem?.isEnabled = currentPageURL != nil
        updateBackForwardMenus()
    }

    private func updateBackForwardMenus() {
        guard let webView else { return }

        let backItems = Array(webView.backForwardList.backList.reversed())
        let forwardItems = webView.backForwardList.forwardList

        backItem?.menu = makeNavigationMenu(title: AppLocalization.text("navigation.back", "Back"), items: backItems)
        forwardItem?.menu = makeNavigationMenu(title: AppLocalization.text("navigation.forward", "Forward"), items: forwardItems)
    }

    private func makeNavigationMenu(title: String, items: [WKBackForwardListItem]) -> UIMenu? {
        guard !items.isEmpty else { return nil }

        let actions = items.prefix(12).map { item in
            UIAction(title: titleForBackForwardItem(item)) { [weak self] _ in
                self?.webView.go(to: item)
            }
        }

        return UIMenu(title: title, children: actions)
    }

    private func titleForBackForwardItem(_ item: WKBackForwardListItem) -> String {
        let trimmedTitle = item.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedTitle, !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        if let host = item.url.host, !host.isEmpty {
            return host
        }

        return item.url.absoluteString
    }

    private func makeSiteMenu() -> UIMenu {
        let pageURL = currentPageURL
        let actions: [UIMenuElement] = [
            UICommand(
                title: "בית",
                image: UIImage(systemName: "house"),
                action: #selector(menuGoHome(_:)),
                propertyList: "site-home"
            ),
            UICommand(
                title: "פתח אתר בחלון חדש",
                image: UIImage(systemName: "macwindow.badge.plus"),
                action: #selector(menuOpenSiteInNewWindow(_:)),
                propertyList: "site-new-window"
            ),
            UICommand(
                title: "העתק קישור נוכחי",
                image: UIImage(systemName: "doc.on.doc"),
                action: #selector(menuCopyCurrentLink(_:)),
                propertyList: "site-copy-link",
                attributes: pageURL == nil ? [.disabled] : []
            ),
            UICommand(
                title: "פתח דף נוכחי בספארי",
                image: UIImage(systemName: "safari"),
                action: #selector(menuOpenCurrentPageInSafari(_:)),
                propertyList: "site-open-safari",
                attributes: pageURL == nil ? [.disabled] : []
            ),
            UICommand(
                title: "פתח דף נוכחי בספארי בתוך האפליקציה",
                image: UIImage(systemName: "safari"),
                action: #selector(menuOpenCurrentPageInSafariView(_:)),
                propertyList: "site-open-safari-view",
                attributes: pageURL == nil ? [.disabled] : []
            ),
            UICommand(
                title: "שתף דף נוכחי",
                image: UIImage(systemName: "square.and.arrow.up"),
                action: #selector(menuShareCurrentPage(_:)),
                propertyList: "site-share-page",
                attributes: pageURL == nil ? [.disabled] : []
            ),
            UICommand(
                title: "רענן",
                image: UIImage(systemName: "arrow.clockwise"),
                action: #selector(menuReload(_:)),
                propertyList: "site-reload"
            )
        ]

        return UIMenu(title: "אתר", image: UIImage(systemName: "globe"), identifier: NativeMenuIdentifier.site, children: actions)
    }

    private func makeHistoryMenu() -> UIMenu {
        let recent = historyStore.recentItems(forSiteID: siteID, limit: 12)
        AppLogger.shared.logSync("makeHistoryMenu started; count=\(recent.count)")

        var children: [UIMenuElement] = []

        if recent.isEmpty {
            children.append(UICommand(
                title: "אין היסטוריה אחרונה",
                action: #selector(menuNoOp(_:)),
                propertyList: "history-empty-\(siteID)",
                attributes: [.disabled]
            ))
        } else {
            children.append(contentsOf: recent.map { item in
                UICommand(
                    title: item.title,
                    image: UIImage(systemName: "clock"),
                    action: #selector(menuOpenURLCommand(_:)),
                    propertyList: [
                        "source": "history-recent",
                        "id": item.id.uuidString,
                        "url": item.urlString
                    ]
                )
            })
        }

        children.append(UIMenu(title: "", options: .displayInline, children: [
            UICommand(
                title: "הצג היסטוריה של אתר זה...",
                image: UIImage(systemName: "clock.arrow.circlepath"),
                action: #selector(menuShowSiteHistory(_:)),
                propertyList: "history-show-site-\(siteID)"
            ),
            UICommand(
                title: "הצג היסטוריה מכל האתרים...",
                image: UIImage(systemName: "clock"),
                action: #selector(menuShowAllHistory(_:)),
                propertyList: "history-show-all-sites"
            ),
            UICommand(
                title: "נקה היסטוריה לאתר זה",
                image: UIImage(systemName: "trash"),
                action: #selector(menuClearSiteHistory(_:)),
                propertyList: "history-clear-site-\(siteID)",
                attributes: recent.isEmpty ? [.disabled] : []
            )
        ]))

        return UIMenu(title: "היסטוריה", image: UIImage(systemName: "clock.arrow.circlepath"), identifier: NativeMenuIdentifier.history, children: children)
    }

    private func makeBookmarksMenu() -> UIMenu {
        let bookmarks = bookmarkStore.recentItems(forSiteID: siteID, limit: 12)
        AppLogger.shared.logSync("makeBookmarksMenu started; count=\(bookmarks.count)")

        var children: [UIMenuElement] = [
            UICommand(
                title: "הוסף דף נוכחי למועדפים",
                image: UIImage(systemName: "bookmark"),
                action: #selector(menuAddBookmark(_:)),
                propertyList: "bookmarks-add-current",
                attributes: currentPageURL == nil ? [.disabled] : []
            )
        ]

        if bookmarks.isEmpty {
            children.append(UIMenu(title: "", options: .displayInline, children: [
                UICommand(
                    title: "אין מועדפים לאתר זה",
                    action: #selector(menuNoOp(_:)),
                    propertyList: "bookmarks-empty-\(siteID)",
                    attributes: [.disabled]
                )
            ]))
        } else {
            children.append(UIMenu(title: "", options: .displayInline, children: bookmarks.map { bookmark in
                UICommand(
                    title: bookmark.title,
                    image: UIImage(systemName: "bookmark"),
                    action: #selector(menuOpenURLCommand(_:)),
                    propertyList: [
                        "source": "bookmark-recent",
                        "id": bookmark.id.uuidString,
                        "url": bookmark.urlString
                    ]
                )
            }))
        }


        children.append(UIMenu(title: "", options: .displayInline, children: [
            makeBookmarksSubmenu(title: "הצג מועדפים של אתר זה...", bookmarks: bookmarks, source: "bookmark-site-submenu", emptyPropertyList: "bookmarks-show-site-empty-\(siteID)"),
            makeBookmarksSubmenu(title: "הצג כל המועדפים...", bookmarks: bookmarkStore.recentItems(forSiteID: nil, limit: 50), source: "bookmark-all-submenu", emptyPropertyList: "bookmarks-show-all-empty")
        ]))

        return UIMenu(title: "מועדפים", image: UIImage(systemName: "bookmark"), identifier: NativeMenuIdentifier.bookmarks, children: children)
    }

    private func makeBookmarksSubmenu(title: String, bookmarks: [BookmarkItem], source: String, emptyPropertyList: String) -> UIMenu {
        let children: [UIMenuElement]
        if bookmarks.isEmpty {
            children = [
                UICommand(
                    title: "אין מועדפים",
                    action: #selector(menuNoOp(_:)),
                    propertyList: emptyPropertyList,
                    attributes: [.disabled]
                )
            ]
        } else {
            children = bookmarks.map { bookmark in
                UICommand(
                    title: bookmark.title,
                    image: UIImage(systemName: "bookmark"),
                    action: #selector(menuOpenURLCommand(_:)),
                    propertyList: [
                        "source": source,
                        "id": bookmark.id.uuidString,
                        "url": bookmark.urlString
                    ]
                )
            }
        }

        return UIMenu(title: title, image: UIImage(systemName: "bookmark"), children: children)
    }

    private func makeWindowsMenu() -> UIMenu {
        AppLogger.shared.logSync("makeWindowsMenu started")
        return UIMenu(
            title: "חלונות",
            image: UIImage(systemName: "rectangle.on.rectangle"),
            identifier: NativeMenuIdentifier.windows,
            children: [
                UICommand(
                    title: "פתח חלון חדש לאתר זה",
                    image: UIImage(systemName: "macwindow.badge.plus"),
                    action: #selector(menuOpenSiteInNewWindow(_:)),
                    propertyList: "windows-new-site-window"
                ),
                UICommand(
                    title: "פתח לשונית חדשה",
                    image: UIImage(systemName: "plus.square.on.square"),
                    action: #selector(menuOpenNewTab(_:)),
                    propertyList: "windows-new-tab"
                ),
                UICommand(
                    title: "הצג לשוניות",
                    image: UIImage(systemName: "square.on.square"),
                    action: #selector(menuShowTabs(_:)),
                    propertyList: "windows-show-tabs"
                )
            ]
        )
    }

    private func makeHelpMenu() -> UIMenu {
        AppLogger.shared.logSync("makeHelpMenu started")
        return UIMenu(
            title: "עזרה",
            image: UIImage(systemName: "questionmark.circle"),
            identifier: NativeMenuIdentifier.help,
            children: [
                UICommand(
                    title: "העתק מיקום קובץ לוג",
                    image: UIImage(systemName: "doc.on.doc"),
                    action: #selector(menuCopyLogFilePath(_:)),
                    propertyList: "help-copy-log-path"
                ),
                UICommand(
                    title: "נקה לוג אבחון",
                    image: UIImage(systemName: "trash"),
                    action: #selector(menuClearDiagnosticLog(_:)),
                    propertyList: "help-clear-log"
                )
            ]
        )
    }

    private func rebuildMainMenu() {
        UIMenuSystem.main.setNeedsRebuild()
    }

    private func addCurrentBookmark() {
        guard let url = currentPageURL else { return }
        bookmarkStore.add(title: webView?.title ?? tabStore.currentTab?.title, url: url, siteID: siteID)
        rebuildMainMenu()
        showMessage("המועדף נוסף", message: currentSite.name)
    }

    private func updateScrollInsets() {
        let bottomInset = toolbarVisible ? toolbarHeightConstraint.constant : 0
        webView.scrollView.contentInset.bottom = bottomInset
        webView.scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    private func showToolbar(animated: Bool) {
        setToolbarVisible(true, animated: animated)
    }

    private func hideToolbar(animated: Bool) {
        guard settingsStore.settings.hideToolbarOnScroll else { return }
        setToolbarVisible(false, animated: animated)
    }

    private func setToolbarVisible(_ visible: Bool, animated: Bool) {
        guard toolbarVisible != visible else { return }
        toolbarVisible = visible
        let targetTransform: CGAffineTransform = visible ? .identity : CGAffineTransform(translationX: 0, y: toolbarHeightConstraint.constant + view.safeAreaInsets.bottom)
        let changes = {
            self.toolbar.alpha = visible ? 1 : 0.02
            self.toolbar.transform = targetTransform
        }
        updateScrollInsets()

        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: changes)
        } else {
            changes()
        }
    }

    private func captureCurrentTabSnapshot(completion: (() -> Void)? = nil) {
        guard
            let currentTabID = tabStore.currentTabID,
            webView.bounds.width > 0,
            webView.bounds.height > 0
        else {
            completion?()
            return
        }

        let configuration = WKSnapshotConfiguration()
        configuration.snapshotWidth = NSNumber(value: Double(min(webView.bounds.width, 520)))

        webView.takeSnapshot(with: configuration) { image, _ in
            if let image {
                TabPreviewStore.save(image: image, for: currentTabID)
            }
            completion?()
        }
    }

    private func presentSafariView(for url: URL) {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        present(controller, animated: true)
    }

    private func openSystemURL(_ url: URL) {
        UIApplication.shared.open(url, options: [:])
    }

    private func showMessage(_ title: String, message: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func goBack() {
        if webView.canGoBack { webView.goBack() }
    }

    @objc private func goForward() {
        if webView.canGoForward { webView.goForward() }
    }

    @objc private func reloadOrStop() {
        if webView.isLoading {
            webView.stopLoading()
        } else {
            webView.reload()
        }
    }

    @objc private func goHome() {
        let homeURL = currentSite.homeURL
        tabStore.updateCurrentTab(title: currentSite.name, url: homeURL)
        load(homeURL)
    }

    @objc private func shareCurrentPage() {
        guard let url = webView.url else { return }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.popoverPresentationController?.barButtonItem = shareItem
        present(controller, animated: true)
    }

    @objc private func openCurrentPageInSafariView() {
        guard let url = currentPageURL else { return }
        presentSafariView(for: url)
    }

    @objc private func showCurrentSiteHistory() {
        showHistory(siteID: siteID, siteName: currentSite.name)
    }

    private func showHistory(siteID: String?, siteName: String?) {
        let controller = HistoryViewController(historyStore: historyStore, siteID: siteID, siteName: siteName)
        controller.delegate = self

        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .formSheet
        navigation.preferredContentSize = CGSize(width: 520, height: 660)

        present(navigation, animated: true)
    }

    @objc private func showTabs() {
        captureCurrentTabSnapshot { [weak self] in
            guard let self else { return }

            let controller = TabsViewController(tabStore: self.tabStore, settings: self.settingsStore.settings)
            controller.delegate = self

            let navigation = UINavigationController(rootViewController: controller)
            navigation.modalPresentationStyle = .pageSheet

            if let sheet = navigation.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }

            self.present(navigation, animated: true)
        }
    }

    @objc private func showSettings() {
        let controller = SettingsViewController(settingsStore: settingsStore, historyStore: historyStore)
        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .formSheet
        present(navigation, animated: true)
    }

    @objc private func menuGoHome(_ command: UICommand) {
        goHome()
    }

    @objc private func menuOpenSiteInNewWindow(_ command: UICommand) {
        openURLInSiteWindow(currentSite.homeURL, siteID: siteID)
    }

    @objc private func menuShowSiteHistory(_ command: UICommand) {
        showHistory(siteID: siteID, siteName: currentSite.name)
    }

    @objc private func menuShowAllHistory(_ command: UICommand) {
        showHistory(siteID: nil, siteName: nil)
    }

    @objc private func menuClearSiteHistory(_ command: UICommand) {
        AppLogger.shared.log("menuClearSiteHistory siteID=\(siteID)")
        historyStore.clear(siteID: siteID)
        rebuildMainMenu()
        showMessage("ההיסטוריה נוקתה", message: currentSite.name)
    }

    @objc private func menuAddBookmark(_ command: UICommand) {
        addCurrentBookmark()
    }

    @objc private func menuCopyCurrentLink(_ command: UICommand) {
        guard let url = currentPageURL else { return }
        UIPasteboard.general.url = url
    }

    @objc private func menuOpenCurrentPageInSafari(_ command: UICommand) {
        guard let url = currentPageURL else { return }
        openSystemURL(url)
    }

    @objc private func menuOpenCurrentPageInSafariView(_ command: UICommand) {
        openCurrentPageInSafariView()
    }

    @objc private func menuShareCurrentPage(_ command: UICommand) {
        shareCurrentPage()
    }

    @objc private func menuReload(_ command: UICommand) {
        reloadOrStop()
    }

    @objc private func menuOpenURLCommand(_ command: UICommand) {
        if let dict = command.propertyList as? [String: String],
           let urlString = dict["url"],
           let url = URL(string: urlString) {
            let source = dict["source"] ?? "unknown"
            AppLogger.shared.log("menuOpenURLCommand source=\(source) url=\(urlString)")
            openIncomingURL(url)
            return
        }

        if let urlString = command.propertyList as? String,
           let url = URL(string: urlString) {
            AppLogger.shared.log("menuOpenURLCommand source=stringFallback url=\(urlString)")
            openIncomingURL(url)
        }
    }

    @objc private func menuOpenNewTab(_ command: UICommand) {
        AppLogger.shared.log("menuOpenNewTab siteID=\(siteID)")
        openIncomingURLInNewTab(currentSite.homeURL)
    }

    @objc private func menuShowTabs(_ command: UICommand) {
        showTabs()
    }

    @objc private func menuCopyLogFilePath(_ command: UICommand) {
        let path = AppLogger.shared.logFileURL.path
        UIPasteboard.general.string = path
        AppLogger.shared.log("menuCopyLogFilePath path=\(path)")
        showMessage("מיקום קובץ הלוג הועתק", message: path)
    }

    @objc private func menuClearDiagnosticLog(_ command: UICommand) {
        AppLogger.shared.clear()
        showMessage("לוג האבחון נוקה")
    }

    @objc private func menuNoOp(_ command: UICommand) {}

    @objc private func handleBottomEdgeGesture(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .recognized || gesture.state == .ended {
            showToolbar(animated: true)
        }
    }

    @objc private func toggleToolbarFromGesture() {
        setToolbarVisible(!toolbarVisible, animated: true)
    }
}

extension BrowserViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let policy = URLPolicy(settings: settingsStore.settings, currentSiteID: siteID)
        switch policy.decision(for: url) {
        case .internalWeb:
            decisionHandler(.allow)
        case .configuredSite(let targetSiteID):
            decisionHandler(.cancel)
            if targetSiteID == siteID {
                loadInternally(url, inNewTab: false)
            } else {
                openURLInSiteWindow(url, siteID: targetSiteID)
            }
        case .externalWeb:
            decisionHandler(.cancel)
            if settingsStore.settings.openExternalLinksInSafariView {
                presentSafariView(for: url)
            } else {
                openSystemURL(url)
            }
        case .systemExternal:
            decisionHandler(.cancel)
            openSystemURL(url)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            historyStore.add(title: webView.title, url: url, siteID: siteID)
        }
        syncCurrentTabFromWebView()
        captureCurrentTabSnapshot()
        rebuildMainMenu()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateToolbarItems()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        updateToolbarItems()
    }
}

extension BrowserViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil, let url = navigationAction.request.url else { return nil }
        let policy = URLPolicy(settings: settingsStore.settings, currentSiteID: siteID)
        switch policy.decision(for: url) {
        case .internalWeb:
            tabStore.createTab(title: url.host ?? "New Tab", url: url, select: true)
            load(url)
        case .configuredSite(let targetSiteID):
            if targetSiteID == siteID {
                tabStore.createTab(title: url.host ?? "New Tab", url: url, select: true)
                load(url)
            } else {
                openURLInSiteWindow(url, siteID: targetSiteID)
            }
        case .externalWeb:
            presentSafariView(for: url)
        case .systemExternal:
            openSystemURL(url)
        }
        return nil
    }
}

extension BrowserViewController: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        lastScrollOffsetY = scrollView.contentOffset.y
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let currentY = scrollView.contentOffset.y
        let delta = currentY - lastScrollOffsetY
        let threshold: CGFloat = 18

        if delta > threshold, currentY > 80 {
            hideToolbar(animated: true)
            lastScrollOffsetY = currentY
        } else if delta < -threshold {
            showToolbar(animated: true)
            lastScrollOffsetY = currentY
        }
    }
}

extension BrowserViewController: TabsViewControllerDelegate {
    func tabsViewControllerDidRequestNewTab(_ controller: TabsViewController) {
        let tab = tabStore.createTab(url: currentSite.homeURL, select: true)
        controller.dismiss(animated: true) { [weak self] in
            if let url = tab.url { self?.load(url) }
        }
    }

    func tabsViewController(_ controller: TabsViewController, didSelect tab: BrowserTab) {
        tabStore.selectTab(id: tab.id)
        controller.dismiss(animated: true) { [weak self] in
            if let url = tab.url { self?.load(url) }
        }
    }
}

extension BrowserViewController: HistoryViewControllerDelegate {
    func historyViewController(_ controller: HistoryViewController, didSelect item: HistoryItem) {
        controller.dismiss(animated: true) { [weak self] in
            guard let self, let url = item.url else { return }
            self.tabStore.updateCurrentTab(title: item.title, url: url)
            self.openIncomingURL(url)
        }
    }
}

extension BrowserViewController: SettingsStoreDelegate {
    func settingsStoreDidChange(_ store: SettingsStore) {
        if store.settings.siteProfile(withID: siteID) == nil {
            siteID = store.settings.defaultSiteID
        }
        updateSiteWindowIdentity()
        applyUserAgentPreference()
        updateScrollInsets()
        AppShortcutManager.updateQuickActions(settings: store.settings)
        rebuildMainMenu()
    }
}

extension BrowserViewController: TabStoreDelegate {
    func tabStoreDidChange(_ store: TabStore) {
        updateToolbarItems()
        rebuildMainMenu()
    }
}

private enum NativeMenuIdentifier {
    static let site = UIMenu.Identifier("native.site.menu")
    static let history = UIMenu.Identifier("native.history.menu")
    static let bookmarks = UIMenu.Identifier("native.bookmarks.menu")
    static let windows = UIMenu.Identifier("native.windows.menu")
    static let help = UIMenu.Identifier("native.help.menu")
}
