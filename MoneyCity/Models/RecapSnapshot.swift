import Foundation
import SwiftData

/// A frozen copy of a closed month's selected recap story.
///
/// Phase 9: an archived month must never be re-curated with a newer engine. Once a month
/// closes, the exact Hero / Noticed / MicroFact slots that were first shown are stored here,
/// and every later opening of that month reads them back instead of regenerating. The
/// accounting anchors (totals, districts, city vibe) stay deterministic and are recomputed
/// from the transaction log on demand — only the story content is pinned.
@Model
public final class RecapSnapshot {
    /// e.g. "2026-08" — the same id `MonthlyRecap.monthId` uses.
    public var monthId: String
    /// A `RecapStorySnapshot` encoded with `RecapSnapshotService`'s stable ISO-8601 coder,
    /// stored as its UTF-8 string representation.
    public var payloadJSON: String
    /// When the story was first frozen. Written once; later openings never overwrite it.
    public var frozenAt: Date

    public init(monthId: String, payloadJSON: String, frozenAt: Date) {
        self.monthId = monthId
        self.payloadJSON = payloadJSON
        self.frozenAt = frozenAt
    }
}