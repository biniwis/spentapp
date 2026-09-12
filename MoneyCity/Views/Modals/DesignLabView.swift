#if DEBUG
import SwiftUI
import SwiftData

// MARK: - Onboarding Preview Item
struct OnboardingPreviewConfig: Identifiable {
    let id = UUID()
    let step: Int
    let phase: String
    let titleHe: String
    let titleEn: String
    let subtitleHe: String
    let subtitleEn: String
    let badgeText: String
    let icon: MoneyIconName
}

// MARK: - Mock Preset Item
struct RecapPresetItem: Identifiable {
    let id: String
    let nameHe: String
    let nameEn: String
    let subtitleHe: String
    let subtitleEn: String
    let emoji: String
    let badgeColor: Color
    let recap: () -> MonthlyRecap
}

// MARK: - City Density Preset
struct CityDensityPreset: Identifiable {
    let id: String
    let nameHe: String
    let nameEn: String
    let subtitleHe: String
    let subtitleEn: String
    let emoji: String
    let badgeColor: Color
    let totalSpent: Double
    let totalSavings: Double
    let savingsTarget: Double
    let parkHealth: Double
    let categoryTotals: [SpendingCategory: Double]
    let buildingTotals: [String: Double]
    let habits: BehavioralHabits
    let enrichmentIds: [String]
}

// MARK: - Recap Lab Preset Kinds

/// The curated Recap 2.0 presets the Design Lab and Candidate Inspector run.
public enum RecapLabKind: String, CaseIterable, Identifiable, Sendable {
    case normal, delivery, coffee, quiet, accumulation, minimalData, strongTrend, richNoticed
    public var id: String { rawValue }
}

// MARK: - Recap Mock Data Provider

/// One source of truth for the Recap presets: the recap, the candidate pipeline and the
/// visual QA all consume the same transaction set via this single registry.
public enum RecapPreviewData {
    typealias PTx = (category: SpendingCategory, merchant: String, amount: Double, day: Int)

    private struct PreviewSource {
        let budget: Double
        let txs: [PTx]
        let prevTxs: [PTx]
    }

    private static var targetMonthDate: Date {
        let cal = Calendar.current
        let now = Date()
        return cal.date(byAdding: .month, value: -1, to: now) ?? now
    }

    private static func makeTransactions(
        targetMonthDate: Date,
        txs: [PTx],
        prevTxs: [PTx] = []
    ) -> [Transaction] {
        let cal = Calendar.current
        let startOfMonth = cal.dateInterval(of: .month, for: targetMonthDate)?.start ?? targetMonthDate

        var allTxs: [Transaction] = []

        for item in txs {
            let clampedDay = max(0, min(27, item.day - 1))
            let date = cal.date(byAdding: .day, value: clampedDay, to: startOfMonth) ?? startOfMonth
            allTxs.append(Transaction(
                amount: item.amount,
                currency: "₪",
                merchant: item.merchant,
                category: item.category,
                timestamp: date
            ))
        }

        let prevMonthDate = cal.date(byAdding: .month, value: -1, to: startOfMonth) ?? startOfMonth
        let startOfPrev = cal.dateInterval(of: .month, for: prevMonthDate)?.start ?? prevMonthDate
        for item in prevTxs {
            let clampedDay = max(0, min(27, item.day - 1))
            let date = cal.date(byAdding: .day, value: clampedDay, to: startOfPrev) ?? startOfPrev
            allTxs.append(Transaction(
                amount: item.amount,
                currency: "₪",
                merchant: item.merchant,
                category: item.category,
                timestamp: date
            ))
        }
        return allTxs
    }

    private static func makeRecap(kind: RecapLabKind) -> MonthlyRecap {
        let source = sources[kind] ?? sources[.normal]!
        let date = targetMonthDate
        return MonthlyRecapService.generateRecap(
            for: date,
            allTransactions: makeTransactions(targetMonthDate: date, txs: source.txs, prevTxs: source.prevTxs),
            monthlyBudget: source.budget
        )
    }

    /// The raw transaction set behind a preset — feeds the Candidate Inspector and QA.
    public static func transactions(kind: RecapLabKind) -> [Transaction] {
        let source = sources[kind] ?? sources[.normal]!
        return makeTransactions(targetMonthDate: targetMonthDate, txs: source.txs, prevTxs: source.prevTxs)
    }

    /// The recap for a preset.
    public static func recap(kind: RecapLabKind) -> MonthlyRecap { makeRecap(kind: kind) }

    // MARK: The seven curated presets (phase 10)

    public static var normal: MonthlyRecap { makeRecap(kind: .normal) }
    public static var delivery: MonthlyRecap { makeRecap(kind: .delivery) }
    public static var coffee: MonthlyRecap { makeRecap(kind: .coffee) }
    public static var quiet: MonthlyRecap { makeRecap(kind: .quiet) }
    public static var accumulation: MonthlyRecap { makeRecap(kind: .accumulation) }
    public static var minimalData: MonthlyRecap { makeRecap(kind: .minimalData) }
    public static var strongTrend: MonthlyRecap { makeRecap(kind: .strongTrend) }
    public static var richNoticed: MonthlyRecap { makeRecap(kind: .richNoticed) }

    // MARK: Sources (single source of truth for recap + candidate pipeline)

