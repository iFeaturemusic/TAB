import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var store: HistoryStore
    @EnvironmentObject var mind: Mind
    @EnvironmentObject var link: PhoneLink
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                breakStyle
                rhythm
                water
                movement
                mindSection
                digitalSection
                smart
                sound
                general
                Text("TAB \(Bundle.main.version) · by iFeature")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.faint)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var breakStyle: some View {
        VStack(spacing: 8) {
            SectionTitle(text: "Break style")
            HStack(spacing: 8) {
                ForEach(BreakStyle.allCases) { style in
                    StyleCard(style: style, selected: prefs.breakStyle == style) {
                        prefs.breakStyle = style
                        if style == .lock && !KeyboardBlocker.isTrusted { KeyboardBlocker.requestAccess() }
                    }
                }
            }
            if prefs.breakStyle == .lock && !KeyboardBlocker.isTrusted {
                HStack(spacing: 10) {
                    Image(systemName: "keyboard.badge.ellipsis")
                        .foregroundColor(Theme.move)
                    Text("Allow Accessibility access so TAB can also pause the keyboard during breaks.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Allow") { KeyboardBlocker.requestAccess() }
                        .buttonStyle(PillButtonStyle(filled: true, tint: Theme.move, height: 24))
                        .frame(width: 64)
                }
                .card(padding: 10, radius: 14)
            }
        }
    }

    private var rhythm: some View {
        VStack(spacing: 8) {
            SectionTitle(text: "Rhythm")
            VStack(spacing: 0) {
                Row(title: "Work for", subtitle: "Time between breaks") {
                    ValueStepper(value: $prefs.workMinutes, range: 5...180, step: 5) { "\($0) min" }
                }
                Divider().overlay(Theme.stroke)
                Row(title: "Break for", subtitle: "How long each break lasts") {
                    ValueStepper(value: $prefs.breakMinutes, range: 1...60) { "\($0) min" }
                }
                if prefs.breakStyle == .lock {
                    Divider().overlay(Theme.stroke)
                    Row(title: "Emergency skip", subtitle: "Hold a button for 3 s to unlock early") {
                        PillToggle(isOn: $prefs.allowSkip)
                    }
                }
            }
            .card(padding: 4, radius: 16)
        }
    }

    private var water: some View {
        VStack(spacing: 8) {
            SectionTitle(text: "Water")
            VStack(spacing: 0) {
                Row(title: "Daily goal") {
                    ValueStepper(value: $prefs.waterGoal, range: 500...5000, step: prefs.useOunces ? 237 : 250) {
                        Fmt.water($0, ounces: prefs.useOunces)
                    }
                }
                Divider().overlay(Theme.stroke)
                Row(title: "Glass size") {
                    ValueStepper(value: $prefs.glassSize, range: 100...1000, step: prefs.useOunces ? 59 : 50) {
                        Fmt.water($0, ounces: prefs.useOunces)
                    }
                }
                Divider().overlay(Theme.stroke)
                Row(title: "Remind me to drink") {
                    PillToggle(isOn: $prefs.waterReminders, tint: Theme.water)
                }
                if prefs.waterReminders {
                    Divider().overlay(Theme.stroke)
                    Row(title: "Every") {
                        ValueStepper(value: $prefs.waterMinutes, range: 15...180, step: 15) { "\($0) min" }
                    }
                }
                Divider().overlay(Theme.stroke)
                Row(title: "Units") {
                    HStack(spacing: 4) {
                        Chip(title: "ml", selected: !prefs.useOunces, tint: Theme.water) { prefs.useOunces = false }
                        Chip(title: "oz", selected: prefs.useOunces, tint: Theme.water) { prefs.useOunces = true }
                    }
                    .frame(width: 96)
                }
            }
            .card(padding: 4, radius: 16)
        }
    }

    private var movement: some View {
        VStack(spacing: 8) {
            SectionTitle(text: "Stand up & stretch")
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Remind me to stand up")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    PillToggle(isOn: $prefs.standReminders, tint: Theme.move)
                }
                Text("Your age")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.dim)
                HStack(spacing: 4) {
                    ForEach(AgeGroup.allCases) { group in
                        Chip(title: group.label, selected: prefs.ageGroup == group, tint: Theme.move) {
                            prefs.ageGroup = group
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Every \(prefs.ageGroup.standEvery) min, \(prefs.ageGroup.moveFor)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.move)
                    Text(prefs.ageGroup.reason)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Across \(Research.studies.count) studies, the average was one break every \(Fmt.number(Research.averageInterval)) min.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.move.opacity(0.08)))
                Divider().overlay(Theme.stroke)
                HStack {
                    Text("Use my own interval")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    PillToggle(isOn: $prefs.customStand, tint: Theme.move)
                }
                if prefs.customStand {
                    HStack {
                        Text("Every")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        ValueStepper(value: $prefs.customStandMinutes, range: 10...120, step: 5) { "\($0) min" }
                    }
                }
            }
            .card(padding: 12, radius: 16)
        }
    }

    private var mindSection: some View {
        VStack(spacing: 8) {
            SectionTitle(text: "Mind")
            VStack(spacing: 0) {
                Row(title: "Practice") {
                    HStack(spacing: 4) {
                        Chip(title: "NSDR", selected: prefs.mindKind == .nsdr, tint: Theme.mind) { prefs.mindKind = .nsdr }
                        Chip(title: "Meditation", selected: prefs.mindKind == .meditation, tint: Theme.mind) { prefs.mindKind = .meditation }
                    }
                    .frame(width: 150)
                }
                Divider().overlay(Theme.stroke)
                Row(title: "Daily goal") {
                    ValueStepper(value: $prefs.mindGoal, range: 5...30, step: 5) { "\($0) min" }
                }
                Divider().overlay(Theme.stroke)
                Row(title: "Remind me daily") {
                    PillToggle(isOn: $prefs.mindReminder, tint: Theme.mind)
                }
                if prefs.mindReminder {
                    Divider().overlay(Theme.stroke)
                    Row(title: "At", subtitle: "Only if you haven't done it yet") {
                        ValueStepper(value: $prefs.mindReminderAt, range: 6 * 60...21 * 60, step: 30) { Fmt.timeOfDay($0) }
                    }
                }
                Divider().overlay(Theme.stroke)
                Row(title: "Voice guidance", subtitle: "A calm voice talks you through each session") {
                    PillToggle(isOn: $prefs.voiceGuidance, tint: Theme.mind)
                }
                Divider().overlay(Theme.stroke)
                Row(title: "Count in health score") {
                    PillToggle(isOn: $prefs.mindInScore, tint: Theme.mind)
                }
            }
            .card(padding: 4, radius: 16)
        }
    }

    private var digitalSection: some View {
        VStack(spacing: 8) {
            SectionTitle(text: "Digital hygiene")
            VStack(spacing: 0) {
                Row(title: "Track social media", subtitle: "Counts time in the apps below") {
                    PillToggle(isOn: $prefs.socialTracking, tint: Theme.digital)
                }
                if prefs.socialTracking {
                    Divider().overlay(Theme.stroke)
                    Row(title: "Daily limit") {
                        ValueStepper(value: $prefs.socialLimit, range: 10...180, step: 5) { "\($0) min" }
                    }
                    Divider().overlay(Theme.stroke)
                    Row(title: "Nudge after 5 min of scrolling") {
                        PillToggle(isOn: $prefs.scrollNudge, tint: Theme.digital)
                    }
                    Divider().overlay(Theme.stroke)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Apps")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        FlowLayout(spacing: 5) {
                            ForEach(installedSocialApps, id: \.self) { id in
                                RemovableChip(title: Distractions.name(for: id)) {
                                    prefs.socialApps.removeAll { $0 == id }
                                }
                            }
                            AddChip(title: "Add app") { addApp() }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    Divider().overlay(Theme.stroke)
                    Row(title: "Also count websites", subtitle: "Safari, Chrome, Arc, Brave, Edge and Vivaldi. macOS asks you once.") {
                        PillToggle(isOn: $prefs.trackWebsites, tint: Theme.digital)
                    }
                    if prefs.trackWebsites {
                        if mind.websitesDenied {
                            Text("TAB isn't allowed to read your browser yet. Turn it on in System Settings › Privacy & Security › Automation.")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.alert)
                                .padding(.horizontal, 10)
                                .padding(.bottom, 6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        FlowLayout(spacing: 5) {
                            ForEach(prefs.socialSites, id: \.self) { site in
                                RemovableChip(title: site) { prefs.socialSites.removeAll { $0 == site } }
                            }
                            AddChip(title: "Add website") { addSite() }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 9)
                    }
                }
                Divider().overlay(Theme.stroke)
                Row(title: "Lock my iPhone while I focus", subtitle: "Needs TAB on your iPhone") {
                    PillToggle(isOn: $prefs.lockPhone, tint: Theme.digital)
                }
                Divider().overlay(Theme.stroke)
                Row(title: "iPhone", subtitle: phoneSubtitle) {
                    Button(link.isPairing ? "Cancel" : (link.phones.isEmpty ? "Pair" : "Pair new")) {
                        link.isPairing ? link.cancelPairing() : link.beginPairing()
                    }
                    .buttonStyle(PillButtonStyle(filled: link.phones.isEmpty && !link.isPairing, tint: Theme.digital, height: 26))
                    .frame(width: 92)
                }
                if !link.phones.isEmpty {
                    FlowLayout(spacing: 5) {
                        ForEach(link.phones) { phone in
                            RemovableChip(title: phone.name) { link.forget(phone) }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 9)
                }
                Divider().overlay(Theme.stroke)
                Row(title: "Push key", subtitle: link.keyID.map { "Key \($0) is saved in your keychain" }
                    ?? "AuthKey file from your Apple developer account. Locks your iPhone instantly.") {
                    Button("Choose…") { choosePushKey() }
                        .buttonStyle(PillButtonStyle(filled: false, height: 26))
                        .frame(width: 92)
                }
                Divider().overlay(Theme.stroke)
                Row(title: "Notifications only in breaks", subtitle: "Do Not Disturb while you focus, via Shortcuts") {
                    PillToggle(isOn: $prefs.silenceWhileFocus, tint: Theme.digital)
                }
                if prefs.silenceWhileFocus && !mind.shortcutsReady {
                    ShortcutSetup()
                        .padding(.horizontal, 6)
                        .padding(.bottom, 6)
                }
            }
            .card(padding: 4, radius: 16)
        }
    }

    private var phoneSubtitle: String {
        if let until = link.pairingUntil, until > Date() {
            return "Open TAB on your iPhone and tap Connect. Waiting \(Fmt.clock(Int(until.timeIntervalSinceNow)))"
        }
        if link.phones.isEmpty { return "Not paired yet. Both need to be on the same Wi-Fi." }
        if let last = link.lastPhoneUpdate { return "Paired · last seen \(Fmt.time(last))" }
        return "Paired"
    }

    private func choosePushKey() {
        let panel = NSOpenPanel()
        panel.title = "Choose your AuthKey file"
        panel.allowedContentTypes = [UTType(filenameExtension: "p8") ?? .data]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        PanelController.shared?.keepOpen = true
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try link.importKey(from: url)
            } catch {
                let alert = NSAlert()
                alert.messageText = "That key didn't work"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
        PanelController.shared?.keepOpen = false
    }

    private var installedSocialApps: [String] {
        prefs.socialApps.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }

    private func addApp() {
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (String, String)? in
                guard let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier,
                      !prefs.socialApps.contains(id) else { return nil }
                return (id, app.localizedName ?? id)
            }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
        let items: [NSMenuItem] = running.isEmpty
            ? [NSMenuItem(title: "Open the app first, then add it here", action: nil, keyEquivalent: "")]
            : running.map { id, name in MenuAction(name) { prefs.socialApps.append(id) } }
        Popup.show(items)
    }

    private func addSite() {
        let alert = NSAlert()
        alert.messageText = "Add a website"
        alert.informativeText = "For example tiktok.com. Subdomains count too."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "example.com"
        alert.accessoryView = field
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        PanelController.shared?.keepOpen = true
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            var site = field.stringValue.lowercased().trimmingCharacters(in: .whitespaces)
            if let host = URL(string: site.contains("://") ? site : "https://" + site)?.host { site = host }
            if site.hasPrefix("www.") { site.removeFirst(4) }
            if !site.isEmpty && !prefs.socialSites.contains(site) { prefs.socialSites.append(site) }
        }
        PanelController.shared?.keepOpen = false
    }

    private var smart: some View {
        VStack(spacing: 8) {
            SectionTitle(text: "Smart tracking")
            VStack(spacing: 0) {
                Row(title: "Notice when I'm away", subtitle: "Time away from the Mac counts as a break") {
                    PillToggle(isOn: $prefs.detectAway)
                }
                Divider().overlay(Theme.stroke)
                Row(title: "Timer in menu bar") {
                    PillToggle(isOn: $prefs.showTimer)
                }
            }
            .card(padding: 4, radius: 16)
        }
    }

    private var sound: some View {
        VStack(spacing: 8) {
            SectionTitle(text: "Sound")
            VStack(spacing: 0) {
                Row(title: "Play sounds") {
                    PillToggle(isOn: $prefs.soundEnabled)
                }
                if prefs.soundEnabled {
                    Divider().overlay(Theme.stroke)
                    Row(title: "Sound") {
                        Button {
                            Popup.show(SoundPlayer.systemSounds.map { name in
                                MenuAction(name, checked: prefs.customSoundPath.isEmpty && prefs.soundName == name) {
                                    prefs.customSoundPath = ""
                                    prefs.soundName = name
                                    SoundPlayer.playSystem(name)
                                }
                            })
                        } label: {
                            HStack(spacing: 4) {
                                Text(currentSoundName).lineLimit(1).truncationMode(.middle)
                                Image(systemName: "chevron.up.chevron.down").font(.system(size: 8, weight: .bold))
                            }
                        }
                        .buttonStyle(PillButtonStyle(filled: false, height: 26))
                        .frame(maxWidth: 130)
                    }
                    Divider().overlay(Theme.stroke)
                    Row(title: "Custom sound file") {
                        HStack(spacing: 6) {
                            if !prefs.customSoundPath.isEmpty {
                                Button { prefs.customSoundPath = "" } label: { Image(systemName: "xmark") }
                                    .buttonStyle(IconButtonStyle(size: 24, tint: Theme.alert))
                            }
                            Button("Choose…") { chooseSound() }
                                .buttonStyle(PillButtonStyle(filled: false, height: 26))
                                .frame(width: 92)
                            Button { SoundPlayer.play(prefs) } label: { Image(systemName: "play.fill") }
                                .buttonStyle(IconButtonStyle(size: 24))
                        }
                    }
                }
            }
            .card(padding: 4, radius: 16)
        }
    }

    private var general: some View {
        VStack(spacing: 8) {
            SectionTitle(text: "General")
            VStack(spacing: 0) {
                Row(title: "Start TAB at login", subtitle: LoginItem.needsApproval ? "Approve TAB in System Settings › Login Items" : nil) {
                    PillToggle(isOn: Binding(
                        get: { launchAtLogin },
                        set: { on in
                            launchAtLogin = on
                            LoginItem.setEnabled(on)
                        }
                    ))
                }
                Divider().overlay(Theme.stroke)
                Row(title: "Export data", subtitle: "Every day as a CSV file") {
                    Button("Export…") { exportCSV() }
                        .buttonStyle(PillButtonStyle(filled: false, height: 26))
                        .frame(width: 92)
                }
                Divider().overlay(Theme.stroke)
                Row(title: "Erase history") {
                    Button("Erase…") { erase() }
                        .buttonStyle(PillButtonStyle(filled: false, tint: Theme.alert, height: 26))
                        .frame(width: 92)
                }
            }
            .card(padding: 4, radius: 16)
            Button("Quit TAB") { NSApp.terminate(nil) }
                .buttonStyle(PillButtonStyle(filled: false, tint: Theme.dim, height: 32))
        }
    }

    private var currentSoundName: String {
        prefs.customSoundPath.isEmpty ? prefs.soundName : URL(fileURLWithPath: prefs.customSoundPath).lastPathComponent
    }

    private func chooseSound() {
        let panel = NSOpenPanel()
        panel.title = "Choose a sound"
        panel.allowedContentTypes = [.audio]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        PanelController.shared?.keepOpen = true
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            prefs.customSoundPath = url.path
            SoundPlayer.playFile(url.path)
        }
        PanelController.shared?.keepOpen = false
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.title = "Export TAB history"
        panel.nameFieldStringValue = "TAB History \(HistoryStore.key(Date())).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        PanelController.shared?.keepOpen = true
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            try? store.csv().write(to: url, atomically: true, encoding: .utf8)
        }
        PanelController.shared?.keepOpen = false
    }

    private func erase() {
        let alert = NSAlert()
        alert.messageText = "Erase all history?"
        alert.informativeText = "This deletes every day TAB has tracked. Your settings stay as they are."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Erase")
        alert.addButton(withTitle: "Cancel")
        PanelController.shared?.keepOpen = true
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            store.eraseAll()
        }
        PanelController.shared?.keepOpen = false
    }
}

struct Row<Trailing: View>: View {
    var title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 6)
            trailing
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }
}

struct StyleCard: View {
    var style: BreakStyle
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: style.symbol)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(selected ? .black : .white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(selected ? Color.white : Color.white.opacity(0.08)))
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundColor(selected ? .white : Theme.faint)
                }
                Text(style.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(style.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(selected ? Color.white.opacity(0.1) : Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(selected ? Color.white.opacity(0.5) : Theme.stroke))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

extension Bundle {
    var version: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "2.1"
    }
}
