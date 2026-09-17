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
        let sanitized = sanitize(story)
        guard let data = try? makeEncoder().encode(sanitized),
              let payload = String(data: data, encoding: .utf8) else {
            MoneyCityLog.error("recap snapshot encode failed for \(monthId)")
            return false
        }
        context.insert(RecapSnapshot(monthId: monthId, payloadJSON: payload, frozenAt: Date()))
        return DatabaseService.safeSave(context, caller: "RecapSnapshotService.freeze")
    }

    /// The frozen story for a month, or nil when none exists yet. Automatically sanitizes
    /// legacy copy variants if an older snapshot is loaded.
    public static func storedStory(for monthId: String, context: ModelContext) -> RecapStorySnapshot? {
        let descriptor = FetchDescriptor<RecapSnapshot>()
        guard let row = (try? context.fetch(descriptor))?.first(where: { $0.monthId == monthId }),
              let data = row.payloadJSON.data(using: .utf8),
              var story = try? makeDecoder().decode(RecapStorySnapshot.self, from: data) else {
            return nil
        }
        let sanitized = sanitize(story)
        if sanitized != story {
            if let updatedData = try? makeEncoder().encode(sanitized),
               let updatedJSON = String(data: updatedData, encoding: .utf8) {
                row.payloadJSON = updatedJSON
                _ = DatabaseService.safeSave(context, caller: "RecapSnapshotService.migrate")
            }
            story = sanitized
        }
        return story
    }

    /// Clears all stored recap snapshots to allow a full fresh re-curation.
    public static func clearAll(context: ModelContext) {
        let descriptor = FetchDescriptor<RecapSnapshot>()
        if let rows = try? context.fetch(descriptor) {
            for row in rows {
                context.delete(row)
            }
            _ = DatabaseService.safeSave(context, caller: "RecapSnapshotService.clearAll")
        }
    }

    // MARK: - Sanitization / Migration

    public static func sanitize(_ insight: MonthlyRecapDynamicInsight) -> MonthlyRecapDynamicInsight {
        var copy = insight

        // 1. Headlines
        if let h = copy.headlineHe {
            if h.contains("Delivery הפך לחלק קבוע") || (h.contains("Delivery") && h.contains("הפך לחלק קבוע")) {
                copy.headlineHe = "הזמנת משלוחים לאורך החודש."
            } else if h.contains("Coffee הפך לחלק קבוע") || (h.contains("Coffee") && h.contains("הפך לחלק קבוע")) {
                copy.headlineHe = "קנית קפה לאורך החודש."
            } else if h == "קומץ רכישות נשא את החודש." {
                copy.headlineHe = "חלק גדול מההוצאות הגיע מכמה רכישות."
            } else if h == "החודש הסתובב בהרבה מקומות." {
                copy.headlineHe = "קנית בהרבה מקומות שונים החודש."
            } else if h == "רכישה אחת שברה את התבנית." {
                copy.headlineHe = "רכישה אחת הייתה גבוהה משמעותית מהרגיל."
            } else if h == "החודש התגבר לקראת הסוף." {
                copy.headlineHe = "בחצי השני של החודש הוצאת יותר ליום."
            } else if h == "החודש הוציא את עיקר הכסף בהתחלה." {
                copy.headlineHe = "בחצי הראשון של החודש הוצאת יותר ליום."
            } else if h.contains("בוצעו") && h.contains("רכישות"), let d = copy.date {
                let fHe = DateFormatter()
                fHe.locale = Locale(identifier: "he_IL")
                fHe.dateFormat = "d בMMMM"
                copy.headlineHe = "\(fHe.string(from: d)) היה היום עם הכי הרבה רכישות."
            } else if h.contains("שוב ושוב"), let m = copy.merchant {
                copy.headlineHe = "\(m) היה המקום שחזרת אליו הכי הרבה."
            } else if h.contains("בלטו החודש."), let range = h.range(of: "ימי ") {
                let rest = h[range.upperBound...]
                if let end = rest.range(of: " בלטו") {
                    let dayName = String(rest[..<end.lowerBound])
                    copy.headlineHe = "בימי \(dayName) הוצאת יותר מהרגיל."
                }
            } else if h.contains("תפס") && h.contains("מקום."), let cat = copy.category {
                let catName = cat.shortName(for: .hebrew)
                let dir = (copy.primaryValue < 0 || copy.secondaryValue < 0) ? "פחות" : "יותר"
                copy.headlineHe = "הוצאת \(dir) על \(catName) מהחודש הקודם."
            } else if h.contains("הופיע") && h.contains("פעמים."), let cat = copy.category {
                let catName = cat.shortName(for: .hebrew)
                copy.headlineHe = "היו \(copy.count) הוצאות על \(catName) החודש."
            }
        }

        // 2. Values
        if let v = copy.valueHe {
            if v.contains("פי מיום אופייני") {
                let cleaned = v.replacingOccurrences(of: " פי מיום אופייני", with: "")
                copy.valueHe = "פי " + cleaned + " מההוצאה ביום רגיל"
            } else if v.contains("ביקורים") {
                copy.valueHe = v.replacingOccurrences(of: "ביקורים", with: "פעמים")
            }
        }

        // 3. Support text
        if let s = copy.supportHe {
            if s.contains("ימים שנמדדו") {
                copy.supportHe = nil
            } else if s.contains("עכשיו לעומת") {
                copy.supportHe = s.replacingOccurrences(of: "עכשיו לעומת", with: "החודש לעומת")
            } else if s.contains("על פני החודש") {
                copy.supportHe = s.replacingOccurrences(of: "על פני החודש", with: "במהלך החודש")
            } else if s.contains("הצטברו ·") {
                copy.supportHe = s.replacingOccurrences(of: "הצטברו ·", with: "בסך הכול ·")
            } else if s.contains("ארוחות טיפוסיות ≈") {
                let catName = copy.category?.shortName(for: .hebrew) ?? "אוכל"
                copy.supportHe = s.replacingOccurrences(of: "ארוחות טיפוסיות ≈", with: "הוצאה טיפוסית ב\(catName):")
            }
        }

        // 4. Separators
        if let h = copy.headlineHe, h.contains(" — ") {
            copy.headlineHe = h.replacingOccurrences(of: " — ", with: " · ")
        }
        if let v = copy.valueHe, v.contains(" — ") {
            copy.valueHe = v.replacingOccurrences(of: " — ", with: " · ")
        }
        if let s = copy.supportHe, s.contains(" — ") {
            copy.supportHe = s.replacingOccurrences(of: " — ", with: " · ")
        }

        return copy
    }

    public static func sanitize(_ story: RecapStorySnapshot) -> RecapStorySnapshot {
        var updated = story
        updated.dynamicInsights = story.dynamicInsights.map { sanitize($0) }
        updated.noticedInsights = story.noticedInsights.map { sanitize($0) }
        if let micro = story.microFactInsight {
            updated.microFactInsight = sanitize(micro)
        }
        return updated
    }
}