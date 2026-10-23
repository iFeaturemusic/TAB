import SwiftUI

enum Period: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

enum Metric: String, CaseIterable {
    case focus = "Desk"
    case water = "Water"
    case breaks = "Breaks"
    case moves = "Moves"
    case mind = "Mind"
    case social = "Social"
    case phone = "iPhone"
    case score = "Score"

    var color: Color {
        switch self {
        case .focus: return .white
        case .water: return Theme.water
        case .breaks: return Theme.rest
        case .moves: return Theme.move
        case .mind: return Theme.mind
        case .social: return Theme.digital
        case .phone: return Theme.digital
        case .score: return Theme.score
        }
    }
}

struct ChartPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct Stat: Identifiable {
    let title: String
    let value: String
    let tint: Color
    var id: String { title }
}

struct Insights {
    let period: Period
    let start: Date
    let end: Date
    let title: String
    let logs: [DayLog]
    let previous: [DayLog]

    private let cal = Calendar.current

    init(store: HistoryStore, period: Period, offset: Int, now: Date = Date()) {
        self.period = period
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        var s: Date
        var e: Date
        var prevStart: Date
        let df = DateFormatter()

        switch period {
        case .day:
            s = cal.date(byAdding: .day, value: offset, to: today)!
            e = cal.date(byAdding: .day, value: 1, to: s)!
            prevStart = cal.date(byAdding: .day, value: -1, to: s)!
            if offset == 0 { title = "Today" }
            else if offset == -1 { title = "Yesterday" }
            else { df.setLocalizedDateFormatFromTemplate("EEEMMMd"); title = df.string(from: s) }
        case .week:
            e = cal.date(byAdding: .day, value: 1 + offset * 7, to: today)!
            s = cal.date(byAdding: .day, value: -7, to: e)!
            prevStart = cal.date(byAdding: .day, value: -7, to: s)!
            if offset == 0 { title = "Last 7 days" }
            else {
                df.setLocalizedDateFormatFromTemplate("MMMd")
                title = "\(df.string(from: s)) – \(df.string(from: e.addingTimeInterval(-1)))"
            }
        case .month:
            let base = cal.date(from: cal.dateComponents([.year, .month], from: today))!
            s = cal.date(byAdding: .month, value: offset, to: base)!
            e = cal.date(byAdding: .month, value: 1, to: s)!
            prevStart = cal.date(byAdding: .month, value: -1, to: s)!
            df.setLocalizedDateFormatFromTemplate("MMMMyyyy")
            title = df.string(from: s)
        case .year:
            let base = cal.date(from: cal.dateComponents([.year], from: today))!
            s = cal.date(byAdding: .year, value: offset, to: base)!
            e = cal.date(byAdding: .year, value: 1, to: s)!
            prevStart = cal.date(byAdding: .year, value: -1, to: s)!
            df.setLocalizedDateFormatFromTemplate("yyyy")
            title = df.string(from: s)
        }

        start = s
        end = e
        logs = store.logs(from: s, to: e)
        previous = store.logs(from: prevStart, to: s)
    }

    var active: [DayLog] { logs.filter(\.hasData) }

    static func averageScore(_ logs: [DayLog]) -> Int? {
        let scores = logs.compactMap(\.healthScore)
        guard !scores.isEmpty else { return nil }
        return Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
    }

    var score: Int? { Self.averageScore(logs) }
    var previousScore: Int? { Self.averageScore(previous) }

    var delta: Int? {
        guard let score, let previousScore else { return nil }
        return score - previousScore
    }

    var unit: Calendar.Component {
        switch period {
        case .day: return .hour
        case .week, .month: return .day
        case .year: return .month
        }
    }

    func value(_ day: DayLog, _ metric: Metric, ounces: Bool) -> Double? {
        switch metric {
        case .focus: return Double(day.focusSeconds) / 3600
        case .water: return ounces ? Double(day.waterML) / 29.5735 : Double(day.waterML) / 1000
        case .breaks: return Double(day.breakCount)
        case .moves: return Double(day.standCount)
        case .mind: return Double(day.restSeconds) / 60
        case .social: return Double(day.allSocialSeconds) / 60
        case .phone: return Double(day.phoneMinutes) / 60
        case .score: return day.healthScore.map(Double.init)
        }
    }

