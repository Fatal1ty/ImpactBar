<p align="center">
  <img src="docs/images/app-icon.png" width="128" height="128" alt="ImpactBar app icon">
</p>

<h1 align="center">ImpactBar</h1>

<p align="center">
  Turret hit quality and capacitor pressure, at a glance.<br>
  <sub>A native macOS combat-log overlay for EVE Online.</sub>
</p>

<p align="center">
  <a href="#-download">Download</a> ·
  <a href="#-quick-start">Quick start</a> ·
  <a href="#-features">Features</a> ·
  <a href="#-build-from-source">Build from source</a>
</p>

<p align="center">
  <a href="https://github.com/Fatal1ty/ImpactBar/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/Fatal1ty/ImpactBar/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/Fatal1ty/ImpactBar/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/Fatal1ty/ImpactBar"></a>
  <img alt="macOS 13 or later" src="https://img.shields.io/badge/macOS-13%2B-black?logo=apple">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
</p>

<p align="center">
  <img src="docs/images/turret-overlay.gif" width="364" height="20" alt="Animated demonstration of the ImpactBar turret hit-quality overlay"><br>
  <sub>Turret hit-quality overlay</sub>
</p>

<p align="center">
  <img src="docs/images/neutralizer-overlay.gif" width="364" height="68" alt="Animated demonstration of the ImpactBar energy-neutralizer overlay"><br>
  <sub>Energy-neutralizer overlay</sub>
</p>

ImpactBar puts two small overlays above EVE, so you can follow your turret application and neutralizer results during a fight. Move them where you want, enable each feature independently, and control everything from the macOS menu bar.

It reads new combat-log lines from `~/Documents/EVE/logs/Gamelogs` and processes them locally.

## 📦 Download

