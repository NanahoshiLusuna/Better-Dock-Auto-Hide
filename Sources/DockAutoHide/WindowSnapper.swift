import AppKit
import ApplicationServices

final class WindowSnapper {
    private var timer: Timer?
    private var pendingWindowID: CGWindowID?
    private var finishedWindowIDs = Set<CGWindowID>()

    static func hasPermission(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func expandAfterDockHides(_ window: WindowInfo, dockLocator: DockLocator) {
        guard Self.hasPermission(prompt: false) else { return }
        if finishedWindowIDs.contains(window.id) || pendingWindowID == window.id { return }

        cancelPending()
        pendingWindowID = window.id

        if let dock = dockLocator.geometry(), !dock.isShown {
            finish(windowID: window.id, pid: window.pid, dock: dock)
            return
        }

        var attempts = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            attempts += 1
            guard let dock = dockLocator.geometry(), attempts <= 60 else {
                self.cancelPending()
                return
            }
            guard !dock.isShown else { return }
            self.finish(windowID: window.id, pid: window.pid, dock: dock)
        }
    }

    func cancel() {
        cancelPending()
        finishedWindowIDs.removeAll()
    }

    func allowAgain(exceptStillNear ids: Set<CGWindowID>) {
        finishedWindowIDs.formIntersection(ids)
    }

    private func cancelPending() {
        timer?.invalidate()
        timer = nil
        pendingWindowID = nil
    }

    private func finish(windowID: CGWindowID, pid: pid_t, dock: DockGeometry) {
        cancelPending()
        finishedWindowIDs.insert(windowID)

        let frame = WindowObserver.visibleWindows().first { $0.id == windowID }?.frame ?? .null
        guard !frame.isNull else { return }
        guard let element = Self.axWindow(pid: pid, preferring: frame) else {
            finishedWindowIDs.remove(windowID)
            return
        }

        let target = Self.targetFrame(for: frame, dock: dock)
        guard target.height - frame.height > 2 || target.width - frame.width > 2 else { return }

        if Self.setFrame(element, target) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                _ = Self.setFrame(element, target)
                let current = Self.frame(of: element) ?? .null
                if current.isNull || abs(current.height - target.height) > 4 || abs(current.width - target.width) > 4 {
                    Self.rezoom(element)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        _ = Self.setFrame(element, Self.targetFrame(for: Self.frame(of: element) ?? target, dock: dock))
                    }
                }
            }
            return
        }

        Self.rezoom(element)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let after = Self.frame(of: element) ?? frame
            _ = Self.setFrame(element, Self.targetFrame(for: after, dock: dock))
        }
    }

    private static func targetFrame(for frame: CGRect, dock: DockGeometry) -> CGRect {
        switch dock.orientation {
        case .bottom:
            let bottom = dock.screenFrame.minY
            return CGRect(x: frame.minX, y: bottom, width: frame.width, height: max(0, frame.maxY - bottom))
        case .left:
            let left = dock.screenFrame.minX
            return CGRect(x: left, y: frame.minY, width: max(0, frame.maxX - left), height: frame.height)
        case .right:
            let right = dock.screenFrame.maxX
            return CGRect(x: frame.minX, y: frame.minY, width: max(0, right - frame.minX), height: frame.height)
        }
    }

    @discardableResult
    private static func setFrame(_ element: AXUIElement, _ cocoaFrame: CGRect) -> Bool {
        let topLeft = ScreenGeometry.flipped(cocoaFrame)
        var origin = topLeft.origin
        var size = topLeft.size
        guard let originValue = AXValueCreate(.cgPoint, &origin),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else { return false }

        let positioned = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, originValue)
        let sized = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        let repositioned = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, originValue)
        return positioned == .success || sized == .success || repositioned == .success
    }

    private static func rezoom(_ element: AXUIElement) {
        var buttonRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXZoomButtonAttribute as CFString, &buttonRef) == .success,
              let buttonRef, CFGetTypeID(buttonRef) == AXUIElementGetTypeID()
        else { return }
        let button = buttonRef as! AXUIElement
        AXUIElementPerformAction(button, kAXPressAction as CFString)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            AXUIElementPerformAction(button, kAXPressAction as CFString)
        }
    }

    private static func axWindow(pid: pid_t, preferring frame: CGRect) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        var focusedElement: AXUIElement?

        var focused: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focused) == .success,
           let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() {
            focusedElement = (focused as! AXUIElement)
            if let axFrame = Self.frame(of: focusedElement!), framesRoughlyMatch(axFrame, frame) {
                return focusedElement
            }
        }

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return focusedElement }

        var best: AXUIElement?
        var bestArea: CGFloat = 0
        for element in windows {
            guard let axFrame = Self.frame(of: element) else { continue }
            if framesRoughlyMatch(axFrame, frame) { return element }
            let overlap = axFrame.intersection(frame)
            guard !overlap.isNull else { continue }
            let area = overlap.width * overlap.height
            if area > bestArea {
                bestArea = area
                best = element
            }
        }
        return best ?? focusedElement
    }

    private static func framesRoughlyMatch(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 24 && abs(a.minY - b.minY) <= 24
            && abs(a.width - b.width) <= 24 && abs(a.height - b.height) <= 24
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let origin: CGPoint = axValue(element, kAXPositionAttribute, .cgPoint),
              let size: CGSize = axValue(element, kAXSizeAttribute, .cgSize)
        else { return nil }
        return ScreenGeometry.flipped(CGRect(origin: origin, size: size))
    }

    private static func axValue<T>(_ element: AXUIElement, _ attribute: String, _ type: AXValueType) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        return withUnsafeTemporaryAllocation(of: T.self, capacity: 1) { buffer in
            guard let base = buffer.baseAddress, AXValueGetValue(value as! AXValue, type, base) else { return nil }
            return base.pointee
        }
    }
}
