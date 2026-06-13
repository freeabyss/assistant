# Privacy Policy for Mac Super Assistant

Last updated: 2026-06-13

Mac Super Assistant is a local-first macOS productivity app. The MVP is designed so clipboard history, screenshots, settings, and usage data stay on your Mac by default.

## Data stored locally

Mac Super Assistant may store the following data locally:

- Clipboard records: text, rich text plain-text summaries, image resources, and Finder file references.
- Clipboard resources: image originals, thumbnails, and rich text RTF/HTML resources in the app support folder.
- Settings: hotkey, launch-at-login preference, search source display settings, clipboard retention, screenshot save directory, and language preference.
- Search metadata: local blacklist entries and app/command usage counts used for result ordering.
- Screenshot files: PNG screenshots saved to the directory you choose, defaulting to `~/Pictures/Screenshots`.

## Clipboard history

Clipboard history is enabled by default after onboarding confirmation. You can pause clipboard recording, adjust retention, delete individual items, or clear all clipboard history from the app.

File clipboard history stores file references and paths only. It does not copy file contents into the app database.

## Screenshots

Screenshots and annotations are processed locally. Copying a screenshot writes it to the system clipboard and may add it to local clipboard history. Saving a screenshot writes a PNG file to your configured screenshot directory and does not create a separate screenshot history.

## Permissions

- **Screen Recording** is required for screenshot capture.
- **Accessibility** is requested during onboarding to support the MVP permission gate and future-safe macOS control boundaries such as simulated shortcuts, automatic paste, window control, and controlling other apps. Current MVP behavior is limited to explicitly triggered app features and safe built-in command flows.
- **Apple Events / Automation** may be used only for allowed built-in commands that you explicitly trigger.
- **Clipboard access** is explained in onboarding because macOS does not show a separate prompt for clipboard reads.

## Network and uploads

The MVP does not upload clipboard history, screenshots, files, settings, search usage data, or diagnostics automatically. It does not sync data to a cloud service and does not use your data to train models.

The app's **Check for Updates** action opens the GitHub Releases page in your browser for manual download. The MVP does not auto-download, auto-install, or restart to update.

## Feedback email

Feedback is user-initiated email only. Before opening your mail app, Mac Super Assistant shows the data scope and lets you cancel. The generated email may include:

- App version and build number.
- macOS version.
- Optional error summary.
- Notes you type yourself.

The generated email does not attach clipboard history, screenshots, files, or automatic crash logs.

## Accounts, payment, and subscriptions

The MVP does not include accounts, login, registration, payment, subscriptions, license keys, or Mac App Store purchase flows.

## Contact

For privacy questions or feedback, email [feedback@assistant.app](mailto:feedback@assistant.app).
