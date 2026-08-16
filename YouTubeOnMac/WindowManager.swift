//
//  WindowManager.swift
//  YouTubeOnMac
//
//  Creates and routes commands to the correct NSWindow/TabManager.
//

import SwiftUI
import AppKit
import Combine

@MainActor
final class WindowManager: ObservableObject {
    static let shared = WindowManager()

    private(set) var windows: [WindowController] = []
    private var currentID = 0

    private init() {}

    @discardableResult
    func createWindow(makeKey: Bool = true) -> NSWindow {
        currentID += 1
        let manager = TabManager()

        let contentView = RootView()
            .environmentObject(manager)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = "YouTubeOnMac"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.center()
        window.minSize = NSSize(width: 800, height: 500)
        window.isReleasedWhenClosed = false

        // Ensure the SwiftUI view actually fills the window on first display.
        hostingController.view.frame = window.contentView?.bounds ?? window.contentRect(forFrameRect: window.frame)
        hostingController.view.autoresizingMask = [.width, .height]

        let controller = WindowController(window: window, manager: manager)
        windows.append(controller)

        if makeKey {
            window.makeKeyAndOrderFront(nil)
        }

        // Move window slightly offset from the previous one for a natural cascade.
        if let last = windows.dropLast().last?.window {
            let offset = CGFloat(min(currentID, 10)) * 22
            var frame = window.frame
            frame.origin = NSPoint(x: last.frame.origin.x + offset, y: last.frame.origin.y - offset)
            window.setFrame(frame, display: true)
        }

        return window
    }

    func keyWindowManager() -> TabManager? {
        windows.first(where: { $0.window === NSApp.keyWindow })?.manager
    }

    func remove(controller: WindowController) {
        windows.removeAll { $0 === controller }
    }
}

@MainActor
final class WindowController: NSObject {
    let window: NSWindow
    let manager: TabManager

    init(window: NSWindow, manager: TabManager) {
        self.window = window
        self.manager = manager
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }

    @objc func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: window)
        WindowManager.shared.remove(controller: self)
    }
}
