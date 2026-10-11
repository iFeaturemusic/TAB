import AppKit
import Combine
import SwiftUI

enum FaceIcon {
    static func image(_ mood: Mood, blink: Bool = false) -> NSImage {
        let size = NSSize(width: 20, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            NSColor.black.set()
            NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 4.6, yRadius: 4.6).fill()

            ctx.setBlendMode(.clear)
            let cx = rect.midX
            let cy = rect.midY
            let eyeX: CGFloat = 5.1
            let eyeW: CGFloat = 2.2
            let eyeH: CGFloat = 3.8

            func open(_ x: CGFloat) {
                NSBezierPath(roundedRect: NSRect(x: x - eyeW / 2, y: cy - eyeH / 2 + 0.2, width: eyeW, height: eyeH),
                             xRadius: 1, yRadius: 1).fill()
            }
            func closed(_ x: CGFloat) {
                NSBezierPath(roundedRect: NSRect(x: x - 1.6, y: cy - 0.4, width: 3.2, height: 1.3),
                             xRadius: 0.6, yRadius: 0.6).fill()
            }
            func sleepy(_ x: CGFloat) {
                let p = NSBezierPath()
                p.lineWidth = 1.2
                p.lineCapStyle = .round
                p.move(to: NSPoint(x: x - 1.8, y: cy + 0.6))
                p.curve(to: NSPoint(x: x + 1.8, y: cy + 0.6),
                        controlPoint1: NSPoint(x: x - 1, y: cy - 1),
                        controlPoint2: NSPoint(x: x + 1, y: cy - 1))
                p.stroke()
            }

            switch mood {
            case .sleepy:
                sleepy(cx - eyeX)
                sleepy(cx + eyeX)
            case .wink:
                closed(cx - eyeX)
                open(cx + eyeX)
            default:
                if blink {
                    closed(cx - eyeX)
                    closed(cx + eyeX)
                } else {
                    open(cx - eyeX)
                    open(cx + eyeX)
                }
            }

            let mouth = NSBezierPath()
            mouth.lineWidth = 1.3
            mouth.lineCapStyle = .round
            switch mood {
            case .alert:
                let ring = NSBezierPath(ovalIn: NSRect(x: cx - 1.4, y: cy - 2.0, width: 2.8, height: 3.0))
                ring.lineWidth = 1.1
                ring.stroke()
            case .calm:
                mouth.move(to: NSPoint(x: cx - 1.8, y: cy - 0.2))
                mouth.line(to: NSPoint(x: cx + 1.8, y: cy - 0.2))
                mouth.stroke()
            case .sleepy:
                mouth.move(to: NSPoint(x: cx - 1.1, y: cy - 1.2))
                mouth.line(to: NSPoint(x: cx + 1.1, y: cy - 1.2))
                mouth.stroke()
            default:
                mouth.move(to: NSPoint(x: cx - 2.7, y: cy + 1.0))
                mouth.curve(to: NSPoint(x: cx + 2.7, y: cy + 1.0),
                            controlPoint1: NSPoint(x: cx - 1.5, y: cy - 1.9),
                            controlPoint2: NSPoint(x: cx + 1.5, y: cy - 1.9))
                mouth.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

final class StatusBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let engine: Engine
    private let prefs: Preferences
    private let panel: PanelController
    private var bag = Set<AnyCancellable>()
    private var blinking = false
    private var winking = false

    init(engine: Engine, prefs: Preferences, store: HistoryStore) {
        self.engine = engine
        self.prefs = prefs
        panel = PanelController(root: RootView()
            .environmentObject(engine)
            .environmentObject(prefs)
            .environmentObject(store))
        super.init()

        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
        }
        panel.anchor = { [weak self] in self?.anchorFrame }

        engine.objectWillChange
            .merge(with: prefs.objectWillChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &bag)
        refresh()
        scheduleBlink()
    }

    var anchorFrame: NSRect? {
        guard let button = item.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    var isPanelVisible: Bool { panel.isVisible }

    func showPanel() {
        if !panel.isVisible { panel.show() }
    }
    var panelVisibility: AnyPublisher<Bool, Never> { panel.$visible.eraseToAnyPublisher() }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showQuickMenu()
            return
        }
        winking = true
        refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.winking = false
            self?.refresh()
        }
        panel.toggle()
    }

    private func showQuickMenu() {
        let menu = NSMenu()
        if engine.phase == .onBreak {
            menu.addItem(MenuAction("I'm back", symbol: "arrow.uturn.backward") { [weak self] in self?.engine.endBreak() })
        } else {
            menu.addItem(MenuAction("Take a break", symbol: "cup.and.saucer") { [weak self] in self?.engine.beginBreak(.manual) })
        }
        menu.addItem(MenuAction("Log a glass of water", symbol: "drop") { [weak self] in self?.engine.logWater() })
        menu.addItem(MenuAction("I stood up", symbol: "figure.walk") { [weak self] in self?.engine.logStand() })
        menu.addItem(.separator())
        Popup.pauseItems(engine).forEach(menu.addItem)
        menu.addItem(.separator())
        menu.addItem(MenuAction("Open TAB", symbol: "face.smiling") { [weak self] in self?.panel.show() })
        let quit = NSMenuItem(title: "Quit TAB", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    private var mood: Mood {
        if winking { return .wink }
        switch engine.phase {
        case .focus: return engine.nudge == nil ? .happy : .alert
        case .onBreak: return engine.breakComplete ? .happy : .sleepy
        case .away: return .sleepy
        case .paused: return .calm
        }
    }

    private var title: String {
        guard prefs.showTimer else { return "" }
        switch engine.phase {
        case .focus:
            if engine.nudge == .breakTime { return "break" }
            if engine.focusLeft < 60 || engine.nudge == .lockSoon { return Fmt.clock(engine.focusLeft) }
            return "\((engine.focusLeft + 59) / 60)m"
        case .onBreak:
            return engine.breakComplete ? "back?" : Fmt.clock(engine.breakLeft)
        case .away, .paused:
            return ""
        }
    }

    private func refresh() {
        guard let button = item.button else { return }
        button.image = FaceIcon.image(mood, blink: blinking)
        let text = title
        if text.isEmpty {
            button.attributedTitle = NSAttributedString(string: "")
            button.imagePosition = .imageOnly
        } else {
            button.imagePosition = .imageLeading
            button.attributedTitle = NSAttributedString(string: " " + text, attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                .baselineOffset: 0.5,
            ])
        }
    }

    private func scheduleBlink() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .random(in: 8...20)) { [weak self] in
            guard let self else { return }
            self.blinking = true
            self.refresh()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                self.blinking = false
                self.refresh()
                self.scheduleBlink()
            }
        }
    }
}

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class FloatingPanel: NSPanel {
    var onCancel: (() -> Void)?

    init(size: NSSize, focusable: Bool) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        canTakeFocus = focusable
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        animationBehavior = .utilityWindow
    }

    private var canTakeFocus = true

    override var canBecomeKey: Bool { canTakeFocus }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