    private static let sources: [RecapLabKind: PreviewSource] = [
        .normal: PreviewSource(
            budget: 8000,
            txs: [
                (.food, "שופרסל דיל", 480, 2),
                (.food, "קפה נחת", 42, 3),
                (.transport, "פז דלק", 240, 4),
                (.shopping, "זארה", 650, 6),
                (.food, "Wolt - פיצה", 135, 7),
                (.housing, "חשבון חשמל", 410, 8),
                (.subscriptions, "נטפליקס", 54.90, 9),
                (.food, "שופרסל דיל", 390, 11),
                (.health, "סופר-פארם", 160, 12),
                (.transport, "רב-קו טעינה", 120, 14),
                (.food, "ארומה אספרסו בר", 38, 15),
                (.food, "Wolt - המבורגר", 145, 17),
                (.entertainment, "סינמה סיטי", 92, 18),
                (.food, "שופרסל דיל", 520, 19),
                (.shopping, "סטימצקי ספרים", 110, 21),
                (.food, "קפה שכונתי", 28, 22),
                (.transport, "פז דלק", 235, 23),
                (.food, "Wolt - סושי", 185, 24),
                (.health, "מכבי שירותי בריאות", 85, 25),
                (.food, "שופרסל דיל", 440, 26),
                (.subscriptions, "Spotify", 29.90, 27)
            ],
            prevTxs: [
                (.food, "שופרסל", 2400, 5),
                (.shopping, "קניות", 1800, 10),
                (.transport, "דלק", 1100, 15),
                (.housing, "חשבונות", 1200, 20)
            ]
        ),
        .delivery: PreviewSource(
            budget: 7000,
            txs: [
                (.food, "Wolt - המבורגר", 149, 2),
                (.food, "שופרסל דיל", 470, 3),
                (.food, "Wolt - סושי", 179, 5),
                (.transport, "רב-קו טעינה", 45, 6),
                (.food, "Wolt - פיצה", 132, 8),
                (.food, "Wolt - אסייתי", 158, 10),
                (.food, "Wolt - בורגר", 141, 12),
                (.food, "שופרסל דיל", 430, 13),
                (.food, "Wolt - באגט", 96, 15),
                (.food, "Wolt - סושי", 168, 17),
                (.food, "Wolt - שנצואי", 145, 19),
                (.food, "Wolt - פיצה", 128, 21),
                (.food, "Wolt - גלידה", 62, 22),
                (.food, "Wolt - פסטה", 138, 24),
                (.food, "Wolt - קבב", 152, 26),
                (.food, "שופרסל דיל", 395, 27)
            ],
            prevTxs: [
                (.food, "אוכל", 2400, 6),
                (.shopping, "בגדים", 1100, 14),
                (.transport, "תחבורה", 800, 20)
            ]
        ),
        .coffee: PreviewSource(
            budget: 6000,
            txs: [
                (.food, "קפה נחת", 42, 1),
                (.food, "ארומה אספרסו בר", 38, 2),
                (.food, "קפה בוקר", 32, 3),
                (.food, "קפה נחת", 44, 4),
                (.food, "שופרסל דיל", 520, 4),
                (.food, "ארומה", 41, 6),
                (.food, "קפה לנדוור", 46, 7),
                (.food, "קפה נחת", 42, 8),
                (.food, "ארומה", 34, 9),
                (.food, "קפה בוקר", 32, 10),
                (.food, "שופרסל דיל", 480, 11),
                (.food, "קפה נחת", 44, 12),
                (.food, "ארומה", 38, 13),
                (.food, "קפה לנדוור", 45, 14),
                (.food, "קפה נחת", 40, 15),
                (.food, "ארומה", 36, 16),
                (.food, "שופרסל דיל", 460, 18),
                (.food, "קפה נחת", 43, 19),
                (.food, "ארומה", 33, 20),
                (.food, "קפה בוקר", 34, 21),
                (.food, "קפה נחת", 41, 22),
                (.food, "ארומה", 37, 24),
                (.food, "שופרסל דיל", 450, 25)
            ],
            prevTxs: [
                (.food, "קפה ואוכל", 2100, 10),
                (.shopping, "קניות", 700, 16)
            ]
        ),
        .quiet: PreviewSource(
            budget: 7000,
            txs: [
                (.food, "שופרסל שלי", 320, 3),
                (.health, "סופר-פארם", 145, 7),
                (.transport, "רב-קו חודשי", 225, 9),
                (.food, "מכולת שכונתית", 85, 12),
                (.housing, "תאגיד מים", 110, 15),
                (.food, "שופרסל שלי", 290, 18),
                (.health, "בית מרקחת", 68, 22),
                (.food, "מאפייה", 42, 25)
            ],
            prevTxs: [
                (.food, "סופר", 1400, 10),
                (.transport, "נסיעות", 500, 15)
            ]
        ),
        .accumulation: PreviewSource(
            budget: 6500,
            txs: [
                (.food, "מכולת שכונתית", 86, 2),
                (.health, "בית מרקחת", 54, 4),
                (.food, "קפה שכונתי", 32, 5),
                (.shopping, "חנות ספרים", 128, 7),
                (.food, "שופרסל אקספרס", 210, 8),
                (.transport, "רב-קו", 65, 9),
                (.food, "מאפייה", 47, 12),
                (.shopping, "תיק קטן", 175, 14),
                (.health, "סופר-פארם", 92, 15),
                (.entertainment, "קולנוע לב", 78, 16),
                (.food, "גלידה", 38, 18),
                (.shopping, "חנות נעליים", 145, 20),
                (.food, "מסעדה שכונתית", 165, 21),
                (.transport, "פנגו חניה", 58, 22),
                (.food, "מכולת שכונתית", 92, 23),
                (.health, "ויטמינים", 120, 24),
                (.subscriptions, "סרט בסטרימינג", 34, 25),
                (.food, "שיפודיה", 130, 26),
                (.shopping, "קוסמטיקה", 110, 27)
            ],
            prevTxs: [
                (.food, "אוכל", 1500, 8),
                (.shopping, "קניות", 500, 15),
                (.transport, "תחבורה", 250, 20),
                (.health, "בריאות", 180, 22)
            ]
        ),
        .minimalData: PreviewSource(
            budget: 5000,
            txs: [
                (.food, "שופרסל דיל", 132, 5),
                (.food, "מכולת שכונתית", 89, 12)
            ],
            prevTxs: []
        ),
        .strongTrend: PreviewSource(
            budget: 8000,
            txs: [
                (.food, "שופרסל דיל", 340, 3),
                (.food, "קפה ועוגה", 28, 5),
                (.transport, "רב-קו", 95, 7),
                (.health, "בית מרקחת", 60, 9),
                (.food, "שופרסל דיל", 310, 11),
                (.shopping, "חנות בגדים", 220, 14),
                (.food, "מכולת שכונתית", 120, 17),
                (.food, "מסעדה", 240, 20),
                (.entertainment, "קולנוע", 86, 23),
                (.food, "שופרסל דיל", 380, 26)
            ],
            prevTxs: [
                (.food, "שופרסל גדול", 2100, 3),
                (.shopping, "רשת אופנה", 1400, 8),
                (.transport, "דלק ומוסך", 1250, 12),
                (.entertainment, "הופעות", 600, 16),
                (.food, "מסעדות", 900, 20),
                (.shopping, "אלקטרוניקה", 1300, 24)
            ]
        ),
        .richNoticed: PreviewSource(
            budget: 10000,
            txs: [
                (.food, "Wolt - המבורגר", 128, 2),
                (.health, "סופר-פארם", 89, 3),
                (.food, "Wolt - סושי", 156, 4),
                (.food, "קפה נחת", 38, 5),
                (.transport, "פז תחנת דלק", 320, 6),
                (.food, "שופרסל דיל", 480, 7),
                (.food, "Wolt - פיצה", 132, 7),
                (.shopping, "איל עיצוב רהיטים", 1900, 8),
                (.food, "Wolt - סלט", 112, 8),
                (.food, "קפה נחת", 35, 8),
                (.health, "סופר-פארם", 95, 8),
                (.food, "סופרמרקט אקספרס", 210, 8),
                (.food, "Wolt - אסייתי", 148, 9),
                (.food, "שופרסל דיל", 410, 10),
                (.health, "סופר-פארם", 128, 11),
                (.food, "Wolt - בורגר", 135, 12),
                (.transport, "רב-קו טעינה", 105, 13),
                (.shopping, "אלקטרה מובייל", 1400, 14),
                (.food, "שופרסל דיל", 520, 14),
                (.food, "Wolt - שנצואי", 142, 15),
                (.health, "סופר-פארם", 76, 16),
                (.transport, "רכבת ישראל", 240, 18),
                (.food, "שופרסל דיל", 390, 17),
                (.food, "קפה בוקר", 32, 17),
                (.food, "Wolt - גלידה", 58, 19),
                (.transport, "Gett מוניות", 220, 21),
                (.food, "Wolt - פסטה", 138, 20),
                (.shopping, "חנות ספרים", 95, 22),
                (.health, "סופר-פארם", 84, 20),
                (.transport, "פנגו חניה", 55, 24),
                (.food, "שופרסל דיל", 460, 26),
                (.food, "קפה שכונתי", 30, 27),
                (.health, "סופר-פארם", 110, 28),
                (.food, "שופרסל דיל", 340, 30)
            ],
            prevTxs: [
                (.food, "שופרסל", 2100, 4),
                (.food, "קפה ונחת", 120, 7),
                (.transport, "דלק ונסיעות", 1160, 9),
                (.shopping, "קניות יומיומיות", 950, 12),
                (.housing, "חשבונות", 1500, 15),
                (.health, "בית מרקחת", 200, 18),
                (.entertainment, "בילויים", 450, 21),
                (.food, "שופרסל", 1900, 24),
                (.subscriptions, "מנויים", 150, 26),
                (.shopping, "מוצרי בית", 350, 27),
                (.food, "מסעדות", 800, 28),
                (.transport, "תחבורה ציבורית", 260, 29)
            ]
        )
    ]

    public static var highSpend: MonthlyRecap {
        let date = targetMonthDate
        let txs: [PTx] = [
            (.shopping, "אל על - טיסה לטוקיו", 4200, 3),
            (.shopping, "Apple Store - iPad", 2350, 6),
            (.food, "טאיזו מסעדת שף", 880, 8),
            (.shopping, "פקטורי 54", 1450, 10),
            (.food, "שופרסל", 620, 11),
            (.transport, "טיפול רכב מורשה", 1200, 13),
            (.food, "Wolt סופש", 280, 15),
            (.entertainment, "הופעה חיה פארק הירקון", 760, 18),
            (.food, "פאסטל מסעדה", 590, 22),
            (.shopping, "רנואר", 420, 25),
            (.food, "סופרמרקט", 580, 27)
        ]
        let prevTxs: [PTx] = [
            (.food, "סופרמרקט", 2200, 5),
            (.shopping, "בגדים", 1500, 12),
            (.transport, "דלק", 900, 20)
        ]
        return MonthlyRecapService.generateRecap(
            for: date,
            allTransactions: makeTransactions(targetMonthDate: date, txs: txs, prevTxs: prevTxs),
            monthlyBudget: 8000
        )
    }

    public static var balanced: MonthlyRecap {
        let date = targetMonthDate
        let txs: [PTx] = [
            (.food, "שופרסל דיל", 550, 2),
            (.housing, "ועד בית ואחזקה", 450, 4),
            (.transport, "פז תחנת דלק", 280, 6),
            (.food, "קפה ומאפה", 45, 8),
            (.shopping, "זארה הום", 340, 10),
            (.food, "Wolt", 160, 12),
            (.savings, "חיסכון חודשי לטיול", 1500, 13),
            (.housing, "אינטרנט וסלולר", 185, 15),
            (.food, "שופרסל דיל", 580, 17),
            (.health, "אימון וחדר כושר", 260, 19),
            (.entertainment, "קולנוע לב", 88, 21),
            (.food, "מסעדה עם חברים", 380, 23),
            (.transport, "רכבת ישראל", 140, 25),
            (.food, "שופרסל דיל", 520, 27)
        ]
        let prevTxs: [PTx] = [
            (.food, "אוכל", 2500, 5),
            (.housing, "דיור", 1200, 10),
            (.transport, "תחבורה", 900, 15)
        ]
        return MonthlyRecapService.generateRecap(
            for: date,
            allTransactions: makeTransactions(targetMonthDate: date, txs: txs, prevTxs: prevTxs),
            monthlyBudget: 7500
        )
    }

