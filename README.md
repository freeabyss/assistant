# Mac Super Assistant

**English** | [简体中文](README.zh-CN.md)

> Your local-first macOS command center: Spotlight-style search, clipboard history, screenshots, safe commands, and settings in one menu bar app.

Mac Super Assistant (internal project name: Assistant) is a native macOS productivity assistant for a public-beta-ready MVP. It stays in the menu bar, opens with `⌥ Space`, and keeps clipboard, screenshot, and settings data on your Mac by default.

## Product page checklist

| Item | MVP content |
| --- | --- |
| Product name | Mac Super Assistant |
| Slogan | Your local-first macOS command center. |
| Core features | Unified search, app launch, clipboard history, screenshots and annotations, safe built-in commands, calculator/converter, settings and permissions center. |
| Screenshots / demo GIF | Use `/assets/product/search-panel.png`, `/assets/product/clipboard-history.png`, `/assets/product/screenshot-annotation.gif` once captured from the MVP build. Until images are committed, this README is the canonical placeholder list for required launch assets. |
| Download button | [Download the latest public beta from GitHub Releases](https://github.com/abyss/assistant/releases). |
| Version history | [CHANGELOG.md](CHANGELOG.md) and [GitHub Releases](https://github.com/abyss/assistant/releases). |
| Privacy policy | [PRIVACY.md](PRIVACY.md). |
| Feedback email | [feedback@assistant.app](mailto:feedback@assistant.app). |
| FAQ | See [FAQ](#faq). |

## Download

[Download the latest public beta](https://github.com/abyss/assistant/releases)

MVP distribution is GitHub Releases only. The MVP does not use accounts, payment, subscriptions, license keys, or Mac App Store delivery.

## Core features

- **Unified search entry**: Press `⌥ Space` to open a centered Spotlight-style search panel for apps, commands, settings, clipboard items, calculator results, and unit conversions.
- **Application launcher**: Search apps in `/Applications`, `~/Applications`, and `/System/Applications`, including Chinese pinyin and initials where available.
- **Clipboard history**: Record text, rich text, images, and Finder file references locally, with search, pinning, retention settings, and clear-all controls.
- **Screenshots and lightweight annotation**: Capture region, full-screen, or window screenshots; annotate with rectangles, arrows, text, and mosaic/blur; then copy or save as PNG.
- **Safe built-in commands**: Run a fixed whitelist of common macOS commands. Medium-risk actions such as clearing clipboard history or restarting Finder/Dock require confirmation.
- **Settings and permissions center**: Manage search sources, shortcuts, clipboard retention, screenshot save directory, language, startup behavior, permissions, privacy, feedback, and release links.

## Screenshots and demo assets

The MVP product page should include the following launch assets before wider public distribution:

1. `assets/product/search-panel.png` — unified search panel with app, command, setting, calculator, and clipboard result examples.
2. `assets/product/clipboard-history.png` — clipboard history page with type filter, search, pin, delete, storage usage, and clear-all entry.
3. `assets/product/screenshot-annotation.gif` — capture preview, annotation toolbar, copy, save, and cancel flow.
4. `assets/product/onboarding-permissions.png` — onboarding permission explanation for Screen Recording and Accessibility.

These assets are intentionally placeholders for US-020. They should be captured from the signed or release-candidate build during final release preparation.

## Permissions explained

Mac Super Assistant asks only for MVP-related macOS permissions and explains them before requesting access:

- **Screen Recording**: required for region, full-screen, and window screenshots. Screenshots are processed locally and are not uploaded.
- **Accessibility**: required for the MVP permission gate and future-safe system control boundaries such as simulated shortcuts, automatic paste, window control, and controlling other apps. Current MVP usage is limited to explicitly triggered app features and safe built-in command flows.
- **Apple Events / Automation**: used only for allowed built-in commands that you explicitly trigger. The app does not execute arbitrary shell commands.
- **Clipboard access**: macOS does not show a separate permission prompt for clipboard reads, so the onboarding and privacy policy explicitly state that clipboard history is on by default, stored locally, and can be paused or cleared at any time.

## Privacy-first defaults

- Clipboard metadata and content are stored locally in Core Data and the app support folder.
- Screenshots are captured, annotated, copied, or saved locally.
- File clipboard history stores file references and paths only; it does not copy file contents.
- No account system, cloud sync, analytics backend, payment system, subscription, or training pipeline is connected in the MVP.
- Feedback is user-initiated email only; no diagnostic data is sent silently.

Read the full [Privacy Policy](PRIVACY.md).

## Version history

See [CHANGELOG.md](CHANGELOG.md) for release notes. The app's **Check for Updates** action opens [GitHub Releases](https://github.com/abyss/assistant/releases) so users can manually download updates. The MVP does not auto-download, auto-install, or restart to update.

## Feedback

Send bug reports, suggestions, and public beta feedback to [feedback@assistant.app](mailto:feedback@assistant.app). The feedback email generated from the app includes app version, build number, macOS version, an optional error summary, and your notes. It does not attach clipboard history, screenshots, files, or automatic crash logs.

## FAQ

### Is Mac Super Assistant free?

Yes. The MVP is free and does not include payment, subscription, license-key, account, or Mac App Store flows.

### Where do I download updates?

Use [GitHub Releases](https://github.com/abyss/assistant/releases). The app's **Check for Updates** button opens the same page.

### Does the app upload my clipboard or screenshots?

No. Clipboard history, screenshots, settings, and search usage data are local-first and remain on your Mac unless you manually include information in a feedback email.

### Can I turn off clipboard history?

Yes. You can pause clipboard recording in Settings and clear clipboard history from the clipboard history page or built-in command.

### Why does the app request Screen Recording?

macOS requires Screen Recording permission for screenshot capture. The permission is used for region, full-screen, and window screenshots only.

### Why does the app request Accessibility?

The MVP asks for Accessibility during onboarding to establish the permission boundary for current and future macOS control features. The product page and onboarding explain the current MVP usage and future capability boundary so users can decide before granting access.

### Does the MVP support arbitrary shell commands?

No. Only a fixed whitelist of safe built-in commands is available. Arbitrary shell, `sudo`, shutdown, restart system, logout, file deletion, and process killing are out of scope.

### Is this available on the Mac App Store?

No. MVP distribution is GitHub Releases. Mac App Store submission is not part of this MVP.

## Third-party notices

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
