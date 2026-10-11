import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Theme {
    static let bg = Color(hex: 0x0E1014)
    static let raised = Color(hex: 0x161920)
    static let card = Color.white.opacity(0.05)
    static let stroke = Color.white.opacity(0.08)
    static let text = Color.white
    static let dim = Color(hex: 0x8D95A3)
    static let faint = Color.white.opacity(0.32)

    static let water = Color(hex: 0x5CC8FF)
    static let rest = Color(hex: 0x7EE2B0)
    static let move = Color(hex: 0xFFB672)
    static let score = Color(hex: 0xC7A6FF)
    static let alert = Color(hex: 0xFF6B6B)
}

enum Fmt {
    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60) }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static func duration(_ seconds: Int) -> String {
        let s = max(0, seconds)
        if s < 60 { return "\(s)s" }
        let h = s / 3600
        let m = (s % 3600) / 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    static func short(_ seconds: Int) -> String {
        let s = max(0, seconds)
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        return String(format: "%dh%02d", s / 3600, (s % 3600) / 60)
    }

    static func water(_ ml: Int, ounces: Bool) -> String {
        if ounces {
            let oz = Double(ml) / 29.5735
            return oz >= 10 ? "\(Int(oz.rounded())) oz" : String(format: "%.1f oz", oz)
        }
        if ml >= 1000 {
            let liters = Double(ml) / 1000
            let text = String(format: "%.2f", liters)
                .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
            return "\(text) L"
        }
        return "\(ml) ml"
    }

    static func number(_ value: Double) -> String {
        value >= 10 || value == value.rounded() ? "\(Int(value.rounded()))" : String(format: "%.1f", value)
    }

    static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }

    static func scoreLabel(_ score: Int?) -> String {
        guard let score else { return "No data yet" }
        switch score {
        case 85...: return "Thriving"
        case 70..<85: return "Looking good"
        case 50..<70: return "Could be better"
        default: return "Needs some care"
        }
    }
}

enum Mood {
    case happy
    case alert
    case sleepy
    case calm
    case wink
}

struct MascotView: View {
    var mood: Mood = .happy
    var size: CGFloat = 40
    var animated = true
    var boxed = true

    @State private var blink = false

    var body: some View {
        Canvas { ctx, canvas in
            let s = canvas.width
            let box = CGRect(origin: .zero, size: canvas)
            if boxed {
                ctx.fill(Path(roundedRect: box, cornerRadius: s * 0.28, style: .continuous), with: .color(.black))
                ctx.stroke(Path(roundedRect: box.insetBy(dx: 0.5, dy: 0.5), cornerRadius: s * 0.28, style: .continuous),
                           with: .color(.white.opacity(0.12)), lineWidth: 1)
            }
            let cx = s / 2
            let cy = s / 2
            let eyeW = s * 0.085
            let eyeH = s * 0.14
            let eyeX = s * 0.255
            let white = GraphicsContext.Shading.color(.white)

            func openEye(_ x: CGFloat) {
                let r = CGRect(x: x - eyeW / 2, y: cy - eyeH / 2, width: eyeW, height: eyeH)
                ctx.fill(Path(roundedRect: r, cornerRadius: eyeW * 0.45), with: white)
            }
            func closedEye(_ x: CGFloat) {
                let w = eyeW * 1.6
                let h = max(1.5, s * 0.03)
                let r = CGRect(x: x - w / 2, y: cy - h / 2 + eyeH * 0.15, width: w, height: h)
                ctx.fill(Path(roundedRect: r, cornerRadius: h / 2), with: white)
            }
            func sleepyEye(_ x: CGFloat) {
                var p = Path()
                let w = eyeW * 1.9
                p.move(to: CGPoint(x: x - w / 2, y: cy))
                p.addQuadCurve(to: CGPoint(x: x + w / 2, y: cy), control: CGPoint(x: x, y: cy + eyeH * 0.55))
                ctx.stroke(p, with: white, style: StrokeStyle(lineWidth: max(1.5, s * 0.032), lineCap: .round))
            }

            let blinking = blink && mood != .sleepy
            switch mood {
            case .sleepy:
                sleepyEye(cx - eyeX)
                sleepyEye(cx + eyeX)
            case .wink:
                closedEye(cx - eyeX)
                openEye(cx + eyeX)
            default:
                if blinking {
                    closedEye(cx - eyeX)
                    closedEye(cx + eyeX)
                } else {
                    openEye(cx - eyeX)
                    openEye(cx + eyeX)
                }
            }

            let line = StrokeStyle(lineWidth: max(1.5, s * 0.032), lineCap: .round)
            let mw = s * 0.135
            switch mood {
            case .alert:
                let r = s * 0.05
                ctx.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r * 0.6, width: r * 2, height: r * 2.2)), with: white, style: line)
            case .calm:
                var p = Path()
                p.move(to: CGPoint(x: cx - mw * 0.7, y: cy + s * 0.01))
                p.addLine(to: CGPoint(x: cx + mw * 0.7, y: cy + s * 0.01))
                ctx.stroke(p, with: white, style: line)
            case .sleepy:
                var p = Path()
                p.move(to: CGPoint(x: cx - mw * 0.35, y: cy + s * 0.06))
                p.addLine(to: CGPoint(x: cx + mw * 0.35, y: cy + s * 0.06))
                ctx.stroke(p, with: white, style: line)
            default:
                var p = Path()
                p.move(to: CGPoint(x: cx - mw, y: cy - s * 0.035))
                p.addQuadCurve(to: CGPoint(x: cx + mw, y: cy - s * 0.035), control: CGPoint(x: cx, y: cy + s * 0.12))
                ctx.stroke(p, with: white, style: line)
            }
        }
        .frame(width: size, height: size)
        .task(id: animated) {
            guard animated else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64.random(in: 2_500_000_000...6_000_000_000))
                blink = true
                try? await Task.sleep(nanoseconds: 130_000_000)
                blink = false
            }
        }
    }
}