    public static var foodHeavy: MonthlyRecap {
        let date = targetMonthDate
        let txs: [PTx] = [
            (.food, "Wolt - המבורגר", 155, 1),
            (.food, "קפה נחת", 44, 2),
            (.food, "שופרסל דיל", 620, 3),
            (.food, "Wolt - פיצה", 140, 5),
            (.food, "טאקרייה מקסיקנית", 210, 6),
            (.food, "ארומה תל אביב", 36, 7),
            (.food, "Wolt - סושי", 195, 8),
            (.food, "גלידה גולדה", 48, 9),
            (.food, "שופרסל דיל", 540, 10),
            (.food, "Wolt - אסייתי", 165, 12),
            (.food, "קפה לנדוור", 95, 13),
            (.food, "Wolt - פסטה", 130, 14),
            (.food, "מסעדת מחניודה", 780, 16),
            (.food, "שופרסל דיל", 490, 17),
            (.food, "Wolt - אוכל ביתי", 125, 19),
            (.food, "קפה בוקר", 32, 21),
            (.food, "Wolt - סנדוויץ'", 85, 23),
            (.food, "שופרסל דיל", 580, 25),
            (.food, "Wolt - קינוחים", 110, 26),
            (.transport, "פז תחנת דלק", 240, 11),
            (.shopping, "סופר-פארם", 120, 20)
        ]
        let prevTxs: [PTx] = [
            (.food, "אוכל", 3800, 5),
            (.shopping, "שונות", 800, 12)
        ]
        return MonthlyRecapService.generateRecap(
            for: date,
            allTransactions: makeTransactions(targetMonthDate: date, txs: txs, prevTxs: prevTxs),
            monthlyBudget: 7000
        )
    }

    public static var transportHeavy: MonthlyRecap {
        let date = targetMonthDate
        let txs: [PTx] = [
            (.transport, "מוסך מרכזי - טיפול 60,000", 2850, 4),
            (.transport, "מכון רישוי וטסט לרכב", 320, 5),
            (.transport, "פז תחנת דלק", 340, 7),
            (.transport, "סונול דלק", 310, 12),
            (.transport, "רכבת ישראל", 165, 14),
            (.transport, "Gett מוניות", 145, 16),
            (.transport, "פנגו חניה חודשית", 125, 18),
            (.transport, "פז תחנת דלק", 330, 22),
            (.transport, "Gett מוניות", 95, 24),
            (.food, "שופרסל דיל", 490, 8),
            (.food, "קפה לדרך", 28, 10),
            (.food, "שופרסל דיל", 440, 20),
            (.housing, "חשבון חשמל", 380, 15)
        ]
        let prevTxs: [PTx] = [
            (.transport, "רכב", 1200, 5),
            (.food, "אוכל", 2100, 10)
        ]
        return MonthlyRecapService.generateRecap(
            for: date,
            allTransactions: makeTransactions(targetMonthDate: date, txs: txs, prevTxs: prevTxs),
            monthlyBudget: 6500
        )
    }
}

