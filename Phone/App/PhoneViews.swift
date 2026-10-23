import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

struct PhoneRoot: View {
    @EnvironmentObject var model: PhoneModel

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            RadialGradient(colors: [Color.white.opacity(0.07), .clear], center: .top, startRadius: 0, endRadius: 360)
                .ignoresSafeArea()
            if model.authorized {
                HomeView()
            } else {
                OnboardingView()
            }
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var model: PhoneModel

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            MascotView(mood: .happy, size: 96)
            VStack(spacing: 8) {
                Text("TAB for iPhone")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text("Your Mac and your phone, working together.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.dim)
            }
            VStack(alignment: .leading, spacing: 14) {
                point("lock.fill", Theme.alert, "Your phone locks while your Mac is in focus mode.")
                point("square.and.arrow.up.fill", Theme.mind, "Unlock your social apps for a few minutes when you need to post.")
                point("chart.bar.fill", Theme.digital, "See your phone time next to your Mac time in TAB.")
            }
            .padding(.horizontal, 8)
            Spacer()
            Button {
                Task { await model.requestAccess() }
            } label: {
                Text("Allow Screen Time access")
            }
            .buttonStyle(PillButtonStyle(filled: true, tint: .white, height: 52))
            Text("Use the same iCloud account as on your Mac. Your data stays in your iCloud.")
                .font(.system(size: 12))
                .foregroundColor(Theme.faint)
                .multilineTextAlignment(.center)
        }
        .padding(28)
    }

    private func point(_ symbol: String, _ tint: Color, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 34, height: 34)
                .background(Circle().fill(tint.opacity(0.15)))
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var model: PhoneModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                PhoneHeader()
                if !model.config.ready || !model.paired || !model.notificationsAllowed {
                    SetupCard()
                }
                LockCard()
                TodayCard()
                PassCard()
                PhoneSettings()
                SyncFooter()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .refreshable { await model.sync() }
    }
}

struct PhoneHeader: View {
    @EnvironmentObject var model: PhoneModel

    var body: some View {
        HStack(spacing: 12) {
            MascotView(mood: model.focus.active ? .sleepy : .happy, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("TAB")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Circle().fill(dot).frame(width: 7, height: 7)
                    Text(status)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.dim)
                }
            }
            Spacer()
            Button {
                Task { await model.sync() }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .rotationEffect(.degrees(model.syncing ? 180 : 0))
                    .animation(model.syncing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: model.syncing)
            }
            .buttonStyle(IconButtonStyle(size: 36))
        }
        .padding(.top, 12)
    }

    private var status: String {
        guard model.paired else { return "Not connected to your Mac" }
        switch model.focus.macState {
        case "focus": return "Mac is focusing"
        case "rest": return "Mac is on a break"
        default: return "Mac isn't focusing"
        }
    }

    private var dot: Color {
        guard model.paired else { return Theme.alert }
        return model.focus.macState == "focus" ? Theme.move : Theme.rest
    }
}

