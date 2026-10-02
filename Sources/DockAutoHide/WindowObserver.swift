import AppKit

struct WindowInfo: Equatable {
    let id: CGWindowID
    let pid: pid_t
    let frame: CGRect
}

final class WindowObserver {
    var onChange: (([WindowInfo]) -> Void)?

    private let pollInterval: TimeInterval
    private var timer: Timer?
    private var activationToken: NSObjectProtocol?
    private var lastWindows: [WindowInfo]?

    init(pollInterval: TimeInterval = 0.2) {
        self.pollInterval = pollInterval
    }

    func start() {
        guard timer == nil else { return }
        lastWindows = nil
        activationToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.poll() }

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let token = activationToken {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            activationToken = nil
        }
    }

    private func poll() {
        let windows = Self.visibleWindows()
        if windows == lastWindows { return }
        lastWindows = windows
        onChange?(windows)
    }

    static func visibleWindows() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }

        let ownPID = getpid()
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        var windows: [WindowInfo] = []
        windows.reserveCapacity(list.count)

        for info in list {
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width >= 50, bounds.height >= 50
            else { continue }
            if let alpha = info[kCGWindowAlpha as String] as? Double, alpha <= 0 { continue }
            windows.append(WindowInfo(id: id, pid: pid, frame: ScreenGeometry.flipped(bounds, primaryHeight: primaryHeight)))
        }
        return windows
    }
}