// MARK: - Main Design Lab View
public struct DesignLabView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager

    @State private var activeOnboardingConfig: OnboardingPreviewConfig? = nil
    @State private var activeRecap: MonthlyRecap? = nil
    @State private var showWeeklyRewardSheet = false
    @State private var debugRewardTrigger: CityRewardTrigger = .weeklyPresence
    @State private var debugRewardJoined = false
    @State private var showAllCompanionsCompletedSheet = false
    @State private var showCityDensityLab = false
    @State private var showCandidateLab = false

    private var isHe: Bool { l10n.language == .hebrew }

    private let onboardingSteps: [OnboardingPreviewConfig] = [
        OnboardingPreviewConfig(
            step: 1,
            phase: "intro",
            titleHe: "1. קונספט ומבוא לעיר",
            titleEn: "1. Concept & City Scene",
            subtitleHe: "ההוצאות שלך בונות עיר, איור העיר הראשי",
            subtitleEn: "Your spending builds a city, city skyline artwork",
            badgeText: "Concept",
            icon: .home
        ),
        OnboardingPreviewConfig(
            step: 2,
            phase: "intro",
            titleHe: "2. שם ראש העיר",
            titleEn: "2. Mayor Name",
            subtitleHe: "שם אישי לעיר עם שלט כניסה מותאם",
            subtitleEn: "Personalized mayor name and city entrance sign",
            badgeText: "Name",
            icon: .user
        ),
        OnboardingPreviewConfig(
            step: 3,
            phase: "intro",
            titleHe: "3. יעד תקציב חודשי",
            titleEn: "3. Monthly Spending Target",
            subtitleHe: "הגדרת מסגרת הוצאות חודשית ומספרים",
            subtitleEn: "Monthly target and financial limit setup",
            badgeText: "Target",
            icon: .target
        ),
        OnboardingPreviewConfig(
            step: 4,
            phase: "intro",
            titleHe: "4א. מבוא לאוטומציה",
            titleEn: "4A. Automation Intro",
            subtitleHe: "קליטת Apple Pay מהירה ואיור כרטיס אשראי",
            subtitleEn: "Apple Pay Shortcuts automation introduction",
            badgeText: "Shortcuts A",
            icon: .creditCard
        ),
        OnboardingPreviewConfig(
            step: 4,
            phase: "guide",
            titleHe: "4ב. מדריך 3 השלבים",
            titleEn: "4B. Shortcuts 3-Step Guide",
            subtitleHe: "הוראות חיבור מדויקות באפליקציית קיצורים",
            subtitleEn: "Step-by-step setup in Apple Shortcuts app",
            badgeText: "Shortcuts B",
            icon: .sliders
        ),
        OnboardingPreviewConfig(
            step: 5,
            phase: "intro",
            titleHe: "5. חשיפת העיר הראשונה",
            titleEn: "5. City Opening Reveal",
            subtitleHe: "מסך הסיום עם אנימציית העיר שנפתחת",
            subtitleEn: "Final reveal screen before entering the main city",
            badgeText: "Reveal",
            icon: .citySkyline
        )
    ]

    private var recapPresets: [RecapPresetItem] {
        [
            RecapPresetItem(
                id: "normal",
                nameHe: "חודש רגיל",
                nameEn: "Normal Month",
                subtitleHe: "הוצאה מאוזנת של ~₪6.4K מתוך ₪8K, צמיחה יציבה",
                subtitleEn: "Balanced spend ~₪6.4K of ₪8K, steady growth",
                emoji: "🌟",
                badgeColor: Color(red: 59/255, green: 130/255, blue: 246/255),
                recap: { RecapPreviewData.normal }
            ),
            RecapPresetItem(
                id: "delivery",
                nameHe: "עיר המשלוחים",
                nameEn: "Delivery Month",
                subtitleHe: "רוב האוכל הגיע מ־Wolt — הרגל ברור ומזמין ניתוח",
                subtitleEn: "Most food arrived via Wolt — a clear, inspectable habit",
                emoji: "🛵",
                badgeColor: Color(red: 0/255, green: 194/255, blue: 232/255),
                recap: { RecapPreviewData.delivery }
            ),
            RecapPresetItem(
                id: "coffee",
                nameHe: "עיר הקפה",
                nameEn: "Coffee Month",
                subtitleHe: "בעצם כל יום קפה — הרגל חם וחוזר",
                subtitleEn: "Coffee almost every day — a warm, repeated habit",
                emoji: "☕",
                badgeColor: Color(red: 180/255, green: 83/255, blue: 9/255),
                recap: { RecapPreviewData.coffee }
            ),
            RecapPresetItem(
                id: "quiet",
                nameHe: "חודש רגוע ומצומצם",
                nameEn: "Quiet Month",
                subtitleHe: "פעילות מעטה (~₪2.1K מתוך ₪7K), עיר שלווה וירוקה",
                subtitleEn: "Low volume (~₪2.1K of ₪7K), peaceful calm city",
                emoji: "🌿",
                badgeColor: Color(red: 16/255, green: 185/255, blue: 129/255),
                recap: { RecapPreviewData.quiet }
            ),
            RecapPresetItem(
                id: "accumulation",
                nameHe: "הצטברות",
                nameEn: "Accumulation",
                subtitleHe: "הרבה רכישות קטנות שהצטברו בלי משים",
                subtitleEn: "Many small purchases that quietly added up",
                emoji: "🧩",
                badgeColor: Color(red: 139/255, green: 92/255, blue: 246/255),
                recap: { RecapPreviewData.accumulation }
            ),
            RecapPresetItem(
                id: "minimalData",
                nameHe: "נתונים מינימליים",
                nameEn: "Minimal Data",
                subtitleHe: "חודש כמעט ריק — סיפור קצר ונקי",
                subtitleEn: "A nearly empty month — a clean, short story",
                emoji: "🌫️",
                badgeColor: Color(red: 120/255, green: 120/255, blue: 128/255),
                recap: { RecapPreviewData.minimalData }
            ),
            RecapPresetItem(
                id: "strongTrend",
                nameHe: "מגמה חזקה",
                nameEn: "Strong Trend",
                subtitleHe: "ירידה חדה ביחס לחודש הקודם",
                subtitleEn: "A sharp drop vs last month",
                emoji: "📉",
                badgeColor: Color(red: 239/255, green: 68/255, blue: 68/255),
                recap: { RecapPreviewData.strongTrend }
            ),
            RecapPresetItem(
                id: "richNoticed",
                nameHe: "חודש עשיר ומלא חיים",
                nameEn: "Rich & Noticed Month",
                subtitleHe: "קניות זינקו, יום עמוס במיוחד וסיפור נוסף בכל פינה",
                subtitleEn: "Shopping surged, one packed day and a story around every corner",
                emoji: "🎡",
                badgeColor: Color(red: 8/255, green: 145/255, blue: 178/255),
                recap: { RecapPreviewData.richNoticed }
            )
        ]
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        // ── Sandbox Warning & Guarantee Banner ──
                        sandboxBanner

                        // ── Section 1: Onboarding Flows & Screens ──
                        onboardingSection

                        // ── Section 2: Monthly Recap Presets ──
                        recapSection

                        // ── Section 3: Weekly Addition / Bonus Previews ──
                        weeklyBonusSection

                        // ── Section 4: City Density States & 3D Lab ──
                        cityDensitySection

                        // ── Section 5: Future Labs ──
                        futureLabsSection

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Design Lab 🧪")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isHe ? "סגור" : "Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                }
            }
        }
        .environment(\.layoutDirection, isHe ? .rightToLeft : .leftToRight)
        .fullScreenCover(item: $activeOnboardingConfig) { config in
            OnboardingWizardView(
                initialStep: config.step,
                initialPhase: config.phase,
                canDismiss: true,
                isPreview: true,
                onComplete: {
                    activeOnboardingConfig = nil
                },
                onTriggerSampleTransaction: {}
            )
            .environmentObject(l10n)
        }
        .fullScreenCover(item: $activeRecap) { recap in
            MonthlyRecapSheet(recap: recap, onNavigateToCity: nil)
                .environmentObject(l10n)
        }
        .sheet(isPresented: $showWeeklyRewardSheet) {
            CityProgressSheet(
                options: CityProgressEngine.shared.allCatalogOptions,
                unlockedEnrichments: [],
                rewardContext: CityRewardContext(trigger: debugRewardTrigger, unlockedAt: Date()),
                previewJoined: debugRewardJoined ? CityProgressEngine.shared.allCatalogOptions.first : nil,
                onSelectOption: { _ in
                    Haptics.notify(.success)
                    return true
                }
            )
            .environmentObject(l10n)
        }
        .sheet(isPresented: $showAllCompanionsCompletedSheet) {
            CityProgressSheet(
                options: [],
                unlockedEnrichments: CityCompanions.ids.map {
                    CityEnrichment(
                        itemId: $0,
                        name: $0,
                        subtitle: "",
                        icon: "pawprint.fill",
                        type: .pet,
                        tier: "small",
                        savedAmount: 500,
                        districtId: "city",
                        isApplied: true
                    )
                },

                onSelectOption: { _ in false }
            )
            .environmentObject(l10n)
        }
        .fullScreenCover(isPresented: $showCityDensityLab) {
            CityDensityLabSheet()
                .environmentObject(l10n)
        }
        .sheet(isPresented: $showCandidateLab) {
            RecapCandidateLabSheet()
                .environmentObject(l10n)
        }
    }

    // MARK: - Safe Sandbox Banner
    private var sandboxBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 139/255, green: 92/255, blue: 246/255).opacity(0.12))
                    .frame(width: 36, height: 36)
                MoneyIcon(.sliders, size: 20, color: Color(red: 139/255, green: 92/255, blue: 246/255))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(isHe ? "סביבת בדיקות מבודדת" : "Isolated Preview Sandbox")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    Spacer()
                    Text("DEBUG ONLY")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 139/255, green: 92/255, blue: 246/255))
                        .clipShape(Capsule())
                }

                Text(isHe
                    ? "אין שמירה ב־SwiftData, אין שינוי בהוצאות אמיתיות, בתקציב, בהתקדמות העיר או בדגל השלמת ה־Onboarding."
                    : "Zero writes to SwiftData. Does not modify real transactions, budget, city progression, or onboarding completion flags.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(Color.textSecondary)
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
    }

    // MARK: - Section 1: Onboarding Previews
    private var onboardingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: isHe ? "הדרכת פתיחה (Onboarding)" : "Onboarding Experience",
                badge: "FLOW & SCREENS"
            )

            // Full Flow Hero Card
            Button {
                Haptics.impact(.medium)
                activeOnboardingConfig = OnboardingPreviewConfig(
                    step: 1,
                    phase: "intro",
                    titleHe: "סיור Onboarding מלא",
                    titleEn: "Full Onboarding Flow",
                    subtitleHe: "זרימה שלמה משלב 1 עד 5",
                    subtitleEn: "Complete flow from step 1 to 5",
                    badgeText: "Full Flow",
                    icon: .citySkyline
                )
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(MoneyCityTheme.spentGreenSoft)
                            .frame(width: 44, height: 44)
                        MoneyIcon(.citySkyline, size: 24, color: MoneyCityTheme.brandPrimary)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(isHe ? "סיור Onboarding מלא" : "Full Onboarding Flow")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Spacer()
                            Text("1 → 5")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(MoneyCityTheme.brandPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(MoneyCityTheme.spentGreenSoft)
                                .clipShape(Capsule())
                        }

                        Text(isHe
                            ? "זרימה מלאה מקונספט העיר ועד פתיחת הדלתות, כולל מעברים ואנימציות"
                            : "Full journey from city concept to reveal, with all transitions")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(Color.textSecondary)
                    }
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .bouncyPress(scale: 0.98)

            // Individual Screen Grid
            Text(isHe ? "בדיקת מסכים בודדים:" : "Individual Step Previews:")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .padding(.top, 4)

            VStack(spacing: 8) {
                ForEach(onboardingSteps) { stepConfig in
                    Button {
                        Haptics.impact(.light)
                        activeOnboardingConfig = stepConfig
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(red: 243/255, green: 244/255, blue: 246/255))
                                    .frame(width: 36, height: 36)
                                MoneyIcon(stepConfig.icon, size: 20)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(isHe ? stepConfig.titleHe : stepConfig.titleEn)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)

                                Text(isHe ? stepConfig.subtitleHe : stepConfig.subtitleEn)
                                    .font(.system(size: 11, weight: .regular, design: .default))
                                    .foregroundColor(Color.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(stepConfig.badgeText)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(Color.textMuted)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color(red: 243/255, green: 244/255, blue: 246/255))
                                .clipShape(Capsule())

                            MoneyIcon(
                                isHe ? .chevronLeft : .chevronRight,
                                size: 10,
                                color: Color.textMuted
                            )
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.black.opacity(0.02), radius: 4, y: 1)
                    }
                    .buttonStyle(.plain)
                    .bouncyPress(scale: 0.98)
                }
            }
        }
    }

    // MARK: - Section 2: Monthly Recap Presets
    private var recapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: isHe ? "סיכום חודשי (Monthly Recap Presets)" : "Monthly Recap Presets",
                badge: "8 CURATED"
            )

            Text(isHe
                ? "הקש על כל Preset כדי להריץ את הסטורי והאנימציות האמיתיות עם נתוני Mock:"
                : "Tap any preset to view the full story & editorial animations with mock data:")
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(Color.textSecondary)

            // Candidate Inspector launcher
            Button {
                Haptics.impact(.medium)
                showCandidateLab = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 219/255, green: 234/255, blue: 254/255))
                            .frame(width: 46, height: 46)
                        MoneyIcon(.search, size: 24, color: Color(red: 37/255, green: 99/255, blue: 235/255))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(isHe ? "מפקח מועמדויות (Candidate Inspector)" : "Candidate Inspector")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Spacer()
                            Text(isHe ? "מנוע + אוצר ↗" : "Engine + Curator ↗")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 37/255, green: 99/255, blue: 235/255))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(red: 219/255, green: 234/255, blue: 254/255))
                                .clipShape(Capsule())
                        }

                        Text(isHe
                            ? "צפייה במועמדויות המנוע, הסיפור המעוצב, הדחיות והניקוד לכל Preset"
                            : "Inspect engine candidates, the curated story, rejections & scores per preset")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(Color.textSecondary)
                    }
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.035), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .bouncyPress(scale: 0.98)

            VStack(spacing: 10) {
                ForEach(recapPresets) { preset in
                    Button {
                        Haptics.impact(.medium)
                        activeRecap = preset.recap()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(preset.badgeColor.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Text(preset.emoji)
                                    .font(.system(size: 22))
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(isHe ? preset.nameHe : preset.nameEn)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.deepNavy)
                                    Spacer()
                                    Text(isHe ? "צפה בסטורי" : "View Story")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(preset.badgeColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(preset.badgeColor.opacity(0.1))
                                        .clipShape(Capsule())
                                }

                                Text(isHe ? preset.subtitleHe : preset.subtitleEn)
                                    .font(.system(size: 12, weight: .regular, design: .default))
                                    .foregroundColor(Color.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                    .bouncyPress(scale: 0.98)
                }
            }
        }
    }

    // MARK: - Section 3: Weekly Addition & Bonus Previews
    private var weeklyBonusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: isHe ? "בונוס שבועי וחברים (Weekly Addition)" : "Weekly Addition & Bonus",
                badge: "COMPANIONS"
            )

            Text(isHe
                ? "בדיקת טקסי הבונוס וההתקדמות השבועית, בחירת דמויות ואנימציות הצטרפות לעיר:"
                : "Preview weekly companion rewards, unlock flow, and animated join ceremonies:")
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(Color.textSecondary)

            VStack(spacing: 10) {
                #if DEBUG
                Button("Open Reward Selection") {
                    debugRewardJoined = false
                    showWeeklyRewardSheet = true
                }
                Button("Trigger Weekly Reward") {
                    var engine = CityRewardEngine()
                    engine.debugTrigger(.weeklyPresence)
                    engine.save()
                    debugRewardTrigger = .weeklyPresence
                    debugRewardJoined = false
                    showWeeklyRewardSheet = true
                }
                Button("Trigger Surprise Reward") {
                    var engine = CityRewardEngine()
                    engine.debugTrigger(.quietPeriod)
                    engine.save()
                    debugRewardTrigger = .quietPeriod
                    debugRewardJoined = false
                    showWeeklyRewardSheet = true
                }
                Button("Open Reward Claimed State") {
                    debugRewardJoined = true
                    showWeeklyRewardSheet = true
                }
                Button("Reset Reward Cooldowns") {
                    var engine = CityRewardEngine()
                    engine.debugResetCooldowns()
                    engine.save()
                }
                #endif
                // Active Choice Ceremony
                Button {
                    Haptics.impact(.medium)
                    debugRewardJoined = false
                    showWeeklyRewardSheet = true
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 254/255, green: 240/255, blue: 138/255).opacity(0.6))
                                .frame(width: 44, height: 44)
                            MoneyIcon(.gift, size: 24, color: Color(red: 202/255, green: 138/255, blue: 4/255))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(isHe ? "טקס בחירת חבר שבועי" : "Weekly Companion Ceremony")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                Spacer()
                                Text(isHe ? "חיסכון ₪480" : "₪480 Saved")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 202/255, green: 138/255, blue: 4/255))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(red: 254/255, green: 240/255, blue: 138/255).opacity(0.4))
                                    .clipShape(Capsule())
                            }

                            Text(isHe
                                ? "הדמיית התקדמות שבועית חיובית (₪480 חיסכון), בחירה אינטראקטיבית ואנימציית הצטרפות"
                                : "Simulates positive weekly progress (₪480 saved), interactive selection & join animation")
                                .font(.system(size: 12, weight: .regular, design: .default))
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .bouncyPress(scale: 0.98)

                // All Companions Completed State
                Button {
                    Haptics.impact(.light)
                    showAllCompanionsCompletedSheet = true
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 209/255, green: 250/255, blue: 229/255))
                                .frame(width: 44, height: 44)
                            MoneyIcon(.checkCircle, size: 24, color: MoneyCityTheme.brandPrimary)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(isHe ? "מצב סיום: כל החברים כבר בעיר" : "All Companions Unlocked State")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                Spacer()
                                Text("6 / 6")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(MoneyCityTheme.brandPrimary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(red: 209/255, green: 250/255, blue: 229/255))
                                    .clipShape(Capsule())
                            }

                            Text(isHe
                                ? "בדיקת מסך ההודעה כאשר המשתמש פתח כבר את כל 6 החברים בעיר"
                                : "Check state when all 6 companions have already joined the city")
                                .font(.system(size: 12, weight: .regular, design: .default))
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .bouncyPress(scale: 0.98)
            }
        }
    }

    // MARK: - Section 4: City Density States
    private var cityDensitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: isHe ? "מצבי צפיפות עיר (City Density States)" : "City Density States",
                badge: "3D LIVE LAB"
            )

            Text(isHe
                ? "תצוגת 3D אינטראקטיבית עם החלפת מצבי צפיפות בזמן אמת – מתחילת חודש ועד מגה-מטרופולין:"
                : "Live interactive 3D diorama lab with real-time density switching from Day 1 to Mega Metropolis:")
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(Color.textSecondary)

            // 3D Lab Launcher Card
            Button {
                Haptics.impact(.medium)
                showCityDensityLab = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 219/255, green: 234/255, blue: 254/255))
                            .frame(width: 46, height: 46)
                        MoneyIcon(.citySkyline, size: 26, color: Color(red: 37/255, green: 99/255, blue: 235/255))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(isHe ? "מעבדת תלת-ממד אינטראקטיבית" : "Live 3D City Density Lab")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Spacer()
                            Text(isHe ? "פתח תלת-ממד ↗" : "Open 3D ↗")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 37/255, green: 99/255, blue: 235/255))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(red: 219/255, green: 234/255, blue: 254/255))
                                .clipShape(Capsule())
                        }

                        Text(isHe
                            ? "הדמיית הדיורמה התלת-ממדית עם שליטה מיידית בצפיפות, מבנים, פארק ותנועה"
                            : "Interactive WebGL 3D diorama with live controls for density, buildings, park & traffic")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(Color.textSecondary)
                    }
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.035), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .bouncyPress(scale: 0.98)
        }
    }

    // MARK: - Section 5: Future Labs (Extensibility)
    private var futureLabsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: isHe ? "מעבדות נוספות" : "More Preview Labs",
                badge: "COMING SOON"
            )

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                futureLabTile(title: isHe ? "התראות מערכת" : "Notifications", icon: .bell)
                futureLabTile(title: isHe ? "מצבי שגיאה" : "Error States", icon: .warningCircle)
                futureLabTile(title: isHe ? "מצבי ריקון (Empty)" : "Empty States", icon: .folder)
                futureLabTile(title: isHe ? "ארכיון עיר" : "City Archive", icon: .calendar)
            }
        }
    }

    private func futureLabTile(title: String, icon: MoneyIconName) -> some View {
        HStack(spacing: 8) {
            MoneyIcon(icon, size: 16, color: Color.textMuted)
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color.textMuted)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.borderSubtle, lineWidth: 1)
        )
    }

    private func sectionHeader(title: String, badge: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
            Spacer()
            Text(badge)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundColor(Color.textMuted)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(red: 243/255, green: 244/255, blue: 246/255))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Interactive 3D City Density Laboratory Sheet
