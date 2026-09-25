import UIKit

enum Haptics {
    static func tap() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        g.impactOccurred()
    }

    static func soft() {
        let g = UIImpactFeedbackGenerator(style: .soft)
        g.prepare()
        g.impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
