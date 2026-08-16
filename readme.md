# YouTubeOnMac

A lightweight, native-feeling YouTube app for macOS. It wraps YouTube in a dedicated WKWebView window so you get the full YouTube experience without keeping a browser tab open.

![YouTubeOnMac screenshot placeholder](https://i.imgur.com/CHs9vIi.jpeg)

## Download

Grab the latest universal DMG from the [latest release](https://github.com/fynnelsner/YouTubeOnMac/releases/latest).

The same app runs natively on Apple Silicon (`arm64`) and Intel (`x86_64`) Macs from a single download.

## Features

- **Native Mac app** with a clean toolbar and inline fullscreen
- **Real tabs** — open multiple YouTube pages in one window
  - `⌘T` new tab · `⌘W` close tab · `⌘1-9` jump to tab · `^⇥` / `^⇧⇥` cycle tabs
  - click, drag-to-reorder, close, and pin tabs in the tab bar
- **Multiple windows** — `⌘N` opens a separate YouTubeOnMac window with its own tabs
- **Universal binary** — Apple Silicon and Intel from one download
- **External links open in your default browser** automatically
- **Sleep timer** with quick presets or a custom duration
- **Playback speed control** and **page zoom** from the toolbar
- **No injected ad blockers** — YouTube works as designed, no fragile hacks
- **Welcome screen** on first launch

## System Requirements

- macOS 11 Big Sur or later
- Apple Silicon or Intel Mac

## Installation

1. Download `YouTubeOnMac-v3.2.3.dmg` from [Releases](https://github.com/fynnelsner/YouTubeOnMac/releases).
2. Open the DMG and drag **YouTubeOnMac** into your **Applications** folder.
3. Launch the app from Applications.

### First Launch

Because the app is not notarized by Apple, you may see:

> “YouTubeOnMac” can’t be opened because Apple cannot check it for malicious software.

Click **OK**, then open **System Settings → Privacy & Security** and scroll down to click **Open Anyway**. This is standard for independently distributed Mac apps. The app is clean; it is only a wrapper around YouTube.

## Building from Source

Open `YouTubeOnMac.xcodeproj` in Xcode 15 or later and build the `YouTubeOnMac` scheme. Release builds are configured as a universal binary for `x86_64` and `arm64`.

To build from the command line on a Mac:

```bash
xcodebuild -project YouTubeOnMac.xcodeproj \
  -scheme YouTubeOnMac \
  -configuration Release \
  -destination "generic/platform=macOS" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  ONLY_ACTIVE_ARCH=NO \
  build
```

The unsigned `.app` will appear in the DerivedData build products folder.

## Packaging a DMG

The project includes a GitHub Actions workflow that builds and packages the DMG automatically on every release. To do it manually:

```bash
mkdir -p /tmp/YouTubeOnMac
rm -rf /tmp/YouTubeOnMac/YouTubeOnMac.app
cp -R path/to/YouTubeOnMac.app /tmp/YouTubeOnMac/
ln -s /Applications /tmp/YouTubeOnMac/Applications
hdiutil create -volname "YouTubeOnMac" -srcfolder /tmp/YouTubeOnMac \
  -ov -format UDZO -o YouTubeOnMac.dmg
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘N` | New window |
| `⌘T` | New tab |
| `⌘W` | Close tab |
| `^⇥` | Next tab |
| `^⇧⇥` | Previous tab |
| `⌘1` … `⌘9` | Jump to tab 1–9 |
| `⌃⌘F` | Toggle inline fullscreen |
| `F` | Toggle inline fullscreen (when video player is focused) |
| `Esc` | Exit inline fullscreen |

## Why no ad blocker?

Previous versions tried to inject aggressive JavaScript ad blocking. It frequently broke as YouTube changed their site, caused playback issues, and made the app feel unreliable. This version keeps the wrapper minimal and lets YouTube behave normally.

## Contributing

Pull requests are welcome. If you want to add a feature, keep the app lightweight and native-feeling. Open an issue first for large changes.

## License

MIT

---

Made by [Fynn Elsner](https://github.com/fynnelsner).