public struct CityDensityLabSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager

    @State private var selectedPresetIndex: Int = 2 // Start at Thriving City
    @State private var viewResetToken: Int = 0

    private var isHe: Bool { l10n.language == .hebrew }

    private let presets: [CityDensityPreset] = [
        // 1. Pristine / Day 1
        CityDensityPreset(
            id: "pristine",
            nameHe: "עיר בתולית (יום 1)",
            nameEn: "Pristine City (Day 1)",
            subtitleHe: "רשת כבישים בסיסית, שמורת טבע שקטה, ₪0 הוצאות",
            subtitleEn: "Pristine start of month, basic roads, ₪0 spend",
            emoji: "🍃",
            badgeColor: Color.gray,
            totalSpent: 0.0,
            totalSavings: 0.0,
            savingsTarget: 1000.0,
            parkHealth: 0.78,
            categoryTotals: [:],
            buildingTotals: [:],
            habits: BehavioralHabits(),
            enrichmentIds: []
        ),
        // 2. Growing Town
        CityDensityPreset(
            id: "growing",
            nameHe: "עיירה מתפתחת (הוצאה נמוכה)",
            nameEn: "Growing Town (Low)",
            subtitleHe: "~₪1.8K הוצאות, בית קפה ומכולת שכונתית, תנועה שקטה",
            subtitleEn: "~₪1.8K spend, local cafe & grocery, quiet streets",
            emoji: "🌱",
            badgeColor: MoneyCityTheme.brandPrimary,
            totalSpent: 1850.0,
            totalSavings: 600.0,
            savingsTarget: 1000.0,
            parkHealth: 0.82,
            categoryTotals: [.food: 950, .shopping: 350, .transport: 250, .housing: 300],
            buildingTotals: ["food_bistro": 450, "food_super": 380, "food_coffee": 120, "shop_boutique": 350, "trans_station": 250, "house_util": 300],
            habits: BehavioralHabits(woltDeliveryCount: 2, coffeeCount: 3, onlinePackagesCount: 1, totalGroceryBags: 2),
            enrichmentIds: ["pet_cat_rooftop"]
        ),
        // 3. Thriving City (Balanced)
        CityDensityPreset(
            id: "thriving",
            nameHe: "מטרופולין פעיל (מאוזן)",
            nameEn: "Thriving City (Balanced)",
            subtitleHe: "~₪6.5K הוצאות, מבנים מפותחים, שדרות פעילות ופארק ירוק",
            subtitleEn: "~₪6.5K balanced spend, active districts & green park",
            emoji: "🏙️",
            badgeColor: Color(red: 37/255, green: 99/255, blue: 235/255),
            totalSpent: 6480.0,
            totalSavings: 1800.0,
            savingsTarget: 2000.0,
            parkHealth: 0.85,
            categoryTotals: [.food: 2400, .shopping: 1200, .transport: 850, .housing: 1400, .entertainment: 630],
            buildingTotals: ["food_bistro": 820, "food_super": 950, "food_coffee": 280, "food_wolt": 350, "shop_boutique": 750, "shop_tech": 450, "trans_station": 850, "house_tower": 800, "house_util": 600],
            habits: BehavioralHabits(woltDeliveryCount: 6, coffeeCount: 8, onlinePackagesCount: 3, totalGroceryBags: 6),
            enrichmentIds: ["pet_cat_rooftop", "resident_artist", "resident_skater"]
        ),
        // 4. Mega Metropolis (Peak)
        CityDensityPreset(
            id: "metropolis",
            nameHe: "מגה מטרופולין (שיא)",
            nameEn: "Mega Metropolis (Peak)",
            subtitleHe: "~₪14.6K הוצאות, גורדי שחקים, תנועה כבדה וטיסות",
            subtitleEn: "~₪14.6K high spend, towering skyscrapers & dense traffic",
            emoji: "🌆",
            badgeColor: Color(red: 139/255, green: 92/255, blue: 246/255),
            totalSpent: 14650.0,
            totalSavings: 1000.0,
            savingsTarget: 2500.0,
            parkHealth: 0.72,
            categoryTotals: [.food: 4200, .shopping: 4800, .transport: 2200, .housing: 2100, .entertainment: 1350],
            buildingTotals: ["food_bistro": 1600, "food_super": 1400, "food_wolt": 1200, "shop_tech": 2600, "shop_travel": 1400, "shop_boutique": 800, "trans_station": 2200, "house_tower": 1400, "house_util": 700],
            habits: BehavioralHabits(woltDeliveryCount: 16, coffeeCount: 14, onlinePackagesCount: 8, hasTravelOrFlight: true, totalGroceryBags: 8),
            enrichmentIds: ["pet_cat_rooftop", "resident_artist", "resident_skater", "resident_musician", "pet_golden_dog"]
        ),
        // 5. Parched Park (Budget Strain)
        CityDensityPreset(
            id: "parched",
            nameHe: "פארק צחיח (חריגה)",
            nameEn: "Parched Park (Strain)",
            subtitleHe: "חריגת תקציב (~₪9.2K), ללא חיסכון, בריאות פארק של 15%",
            subtitleEn: "Budget strain (~₪9.2K), 0 savings, 15% park health",
            emoji: "🍂",
            badgeColor: Color(red: 239/255, green: 68/255, blue: 68/255),
            totalSpent: 9200.0,
            totalSavings: 0.0,
            savingsTarget: 1500.0,
            parkHealth: 0.15,
            categoryTotals: [.food: 4500, .shopping: 2800, .entertainment: 1200, .transport: 700],
            buildingTotals: ["food_wolt": 2500, "food_bistro": 2000, "shop_boutique": 1800, "shop_tech": 1000, "trans_station": 700],
            habits: BehavioralHabits(woltDeliveryCount: 22, coffeeCount: 15, onlinePackagesCount: 6),
            enrichmentIds: []
        ),
        // 6. Lush Sanctuary (Max Savings)
        CityDensityPreset(
            id: "lush",
            nameHe: "שמורת טבע פורחת (חיסכון)",
            nameEn: "Lush Sanctuary (Savings)",
            subtitleHe: "הפקדת חיסכון שיא של ₪6,000, בריאות פארק 100%, פריחה מרהיבה",
            subtitleEn: "Record ₪6,000 savings, 100% park health, thriving trees",
            emoji: "🌿",
            badgeColor: Color(red: 16/255, green: 185/255, blue: 129/255),
            totalSpent: 4200.0,
            totalSavings: 6000.0,
            savingsTarget: 5000.0,
            parkHealth: 1.0,
            categoryTotals: [.savings: 6000, .food: 1800, .housing: 1400, .transport: 500, .shopping: 500],
            buildingTotals: ["food_super": 1200, "food_bistro": 600, "house_tower": 800, "house_util": 600, "trans_station": 500, "shop_boutique": 500],
            habits: BehavioralHabits(woltDeliveryCount: 1, coffeeCount: 2, totalGroceryBags: 5),
            enrichmentIds: ["pet_golden_dog", "pet_cat_rooftop", "resident_balloon"]
        ),

        // ── Delivery Intensity Presets ───────────────────────────────────
        // These exist to test the behavioral intensity visual system.
        // Each preset drives a specific DeliveryIntensityTier without requiring real transactions.

        CityDensityPreset(
            id: "delivery_quiet",
            nameHe: "🚲 משלוחים — שקט",
            nameEn: "🚲 Delivery — Quiet",
            subtitleHe: "0–1 הזמנות חודשיות • כמעט ואין נוכחות משלוחים",
            subtitleEn: "0–1 monthly orders · almost no delivery presence",
            emoji: "🚲",
            badgeColor: Color.gray,
            totalSpent: 3800.0,
            totalSavings: 0.0,
            savingsTarget: 1600.0,
            parkHealth: 0.75,
            categoryTotals: [.food: 1200, .housing: 1400, .transport: 600, .shopping: 400, .subscriptions: 200],
            buildingTotals: ["food_bistro": 500, "food_super": 600, "food_coffee": 100, "food_wolt": 90, "house_tower": 900, "house_util": 500, "house_subs": 200, "trans_station": 600, "shop_boutique": 400],
            habits: BehavioralHabits(
                woltDeliveryCount: 1, woltActiveDays: 1, woltTotalSpend: 90,
                coffeeCount: 3, totalGroceryBags: 4,
                deliveryIntensity: DeliveryIntensityEngine.compute(
                    orderCount: 1, totalSpend: 90, activeDays: 1, elapsedDays: 30)
            ),
            enrichmentIds: []
        ),

        CityDensityPreset(
            id: "delivery_normal",
            nameHe: "🛵 משלוחים — רגיל",
            nameEn: "🛵 Delivery — Normal",
            subtitleHe: "2–3 הזמנות • נוכחות טבעית ברחובות",
            subtitleEn: "2–3 orders · natural delivery presence",
            emoji: "🛵",
            badgeColor: Color(red: 0/255, green: 194/255, blue: 232/255),
            totalSpent: 4800.0,
            totalSavings: 0.0,
            savingsTarget: 1600.0,
            parkHealth: 0.65,
            categoryTotals: [.food: 1800, .housing: 1400, .transport: 700, .shopping: 700, .subscriptions: 200],
            buildingTotals: ["food_bistro": 600, "food_super": 700, "food_coffee": 200, "food_wolt": 300, "house_tower": 900, "house_util": 500, "house_subs": 200, "trans_station": 700, "shop_boutique": 500],
            habits: BehavioralHabits(
                woltDeliveryCount: 3, woltActiveDays: 3, woltTotalSpend: 300,
                coffeeCount: 5, totalGroceryBags: 5,
                deliveryIntensity: DeliveryIntensityEngine.compute(
                    orderCount: 3, totalSpend: 300, activeDays: 3, elapsedDays: 30)
            ),
            enrichmentIds: []
        ),

        CityDensityPreset(
            id: "delivery_active",
            nameHe: "🛵🛵 משלוחים — פעיל",
            nameEn: "🛵🛵 Delivery — Active",
            subtitleHe: "4–7 הזמנות • ניכרת שגרת משלוחים קבועה",
            subtitleEn: "4–7 orders · regular delivery routine visible",
            emoji: "🛵",
            badgeColor: Color(red: 69/255, green: 173/255, blue: 189/255),
            totalSpent: 5600.0,
            totalSavings: 0.0,
            savingsTarget: 1600.0,
            parkHealth: 0.52,
            categoryTotals: [.food: 2400, .housing: 1400, .transport: 800, .shopping: 700, .subscriptions: 300],
            buildingTotals: ["food_bistro": 700, "food_super": 800, "food_coffee": 300, "food_wolt": 600, "house_tower": 900, "house_util": 500, "house_subs": 300, "trans_station": 800, "shop_boutique": 500],
            habits: BehavioralHabits(
                woltDeliveryCount: 6, woltActiveDays: 5, woltTotalSpend: 600,
                coffeeCount: 7, totalGroceryBags: 6,
                deliveryIntensity: DeliveryIntensityEngine.compute(
                    orderCount: 6, totalSpend: 600, activeDays: 5, elapsedDays: 30)
            ),
            enrichmentIds: []
        ),

        CityDensityPreset(
            id: "delivery_high",
            nameHe: "🛵🛵🛵 משלוחים — גבוה",
            nameEn: "🛵🛵🛵 Delivery — High",
            subtitleHe: "8–11 הזמנות • משלוחים משמעותיים החודש",
            subtitleEn: "8–11 orders · delivery is clearly dominant this month",
            emoji: "🛵",
            badgeColor: Color(red: 245/255, green: 158/255, blue: 11/255),
            totalSpent: 7000.0,
            totalSavings: 0.0,
            savingsTarget: 1600.0,
            parkHealth: 0.35,
            categoryTotals: [.food: 3200, .housing: 1400, .transport: 900, .shopping: 1000, .subscriptions: 500],
            buildingTotals: ["food_bistro": 800, "food_super": 700, "food_coffee": 350, "food_wolt": 1350, "house_tower": 900, "house_util": 500, "house_subs": 500, "trans_station": 900, "shop_boutique": 700],
            habits: BehavioralHabits(
                woltDeliveryCount: 10, woltActiveDays: 8, woltTotalSpend: 1350,
                coffeeCount: 9, totalGroceryBags: 5,
                deliveryIntensity: DeliveryIntensityEngine.compute(
                    orderCount: 10, totalSpend: 1350, activeDays: 8, elapsedDays: 30)
            ),
            enrichmentIds: []
        ),

        CityDensityPreset(
            id: "delivery_extreme",
            nameHe: "🔥 משלוחים — קיצוני",
            nameEn: "🔥 Delivery — Extreme",
            subtitleHe: "12+ הזמנות • העיר מוצפת שליחים — וואו",
            subtitleEn: "12+ orders · the city is flooded with riders",
            emoji: "🔥",
            badgeColor: Color(red: 239/255, green: 68/255, blue: 68/255),
            totalSpent: 8500.0,
            totalSavings: 0.0,
            savingsTarget: 1600.0,
            parkHealth: 0.20,
            categoryTotals: [.food: 4200, .housing: 1400, .transport: 1000, .shopping: 1400, .subscriptions: 500],
            buildingTotals: ["food_bistro": 800, "food_super": 700, "food_coffee": 300, "food_wolt": 2400, "house_tower": 900, "house_util": 500, "house_subs": 500, "trans_station": 1000, "shop_boutique": 1000],
            habits: BehavioralHabits(
                woltDeliveryCount: 18, woltActiveDays: 14, woltTotalSpend: 2400,
                coffeeCount: 10, totalGroceryBags: 4,
                deliveryIntensity: DeliveryIntensityEngine.compute(
                    orderCount: 18, totalSpend: 2400, activeDays: 14, elapsedDays: 30)
            ),
            enrichmentIds: []
        ),

        // ── Stress Test (DEBUG internal only) ────────────────────────────
        // Not a real user state. Tests maximum visual density, performance,
        // and scene readability under exaggerated conditions.
        CityDensityPreset(
            id: "delivery_absurd",
            nameHe: "💀 Stress Test — Delivery Absurd",
            nameEn: "💀 Stress Test — Delivery Absurd",
            subtitleHe: "30 הזמנות • בדיקת עומס מרבי — לא מצב אמיתי",
            subtitleEn: "30 orders · maximum visual load — not a real user state",
            emoji: "💀",
            badgeColor: Color(red: 139/255, green: 92/255, blue: 246/255),
            totalSpent: 12000.0,
            totalSavings: 0.0,
            savingsTarget: 1600.0,
            parkHealth: 0.05,
            categoryTotals: [.food: 7000, .housing: 1400, .transport: 1200, .shopping: 1800, .subscriptions: 600],
            buildingTotals: ["food_bistro": 800, "food_super": 700, "food_coffee": 300, "food_wolt": 5200, "house_tower": 900, "house_util": 500, "house_subs": 600, "trans_station": 1200, "shop_boutique": 1200],
            habits: BehavioralHabits(
                woltDeliveryCount: 30, woltActiveDays: 20, woltTotalSpend: 5200,
                coffeeCount: 12, totalGroceryBags: 3,
                deliveryIntensity: DeliveryIntensityEngine.compute(
                    orderCount: 30, totalSpend: 5200, activeDays: 20, elapsedDays: 30)
            ),
            enrichmentIds: []
        )
    ]

    private var currentPreset: CityDensityPreset {
        presets[selectedPresetIndex]
    }

    public var body: some View {
        ZStack {
            // Real 3D Diorama View
            DioramaReadyWrapper(
                totalSpent: currentPreset.totalSpent,
                totalSavings: currentPreset.totalSavings,
                savingsTarget: currentPreset.savingsTarget,
                parkHealth: currentPreset.parkHealth,
                viewResetToken: viewResetToken,
                isOverview: false,
                categoryTotals: currentPreset.categoryTotals,
                buildingTotals: currentPreset.buildingTotals,
                districtStates: CitySimulationEngine.districtStates(for: currentPreset.categoryTotals),
                venueStates: [],
                habits: currentPreset.habits,
                enrichmentIds: currentPreset.enrichmentIds,
                newlyUnlockedEnrichmentId: nil,
                slotPlacements: [:],
                selectedDistrict: nil,
                selectedBuildingId: nil,
                tutorialBuildingId: nil,
                language: isHe ? "he" : "en",
                isPaused: false,
                onSelectDistrict: { _ in },
                onBuildingSelected: { _ in },
                onSlotTapped: nil,
                onCameraOffsetChanged: nil
            )
            .ignoresSafeArea()

            // Overlaid Controls & Preset Switcher
            VStack(spacing: 0) {
                // Top Header Pill Bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            MoneyIcon(isHe ? .chevronRight : .chevronLeft, size: 14)
                            Text(isHe ? "חזרה" : "Back")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color.deepNavy)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.92))
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    HStack(spacing: 8) {
                        Text("\(currentPreset.emoji) \(isHe ? currentPreset.nameHe : currentPreset.nameEn)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)

                        Button {
                            Haptics.impact(.light)
                            viewResetToken &+= 1
                        } label: {
                            MoneyIcon(.refresh, size: 14, color: Color.deepNavy)
                                .padding(7)
                                .background(Color(red: 243/255, green: 244/255, blue: 246/255))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.92))
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)

                Spacer()

                // Bottom Floating Control Dashboard
                VStack(spacing: 12) {
                    // Live Stats Readout Bar
                    HStack(spacing: 12) {
                        metricTag(label: isHe ? "הוצאה:" : "Spent:", value: l10n.format(amount: currentPreset.totalSpent))
                        metricTag(label: isHe ? "חיסכון:" : "Savings:", value: l10n.format(amount: currentPreset.totalSavings))
                        metricTag(label: isHe ? "בריאות פארק:" : "Park:", value: "\(Int(currentPreset.parkHealth * 100))%")
                    }

                    // Preset Switcher Carousel
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
                                let isSel = selectedPresetIndex == index
                                Button {
                                    Haptics.selection()
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                        selectedPresetIndex = index
                                        viewResetToken &+= 1
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(preset.emoji)
                                        Text(isHe ? preset.nameHe : preset.nameEn)
                                            .font(.system(size: 12, weight: isSel ? .bold : .medium, design: .rounded))
                                    }
                                    .foregroundColor(isSel ? .white : Color.deepNavy)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(isSel ? Color.deepNavy : Color.white)
                                    .clipShape(Capsule())
                                    .shadow(color: Color.black.opacity(isSel ? 0.12 : 0.04), radius: 4, y: 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.12), radius: 14, y: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .environment(\.layoutDirection, isHe ? .rightToLeft : .leftToRight)
    }

    private func metricTag(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundColor(Color.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.85))
        .clipShape(Capsule())
    }
}

