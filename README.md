# Sonarpad Mobile

**Sonarpad Mobile** is the mobile companion to Sonarpad: an accessibility-focused Flutter application for reading documents, listening to media, following news and podcasts, searching routes, discovering radio stations, and consulting cinema information.

The project is designed around practical reading and listening workflows, with persistent resume points so documents, podcasts, and media can continue from where they were interrupted.

> **License Notice**
> This project is **source-available but NOT open source** and **NOT freeware**.
> Commercial use, redistribution, and derivative works are prohibited unless explicitly authorized in writing.

---

## Features

- **Document Reading**
  - Import and read documents from the mobile file system.
  - Create new documents directly in Sonarpad.
  - Organize documents in folders.
  - Import ZIP archives and expand them into the document library.
  - OCR support for documents that contain only images.
  - Dropbox import for browsing and importing files from a Dropbox account.

- **Bookmarks and Resume**
  - Save bookmarks in documents.
  - Automatically create a bookmark when reading is stopped, if enabled in settings.
  - Resume documents from the point where reading was interrupted.
  - Resume podcasts and media files from the previous playback position.

- **News Reading**
  - Read news and articles in a cleaner reading view.
  - Skip unnecessary web page blocks where possible.
  - Save or import readable content into the document workflow.

- **Podcasts**
  - Search podcasts by name.
  - Add podcasts from RSS feeds.
  - Import and export podcast subscriptions, including transfers from Sonarpad for Windows or Mac.
  - Play podcast episodes with position tracking.

- **Radio**
  - Search radio stations.
  - Use tolerant search, so partial station names can return results.
  - Save favorite stations.
  - Play audio streams and supported video streams.

- **Routes**
  - Search routes between places.
  - Choose route options such as walking, cycling, driving, or wheelchair where supported.
  - View route distance, duration, and navigation steps.

- **Cinema**
  - Browse movies currently playing in theaters.
  - Read movie plots.
  - Watch trailers when available.
  - Check upcoming movie releases.

- **Audio and Video Playback**
  - Play local audio and video files.
  - Open media shared from other apps.
  - Toggle video display for video content.
  - Convert audio and video files, for example MP3 to WAV or audio to MP4 with an image.

- **AIFA Medicines**
  - Search medicines from AIFA data.
  - Browse available packages and formulations.
  - Read leaflet sections such as usage, warnings, dosage, side effects, conservation, or the full leaflet.

- **Accessibility**
  - Built with accessibility as a core requirement.
  - Uses readable screens and mobile-friendly controls.
  - Supports workflows intended for screen-reader users.

- **Localization**
  - Includes multilingual UI support.

---

## Tech Stack

- Flutter and Dart
- `just_audio` and `video_player` for media playback
- `shared_preferences` and local storage for user state
- PDF, EPUB, ZIP, OCR, RSS, and web content integrations
- Optional native/Rust components for selected platform features

---

## Build Instructions

Install Flutter and fetch dependencies:

```bash
flutter pub get
```

Run on a connected device or simulator:

```bash
flutter run
```

For iOS release builds, use macOS with Xcode.

---

## Legal and Licensing

This repository is published for transparency, evaluation, and personal use only.

### You may

- View and study the source code.
- Build and run the software for personal or evaluation purposes.

### You may not

- Use the software for commercial purposes.
- Redistribute the source code or binaries.
- Fork this repository for redistribution.
- Include this software in other products or projects.
- Create or distribute derivative works without written permission.

Refer to the `LICENSE` file for full terms.

---

## Author

**Ambrogio Riili**
