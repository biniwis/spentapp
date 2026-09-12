import Foundation

// MARK: - Tier

/// Named intensity tier for a behavioral category.
/// The tier is used by the city renderer to select visual density, actor counts, and event probabilities.
public enum DeliveryIntensityTier: String, Codable, Sendable, Equatable, CaseIterable {
    case quiet
    case normal
    case active
    case high
    case extreme
}

// MARK: - Config

/// All tunable thresholds in one place. Override for testing or future calibration.
public struct DeliveryIntensityConfig: Sendable {

    // ── Market (cold-start) thresholds (weekly order rate) ──────────────────
    /// Orders/week below this → quiet
    public var marketQuietMax: Double       = 0.25
    /// Orders/week below this → normal
    public var marketNormalMax: Double      = 0.75
    /// Orders/week below this → active
    public var marketActiveMax: Double      = 1.75
    /// Orders/week below this → high
    public var marketHighMax: Double        = 3.00
    // ≥ marketHighMax → extreme

    // ── Personal baseline thresholds (relative ratio to typical rate) ────────
    /// Ratio below this → quiet relative to personal norm
    public var personalQuietRatio: Double   = 0.40
    /// Ratio below this → normal
    public var personalNormalRatio: Double  = 0.80
    /// Ratio below this → active
    public var personalActiveRatio: Double  = 1.40
    /// Ratio below this → high
    public var personalHighRatio: Double    = 2.20
    // ≥ personalHighRatio → extreme

    // ── History blending ────────────────────────────────────────────────────
    /// Months needed before personal baseline starts contributing
    public var historyBlendStartMonths: Int = 3
    /// Months needed before personal baseline is dominant (weight = 1)
    public var historyBlendFullMonths: Int  = 7

    // ── Partial-month confidence ramp ───────────────────────────────────────
    /// Days elapsed before rate extrapolation reaches full confidence
    public var partialMonthConfidenceDays: Double = 14.0

    // ── Spend baselines ─────────────────────────────────────────────────────
    /// Market fallback: ₪/week considered "full" delivery spend activity
    public var marketWeeklySpendBaseline: Double = 200.0

    public init() {}
}

// MARK: - Result

/// Full intensity reading for the delivery behavioral category.
public struct DeliveryIntensity: Sendable, Equatable {

    /// Named tier — primary input for the city renderer.
    public let tier: DeliveryIntensityTier

    /// 0–1 frequency score (drives actor count, crowd, events).
    public let frequencyScore: Double

    /// 0–1 spend score (drives venue prominence / building weight).
    public let spendScore: Double

    /// Raw order count for the month so far.
    public let orderCount: Int

    /// Days with at least one delivery transaction.
    public let activeDays: Int

    /// Total spend attributed to delivery venues.
    public let totalSpend: Double

    /// Whether personal history was available to inform the tier.
    public let personalBaselineAvailable: Bool
}

// MARK: - Engine

/// Stateless engine that converts raw delivery metrics into a `DeliveryIntensity`.
/// All inputs are plain value types; no SwiftData or persistence dependency.
public enum DeliveryIntensityEngine {

