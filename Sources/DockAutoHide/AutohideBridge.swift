import Foundation

final class AutohideBridge {
    var onError: ((String) -> Void)?

    private static let dockDomain = "com.apple.dock" as CFString

    private var previousState: Bool?
    private var lastRequested: Bool?
    private let queue = DispatchQueue(label: "DockAutoHide.AutohideBridge")

    func isAutohideEnabled() -> Bool {
        dockBool("autohide")
    }

    func setAutohide(_ enabled: Bool) {
        if lastRequested == nil { lastRequested = isAutohideEnabled() }
        guard enabled != lastRequested else { return }
        lastRequested = enabled
        queue.async { [weak self] in
            self?.run("/usr/bin/osascript", [
                "-e",
                "tell application \"System Events\" to set autohide of dock preferences to \(enabled)",
            ], failure: "Dock 설정 변경 실패")
        }
    }

    func hoverDelay() -> Double? {
        CFPreferencesAppSynchronize(Self.dockDomain)
        return CFPreferencesCopyAppValue("autohide-delay" as CFString, Self.dockDomain) as? Double
    }

    func setHoverDelay(_ seconds: Double?) {
        let arguments = seconds.map { ["write", "com.apple.dock", "autohide-delay", "-float", String($0)] }
            ?? ["delete", "com.apple.dock", "autohide-delay"]
        queue.async { [weak self] in
            self?.run("/usr/bin/defaults", arguments, failure: "표시 지연 변경 실패", ignoreFailure: seconds == nil)
            self?.run("/usr/bin/killall", ["Dock"], failure: "Dock 재시작 실패")
        }
    }

    func rememberCurrentState() {
        previousState = isAutohideEnabled()
        lastRequested = previousState
    }

    var baselineState: Bool {
        previousState ?? false
    }

    func restorePreviousState() {
        guard let state = previousState else { return }
        setAutohide(state)
        queue.sync {}
    }

    private func dockBool(_ key: String) -> Bool {
        CFPreferencesAppSynchronize(Self.dockDomain)
        return CFPreferencesCopyAppValue(key as CFString, Self.dockDomain) as? Bool ?? false
    }

    private func run(_ executable: String, _ arguments: [String], failure: String, ignoreFailure: Bool = false) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            report("\(failure): \(error.localizedDescription)")
            return
        }

        guard process.terminationStatus != 0, !ignoreFailure else { return }
        let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let message = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown error"
        report("\(failure): \(message)")
    }

    private func report(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.lastRequested = nil
            self?.onError?(message)
        }
    }
}
