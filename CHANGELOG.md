# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.3.2] - 2026-08-21

### Added
- `Cmd+R` reload shortcut for the current tab.

## [3.3.1] - 2026-08-21

### Fixed
- Video scaling and centering in inline fullscreen across all screen resolutions.

## [3.3.0] - 2026-08-21

### Added
- Centered video in inline fullscreen with equal black bars top and bottom.
- `Cmd+T` now creates exactly one tab.

## [3.2.9] - 2026-08-21

### Fixed
- Removed duplicate `Cmd+T` handler that created multiple tabs.

## [3.2.8] - 2026-08-21

### Changed
- App window can enter native macOS fullscreen (Space).
- YouTube video fullscreen stays inline in the same window/Space.

## [3.2.7] - 2026-08-21

### Fixed
- Restored robust inline fullscreen CSS and event interception.
- Added external-link handling back to JS layer.

## [3.2.6] - 2026-08-16

### Changed
- Disabled native Space fullscreen; video fullscreen is now window-inline only.

## [3.2.5] - 2026-08-16

### Added
- System dark-mode detection; YouTube theme now syncs to macOS appearance across tabs and windows.

## [3.2.4] - 2026-08-16

### Fixed
- Window no longer opens at a tiny intrinsic size; explicit 1280×800 initial frame.

## [3.2.3] - 2026-08-16

### Fixed
- Removed SwiftUI `WindowGroup` double-window bug; pure AppKit lifecycle.

## [3.2.2] - 2026-08-16

### Fixed
- Defer initial webview creation until window appears for faster launch.
- Loading placeholder while YouTube loads.

## [3.2.1] - 2026-08-16

### Fixed
- Shared `WKProcessPool` / `WKWebsiteDataStore` across all tabs and windows so login state and YouTube theme persist.

## [3.2.0] - 2026-08-16

### Added
- Native multi-tab bar with drag-to-reorder, pinning, and keyboard cycling.
- Multi-window support via AppKit.
- Fixes for Shorts offline errors and Google-login blank screen.

## [3.0.1] - earlier

### Added
- Universal `x86_64 + arm64` binary.
- Hardened runtime + JIT entitlements.
- DMG release pipeline.
