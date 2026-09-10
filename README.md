<div align="center">

  <img src="assets/images/app_logo.png" alt="Exalere Logo" width="130" />

  # Exalere

  ### Next-Generation Cross-Platform Media Hub & Streaming Client

  <p align="center">
    <b>Crafted with Flutter for Android Mobile, Android TV, and Windows Desktop.</b>
  </p>

  <!-- Live Dynamic Shields -->
  <p align="center">
    <a href="https://github.com/Abhishekrazy/Exalere/stargazers">
      <img src="https://img.shields.io/github/stars/Abhishekrazy/Exalere?style=for-the-badge&logo=github&color=FFB800" alt="GitHub Stars" />
    </a>
    <a href="https://github.com/Abhishekrazy/Exalere/network/members">
      <img src="https://img.shields.io/github/forks/Abhishekrazy/Exalere?style=for-the-badge&logo=github&color=blue" alt="GitHub Forks" />
    </a>
    <a href="https://github.com/Abhishekrazy/Exalere/issues">
      <img src="https://img.shields.io/github/issues/Abhishekrazy/Exalere?style=for-the-badge&color=red" alt="Open Issues" />
    </a>
    <a href="LICENSE">
      <img src="https://img.shields.io/badge/License-PolyForm%20Noncommercial-00C853?style=for-the-badge" alt="License" />
    </a>
    <a href="https://github.com/Abhishekrazy/Exalere/actions/workflows/ci.yml">
      <img src="https://img.shields.io/github/actions/workflow/status/Abhishekrazy/Exalere/ci.yml?branch=main&style=for-the-badge&logo=githubactions&logoColor=white&label=CI%20Build" alt="CI Status" />
    </a>
  </p>

  <!-- Quick Action & Release Buttons Distinct by Platform -->
  <p align="center">
    <a href="https://github.com/Abhishekrazy/Exalere/releases/latest/download/Exalere-AndroidTV-Leanback.apk">
      <img src="https://img.shields.io/badge/Android%20TV%20Build-Direct%20Download-FF5722?style=for-the-badge&logo=android&logoColor=white" alt="Direct Android TV Download" />
    </a>
    <a href="https://github.com/Abhishekrazy/Exalere/releases/latest/download/Exalere-Android-Mobile-Universal.apk">
      <img src="https://img.shields.io/badge/Mobile%20Build-Direct%20Download-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Direct Mobile Download" />
    </a>
    <a href="https://github.com/Abhishekrazy/Exalere/releases/latest/download/Exalere-Windows-Setup-x64.exe">
      <img src="https://img.shields.io/badge/Windows%20Setup%20(Installer)-Direct%20Download-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Direct Windows Setup Download" />
    </a>
    <a href="https://github.com/Abhishekrazy/Exalere/releases/latest/download/Exalere-Windows-Portable-x64.zip">
      <img src="https://img.shields.io/badge/Windows%20Portable%20(.zip)-Direct%20Download-00A4EF?style=for-the-badge&logo=windows&logoColor=white" alt="Direct Windows Portable Download" />
    </a>
  </p>

  <p align="center">
    <a href="https://abhishekrazy.github.io/Exalere/">
      <img src="https://img.shields.io/badge/Official%20Website-Live%20Preview-00C853?style=for-the-badge&logo=googlechrome&logoColor=white" alt="Official Website" />
    </a>
    <a href="https://github.com/users/Abhishekrazy/projects">
      <img src="https://img.shields.io/badge/GitHub%20Projects-Interactive%20Roadmap-8A2BE2?style=for-the-badge&logo=github" alt="Project Roadmap" />
    </a>
    <a href="https://komarev.com/ghpvc/?username=Abhishekrazy-Exalere&label=Project+Views&color=0e75b6&style=for-the-badge">
      <img src="https://komarev.com/ghpvc/?username=Abhishekrazy-Exalere&label=Project+Views&color=0e75b6&style=for-the-badge" alt="Project Views" />
    </a>
  </p>

</div>

---

## 📑 Table of Contents

