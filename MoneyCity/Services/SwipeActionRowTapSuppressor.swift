import Foundation
import QuartzCore

/// Clean gesture coordinator that prevents parent `SwipeActionRow.onTapGesture` from firing
/// when an interactive accessory (e.g. inline confirmation ✓) inside the row is tapped.
@MainActor
public enum SwipeActionRowTapSuppressor {
    private static var suppressedUntilTimestamp: CFTimeInterval = 0

    /// Suppresses parent row tap gestures for the next 400 milliseconds.
    public static func suppressNext() {
        suppressedUntilTimestamp = CACurrentMediaTime() + 0.40
    }

    /// Checks whether the parent tap gesture should be ignored.
    public static func shouldSuppress() -> Bool {
        return CACurrentMediaTime() < suppressedUntilTimestamp
    }

    /// Resets suppression state immediately for testing.
    public static func resetForTesting() {
        suppressedUntilTimestamp = 0
    }
}