    /// Compute the delivery intensity for a given month.
    ///
    /// - Parameters:
    ///   - orderCount: Delivery transactions in the current month so far.
    ///   - totalSpend: Total ₪ spent on delivery this month.
    ///   - activeDays: Number of distinct calendar days with a delivery transaction.
    ///   - elapsedDays: Calendar days elapsed in the current month (1 = first day done).
    ///   - historicalOrderCounts: Previous months' order counts, oldest first.
    ///   - historicalSpends: Previous months' delivery spends, oldest first.
    ///   - config: Tunable thresholds — defaults to market calibration.
    public static func compute(
        orderCount: Int,
        totalSpend: Double,
        activeDays: Int,
        elapsedDays: Int,
        historicalOrderCounts: [Int] = [],
        historicalSpends: [Double] = [],
        config: DeliveryIntensityConfig = .init()
    ) -> DeliveryIntensity {

        // ── 1. Partial-month confidence gate ───────────────────────────────
        // Confidence ramps from 0 → 1 over the first N days.
        // When confidence is low, we blend the rate-based signal toward the
        // market prior so that 5 orders on day 3 does not read as Extreme.
        let elapsed = max(1, elapsedDays)
        let confidence = min(1.0, Double(elapsed) / config.partialMonthConfidenceDays)

        // Weeks elapsed (clamped below 1 week so we never divide by a tiny denominator)
        let elapsedWeeks = max(1.0, Double(elapsed) / 7.0)

        // Rate-based estimate
        let rawWeeklyRate  = Double(orderCount) / elapsedWeeks
        let rawWeeklySpend = totalSpend / elapsedWeeks

        // Market-prior estimate from raw count (no extrapolation).
        // Attenuates the raw count to approximate what "this pace over a full month" looks like
        // without committing to the aggressive weekly extrapolation early in the month.
        let marketPriorRate  = Double(orderCount) * 0.35

        // Blend: early in the month → lean on market prior; later → trust the rate.
        let effectiveRate  = rawWeeklyRate * confidence + marketPriorRate * (1.0 - confidence)
        let effectiveSpend = rawWeeklySpend * confidence + (totalSpend * 0.5) * (1.0 - confidence)

        // ── 2. Personal baseline ───────────────────────────────────────────
        let historyMonths = historicalOrderCounts.count
        let personalAvailable = historyMonths >= config.historyBlendStartMonths

        // personalWeight: 0 at historyBlendStartMonths, 1 at historyBlendFullMonths
        let personalWeight: Double = personalAvailable
            ? min(1.0, Double(historyMonths - config.historyBlendStartMonths)
                  / Double(max(1, config.historyBlendFullMonths - config.historyBlendStartMonths)))
            : 0.0

        // Median of historical counts (robust to outlier months)
        let typicalWeeklyRate: Double
        let typicalWeeklySpend: Double

        if personalAvailable {
            let sortedCounts = historicalOrderCounts.sorted()
            let midCount = sortedCounts[sortedCounts.count / 2]
            // ~4.33 weeks/month for a typical calendar month
            typicalWeeklyRate = Double(midCount) / 4.33

            if !historicalSpends.isEmpty {
                let sortedSpends = historicalSpends.sorted()
                let midSpend = sortedSpends[sortedSpends.count / 2]
                typicalWeeklySpend = midSpend / 4.33
            } else {
                typicalWeeklySpend = 0
            }
        } else {
            typicalWeeklyRate  = 0
            typicalWeeklySpend = 0
        }

        // ── 3. Tier computation ────────────────────────────────────────────
        let tier: DeliveryIntensityTier

        if personalAvailable && typicalWeeklyRate > 0.05 {
            // ── Personal-baseline path ─────────────────────────────────────
            // Blended anchor: actualWeight drives the mix between personal and market.
            // At weight=0 → pure market midpoint; at weight=1 → pure personal median.
            let marketMidRate  = (config.marketNormalMax + config.marketActiveMax) / 2.0
            let blendedAnchor  = typicalWeeklyRate * personalWeight + marketMidRate * (1.0 - personalWeight)

            let ratio = effectiveRate / max(0.01, blendedAnchor)

            if      ratio < config.personalQuietRatio  { tier = .quiet   }
            else if ratio < config.personalNormalRatio { tier = .normal  }
            else if ratio < config.personalActiveRatio { tier = .active  }
            else if ratio < config.personalHighRatio   { tier = .high    }
            else                                        { tier = .extreme }

        } else {
            // ── Market-baseline path (cold start) ──────────────────────────
            if      effectiveRate < config.marketQuietMax  { tier = .quiet   }
            else if effectiveRate < config.marketNormalMax { tier = .normal  }
            else if effectiveRate < config.marketActiveMax { tier = .active  }
            else if effectiveRate < config.marketHighMax   { tier = .high    }
            else                                            { tier = .extreme }
        }

        // ── 4. Frequency score (0–1, for actor count / crowd) ─────────────
        // Normalises against the high threshold so the full range 0…1 is usable.
        let freqScore = min(1.0, effectiveRate / config.marketHighMax)

        // ── 5. Spend score (0–1, for venue prominence) ────────────────────
        let spendBaseline: Double
        if personalAvailable && typicalWeeklySpend > 5 {
            // Same blend logic as frequency
            let marketSpend = config.marketWeeklySpendBaseline
            let blendedSpend = typicalWeeklySpend * personalWeight + marketSpend * (1.0 - personalWeight)
            spendBaseline = blendedSpend
        } else {
            spendBaseline = config.marketWeeklySpendBaseline
        }
        let spendScore = min(1.0, effectiveSpend / max(1.0, spendBaseline))

        return DeliveryIntensity(
            tier: tier,
            frequencyScore: freqScore,
            spendScore: spendScore,
            orderCount: orderCount,
            activeDays: activeDays,
            totalSpend: totalSpend,
            personalBaselineAvailable: personalAvailable
        )
    }
}
