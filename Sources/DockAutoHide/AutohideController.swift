import AppKit

final class AutohideController {
    enum State: Equatable {
        case idle
        case edgeNear
        case edgeFar
        case fullscreen
        case overFullscreen
    }

    var onStateChange: ((State) -> Void)?
    private(set) var state: State = .idle {
        didSet { if state != oldValue { onStateChange?(state) } }
    }
    private(set) var isRunning = false

    private let settings: SettingsModel
    private let bridge: AutohideBridge
    private let windowObserver: WindowObserver
    private let snapper: WindowSnapper
    private let dockLocator = DockLocator()
    private var windows: [WindowInfo] = []
    private var nearWindowIDs = Set<CGWindowID>()

    init(settings: SettingsModel, bridge: AutohideBridge, windowObserver: WindowObserver, snapper: WindowSnapper) {
        self.settings = settings
        self.bridge = bridge
        self.windowObserver = windowObserver
        self.snapper = snapper
        windowObserver.onChange = { [weak self] windows in
            self?.windows = windows
            self?.evaluate()
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        windowObserver.start()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        windowObserver.stop()
        snapper.cancel()
        windows = []
        nearWindowIDs = []
        state = .idle
        bridge.setAutohide(bridge.baselineState)
    }

    func reevaluate() {
        guard isRunning else { return }
        evaluate()
    }

    private func evaluate() {
        guard let dock = dockLocator.geometry() else {
            release(.edgeFar)
            return
        }

        let detector = EdgeDetector(threshold: settings.threshold)
        let screens = NSScreen.screens.map(\.frame)
        var front: WindowInfo?
        var nearWindows: [WindowInfo] = []
        var expandTargets: [WindowInfo] = []
        var zoomedBehind = false
        var anyFullscreen = false

        for window in windows {
            guard ScreenGeometry.screenFrame(containing: window.frame, among: screens) == dock.screenFrame else { continue }
            let isFront = front == nil
            if isFront { front = window }
            guard detector.isNearDockEdge(
                windowFrame: window.frame,
                dock: dock,
                currentlyNear: nearWindowIDs.contains(window.id)
            ) else { continue }

            nearWindows.append(window)
            if detector.isFullscreen(windowFrame: window.frame, dock: dock) {
                anyFullscreen = true
                if !isFront { zoomedBehind = true }
            } else if detector.spansDockEdge(windowFrame: window.frame, dock: dock) {
                expandTargets.append(window)
                if !isFront { zoomedBehind = true }
            }
        }

        nearWindowIDs = Set(nearWindows.map(\.id))
        guard let front, !nearWindows.isEmpty else {
            release(.edgeFar)
            return
        }

        if settings.showDockOverFullscreen, !nearWindowIDs.contains(front.id), zoomedBehind {
            state = .overFullscreen
            snapper.allowAgain(exceptStillNear: nearWindowIDs)
            bridge.setAutohide(bridge.baselineState)
            return
        }

        state = anyFullscreen ? .fullscreen : .edgeNear
        bridge.setAutohide(true)
        if settings.expandZoomedWindows {
            for window in expandTargets {
                snapper.expandAfterDockHides(window, dockLocator: dockLocator)
            }
        }
        snapper.allowAgain(exceptStillNear: nearWindowIDs)
    }

    private func release(_ newState: State) {
        nearWindowIDs = []
        snapper.cancel()
        state = newState
        bridge.setAutohide(bridge.baselineState)
    }
}
