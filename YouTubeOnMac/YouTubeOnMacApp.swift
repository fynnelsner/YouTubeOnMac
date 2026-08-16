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
            RootView()
                .environmentObject(WindowManager.shared)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    WindowManager.shared.createWindow()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Tab") {
                    WindowManager.shared.keyWindowManager()?.addTab()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Close Tab") {
                    if let id = WindowManager.shared.keyWindowManager()?.selectedTabID {
                        WindowManager.shared.keyWindowManager()?.closeTab(id: id)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
            }

            CommandMenu("Tabs") {
                Button("Select Next Tab") {
                    WindowManager.shared.keyWindowManager()?.selectNextTab()
                }
                .keyboardShortcut("t", modifiers: [.control, .shift])

                Button("Select Previous Tab") {
                    WindowManager.shared.keyWindowManager()?.selectPreviousTab()
                }
                .keyboardShortcut("t", modifiers: [.control])

                ForEach(1..<10, id: \.self) { n in
                    Button("Select Tab \(n)") {
                        WindowManager.shared.keyWindowManager()?.selectTab(at: n - 1)
                    }
                    .keyboardShortcut(String(n), modifiers: .command)
                }
            }

            CommandGroup(after: .windowArrangement) {
                Button("Toggle Full Screen") {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                }
                .keyboardShortcut("f", modifiers: [.control, .command])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyMonitor: Any?
    private var windowManager: WindowManager { WindowManager.shared }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the first window if the default launch doesn't.
        DispatchQueue.main.async {
            if NSApp.windows.isEmpty {
                self.windowManager.createWindow()
            }
        }

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
