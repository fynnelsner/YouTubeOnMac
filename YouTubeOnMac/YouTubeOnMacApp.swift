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
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) { }
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
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.mainWindow ?? NSApplication.shared.windows.first {
            window.center()
            window.setContentSize(NSSize(width: 1280, height: 800))
            window.minSize = NSSize(width: 800, height: 500)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}
