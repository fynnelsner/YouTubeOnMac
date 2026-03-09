//
//  ContentView.swift
//  MacTube
//
//  Created by Kevin Dion on 2022-02-23.
//

import SwiftUI
import WebKit
import Combine

final class WebViewState: ObservableObject {
    @Published var isVideoFullscreen = false
}

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme

    @StateObject private var webViewState: WebViewState
    let webView: WebView

    init() {
        let state = WebViewState()
        _webViewState = StateObject(wrappedValue: state)
        webView = WebView(state: state)
    }
    
    var body: some View {
        webView
            .toolbar {
                if !webViewState.isVideoFullscreen {
                    Spacer()
                    
                    Text("MacTube")
                        .padding(.leading, 110)
                    
                    Spacer()
                    
                    Button(action: {
                        self.webView.wkWebView.goBack()
                    }, label: {
                        Image(systemName: "chevron.left")
                    })
                    
                    Button(action: {
                        self.webView.wkWebView.goForward()
                    }, label: {
                        Image(systemName: "chevron.right")
                    })
                    
                    Button(action: {
                        self.webView.wkWebView.reload()
                    }, label: {
                        Image(systemName: "arrow.clockwise")
                    })
                }
            }
            .toolbarVisibility(webViewState.isVideoFullscreen ? .hidden : .visible, for: .windowToolbar)
            .background(Color(colorScheme == .dark
                ? CGColor(red: 0.097, green: 0.097, blue: 0.097, alpha: 1)
                : CGColor(red: 1, green: 1, blue: 1, alpha: 1)
            ))
    }
}


struct WebView: NSViewRepresentable {
    let state: WebViewState
    let wkWebView: WKWebView

