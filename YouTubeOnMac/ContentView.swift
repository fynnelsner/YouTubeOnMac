//
//  ContentView.swift
//  YouTubeOnMac
//
//  Native webview wrapper for YouTube with toolbar, sleep timer,
//  inline fullscreen, and external-link handling. No injected ad blocking.
//

import SwiftUI
import WebKit
import Combine
import AppKit

// MARK: - State

@MainActor
final class WebViewState: ObservableObject {
    @Published var isVideoFullscreen = false
}

@MainActor
final class NavState: ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false
}

@MainActor
final class SleepTimer: ObservableObject {
    @Published var isActive = false
    @Published var remainingSeconds: TimeInterval = 0

    private var timer: Timer?
    private var endDate: Date?

    var remainingText: String {
        guard isActive else { return "" }
        let h = Int(remainingSeconds) / 3600
        let m = Int(remainingSeconds) / 60 % 60
        let s = Int(remainingSeconds) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    func start(seconds: TimeInterval) {
        guard seconds > 0 else { return }
        stop()
        remainingSeconds = seconds
        endDate = Date().addingTimeInterval(seconds)
        isActive = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        isActive = false
        remainingSeconds = 0
        endDate = nil
    }

    private func tick() {
        guard let end = endDate else { stop(); return }
        remainingSeconds = max(0, end.timeIntervalSinceNow)
        if remainingSeconds <= 0 { stop(); NSApp.terminate(nil) }
    }
}

// MARK: - Toolbar

struct AppKitToolbarSetup: NSViewRepresentable {
    @ObservedObject var webViewState: WebViewState
    @ObservedObject var navState: NavState
    @ObservedObject var sleepTimer: SleepTimer
    var webView: WKWebView
    @Binding var showCustomTimer: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window, window.toolbar == nil {
                context.coordinator.setup(window: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        window.toolbar?.isVisible = !webViewState.isVideoFullscreen
        context.coordinator.refresh()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    class Coordinator: NSObject, NSToolbarDelegate {
        let parent: AppKitToolbarSetup
        weak var toolbar: NSToolbar?
        var items: [NSToolbarItem.Identifier: NSToolbarItem] = [:]
        var wasTimerActive = false
        var timerBadgeItem: NSToolbarItem?
        var timerBadgeTextField: NSTextField?

        init(_ parent: AppKitToolbarSetup) { self.parent = parent }

        func setup(window: NSWindow) {
            let t = NSToolbar(identifier: "YOM")
            t.delegate = self
            t.displayMode = .iconOnly
            t.allowsUserCustomization = false
            t.showsBaselineSeparator = false
            window.toolbar = t
            self.toolbar = t
        }

        func refresh() {
            if let back = items[.init("back")] {
                back.isEnabled = parent.navState.canGoBack
            }
            if let fwd = items[.init("forward")] {
                fwd.isEnabled = parent.navState.canGoForward
            }
            if let zoomLabel = items[.init("zoomLabel")],
               let tf = zoomLabel.view as? NSTextField {
                tf.stringValue = "\(Int(parent.webView.pageZoom * 100))%"
            }
            if let timer = items[.init("timer")] as? NSMenuToolbarItem {
                let active = parent.sleepTimer.isActive
                timer.image = NSImage(systemSymbolName: active ? "timer.circle.fill" : "timer", accessibilityDescription: nil)
                let menu = NSMenu()
                if active {
                    let cancel = NSMenuItem(title: "Cancel (\(parent.sleepTimer.remainingText))", action: #selector(stopTimer), keyEquivalent: "")
                    cancel.target = self
                    menu.addItem(cancel)
                    menu.addItem(.separator())
                }
                for m in [15, 30, 45, 60, 90] {
                    let mi = NSMenuItem(title: "\(m) min", action: #selector(startTimer(_:)), keyEquivalent: "")
                    mi.representedObject = m * 60
                    mi.target = self
                    menu.addItem(mi)
                }
                menu.addItem(.separator())
                let custom = NSMenuItem(title: "Custom…", action: #selector(showCustomTimerSheet), keyEquivalent: "")
                custom.target = self
                menu.addItem(custom)
                timer.menu = menu
            }

            let active = parent.sleepTimer.isActive
            if active != wasTimerActive {
                wasTimerActive = active
                if active, let t = toolbar,
                   let idx = t.items.firstIndex(where: { $0.itemIdentifier.rawValue == "timer" }) {
                    t.insertItem(withItemIdentifier: .init("timerBadge"), at: idx + 1)
                } else if let idx = toolbar?.items.firstIndex(where: { $0.itemIdentifier.rawValue == "timerBadge" }) {
                    toolbar?.removeItem(at: idx)
                }
            }
            if active, let tf = timerBadgeTextField {
                tf.stringValue = parent.sleepTimer.remainingText
                tf.sizeToFit()
                let width = max(50, tf.frame.width + 6 + 13 + 4 + 8)
                tf.frame.origin = NSPoint(x: 6 + 13 + 4, y: (20 - tf.frame.height) / 2)
                if let item = timerBadgeItem, let container = item.view {
                    container.frame.size = NSSize(width: width, height: 20)
                }
                timerBadgeItem?.minSize = NSSize(width: width, height: 20)
                timerBadgeItem?.maxSize = NSSize(width: width, height: 20)
            }
        }

        func toolbar(_ toolbar: NSToolbar,
                     itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                     willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
            if let existing = items[itemIdentifier] { return existing }

            let item: NSToolbarItem
            switch itemIdentifier.rawValue {
            case "back":
                let i = NSToolbarItem(itemIdentifier: itemIdentifier)
                i.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: nil)
                i.target = self
                i.action = #selector(goBack)
                i.isEnabled = parent.navState.canGoBack
                item = i
            case "forward":
                let i = NSToolbarItem(itemIdentifier: itemIdentifier)
                i.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
                i.target = self
                i.action = #selector(goForward)
                i.isEnabled = parent.navState.canGoForward
                item = i
            case "reload":
                let i = NSToolbarItem(itemIdentifier: itemIdentifier)
                i.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
                i.target = self
                i.action = #selector(reload)
                item = i
            case "speed":
                let i = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
                i.image = NSImage(systemSymbolName: "gauge.with.dots.needle.67percent", accessibilityDescription: nil)
                let menu = NSMenu()
                for s in [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0] {
                    let mi = NSMenuItem(title: s == 1.0 ? "Normal" : "\(s)x", action: #selector(setSpeed(_:)), keyEquivalent: "")
                    mi.representedObject = s
                    mi.target = self
                    menu.addItem(mi)
                }
                i.menu = menu
                item = i
            case "zoomOut":
                let i = NSToolbarItem(itemIdentifier: itemIdentifier)
                i.image = NSImage(systemSymbolName: "minus.magnifyingglass", accessibilityDescription: nil)
                i.target = self
                i.action = #selector(zoomOut)
                item = i
            case "zoomLabel":
                let tf = NSTextField(labelWithString: "\(Int(parent.webView.pageZoom * 100))%")
                tf.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
                tf.alignment = .center
                let i = NSToolbarItem(itemIdentifier: itemIdentifier)
                i.view = tf
                i.minSize = NSSize(width: 38, height: 22)
                i.maxSize = NSSize(width: 50, height: 22)
                item = i
            case "zoomIn":
                let i = NSToolbarItem(itemIdentifier: itemIdentifier)
                i.image = NSImage(systemSymbolName: "plus.magnifyingglass", accessibilityDescription: nil)
                i.target = self
                i.action = #selector(zoomIn)
                item = i
            case "timer":
                let i = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
                i.image = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)
                let menu = NSMenu()
                for m in [15, 30, 45, 60, 90] {
                    let mi = NSMenuItem(title: "\(m) min", action: #selector(startTimer(_:)), keyEquivalent: "")
                    mi.representedObject = m * 60
                    mi.target = self
                    menu.addItem(mi)
                }
                menu.addItem(.separator())
                let custom = NSMenuItem(title: "Custom…", action: #selector(showCustomTimerSheet), keyEquivalent: "")
                custom.target = self
                menu.addItem(custom)
                i.menu = menu
                item = i
            case "timerBadge":
                let i = NSToolbarItem(itemIdentifier: itemIdentifier)
                let container = NSView()
                container.wantsLayer = true
                container.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1.0).cgColor
                container.layer?.cornerRadius = 10
                container.layer?.masksToBounds = true

                let image = NSImageView(frame: NSRect(x: 6, y: 3.5, width: 13, height: 13))
                image.image = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)
                image.contentTintColor = .systemOrange
                image.imageScaling = .scaleProportionallyUpOrDown

                let tf = NSTextField(frame: NSRect(x: 23, y: 2, width: 60, height: 16))
                tf.isBezeled = false
                tf.isEditable = false
                tf.isSelectable = false
                tf.drawsBackground = false
                tf.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
                tf.textColor = .systemOrange
                tf.alignment = .left
                timerBadgeTextField = tf

                container.addSubview(image)
                container.addSubview(tf)
                container.frame = NSRect(x: 0, y: 0, width: 50, height: 20)

                i.view = container
                i.minSize = NSSize(width: 50, height: 20)
                i.maxSize = NSSize(width: 50, height: 20)
                timerBadgeItem = i
                item = i
            default:
                return nil
            }

            items[itemIdentifier] = item
            return item
        }

        func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            [.init("back"), .init("forward"), .init("reload"),
             .flexibleSpace,
             .init("timer"), .init("speed"), .init("zoomOut"), .init("zoomLabel"), .init("zoomIn")]
        }

        func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            toolbarDefaultItemIdentifiers(toolbar) + [.init("timerBadge")]
        }

        @objc func goBack() { parent.webView.goBack() }
        @objc func goForward() { parent.webView.goForward() }
        @objc func reload() { parent.webView.reload() }
        @objc func setSpeed(_ sender: NSMenuItem) {
            if let s = sender.representedObject as? Double {
                parent.webView.evaluateJavaScript("window.yomSetSpeed?.(\(s));", completionHandler: nil)
            }
        }
        @objc func zoomOut() {
            parent.webView.pageZoom = max(0.5, parent.webView.pageZoom - 0.1)
            refresh()
        }
        @objc func zoomIn() {
            parent.webView.pageZoom = min(3.0, parent.webView.pageZoom + 0.1)
            refresh()
        }
        @objc func startTimer(_ sender: NSMenuItem) {
            if let s = sender.representedObject as? TimeInterval {
                parent.sleepTimer.start(seconds: s)
            }
        }
        @objc func stopTimer() { parent.sleepTimer.stop() }
        @objc func showCustomTimerSheet() { parent.showCustomTimer = true }
    }
}

// MARK: - Content View

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme

    @StateObject private var webViewState: WebViewState
    @StateObject private var navState: NavState
    @StateObject private var sleepTimer: SleepTimer
    @State private var showCustomTimer = false
    @State private var customTimerInput = ""

    let webView: WebView

    init() {
        let wvs = WebViewState()
        _webViewState = StateObject(wrappedValue: wvs)
        let ns = NavState()
        _navState = StateObject(wrappedValue: ns)
        _sleepTimer = StateObject(wrappedValue: SleepTimer())
        _showCustomTimer = State(wrappedValue: false)
        _customTimerInput = State(wrappedValue: "")
        webView = WebView(state: wvs, navState: ns)
    }

    var body: some View {
        webView
            .background(
                AppKitToolbarSetup(
                    webViewState: webViewState,
                    navState: navState,
                    sleepTimer: sleepTimer,
                    webView: webView.wkWebView,
                    showCustomTimer: $showCustomTimer
                )
                .allowsHitTesting(false)
            )
            .background(Color(colorScheme == .dark
                ? CGColor(red: 0.097, green: 0.097, blue: 0.097, alpha: 1)
                : CGColor(red: 1, green: 1, blue: 1, alpha: 1)
            ))
            .sheet(isPresented: $showCustomTimer) {
                customTimerSheet
            }
    }

    private var customTimerSheet: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
                Text("Sleep Timer")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                Text("Force-quits the app when time runs out")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            Divider()

            HStack(spacing: 0) {
                Text("Duration")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .frame(width: 80, alignment: .trailing)
                    .padding(.trailing, 12)

                TextField("e.g. 30, 5:30, 1:15:00", text: $customTimerInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(width: 180)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 20)

            Divider()

            HStack(spacing: 0) {
                Text("Presets")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .frame(width: 80, alignment: .trailing)
                    .padding(.trailing, 12)

                HStack(spacing: 6) {
                    ForEach([("15 min", "15"), ("30 min", "30"), ("1 hr", "60"), ("2 hr", "120")], id: \.0) { pair in
                        Button(pair.0) {
                            customTimerInput = pair.1
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.secondary.opacity(colorScheme == .dark ? 0.15 : 0.08))
                        )
                        .foregroundColor(.primary)
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)

            Text("Numbers = minutes  ·  MM:SS  ·  HH:MM:SS")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.bottom, 16)

            Divider()

            HStack(spacing: 10) {
                Button("Cancel") {
                    showCustomTimer = false
                    customTimerInput = ""
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Start Timer") {
                    if let secs = parseDuration(customTimerInput), secs > 0 {
                        sleepTimer.start(seconds: secs)
                    }
                    showCustomTimer = false
                    customTimerInput = ""
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(parseDuration(customTimerInput).map { $0 <= 0 } ?? true)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
        }
        .frame(width: 360)
        .background(Color(colorScheme == .dark
            ? CGColor(red: 0.14, green: 0.14, blue: 0.14, alpha: 1)
            : CGColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1)
        ))
    }

    /// Parse "30", "5:30", "1:15:00" etc. into seconds
    private func parseDuration(_ input: String) -> TimeInterval? {
        let s = input.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        let parts = s.split(separator: ":").compactMap { Double($0) }
        guard !parts.isEmpty else { return nil }
        switch parts.count {
        case 1: return parts[0] * 60
        case 2: return parts[0] * 60 + parts[1]
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        default: return nil
        }
    }
}

// MARK: - WebView

struct WebView: NSViewRepresentable {
    let state: WebViewState
    let navState: NavState
    let wkWebView: WKWebView

