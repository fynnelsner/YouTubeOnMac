//
//  WelcomeView.swift
//  YouTubeOnMac
//
//  Native onboarding screen for first launch.
//

import SwiftUI

struct WelcomeView: View {
    @Binding var isPresented: Bool
    @Binding var hasSeenWelcome: Bool

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("play.rectangle.fill", "Native YouTube", "A clean, standalone Mac app for YouTube without browser tabs."),
        ("arrow.up.arrow.down", "Universal Build", "Runs natively on Apple Silicon and Intel Macs from a single download."),
        ("safari.fill", "External Links", "Links outside YouTube open in your default browser automatically."),
        ("moon.fill", "Sleep Timer", "Set a timer and the app quits for you when it runs out."),
        ("arrow.up.left.and.arrow.down.right", "Inline Fullscreen", "Watch videos fullscreen without leaving the app window."),
        ("hand.raised.fill", "No Interference", "We do not inject ad blockers. Your account and preferences stay untouched.")
    ]

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 48)

                Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage(size: NSSize(width: 96, height: 96)))
                    .resizable()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)

                Text("YouTubeOnMac")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .padding(.top, 20)

                Text("The Mac YouTube app you actually want")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                Spacer().frame(height: 40)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(0..<features.count, id: \.self) { idx in
                        let f = features[idx]
                        HStack(spacing: 14) {
                            Image(systemName: f.icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.red)
                                .frame(width: 28, alignment: .center)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.title)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(f.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: 420)
                .padding(.horizontal, 32)

                Spacer().frame(height: 44)

                Button("Get Started") {
                    hasSeenWelcome = true
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: [])

                Toggle("Don't show this again", isOn: $hasSeenWelcome)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .padding(.top, 14)

                Spacer().frame(height: 36)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 520, minHeight: 640)
    }
}

#Preview {
    WelcomeView(isPresented: .constant(true), hasSeenWelcome: .constant(false))
}