    func points(_ metric: Metric, ounces: Bool) -> [ChartPoint] {
        switch period {
        case .day:
            let day = logs.first ?? DayLog(key: HistoryStore.key(start))
            return (0..<24).map { hour in
                let date = cal.date(byAdding: .hour, value: hour, to: start)!
                let inHour: (Date) -> Bool = { cal.component(.hour, from: $0) == hour }
                let v: Double
                switch metric {
                case .focus, .score: v = Double(day.hourlyFocus[hour]) / 60
                case .water:
                    let ml = day.water.filter { inHour($0.time) }.reduce(0) { $0 + $1.ml }
                    v = ounces ? Double(ml) / 29.5735 : Double(ml)
                case .breaks: v = Double(day.breaks.filter { inHour($0.start) }.count)
                case .moves: v = Double(day.standUps.filter(inHour).count)
                case .mind: v = Double(day.mindSessions.filter { $0.kind != .breathing && inHour($0.start) }.reduce(0) { $0 + $1.seconds }) / 60
                case .social: v = Double(day.hourlySocial[hour]) / 60
                case .phone: v = 0
                }
                return ChartPoint(date: date, value: v)
            }
        case .week, .month:
            let byKey = Dictionary(logs.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
            var result: [ChartPoint] = []
            var cursor = start
            while cursor < end {
                let day = byKey[HistoryStore.key(cursor)]
                if let day, let v = value(day, metric, ounces: ounces) {
                    result.append(ChartPoint(date: cursor, value: v))
                } else if metric != .score {
                    result.append(ChartPoint(date: cursor, value: 0))
                }
                cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
            }
            return result
        case .year:
            return (0..<12).compactMap { m in
                let monthStart = cal.date(byAdding: .month, value: m, to: start)!
                let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)!
                let days = active.filter { $0.date >= monthStart && $0.date < monthEnd }
                let values = days.compactMap { value($0, metric, ounces: ounces) }
                guard !values.isEmpty else { return metric == .score ? nil : ChartPoint(date: monthStart, value: 0) }
                return ChartPoint(date: monthStart, value: values.reduce(0, +) / Double(values.count))
            }
        }
    }

    func axisLabel(_ metric: Metric, ounces: Bool) -> String {
        switch (metric, period) {
        case (.focus, .day), (.score, .day): return "minutes per hour"
        case (.focus, .year): return "hours per day, monthly average"
        case (.focus, _): return "hours per day"
        case (.water, .day): return ounces ? "oz per hour" : "ml per hour"
        case (.water, .year): return ounces ? "oz per day, monthly average" : "liters per day, monthly average"
        case (.water, _): return ounces ? "oz per day" : "liters per day"
        case (.breaks, .day): return "breaks per hour"
        case (.breaks, .year): return "breaks per day, monthly average"
        case (.breaks, _): return "breaks per day"
        case (.moves, .day): return "stand-ups per hour"
        case (.moves, .year): return "stand-ups per day, monthly average"
        case (.moves, _): return "stand-ups per day"
        case (.mind, .day): return "minutes of rest per hour"
        case (.mind, .year): return "minutes of rest per day, monthly average"
        case (.mind, _): return "minutes of NSDR or meditation per day"
        case (.social, .day): return "minutes of social media per hour"
        case (.social, .year): return "social media minutes per day, monthly average"
        case (.social, _): return "minutes of social media per day, Mac and iPhone"
        case (.phone, .year): return "hours on your iPhone per day, monthly average"
        case (.phone, _): return "hours on your iPhone per day"
        case (.score, .year): return "monthly average score"
        case (.score, _): return "daily health score"
        }
    }

