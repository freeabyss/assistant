# Third-Party Notices

Mac Super Assistant uses Swift Package Manager dependencies listed in `Package.swift`. Each dependency remains under its own license.

## Dependencies

| Dependency | Purpose | Source | License reference |
| --- | --- | --- | --- |
| GRDB.swift | SQLite/Core Data adjacent legacy package dependency retained by the project manifest | https://github.com/groue/GRDB.swift | See the package's LICENSE file |
| KeyboardShortcuts | Global keyboard shortcut support | https://github.com/sindresorhus/KeyboardShortcuts | See the package's license file |
| Sparkle | Legacy update framework dependency retained by the project; MVP user-facing update check opens GitHub Releases for manual download | https://github.com/sparkle-project/Sparkle | See the package's LICENSE file |

## MVP update policy

Although Sparkle remains in the project dependencies, the MVP user-facing **Check for Updates** action opens [GitHub Releases](https://github.com/abyss/assistant/releases). The MVP does not auto-download, auto-install, or restart to update.
