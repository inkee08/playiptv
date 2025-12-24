# PlayIPTV

**PlayIPTV** is a modern, native macOS application designed for a premium IPTV experience. Built with SwiftUI and VLCKit, it supports both Xtream Codes and M3U playlists, offering a seamless and responsive interface for Live TV, Series, and Movies.

---

## ✨ Features

### 📺 Content Support
-   **Xtream Codes & M3U:** Full support for both major IPTV formats.
-   **Live TV:** Fast channel switching and category management.
-   **VOD (Series & Movies):** Dedicated browser for on-demand content with rich metadata.
-   **M3U Flattening:** Automatically organizes messy M3U lists into a clean "Live TV" structure.

### 🌟 Smart Management
-   **Favorites:** Separated **Favorites (Live)** and **Favorites (VOD)** lists to keep your best content organized.
-   **Recent History:** Automatically tracks your recently watched Series and Movies for quick resumption.
-   **Auto-Resume:** Remembers your last active source and automatically reconnects on launch.
-   **Series Progress:** Tracks watched episodes so you never lose your place.

### ⚡️ Player & UX
-   **Native macOS Interface:** Built with SwiftUI for a familiar, fast, and fluid experience.
-   **VLCKit Engine:** Robust playback support for virtually all stream formats and codecs.
-   **Modern UI:** Glassmorphism effects, dynamic sidebar, and intuitive navigation.

---

## 📦 Installation
Download the latest version from the **[Releases](../../releases)** page.

1.  Download the `.zip` file for your architecture (`arm64` for Apple Silicon).
2.  Unzip the file.
3.  Drag **PlayIPTV** to your `Applications` folder.

> **Note:** This app is ad-hoc signed. You may need to right-click and select "Open" the first time you run it.

---

## 🛠 Building from Source

### Prerequisites
-   **macOS** (latest recommended)
-   **Xcode** (for Swift compiler and developer tools)
-   **VLCKit** (Automatically handled by the build script)

### Build & Package Script
We provide a powerful `package_app.sh` script to handle dependencies, signing, icon generation, and packaging.

## 📄 License
[MIT](https://choosealicense.com/licenses/mit/)
