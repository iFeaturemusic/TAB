import SwiftUI

enum PanelTab: String, CaseIterable {
    case today = "Today"
    case mind = "Mind"
    case insights = "Insights"
    case settings = "Settings"

    var symbol: String {
        switch self {
        case .today: return "sun.max.fill"
        case .mind: return "leaf.fill"
        case .insights: return "chart.bar.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
}

final class PanelNav: ObservableObject {
    @Published var tab: PanelTab

    init(_ tab: PanelTab = .today) {
        self.tab = tab
    }
}

struct RootView: View {
    @EnvironmentObject var engine: Engine
    @StateObject private var nav: PanelNav

    static let size = CGSize(width: 340, height: 580)

    init(tab: PanelTab = .today) {
        _nav = StateObject(wrappedValue: PanelNav(tab))
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar()
            ZStack {
                switch nav.tab {
                case .today: TodayView()
                case .mind: MindView()
                case .insights: InsightsView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            TabBar(selection: $nav.tab)
        }
        .environmentObject(nav)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(
            ZStack {
                Theme.bg
                RadialGradient(colors: [Color.white.opacity(0.07), .clear], center: .top, startRadius: 0, endRadius: 260)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
        .environment(\.colorScheme, .dark)
    }
}

struct HeaderBar: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var mind: Mind

    var body: some View {
        HStack(spacing: 10) {
            MascotView(mood: mood, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("TAB")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                HStack(spacing: 5) {
                    Circle().fill(dot).frame(width: 6, height: 6)
                    Text(status)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.dim)
                }
            }
            Spacer()
            Button {
                Popup.show(Popup.pauseItems(engine))
            } label: {
                Image(systemName: engine.phase == .paused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(IconButtonStyle(size: 28))
            .help(engine.phase == .paused ? "Resume" : "Pause reminders")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var mood: Mood {
        switch engine.phase {
        case .focus: return engine.nudge == nil ? .happy : .alert
        case .onBreak, .away: return .sleepy
        case .paused: return .calm
        }
    }

    private var status: String {
        if let session = mind.session { return "\(session.kind.title) · \(Fmt.clock(mind.remaining)) left" }
        switch engine.phase {
        case .focus:
            switch engine.nudge {
            case .breakTime: return "Break time"
            case .stand: return "Time to stand up"
            case .water: return "Time for water"
            case .mindPractice: return "Time for your daily reset"
            case .socialLimit, .scrolling: return "Social media check"
            default: return "Focusing · sitting \(Fmt.duration(engine.sittingFor))"
            }
        case .onBreak: return engine.breakComplete ? "Break complete" : "On a break"
        case .away: return "Away"
        case .paused:
            guard let until = engine.pausedUntil else { return "Paused" }
            return Calendar.current.isDateInToday(until) ? "Paused until \(Fmt.time(until))" : "Paused until tomorrow"
        }
    }

    private var dot: Color {
        switch engine.phase {
        case .focus: return engine.nudge == nil ? Theme.rest : Theme.move
        case .onBreak: return Theme.water
        case .away, .paused: return Theme.faint
        }
    }
}

struct TabBar: View {
    @Binding var selection: PanelTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PanelTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selection = tab }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.symbol).font(.system(size: 10, weight: .semibold))
                        Text(tab.rawValue).font(.system(size: 11.5, weight: .semibold, design: .rounded)).lineLimit(1)
                    }
                    .foregroundColor(selection == tab ? .white : Theme.dim)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Capsule().fill(selection == tab ? Color.white.opacity(0.1) : .clear))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.white.opacity(0.04)))
        .overlay(Capsule().strokeBorder(Theme.stroke))
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .padding(.top, 8)
    }
}
