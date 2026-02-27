# IconSwap — Agent Context

A native macOS app that replicates [Replacicon](https://replacicon.app): browse alternative icons from macosicons.com and replace installed app icons with one click.

---

## Quick Facts

| | |
|---|---|
| **Language** | Swift 6 |
| **UI** | SwiftUI (macOS 13+ target) |
| **Architecture** | MVVM |
| **Sandbox** | **Disabled** — required to write to `/Applications` and run shell processes |
| **Xcode project** | Generated via `xcodegen` from `project.yml` |
| **Bundle ID** | `com.iconswap.app` |
| **Installed at** | `/Applications/IconSwap.app` |
| **DB** | `~/Library/Application Support/IconSwap/db.sqlite` |
| **Icon cache** | `~/Library/Application Support/IconSwap/IconCache/` |

---

## Project Layout

```
replacicon-alternative/
├── project.yml                         ← xcodegen spec (source of truth for Xcode project)
├── IconSwap.xcodeproj/                 ← generated; regenerate with `xcodegen generate`
└── IconSwap/
    ├── App/
    │   ├── IconSwapApp.swift           ← @main; wires all services into the view hierarchy
    │   └── AppDelegate.swift           ← starts AppUpdateMonitor; app stays alive after window close
    ├── Models/
    │   ├── InstalledApp.swift          ← scanned app (id = bundleIdentifier)
    │   ├── IconResult.swift            ← API hit + Decodable types (IconSearchResponse, IconHit)
    │   ├── CustomIconMapping.swift     ← persisted replacement record
    │   └── AppFilter.swift             ← All / Dock / Legacy / Customized
    ├── Services/
    │   ├── AppScannerService.swift     ← reads Info.plist from /Applications + ~/Applications
    │   ├── IconAPIService.swift        ← macosicons.com POST search (actor)
    │   ├── IconDownloadService.swift   ← downloads .icns to cache dir (actor)
    │   ├── IconReplacementService.swift← shells to fileicon; direct-first, sudo fallback (actor)
    │   ├── PersistenceService.swift    ← SQLite3 CRUD for CustomIconMapping (singleton)
    │   ├── AppUpdateMonitor.swift      ← FSEvents on mapped app paths; reapplies on bundle change
    │   └── FileiconInstaller.swift     ← detects fileicon at Homebrew paths
    ├── ViewModels/
    │   ├── AppListViewModel.swift      ← drives left panel; filter/search with Combine debounce
    │   ├── IconGridViewModel.swift     ← drives right panel; search, paginate, apply, restore
    │   └── SettingsViewModel.swift     ← thin wrapper around @AppStorage
    ├── Views/
    │   ├── MainWindowView.swift        ← HSplitView root; fileicon alert on launch
    │   ├── AppListView.swift           ← sidebar List with selection → iconGridVM.selectedApp
    │   ├── AppRowView.swift            ← app row with icon, badges (customized ✓, legacy ⚠)
    │   ├── AppIconImageView.swift      ← async .icns loader from local URL
    │   ├── IconGridView.swift          ← right panel: header + LazyVGrid + fileImporter
    │   ├── IconGridItemView.swift      ← single icon card; lowResPng thumbnail, hover/checkmark
    │   ├── SearchBarView.swift
    │   ├── FilterBarView.swift
    │   ├── EmptyStateView.swift
    │   ├── LoadingView.swift
    │   └── SettingsView.swift          ← API key (SecureField), behavior toggles, fileicon status
    ├── Utilities/
    │   ├── Process+Shell.swift         ← async Process.run() and Process.runPrivileged()
    │   └── AppLogger.swift             ← os.Logger channels: scanner, api, download, replace, monitor, persist
    └── Resources/
        ├── Info.plist
        ├── IconSwap.entitlements       ← only network.client; NO sandbox key
        └── Assets.xcassets/
```

---

## Build & Install

```bash
# Prerequisites (one-time)
brew install xcodegen fileicon

# Regenerate Xcode project after editing project.yml
/opt/homebrew/bin/xcodegen generate

# Build (no code signing required for local use)
xcodebuild \
  -project IconSwap.xcodeproj \
  -scheme IconSwap \
  -configuration Debug \
  build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Install
cp -R ~/Library/Developer/Xcode/DerivedData/IconSwap-*/Build/Products/Debug/IconSwap.app \
      /Applications/IconSwap.app

# Launch
open /Applications/IconSwap.app
```

> After any source change: just re-run `xcodebuild ...` and `cp -R`. No need to re-run xcodegen unless `project.yml` changed.

---

## macosicons.com API

**Endpoint:** `POST https://api.macosicons.com/api/v1/search`

**Headers:**
```
Content-Type: application/json
x-api-key: <stored in @AppStorage("macosIconsApiKey")>
```

**Request body:**
```json
{
  "query": "Safari",
  "searchOptions": {
    "hitsPerPage": 20,
    "page": 1
  }
}
```

**Response shape** (exact field names — these differ from Algolia defaults):
```json
{
  "hits": [
    {
      "objectID":    "sD4DFzTv78",
      "appName":     "Chrome",
      "icnsUrl":     "https://s3.macosicons.com/...icns",
      "lowResPngUrl":"https://s3.macosicons.com/...png",
      "iOSUrl":      "https://s3.macosicons.com/...png",
      "category":    "joml1zA4lv",
      "usersName":   "Jason",
      "credit":      "https://twitter.com/...",
      "uploadedBy":  "https://macosicons.com/#/u/Jason",
      "downloads":   207,
      "timeStamp":   1618405335028
    }
  ],
  "query":           "Chrome",
  "totalHits":       209,
  "hitsPerPage":     50,
  "page":            1,
  "totalPages":      5,
  "processingTimeMs":1
}
```

**Critical field mappings:**
| API field | Maps to | Used for |
|---|---|---|
| `icnsUrl` | `IconResult.icnsUrl` | **Icon replacement** (only this URL is downloaded/applied) |
| `lowResPngUrl` | `IconResult.lowResPngUrl` | Thumbnail preview in grid only — never written as replacement |
| `usersName` | `IconResult.creatorName` | Display ("by Jason") |
| `credit` | `IconResult.creditUrl` | A URL (e.g. Twitter), not a name |
| `objectID` | `IconResult.id` | Stable identity for deduplication and checkmark state |
| `iOSUrl` | decoded, discarded | Not used |

---

## Icon Replacement

Uses the `fileicon` CLI (`/opt/homebrew/bin/fileicon` on Apple Silicon).

**Strategy in `IconReplacementService`:**
1. **Direct call** — `Process.run(fileicon, ["set", appPath, icnsPath])` — works for user-owned apps, no password prompt
2. **Privileged fallback** — `Process.runPrivileged("fileicon set ...")` via `osascript do shell script ... with administrator privileges` — only triggered if direct call returns non-zero exit code

**Why not always use osascript?**
`osascript` runs in a clean shell environment without `/opt/homebrew/bin` in `PATH`. Even with the full path to `fileicon`, the binary can fail when run as root because Homebrew-installed tools sometimes depend on the user environment. Direct execution avoids this entirely for user-owned apps (the common case).

**After replacement:**
```swift
touch <app.bundle>       // invalidates Dock/Launchpad icon cache
killall Dock             // forces Dock to re-read icon
```

**Restore:** `fileicon rm <app.bundle>` + touch + killall Dock + delete SQLite mapping

---

## Persistence (SQLite)

File: `~/Library/Application Support/IconSwap/db.sqlite`

Table `icon_mappings`:

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PK | UUID |
| `bundle_identifier` | TEXT UNIQUE | e.g. `com.google.Chrome` |
| `app_name` | TEXT | |
| `app_bundle_url` | TEXT | full path at time of replacement |
| `icon_object_id` | TEXT | `IconResult.id` (objectID from API) |
| `icns_url` | TEXT | remote URL, for re-download if local file lost |
| `local_icns_path` | TEXT | path in IconCache dir |
| `applied_date` | REAL | Unix timestamp |
| `last_verified_date` | REAL | updated by AppUpdateMonitor |
| `app_version` | TEXT | CFBundleShortVersionString at replacement time |

`PersistenceService` is a singleton (`PersistenceService.shared`) with a serial `DispatchQueue` for thread safety. All writes are async (`queue.async`); reads are sync (`queue.sync`).

---

## Key Gotchas & Decisions

### Swift 6 / macOS 13 Compatibility
- `onChange(of:)` with **two parameters** requires macOS 14 — use the **single-param** form: `.onChange(of: value) { newValue in ... }`
- `FSEventStreamSchedule` is deprecated on macOS 13 — use `FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)`
- `NSImage` `Sendable` conformance only available on macOS 14+ — expect warnings on macOS 13 target, safe to suppress
- `foregroundStyle(.red)` type inference fails in some contexts — use `.foregroundColor(Color.red)` instead

### App Update Monitor
Uses `FSEventStreamCreate` with `FSEventStreamSetDispatchQueue`. The `eventPaths` callback parameter is a `CFArray` of C strings — access via `unsafeBitCast` to `UnsafeMutablePointer<UnsafePointer<CChar>?>` (see `AppUpdateMonitor.swift`). Also has a 30-minute fallback poll timer.

### Xcode Project Regeneration
After editing `project.yml`, run `/opt/homebrew/bin/xcodegen generate`. The `.xcodeproj` is fully derived from `project.yml` — never edit `project.pbxproj` manually.

### Icon Cache Filenames
`IconDownloadService` derives filenames from `abs(icnsUrl.absoluteString.hashValue)` — produces stable `.icns` filenames without special chars. Cache is at `~/Library/Application Support/IconSwap/IconCache/`.

### Entitlements
Only `com.apple.security.network.client: true`. No sandbox key — omitting it disables sandboxing. This is required to:
- Write to `/Applications/*.app` bundles
- Execute `fileicon` via `Process`
- Watch FSEvents on arbitrary paths

---

## Settings (@AppStorage Keys)

| Key | Type | Default | Description |
|---|---|---|---|
| `macosIconsApiKey` | String | `""` | macosicons.com API key |
| `autoReapplyOnUpdate` | Bool | `true` | Re-apply icons on app update detection |
| `showLegacyWarnings` | Bool | `true` | Show ⚠ badge for non-Retina icons |

---

## Logging

All logging via `os.Logger`. View in Console.app, filter by subsystem `com.iconswap`.

| Logger | Category | Used in |
|---|---|---|
| `AppLogger.scanner` | `scanner` | AppScannerService |
| `AppLogger.api` | `api` | IconAPIService |
| `AppLogger.download` | `download` | IconDownloadService |
| `AppLogger.replace` | `replace` | IconReplacementService |
| `AppLogger.monitor` | `monitor` | AppUpdateMonitor |
| `AppLogger.persist` | `persist` | PersistenceService |
