//
//  TabManager.swift
//  YouTubeOnMac
//
//  Multi-tab state and per-tab WKWebView management.
//

import SwiftUI
import WebKit
import Combine

struct Tab: Identifiable, Equatable {
    let id: UUID
    var title: String
    var url: URL
    let webView: WKWebView
    var isLoading: Bool = false
    var isPinned: Bool = false
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var isFullscreen: Bool = false

    static func == (lhs: Tab, rhs: Tab) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class TabManager: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var selectedTabID: UUID? = nil

    private var cancellables: Set<AnyCancellable> = []
    private var observers: [UUID: NSKeyValueObservation] = [:]

    init() {
        addTab()
    }

    // MARK: - Mutation

    @discardableResult
    func addTab(url: URL? = nil, request: URLRequest? = nil) -> Tab {
        let startURL = url ?? URL(string: "https://www.youtube.com")!
        let webView = Self.createWebView()
        let tab = Tab(id: UUID(), title: "YouTube", url: startURL, webView: webView)

        let coordinator = WebCoordinator(tabID: tab.id, manager: self)
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        objc_setAssociatedObject(webView, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        tabs.append(tab)
        selectedTabID = tab.id

        if let req = request {
            webView.load(req)
        } else {
            webView.load(URLRequest(url: startURL))
        }

        return tab
    }

    func closeTab(id: UUID) {
        guard tabs.count > 1 else { return }
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        let removingSelected = selectedTabID == id
        tabs.remove(at: index)
        observers.removeValue(forKey: id)

        if removingSelected {
            let newIndex = min(index, tabs.count - 1)
            selectedTabID = tabs[max(newIndex, 0)].id
        }
    }

    func selectTab(id: UUID) {
        selectedTabID = id
    }

    func selectTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        selectedTabID = tabs[index].id
    }

    func selectNextTab() {
        guard let id = selectedTabID, let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let next = (idx + 1) % tabs.count
        selectedTabID = tabs[next].id
    }

    func selectPreviousTab() {
        guard let id = selectedTabID, let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let prev = (idx - 1 + tabs.count) % tabs.count
        selectedTabID = tabs[prev].id
    }

    func pinTab(id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[idx].isPinned.toggle()
        if tabs[idx].isPinned {
            // Move pinned tabs to the front, preserving order
            let tab = tabs.remove(at: idx)
            let firstUnpinned = tabs.firstIndex(where: { !$0.isPinned }) ?? tabs.count
            tabs.insert(tab, at: firstUnpinned)
            selectedTabID = tab.id
        }
    }

    func updateTitle(id: UUID, title: String) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[idx].title = title.isEmpty ? "YouTube" : title
    }

    func updateURL(id: UUID, url: URL) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[idx].url = url
    }

    func updateLoading(id: UUID, loading: Bool) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[idx].isLoading = loading
    }

    func updateNavState(id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let webView = tabs[idx].webView
        tabs[idx].canGoBack = webView.canGoBack
        tabs[idx].canGoForward = webView.canGoForward
    }

    func setFullscreen(id: UUID, fullscreen: Bool) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[idx].isFullscreen = fullscreen
    }

    var selectedTab: Tab? {
        guard let id = selectedTabID else { return nil }
        return tabs.first(where: { $0.id == id })
    }

    // MARK: - WebView factory

    private static func createWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.processPool = sharedProcessPool
        config.websiteDataStore = sharedDataStore
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        if #available(macOS 12.3, *) {
            config.preferences.isElementFullscreenEnabled = true
        }

        let userController = WKUserContentController()

        // Playback-speed helper
        let speedScript = WKUserScript(
            source: """
            window.yomSetSpeed = function(rate) {
                document.querySelectorAll('video').forEach(function(v) {
                    v.playbackRate = rate;
                });
            };
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        userController.addUserScript(speedScript)

        // Inline-fullscreen bridge
        let fullscreenScript = WKUserScript(
            source: """
            function yomNotifyFullscreen() {
                var isFs = !!(document.fullscreenElement || document.webkitFullscreenElement);
                window.webkit.messageHandlers.yomFullscreen.postMessage(isFs ? 'enter' : 'exit');
            }
            document.addEventListener('fullscreenchange', yomNotifyFullscreen);
            document.addEventListener('webkitfullscreenchange', yomNotifyFullscreen);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        userController.addUserScript(fullscreenScript)
        userController.add(WebMessageHandler(), name: "yomFullscreen")

        config.userContentController = userController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }
}