    init(state: WebViewState) {
        self.state = state

        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        let inlineFullscreenScript = """
        (() => {
          if (!window.location.hostname.includes("youtube.com")) return;
          if (window.__mactubeInlineFullscreenInstalled) return;
          window.__mactubeInlineFullscreenInstalled = true;

          const STYLE_ID = "mactube-inline-fullscreen-style";
          let pseudoFullscreen = false;

          const installStyle = () => {
            if (document.getElementById(STYLE_ID)) return;
            const style = document.createElement("style");
            style.id = STYLE_ID;
            style.textContent = `
              html.mactube-inline-fs,
              body.mactube-inline-fs {
                overflow: hidden !important;
              }
              html.mactube-inline-fs ytd-masthead,
              html.mactube-inline-fs #secondary,
              html.mactube-inline-fs #chat,
              html.mactube-inline-fs #below,
              html.mactube-inline-fs #comments {
                display: none !important;
              }
              html.mactube-inline-fs ytd-watch-flexy #primary {
                margin: 0 !important;
                width: 100% !important;
                max-width: 100% !important;
              }
              .html5-video-player.mactube-inline-fs-player {
                position: fixed !important;
                inset: 0 !important;
                width: 100vw !important;
                height: 100vh !important;
                z-index: 2147483647 !important;
                background: #000 !important;
              }
              .html5-video-player.mactube-inline-fs-player .html5-video-container,
              .html5-video-player.mactube-inline-fs-player video {
                width: 100% !important;
                height: 100% !important;
              }
              .html5-video-player.mactube-inline-fs-player .html5-video-container {
                position: absolute !important;
                inset: 0 !important;
                display: flex !important;
                align-items: center !important;
                justify-content: center !important;
                transform: none !important;
              }
              .html5-video-player.mactube-inline-fs-player video {
                object-fit: contain !important;
                object-position: center center !important;
                width: auto !important;
                height: auto !important;
                max-width: 100% !important;
                max-height: 100% !important;
                top: auto !important;
                left: auto !important;
                right: auto !important;
                bottom: auto !important;
                transform: none !important;
                margin: auto !important;
              }
              .html5-video-player.mactube-inline-fs-player .ytp-chrome-bottom {
                left: 0 !important;
                width: 100% !important;
              }
              .html5-video-player.mactube-inline-fs-player .ytp-chrome-controls {
                width: 100% !important;
              }
              .html5-video-player.mactube-inline-fs-player .ytp-right-controls {
                margin-right: 12px !important;
              }
              .html5-video-player.mactube-inline-fs-player .ytp-progress-bar-container {
                left: 12px !important;
                right: 12px !important;
                width: auto !important;
              }
            `;
            document.head.appendChild(style);
          };

          const getPlayer = () => document.querySelector(".html5-video-player");

          const enterPseudoFullscreen = () => {
            installStyle();
            const player = getPlayer();
            if (!player) return;
            pseudoFullscreen = true;
            document.documentElement.classList.add("mactube-inline-fs");
            document.body.classList.add("mactube-inline-fs");
            player.classList.add("mactube-inline-fs-player");
            player.classList.add("ytp-fullscreen");
            try {
              window.webkit?.messageHandlers?.mactubeFullscreen?.postMessage(true);
            } catch {}
          };

          const exitPseudoFullscreen = () => {
            const player = getPlayer();
            pseudoFullscreen = false;
            document.documentElement.classList.remove("mactube-inline-fs");
            document.body.classList.remove("mactube-inline-fs");
            if (player) {
              player.classList.remove("mactube-inline-fs-player");
              player.classList.remove("ytp-fullscreen");
            }
            try {
              window.webkit?.messageHandlers?.mactubeFullscreen?.postMessage(false);
            } catch {}
          };

          const togglePseudoFullscreen = () => {
            if (pseudoFullscreen) {
              exitPseudoFullscreen();
            } else {
              enterPseudoFullscreen();
            }
          };

          const patch = (obj, name, replacement) => {
            if (!obj || typeof obj[name] !== "function") return;
            const key = "__mactubePatched_" + name;
            if (obj[key]) return;
            const original = obj[name];
            obj[key] = original;
            obj[name] = replacement(original);
          };

          patch(Element.prototype, "requestFullscreen", () => function () {
            enterPseudoFullscreen();
            return Promise.resolve();
          });

          patch(Element.prototype, "webkitRequestFullscreen", () => function () {
            enterPseudoFullscreen();
          });

          patch(Document.prototype, "exitFullscreen", () => function () {
            exitPseudoFullscreen();
            return Promise.resolve();
          });

          patch(Document.prototype, "webkitExitFullscreen", () => function () {
            exitPseudoFullscreen();
          });

          patch(HTMLVideoElement.prototype, "webkitEnterFullscreen", () => function () {
            enterPseudoFullscreen();
          });

          const handleNativeFullscreenChange = () => {
            if (!document.fullscreenElement) return;
            enterPseudoFullscreen();
            const exit = document.exitFullscreen?.bind(document);
            if (exit) {
              Promise.resolve(exit()).catch(() => {});
            }
          };

          const handleClick = (event) => {
            const target = event.target;
            if (!(target instanceof Element)) return;
            const fullscreenButton = target.closest(".ytp-fullscreen-button");
            if (!fullscreenButton) return;
            event.preventDefault();
            event.stopPropagation();
            togglePseudoFullscreen();
          };

          const handleKeydown = (event) => {
            const tag = document.activeElement?.tagName;
            const isEditable =
              tag === "INPUT" ||
              tag === "TEXTAREA" ||
              document.activeElement?.getAttribute("contenteditable") === "true";
            if (isEditable) return;
            if (event.metaKey || event.ctrlKey || event.altKey) return;

            if (event.key.toLowerCase() === "f") {
              event.preventDefault();
              event.stopPropagation();
              togglePseudoFullscreen();
            } else if (event.key === "Escape" && pseudoFullscreen) {
              event.preventDefault();
              event.stopPropagation();
              exitPseudoFullscreen();
            }
          };

          document.addEventListener("click", handleClick, true);
          document.addEventListener("keydown", handleKeydown, true);
          document.addEventListener("fullscreenchange", handleNativeFullscreenChange, true);
          document.addEventListener("webkitfullscreenchange", handleNativeFullscreenChange, true);
        })();
        """

        let userScripts = configuration.userContentController
        let script = WKUserScript(source: inlineFullscreenScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userScripts.addUserScript(script)

        self.wkWebView = WKWebView(frame: .zero, configuration: configuration)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeNSView(context: Context) -> WKWebView {
        wkWebView.configuration.userContentController.removeScriptMessageHandler(forName: "mactubeFullscreen")
        wkWebView.configuration.userContentController.add(context.coordinator, name: "mactubeFullscreen")

        if let url = URL(string: "https://www.youtube.com") {
            if wkWebView.url == nil {
                wkWebView.load(URLRequest(url: url))
            }
        }
        return wkWebView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Intentionally no-op to avoid reloading YouTube during SwiftUI updates
        // (which breaks transitions like entering fullscreen video).
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        private let state: WebViewState

        init(state: WebViewState) {
            self.state = state
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "mactubeFullscreen" else { return }
            guard let isFullscreen = message.body as? Bool else { return }
            DispatchQueue.main.async {
                self.state.isVideoFullscreen = isFullscreen
            }
        }
    }
}
