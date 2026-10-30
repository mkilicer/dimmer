# Dimmer

Change your external monitor's brightness from the macOS menu bar, without touching the buttons on the monitor.

Dimmer talks to the monitor over DDC/CI, the same cable that carries the picture, so it changes the real backlight, not just a dark overlay. When the lowest backlight is still too bright, an extra software dim takes it further.

**[Download the latest release](https://github.com/mkilicer/dimmer/releases/latest)**

## Features

- **Brightness**: the monitor's real backlight, 0–100%.
- **Extra dimming**: software dim (gamma) for darker than the monitor's minimum. Undone when you quit.
- **Scroll on the menu bar icon** to change brightness in 5% steps. Below 0% it keeps going into the extra dim. No keyboard needed.
- **Presets**: Day, Evening, Night.
- **Launch at login**.
- Tiny: one Swift file plus DDC code, no dependencies, no network, no tracking.
- Languages: English, Türkçe, Deutsch, Français, Español, Italiano, Português (Brasil), Nederlands, Polski, Русский, Українська, 日本語, 한국어, 简体中文, العربية. It follows your macOS language.

## Requirements

- A Mac with Apple Silicon (M1 or later), macOS 13 or later.
- An external monitor with DDC/CI turned on (most monitors have it; some hide it in the on-screen menu).
- Tested on a Mac mini M4 with a Dell P2418D. If it works or fails on your setup, please open an issue with the monitor model and the cable (HDMI, USB-C, DisplayPort).

## Install

1. Download `Dimmer.zip` from [Releases](https://github.com/mkilicer/dimmer/releases/latest) and unzip it.
2. Move `Dimmer.app` to `Applications`.
3. The app is not notarized by Apple, so the first launch is blocked. Either right-click the app and choose **Open**, or run:

   ```sh
   xattr -dr com.apple.quarantine /Applications/Dimmer.app
   ```

The sun icon appears in the menu bar.

## Build from source

Command Line Tools are enough, Xcode is not needed:

```sh
git clone https://github.com/mkilicer/dimmer.git
cd dimmer
./build.sh --install
```

## Limits

- Only the first external monitor gets DDC brightness. The extra dim applies to every screen.
- A built-in MacBook display has no DDC; use the brightness keys for it.
- DDC uses Apple's private `IOAVService` API, like [m1ddc](https://github.com/waydabber/m1ddc) and [MonitorControl](https://github.com/MonitorControl/MonitorControl). A macOS update could break it.
- If you want more (multiple monitors, keyboard shortcuts, volume), MonitorControl is the full-featured option. Dimmer aims to stay small.

## Translations

Strings live in `Resources/<language>.lproj/Localizable.strings`; the English text is the key. Fixes and new languages are welcome as pull requests.

## Türkçe

Harici monitörün parlaklığını menü çubuğundan değiştirir, monitörün tuşlarına dokunmak gerekmez. Monitörle DDC/CI üzerinden konuşur, yani gerçek arka ışığı kısar. En düşük parlaklık hâlâ fazlaysa "Ekstra karartma" ekranı yazılımla daha da karartır. Menü çubuğundaki güneş ikonunun üstünde fare tekerini çevirmek yeterli.

Kurulum: [Releases](https://github.com/mkilicer/dimmer/releases/latest) sayfasından `Dimmer.zip`'i indir, açıp `Dimmer.app`'i Uygulamalar'a taşı. İlk açılışta sağ tıklayıp **Aç**'ı seç (uygulama Apple tarafından onaylı değil). Apple Silicon (M1 ve sonrası) ve macOS 13+ gerekir.

## License

MIT
