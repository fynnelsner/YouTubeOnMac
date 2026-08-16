//
//  ContentView.swift
//  YouTubeOnMac
//
//  Native webview wrapper for YouTube with tabs, toolbar, sleep timer,
//  inline fullscreen, and external-link handling.
//

import SwiftUI
import WebKit
import Combine
import AppKit

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

struct ContentView: View {
    @EnvironmentObject var tabManager: TabManager
    @StateObject private var sleepTimer = SleepTimer()
    @State private var showCustomTimer = false
    @State private var customTimerInput = ""
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            TabBarView(manager: tabManager)
                .frame(height: 34)

            ZStack {
                ForEach(tabManager.tabs) { tab in
                    WebViewContainer(webView: tab.webView)
                        .opacity(tabManager.selectedTabID == tab.id ? 1 : 0)
                        .disabled(tabManager.selectedTabID != tab.id)
                        .allowsHitTesting(tabManager.selectedTabID == tab.id)
                }

                if tabManager.tabs.isEmpty {
                    LoadingPlaceholder()
                }

                AppKitToolbarSetup(
                    manager: tabManager,
                    sleepTimer: sleepTimer,
                    showCustomTimer: $showCustomTimer
                )
                .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $showCustomTimer) {
            customTimerSheet
        }
        .background(
            colorScheme == .dark
                ? Color(red: 0.097, green: 0.097, blue: 0.097)
                : Color.white
        )
        .onAppear {
            tabManager.ensureInitialTab()
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
        .background(
            colorScheme == .dark
                ? Color(red: 0.14, green: 0.14, blue: 0.14)
                : Color(red: 0.97, green: 0.97, blue: 0.97)
        )
    }

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

struct WebViewContainer: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// MARK: - Startup loading placeholder

struct LoadingPlaceholder: View {
    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.06)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.red)
                        .frame(width: 76, height: 54)
                    Image(systemName: "play.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.9)

                Text("Loading YouTube…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Toolbar

struct AppKitToolbarSetup: NSViewRepresentable {
    @ObservedObject var manager: TabManager
    @ObservedObject var sleepTimer: SleepTimer
    @Binding var showCustomTimer: Bool

    var selectedWebView: WKWebView? {
        manager.selectedTab?.webView
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        if window.toolbar == nil {
            context.coordinator.setup(window: window)
        }
        window.toolbar?.isVisible = !(manager.selectedTab?.isFullscreen ?? false)
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
                back.isEnabled = parent.manager.selectedTab?.canGoBack ?? false
            }
            if let fwd = items[.init("forward")] {
                fwd.isEnabled = parent.manager.selectedTab?.canGoForward ?? false
            }
            if let zoomLabel = items[.init("zoomLabel")],
               let tf = zoomLabel.view as? NSTextField,
               let webView = parent.selectedWebView {
                tf.stringValue = "\(Int(webView.pageZoom * 100))%"
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
            if active, let tf = timerBadgeTextField, let item = timerBadgeItem {
                tf.stringValue = parent.sleepTimer.remainingText
                tf.sizeToFit()
                let width = max(50, tf.frame.width + 6 + 13 + 4 + 8)
                tf.frame.origin = NSPoint(x: 6 + 13 + 4, y: (20 - tf.frame.height) / 2)
                if let container = item.view {
                    container.frame.size = NSSize(width: width, height: 20)
                }
                item.minSize = NSSize(width: width, height: 20)
                item.maxSize = NSSize(width: width, height: 20)
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
                item = i
            case "forward":
                let i = NSToolbarItem(itemIdentifier: itemIdentifier)
                i.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
                i.target = self
                i.action = #selector(goForward)
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
                let tf = NSTextField(labelWithString: "100%")
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

        @objc func goBack() {
            parent.selectedWebView?.goBack()
        }
        @objc func goForward() {
            parent.selectedWebView?.goForward()
        }
        @objc func reload() {
            parent.selectedWebView?.reload()
        }
        @objc func setSpeed(_ sender: NSMenuItem) {
            if let s = sender.representedObject as? Double, let webView = parent.selectedWebView {
                webView.evaluateJavaScript("window.yomSetSpeed?.(\(s));", completionHandler: nil)
            }
        }
        @objc func zoomOut() {
            guard let webView = parent.selectedWebView else { return }
            webView.pageZoom = max(0.5, webView.pageZoom - 0.1)
            refresh()
        }
        @objc func zoomIn() {
            guard let webView = parent.selectedWebView else { return }
            webView.pageZoom = min(3.0, webView.pageZoom + 0.1)
            refresh()
        }
        @objc func startTimer(_ sender: NSMenuItem) {
            if let s = sender.representedObject as? TimeInterval {
                parent.sleepTimer.start(seconds: s)
            }
        }
        @objc func stopTimer() {
            parent.sleepTimer.stop()
        }
        @objc func showCustomTimerSheet() {
            parent.showCustomTimer = true
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TabManager())
}
