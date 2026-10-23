import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject var store: HistoryStore
    @EnvironmentObject var prefs: Preferences
    @State private var period: Period
    @State private var metric: Metric
    @State private var offset = 0

    init(period: Period = .week, metric: Metric = .focus) {
        _period = State(initialValue: period)
        _metric = State(initialValue: metric)
    }

    var body: some View {
        let data = Insights(store: store, period: period, offset: offset)
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(Period.allCases, id: \.self) { p in
                    Chip(title: p.rawValue, selected: p == period) {
                        period = p
                        offset = 0
                        if p == .day && metric == .score { metric = .focus }
                    }
                }
            }
            .padding(3)
            .background(Capsule().fill(Color.white.opacity(0.04)))
            .padding(.horizontal, 16)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ScoreHeader(data: data, offset: $offset)
                    if data.active.isEmpty {
                        EmptyInsights()
                    } else {
                        MetricPicker(metric: $metric, allowScore: period != .day)
                        TrendChart(data: data, metric: metric)
                        StatGrid(stats: data.stats(ounces: prefs.useOunces))
                        NotesCard(notes: data.notes(prefs: prefs))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
        }
        .padding(.top, 2)
    }
}

struct ScoreHeader: View {
    var data: Insights
    @Binding var offset: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RingView(progress: Double(data.score ?? 0) / 100, color: Theme.score, lineWidth: 7)
                VStack(spacing: -2) {
                    Text(data.score.map(String.init) ?? "–")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("score")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Theme.dim)
                }
            }
            .frame(width: 66, height: 66)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Button { offset -= 1 } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(IconButtonStyle(size: 20, tint: Theme.dim))
                    Text(data.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Button { offset = min(0, offset + 1) } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(IconButtonStyle(size: 20, tint: offset < 0 ? Theme.dim : Theme.faint.opacity(0.4)))
                        .disabled(offset >= 0)
                }
                Text(Fmt.scoreLabel(data.score))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.score)
                if let delta = data.delta, delta != 0 {
                    Label("\(abs(delta)) vs before", systemImage: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(delta > 0 ? Theme.rest : Theme.alert)
                } else {
                    Text("\(data.active.count) active \(data.active.count == 1 ? "day" : "days")")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.dim)
                }
            }
            Spacer(minLength: 0)
        }
        .card(padding: 12, radius: 18)
    }
}

struct MetricPicker: View {
    @Binding var metric: Metric
    var allowScore: Bool

    var body: some View {
        let metrics = Metric.allCases.filter { allowScore || ($0 != .score && $0 != .phone) }
        let split = (metrics.count + 1) / 2
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(metrics.prefix(split), id: \.self) { m in
                    Chip(title: m.rawValue, selected: m == metric, tint: m.color) { metric = m }
                }
            }
            HStack(spacing: 4) {
                ForEach(metrics.suffix(from: split), id: \.self) { m in
                    Chip(title: m.rawValue, selected: m == metric, tint: m.color) { metric = m }
                }
            }
        }
    }
}

struct TrendChart: View {
    @EnvironmentObject var prefs: Preferences
    var data: Insights
    var metric: Metric
    @State private var hovered: ChartPoint?

