<p align="center">
  <img src="App/AppIcon.png" width="120" alt="Plink icon">
</p>

<h1 align="center">Plink</h1>

<p align="center">A tiny macOS menu bar app that converts HEIC/HEIF photos to JPG.<br>Drag them in — JPGs <em>plink</em> onto your Desktop.</p>

---

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

[MIT](LICENSE) © Nick Lafferty