    init(state: WebViewState, navState: NavState) {
        self.state = state
        self.navState = navState

        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
                let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = prefs
        configuration.userContentController.addUserScript(
            WKUserScript(source: WebView.js, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        self.wkWebView = WKWebView(frame: .zero, configuration: configuration)
    }

    func makeCoordinator() -> Coordinator { Coordinator(state: state, navState: navState) }

    func makeNSView(context: Context) -> WKWebView {
        wkWebView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Safari/605.1.15"
        wkWebView.navigationDelegate = context.coordinator
        wkWebView.uiDelegate = context.coordinator
        wkWebView.configuration.userContentController.add(context.coordinator, name: "yomFs")
        wkWebView.configuration.userContentController.add(context.coordinator, name: "yomLink")
        if wkWebView.url == nil, let url = URL(string: "https://www.youtube.com") {
            wkWebView.load(URLRequest(url: url))
        }
        return wkWebView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        private let state: WebViewState
        private let navState: NavState
        init(state: WebViewState, navState: NavState) {
            self.state = state
            self.navState = navState
        }

        func userContentController(_ uc: WKUserContentController, didReceive msg: WKScriptMessage) {
            switch msg.name {
            case "yomFs":
                guard let v = msg.body as? Bool else { return }
                DispatchQueue.main.async { self.state.isVideoFullscreen = v }
            case "yomLink":
                guard let urlString = msg.body as? String, let url = URL(string: urlString) else { return }
                DispatchQueue.main.async { NSWorkspace.shared.open(url) }
            default:
                break
            }
        }

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                DispatchQueue.main.async { NSWorkspace.shared.open(url) }
            }
            return nil
        }

        func webView(_ wv: WKWebView, didFinish nav: WKNavigation!) {
            DispatchQueue.main.async {
                self.navState.canGoBack = wv.canGoBack
                self.navState.canGoForward = wv.canGoForward
            }
        }

        func webView(_ wv: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            let scheme = url.scheme?.lowercased() ?? ""
            guard scheme == "http" || scheme == "https" else {
                decisionHandler(.allow)
                return
            }
            let host = url.host?.lowercased() ?? ""
            let isYouTube = host.contains("youtube.com")
                || host.contains("youtube-nocookie.com")
                || host.contains("google.com")
                || host.contains("googlevideo.com")
            if isYouTube {
                decisionHandler(.allow)
                return
            }
            DispatchQueue.main.async { NSWorkspace.shared.open(url) }
            decisionHandler(.cancel)
        }
    }

