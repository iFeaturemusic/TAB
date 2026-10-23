import AppKit
import Combine
import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var mind: Mind

    var body: some View {
        let done = engine.breakComplete
        ZStack {
            Theme.bg.opacity(0.97).ignoresSafeArea()
            RadialGradient(colors: [(done ? Theme.rest : Color.white).opacity(0.12), .clear],
                           center: .center, startRadius: 0, endRadius: 520)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                MascotView(mood: done ? .happy : .sleepy, size: 96)

                VStack(spacing: 10) {
                    Text(done ? "Welcome back" : "Time for a break")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text(done
                         ? "You rested for \(Fmt.duration(engine.breakElapsed)). Your eyes and back say thanks."
                         : "Step away from the screen, drink some water and stretch a little.")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.dim)
                        .multilineTextAlignment(.center)
                }

                ZStack {
                    RingView(progress: engine.breakProgress, color: done ? Theme.rest : .white, lineWidth: 12)
                    VStack(spacing: 2) {
                        Text(done ? "Done" : Fmt.clock(engine.breakLeft))
                            .font(.system(size: 46, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white)
                        Text(done ? "break complete" : "left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.dim)
                    }
                }
                .frame(width: 190, height: 190)

                if done {
                    Button { engine.endBreak() } label: {
                        Label("I'm back", systemImage: "arrow.uturn.backward")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .buttonStyle(PillButtonStyle(filled: true, tint: Theme.rest, height: 48))
                    .frame(width: 220)
                } else if let session = mind.session, session.kind == .breathing {
                    HStack(spacing: 18) {
                        BreathingGuide(start: session.start, size: 84)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mind.cue)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Physiological sigh · \(Fmt.clock(mind.remaining)) left")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.dim)
                        }
                        Spacer(minLength: 0)
                    }
                    .card(padding: 14, radius: 20)
                    .frame(width: 420)
                } else {
                    StretchCard(stretch: engine.stretch)
                        .frame(width: 420)
                }

                HStack(spacing: 12) {
                    CheckChip(title: "I drank water", symbol: "drop.fill", tint: Theme.water, done: engine.loggedWaterThisBreak) {
                        engine.logWater()
                    }
                    CheckChip(title: "I stretched", symbol: "figure.flexibility", tint: Theme.move, done: engine.stretchedThisBreak) {
                        engine.logStand()
                    }
                    CheckChip(title: "Breathe", symbol: "wind", tint: Theme.breath, done: engine.breathedThisBreak) {
                        mind.begin(.breathing, minutes: 1, inline: true)
                    }
                }
            }
            .padding(40)

            if prefs.allowSkip && !done {
                VStack {
                    Spacer()
                    HoldToSkip { engine.emergencySkip() }
                        .padding(.bottom, 28)
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

struct StretchCard: View {
    var stretch: Stretch

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: stretch.symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(Theme.move)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Theme.move.opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                Text(stretch.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(stretch.detail)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .card(padding: 14, radius: 20)
    }
}

struct CheckChip: View {
    var title: String
    var symbol: String
    var tint: Color
    var done: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: done ? "checkmark.circle.fill" : symbol)
                    .foregroundColor(done ? Theme.rest : tint)
                Text(title)
                    .foregroundColor(.white)
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(Capsule().fill(done ? Theme.rest.opacity(0.14) : Color.white.opacity(0.07)))
            .overlay(Capsule().strokeBorder(done ? Theme.rest.opacity(0.4) : Theme.stroke))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!done)
    }
}

struct HoldToSkip: View {
    var action: () -> Void
    @State private var pressing = false

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.06))
            Capsule()
                .fill(Theme.alert.opacity(0.35))
                .frame(width: pressing ? 220 : 0)
                .animation(pressing ? .linear(duration: 3) : .easeOut(duration: 0.2), value: pressing)
            Text(pressing ? "Keep holding…" : "Hold to skip (emergency)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.dim)
                .frame(width: 220)
        }
        .frame(width: 220, height: 34)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.stroke))
        .onLongPressGesture(minimumDuration: 3, maximumDistance: 40, pressing: { pressing = $0 }, perform: action)
    }
}

final class LockWindow: NSWindow {
    var onEscape: (() -> Void)?

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        setFrame(screen.frame, display: true)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?() }
    }
    override func keyUp(with event: NSEvent) {}
}

final class LockScreenController {
    private let engine: Engine
    private let prefs: Preferences
    private let mind: Mind
    private var windows: [LockWindow] = []
    private var bag = Set<AnyCancellable>()

    init(engine: Engine, prefs: Preferences, mind: Mind) {
        self.engine = engine
        self.prefs = prefs
        self.mind = mind

        engine.$isScreenLocked
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] locked in locked ? self?.show() : self?.hide() }
            .store(in: &bag)

        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] note in
                guard let self, !self.windows.isEmpty else { return }
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                if app?.bundleIdentifier != Bundle.main.bundleIdentifier {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.bringToFront() }
                }
            }
            .store(in: &bag)

        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                guard let self, !self.windows.isEmpty else { return }
                self.hide()
                self.show()
            }
            .store(in: &bag)
    }

    private func show() {
        guard windows.isEmpty else { return }
        NSApp.activate(ignoringOtherApps: true)
        for screen in NSScreen.screens {
            let window = LockWindow(screen: screen)
            window.contentView = FirstMouseHostingView(rootView: LockScreenView()
                .environmentObject(engine)
                .environmentObject(prefs)
                .environmentObject(mind))
            window.alphaValue = 0
            window.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.4
                window.animator().alphaValue = 1
            }
            windows.append(window)
        }
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching, .disableHideApplication]
    }

    private func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        windows.forEach { $0.makeKeyAndOrderFront(nil) }
    }

    private func hide() {
        NSApp.presentationOptions = []
        let closing = windows
        windows = []
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            closing.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            closing.forEach { $0.orderOut(nil) }
        })
    }
}
