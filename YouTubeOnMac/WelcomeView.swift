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
        ("play.rectangle.fill", "Native YouTube", "The full YouTube website in a dedicated Mac app."),
        ("arrow.up.arrow.down", "Universal Build", "Runs natively on Apple Silicon and Intel from one download."),
        ("safari.fill", "External Links", "Links outside YouTube open in your default browser automatically."),
        ("moon.fill", "Sleep Timer", "Set a timer and the app quits for you when it runs out."),
        ("arrow.up.left.and.arrow.down.right", "Inline Fullscreen", "Watch fullscreen without a separate window."),
        ("hand.raised.fill", "Clean & Lightweight", "No injected extensions. YouTube stays exactly as YouTube ships it.")
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.05),
                         Color(red: 0.10, green: 0.02, blue: 0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 52)

                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(.black.opacity(0.35))
                        .frame(width: 112, height: 112)
                        .shadow(color: Color.red.opacity(0.25), radius: 24, x: 0, y: 12)

                    Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage(size: NSSize(width: 96, height: 96)))
                        .resizable()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                Text("YouTubeOnMac")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 24)

                Text("YouTube, but better on Mac")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 6)

                Spacer().frame(height: 44)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(0..<features.count, id: \.self) { idx in
                        let f = features[idx]
                        HStack(spacing: 16) {
                            Image(systemName: f.icon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(width: 32, alignment: .center)
                                

                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(f.subtitle)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.65))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: 420)
                .padding(.horizontal, 36)

                Spacer().frame(height: 48)

                Button("Get Started") {
                    hasSeenWelcome = true
                    isPresented = false
                }
                .buttonStyle(WelcomeButtonStyle())
                .keyboardShortcut(.return, modifiers: [])

                Toggle("Don't show this again", isOn: $hasSeenWelcome)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.top, 16)

                Spacer().frame(height: 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 520, minHeight: 680)
    }
}

private struct WelcomeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 36)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.8 : 1.0))
            )
            .shadow(color: Color.red.opacity(0.35), radius: 12, x: 0, y: 6)
    }
}

#Preview {
    WelcomeView(isPresented: .constant(true), hasSeenWelcome: .constant(false))
}