struct SetupCard: View {
    @EnvironmentObject var model: PhoneModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Finish setting up")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Choose what stays open before your phone starts locking with your Mac. You'll find these settings further down.")
                .font(.system(size: 14))
                .foregroundColor(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
            if !model.paired {
                VStack(alignment: .leading, spacing: 10) {
                    step(done: false, "Connect to your Mac. On your Mac, open TAB › Settings › Digital hygiene and click Pair, then tap Connect.")
                    Button {
                        Task { await model.sync(pairing: true) }
                    } label: {
                        Text(model.syncing ? "Looking for your Mac…" : "Connect")
                    }
                    .buttonStyle(PillButtonStyle(filled: false, height: 38))
                }
            } else {
                step(done: true, "Connected to \(model.macName ?? "your Mac")")
            }
            if model.notificationsAllowed {
                step(done: true, "Notifications are on, so your Mac can lock your phone instantly")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    step(done: false, "Allow notifications, so your Mac can lock and unlock your phone instantly")
                    Button {
                        Task { await model.requestNotifications() }
                    } label: {
                        Text("Allow notifications")
                    }
                    .buttonStyle(PillButtonStyle(filled: false, height: 38))
                }
            }
            step(done: !model.config.allowed.applicationTokens.isEmpty || !model.config.allowed.categoryTokens.isEmpty,
                 "Always allowed apps, for example Messages, Maps, music and TAB itself")
            step(done: !model.config.social.applicationTokens.isEmpty, "Your social apps, each with a name")
            step(done: !model.config.everything.categoryTokens.isEmpty, "All Apps & Categories, to count your phone time")
            if !model.config.ready {
                Button {
                    model.config.ready = true
                    Task { await model.sync() }
                } label: {
                    Text("Start locking with my Mac")
                }
                .buttonStyle(PillButtonStyle(filled: true, tint: Theme.rest, height: 46))
            }
        }
        .card(padding: 18, radius: 24)
    }

    private func step(done: Bool, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17))
                .foregroundColor(done ? Theme.rest : Theme.faint)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(done ? 0.6 : 0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct LockCard: View {
    @EnvironmentObject var model: PhoneModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let locked = model.focus.active && (model.focus.until ?? .distantPast) > context.date
            VStack(spacing: 14) {
                ZStack {
                    RingView(progress: locked ? progress(at: context.date) : 0, color: locked ? Theme.alert : Theme.rest, lineWidth: 8)
                    MascotView(mood: locked ? .sleepy : .happy, size: 64)
                }
                .frame(width: 128, height: 128)
                VStack(spacing: 6) {
                    Text(locked ? "Focus time" : "Phone is free")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle(locked: locked, now: context.date))
                        .font(.system(size: 14))
                        .foregroundColor(Theme.dim)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if locked, let until = model.focus.until {
                    Text("\(Fmt.clock(Int(until.timeIntervalSince(context.date)))) left")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
            }
            .frame(maxWidth: .infinity)
            .card(padding: 20, radius: 26)
        }
    }

    private func progress(at date: Date) -> Double {
        guard let until = model.focus.until, let updated = model.focus.updated else { return 0.5 }
        let total = until.timeIntervalSince(min(updated, date))
        guard total > 0 else { return 1 }
        return min(1, max(0, 1 - until.timeIntervalSince(date) / total))
    }

    private func subtitle(locked: Bool, now: Date) -> String {
        if locked {
            let until = model.focus.until.map(Fmt.time) ?? ""
            return model.config.mode == .almostAll
                ? "Your Mac is in focus mode. Apps are locked until \(until). Calls always work."
                : "Your Mac is in focus mode. Social apps are locked until \(until)."
        }
        if !model.config.ready { return "Your phone starts locking once you finish setting up." }
        if !model.config.lockWithMac { return "Locking with your Mac is turned off." }
        switch model.focus.macState {
        case "rest": return "Your Mac is on a break. Enjoy it, then back to work."
        default: return "Your phone locks again when your Mac starts focusing."
        }
    }
}

struct TodayCard: View {
    private var filter: DeviceActivityFilter {
        let interval = Calendar.current.dateInterval(of: .day, for: Date()) ?? DateInterval(start: Date(), duration: 86400)
        return DeviceActivityFilter(segment: .daily(during: interval), users: .all, devices: .init([.iPhone]))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Today on your iPhone")
            DeviceActivityReport(.today, filter: filter)
                .frame(height: 340)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.stroke))
        }
    }
}

struct PassCard: View {
    @EnvironmentObject var model: PhoneModel

