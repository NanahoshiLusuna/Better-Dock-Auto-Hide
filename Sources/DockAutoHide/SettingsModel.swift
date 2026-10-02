import Foundation

final class SettingsModel {
    private enum Key {
        static let autoMode = "autoModeEnabled"
        static let threshold = "edgeThreshold"
        static let showDockOverFullscreen = "showDockOverFullscreen"
        static let expandZoomedWindows = "expandZoomedWindows"
        static let showDockIcon = "showDockIcon"
        static let tileCycleSeconds = "tileCycleSeconds"
    }

    static let thresholdOptions: [CGFloat] = [16, 24, 32, 48]
    static let hoverDelayOptions: [Double?] = [nil, 0, 0.2, 0.5, 1, 2]
    static let tileCycleOptions: [Double] = [5, 10, 15, 30, 60]

    var autoModeEnabled = true
    var threshold: CGFloat = 24
    var showDockOverFullscreen = false
    var expandZoomedWindows = true
    var showDockIcon = true
    var tileCycleSeconds: Double = 15

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func load() {
        defaults.register(defaults: [
            Key.autoMode: true,
            Key.threshold: 24.0,
            Key.showDockOverFullscreen: false,
            Key.expandZoomedWindows: true,
            Key.showDockIcon: true,
            Key.tileCycleSeconds: 15.0,
        ])
        autoModeEnabled = defaults.bool(forKey: Key.autoMode)
        threshold = CGFloat(defaults.double(forKey: Key.threshold))
        showDockOverFullscreen = defaults.bool(forKey: Key.showDockOverFullscreen)
        expandZoomedWindows = defaults.bool(forKey: Key.expandZoomedWindows)
        showDockIcon = defaults.bool(forKey: Key.showDockIcon)
        let cycle = defaults.double(forKey: Key.tileCycleSeconds)
        tileCycleSeconds = Self.tileCycleOptions.contains(cycle) ? cycle : 15
    }

    func save() {
        defaults.set(autoModeEnabled, forKey: Key.autoMode)
        defaults.set(Double(threshold), forKey: Key.threshold)
        defaults.set(showDockOverFullscreen, forKey: Key.showDockOverFullscreen)
        defaults.set(expandZoomedWindows, forKey: Key.expandZoomedWindows)
        defaults.set(showDockIcon, forKey: Key.showDockIcon)
        defaults.set(tileCycleSeconds, forKey: Key.tileCycleSeconds)
    }
}
