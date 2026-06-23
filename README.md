<p align="center">
  <img src="App/AppIcon.png" width="120" alt="Plink icon">
</p>

<h1 align="center">Plink</h1>

<p align="center">A tiny macOS menu bar app that converts HEIC/HEIF photos to JPG.<br>Drag them in — JPGs <em>plink</em> onto your Desktop.</p>

<p align="center">
  <a href="https://justplink.com"><b>Website</b></a> ·
  <a href="https://github.com/nicklafferty/plink/releases/latest"><b>Download</b></a> ·
  <a href="https://github.com/nicklafferty/plink/releases"><b>Releases</b></a>
</p>

<p align="center">
  <img src="https://img.shields.io/github/v/release/nicklafferty/plink?color=2b2b2e" alt="Latest release">
  <img src="https://img.shields.io/badge/platform-macOS%2012%2B-2b2b2e" alt="macOS 12+">
  <img src="https://img.shields.io/github/license/nicklafferty/plink?color=2b2b2e" alt="MIT License">
</p>

---

## Download

Grab the latest **signed & notarized** build from **[justplink.com](https://justplink.com)** or the
[releases page](https://github.com/nicklafferty/plink/releases/latest) — unzip and drag
`Plink.app` into your Applications folder. It opens with a normal double-click, no Gatekeeper
warnings. Prefer to compile it yourself? See [Build](#build).

## Features

- 🪶 **Tiny & native** — a single Swift file, no dependencies, pure system frameworks (AppKit + ImageIO).
- 🎯 **Drag & drop** — drop `.heic`/`.heif` onto the menu bar popover, or click to choose files.
- 🗂 **Finder Quick Action** — right-click HEIC files → **Quick Actions → Convert HEIC to JPG**.
- ⚡️ **Batch + progress** — converts multiple files at once with a live progress bar.
- 🖼 **Quality preserved** — keeps orientation metadata, exports at 92% JPEG quality.
- 📂 JPGs are saved to your **Desktop** by default; the **Reveal** button jumps straight to them.

## Requirements

- macOS 12 (Monterey) or later
- Xcode command line tools (`xcode-select --install`) to build from source

## Build

```sh
./build.sh
```

Produces the app bundle at `dist/Plink.app`.

## Install

```sh
./install.sh
```

The installer:

- copies the app to `/Applications/Plink.app`
- launches it and sets it to open at login
- installs the Finder Quick Action at `~/Library/Services/Convert HEIC to JPG.workflow`
- registers a fallback Finder service from the app bundle

## Usage

Click the droplet in the menu bar, then drop `.heic` or `.heif` files onto the popover (or click the drop zone to choose files). Converted JPGs land on your Desktop. Right-click the menu bar icon to quit.

You can also right-click HEIC files in Finder and choose **Quick Actions → Convert HEIC to JPG**.

## Installing a release

Prebuilt `Plink.zip` downloads from [Releases](../../releases) are **Developer ID
signed and notarized by Apple**, so they open with a normal double-click — just
unzip and drag `Plink.app` to `/Applications`.

Builds you make yourself with `./build.sh` are ad-hoc signed (no warning when run
locally). See [RELEASING.md](RELEASING.md) for how signed/notarized releases are
produced.

## Uninstall

```sh
rm -rf "/Applications/Plink.app"
rm -rf "$HOME/Library/Services/Convert HEIC to JPG.workflow"
```

Then remove **Plink** from **System Settings → General → Login Items** if you enabled launch-at-login.

## License

[MIT](LICENSE) © [Nick Lafferty](https://www.linkedin.com/in/nicklafferty)

---

<p align="center">
  <a href="https://justplink.com">justplink.com</a> ·
  <a href="https://github.com/nicklafferty/plink/releases">Releases</a> ·
  <a href="https://www.linkedin.com/in/nicklafferty">LinkedIn</a>
</p>
