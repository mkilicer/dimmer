import AppKit
import ServiceManagement

// Menu bar app: monitor brightness over DDC/CI, plus an extra software dim (gamma) for below the panel's minimum.
// Scrolling on the menu bar icon changes brightness, so no keyboard or monitor buttons are needed.

/// UI text; translations live in Resources/<lang>.lproj/Localizable.strings, English is the key.
func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

final class SliderRow: NSView {
    let slider: NSSlider
    private let value = NSTextField(labelWithString: "")
    var onChange: ((Int) -> Void)?

    init(title: String, max: Double) {
        slider = NSSlider(value: 0, minValue: 0, maxValue: max, target: nil, action: nil)
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 46))
        let label = NSTextField(labelWithString: title)
        label.font = .menuFont(ofSize: 13)
        label.frame = NSRect(x: 18, y: 26, width: 180, height: 16)
        value.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        value.textColor = .secondaryLabelColor
        value.alignment = .right
        value.frame = NSRect(x: 190, y: 26, width: 52, height: 16)
        slider.frame = NSRect(x: 16, y: 4, width: 228, height: 20)
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(changed)
        [label, value, slider].forEach(addSubview)
    }

    required init?(coder: NSCoder) { fatalError() }

    func set(_ v: Int) {
        slider.integerValue = v
        value.stringValue = "\(v)%"
    }

    @objc private func changed() {
        set(slider.integerValue)
        onChange?(slider.integerValue)
    }
}

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let ddc = DDC.external()
    private let queue = DispatchQueue(label: "ddc")
    private var pending: Int?
    private var sending = false
    private let defaults = UserDefaults.standard

    private let brightnessRow = SliderRow(title: L("Brightness"), max: 100)
    private let dimRow = SliderRow(title: L("Extra dimming"), max: 80)
    private let loginItem = NSMenuItem(title: L("Launch at login"), action: #selector(toggleLogin), keyEquivalent: "")

    private var brightness: Int {
        get { defaults.object(forKey: "brightness") as? Int ?? 50 }
        set { defaults.set(newValue, forKey: "brightness") }
    }
    private var dim: Int {
        get { defaults.integer(forKey: "dim") }
        set { defaults.set(newValue, forKey: "dim") }
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        item.button?.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: L("Brightness"))
        item.button?.toolTip = L("Scroll to change brightness")

        let menu = NSMenu()
        menu.delegate = self
        let name = NSMenuItem(title: NSScreen.screens.first?.localizedName ?? L("Monitor"), action: nil, keyEquivalent: "")
        name.isEnabled = false
        menu.addItem(name)
        if ddc == nil {
            let warn = NSMenuItem(title: L("The monitor does not answer DDC"), action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)
        }
        menu.addItem(row(brightnessRow))
        menu.addItem(row(dimRow))
        menu.addItem(.separator())
        for (title, b, d) in [(L("Day"), 70, 0), (L("Evening"), 30, 0), (L("Night"), 0, 30)] {
            let preset = NSMenuItem(title: d > 0 ? String(format: L("%@  (%d%% + dimming %d%%)"), title, b, d) : String(format: L("%@  (%d%%)"), title, b), action: #selector(applyPreset), keyEquivalent: "")
            preset.target = self
            preset.representedObject = [b, d]
            menu.addItem(preset)
        }
        menu.addItem(.separator())
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: L("Quit"), action: #selector(NSApplication.terminate), keyEquivalent: "q"))
        item.menu = menu

        brightnessRow.onChange = { [weak self] in self?.setBrightness($0) }
        dimRow.onChange = { [weak self] in self?.setDim($0) }

        // The monitor keeps its own value; start from what it reports, not from what we saved.
        queue.async { [weak self] in
            guard let self, let current = self.ddc?.read(.brightness) else { return }
            let percent = Int((Double(current.current) / Double(max(current.max, 1)) * 100).rounded())
            DispatchQueue.main.async {
                self.brightness = percent
                self.brightnessRow.set(percent)
            }
        }
        brightnessRow.set(brightness)
        dimRow.set(dim)
        applyDim()

        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, event.window == self.item.button?.window else { return event }
            let delta = event.scrollingDeltaY * (event.isDirectionInvertedFromDevice ? -1 : 1)
            guard abs(delta) > 0.1 else { return nil }
            self.nudge(delta > 0 ? 5 : -5)
            return nil
        }
        NotificationCenter.default.addObserver(self, selector: #selector(reapplyDim), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reapplyDim), name: NSWorkspace.didWakeNotification, object: nil)
    }

    func applicationWillTerminate(_ note: Notification) {
        CGDisplayRestoreColorSyncSettings()
    }

    func menuWillOpen(_ menu: NSMenu) {
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    private func row(_ view: NSView) -> NSMenuItem {
        let menuItem = NSMenuItem()
        menuItem.view = view
        return menuItem
    }

    /// Scroll on the icon: brightness first, then the software dim once the panel is at 0.
    private func nudge(_ step: Int) {
        if step < 0, brightness == 0 {
            setDim(min(dim - step, 80))
        } else if step > 0, dim > 0 {
            setDim(max(dim - step, 0))
        } else {
            setBrightness(min(max(brightness + step, 0), 100))
        }
        brightnessRow.set(brightness)
        dimRow.set(dim)
    }

    private func setBrightness(_ value: Int) {
        brightness = value
        // Sliders fire faster than DDC can take; only the latest value is sent.
        pending = value
        guard !sending else { return }
        sending = true
        queue.async { [weak self] in self?.flush() }
    }

    private func flush() {
        while let value = DispatchQueue.main.sync(execute: { () -> Int? in
            guard let next = pending else { sending = false; return nil }
            pending = nil
            return next
        }) {
            _ = ddc?.write(.brightness, UInt16(value))
            usleep(40_000)
        }
    }

    private func setDim(_ value: Int) {
        dim = value
        applyDim()
    }

    private func applyDim() {
        let top = Float(100 - dim) / 100
        for screen in NSScreen.screens {
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { continue }
            if dim == 0 {
                CGDisplayRestoreColorSyncSettings()
            } else {
                CGSetDisplayTransferByFormula(id, 0, top, 1, 0, top, 1, 0, top, 1)
            }
        }
    }

    // macOS resets gamma on wake and on display changes.
    @objc private func reapplyDim() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.applyDim() }
    }

    @objc private func applyPreset(_ sender: NSMenuItem) {
        guard let values = sender.representedObject as? [Int] else { return }
        setBrightness(values[0])
        setDim(values[1])
        brightnessRow.set(values[0])
        dimRow.set(values[1])
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
