import AppKit
import AVFoundation
import IOKit.pwr_mgt
import ServiceManagement

enum IdleMonitor {
    static var seconds: TimeInterval {
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    static var mediaIsPlaying: Bool {
        var status: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsStatus(&status) == kIOReturnSuccess,
              let dict = status?.takeRetainedValue() as? [String: Any] else { return false }
        let count = (dict["PreventUserIdleDisplaySleep"] as? NSNumber)?.intValue ?? 0
        return count > 0
    }
}

final class KeyboardBlocker {
    private static var activeTap: CFMachPort?
    private var source: CFRunLoopSource?

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    private static let callback: CGEventTapCallBack = { _, type, event, _ in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = KeyboardBlocker.activeTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        return nil
    }

    func start() {
        guard Self.activeTap == nil else { return }
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.callback,
            userInfo: nil
        ) else { return }
        Self.activeTap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        source = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        guard let tap = Self.activeTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        Self.activeTap = nil
        source = nil
    }
}

enum LoginItem {
    private static let label = "com.ifeature.TAB"

    private static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled || FileManager.default.fileExists(atPath: agentURL.path)
    }

    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func setEnabled(_ on: Bool) {
        if on {
            do {
                try SMAppService.mainApp.register()
                try? FileManager.default.removeItem(at: agentURL)
            } catch {
                writeAgent()
            }
        } else {
            try? SMAppService.mainApp.unregister()
            try? FileManager.default.removeItem(at: agentURL)
        }
    }

    static func enableOnFirstLaunch(_ defaults: UserDefaults = .standard) {
        let key = "loginItemConfigured"
        if !defaults.bool(forKey: key) {
            defaults.set(true, forKey: key)
            setEnabled(true)
        } else if FileManager.default.fileExists(atPath: agentURL.path) {
            setEnabled(true)
        }
    }

    private static func writeAgent() {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", "-b", Bundle.main.bundleIdentifier ?? label],
            "RunAtLoad": true,
        ]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else { return }
        try? FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: agentURL)
    }
}

enum SoundPlayer {
    static let systemSounds = ["Glass", "Ping", "Pop", "Purr", "Tink", "Hero", "Funk", "Bottle", "Blow", "Morse", "Frog", "Sosumi", "Submarine", "Basso"]

    private static var sound: NSSound?
    private static var player: AVAudioPlayer?

    static func play(_ prefs: Preferences, volume: Float = 1) {
        guard prefs.soundEnabled else { return }
        if !prefs.customSoundPath.isEmpty, playFile(prefs.customSoundPath, volume: volume) { return }
        playSystem(prefs.soundName, volume: volume)
    }

    static func playSystem(_ name: String, volume: Float = 1) {
        sound?.stop()
        guard let s = NSSound(named: NSSound.Name(name)) else { return }
        s.volume = volume
        sound = s
        s.play()
    }

    @discardableResult
    static func playFile(_ path: String, volume: Float = 1) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path),
              let p = try? AVAudioPlayer(contentsOf: url) else { return false }
        player?.stop()
        p.volume = volume
        player = p
        p.play()
        return true
    }
}

final class MenuAction: NSMenuItem {
    private var handler: () -> Void = {}

    convenience init(_ title: String, symbol: String? = nil, checked: Bool = false, handler: @escaping () -> Void) {
        self.init(title: title, action: #selector(run), keyEquivalent: "")
        self.handler = handler
        target = self
        state = checked ? .on : .off
        if let symbol { image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
    }

    @objc private func run() { handler() }
}

enum Popup {
    static func show(_ items: [NSMenuItem]) {
        let menu = NSMenu()
        items.forEach(menu.addItem)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    static func pauseItems(_ engine: Engine) -> [NSMenuItem] {
        if engine.phase == .paused {
            return [MenuAction("Resume", symbol: "play.fill") { engine.resume() }]
        }
        return [
            MenuAction("Pause for 30 minutes", symbol: "pause") { engine.pause(minutes: 30) },
            MenuAction("Pause for 1 hour", symbol: "pause") { engine.pause(minutes: 60) },
            MenuAction("Pause for 2 hours", symbol: "pause") { engine.pause(minutes: 120) },
            MenuAction("Pause until tomorrow", symbol: "moon.zzz") { engine.pause(minutes: nil) },
        ]
    }
}
