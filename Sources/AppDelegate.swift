import Cocoa
import Carbon.HIToolbox
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    /// How much menu bar real estate the app is allowed to take.
    private enum IconVisibility: String, CaseIterable {
        case always, whenAwake, never

        var title: String {
            switch self {
            case .always: return "Always Show Icon"
            case .whenAwake: return "Show Icon Only When Awake"
            case .never: return "Never Show Icon (shortcut only)"
            }
        }
    }

    private enum Defaults {
        static let showLabel = "ShowMenuBarLabel"
        static let hasLaunched = "HasLaunchedBefore"
        static let iconVisibility = "IconVisibility"
    }

    private static let hotKeyDisplay = "⌃⌥⌘S"

    private var statusItem: NSStatusItem!
    private let stateItem = NSMenuItem(title: "", action: #selector(refresh), keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "", action: #selector(toggleSleep), keyEquivalent: "s")
    private let visibilityItem = NSMenuItem(title: "Menu Bar Icon", action: nil, keyEquivalent: "")
    private let labelItem = NSMenuItem(title: "Show AWAKE Label", action: #selector(toggleLabel), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

    private var hotKey: GlobalHotKey?
    private var hasHotKey = false
    private var timer: Timer?
    private var isBusy = false
    /// Set while the icon is force-shown so a hidden app can still be reached.
    private var isRevealing = false

    private var showsLabel: Bool {
        get { UserDefaults.standard.object(forKey: Defaults.showLabel) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Defaults.showLabel) }
    }

    private var visibility: IconVisibility {
        get {
            let raw = UserDefaults.standard.string(forKey: Defaults.iconVisibility) ?? ""
            return IconVisibility(rawValue: raw) ?? .always
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Defaults.iconVisibility) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = buildMenu()

        // ⌃⌥⌘S works even when the icon is hidden or buried behind the notch.
        hotKey = GlobalHotKey(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(controlKey | optionKey | cmdKey)) { [weak self] in
            self?.toggleSleep()
        }
        hasHotKey = hotKey != nil
        NSLog("Anchorlight: global shortcut %@ %@", AppDelegate.hotKeyDisplay, hasHotKey ? "registered" : "UNAVAILABLE")

        refresh()
        showWelcomeIfNeeded()

        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.refresh()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(refresh),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    /// Opening the app again from Finder or Spotlight brings a hidden icon back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        isRevealing = true
        refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.statusItem.button?.performClick(nil)
        }
        return true
    }

    private func showWelcomeIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Defaults.hasLaunched) else { return }
        UserDefaults.standard.set(true, forKey: Defaults.hasLaunched)

        let alert = NSAlert()
        alert.messageText = "Anchorlight is running"
        alert.informativeText = [
            "Press \(AppDelegate.hotKeyDisplay) anywhere to switch between sleeping normally and staying awake with the lid closed. A panel confirms which one you just picked.",
            "There is also a menu bar icon — a moon, or a tinted cup labelled AWAKE. If your menu bar is full and you can't see it, that's fine: the shortcut still works, and opening Anchorlight again from Spotlight always brings the menu back.",
        ].joined(separator: "\n\n")
        alert.addButton(withTitle: "Show Me")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        statusItem.button?.performClick(nil)
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        stateItem.target = self
        menu.addItem(stateItem)
        menu.addItem(.separator())

        toggleItem.target = self
        toggleItem.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(toggleItem)
        menu.addItem(.separator())

        let visibilityMenu = NSMenu()
        for option in IconVisibility.allCases {
            let item = NSMenuItem(title: option.title, action: #selector(setVisibility(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = option.rawValue
            visibilityMenu.addItem(item)
        }
        visibilityMenu.addItem(.separator())
        labelItem.target = self
        visibilityMenu.addItem(labelItem)
        visibilityItem.submenu = visibilityMenu
        menu.addItem(visibilityItem)

        loginItem.target = self
        menu.addItem(loginItem)

        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Anchorlight", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
    }

    func menuDidClose(_ menu: NSMenu) {
        guard isRevealing else { return }
        isRevealing = false
        DispatchQueue.main.async { self.refresh() }
    }

    // MARK: - State

    @objc private func refresh() {
        guard !isBusy else { return }
        render(sleepDisabled: PowerSleep.isSleepDisabled())
    }

    private func render(sleepDisabled: Bool?) {
        guard let button = statusItem.button else { return }

        switch sleepDisabled {
        case true:
            apply(button: button, symbol: "cup.and.saucer.fill", label: "AWAKE", tint: .controlAccentColor)
            stateItem.attributedTitle = headline("Staying awake", dot: .systemGreen)
            subtitle(stateItem, "Closing the lid will not sleep this Mac")
            toggleItem.title = "Allow Sleep on Lid Close"
            subtitle(toggleItem, shortcutHint)
        case false:
            apply(button: button, symbol: "moon.zzz.fill", label: nil, tint: nil)
            stateItem.attributedTitle = headline("Sleeping normally", dot: .tertiaryLabelColor)
            subtitle(stateItem, "Closing the lid puts this Mac to sleep")
            toggleItem.title = "Keep Awake with Lid Closed"
            subtitle(toggleItem, shortcutHint)
        case nil:
            apply(button: button, symbol: "exclamationmark.triangle.fill", label: "?", tint: .systemOrange)
            stateItem.attributedTitle = headline("Unknown", dot: .systemOrange)
            subtitle(stateItem, "Could not read the setting from pmset")
            toggleItem.title = "Keep Awake with Lid Closed"
            subtitle(toggleItem, shortcutHint)
        }

        switch visibility {
        case .always: statusItem.isVisible = true
        case .whenAwake: statusItem.isVisible = isRevealing || sleepDisabled == true
        case .never: statusItem.isVisible = isRevealing
        }

        visibilityItem.submenu?.items.forEach { item in
            guard let raw = item.representedObject as? String else { return }
            item.state = raw == visibility.rawValue ? .on : .off
        }
        labelItem.state = showsLabel ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    /// Menu bar appearance: tinted icon plus an optional text label, so the
    /// on-state is readable at a glance rather than one glyph among many.
    private func apply(button: NSStatusBarButton, symbol name: String, label: String?, tint: NSColor?) {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: label ?? "Sleeps on lid close")
        image?.isTemplate = tint == nil
        button.image = image
        button.contentTintColor = tint

        if let label, showsLabel {
            button.imagePosition = .imageLeading
            button.attributedTitle = NSAttributedString(string: " \(label)", attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: tint ?? NSColor.labelColor,
                .kern: 0.4,
            ])
        } else {
            button.imagePosition = .imageOnly
            button.title = ""
        }

        if image == nil {
            button.imagePosition = .noImage
            button.title = label ?? "SLEEP"
        }
    }

    private var shortcutHint: String {
        hasHotKey
            ? "Works anywhere with \(AppDelegate.hotKeyDisplay)"
            : "\(AppDelegate.hotKeyDisplay) is taken by another app"
    }

    private func headline(_ text: String, dot: NSColor) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "● ", attributes: [
            .foregroundColor: dot,
            .font: NSFont.systemFont(ofSize: 11),
        ])
        result.append(NSAttributedString(string: text, attributes: [
            .font: NSFont.menuFont(ofSize: 0),
            .foregroundColor: NSColor.labelColor,
        ]))
        return result
    }

    private func subtitle(_ item: NSMenuItem, _ text: String) {
        if #available(macOS 14.4, *) {
            item.subtitle = text
        } else {
            item.toolTip = text
        }
    }

    // MARK: - Actions

    @objc private func toggleSleep() {
        guard !isBusy else { return }
        let target = PowerSleep.isSleepDisabled() != true
        isBusy = true

        DispatchQueue.global(qos: .userInitiated).async {
            var thrown: Error?
            do {
                try PowerSleep.setSleepDisabled(target)
            } catch {
                thrown = error
            }
            DispatchQueue.main.async {
                self.isBusy = false
                let actual = PowerSleep.isSleepDisabled()
                self.render(sleepDisabled: actual)

                if let error = thrown {
                    if !self.isCancellation(error) { self.presentError(error) }
                    return
                }
                guard actual == target else {
                    self.presentError(PowerSleep.Failure.failed("pmset reported success but the setting did not change."))
                    return
                }
                self.announce(sleepDisabled: target)
            }
        }
    }

    private func announce(sleepDisabled: Bool) {
        if sleepDisabled {
            HUD.show(
                symbol: "cup.and.saucer.fill",
                title: "Staying Awake",
                detail: "Closing the lid will not sleep this Mac",
                tint: .controlAccentColor
            )
        } else {
            HUD.show(
                symbol: "moon.zzz.fill",
                title: "Sleeping Normally",
                detail: "Closing the lid puts this Mac to sleep",
                tint: .secondaryLabelColor
            )
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        if let failure = error as? PowerSleep.Failure, case .cancelled = failure { return true }
        return false
    }

    @objc private func setVisibility(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let option = IconVisibility(rawValue: raw) else { return }
        visibility = option
        refresh()

        if option != .always {
            HUD.show(
                symbol: "menubar.arrow.up.rectangle",
                title: option == .never ? "Icon Hidden" : "Icon Shows When Awake",
                detail: "Press \(AppDelegate.hotKeyDisplay) to switch, or open Anchorlight again for the menu",
                tint: .controlAccentColor
            )
        }
    }

    @objc private func toggleLabel() {
        showsLabel.toggle()
        refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            presentError(error)
        }
        refresh()
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn't change the sleep setting"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
