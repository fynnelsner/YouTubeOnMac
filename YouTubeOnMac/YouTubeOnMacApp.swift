//
//  YouTubeOnMacApp.swift
//  YouTubeOnMac
//
//  Created by Kevin Dion on 2022-02-23.
//  Refactored by Fynn Elsner / Hermes Agent.
//

import SwiftUI
import AppKit

@MainActor
@main
final class YouTubeOnMacApp: NSObject, NSApplicationDelegate {
    private var keyMonitor: Any?
    private let windowManager = WindowManager.shared

    static func main() {
        let app = NSApplication.shared
        app.delegate = YouTubeOnMacApp()
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
        windowManager.createWindow()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event) ?? event
        }

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

    // MARK: - Keyboard routing

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return event }
        let ctrl = event.modifierFlags.contains(.control)
        let cmd = event.modifierFlags.contains(.command)
        let shift = event.modifierFlags.contains(.shift)

        if cmd && chars == "t" {
            windowManager.keyWindowManager()?.addTab()
            return nil
        }
        if cmd && chars == "w" && !shift {
            windowManager.keyWindowManager()?.closeSelectedTab()
            return nil
        }
        if cmd && chars == "n" {
            windowManager.createWindow()
            return nil
        }
        if ctrl && chars == "\t" {
            if shift {
                windowManager.keyWindowManager()?.selectPreviousTab()
            } else {
                windowManager.keyWindowManager()?.selectNextTab()
            }
            return nil
        }
        if cmd && "123456789".contains(chars) {
            if let n = Int(chars) {
                windowManager.keyWindowManager()?.selectTab(at: n - 1)
            }
            return nil
        }
        return event
    }

    // MARK: - Menu

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = NSMenu(title: "YouTubeOnMac")
        appMenuItem.submenu?.addItem(withTitle: "About YouTubeOnMac", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenuItem.submenu?.addItem(NSMenuItem.separator())
        appMenuItem.submenu?.addItem(withTitle: "Quit YouTubeOnMac", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        mainMenu.addItem(appMenuItem)

        let fileMenu = NSMenuItem()
        fileMenu.submenu = NSMenu(title: "File")
        fileMenu.submenu?.addItem(withTitle: "New Window", action: #selector(newWindow), keyEquivalent: "n")
        fileMenu.submenu?.addItem(withTitle: "New Tab", action: #selector(newTab), keyEquivalent: "t")
        fileMenu.submenu?.addItem(withTitle: "Close Tab", action: #selector(closeTab), keyEquivalent: "w")
        mainMenu.addItem(fileMenu)

        let tabsMenu = NSMenuItem()
        tabsMenu.submenu = NSMenu(title: "Tabs")
        tabsMenu.submenu?.addItem(withTitle: "Select Next Tab", action: #selector(nextTab), keyEquivalent: "\t")
        tabsMenu.submenu?.items.last?.keyEquivalentModifierMask = [.control]
        tabsMenu.submenu?.addItem(withTitle: "Select Previous Tab", action: #selector(previousTab), keyEquivalent: "\t")
        tabsMenu.submenu?.items.last?.keyEquivalentModifierMask = [.control, .shift]
        for n in 1...9 {
            let item = NSMenuItem(title: "Select Tab \(n)", action: #selector(selectTab(_:)), keyEquivalent: "\(n)")
            item.keyEquivalentModifierMask = .command
            item.representedObject = n - 1
            tabsMenu.submenu?.addItem(item)
        }
        mainMenu.addItem(tabsMenu)

        let viewMenu = NSMenuItem()
        viewMenu.submenu = NSMenu(title: "View")
        viewMenu.submenu?.addItem(withTitle: "Toggle Full Screen", action: #selector(toggleFullScreen), keyEquivalent: "f")
        viewMenu.submenu?.items.last?.keyEquivalentModifierMask = [.control, .command]
        mainMenu.addItem(viewMenu)

        let windowMenu = NSMenuItem()
        windowMenu.submenu = NSMenu(title: "Window")
        windowMenu.submenu?.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.submenu?.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "W")
        mainMenu.addItem(windowMenu)

        NSApplication.shared.mainMenu = mainMenu
    }

    // MARK: - Actions

    @objc private func newWindow() { windowManager.createWindow() }
    @objc private func newTab() { windowManager.keyWindowManager()?.addTab() }
    @objc private func closeTab() { windowManager.keyWindowManager()?.closeSelectedTab() }
    @objc private func nextTab() { windowManager.keyWindowManager()?.selectNextTab() }
    @objc private func previousTab() { windowManager.keyWindowManager()?.selectPreviousTab() }
    @objc private func selectTab(_ sender: NSMenuItem) {
        if let n = sender.representedObject as? Int {
            windowManager.keyWindowManager()?.selectTab(at: n)
        }
    }
    @objc private func toggleFullScreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
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