Download the latest macOS archive from [GitHub Releases](https://github.com/Fatal1ty/ImpactBar/releases/latest), unzip it, and move `ImpactBar.app` to `Applications`.

**Requires macOS 13 or later.** Release archives include both Apple Silicon and Intel binaries.

Current public builds are ad-hoc signed because the project does not yet use an Apple Developer ID. On first launch, macOS may block the app. Open **System Settings → Privacy & Security**, locate the ImpactBar message, and choose **Open Anyway**. Allow access to Documents if prompted so ImpactBar can read EVE logs.

## 🚀 Quick start

1. Launch `ImpactBar.app` and open its crosshair icon in the menu bar.
2. Select the character whose combat log you want to follow.
3. Enable **Turret Hit Quality**, **Energy Neutralizers**, or both.
4. Choose **Move Overlays**, drag the panels into position, and select **Finish Moving Overlays**.
5. Try **Testing → Turret Overlay** or **Testing → Neutralizer Overlay** to preview the panels before a fight.

ImpactBar starts at the end of the selected log, so launching the app or changing characters does not replay earlier combat. EVE combat logging must be enabled.

## ✨ Features

### 🎯 Turret hit quality

A slim bar shows a normalized rolling average of your last ten outgoing turret results. Its length and color change with hit quality, making changes in application visible while you watch the fight.

- **Smooth feedback.** Colors blend continuously between hit-quality thresholds.
- **Misses stay visible.** A miss contributes zero to the average, with a small activity marker to show that a shot occurred.
- **A little celebration for `Wrecks`.** A short double border pulse highlights the hit. Wrecking hits stay outside the rolling average.
- **Flexible placement.** Choose a horizontal bar or a bottom-to-top vertical bar.
- **A fresh average for each engagement.** The window resets on target, character, or game-session changes, on undocking, and after 30 seconds without a turret event.

Lasers, blasters, railguns, autocannons, artillery, and entropic disintegrators are supported. Missiles, drones, and incoming damage are ignored.

### ⚡ Energy neutralizers

The neutralizer panel follows one target at a time. The lightning bolt and three activity segments take on the color of the current state.

For a display such as **`150 GJ · 321 GJ`**, the left number is the latest volley and the right number is the total drained from the current target. Synchronous module events within two seconds are added together for the volley display.

<table>
  <thead>
    <tr><th width="120">State</th><th>What it tells you</th></tr>
  </thead>
  <tbody>
    <tr>
      <td width="120" nowrap><img src="docs/images/state-draining.svg" width="120" height="30" alt="DRAINING"></td>
      <td>Neutralization is underway.</td>
    </tr>
    <tr>
      <td width="120" nowrap><img src="docs/images/state-dry.svg" width="120" height="30" alt="DRY"></td>
      <td>A zero-GJ event was observed while draining or recovering, or as the first event.</td>
    </tr>
    <tr>
      <td width="120" nowrap><img src="docs/images/state-pinned.svg" width="120" height="30" alt="PINNED"></td>
      <td>A low drain was observed, or a zero-GJ event followed <code>DRY</code> or <code>PINNED</code>.</td>
    </tr>
    <tr>
      <td width="120" nowrap><img src="docs/images/state-recovered.svg" width="120" height="30" alt="RECOVERED"></td>
      <td>A sufficiently large drain was observed after <code>DRY</code> or <code>PINNED</code>.</td>
    </tr>
  </tbody>
</table>

The bright segment advances with each new volley and wraps after the third segment. Dimmer segments show recent activity. The segments indicate incoming results without estimating the target's capacitor capacity.

**Sound cues:** celebrate `DRY` with **Glass** and hear **Submarine** on `RECOVERED`. Both cues have independent enable and test controls under **Sounds → Neutralizers**.

<details>
<summary>How state detection and resets work</summary>

State detection evaluates each module event as it arrives, even when multiple events share one displayed volley.

- The first positive drain establishes the current ceiling and the highest observed single drain for the target.
- A positive result at or below **50% of the current ceiling** immediately gives `PINNED`.
- A result above that threshold can update the ceiling or signal recovery when it reaches at least **75% of the highest observed single drain**. A new maximum raises both values.
- Intermediate results keep the previous state. Zero-GJ events use the `DRY` / `PINNED` rules shown above.
- The ceiling is shared across modules for the current target. Modules with different drain strengths can therefore affect state detection. Results are most predictable with similarly sized modules operating inside optimal range.
- Target data clears on target, character, or game-session changes, on undocking, on a target-gone notification, and after **10 minutes without a neutralizer event**.

With **Hide When Idle** disabled, cleared values appear as **`— GJ · — GJ`**. Hiding an idle panel happens earlier and preserves its data until a reset occurs.

</details>

### Made for macOS

- Always-on-top overlays, including full-screen EVE.
- Automatic active-log discovery and character selection.
- Independent feature toggles and saved overlay positions.
- Menu-bar controls for movement, visibility, appearance, orientation, testing, and sounds.
- A menu-bar app with no Dock icon or persistent main window.

## 🛠️ Troubleshooting

<details>
<summary>No characters are listed</summary>

Make sure EVE combat logging is enabled and that a game log created within the last 24 hours exists in `~/Documents/EVE/logs/Gamelogs`. Use **Open Logs Folder** from the ImpactBar menu to inspect the directory.

</details>

<details>
<summary>An overlay is missing</summary>

Check that its feature is enabled, choose **Show Overlays**, and use **Reset All Overlay Positions…** if it may be outside the visible screen area. Check **Hide When Idle** if the panel disappears between fights.

</details>

<details>
<summary>Sounds are silent</summary>

Check both **Sounds → Enable Sounds** and **Sounds → Neutralizers → Enable Neutralizer Sounds**. Dry and recovered cues can also be enabled and tested independently.

</details>

## 🔧 Build from source

Requirements:

- macOS 13 or later.
- Xcode Command Line Tools with Swift 6 or later.

Build and launch a native-architecture app:

```sh
scripts/build-app.sh
open dist/ImpactBar.app
```

Build an ad-hoc signed universal release archive:

```sh
scripts/package-release.sh
```

Run the test suite:

```sh
swift test --disable-sandbox
```

The release workflow publishes tagged versions as universal macOS archives. Developer ID signing and notarization are intentionally deferred until an Apple Developer Program identity is available.

## 🔒 Privacy

ImpactBar processes EVE combat logs locally. It does not transmit log contents, collect analytics, or make network requests. Character names are only read from local log headers to let the user choose the active log.

## 🤝 Contributing

Bug reports and focused pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a change. Security-sensitive reports should follow [SECURITY.md](SECURITY.md).

## Disclaimer

ImpactBar is an independent, fan-made utility. It is not affiliated with or endorsed by Fenris Creations. Third-party software is used at the player's own risk; review the current [EVE Online third-party policies](https://support.eveonline.com/hc/en-us/articles/8564030965660-Third-Party-Policies) before use.

## License

ImpactBar is available under the [MIT License](LICENSE).
