## Contributing to YouTubeOnMac

Thanks for your interest in improving YouTubeOnMac!

### Reporting Issues

- Use the [bug report](.github/ISSUE_TEMPLATE/bug_report.md) template for crashes or incorrect behavior.
- Use the [feature request](.github/ISSUE_TEMPLATE/feature_request.md) template for enhancements.
- Provide as much detail as possible: macOS version, app version, reproduction steps, and screenshots.

### Branching and Pull Requests

1. Fork the repository (or create a feature branch if you have write access).
2. Use a clear branch name:
   - `feat/description` for new features
   - `fix/description` for bug fixes
   - `refactor/description` for code restructuring
   - `docs/description` for documentation changes
3. Make focused commits with descriptive messages.
4. Open a pull request against `master` and fill out the PR template.
5. Ensure the "Build and Release Universal DMG" workflow passes before requesting review.

### Coding Guidelines

- Keep the core YouTube UI untouched; only add native macOS chrome around the webviews.
- Maintain macOS 11 Big Sur compatibility and universal `x86_64 + arm64` builds.
- Avoid breaking the existing toolbar, tab bar, keyboard shortcuts, and inline fullscreen behavior.
- Follow Swift style consistent with the existing codebase.
- Update `readme.md` and the shortcut table if you change user-facing behavior.

### Release Process

Maintainers bump the version in the Xcode project and `readme.md`, tag a semver release (`vX.Y.Z`), and the GitHub Actions workflow builds and attaches the universal DMG automatically.

### License

By contributing, you agree that your contributions will be licensed under the same license as the project.