    var body: some View {
        let points = data.points(metric, ounces: prefs.useOunces)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(hovered.map(describe) ?? data.axisLabel(metric, ounces: prefs.useOunces))
                    .font(.system(size: 11, weight: hovered == nil ? .regular : .semibold))
                    .foregroundColor(hovered == nil ? Theme.dim : .white)
                Spacer()
            }
            Chart {
                ForEach(points) { p in
                    BarMark(
                        x: .value("Date", p.date, unit: data.unit),
                        y: .value(metric.rawValue, p.value)
                    )
                    .foregroundStyle(metric.color.opacity(hovered == nil || hovered?.date == p.date ? 0.95 : 0.35))
                    .cornerRadius(3)
                }
                if let goal = goalLine {
                    RuleMark(y: .value("Goal", goal))
                        .foregroundStyle(Theme.water.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: xStride.0, count: xStride.1)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(xLabel(date)).font(.system(size: 9)).foregroundColor(Theme.dim)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel().font(.system(size: 9)).foregroundStyle(Theme.dim)
                }
            }
            .chartYScale(domain: .automatic(includesZero: true))
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(Color.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                let x = location.x - geo[proxy.plotAreaFrame].origin.x
                                if let date: Date = proxy.value(atX: x) {
                                    hovered = nearest(date, in: points)
                                }
                            case .ended:
                                hovered = nil
                            }
                        }
                }
            }
            .frame(height: 130)
        }
        .card(padding: 12, radius: 18)
    }

    private var goalLine: Double? {
        guard metric == .water, data.period != .day else { return nil }
        return prefs.useOunces ? Double(prefs.waterGoal) / 29.5735 : Double(prefs.waterGoal) / 1000
    }

    private var xStride: (Calendar.Component, Int) {
        switch data.period {
        case .day: return (.hour, 6)
        case .week: return (.day, 1)
        case .month: return (.day, 7)
        case .year: return (.month, 2)
        }
    }

    private func xLabel(_ date: Date) -> String {
        let df = DateFormatter()
        switch data.period {
        case .day: df.setLocalizedDateFormatFromTemplate("j")
        case .week: df.setLocalizedDateFormatFromTemplate("EEE")
        case .month: df.setLocalizedDateFormatFromTemplate("d")
        case .year: df.setLocalizedDateFormatFromTemplate("MMM")
        }
        return df.string(from: date)
    }

    private func nearest(_ date: Date, in points: [ChartPoint]) -> ChartPoint? {
        points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    private func describe(_ p: ChartPoint) -> String {
        let df = DateFormatter()
        switch data.period {
        case .day: df.setLocalizedDateFormatFromTemplate("j")
        case .week, .month: df.setLocalizedDateFormatFromTemplate("EEEMMMd")
        case .year: df.setLocalizedDateFormatFromTemplate("MMMM")
        }
        let when = df.string(from: p.date)
        let ounces = prefs.useOunces
        let value: String
        switch metric {
        case .focus:
            value = data.period == .day ? "\(Int(p.value)) min at the desk" : "\(Fmt.duration(Int(p.value * 3600))) at the desk"
        case .water:
            let ml = data.period == .day ? (ounces ? p.value * 29.5735 : p.value) : (ounces ? p.value * 29.5735 : p.value * 1000)
            value = Fmt.water(Int(ml), ounces: ounces)
        case .breaks: value = "\(Fmt.number(p.value)) breaks"
        case .moves: value = "\(Fmt.number(p.value)) stand-ups"
        case .mind: value = "\(Fmt.duration(Int(p.value * 60))) of rest"
        case .social: value = "\(Fmt.duration(Int(p.value * 60))) of social media"
        case .phone: value = "\(Fmt.duration(Int(p.value * 3600))) on your iPhone"
        case .score: value = "score \(Int(p.value))"
        }
        return "\(when) · \(value)"
    }
}

struct StatGrid: View {
    var stats: [Stat]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Circle().fill(stat.tint).frame(width: 5, height: 5)
                        Text(stat.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.dim)
                    }
                    Text(stat.value)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 10, radius: 14)
            }
        }
    }
}

struct NotesCard: View {
    var notes: [String]

    var body: some View {
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(notes, id: \.self) { note in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.score)
                            .padding(.top, 2)
                        Text(note)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 12, radius: 16)
        }
    }
}

struct EmptyInsights: View {
    var body: some View {
        VStack(spacing: 10) {
            MascotView(mood: .sleepy, size: 56)
            Text("Nothing here yet")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Keep TAB running and your desk time, water, breaks and stand-ups will show up here.")
                .font(.system(size: 12))
                .foregroundColor(Theme.dim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .card(padding: 16, radius: 18)
    }
}
