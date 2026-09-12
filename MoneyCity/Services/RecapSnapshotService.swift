import Foundation
import SwiftData

/// The exact curated story of one closed month: the dynamic slots (moment + heroes), the
/// noticed rows and the Micro Fact. This is precisely the content the recap sheet renders,
/// so freezing it keeps archived months stable across app versions.
public struct RecapStorySnapshot: Codable, Sendable, Equatable {
    public var dynamicInsights: [MonthlyRecapDynamicInsight]
    public var noticedInsights: [MonthlyRecapDynamicInsight]
    public var microFactInsight: MonthlyRecapDynamicInsight?

    public init(
        dynamicInsights: [MonthlyRecapDynamicInsight] = [],
        noticedInsights: [MonthlyRecapDynamicInsight] = [],
        microFactInsight: MonthlyRecapDynamicInsight? = nil
    ) {
        self.dynamicInsights = dynamicInsights
        self.noticedInsights = noticedInsights
        self.microFactInsight = microFactInsight
    }
}

/// Persists and reads the frozen story of closed months. The freeze is idempotent: the first
/// freeze that succeeds for a month is the one kept, so later app versions can never rewrite
/// history through the archive.
@MainActor
public enum RecapSnapshotService {
    static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - Story mapping

    /// Extracts the selected story content from a generated recap.
    public static func story(from recap: MonthlyRecap) -> RecapStorySnapshot {
        RecapStorySnapshot(
            dynamicInsights: recap.dynamicInsights,
            noticedInsights: recap.noticedInsights,
            microFactInsight: recap.microFactInsight
        )
    }

    /// Returns a copy of `recap` whose story slots are replaced by the frozen `story`.
    /// The accounting anchors are recomputed live and stay on top; only the story is pinned.
    public static func applied(to recap: MonthlyRecap, story: RecapStorySnapshot) -> MonthlyRecap {
        var copy = recap
        copy.dynamicInsights = story.dynamicInsights
        copy.noticedInsights = story.noticedInsights
        copy.microFactInsight = story.microFactInsight
        return copy
    }

    // MARK: - Store

    /// Stores the story for `monthId`. Never overwrites an existing freeze.
    ///
    /// Returns true when the freeze is in place (whether it was just written or already
    /// existed), false only when the payload could not be encoded or the save failed.
    @discardableResult
    public static func freeze(_ story: RecapStorySnapshot, for monthId: String, context: ModelContext) -> Bool {
        guard !monthId.isEmpty else { return false }
        if storedStory(for: monthId, context: context) != nil { return true }
        guard let data = try? makeEncoder().encode(story),
              let payload = String(data: data, encoding: .utf8) else {
            MoneyCityLog.error("recap snapshot encode failed for \(monthId)")
            return false
        }
        context.insert(RecapSnapshot(monthId: monthId, payloadJSON: payload, frozenAt: Date()))
        return DatabaseService.safeSave(context, caller: "RecapSnapshotService.freeze")
    }

    /// The frozen story for a month, or nil when none exists yet.
    public static func storedStory(for monthId: String, context: ModelContext) -> RecapStorySnapshot? {
        let descriptor = FetchDescriptor<RecapSnapshot>()
        guard let row = (try? context.fetch(descriptor))?.first(where: { $0.monthId == monthId }),
              let data = row.payloadJSON.data(using: .utf8),
              let story = try? makeDecoder().decode(RecapStorySnapshot.self, from: data) else {
            return nil
        }
        return story
    }
}