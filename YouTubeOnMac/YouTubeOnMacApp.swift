//
//  YouTubeOnMacApp.swift
//  YouTubeOnMac
//
//  Created by Kevin Dion on 2022-02-23.
//  Refactored by Fynn Elsner / Hermes Agent.
//

import SwiftUI
import AppKit

@main
struct YouTubeOnMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            PlaceholderRootView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    NotificationCenter.default.post(name: .newWindow, object: nil)
                }
                .keyboardShortcut(KeyEquivalent("n"), modifiers: .command)

                Button("New Tab") {
                    NotificationCenter.default.post(name: .newTab, object: nil)
                }
                .keyboardShortcut(KeyEquivalent("t"), modifiers: .command)

                Button("Close Tab") {
                    NotificationCenter.default.post(name: .closeTab, object: nil)
                }
                .keyboardShortcut(KeyEquivalent("w"), modifiers: .command)
            }

            CommandMenu("Tabs") {
                Button("Select Next Tab") {
                    NotificationCenter.default.post(name: .nextTab, object: nil)
                }
                .keyboardShortcut(KeyEquivalent("t"), modifiers: [.control, .shift])

                Button("Select Previous Tab") {
                    NotificationCenter.default.post(name: .previousTab, object: nil)
                }
                .keyboardShortcut(KeyEquivalent("t"), modifiers: [.control])

                ForEach(1..<10, id: \.self) { n in
                    Button("Select Tab \(n)") {
                        NotificationCenter.default.post(name: .selectTab, object: n - 1)
                    }
                    .keyboardShortcut(KeyEquivalent(Character(String(n))), modifiers: .command)
                }
            }

            CommandGroup(after: .windowArrangement) {
                Button("Toggle Full Screen") {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                }
                .keyboardShortcut(KeyEquivalent("f"), modifiers: [.control, .command])
            }
        }
    }
}

struct PlaceholderRootView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyMonitor: Any?
    private let windowManager = WindowManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Close SwiftUI's default empty WindowGroup window and create our own.
        NSApp.windows.forEach { window in
            if window.contentViewController is NSHostingController<PlaceholderRootView> {
                window.close()
            }
        }
        windowManager.createWindow()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return event }
            let ctrl = event.modifierFlags.contains(.control)
            let cmd = event.modifierFlags.contains(.command)
            let shift = event.modifierFlags.contains(.shift)

            if cmd && chars == "t" {
                self.windowManager.keyWindowManager()?.addTab()
                return nil
            }
            if cmd && chars == "w" && !shift {
                self.windowManager.keyWindowManager()?.closeSelectedTab()
                return nil
            }
            if cmd && chars == "n" {
                self.windowManager.createWindow()
                return nil
            }
            if ctrl && chars == "\t" {
                if shift {
                    self.windowManager.keyWindowManager()?.selectPreviousTab()
                } else {
                    self.windowManager.keyWindowManager()?.selectNextTab()
                }
                return nil
            }
            if cmd && "123456789".contains(chars) {
                if let n = Int(chars) {
                    self.windowManager.keyWindowManager()?.selectTab(at: n - 1)
                }
                return nil
            }
            return event
        }

        // Subscribe to menu-triggered notifications so each window's manager reacts.
        NotificationCenter.default.addObserver(self, selector: #selector(newWindow), name: .newWindow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(newTab), name: .newTab, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(closeTab), name: .closeTab, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(nextTab), name: .nextTab, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(previousTab), name: .previousTab, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(selectTab(_:)), name: .selectTab, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            windowManager.createWindow()
        }
        return true
    }

    @objc private func newWindow() { windowManager.createWindow() }
    @objc private func newTab() { windowManager.keyWindowManager()?.addTab() }
    @objc private func closeTab() { windowManager.keyWindowManager()?.closeSelectedTab() }
    @objc private func nextTab() { windowManager.keyWindowManager()?.selectNextTab() }
    @objc private func previousTab() { windowManager.keyWindowManager()?.selectPreviousTab() }
    @objc private func selectTab(_ notification: Notification) {
        if let n = notification.object as? Int {
            windowManager.keyWindowManager()?.selectTab(at: n)
        }
    }
}

extension TabManager {
    func closeSelectedTab() {
        guard let id = selectedTabID else { return }
        closeTab(id: id)
    }
}

extension Notification.Name {
    static let newWindow = Notification.Name("yom.newWindow")
    static let newTab = Notification.Name("yom.newTab")
    static let closeTab = Notification.Name("yom.closeTab")
    static let nextTab = Notification.Name("yom.nextTab")
    static let previousTab = Notification.Name("yom.previousTab")
    static let selectTab = Notification.Name("yom.selectTab")
}
