# SoundBalancer 🎧

**English** | [Deutsch](README.de.md)

[![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Architecture-Apple%20Silicon%20(arm64)-lightgrey.svg)]()

**SoundBalancer** is a native, modern macOS menu bar application built with Swift 6 and SwiftUI in a sleek **Liquid Glass** aesthetic. It provides per-application volume mixing and instant input/output device switching — **without virtual audio drivers or kernel extensions**, powered by Apple's native **Core Audio Process Tap API** (macOS 15.0+).

---

## 🚀 Key Features & Solved Problems

### 1. Per-App Volume Mixer (0% to 400% Gain Boost, +12 dB)
* **Fix the WhatsApp vs. YouTube Disparity**: Voice messages or calls are frequently vastly louder than background web videos or music. SoundBalancer lets you dial in individual volume levels per app (e.g., lower WhatsApp or boost quiet Safari/YouTube streams up to 400%).
* **Call Passthrough & Voice Compensation**: Apps currently capturing microphone audio are automatically routed directly through macOS by default to preserve hardware echo cancellation during voice calls. Saved volume and mute preferences restore seamlessly once the call finishes. Voice communication apps outside calls receive automatic +6 dB mixdown compensation.
* **Native App Routing Toggle**: Any app can be toggled to route directly through macOS if specific Bluetooth peripherals or specialized software require bypassing Process Taps.
* **Hyperbolic Soft Limiter (`tanh`)**: Seamlessly absorbs volume spikes above 100% (+12 dB headroom), preventing harsh digital clipping and distortion.
* **Process Resolution**: Automatically maps helper processes (such as WhatsApp Helper, Chrome Helper, Electron renderers) back to their parent application with official app icons and names.
* **Instant Mute & Reset**: Toggle mute or return to default 100% volume with a single click.

### 2. Rapid Audio Device Switching (AirPods Call Quality Fix)
* **High-Fidelity Audio During Calls**: When AirPods connect, macOS often switches both input and output to AirPods during calls (Teams, WhatsApp, FaceTime), dropping audio into the low-bandwidth 16 kHz Bluetooth Handsfree profile.
* **The Solution**: Select **Output: AirPods** and **Input: Built-in MacBook Microphone** directly in SoundBalancer's menu bar. Your AirPods remain in pristine stereo AAC (44.1 / 48 kHz) while your voice is captured cleanly by the Mac.

### 3. Loudness Compensation for AirPods & Multichannel Outputs
* Avoids Core Audio attenuation on aggregate output devices through dynamic channel compensation.

### 4. Liquid Glass UI & Zero-Footprint
* Designed natively with SwiftUI using macOS `.ultraThinMaterial`, glassmorphism cards, and responsive custom sliders.
* **Zero Footprint**: Quitting SoundBalancer (`Cmd+Q` or the power icon) tears down all taps immediately. Audio instantly routes via the macOS default path. No background daemons, drivers, or system leftovers.

---

## 💻 System Requirements

* **OS**: macOS 15.0 (Sequoia) or newer
* **Architecture**: Apple Silicon (arm64)
* **Permission**: System Audio Recording permission (*System Settings > Privacy & Security > Screen & System Audio Recording*)

---

## 📦 Download & Installation

Pre-built binaries can be found in the [release](release/) directory:
* Download **[SoundBalancer-arm64.dmg](release/SoundBalancer-arm64.dmg)**
* Open the DMG and drag `SoundBalancer.app` into `/Applications`.

---

## 🛠️ Building from Source

### Prerequisites
* Xcode 16.0+ or Command Line Tools with Swift 6.0+

### Build Application Bundle
```bash
make app
```
The compiled, signed app bundle will be placed at `build/SoundBalancer.app`.

### Build Distribution DMG
```bash
make dmg
```
The DMG image will be created at `release/SoundBalancer-arm64.dmg`.

### Run
```bash
open build/SoundBalancer.app
```

> **Note on Permissions**: On initial launch, macOS will prompt for **Audio Capture / System Audio Recording** permissions so that Core Audio can intercept process streams for mixing.

---

## 🔒 Privacy & Architecture

* **100% Local**: SoundBalancer does not connect to the internet, make external network calls, or transmit telemetry.
* **Driverless**: Built exclusively on Apple's sanctioned user-space `CATapDescription` and `AudioHardwareCreateProcessTap` APIs. No kexts or system extensions required.

---

## 📄 License

SoundBalancer is open source software licensed under the [MIT License](LICENSE).