    // MARK: - JS

    static let js: String = """
    (()=>{
      if(!window.location.hostname.includes("youtube.com"))return;
      if(window.__yom)return;window.__yom=true;

      const P=()=>document.querySelector(".html5-video-player");
      const V=()=>{const p=P();return p?p.querySelector("video"):document.querySelector("video")};

      // Inline fullscreen (avoids native full-screen window swap)
      let fs=false;
      const F="yom-fs";
      const iFs=()=>{
        if(document.getElementById(F))return;
        const s=document.createElement("style");s.id=F;
        s.textContent=`html.${F},body.${F}{overflow:hidden!important}html.${F} ytd-masthead,html.${F} #secondary,html.${F} #chat,html.${F} #below,html.${F} #comments{display:none!important}html.${F} ytd-watch-flexy #primary{margin:0!important;width:100%!important;max-width:100%!important}.html5-video-player.${F}-p{position:fixed!important;inset:0!important;width:100vw!important;height:100vh!important;z-index:2147483647!important;background:#000!important;display:flex!important;align-items:center!important;justify-content:center!important}.html5-video-player.${F}-p .html5-video-container{position:absolute!important;inset:0!important;width:100%!important;height:100%!important;display:flex!important;align-items:center!important;justify-content:center!important;transform:none!important;margin:0!important;padding:0!important;border:none!important}.html5-video-player.${F}-p video{width:100%!important;height:100%!important;object-fit:contain!important;object-position:center!important;margin:0!important;padding:0!important}`;
        document.head.appendChild(s)
      };
      const eFs=()=>{iFs();const p=P();if(!p)return;fs=true;document.documentElement.classList.add(F);document.body.classList.add(F);p.classList.add(F+"-p","ytp-fullscreen");try{webkit.messageHandlers.yomFs.postMessage(true)}catch{}};
      const xFs=()=>{fs=false;document.documentElement.classList.remove(F);document.body.classList.remove(F);const p=P();if(p){p.classList.remove(F+"-p","ytp-fullscreen")}try{webkit.messageHandlers.yomFs.postMessage(false)}catch{}};
      const tFs=()=>fs?xFs():eFs();
      window.yomFs=tFs;

      const pt=(o,n,r)=>{if(o&&typeof o[n]==="function"&&!o["_"+n]){o["_"+n]=o[n];o[n]=r(o[n])}};
      pt(Element.prototype,"requestFullscreen",o=>function(){eFs();return Promise.resolve()});
      pt(Element.prototype,"webkitRequestFullscreen",o=>function(){eFs()});
      pt(Document.prototype,"exitFullscreen",o=>function(){xFs();return Promise.resolve()});
      pt(Document.prototype,"webkitExitFullscreen",o=>function(){xFs()});
      pt(HTMLVideoElement.prototype,"webkitEnterFullscreen",o=>function(){eFs()});
      document.addEventListener("fullscreenchange",()=>{if(document.fullscreenElement){eFs();try{document.exitFullscreen()}catch{}}},true);
      document.addEventListener("webkitfullscreenchange",()=>{if(document.fullscreenElement){eFs();try{document.exitFullscreen()}catch{}}},true);

      document.addEventListener("keydown",e=>{
        if(e.metaKey||e.ctrlKey||e.altKey)return;
        const t=document.activeElement?.tagName;
        if(t==="INPUT"||t==="TEXTAREA"||document.activeElement?.getAttribute("contenteditable")==="true")return;
        if(e.key.toLowerCase()==="f"){e.preventDefault();e.stopPropagation();tFs()}
        else if(e.key==="Escape"&&fs){e.preventDefault();e.stopPropagation();xFs()}
      },true);
      document.addEventListener("click",e=>{
        const btn=e.target?.closest(".ytp-fullscreen-button");
        if(btn){e.preventDefault();e.stopPropagation();tFs()}
      },true);

      // Playback speed hook
      window.yomSetSpeed=s=>{
        const v=V();
        if(v){v.playbackRate=s;return}
        let c=0;
        const r=setInterval(()=>{const v2=V();if(v2){v2.playbackRate=s;clearInterval(r)}if(++c>10)clearInterval(r)},300);
      };

      // External links handler
      const unwrapRedirect=(url)=>{
        if(typeof url!=="string")return url;
        if(url.includes("youtube.com/redirect")||url.includes("youtube.com/shorts/redirect")){
          try{const u=new URL(url);const t=u.searchParams.get("q")||u.searchParams.get("url");if(t)return t;}catch(e){}
        }
        return url;
      };

      const isExternal=(url)=>{
        if(!url||typeof url!=="string")return false;
        try{
          const u=new URL(url,window.location.href);
          const h=u.hostname.toLowerCase();
          return (u.protocol==="http:"||u.protocol==="https:")
                 &&!(h.endsWith("youtube.com")||h.endsWith("youtube-nocookie.com")||h.endsWith("google.com")||h.endsWith("googlevideo.com"));
        }catch(e){return false;}
      };

      const openExternal=(url)=>{
        if(!isExternal(url))return false;
        if(window.webkit?.messageHandlers?.yomLink){
          window.webkit.messageHandlers.yomLink.postMessage(url);
          return true;
        }
        return false;
      };

      const patchAnchor=(a)=>{
        if(a.dataset?.yomPatched)return;
        a.dataset.yomPatched="1";
        const handler=(e)=>{
          const raw=a.getAttribute("href")||a.getAttribute("data-target")||a.getAttribute("data-url")||a.getAttribute("data-href")||"";
          const url=unwrapRedirect(a.href||raw);
          if(!url||url.startsWith("#")||url.startsWith("javascript:")||url==="about:blank")return;
          if(isExternal(url)){
            e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();
            openExternal(url);
          }
        };
        a.addEventListener("click",handler,true);
        a.addEventListener("auxclick",handler,true);
      };

      const patchAllAnchors=()=>{
        document.querySelectorAll('a[href]:not([data-yom-patched]),a[data-target]:not([data-yom-patched]),a[data-url]:not([data-yom-patched])').forEach(patchAnchor);
        document.querySelectorAll('[role="link"]:not([data-yom-patched])').forEach(el=>{
          if(el.dataset?.yomPatched)return;
          el.dataset.yomPatched="1";
          el.addEventListener("click",(e)=>{
            const url=unwrapRedirect(el.getAttribute("data-target")||el.getAttribute("data-url")||el.getAttribute("href")||el.getAttribute("data-href")||"");
            if(isExternal(url)){e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();openExternal(url);}
          },true);
        });
      };

      const linkObs=new MutationObserver(()=>patchAllAnchors());
      linkObs.observe(document.documentElement,{childList:true,subtree:true});
      patchAllAnchors();

      const _origOpen=window.open;
      window.open=function(url,target,features){
        const real=unwrapRedirect(url);
        if(isExternal(real)){openExternal(real);return null;}
        return _origOpen.call(this,url,target,features);
      };

      const _origAssign=window.location.assign;
      window.location.assign=function(url){
        const real=unwrapRedirect(url);
        if(isExternal(real)){openExternal(real);return;}
        return _origAssign.call(this,url);
      };
      const _origReplace=window.location.replace;
      window.location.replace=function(url){
        const real=unwrapRedirect(url);
        if(isExternal(real)){openExternal(real);return;}
        return _origReplace.call(this,url);
      };
    })();
    """
}

#Preview {
    ContentView()
}
