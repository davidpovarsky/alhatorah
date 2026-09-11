import SwiftUI
import WebKit

struct ActiveTextSelection: Equatable {
    let text: String
    let begin: Int
    let end: Int
    let parshan: String
    let paragraph: Int?
    let location: AlHaTorahLocation
}

struct ReaderTabView: View {
    @ObservedObject var coordinator: AppCoordinator = .shared
    @ObservedObject var dataStore: AlHaTorahDataStore = .shared
    @ObservedObject var sessionStore: AlHaTorahSessionStore = .shared

    @State private var currentLocation: AlHaTorahLocation?
    @State private var currentURL: URL?
    @State private var activeSelection: ActiveTextSelection?
    @State private var showingNoteSheet = false
    @State private var noteSheetLocation: AlHaTorahLocation?
    @State private var noteSheetText: String?

    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var pageTitle = ""

    // Reference to underlying browser for actions
    @State private var browserBridge = BrowserBridge()

    init() {}

    private var isCurrentLocationBookmarked: Bool {
        guard let loc = currentLocation else { return false }
        return dataStore.isBookmarked(location: loc)
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ReaderWebViewRepresentable(
                    bridge: browserBridge,
                    onLocationChanged: { loc, url in
                        self.currentLocation = loc
                        self.currentURL = url
                    },
                    onSelectionChanged: { selection in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.activeSelection = selection
                        }
                    },
                    onNavigationStateChanged: { back, forward, loading, title in
                        self.canGoBack = back
                        self.canGoForward = forward
                        self.isLoading = loading
                        self.pageTitle = title
                    }
                )
                .edgesIgnoringSafeArea(.bottom)

                // Floating Highlight / Quick Annotation Bar
                if let selection = activeSelection {
                    VStack(spacing: 8) {
                        HStack(spacing: 14) {
                            // 6 Color circles
                            ForEach(AlHaTorahPaletteColor.all) { color in
                                Button {
                                    applyHighlight(color: color, selection: selection)
                                } label: {
                                    Circle()
                                        .fill(Color(hex: color.hex))
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }

                            Divider()
                                .frame(height: 20)

                            // Add Note button for selection
                            Button {
                                noteSheetLocation = selection.location
                                noteSheetText = selection.text
                                showingNoteSheet = true
                                activeSelection = nil
                            } label: {
                                Image(systemName: "note.text.badge.plus")
                                    .font(.system(size: 18))
                                    .foregroundColor(.primary)
                            }

                            // Dismiss selection bar
                            Button {
                                withAnimation {
                                    activeSelection = nil
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
                    }
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(currentLocation?.displayTitle ?? (pageTitle.isEmpty ? AppLocalization.text("tabs.reader", "אתר") : pageTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        browserBridge.goBack?()
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .disabled(!canGoBack)

                    Button {
                        browserBridge.goForward?()
                    } label: {
                        Image(systemName: "chevron.forward")
                    }
                    .disabled(!canGoForward)

                    Button {
                        browserBridge.reloadOrStop?()
                    } label: {
                        Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Bookmark toggle button
                    Button {
                        toggleBookmark()
                    } label: {
                        Image(systemName: isCurrentLocationBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundColor(isCurrentLocationBookmarked ? .accentColor : .primary)
                    }
                    .disabled(currentLocation == nil)

                    // Add note button
                    Button {
                        noteSheetLocation = currentLocation
                        noteSheetText = nil
                        showingNoteSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .disabled(currentLocation == nil)

                    // Share button
                    Button {
                        sharePage()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(currentURL == nil)
                }
            }
            .sheet(isPresented: $showingNoteSheet) {
                NoteEditorSheet(mode: .create(initialLocation: noteSheetLocation, initialText: noteSheetText))
            }
            .onAppear {
                coordinator.onNavigateReader = { url in
                    browserBridge.loadURL?(url)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func applyHighlight(color: AlHaTorahPaletteColor, selection: ActiveTextSelection) {
        Task {
            _ = try? await dataStore.addHighlight(
                color: color.rgbString,
                location: selection.location,
                paragraph: selection.paragraph,
                begin: selection.begin,
                end: selection.end
            )
        }
        browserBridge.applyHighlightColor?(color.hex)
        withAnimation {
            activeSelection = nil
        }
    }

    private func toggleBookmark() {
        guard let loc = currentLocation else { return }
        Task {
            if isCurrentLocationBookmarked {
                try? await dataStore.removeBookmark(location: loc)
            } else {
                try? await dataStore.addBookmark(location: loc)
            }
        }
    }

    private func sharePage() {
        guard let url = currentURL else { return }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            controller.popoverPresentationController?.sourceView = root.view
            controller.popoverPresentationController?.sourceRect = CGRect(x: root.view.bounds.midX, y: 100, width: 1, height: 1)
            root.present(controller, animated: true)
        }
    }
}

// MARK: - Browser Bridge

final class BrowserBridge: ObservableObject {
    var loadURL: ((URL) -> Void)?
    var goBack: (() -> Void)?
    var goForward: (() -> Void)?
    var reloadOrStop: (() -> Void)?
    var applyHighlightColor: ((String) -> Void)?
}

final class PersistentBrowserHolder {
    static let shared = PersistentBrowserHolder()
    var controller: BrowserViewController?
}

// MARK: - UIViewControllerRepresentable Wrapper

struct ReaderWebViewRepresentable: UIViewControllerRepresentable {
    let bridge: BrowserBridge
    let onLocationChanged: (AlHaTorahLocation?, URL?) -> Void
    let onSelectionChanged: (ActiveTextSelection?) -> Void
    let onNavigationStateChanged: (Bool, Bool, Bool, String) -> Void

    func makeUIViewController(context: Context) -> BrowserViewController {
        let controller: BrowserViewController
        if let existing = PersistentBrowserHolder.shared.controller {
            controller = existing
        } else {
            let settingsStore = SettingsStore()
            let tabStore = TabStore(settings: settingsStore.settings)
            let historyStore = HistoryStore()
            controller = BrowserViewController(
                settingsStore: settingsStore,
                tabStore: tabStore,
                historyStore: historyStore
            )
            PersistentBrowserHolder.shared.controller = controller
            BrowserMenuCoordinator.activeBrowser = controller
        }

        controller.onLocationUpdate = { loc, url in
            DispatchQueue.main.async {
                onLocationChanged(loc, url)
                if let loc {
                    AlHaTorahDataStore.shared.recordHistory(location: loc, title: nil, url: url)
                }
            }
        }

        controller.onSelectionUpdate = { selection in
            DispatchQueue.main.async {
                onSelectionChanged(selection)
            }
        }

        controller.onNavStateUpdate = { back, forward, loading, title in
            DispatchQueue.main.async {
                onNavigationStateChanged(back, forward, loading, title)
            }
        }

        bridge.loadURL = { [weak controller] url in
            controller?.openIncomingURL(url)
        }
        bridge.goBack = { [weak controller] in
            controller?.performGoBack()
        }
        bridge.goForward = { [weak controller] in
            controller?.performGoForward()
        }
        bridge.reloadOrStop = { [weak controller] in
            controller?.performReloadOrStop()
        }
        bridge.applyHighlightColor = { [weak controller] colorHex in
            controller?.evaluateHighlightInDOM(colorHex: colorHex)
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: BrowserViewController, context: Context) {}
}

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let r, g, b: UInt64
        switch clean.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