    var body: some View {
        let used = model.today.passes
        let total = model.config.passesPerDay
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.mind)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.mind.opacity(0.15)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Posting passes")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(max(0, total - used)) of \(total) left today")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.mind)
                }
                Spacer()
                HStack(spacing: 5) {
                    ForEach(0..<max(total, 0), id: \.self) { i in
                        Circle()
                            .fill(i < used ? Color.white.opacity(0.12) : Theme.mind)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            Text("Tap \u{201C}Post for \(model.config.passMinutes) min\u{201D} on a locked social app. It opens for \(model.config.passMinutes) minutes of use, then locks again.")
                .font(.system(size: 13))
                .foregroundColor(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(padding: 16, radius: 22)
    }
}

struct PhoneSettings: View {
    @EnvironmentObject var model: PhoneModel
    @State private var pickAllowed = false
    @State private var pickSocial = false
    @State private var pickEverything = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Settings")
            VStack(spacing: 0) {
                row("Lock while my Mac focuses") {
                    PillToggle(isOn: $model.config.lockWithMac, tint: Theme.rest)
                }
                divider
                VStack(alignment: .leading, spacing: 10) {
                    Text("What to lock")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    HStack(spacing: 6) {
                        ForEach(LockMode.allCases, id: \.self) { mode in
                            Chip(title: mode.title, selected: model.config.mode == mode, tint: .white) { model.config.mode = mode }
                        }
                    }
                    .frame(height: 30)
                }
                .padding(14)
                if model.config.mode == .almostAll {
                    divider
                    row("Always allowed", subtitle: "\(count(model.config.allowed)) chosen. Calls always work.") {
                        chooseButton { pickAllowed = true }
                    }
                }
                divider
                row("Social apps", subtitle: "Locked during focus, can be unlocked to post. Tracked by name on your Mac.") {
                    chooseButton { pickSocial = true }
                }
                ForEach(Array(model.config.trackedApps.enumerated()), id: \.offset) { index, token in
                    HStack(spacing: 10) {
                        Label(token)
                            .labelStyle(.iconOnly)
                            .frame(width: 30, height: 30)
                        TextField("Name, e.g. Instagram", text: Binding(
                            get: { model.config.names[token] ?? "" },
                            set: { model.config.names[token] = $0 }
                        ))
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.06)))
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                }
                divider
                row("Count all phone time", subtitle: model.config.everything.categoryTokens.isEmpty
                    ? "Tap \u{201C}All Apps & Categories\u{201D} at the top of the list."
                    : "On") {
                    chooseButton { pickEverything = true }
                }
                divider
                row("Posting pass") {
                    ValueStepper(value: $model.config.passMinutes, range: 1...30) { "\($0) min" }
                }
                divider
                row("Passes per day") {
                    ValueStepper(value: $model.config.passesPerDay, range: 0...10) { "\($0)" }
                }
            }
            .card(padding: 0, radius: 22)
        }
        .familyActivityPicker(isPresented: $pickAllowed, selection: $model.config.allowed)
        .familyActivityPicker(isPresented: $pickSocial, selection: $model.config.social)
        .familyActivityPicker(isPresented: $pickEverything, selection: $model.config.everything)
    }

    private var divider: some View {
        Divider().overlay(Theme.stroke).padding(.leading, 14)
    }

    private func count(_ selection: FamilyActivitySelection) -> Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    private func chooseButton(action: @escaping () -> Void) -> some View {
        Button("Choose", action: action)
            .buttonStyle(PillButtonStyle(filled: false, height: 32))
            .frame(width: 92)
    }

    private func row<Trailing: View>(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(14)
    }
}

struct SyncFooter: View {
    @EnvironmentObject var model: PhoneModel

    var body: some View {
        VStack(spacing: 6) {
            if let message = model.message {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.alert)
                    .multilineTextAlignment(.center)
            } else if let last = model.lastSync, let mac = model.macName {
                Text("Last talked to \(mac) at \(Fmt.time(last))")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.faint)
            }
            Text("Your Mac locks and unlocks this iPhone through Apple Push. Phone time goes to your Mac over Wi-Fi. No cloud, no account.")
                .font(.system(size: 11))
                .foregroundColor(Theme.faint)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }
}