- [Overview](#-overview)
- [Supported Platforms](#-supported-platforms)
- [Key Features](#-key-features)
- [Backend Data & Streaming Architecture](#-backend-data--streaming-architecture)
- [Project Roadmap & GitHub Projects](#-project-roadmap--github-projects)
- [Platform Downloads (TV vs Mobile vs Windows)](#-platform-downloads-tv-vs-mobile-vs-windows)
- [Getting Started & Installation](#-getting-started--installation)
- [Branching Strategy](#-branching-strategy)
- [Contributing & Code of Conduct](#-contributing--code-of-conduct)
- [AI Contributor Rules & Antigravity Skills](#-ai-contributor-rules--antigravity-skills)
- [Top Contributors & Community](#-top-contributors--community)
- [License & Non-Commercial Notice](#-license--non-commercial-notice)

---

## 🌟 Overview

**Exalere** is an all-in-one, open-source streaming entertainment hub designed from the ground up to offer a seamless cinematic experience across mobile phones, desktop computers, and TV screens. 

Whether you are browsing trending movies on Windows or leaning back with an Android TV D-Pad remote on your couch, Exalere adapts its typography, focus cues, and controls to give you a fluid, native UI.

---

## 📱 Supported Platforms

| Platform | Support Status | Optimized For | Min Requirements |
| :--- | :---: | :--- | :--- |
| **Android TV / Google TV / Fire TV** | 🟢 Official | D-Pad Remote Focus, 10-foot UI, Leanback Mode | Android 7.0+ (API 24) |
| **Android Mobile & Tablet** | 🟢 Official | Touch gestures, responsive drawers, portrait/landscape | Android 7.0+ (API 24) |
| **Windows Desktop (x64)** | 🟢 Official | Keyboard shortcuts, resizable window, hardware acceleration | Windows 10/11 64-bit |

---

## ✨ Key Features

- 📺 **Native Android TV Support**: Built-in `TvFocusable` components, ambient backdrop changes on hover, D-Pad directional navigation, and on-screen remote-friendly player controls.
- 🎬 **Multi-Source Video Engine**: Powered by `media_kit` (libmpv backend) with hardware video decoding, dual audio tracks, embedded subtitles, and seamless external player handoff (VLC / Just Player).
- 📡 **IPTV & Live Channels**: Stream live TV channels with category filtering and persistent custom M3U playlist storage.
- 🎨 **Adaptive Themes**: Dynamic cinematic palettes, glassmorphism badges, and smooth carousels that render at 60/120 FPS.
- 🗂️ **Personal Library**: Track your watch history, resume playback where you left off, and curate your personalized watchlist.

---

## 🏗️ Backend Data & Streaming Architecture

Exalere combines real-time streaming resolution with structured media metadata:

```mermaid
graph TD
    A[Exalere UI Client] --> B[TMDB Metadata Engine]
    A --> C[Multi-Source Stream Decoders]
    A --> D[Custom IPTV Provider]

    B -->|Posters, Cast, Synopsis| E[(TMDB API v3)]
    C -->|High-Speed Resolvers| F[Direct Video Streams / HLS / MP4]
    D -->|M3U / Live Channels| G[Global IPTV Feeds]

    F --> H[media_kit Video Engine / External Players]
```

- **Metadata Services**: Powered by [The Movie Database (TMDB)](https://www.themoviedb.org/) for rich posters, cast listings, release dates, ratings, and plot summaries.
- **Playback Backend**: Powered by [libmpv / media_kit](https://github.com/media-kit/media-kit) for high-performance multi-platform rendering.
- **Provider Decoders**: Custom providers for movie streams and TV series sources with fallback resolution.

---

## 📋 Project Roadmap & GitHub Projects

We track upcoming milestones, sprint tasks, and requested features using the **[Exalere GitHub Project Board](https://github.com/users/Abhishekrazy/projects)**:

- 📌 **Backlog**: Triage and community feature ideas.
- 🚀 **In Progress**: Active work in the `develop` branch.
- 🧪 **Testing**: Builds undergoing verification in `staging`.
- ✅ **Done**: Merged to `main` and tagged for release.

---

## 📥 Platform Downloads (TV vs Mobile vs Windows)

Exalere provides specialized binaries optimized for each target environment:

| Platform Target | Recommended Package | Direct Download Link | Details |
| :--- | :--- | :--- | :--- |
| 📺 **Android TV / Fire TV** | `Exalere-AndroidTV-Leanback.apk` | [⬇️ Download Android TV Build](https://github.com/Abhishekrazy/Exalere/releases/latest/download/Exalere-AndroidTV-Leanback.apk) | Dedicated leanback launcher banner, 10-ft remote focus & D-Pad support |
| 📱 **Android Mobile & Tablet** | `Exalere-Android-Mobile-Universal.apk` | [⬇️ Download Mobile Build](https://github.com/Abhishekrazy/Exalere/releases/latest/download/Exalere-Android-Mobile-Universal.apk) | Touch controls, gesture navigation & responsive mobile UI |
| 💻 **Windows (Setup Installer)** | `Exalere-Windows-Setup-x64.exe` | [⬇️ Download Windows Setup](https://github.com/Abhishekrazy/Exalere/releases/latest/download/Exalere-Windows-Setup-x64.exe) | Modern Windows installation wizard with Desktop & Start menu shortcuts |
| 💻 **Windows (Portable .zip)** | `Exalere-Windows-Portable-x64.zip` | [⬇️ Download Windows Portable](https://github.com/Abhishekrazy/Exalere/releases/latest/download/Exalere-Windows-Portable-x64.zip) | Standalone portable 64-bit Windows executable & runtime (no install needed) |

You can also view all historical versions on our [Releases Page](https://github.com/Abhishekrazy/Exalere/releases).

---

## 🛠️ Getting Started (Local Development)

### 1. Clone & Setup
```bash
git clone https://github.com/Abhishekrazy/Exalere.git
cd Exalere
flutter pub get
```

### 2. Run Locally
```bash
# Run on Windows Desktop
flutter run -d windows

# Run on Android Device / TV Emulator
flutter run -d <device_id>
```

### 3. Remote Testing for TV Emulators
When testing on an Android TV emulator without a physical remote, use the included interactive keyboard controller:
```powershell
.\tv_remote.ps1
```

---

## 🌿 Branching Strategy

To keep releases rock-solid, Exalere enforces a structured multi-branch workflow:

- `main`: **Production releases**. Only receives fast-forward merges from `staging` or urgent hotfixes.
- `staging`: **Pre-release & QA**. Used for automated smoke tests and manual testing before launching to `main`.
- `develop`: **Active integration**. All feature branches and community PRs merge here.
- `feature/*` & `bugfix/*`: **Short-lived working branches** branched from and merged back into `develop`.

---

## 🤖 AI Contributor Rules & Antigravity Skills

We embrace contributors using modern AI coding agents (Google Antigravity, Gemini Code Assist, GitHub Copilot, Claude, Cursor). To ensure AI-generated PRs match our architecture, this repository tracks dedicated agent instructions and skills directly in git:

- **Global Rules**: Review [`AGENTS.md`](AGENTS.md) for architectural rules, TV focus requirements, and provider state practices.
- **Reusable Agent Skills**: Check [`.agents/skills/exalere-contributor/`](.agents/skills/exalere-contributor/SKILL.md) for automated runbooks, validation steps, and tests.
- **Verification Rule**: All AI-generated code **must** be validated by the submitter using `flutter analyze` and manual runtime checks before opening a PR.

---

## 🤝 Contributing & Code of Conduct

We love community contributions! Please review our core documents:
- 📖 [Contributing Guidelines](CONTRIBUTING.md)
- 📜 [Code of Conduct](CODE_OF_CONDUCT.md)
- 🔒 [Security Policy](SECURITY.md)

---

## 👥 Top Contributors

Thank you to everyone making Exalere better every day! 

<p align="center">
  <a href="https://github.com/Abhishekrazy/Exalere/graphs/contributors">
    <img src="https://contrib.rocks/image?repo=Abhishekrazy/Exalere&max=10&columns=10" alt="Exalere Top 10 Contributors" />
  </a>
</p>

### Activity & Repository Metrics
<p align="center">
  <img src="https://github-readme-stats.vercel.app/api/pin/?username=Abhishekrazy&repo=Exalere&theme=tokyonight&show_owner=true" alt="Exalere Repo Card" />
</p>
<p align="center">
  <img src="https://github-readme-streak-stats.herokuapp.com/?user=Abhishekrazy&theme=tokyonight&hide_border=true" alt="GitHub Streak" />
</p>

---

## 📜 License & Legal Disclaimers

This project is licensed under the **[PolyForm Noncommercial License 1.0.0](LICENSE)**.

- ✅ **Free for Personal, Community, and Educational Use**: You are welcome to view, run, modify, fork, and contribute back improvements.
- ❌ **Commercial Use Prohibited**: Selling, offering commercial services, or bundling this application/code into monetized products is strictly forbidden.
- ⚖️ **Terms of Use & DMCA Notice**: Please review the [Terms of Use & Content Disclaimer](https://abhishekrazy.github.io/Exalere/terms.html). Exalere does not host, store, or stream media; all content is fetched dynamically from third-party public web providers and TMDB.
- 🔒 **Privacy Policy**: Exalere does not collect telemetry or track personal user data. Read our transparent [Privacy Policy](https://abhishekrazy.github.io/Exalere/privacy.html).

Copyright (c) 2026 Abhishek Razy and Exalere Contributors. All rights reserved.
