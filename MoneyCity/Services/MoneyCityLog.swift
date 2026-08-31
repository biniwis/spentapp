import Foundation

/// Logging that cannot leak spending data out of a release build.
///
/// A merchant name, an amount and a timestamp together describe a person's life in some
/// detail, so none of it belongs in a device console that any connected Mac can read.
/// Every call here compiles away entirely outside DEBUG — there is no runtime flag to
/// forget to switch off, and no redaction rule to get wrong.
public enum MoneyCityLog {

    /// Ordinary development tracing.
    public static func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[SPENT] \(message())")
        #endif
    }

    /// A failure worth seeing while developing. Pass the error, never the payload.
    public static func error(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[SPENT][error] \(message())")
        #endif
    }

    /// Raw financial payloads. DEBUG only, by construction.
    ///
    /// In a release build the equivalent evidence still exists — it goes to `IngestLogEntry`,
    /// which stays on device, is capped, and the user can clear.
    public static func sensitive(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[SPENT][raw] \(message())")
        #endif
    }

    /// True only in a debug build. Use it to decide whether diagnostics may be shown in UI.
    public static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
