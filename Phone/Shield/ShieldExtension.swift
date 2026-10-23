import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(token: application.token)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(token: application.token)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(token: nil)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        make(token: nil)
    }

    private func make(token: ApplicationToken?) -> ShieldConfiguration {
        let phone = PhoneStore.shared
        let config = phone.config
        let isSocial = token.map { config.social.applicationTokens.contains($0) } ?? false
        let left = phone.passesLeft
        let canPass = left > 0 && config.passMinutes > 0 && (config.mode == .socialOnly || isSocial)

        var subtitle = "Your Mac is in focus mode"
        if let until = phone.focus.until {
            let f = DateFormatter()
            f.timeStyle = .short
            subtitle += " until \(f.string(from: until))"
        }
        subtitle += ". Take a breath and get back to it."
        if canPass {
            subtitle += "\n\nNeed to post something? You have \(left) \(left == 1 ? "pass" : "passes") left today."
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.055, green: 0.063, blue: 0.078, alpha: 0.92),
            icon: Self.face,
            title: ShieldConfiguration.Label(text: "Focus time", color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor(white: 0.7, alpha: 1)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "OK", color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: canPass ? ShieldConfiguration.Label(text: "Post for \(config.passMinutes) min", color: UIColor(red: 0.96, green: 0.66, blue: 0.81, alpha: 1)) : nil
        )
    }

    private static let face: UIImage = {
        let size = CGSize(width: 120, height: 120)
        return UIGraphicsImageRenderer(size: size).image { _ in
            UIColor.black.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 34).fill()
            UIColor.white.setFill()
            UIColor.white.setStroke()
            let eyeW: CGFloat = 10
            let eyeH: CGFloat = 17
            for x: CGFloat in [30, 90] {
                UIBezierPath(roundedRect: CGRect(x: x - eyeW / 2, y: 60 - eyeH / 2, width: eyeW, height: eyeH), cornerRadius: 4.5).fill()
            }
            let mouth = UIBezierPath()
            mouth.lineWidth = 4
            mouth.lineCapStyle = .round
            mouth.move(to: CGPoint(x: 44, y: 56))
            mouth.addQuadCurve(to: CGPoint(x: 76, y: 56), controlPoint: CGPoint(x: 60, y: 74))
            mouth.stroke()
        }
    }()
}
