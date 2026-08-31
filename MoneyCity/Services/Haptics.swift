import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Central haptic feedback gate. Respects the user's "haptics_enabled" preference,
/// which was previously stored but never checked at any call site.
public enum Haptics {

    public static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "haptics_enabled") as? Bool ?? true
    }

    public enum Notification { case success, warning, error }
    public enum Impact { case light, medium, heavy }

    @MainActor
    public static func notify(_ type: Notification) {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        switch type {
        case .success: generator.notificationOccurred(.success)
        case .warning: generator.notificationOccurred(.warning)
        case .error:   generator.notificationOccurred(.error)
        }
        #endif
    }

    @MainActor
    public static func impact(_ style: Impact) {
        guard isEnabled else { return }
        #if canImport(UIKit)
        switch style {
        case .light:  UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:  UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        #endif
    }

    @MainActor
    public static func selection() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}
