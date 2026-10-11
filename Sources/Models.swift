import Foundation

enum BreakStyle: String, CaseIterable, Identifiable {
    case lock
    case gentle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lock: return "Lock Screen"
        case .gentle: return "Gentle Nudge"
        }
    }

    var subtitle: String {
        switch self {
        case .lock: return "Your screen locks until the break is over."
        case .gentle: return "A friendly reminder to drink water and rest."
        }
    }

    var symbol: String {
        switch self {
        case .lock: return "lock.fill"
        case .gentle: return "bell.fill"
        }
    }
}

enum BreakSource: String, Codable {
    case scheduled
    case manual
    case away
}

struct BreakEntry: Codable, Hashable {
    var start: Date
    var end: Date
    var source: BreakSource

    var seconds: Int { max(0, Int(end.timeIntervalSince(start))) }
}

struct WaterEntry: Codable, Hashable {
    var time: Date
    var ml: Int
}

struct DayLog: Codable, Identifiable {
    var key: String
    var focusSeconds = 0
    var hourlyFocus = Array(repeating: 0, count: 24)
    var breaks: [BreakEntry] = []
    var skippedBreaks = 0
    var snoozes = 0
    var water: [WaterEntry] = []
    var standUps: [Date] = []
    var longestSit = 0
    var waterGoal = 2000
    var workInterval = 45 * 60
    var standInterval = 30 * 60

    var id: String { key }

    init(key: String) {
        self.key = key
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        focusSeconds = try c.decodeIfPresent(Int.self, forKey: .focusSeconds) ?? 0
        hourlyFocus = try c.decodeIfPresent([Int].self, forKey: .hourlyFocus) ?? Array(repeating: 0, count: 24)
        if hourlyFocus.count != 24 { hourlyFocus = Array(repeating: 0, count: 24) }
        breaks = try c.decodeIfPresent([BreakEntry].self, forKey: .breaks) ?? []
        skippedBreaks = try c.decodeIfPresent(Int.self, forKey: .skippedBreaks) ?? 0
        snoozes = try c.decodeIfPresent(Int.self, forKey: .snoozes) ?? 0
        water = try c.decodeIfPresent([WaterEntry].self, forKey: .water) ?? []
        standUps = try c.decodeIfPresent([Date].self, forKey: .standUps) ?? []
        longestSit = try c.decodeIfPresent(Int.self, forKey: .longestSit) ?? 0
        waterGoal = try c.decodeIfPresent(Int.self, forKey: .waterGoal) ?? 2000
        workInterval = try c.decodeIfPresent(Int.self, forKey: .workInterval) ?? 45 * 60
        standInterval = try c.decodeIfPresent(Int.self, forKey: .standInterval) ?? 30 * 60
    }

    var date: Date { HistoryStore.date(fromKey: key) ?? Date() }

    var waterML: Int { water.reduce(0) { $0 + $1.ml } }
    var breakSeconds: Int { breaks.reduce(0) { $0 + $1.seconds } }
    var breakCount: Int { breaks.count }
    var standCount: Int { standUps.count }

    var hasData: Bool { focusSeconds >= 10 * 60 || !water.isEmpty || !breaks.isEmpty || !standUps.isEmpty }

    var hydration: Double {
        guard waterGoal > 0 else { return 1 }
        return min(1, Double(waterML) / Double(waterGoal))
    }

    var breakBalance: Double {
        let expected = Double(focusSeconds) / Double(max(60, workInterval))
        guard expected >= 1 else { return 1 }
        var score = min(1, Double(breakCount) / expected.rounded(.down))
        if longestSit > workInterval * 2 { score *= 0.8 }
        score -= Double(skippedBreaks) * 0.05
        return max(0, score)
    }

    var movement: Double {
        let expected = Double(focusSeconds) / Double(max(60, standInterval))
        guard expected >= 1 else { return 1 }
        return min(1, Double(standCount + breakCount) / expected.rounded(.down))
    }

    var healthScore: Int? {
        guard hasData else { return nil }
        let value = 0.35 * hydration + 0.35 * breakBalance + 0.30 * movement
        return Int((value * 100).rounded())
    }
}

enum Nudge: String, Identifiable {
    case breakTime
    case lockSoon
    case stand
    case water
    case welcomeBack

    var id: String { rawValue }
}

enum Phase: Equatable {
    case focus
    case onBreak
    case away
    case paused
}
