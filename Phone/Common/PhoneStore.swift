import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

enum LockMode: String, Codable, CaseIterable {
    case almostAll
    case socialOnly

    var title: String {
        switch self {
        case .almostAll: return "Almost everything"
        case .socialOnly: return "Social apps only"
        }
    }
}

struct PhoneConfig: Codable, Equatable {
    var ready = false
    var lockWithMac = true
    var mode: LockMode = .almostAll
    var allowed = FamilyActivitySelection()
    var social = FamilyActivitySelection()
    var everything = FamilyActivitySelection()
    var names: [ApplicationToken: String] = [:]
    var passMinutes = 5
    var passesPerDay = 3

    var trackedApps: [ApplicationToken] {
        let encoder = JSONEncoder()
        return social.applicationTokens
            .map { token in (token, (try? encoder.encode(token))?.base64EncodedString() ?? "") }
            .sorted { $0.1 < $1.1 }
            .prefix(8)
            .map(\.0)
    }

    func name(for token: ApplicationToken, index: Int) -> String {
        let name = names[token]?.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? "App \(index + 1)" : name
    }
}

struct FocusLock: Codable, Equatable {
    var active = false
    var until: Date?
    var macState = "off"
    var updated: Date?
}

struct PhoneDay: Codable, Equatable {
    var minutes = 0
    var apps: [String: Int] = [:]
    var passes = 0
    var passMinutes = 0
    var updated = Date.distantPast
}

final class PhoneStore {
    static let shared = PhoneStore()
    static let group = "group.com.ifeature.TAB"

    private let defaults = UserDefaults(suiteName: PhoneStore.group) ?? .standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private func load<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? encoder.encode(value) { defaults.set(data, forKey: key) }
    }

    var config: PhoneConfig {
        get { load("config", as: PhoneConfig.self) ?? PhoneConfig() }
        set { save(newValue, "config") }
    }

    var focus: FocusLock {
        get { load("focus", as: FocusLock.self) ?? FocusLock() }
        set { save(newValue, "focus") }
    }

    var days: [String: PhoneDay] {
        get { load("days", as: [String: PhoneDay].self) ?? [:] }
        set { save(newValue, "days") }
    }

    var passUntil: Date? {
        get { defaults.object(forKey: "passUntil") as? Date }
        set { defaults.set(newValue, forKey: "passUntil") }
    }

    var passStarted: Date? {
        get { defaults.object(forKey: "passStarted") as? Date }
        set { defaults.set(newValue, forKey: "passStarted") }
    }

    var usageStarted: Date? {
        get { defaults.object(forKey: "usageStarted") as? Date }
        set { defaults.set(newValue, forKey: "usageStarted") }
    }

    var trackedNames: [String] {
        get { defaults.stringArray(forKey: "trackedNames") ?? [] }
        set { defaults.set(newValue, forKey: "trackedNames") }
    }

    func day(_ date: Date = Date()) -> PhoneDay {
        days[LinkProtocol.dayKey(date)] ?? PhoneDay()
    }

    func updateDay(_ date: Date = Date(), _ change: (inout PhoneDay) -> Void) {
        var all = days
        let key = LinkProtocol.dayKey(date)
        var day = all[key] ?? PhoneDay()
        change(&day)
        day.updated = Date()
        all[key] = day
        let cutoff = LinkProtocol.dayKey(Date().addingTimeInterval(-120 * 86400))
        all = all.filter { $0.key >= cutoff }
        days = all
    }

    var passesLeft: Int { max(0, config.passesPerDay - day().passes) }
}

extension DeviceActivityName {
    static let focus = DeviceActivityName("tab.focus")
    static let pass = DeviceActivityName("tab.pass")
    static let usageTotal = DeviceActivityName("tab.usage.total")
    static func usageApp(_ index: Int) -> DeviceActivityName { DeviceActivityName("tab.usage.app.\(index)") }
}

extension DeviceActivityEvent.Name {
    static let passUsed = DeviceActivityEvent.Name("pass.used")
}

