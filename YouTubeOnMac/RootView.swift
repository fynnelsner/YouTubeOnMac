//
//  RootView.swift
//  YouTubeOnMac
//
//  Handles first-launch onboarding before handing off to the main app.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var tabManager: TabManager
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showWelcome: Bool = false

    var body: some View {
        ZStack {
            ContentView()
                .environmentObject(tabManager)
                .opacity(showWelcome ? 0 : 1)
                .disabled(showWelcome)

            if showWelcome {
                WelcomeView(isPresented: $showWelcome, hasSeenWelcome: $hasSeenWelcome)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if !hasSeenWelcome {
                showWelcome = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTab)) { _ in
            tabManager.addTab()
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeTab)) { _ in
            tabManager.closeSelectedTab()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextTab)) { _ in
            tabManager.selectNextTab()
        }
        .onReceive(NotificationCenter.default.publisher(for: .previousTab)) { _ in
            tabManager.selectPreviousTab()
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectTab)) { notification in
            if let n = notification.object as? Int {
                tabManager.selectTab(at: n)
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(TabManager())
}
