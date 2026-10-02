import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = SettingsModel()
    private let bridge = AutohideBridge()
    private lazy var controller = AutohideController(
        settings: settings,
        bridge: bridge,
        windowObserver: WindowObserver(),
        snapper: WindowSnapper()
    )

    private let weatherMonitor = WeatherMonitor()
    private let tileView = DockTileView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
    private var weather: WeatherSnapshot?
    private var cycleTimer: Timer?
    private var cycleIndex = 0

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var lastError: String?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        bridge.rememberCurrentState()
        bridge.onError = { [weak self] message in
            self?.lastError = message
        }

        setupStatusItem()
        if settings.autoModeEnabled { controller.start() }
        setupDockTile()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
        bridge.restorePreviousState()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem?.button?.performClick(nil)
        return false
    }

    private func setAutoMode(_ enabled: Bool) {
        settings.autoModeEnabled = enabled
        settings.save()
        if enabled {
            controller.start()
        } else {
            controller.stop()
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "Dock AutoHide")
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(withTitle: "상태: \(statusText())", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        addToggle(to: menu, "자동 모드 (창 경계 감지)", settings.autoModeEnabled, #selector(toggleAutoMode), key: "a")
        addToggle(to: menu, "Dock 자동 숨김", bridge.isAutohideEnabled(), #selector(toggleManualAutohide), key: "d")
        addToggle(to: menu, "전체 화면 위 다른 창 사용 시 Dock 표시", settings.showDockOverFullscreen, #selector(toggleShowDockOverFullscreen))
        addToggle(to: menu, "확대한 창을 Dock 자리까지 늘리기", settings.expandZoomedWindows, #selector(toggleExpandZoomedWindows))

        let current = bridge.hoverDelay()
        addSubmenu(to: menu, "Dock 표시 지연", options: SettingsModel.hoverDelayOptions.map { value in
            (Self.delayTitle(value), value as Any, abs((value ?? -1) - (current ?? -1)) < 0.01)
        }, action: #selector(selectHoverDelay(_:)))

        addSubmenu(to: menu, "경계 임계값", options: SettingsModel.thresholdOptions.map { value in
            ("\(Int(value)) px", value as Any, value == settings.threshold)
        }, action: #selector(selectThreshold(_:)))

        menu.addItem(.separator())
        let tileMenu = NSMenu()
        addToggle(to: tileMenu, "Dock 아이콘 표시", settings.showDockIcon, #selector(toggleDockIcon))
        addSubmenu(to: tileMenu, "순환 간격", options: SettingsModel.tileCycleOptions.map { value in
            ("\(Int(value))초", value as Any, value == settings.tileCycleSeconds)
        }, action: #selector(selectTileCycle(_:)))
        menu.addItem(withTitle: "Dock 아이콘", action: nil, keyEquivalent: "").submenu = tileMenu

        menu.addItem(.separator())
        if settings.expandZoomedWindows && !WindowSnapper.hasPermission(prompt: false) {
            addAction(to: menu, "손쉬운 사용 권한 열기… (창 늘리기에 필요)", #selector(openAccessibilitySettings))
        }
        if let lastError {
            menu.addItem(withTitle: "오류: \(lastError)", action: nil, keyEquivalent: "")
            addAction(to: menu, "자동화 권한 열기…", #selector(openAutomationSettings))
        }
        addAction(to: menu, "종료 (원래 숨김 설정 복원)", #selector(quit), key: "q")
    }

    private func addToggle(to menu: NSMenu, _ title: String, _ isOn: Bool, _ action: Selector, key: String = "", enabled: Bool = true) {
        let item = addAction(to: menu, title, action, key: key)
        item.state = isOn ? .on : .off
        if !enabled { item.action = nil }
    }

    @discardableResult
    private func addAction(to menu: NSMenu, _ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func addSubmenu(to menu: NSMenu, _ title: String, options: [(String, Any, Bool)], action: Selector) {
        let submenu = NSMenu()
        for (optionTitle, value, isSelected) in options {
            let option = addAction(to: submenu, optionTitle, action)
            option.representedObject = value
            option.state = isSelected ? .on : .off
        }
        menu.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = submenu
    }

    private static func delayTitle(_ seconds: Double?) -> String {
        guard let seconds else { return "시스템 기본" }
        return seconds == 0 ? "즉시" : "\(seconds.formatted())초"
    }

    @objc private func toggleAutoMode() {
        setAutoMode(!settings.autoModeEnabled)
    }

    @objc private func toggleManualAutohide() {
        let target = !bridge.isAutohideEnabled()
        if settings.autoModeEnabled { setAutoMode(false) }
        lastError = nil
        bridge.setAutohide(target)
    }

    @objc private func toggleShowDockOverFullscreen() {
        settings.showDockOverFullscreen.toggle()
        settings.save()
        controller.reevaluate()
    }

    @objc private func toggleExpandZoomedWindows() {
        settings.expandZoomedWindows.toggle()
        settings.save()
        if settings.expandZoomedWindows, !WindowSnapper.hasPermission(prompt: false) {
            _ = WindowSnapper.hasPermission(prompt: true)
        }
        controller.reevaluate()
    }

    @objc private func selectHoverDelay(_ sender: NSMenuItem) {
        bridge.setHoverDelay(sender.representedObject as? Double)
    }

    @objc private func selectThreshold(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? CGFloat else { return }
        settings.threshold = value
        settings.save()
        controller.reevaluate()
    }

    @objc private func toggleDockIcon() {
        settings.showDockIcon.toggle()
        settings.save()
        NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
        applyTileContent()
    }

    @objc private func selectTileCycle(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        settings.tileCycleSeconds = value
        settings.save()
        startCycle()
    }

    @objc private func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    @objc private func openAutomationSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func open(_ urlString: String) {
        if let url = URL(string: urlString) { NSWorkspace.shared.open(url) }
    }

    private func setupDockTile() {
        weatherMonitor.onUpdate = { [weak self] snapshot in
            self?.weather = snapshot
            self?.showCycleItem()
        }
        weatherMonitor.start()
        startCycle()
    }

    private func startCycle() {
        cycleTimer?.invalidate()
        cycleIndex = 0
        showCycleItem()
        cycleTimer = Timer.scheduledTimer(withTimeInterval: settings.tileCycleSeconds, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.cycleIndex += 1
            self.showCycleItem()
        }
    }

    private func showCycleItem() {
        guard settings.showDockIcon else { return }
        if cycleIndex % 2 == 0 {
            tileView.showTemperature(weather?.temperatureText ?? "—")
        } else if let symbol = weather?.symbolName {
            tileView.showSymbol(symbol)
        } else {
            tileView.showTemperature("—")
        }
        applyTileContent()
    }

    private func applyTileContent() {
        guard settings.showDockIcon else { return }
        NSApp.dockTile.contentView = tileView
        NSApp.dockTile.display()
    }

    private func statusText() -> String {
        guard settings.autoModeEnabled else { return "수동" }
        switch controller.state {
        case .idle: return "대기"
        case .edgeNear: return "경계 근접"
        case .edgeFar: return "경계 이탈"
        case .fullscreen: return "전체 화면"
        case .overFullscreen: return "전체 화면 위 창"
        }
    }
}
