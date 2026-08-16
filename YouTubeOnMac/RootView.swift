//
//  RootView.swift
//  YouTubeOnMac
//
//  Handles first-launch onboarding before handing off to the main app.
//

import SwiftUI

struct RootView: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showWelcome: Bool = false

    var body: some View {
        ZStack {
            ContentView()
                .opacity(showWelcome ? 0 : 1)
                .disabled(showWelcome)

            if showWelcome {
                WelcomeView(isPresented: $showWelcome, hasSeenWelcome: $hasSeenWelcome)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            if !hasSeenWelcome {
                showWelcome = true
            }
        }
        .onChange(of: showWelcome) { newValue in
            if !newValue {
                hasSeenWelcome = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    RootView()
}
