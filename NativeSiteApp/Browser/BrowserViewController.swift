import UIKit
import WebKit
import SafariServices

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
        rebuildMainMenu()
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .main else { return }

        builder.remove(menu: NativeMenuIdentifier.site)
        builder.remove(menu: NativeMenuIdentifier.history)
        builder.remove(menu: NativeMenuIdentifier.bookmarks)
        builder.remove(menu: NativeMenuIdentifier.siteFeatures)

        let siteMenu = makeSiteMenu()
        let historyMenu = makeHistoryMenu()
        let bookmarksMenu = makeBookmarksMenu()

        builder.insertSibling(siteMenu, afterMenu: .view)
        builder.insertSibling(historyMenu, afterMenu: NativeMenuIdentifier.site)
        builder.insertSibling(bookmarksMenu, afterMenu: NativeMenuIdentifier.history)

        if let featuresMenu = SiteFeatureRegistry.menu(for: currentSite, host: self) {
            builder.insertSibling(featuresMenu, afterMenu: NativeMenuIdentifier.bookmarks)
        }
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
        historyItem = UIBarButtonItem(image: UIImage(systemName: "clock.arrow.circlepath"), style: .plain, target: self, action: #selector(showHistory))
        tabsItem = UIBarButtonItem(image: UIImage(systemName: "square.on.square"), style: .plain, target: self, action: #selector(showTabs))
        settingsItem = UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(showSettings))

        toolbar.items = [
            backItem,
            forwardItem,
            reloadItem,
            homeItem,
            UIBarButtonItem(systemItem: .flexibleSpace),
            shareItem,
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
        var actions: [UIMenuElement] = []

        actions.append(UIAction(title: "Home", image: UIImage(systemName: "house")) { [weak self] _ in
            self?.goHome()
        })

        actions.append(UIAction(title: "Open Site in New Window", image: UIImage(systemName: "macwindow.badge.plus")) { [weak self] _ in
            guard let self else { return }
            self.openURLInSiteWindow(self.currentSite.homeURL, siteID: self.siteID)
        })

        actions.append(UIAction(title: "Copy Current Link", image: UIImage(systemName: "doc.on.doc"), attributes: pageURL == nil ? [.disabled] : []) { [weak self] _ in
            guard let url = self?.currentPageURL else { return }
            UIPasteboard.general.url = url
        })

        actions.append(UIAction(title: "Open Current Page in Safari", image: UIImage(systemName: "safari"), attributes: pageURL == nil ? [.disabled] : []) { [weak self] _ in
            guard let self, let url = self.currentPageURL else { return }
            self.openSystemURL(url)
        })

        actions.append(UIAction(title: "Add Bookmark", image: UIImage(systemName: "bookmark"), attributes: pageURL == nil ? [.disabled] : []) { [weak self] _ in
            self?.addCurrentBookmark()
        })

        actions.append(UIAction(title: "Show Site History", image: UIImage(systemName: "clock.arrow.circlepath")) { [weak self] _ in
            self?.showHistory()
        })

        return UIMenu(title: currentSite.name, image: UIImage(systemName: "globe"), identifier: NativeMenuIdentifier.site, children: actions)
    }

    private func makeHistoryMenu() -> UIMenu {
        var children: [UIMenuElement] = [
            UIAction(title: "Show All History", image: UIImage(systemName: "clock")) { [weak self] _ in
                self?.showHistory()
            }
        ]

        let recent = historyStore.recentItems(forSiteID: siteID, limit: 12)
        if recent.isEmpty {
            children.append(UIAction(title: "No recent history", attributes: [.disabled]) { _ in })
        } else {
            children.append(UIMenu(title: "Recent", options: .displayInline, children: recent.map { item in
                UIAction(title: item.title, subtitle: item.url?.host ?? item.urlString, image: UIImage(systemName: "clock")) { [weak self] _ in
                    guard let url = item.url else { return }
                    self?.openIncomingURL(url)
                }
            }))
        }

        return UIMenu(title: "History", image: UIImage(systemName: "clock.arrow.circlepath"), identifier: NativeMenuIdentifier.history, children: children)
    }

    private func makeBookmarksMenu() -> UIMenu {
        var children: [UIMenuElement] = [
            UIAction(title: "Add Current Page", image: UIImage(systemName: "bookmark"), attributes: currentPageURL == nil ? [.disabled] : []) { [weak self] _ in
                self?.addCurrentBookmark()
            }
        ]

        let bookmarks = bookmarkStore.recentItems(forSiteID: siteID, limit: 12)
        if bookmarks.isEmpty {
            children.append(UIAction(title: "No bookmarks for this site", attributes: [.disabled]) { _ in })
        } else {
            children.append(UIMenu(title: "Bookmarks", options: .displayInline, children: bookmarks.map { bookmark in
                UIAction(title: bookmark.title, subtitle: bookmark.url?.host ?? bookmark.urlString, image: UIImage(systemName: "bookmark")) { [weak self] _ in
                    guard let url = bookmark.url else { return }
                    self?.openIncomingURL(url)
                }
            }))
        }

        return UIMenu(title: "Bookmarks", image: UIImage(systemName: "bookmark"), identifier: NativeMenuIdentifier.bookmarks, children: children)
    }

    private func rebuildMainMenu() {
        UIMenuSystem.main.setNeedsRebuild()
    }

    private func addCurrentBookmark() {
        guard let url = currentPageURL else { return }
        bookmarkStore.add(title: webView?.title ?? tabStore.currentTab?.title, url: url, siteID: siteID)
        rebuildMainMenu()
        showMessage("Bookmark Added", message: currentSite.name)
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

    @objc private func showHistory() {
        let controller = HistoryViewController(historyStore: historyStore, siteID: siteID, siteName: currentSite.name)
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

extension BrowserViewController: SiteFeatureHost {
    func openAlHaTorahIndexSearch() {
        guard currentSite.id == SiteProfile.alHaTorahID else { return }

        guard let bundle = RefPHPStore.shared.readCachedBundle(), !bundle.booksIndex.isEmpty else {
            let alert = UIAlertController(
                title: "AlHaTorah Index",
                message: "The local index is not ready yet. Update the Spotlight index first, then try again.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Update Index", style: .default) { [weak self] _ in
                self?.refreshAlHaTorahIndex()
            })
            present(alert, animated: true)
            return
        }

        let controller = AlHaTorahIndexSearchViewController(items: bundle.booksIndex)
        controller.onSelect = { [weak self] item in
            self?.openAlHaTorahIndexItem(item)
        }

        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .formSheet
        navigation.preferredContentSize = CGSize(width: 560, height: 720)
        present(navigation, animated: true)
    }

    func refreshAlHaTorahIndex() {
        let progress = UIAlertController(title: "AlHaTorah Index", message: "Updating the local index...", preferredStyle: .alert)
        progress.addAction(UIAlertAction(title: "Keep Running", style: .cancel))
        present(progress, animated: true)

        SpotlightIndexManager.shared.refreshIfNeeded(force: false) { [weak self] result in
            DispatchQueue.main.async {
                let finish = {
                    switch result {
                    case .success(let summary):
                        self?.showMessage("AlHaTorah Index Updated", message: "Books: \(summary.itemCount)\nIndexed now: \(summary.indexedCount)")
                    case .failure(let error):
                        self?.showMessage("Index Update Failed", message: error.localizedDescription)
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

    private func openAlHaTorahIndexItem(_ item: BookIndexItem) {
        let identifier = SpotlightIndexManager.shared.spotlightIdentifier(for: item.id)
        SpotlightIndexManager.shared.urlForSpotlightIdentifier(identifier) { [weak self] url in
            DispatchQueue.main.async {
                guard let self else { return }
                if let url {
                    self.openIncomingURL(url, preferredSiteID: SiteProfile.alHaTorahID, forceNewWindow: false)
                } else {
                    self.showMessage("Could Not Open Reference", message: item.titleEn.isEmpty ? item.id : item.titleEn)
                }
            }
        }
    }
}

private enum NativeMenuIdentifier {
    static let site = UIMenu.Identifier("native.site.menu")
    static let history = UIMenu.Identifier("native.history.menu")
    static let bookmarks = UIMenu.Identifier("native.bookmarks.menu")
    static let siteFeatures = UIMenu.Identifier("native.site.features.menu")
}

private protocol SiteFeatureHost: AnyObject {
    func openAlHaTorahIndexSearch()
    func refreshAlHaTorahIndex()
}

private enum SiteFeatureRegistry {
    static func menu(for site: SiteProfile, host: SiteFeatureHost) -> UIMenu? {
        if site.id == SiteProfile.alHaTorahID {
            return AlHaTorahFeatureProvider.menu(host: host)
        }
        return nil
    }
}

private enum AlHaTorahFeatureProvider {
    static func menu(host: SiteFeatureHost) -> UIMenu {
        UIMenu(
            title: "AlHaTorah",
            image: UIImage(systemName: "book"),
            identifier: NativeMenuIdentifier.siteFeatures,
            children: [
                UIAction(title: "Search Index", image: UIImage(systemName: "magnifyingglass")) { [weak host] _ in
                    host?.openAlHaTorahIndexSearch()
                },
                UIAction(title: "Update Index", image: UIImage(systemName: "arrow.triangle.2.circlepath")) { [weak host] _ in
                    host?.refreshAlHaTorahIndex()
                }
            ]
        )
    }
}

private final class AlHaTorahIndexSearchViewController: UITableViewController, UISearchResultsUpdating {
    var onSelect: ((BookIndexItem) -> Void)?

    private let allItems: [BookIndexItem]
    private var filteredItems: [BookIndexItem]
    private let searchController = UISearchController(searchResultsController: nil)
    private let reuseIdentifier = "AlHaTorahIndexSearchCell"

    init(items: [BookIndexItem]) {
        self.allItems = items
        self.filteredItems = Array(items.prefix(100))
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Search Index"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search AlHaTorah index"
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredItems.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = filteredItems[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = primaryTitle(for: item)
        content.secondaryText = secondaryTitle(for: item)
        content.image = UIImage(systemName: "book")
        content.textProperties.numberOfLines = 1
        content.secondaryTextProperties.numberOfLines = 2
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = filteredItems[indexPath.row]
        dismiss(animated: true) { [onSelect] in
            onSelect?(item)
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        let query = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            filteredItems = Array(allItems.prefix(100))
            tableView.reloadData()
            return
        }

        filteredItems = Array(allItems.lazy.filter { item in
            self.searchableText(for: item).contains(query)
        }.prefix(100))
        tableView.reloadData()
    }

    private func primaryTitle(for item: BookIndexItem) -> String {
        if AppLocalization.isHebrew {
            return item.titleHe.isEmpty ? item.titleEn : item.titleHe
        }
        return item.titleEn.isEmpty ? item.titleHe : item.titleEn
    }

    private func secondaryTitle(for item: BookIndexItem) -> String {
        var parts = [item.id]
        if !item.titleHe.isEmpty, item.titleHe != primaryTitle(for: item) { parts.append(item.titleHe) }
        if !item.titleEn.isEmpty, item.titleEn != primaryTitle(for: item) { parts.append(item.titleEn) }
        if !item.sectionNames.isEmpty { parts.append(item.sectionNames.prefix(3).joined(separator: " / ")) }
        return parts.filter { !$0.isEmpty }.joined(separator: " • ")
    }

    private func searchableText(for item: BookIndexItem) -> String {
        ([item.id, item.titleHe, item.titleEn, item.searchableText] + item.aliases + item.categoryTitles + item.sectionNames)
            .joined(separator: " ")
            .lowercased()
    }

    @objc private func done() {
        dismiss(animated: true)
    }
}
