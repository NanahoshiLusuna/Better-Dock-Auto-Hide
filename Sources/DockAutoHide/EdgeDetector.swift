import AppKit

enum DockOrientation: String {
    case bottom, left, right
}

struct DockGeometry {
    let screenFrame: CGRect
    let orientation: DockOrientation
    let thickness: CGFloat
    let isShown: Bool
}

final class DockLocator {
    private static let shownInset: CGFloat = 8
    private static let orientationTTL: TimeInterval = 1

    private var cachedOrientation: DockOrientation?
    private var cachedOrientationAt: TimeInterval = -.infinity
    private var cachedThickness: CGFloat?
    private var cachedDisplayID: CGDirectDisplayID?

    func geometry() -> DockGeometry? {
        let orientation = currentOrientation()
        let screens = NSScreen.screens
        let insets = screens.map { Self.inset(of: $0, for: orientation) }

        if let index = insets.firstIndex(where: { $0 > Self.shownInset }) {
            cachedThickness = insets[index]
            cachedDisplayID = screens[index].displayID
            return makeGeometry(screens[index], orientation, thickness: insets[index], isShown: true)
        }

        if let index = insets.firstIndex(where: { $0 > 0 }) {
            cachedDisplayID = screens[index].displayID
        }
        let screen = screens.first { $0.displayID == cachedDisplayID } ?? screens.first
        guard let screen else { return nil }
        return makeGeometry(screen, orientation, thickness: cachedThickness ?? fallbackThickness(), isShown: false)
    }

    private func makeGeometry(_ screen: NSScreen, _ orientation: DockOrientation, thickness: CGFloat, isShown: Bool) -> DockGeometry {
        DockGeometry(screenFrame: screen.frame, orientation: orientation, thickness: thickness, isShown: isShown)
    }

    private func currentOrientation() -> DockOrientation {
        let now = ProcessInfo.processInfo.systemUptime
        if let cachedOrientation, now - cachedOrientationAt < Self.orientationTTL {
            return cachedOrientation
        }
        let domain = "com.apple.dock" as CFString
        CFPreferencesAppSynchronize(domain)
        let raw = CFPreferencesCopyAppValue("orientation" as CFString, domain) as? String
        let orientation = raw.flatMap(DockOrientation.init(rawValue:)) ?? .bottom
        if orientation != cachedOrientation {
            cachedThickness = nil
            cachedDisplayID = nil
        }
        cachedOrientation = orientation
        cachedOrientationAt = now
        return orientation
    }

    private func fallbackThickness() -> CGFloat {
        let tileSize = CFPreferencesCopyAppValue("tilesize" as CFString, "com.apple.dock" as CFString) as? Double ?? 48
        return CGFloat(tileSize) + 16
    }

    private static func inset(of screen: NSScreen, for orientation: DockOrientation) -> CGFloat {
        let frame = screen.frame
        let visible = screen.visibleFrame
        switch orientation {
        case .bottom: return visible.minY - frame.minY
        case .left: return visible.minX - frame.minX
        case .right: return frame.maxX - visible.maxX
        }
    }
}

struct EdgeDetector {
    var threshold: CGFloat = 24
    var hysteresis: CGFloat = 16

    func isNearDockEdge(windowFrame: CGRect, dock: DockGeometry, currentlyNear: Bool) -> Bool {
        guard windowFrame.intersects(dock.screenFrame) else { return false }

        let distance: CGFloat
        switch dock.orientation {
        case .bottom:
            distance = windowFrame.minY - (dock.screenFrame.minY + dock.thickness)
        case .left:
            distance = windowFrame.minX - (dock.screenFrame.minX + dock.thickness)
        case .right:
            distance = (dock.screenFrame.maxX - dock.thickness) - windowFrame.maxX
        }
        return distance < (currentlyNear ? threshold + hysteresis : threshold)
    }

    func spansDockEdge(windowFrame: CGRect, dock: DockGeometry) -> Bool {
        let covered = windowFrame.intersection(dock.screenFrame)
        switch dock.orientation {
        case .bottom: return covered.width >= dock.screenFrame.width * 0.9
        case .left, .right: return covered.height >= dock.screenFrame.height * 0.8
        }
    }

    func isFullscreen(windowFrame: CGRect, dock: DockGeometry) -> Bool {
        let screen = dock.screenFrame
        return abs(windowFrame.minX - screen.minX) <= 2
            && abs(windowFrame.minY - screen.minY) <= 2
            && abs(windowFrame.width - screen.width) <= 2
            && abs(windowFrame.height - screen.height) <= 2
    }
}

enum ScreenGeometry {
    static func flipped(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func flipped(_ rect: CGRect) -> CGRect {
        flipped(rect, primaryHeight: NSScreen.screens.first?.frame.height ?? 0)
    }

    static func screenFrame(containing rect: CGRect, among screens: [CGRect]) -> CGRect? {
        var best: CGRect?
        var bestArea: CGFloat = 0
        for screen in screens {
            let overlap = screen.intersection(rect)
            guard !overlap.isNull else { continue }
            let area = overlap.width * overlap.height
            if area > bestArea {
                bestArea = area
                best = screen
            }
        }
        return best
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
