//
//  YouTubeOnMacApp.swift
//  YouTubeOnMac
//
//  Created by Kevin Dion on 2022-02-23.
//

import SwiftUI
import AppKit

@main
struct YouTubeOnMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Toggle Full Screen") {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                }
                .keyboardShortcut("f", modifiers: [.control, .command])
            }
        }
    }
}
