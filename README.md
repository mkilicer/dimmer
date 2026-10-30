# Dimmer

Menu bar app for the Mac mini that changes the external monitor's brightness over DDC/CI, so the monitor's own buttons are never needed.

- **Parlaklık**: the monitor's real backlight (VCP 0x10).
- **Ekstra karartma**: software dim through the gamma table, for darker than the panel's minimum. Reset on quit.
- Scroll on the menu bar icon: brightness up/down in 5% steps; below 0 it continues into the software dim.
- Presets: Gündüz, Akşam, Gece. "Açılışta başlat" toggles the login item.

Build and install (Command Line Tools are enough, no Xcode):

```sh
./build.sh --install
```

DDC uses the private `IOAVService` API (Apple Silicon only), the same way m1ddc and MonitorControl do. Tested on Mac mini M4 with a Dell P2418D.
