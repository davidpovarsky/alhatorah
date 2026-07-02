import UIKit
import WebKit
import SafariServices

final class BrowserViewController: UIViewController {
    private let settingsStore: SettingsStore
    private let tabStore: TabStore
    private let historyStore: HistoryStore

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

    init(settingsStore: SettingsStore, tabStore: TabStore, historyStore: HistoryStore) {
        self.settingsStore = settingsStore
        self.tabStore = tabStore
        self.historyStore = historyStore
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
        title = AppLocalization.text("browser.title", "Browser")
        configureWebView()
        configureToolbar()
        configureGestures()
        configureObservers()
        loadInitialPage()
    }

    func openIncomingURL(_ url: URL) {
        openIncomingURL(url, inNewTab: false)
    }

    func openIncomingURLInNewTab(_ url: URL) {
        openIncomingURL(url, inNewTab: true)
    }

    private func openIncomingURL(_ url: URL, inNewTab: Bool) {
        let policy = URLPolicy(settings: settingsStore.settings)
        switch policy.decision(for: url) {
        case .internalWeb:
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
        case .externalWeb:
            presentSafariView(for: url)
        case .systemExternal:
            openSystemURL(url)
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
        if let tabURL = tabStore.currentTab?.url {
            load(tabURL)
        } else {
            load(settingsStore.settings.homeURL)
        }
    }

    private func load(_ url: URL) {
        let request = URLRequest(url: url)
        webView.load(request)
        showToolbar(animated: true)
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
        title = pageTitle?.isEmpty == false ? pageTitle : pageURL?.host
        tabStore.updateCurrentTab(title: pageTitle, url: pageURL)
        updateToolbarItems()
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
        let homeURL = settingsStore.settings.homeURL
        tabStore.updateCurrentTab(title: "Home", url: homeURL)
        load(homeURL)
    }

    @objc private func shareCurrentPage() {
        guard let url = webView.url else { return }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.popoverPresentationController?.barButtonItem = shareItem
        present(controller, animated: true)
    }

    @objc private func showHistory() {
        let controller = HistoryViewController(historyStore: historyStore)
        controller.delegate = self

        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .formSheet
        navigation.preferredContentSize = CGSize(width: 460, height: 620)

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

        let policy = URLPolicy(settings: settingsStore.settings)
        switch policy.decision(for: url) {
        case .internalWeb:
            decisionHandler(.allow)
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
            historyStore.add(title: webView.title, url: url)
        }
        syncCurrentTabFromWebView()
        captureCurrentTabSnapshot()
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
        let policy = URLPolicy(settings: settingsStore.settings)
        switch policy.decision(for: url) {
        case .internalWeb:
            tabStore.createTab(title: url.host ?? "New Tab", url: url, select: true)
            load(url)
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
        let tab = tabStore.createTab(url: settingsStore.settings.homeURL, select: true)
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
            self.load(url)
        }
    }
}

extension BrowserViewController: SettingsStoreDelegate {
    func settingsStoreDidChange(_ store: SettingsStore) {
        applyUserAgentPreference()
        updateScrollInsets()
    }
}

extension BrowserViewController: TabStoreDelegate {
    func tabStoreDidChange(_ store: TabStore) {
        updateToolbarItems()
    }
}