// MARK: - Shared WebKit process / data store

extension TabManager {
    /// Shared process pool so all tabs share the same renderer process and persistent cookies.
    private static let sharedProcessPool = WKProcessPool()
    /// Shared data store so session cookies, theme prefs, and login state propagate to every tab.
    private static let sharedDataStore = WKWebsiteDataStore.default()
}

// MARK: - Navigation / UI delegate

@MainActor
private final class WebCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    let tabID: UUID
    weak var manager: TabManager?

    init(tabID: UUID, manager: TabManager) {
        self.tabID = tabID
        self.manager = manager
        super.init()
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        manager?.updateLoading(id: tabID, loading: true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        manager?.updateLoading(id: tabID, loading: false)
        manager?.updateTitle(id: tabID, title: webView.title ?? "YouTube")
        manager?.updateURL(id: tabID, url: webView.url ?? URL(string: "https://www.youtube.com")!)
        manager?.updateNavState(id: tabID)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        manager?.updateLoading(id: tabID, loading: false)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        manager?.updateLoading(id: tabID, loading: false)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        manager?.updateNavState(id: tabID)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, let host = url.host?.lowercased() else {
            decisionHandler(.allow)
            return
        }

        // Keep YouTube + Google services (login, recaptcha, fonts, static assets, video streams) in-app
        let internalHosts = [
            "youtube.com",
            "youtu.be",
            "google.com",
            "googleusercontent.com",
            "gstatic.com",
            "ytimg.com",
            "doubleclick.net",
            "googleadservices.com",
            "googlesyndication.com",
            "googlevideo.com",
            "withgoogle.com",
            "googleapis.com"
        ]
        let isInternal = internalHosts.contains { host == $0 || host.hasSuffix(".\($0)") }

        // Allow any subresource load (images, XHR, video streams, iframes) and any internal navigation
        let isSubresource = navigationAction.navigationType == .other
            || navigationAction.navigationType == .formResubmitted
            || navigationAction.targetFrame == nil

        if isInternal || isSubresource {
            // Unwrap YouTube redirect URLs
            if host.contains("youtube.com"), url.path == "/redirect" {
                if let redirect = extractRedirectURL(from: url) {
                    decisionHandler(.cancel)
                    webView.load(URLRequest(url: redirect))
                    return
                }
            }
            decisionHandler(.allow)
            return
        }

        // External links open in default browser
        decisionHandler(.cancel)
        NSWorkspace.shared.open(url)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        let newTab = manager?.addTab(url: url)
        return newTab?.webView
    }
}

private func extractRedirectURL(from url: URL) -> URL? {
    guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: true),
          let q = comps.queryItems?.first(where: { $0.name == "q" })?.value,
          let decoded = q.removingPercentEncoding,
          let target = URL(string: decoded) else { return nil }
    return target
}

// MARK: - Fullscreen message handler

@MainActor
private final class WebMessageHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let manager = message.webView.flatMap({ webView in
            (objc_getAssociatedObject(webView, "coordinator") as? WebCoordinator)?.manager
        }) else { return }
        let entering = (message.body as? String) == "enter"
        manager.setFullscreen(id: (objc_getAssociatedObject(message.webView!, "coordinator") as? WebCoordinator)?.tabID ?? UUID(), fullscreen: entering)
    }
}