    func stats(ounces: Bool) -> [Stat] {
        let days = active
        let n = Double(max(1, days.count))
        let focus = days.reduce(0) { $0 + $1.focusSeconds }
        let water = days.reduce(0) { $0 + $1.waterML }
        let breaks = days.reduce(0) { $0 + $1.breakCount }
        let breakSecs = days.reduce(0) { $0 + $1.breakSeconds }
        let stands = days.reduce(0) { $0 + $1.standCount }
        let longest = days.map(\.longestSit).max() ?? 0
        let avgBreak = breaks == 0 ? 0 : breakSecs / breaks
        let rest = days.reduce(0) { $0 + $1.restSeconds }
        let social = days.reduce(0) { $0 + $1.allSocialSeconds }
        let phone = days.reduce(0) { $0 + $1.phoneMinutes * 60 }

        if period == .day {
            return [
                Stat(title: "Desk time", value: Fmt.duration(focus), tint: .white),
                Stat(title: "Water", value: Fmt.water(water, ounces: ounces), tint: Theme.water),
                Stat(title: "Breaks", value: "\(breaks)", tint: Theme.rest),
                Stat(title: "Avg break", value: Fmt.duration(avgBreak), tint: Theme.rest),
                Stat(title: "Stand-ups", value: "\(stands)", tint: Theme.move),
                Stat(title: "Longest sit", value: Fmt.duration(longest), tint: Theme.alert),
                Stat(title: "Rest & meditation", value: Fmt.duration(rest), tint: Theme.mind),
                Stat(title: "Social media", value: Fmt.duration(social), tint: Theme.digital),
                Stat(title: "iPhone", value: phone > 0 ? Fmt.duration(phone) : "–", tint: Theme.digital),
                Stat(title: "Posting passes", value: "\(days.reduce(0) { $0 + $1.phonePasses })", tint: Theme.mind),
            ]
        }
        return [
            Stat(title: "Desk time / day", value: Fmt.duration(Int(Double(focus) / n)), tint: .white),
            Stat(title: "Water / day", value: Fmt.water(Int(Double(water) / n), ounces: ounces), tint: Theme.water),
            Stat(title: "Breaks / day", value: Fmt.number(Double(breaks) / n), tint: Theme.rest),
            Stat(title: "Avg break", value: Fmt.duration(avgBreak), tint: Theme.rest),
            Stat(title: "Stand-ups / day", value: Fmt.number(Double(stands) / n), tint: Theme.move),
            Stat(title: "Longest sit", value: Fmt.duration(longest), tint: Theme.alert),
            Stat(title: "Rest / day", value: Fmt.duration(Int(Double(rest) / n)), tint: Theme.mind),
            Stat(title: "Social / day", value: Fmt.duration(Int(Double(social) / n)), tint: Theme.digital),
            Stat(title: "iPhone / day", value: phone > 0 ? Fmt.duration(Int(Double(phone) / n)) : "–", tint: Theme.digital),
            Stat(title: "Posting passes", value: "\(days.reduce(0) { $0 + $1.phonePasses })", tint: Theme.mind),
        ]
    }

    func notes(prefs: Preferences) -> [String] {
        let days = active
        guard !days.isEmpty else { return [] }
        var notes: [String] = []
        let previousName: String = {
            switch period {
            case .day: return "the day before"
            case .week: return "the week before"
            case .month: return "last month"
            case .year: return "last year"
            }
        }()

        if let delta, delta != 0 {
            notes.append(delta > 0
                ? "Your health score is up \(delta) points from \(previousName)."
                : "Your health score is down \(-delta) points from \(previousName).")
        }

        if period == .day, let day = days.first {
            let left = day.waterGoal - day.waterML
            notes.append(left > 0
                ? "Drink \(Fmt.water(left, ounces: prefs.useOunces)) more to hit your water goal."
                : "You hit your water goal. Nice!")
            if day.breakCount > 0 {
                notes.append("You took \(day.breakCount) \(day.breakCount == 1 ? "break" : "breaks") and rested \(Fmt.duration(day.breakSeconds)) in total.")
            }
        } else {
            let hits = days.filter { $0.waterML >= $0.waterGoal }.count
            notes.append("You hit your water goal on \(hits) of \(days.count) days.")
            if let best = days.max(by: { ($0.healthScore ?? 0) < ($1.healthScore ?? 0) }), let s = best.healthScore {
                let df = DateFormatter()
                df.setLocalizedDateFormatFromTemplate("EEEMMMd")
                notes.append("Best day: \(df.string(from: best.date)) with a score of \(s).")
            }
        }

        let longest = days.map(\.longestSit).max() ?? 0
        if longest > prefs.standMinutes * 60 * 2 {
            notes.append("Your longest sit was \(Fmt.duration(longest)). Try to stand up every \(prefs.standMinutes) min.")
        }

        if period != .day {
            let resets = days.filter(\.restDone).count
            if resets > 0 { notes.append("You did your daily reset on \(resets) of \(days.count) days.") }
            let limited = days.filter { $0.socialLimit > 0 }
            if !limited.isEmpty {
                let under = limited.filter { $0.socialSeconds <= $0.socialLimit * 60 }.count
                notes.append("You stayed under your social media limit on \(under) of \(limited.count) days.")
            }
        }

        let skipped = days.reduce(0) { $0 + $1.skippedBreaks }
        if skipped > 0 {
            notes.append("You skipped \(skipped) \(skipped == 1 ? "break" : "breaks"). A 5 minute snooze is better than skipping.")
        }
        return Array(notes.prefix(3))
    }
}
