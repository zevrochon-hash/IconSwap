# IconSwap

A native macOS app for browsing and applying alternative app icons from [macosicons.com](https://macosicons.com) — a free, open-source alternative to [Replacicon](https://replacicon.app).

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift 6](https://img.shields.io/badge/Swift-6-orange) ![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

- **Browse thousands of icons** — search macosicons.com's library directly from the app
- **One-click replacement** — applies the `.icns` file to any installed app instantly
- **Restore originals** — revert any app back to its default icon at any time
- **Import custom icons** — bring your own `.icns` file via the file picker
- **Automatic reapplication** — monitors apps for updates and re-applies your custom icon after upgrades
- **Persistent history** — remembers all your customizations across reboots
- **Filter your app list** — view All, Dock-only, Legacy icon, or Customized apps

---

## Requirements

- macOS 13 Ventura or later
- [Homebrew](https://brew.sh)
- [fileicon](https://github.com/mklement0/fileicon) (`brew install fileicon`)
- A free [macosicons.com](https://macosicons.com) API key (for searching icons)

---

## Installation

### Build from source

```bash
# 1. Install dependencies
brew install xcodegen fileicon

# 2. Clone the repo
git clone https://github.com/your-username/iconswap.git
cd iconswap

# 3. Generate the Xcode project
xcodegen generate

# 4. Build
xcodebuild \
  -project IconSwap.xcodeproj \
  -scheme IconSwap \
  -configuration Release \
  build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# 5. Install
cp -R ~/Library/Developer/Xcode/DerivedData/IconSwap-*/Build/Products/Release/IconSwap.app \
      /Applications/IconSwap.app

# 6. Launch
open /Applications/IconSwap.app
```

---

## Setup

1. Get a free API key from [macosicons.com](https://macosicons.com)
2. Open **IconSwap → Settings** (or `⌘,`) and paste your API key
3. Select any app from the left panel and browse replacement icons on the right

---

## How It Works

IconSwap uses the [`fileicon`](https://github.com/mklement0/fileicon) CLI to set and remove custom icons on macOS app bundles. This works by writing a custom icon resource into the app bundle and setting the `com.apple.FinderInfo` extended attribute — the same mechanism macOS itself uses for custom icons.

After applying an icon, IconSwap:
1. Touches the app bundle to invalidate the icon cache
2. Restarts the Dock (`killall Dock`) so the new icon appears immediately

For apps in `/Applications` (system-level), macOS will prompt for your administrator password.

---

## Architecture

Built with Swift 6 + SwiftUI, targeting macOS 13+. App Sandbox is **disabled** — required to write to app bundles and execute shell processes.

```
IconSwap/
├── App/            — @main entry point, AppDelegate
├── Models/         — InstalledApp, IconResult, CustomIconMapping, AppFilter
├── Services/       — Scanner, API, Download, Replacement, Persistence, Monitor
├── ViewModels/     — AppListViewModel, IconGridViewModel, SettingsViewModel
├── Views/          — Main window, sidebar, icon grid, settings
├── Utilities/      — Async shell runner (Process+Shell), structured logging
└── Resources/      — Info.plist, entitlements, Assets.xcassets
```

See [`AGENT.md`](AGENT.md) for detailed technical documentation.

---

## Privacy

- **No telemetry.** No analytics, no crash reporting, no tracking of any kind.
- Icons are fetched from [macosicons.com](https://macosicons.com) using your own API key.
- Downloaded `.icns` files are cached locally in `~/Library/Application Support/IconSwap/IconCache/`.
- Replacement history is stored locally in `~/Library/Application Support/IconSwap/db.sqlite`.

---

## Contributing

Contributions are welcome. Please open an issue before submitting a pull request for large changes.

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Credits

- Icons sourced from [macosicons.com](https://macosicons.com) — a community-driven library of macOS icons
- Icon replacement powered by [fileicon](https://github.com/mklement0/fileicon) by mklement0
- Inspired by [Replacicon](https://replacicon.app)
