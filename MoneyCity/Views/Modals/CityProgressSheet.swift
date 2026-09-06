import SwiftUI

/// A weekly reward ceremony, not an inventory or a map editor.
public struct CityProgressSheet: View {
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    public let options: [ProgressRewardOption]
    public let unlockedEnrichments: [CityEnrichment]
    public let nextDate: Date
    public let savedAmount: Double
    public let hasBaseline: Bool
    public let onSelectOption: (ProgressRewardOption) -> Bool
    @State private var joined: ProgressRewardOption?
    @State private var saveFailed = false
    @State private var isClaiming = false

    private var he: Bool { l10n.isHebrew }
    private var complete: Bool {
        CityCompanions.ids.isSubset(of: Set(unlockedEnrichments.map(\.itemId)))
    }
    private func title(_ option: ProgressRewardOption) -> String {
        if he { return option.title }
        return ["pet_cat_rooftop": "Mishmish the cat", "pet_golden_dog": "Toffee the dog",
                "resident_artist": "Noga the artist", "resident_skater": "Gal on wheels",
                "resident_musician": "Lenny and the guitar", "resident_balloon": "Ori and the balloon"][option.id] ?? option.title
    }
    private func description(_ option: ProgressRewardOption) -> String {
        if he { return option.subtitle }
        return ["pet_cat_rooftop": "Found a spot by the shops. It's his now.", "pet_golden_dog": "Came for a lakeside walk. Stayed for the company.",
                "resident_artist": "Painting the city at her own pace.", "resident_skater": "Just one more little lap.",
                "resident_musician": "A tiny street concert. No tickets needed.", "resident_balloon": "Going for a walk. The balloon insisted on coming."][option.id] ?? ""
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        MoneyIcon(.xmarkCircle, size: 24).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(he ? "סגירה" : "Close")
                }
                MoneyIcon(joined == nil ? .gift : .checkCircle, size: 46)
                    .padding(20).background(Color.themeMint.opacity(0.13), in: Circle())
                if let friend = joined {
                    Text(he ? "\(title(friend)) — איזה כיף שבאת!" : "\(title(friend)) joined your city!")
                        .font(.title2.bold()).multilineTextAlignment(.center)
                    Text(he ? "החבר החדש כבר בעיר ויישאר בה. בלי הצבה או ניהול — רק לפגוש אותו מדי פעם." : "Already in the city, here to stay. No placing or managing — just a familiar face to spot.")
                        .multilineTextAlignment(.center).foregroundStyle(Color.textSecondary)
                    Button { dismiss() } label: {
                        Text(he ? "בואו נראה בעיר" : "Meet in the city")
                            .font(.headline).frame(maxWidth: .infinity).padding(16)
                            .background(Color.themeMint, in: RoundedRectangle(cornerRadius: 16))
                    }
                } else {
                    Text(he ? "מצטרפים לעיר" : "City companions").font(.title2.bold())
                    if !options.isEmpty {
                        Text(he ? "פרס קטן על ההתקדמות השבועית שלך" : "A little reward for your weekly progress")
                            .font(.headline).multilineTextAlignment(.center)
                        Text(he ? "ב־7 הימים האחרונים ההוצאות היומיומיות היו נמוכות ב־\(l10n.format(amount: savedAmount)) מב־7 הימים שלפניהם. אפשר לבחור חבר אחד שיישאר בעיר." : "Your everyday spending in the last 7 days was \(l10n.format(amount: savedAmount)) lower than in the previous 7 days. Choose one companion to stay in your city.")
                            .font(.subheadline).foregroundStyle(Color.textSecondary).multilineTextAlignment(.center)
                        ForEach(options) { option in
                            Button {
                                guard !isClaiming else { return }
                                isClaiming = true
                                if onSelectOption(option) { joined = option } else { saveFailed = true }
                                isClaiming = false
                            } label: {
                                HStack(spacing: 14) {
                                    MoneyIcon(option.type == .pet ? .paw : .user, size: 30)
                                        .frame(width: 52, height: 52)
                                        .background(Color.themeMint.opacity(0.12), in: Circle())
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(title(option)).font(.headline)
                                        Text(description(option)).font(.subheadline).foregroundStyle(Color.textSecondary)
                                        Text(he ? "לבחור שיצטרף" : "Welcome to the city").font(.caption.bold()).padding(.top, 3)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(.plain).disabled(isClaiming)
                        }
                    } else if complete {
                        Text(he ? "כל החבורה כבר בעיר שלך" : "The whole gang is here").font(.headline)
                        Text(he ? "החברים שהצטרפו נשארים בעיר. כרגע אין חברים נוספים לבחירה." : "Your companions are here to stay. There are no more companions to choose right now.")
                            .foregroundStyle(Color.textSecondary).multilineTextAlignment(.center)
                    } else if nextDate > Date() {
                        Text(he ? "הפרס הבא ייבדק החל מ־" : "Next reward check from")
                        Text(nextDate, style: .date).font(.headline)
                        Text(he ? "בחירה אחת בכל שבעה ימים, כשההוצאות היומיומיות יורדות ביותר מ־10 ₪ לעומת השבוע הקודם. החברים שכבר הצטרפו נשארים תמיד." : "One choice every seven days when everyday spending decreases by more than ₪10 compared with the previous week. Existing companions always stay.")
                            .foregroundStyle(Color.textSecondary).multilineTextAlignment(.center)
                    } else {
                        Text(he ? (hasBaseline ? "השבוע עדיין אין פרס חדש לבחירה" : "קודם נכיר את השבועות שלך") : (hasBaseline ? "No new reward to choose this week yet" : "Let's get to know your weeks first"))
                            .font(.headline).multilineTextAlignment(.center)
                        Text(he ? "משווים שני שבועות של הוצאות יומיומיות, בלי דיור, מנויים, בריאות, בנק וחיסכון. ירידה של יותר מ־10 ₪ יכולה לפתוח בחירה של חבר חדש. אין צורך לוותר על דברים שאתה צריך." : "We compare two weeks of everyday spending, excluding housing, subscriptions, health, finance and savings. A decrease of more than ₪10 can unlock a new companion. There's no need to skip things you need.")
                            .foregroundStyle(Color.textSecondary).multilineTextAlignment(.center)
                    }
                    if !options.isEmpty {
                        Button(he ? "לא עכשיו" : "Not now") { dismiss() }.frame(minHeight: 44)
                    }
                }
            }
            .padding(22).foregroundStyle(Color.deepNavy)
        }
        .background(Color.appBackground)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert(he ? "החבר עדיין לא נוסף" : "Your companion wasn't added", isPresented: $saveFailed) {
            Button(he ? "אישור" : "OK", role: .cancel) {}
        } message: {
            Text(he ? "השמירה לא הצליחה או שהבחירה כבר אינה זמינה. כשל בשמירה לא מנצל את הפרס. אפשר לנסות שוב." : "Saving failed or the choice is no longer available. A failed save does not consume your reward. Please try again.")
        }
    }
}