struct RingView: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 8
    var track: Color = Color.white.opacity(0.07)

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.0001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
        }
    }
}

struct BarView: View {
    var progress: Double
    var color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.07))
                Capsule().fill(color).frame(width: max(4, geo.size.width * min(1, progress)))
            }
        }
        .frame(height: 4)
    }
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = 12
    var radius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.stroke))
    }
}

extension View {
    func card(padding: CGFloat = 12, radius: CGFloat = 16) -> some View {
        modifier(CardBackground(padding: padding, radius: radius))
    }
}

struct PillButtonStyle: ButtonStyle {
    var filled = true
    var tint: Color = .white
    var height: CGFloat = 36
    var expand = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(filled ? .black : tint)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: height)
            .frame(maxWidth: expand ? .infinity : nil)
            .background(Capsule().fill(filled ? tint : Color.white.opacity(0.07)))
            .overlay(Capsule().strokeBorder(filled ? Color.clear : Theme.stroke))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(Capsule())
    }
}

struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 26
    var tint: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundColor(tint)
            .frame(width: size, height: size)
            .background(Circle().fill(tint.opacity(configuration.isPressed ? 0.28 : 0.14)))
            .contentShape(Circle())
    }
}

struct PillToggle: View {
    @Binding var isOn: Bool
    var tint: Color = Theme.rest

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule().fill(isOn ? tint : Color.white.opacity(0.12))
            Circle().fill(.white).padding(2).shadow(color: .black.opacity(0.25), radius: 1, y: 1)
        }
        .frame(width: 34, height: 20)
        .contentShape(Capsule())
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { isOn.toggle() }
        }
    }
}

struct ValueStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step: Int = 1
    var label: (Int) -> String

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus", enabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - step)
            }
            Text(label(value))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .frame(minWidth: 58)
            stepButton("plus", enabled: value < range.upperBound) {
                value = min(range.upperBound, value + step)
            }
        }
        .padding(2)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Theme.stroke))
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .heavy))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .foregroundColor(enabled ? .white : Theme.faint)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct Chip: View {
    var title: String
    var selected: Bool
    var tint: Color = .white
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(selected ? .black : Theme.dim)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(height: 24)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(selected ? tint : Color.white.opacity(0.06)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SectionTitle: View {
    var text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundColor(Theme.faint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }
}