// MARK: - Phase 10 · Candidate Inspector (DEBUG)

/// Inspects the Recap 2.0 pipeline for each curated preset: the engine candidates with their
/// scores, the fixed backbone, the curated story slots, every rejection reason, and the final
/// shot count. Data is computed on demand per preset; nothing is written anywhere.
struct RecapCandidateLabSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager

    @State private var kind: RecapLabKind = .normal
    @State private var showRawReports = false
    @State private var analysis: Analysis?

    private var isHe: Bool { l10n.language == .hebrew }

    private struct Analysis {
        let recap: MonthlyRecap
        let candidates: [RecapInsight]
        let backbone: [RecapBackboneInsight]
        let story: RecapCuratedStory
        let rejections: [RecapCuratedRejection]
        let engineReport: String
        let curatorReport: String
        let shots: Int
    }

    private static let presetMeta: [(kind: RecapLabKind, emoji: String, he: String, en: String)] = [
        (.normal, "🌟", "רגיל", "Normal"),
        (.delivery, "🛵", "משלוחים", "Delivery"),
        (.coffee, "☕", "קפה", "Coffee"),
        (.quiet, "🌿", "רגוע", "Quiet"),
        (.accumulation, "🧩", "הצטברות", "Accumulation"),
        (.minimalData, "🌫️", "מינימלי", "Minimal"),
        (.strongTrend, "📉", "מגמה", "Trend"),
        (.richNoticed, "🎡", "עשיר", "Rich")
    ]

    private func compute() -> Analysis {
        let recap = RecapPreviewData.recap(kind: kind)
        let txs = RecapPreviewData.transactions(kind: kind)
        let month = recap.date
        let candidates = RecapInsightEngine.generateCandidates(for: month, allTransactions: txs)
        let backbone = RecapInsightCurator.backbone(for: month, allTransactions: txs)
        let result = RecapInsightCurator.curate(candidates: candidates, backbone: backbone)
        return Analysis(
            recap: recap,
            candidates: candidates,
            backbone: backbone,
            story: result.story,
            rejections: result.rejections,
            engineReport: RecapInsightEngine.debugReport(for: month, allTransactions: txs),
            curatorReport: RecapInsightCurator.debugCuratorReport(for: month, allTransactions: txs),
            shots: RecapEditorialShot.sequence(for: recap).count
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        presetChips
                        if let analysis {
                            summary(analysis)
                            storyCard(analysis)
                            if !analysis.rejections.isEmpty { rejectionsCard(analysis) }
                            poolCard(analysis)
                            rawReports(analysis)
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(isHe ? "מפקח מועמדויות" : "Candidate Inspector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isHe ? "סגור" : "Done") { dismiss() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                }
            }
        }
        .environment(\.layoutDirection, isHe ? .rightToLeft : .leftToRight)
        .onAppear { if analysis == nil { analysis = compute() } }
        .onChange(of: kind) { _, _ in analysis = compute() }
    }

    private var presetChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.presetMeta, id: \.kind) { meta in
                    let selected = meta.kind == kind
                    Button {
                        Haptics.selection()
                        Haptics.impact(.light)
                        kind = meta.kind
                    } label: {
                        HStack(spacing: 5) {
                            Text(meta.emoji)
                                .font(.system(size: 13))
                            Text(isHe ? meta.he : meta.en)
                                .font(.system(size: 12, weight: selected ? .bold : .medium, design: .rounded))
                        }
                        .foregroundColor(selected ? .white : Color.deepNavy)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selected ? Color.deepNavy : Color.white)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(selected ? 0.12 : 0.04), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func pipelineCard<Content: View>(title: String, badge: String? = nil, accent: Color = Color.deepNavy, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accent.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            content()
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
    }

    private func roleLabel(_ role: String) -> some View {
        Text(role)
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(pipelineRoleColor(role))
            .clipShape(Capsule())
    }
    private func pipelineRoleColor(_ role: String) -> Color {
        switch role {
        case "Hero 1": Color(red: 239/255, green: 68/255, blue: 68/255)
        case "Hero 2": Color(red: 59/255, green: 130/255, blue: 246/255)
        case "Micro Fact": Color(red: 139/255, green: 92/255, blue: 246/255)
        default: Color(red: 16/255, green: 185/255, blue: 129/255)
        }
    }
    private func familyColor(_ family: RecapInsightFamily) -> Color {
        Color(red: 100/255, green: 116/255, blue: 139/255)
    }
    private func scoreText(_ value: Double) -> String { String(format: "%.2f", value) }

    private func summary(_ a: Analysis) -> some View {
        let total = a.recap.totalSpent
        let info = Self.presetMeta.first { $0.kind == kind }
        return pipelineCard(
            title: (info?.he ?? "") + " · " + (info?.en ?? ""),
            badge: a.recap.transactionCount <= 2 ? "SPARSE 5 SHOTS" : "\(a.shots) SHOTS"
        ) {
            HStack(spacing: 16) {
                metricBlock("Spent", l10n.format(amount: total))
                metricBlock("Tx", "\(a.recap.transactionCount)")
                metricBlock("Candidates", "\(a.candidates.count)")
                metricBlock("Slots", "\(a.story.selectedInsights.count)")
                metricBlock("Rejected", "\(a.rejections.count)")
            }
            Text(isHe
                ? "רצף: פתיחה + סה״כ + פעילות + רובע + דינמי⁽≤4⁾ + הבחנות + דיוקן"
                : "Sequence: opening + total + activity + district + dynamic(≤4) + noticed + portrait")
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundColor(Color.textSecondary)
            Text(isHe
                ? "הערה: הדינמי בקצה ה־Flow מוגבל ל־3, וגם ל־2 בכרטיסי אינדקס – החישוב כאן הוא התקרה התיאורטית."
                : "Flow wiring caps dynamic at 3 (2 on archive index) — the count above is the theoretical ceiling.")
                .font(.system(size: 10, weight: .regular, design: .default))
                .foregroundColor(Color.textMuted)
        }
    }

    private func metricBlock(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundColor(Color.textMuted)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
        }
    }

    private func storyCard(_ a: Analysis) -> some View {
        pipelineCard(
            title: isHe ? "הסיפור המעוצב" : "Curated Story",
            badge: "\(a.story.hero1 == nil ? 0 : 1) HERO · \(a.story.noticed.count) NOTICED · \(a.story.hero2 == nil ? 0 : 1) HERO2 · \(a.story.microFact == nil ? 0 : 1) FACT",
            accent: Color(red: 239/255, green: 68/255, blue: 68/255)
        ) {
            if a.story.selectedInsights.isEmpty {
                Text(isHe ? "אין סיפור — שום מועמדות לא עברה את הרף." : "No story — nothing cleared the bars.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textSecondary)
            } else {
                VStack(spacing: 12) {
                    if let h1 = a.story.hero1 { insightRow(h1, role: "Hero 1") }
                    ForEach(a.story.noticed) { row in insightRow(row, role: "Noticed") }
                    if let h2 = a.story.hero2 { insightRow(h2, role: "Hero 2") }
                    if let fact = a.story.microFact { insightRow(fact, role: "Micro Fact") }
                }
            }
        }
    }

    private func insightRow(_ insight: RecapInsight, role: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                roleLabel(role)
                Text(insight.kind.rawValue)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(isHe ? Color.deepNavy : Color.deepNavy)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 243/255, green: 244/255, blue: 246/255))
                    .clipShape(Capsule())
                Text("family=\(insight.family.rawValue)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
                Spacer()
                Text("Σ \(scoreText(insight.scores.total))")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
            }
            Text(isHe ? insight.headlineHe : insight.headlineEn)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
            if let v = isHe ? insight.valueHe : insight.valueEn {
                Text(v)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(Color.textSecondary)
            }
            if let s = isHe ? insight.supportHe : insight.supportEn {
                Text(s)
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundColor(Color.textSecondary)
                    .lineSpacing(2)
            }
            HStack(spacing: 6) {
                subScore("su", insight.scores.surprise)
                subScore("re", insight.scores.relevance)
                subScore("co", insight.scores.contrast)
                subScore("cf", insight.scores.confidence)
                subScore("no", insight.scores.novelty)
            }
        }
        .padding(12)
        .background(Color(red: 248/255, green: 249/255, blue: 251/255))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func subScore(_ tag: String, _ value: Double) -> some View {
        HStack(spacing: 3) {
            Text(tag)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(Color.textMuted)
            Text(scoreText(value))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.white)
        .clipShape(Capsule())
    }

    private func rejectionsCard(_ a: Analysis) -> some View {
        pipelineCard(
            title: isHe ? "דחיות" : "Rejections",
            badge: "\(a.rejections.count)"
        ) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(a.rejections.enumerated()), id: \.offset) { _, rejection in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color.textMuted)
                        Text("\(rejection.insightID) — \(rejection.reason)")
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(Color.textMuted)
                    }
                }
            }
        }
    }

    private func poolCard(_ a: Analysis) -> some View {
        pipelineCard(
            title: isHe ? "בריכת מועמדויות" : "Candidate Pool",
            badge: "\(a.candidates.count) + \(a.backbone.count) BACKBONE"
        ) {
            VStack(spacing: 8) {
                if !a.backbone.isEmpty {
                    HStack(spacing: 6) {
                        roleLabel("Backbone")
                        Text(isHe ? "רובע סיפור + רגע משמעותי" : "Biggest Story District + Meaningful Moment")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Color.textSecondary)
                        Spacer()
                    }
                }
                ForEach(a.candidates.sorted { $0.scores.total > $1.scores.total }) { candidate in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(scoreText(candidate.scores.total))
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Text(candidate.family.rawValue)
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundColor(familyColor(candidate.family))
                        }
                        .frame(width: 64, alignment: isHe ? .trailing : .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(isHe ? candidate.headlineHe : candidate.headlineEn)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                                .lineLimit(1)
                            Text("\(candidate.kind.rawValue) · \(candidate.basis.count) basis")
                                .font(.system(size: 10, weight: .regular, design: .default))
                                .foregroundColor(Color.textMuted)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(a.story.selectedInsights.contains(where: { $0.id == candidate.id })
                        ? Color(red: 209/255, green: 250/255, blue: 229/255).opacity(0.6)
                        : Color(red: 243/255, green: 244/255, blue: 246/255))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func rawReports(_ a: Analysis) -> some View {
        DisclosureGroup(isExpanded: $showRawReports) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Engine — generateCandidates")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(Color.textMuted)
                Text(a.engineReport)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(red: 248/255, green: 249/255, blue: 251/255))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text("Curator — curate")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(Color.textMuted)
                Text(a.curatorReport)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(red: 248/255, green: 249/255, blue: 251/255))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.top, 6)
        } label: {
            HStack {
                Text(isHe ? "דוחות גלם (Engine + Curator)" : "Raw reports (Engine + Curator)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                Spacer()
                Text(showRawReports ? "▲" : "▼")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
    }
}
#endif
