# Spacer — Free macOS Disk Space Analyzer

**A simple, free, open-source utility for checking free disk space and finding large folders on a Mac.**

Spacer is a native **macOS disk usage analyzer and folder size viewer**. It shows available storage, sorts files and folders by size, and visualizes the current folder and its subfolders in a two-level circular chart. Use it to answer “What is taking up space on my Mac?” and review potential cleanup candidates before moving selected items to Trash.

**[Download the ready-to-run DMG](https://github.com/cnc-club/MacOS-Spacer/releases/latest)** · [How to run](#run-the-ready-made-app--no-build-required) · [MIT license](LICENSE)

No subscription, ads, account or file-list uploads. Spacer works locally on your Mac. It does not delete anything automatically.

| Quick facts | |
| --- | --- |
| App name | Spacer; repository name: MacOS-Spacer |
| Purpose | Check free disk space, inspect folder sizes and visualize disk usage on macOS |
| Price | Free; no subscription |
| License | MIT, free and open-source software |
| Ready-made download | One DMG for Apple Silicon (M1 or later), macOS 13+ |
| Installation | Run directly from the DMG, or copy Spacer.app to any folder |
| Languages | English and Russian |
| Technology | Native Swift and SwiftUI |
| Privacy | Local analysis; no account or server required |

![Spacer free disk space display and folder navigation on macOS](docs/screenshots/disk-usage.png)

## Features

- Free space and total capacity for the current volume, refreshed every 30 seconds.
- A folder tree from the disk root, clickable path breadcrumbs, and keyboard navigation.
- Two chart rings: the current folder’s contents and one more level of subfolders.
- Search by name or path, size sorting, and cleanup suggestions with explanations.
- A quick initial folder listing while sizes are calculated in the background.
- Saved scan results for faster navigation during the current session.
- English by default, with Russian available from the language menu.
- Selected items move to macOS Trash only after confirmation. Nothing is automatically deleted.

## Screenshots

Real app captures with sample files. The surrounding area is transparent PNG; the interface and text have not been regenerated.

### Folder sizes and clickable navigation

![Spacer macOS folder size viewer with clickable path navigation](docs/screenshots/folder-navigation.png)

### Review cleanup suggestions

![Spacer cleanup suggestions for old installers and archives in Downloads](docs/screenshots/cleanup-suggestions.png)

## Run the ready-made app — no build required

Open the supplied **Spacer-0.2.0-macOS-arm64.dmg**, then double-click **Spacer.app** inside it. The app runs directly from the disk image; you do not need Swift, Xcode, Terminal or an installation step. You can also copy it to Applications or another folder and run it there.

This DMG is for **Apple Silicon (M1 or later), macOS 13+**. English, Russian and the MIT license are bundled in the app. It is locally signed but not Apple-notarized, so macOS may ask you to approve opening it. Copy it to a stable location before granting Full Disk Access. Quit Spacer before ejecting the image.

## Build from source

Requirements: **macOS 13 or later** and **Apple Command Line Tools with Swift 5.9 or later**. These steps build an app for your Mac’s architecture.

1. Download this repository, or clone it:

   ```sh
   git clone https://github.com/cnc-club/MacOS-Spacer.git
   cd MacOS-Spacer
   ```
2. Open Terminal in the project folder. If Command Line Tools are not installed, run `xcode-select --install` and complete Apple's installer.
3. Build the application:

   ```sh
   chmod +x build-app.sh check.sh package-dmg.sh
   ./build-app.sh
   ```

4. In Finder, open the `dist` folder and drag **Spacer.app** into **Applications**.
5. Open Spacer from Applications, then click **Choose folder…** or **Scan disk**.

The build script signs the app locally. It is not Developer ID signed or notarized; macOS may ask you to approve opening a locally built app. The application and its language resources are contained in `Spacer.app` and do not require the source folder after installation.

To run from source without installing:

```sh
swift run Spacer
```

For a faster development build:

```sh
./build-app.sh debug
```

To create a single compressed disk image for your Mac:

```sh
./package-dmg.sh
```

The image and its SHA-256 checksum are written to `dist/`. A packaged app can verify its language resources without relying on the source directory:

```sh
dist/Spacer.app/Contents/MacOS/Spacer --verify-bundle
```

### Access to protected folders

Some macOS folders require extra permission. If necessary, add **Applications/Spacer.app** in **System Settings → Privacy & Security → Full Disk Access**, then quit and reopen Spacer. macOS may still restrict some system locations. The app does not request an administrator password or change permissions itself. Inaccessible items are counted in the status bar.

## Use

Choose a folder or scan the disk from `/`. The list appears first; unknown sizes show `…` until the scan finishes. You can browse elsewhere while a scan is running: the previous scan is cancelled, and its late results cannot overwrite the new view.

Click a folder in the tree, a breadcrumb, or a chart sector to navigate. Click a file to reveal it in Finder. Click a tree row to focus keyboard navigation:

| Key | Action |
| --- | --- |
| ↑ / ↓ | Move through visible folders |
| → | Expand a branch, or select its first child |
| ← | Collapse a branch, or select its parent if already collapsed |

Choose **English** or **Русский** from the language menu. This changes Spacer's labels, explanations, status messages and size formatting without restarting or losing your current scan. System dialogs, operating-system error messages, disk names and filenames retain their own language.

## Cleanup suggestions and limits

Suggestions are prompts for review, not proof that a file is unnecessary:

- Caches unchanged for more than 30 days: quit the related app before cleanup.
- Logs older than 30 days: they may still help with troubleshooting.
- Old installers and archives in Downloads: check that their contents are installed or saved elsewhere.

The 30-day threshold is a project heuristic, not an Apple rule. A modification date is not a last-used date. Large files, old personal documents, photos and applications are not labelled unnecessary based on size or age alone. Duplicate detection is not implemented.

Deletion is intentionally limited to eligible items inside your home folder. Standard top-level home folders, Library and paths outside home are protected from deletion in this version; they can still be analysed. Spacer does not empty Trash. Moving items to Trash does not free space until you empty it yourself.

Sizes are logical file sizes. APFS clones, hard links, compression, cloud placeholders and snapshots can make actual disk usage or recovered space different. Symlinks are not traversed. App packages and libraries are shown as single objects. A scan from `/` excludes `/dev` and `/System/Volumes` to avoid device traversal and counting the same data volume twice; explicit scans of individual folders are still available. These exclusions and access errors are counted separately.

Background: [Apple storage management](https://support.apple.com/guide/mac-help/change-storage-settings-mchl3d437fbc/mac), [cache directories](https://developer.apple.com/documentation/foundation/using-the-file-system-effectively), and [freeing disk space](https://support.apple.com/en-sg/102624).

## Frequently asked questions

### How do I see what is taking up space on my Mac?

Open Spacer, choose a folder or click **Scan disk**, and wait for sizes to finish calculating. The file list is sorted by size. The inner chart ring shows the current folder’s contents; the outer ring shows one more level. Click a folder or chart sector to explore it.

### Is Spacer a free disk analyzer for macOS?

Yes. Spacer is free and open source under the MIT license. It includes free-space reporting, a folder size viewer, a disk usage chart and reviewable cleanup suggestions, with no subscription or account.

### Do I need to compile Spacer or install Xcode?

No, when using the ready-made DMG. Open the image and launch **Spacer.app** directly. Xcode Command Line Tools are needed only to build the source code yourself.

### Does Spacer clean my Mac automatically?

No. Spacer helps you inspect disk usage and review possible cleanup candidates. Only items you select are moved to Trash, and only after confirmation. The app does not empty Trash, find duplicates or claim to identify every unnecessary file.

### Why are folder sizes different from the Mac’s free-space display?

Free space is reported by the filesystem for the selected volume. Folder totals are logical file sizes. APFS snapshots, clones, compression, hard links, inaccessible folders and cloud files can make these numbers differ. A full-disk scan is not a physical block accounting tool.

### Can Spacer replace a paid disk space visualizer?

Spacer provides a lightweight free option for browsing folder sizes and a two-level circular disk usage view. It focuses on transparent, manual review rather than automatic system cleaning or a subscription-based cleanup suite.

### Which Macs can run Spacer?

The ready-made DMG is for Apple Silicon Macs with macOS 13 or later. Source builds target the architecture of the Mac used to build them; an Intel DMG is not currently provided.

## Contributing and localization

Run the scanner checks with `./check.sh`. They use temporary fixtures and never delete your personal files. Tests cover sizes, sorting, cancellation, links, safe paths, fast lookup and free-space reporting. `python3 scripts/check-localizations.py` checks language keys and placeholders.

Translations live in `Sources/Spacer/Resources/<language>.lproj/Localizable.strings`. English phrases are stable keys; use `T("English phrase")` for app-owned UI strings and `%@` placeholders for values. Suggestions store keys, not rendered translations. See [the localization guide](docs/LOCALIZATION.md) to add another language.

## License

Spacer is free and open-source software under the [MIT License](LICENSE). You can use, modify and redistribute it, including commercially, with the required copyright and license notice.