enum Lock {
    static let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("tab.focus"))
    static let center = DeviceActivityCenter()

    static var passActive: Bool {
        guard let until = PhoneStore.shared.passUntil else { return false }
        return until > Date()
    }

    static func refresh() {
        let state = PhoneStore.shared.focus
        if state.active, let until = state.until, until > Date() {
            shield(pass: passActive)
        } else {
            store.clearAllSettings()
        }
    }

    static func shield(pass: Bool) {
        let config = PhoneStore.shared.config
        store.clearAllSettings()
        switch config.mode {
        case .almostAll:
            var exceptions = config.allowed.applicationTokens
            if pass { exceptions.formUnion(config.social.applicationTokens) }
            store.shield.applicationCategories = .all(except: exceptions)
            store.shield.webDomainCategories = .all(except: pass ? config.allowed.webDomainTokens.union(config.social.webDomainTokens) : config.allowed.webDomainTokens)
        case .socialOnly:
            guard !pass else { return }
            store.shield.applications = config.social.applicationTokens.isEmpty ? nil : config.social.applicationTokens
            store.shield.applicationCategories = config.social.categoryTokens.isEmpty ? nil : .specific(config.social.categoryTokens)
            store.shield.webDomains = config.social.webDomainTokens.isEmpty ? nil : config.social.webDomainTokens
        }
    }

    static func follow(_ mac: MacFocus?) {
        let config = PhoneStore.shared.config
        var state = PhoneStore.shared.focus
        state.macState = mac?.state.rawValue ?? "off"
        state.updated = mac?.updated
        if let mac, mac.locksNow, config.ready, config.lockWithMac, mac.until.timeIntervalSinceNow > 60 {
            let changed = !state.active || abs((state.until ?? .distantPast).timeIntervalSince(mac.until)) > 30
            state.active = true
            state.until = mac.until
            PhoneStore.shared.focus = state
            if changed { schedule(.focus, until: mac.until) }
            shield(pass: passActive)
        } else {
            let wasActive = state.active
            state.active = false
            state.until = nil
            PhoneStore.shared.focus = state
            if wasActive { center.stopMonitoring([.focus, .pass]) }
            PhoneStore.shared.passUntil = nil
            store.clearAllSettings()
        }
    }

    static func focusEnded() {
        var state = PhoneStore.shared.focus
        if let until = state.until, until.timeIntervalSinceNow > 60 {
            schedule(.focus, until: until)
            return
        }
        state.active = false
        state.until = nil
        PhoneStore.shared.focus = state
        PhoneStore.shared.passUntil = nil
        center.stopMonitoring([.pass])
        store.clearAllSettings()
    }

    @discardableResult
    static func grantPass() -> Bool {
        let phone = PhoneStore.shared
        let config = phone.config
        guard phone.focus.active, phone.passesLeft > 0, config.passMinutes > 0 else { return false }
        phone.updateDay { day in
            day.passes += 1
            day.passMinutes += config.passMinutes
        }
        let now = Date()
        phone.passStarted = now
        phone.passUntil = now.addingTimeInterval(TimeInterval(config.passMinutes * 60 + 120))
        shield(pass: true)

        center.stopMonitoring([.pass])
        let event = DeviceActivityEvent(
            applications: config.social.applicationTokens,
            categories: config.social.categoryTokens,
            webDomains: config.social.webDomainTokens,
            threshold: DateComponents(minute: config.passMinutes)
        )
        let end = now.addingTimeInterval(TimeInterval(max(16, config.passMinutes + 10) * 60))
        try? center.startMonitoring(.pass, during: schedule(from: now, to: end), events: [.passUsed: event])
        return true
    }

    static func passUsedUp() {
        guard let started = PhoneStore.shared.passStarted, Date().timeIntervalSince(started) > 30 else { return }
        endPass()
    }

    static func endPass() {
        PhoneStore.shared.passUntil = nil
        PhoneStore.shared.passStarted = nil
        center.stopMonitoring([.pass])
        refresh()
    }

    private static func schedule(_ name: DeviceActivityName, until: Date) {
        center.stopMonitoring([name])
        let now = Date()
        let end = max(until, now.addingTimeInterval(16 * 60))
        try? center.startMonitoring(name, during: schedule(from: now, to: end))
    }

    private static func schedule(from start: Date, to end: Date) -> DeviceActivitySchedule {
        let cal = Calendar.current
        let lastSecond = cal.date(bySettingHour: 23, minute: 59, second: 59, of: start) ?? end
        let clamped = min(end, lastSecond)
        return DeviceActivitySchedule(
            intervalStart: cal.dateComponents([.hour, .minute, .second], from: start),
            intervalEnd: cal.dateComponents([.hour, .minute, .second], from: clamped),
            repeats: false
        )
    }
}

enum Usage {
    static func restart() {
        let phone = PhoneStore.shared
        let config = phone.config
        let names = [DeviceActivityName.usageTotal] + (0..<8).map(DeviceActivityName.usageApp)
        Lock.center.stopMonitoring(names)
        phone.usageStarted = Date()

        let daily = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )

        let all = config.everything
        if !all.categoryTokens.isEmpty || !all.applicationTokens.isEmpty {
            var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
            for minutes in stride(from: 10, through: 960, by: 10) {
                events[DeviceActivityEvent.Name("total.\(minutes)")] = DeviceActivityEvent(
                    applications: all.applicationTokens,
                    categories: all.categoryTokens,
                    webDomains: all.webDomainTokens,
                    threshold: DateComponents(hour: minutes / 60, minute: minutes % 60)
                )
            }
            try? Lock.center.startMonitoring(.usageTotal, during: daily, events: events)
        }

        let tracked = config.trackedApps
        updateNames()
        for (index, token) in tracked.enumerated() {
            var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
            for minutes in stride(from: 5, through: 240, by: 5) {
                events[DeviceActivityEvent.Name("app.\(index).\(minutes)")] = DeviceActivityEvent(
                    applications: [token],
                    threshold: DateComponents(hour: minutes / 60, minute: minutes % 60)
                )
            }
            try? Lock.center.startMonitoring(.usageApp(index), during: daily, events: events)
        }
    }

    static func updateNames() {
        let config = PhoneStore.shared.config
        PhoneStore.shared.trackedNames = config.trackedApps.enumerated().map { config.name(for: $1, index: $0) }
    }

    static func record(_ event: DeviceActivityEvent.Name) {
        let phone = PhoneStore.shared
        if let started = phone.usageStarted, Date().timeIntervalSince(started) < 45 { return }
        let parts = event.rawValue.split(separator: ".")
        guard let minutes = parts.last.flatMap({ Int($0) }) else { return }
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let sinceMidnight = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        guard minutes <= sinceMidnight + 1 else { return }

        if parts.first == "total" {
            phone.updateDay { $0.minutes = max($0.minutes, minutes) }
        } else if parts.first == "app", parts.count == 3, let index = Int(parts[1]) {
            let names = phone.trackedNames
            guard index < names.count else { return }
            let name = names[index]
            phone.updateDay { day in
                day.apps[name] = max(day.apps[name] ?? 0, minutes)
                day.minutes = max(day.minutes, day.apps.values.reduce(0, +))
            }
        }
    }
}
