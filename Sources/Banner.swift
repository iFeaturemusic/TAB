import AppKit
import Combine
import SwiftUI

struct BannerView: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var prefs: Preferences
    var nudge: Nudge

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                MascotView(mood: nudge == .welcomeBack ? .happy : .alert, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(NudgeCopy.title(nudge, engine: engine))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(NudgeCopy.message(nudge, engine: engine, prefs: prefs))
                        .font(.system(size: 12))
                        .foregroundColor(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button { engine.dismissNudge() } label: { Image(systemName: "xmark") }
                    .buttonStyle(IconButtonStyle(size: 20, tint: Theme.dim))
            }
            NudgeButtons(nudge: nudge)
        }
        .padding(14)
        .frame(width: 330)
        .background(
            ZStack {
                Theme.bg
                LinearGradient(colors: [accent.opacity(0.14), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
        .environment(\.colorScheme, .dark)
    }

    private var accent: Color {
        switch nudge {
        case .breakTime, .welcomeBack: return Theme.rest
        case .lockSoon: return Theme.alert
        case .stand: return Theme.move
        case .water: return Theme.water
        }
    }
}

final class BannerController {
    private let engine: Engine
    private let prefs: Preferences
    private let anchor: () -> NSRect?
    private var panel: FloatingPanel?
    private var bag = Set<AnyCancellable>()
    private var panelOpen = false

    init(engine: Engine, prefs: Preferences, anchor: @escaping () -> NSRect?, panelVisibility: AnyPublisher<Bool, Never>) {
        self.engine = engine
        self.prefs = prefs
        self.anchor = anchor

        engine.$nudge
            .combineLatest(engine.$isScreenLocked, panelVisibility)
            .receive(on: RunLoop.main)
            .sink { [weak self] nudge, locked, open in
                self?.panelOpen = open
                if let nudge, !locked, !open {
                    self?.present(nudge)
                } else {
                    self?.dismiss()
                }
            }
            .store(in: &bag)
    }

    private func present(_ nudge: Nudge) {
        let view = BannerView(nudge: nudge)
            .environmentObject(engine)
            .environmentObject(prefs)
        let host = FirstMouseHostingView(rootView: view)
        let size = host.fittingSize
        let panel = self.panel ?? FloatingPanel(size: size, focusable: false)
        panel.contentView = host
        let wasVisible = panel.isVisible
        panel.setFrame(frame(for: size), display: true)
        if !wasVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                panel.animator().alphaValue = 1
            }
        }
        self.panel = panel
    }

    private func dismiss() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func frame(for size: NSSize) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        var x = visible.maxX - size.width - 12
        if let a = anchor(), screen.frame.contains(NSPoint(x: a.midX, y: a.midY)) {
            x = min(max(a.midX - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
        }
        let y = visible.maxY - size.height - 8
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}