final class PanelController: NSObject, NSWindowDelegate, ObservableObject {
    static weak var shared: PanelController?

    @Published private(set) var visible = false
    var anchor: () -> NSRect? = { nil }
    var keepOpen = false

    private let panel: FloatingPanel
    private var lastClose = Date.distantPast

    init<Content: View>(root: Content) {
        panel = FloatingPanel(size: RootView.size, focusable: true)
        super.init()
        let host = FirstMouseHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: RootView.size)
        panel.contentView = host
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.hide() }
        Self.shared = self
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        if panel.isVisible {
            hide()
        } else if Date().timeIntervalSince(lastClose) > 0.25 {
            show()
        }
    }

    func show() {
        position()
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            panel.animator().alphaValue = 1
        }
        visible = true
    }

    func hide() {
        guard panel.isVisible else { return }
        lastClose = Date()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
            self?.panel.alphaValue = 1
        })
        visible = false
    }

    private func position() {
        let size = RootView.size
        let screen = NSScreen.screens.first { $0.frame.contains(anchor()?.origin ?? .zero) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var x: CGFloat
        var y: CGFloat
        if let a = anchor() {
            x = a.midX - size.width / 2
            y = a.minY - size.height - 6
        } else {
            x = visibleFrame.maxX - size.width - 12
            y = visibleFrame.maxY - size.height - 6
        }
        x = min(max(x, visibleFrame.minX + 8), visibleFrame.maxX - size.width - 8)
        y = max(y, visibleFrame.minY + 8)
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !keepOpen else { return }
        hide()
    }
}
