import SwiftUI

/// A weekly reward ceremony, not an inventory or a map editor.
public struct CityProgressSheet: View {
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let options: [ProgressRewardOption]
    public let unlockedEnrichments: [CityEnrichment]
    public var rewardContext: CityRewardContext? = nil
    public var previewJoined: ProgressRewardOption? = nil
    public let onSelectOption: (ProgressRewardOption) -> Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selected: ProgressRewardOption?
    @State private var joined: ProgressRewardOption?
    @State private var saveFailed = false
    @State private var isClaiming = false
    @State private var showInfo = false

    private var he: Bool { l10n.isHebrew }
    private func title(_ option: ProgressRewardOption) -> String {
        if he { return option.title }
        return ["pet_cat_rooftop": "Milo the cat", "pet_golden_dog": "Archie the dog",
                "resident_artist": "Noga the artist", "resident_skater": "Gal and the skate",
                "resident_musician": "Lenny (guitar)", "resident_balloon": "Ori in the park"][option.id] ?? option.title
    }
    private func description(_ option: ProgressRewardOption) -> String {
        if he { return option.subtitle }
        return ["pet_cat_rooftop": "Found a spot by the shops. It's his now.", "pet_golden_dog": "Came for a lakeside walk. Stayed for the company.",
                "resident_artist": "Painting the city at her own pace.", "resident_skater": "Just one more little lap.",
                "resident_musician": "A tiny street concert. No tickets needed.", "resident_balloon": "Going for a walk. The balloon insisted on coming."][option.id] ?? ""
    }

    private func firstName(_ option: ProgressRewardOption) -> String {
        String(title(option).split(separator: " ").first ?? "")
    }

    private func hero(_ option: ProgressRewardOption, size: CGFloat) -> some View {
        // Reuse SPENT's illustrated icon language until dedicated 2D companion portraits exist.
        MoneyIcon(option.type == .pet ? .paw : (option.id == "resident_artist" ? .pencil : .user), size: size)
            .accessibilityHidden(true)
    }

    private var reason: String {
        guard let context = rewardContext else { return he ? "עוד שבוע עבר בעיר." : "Another week in the city." }
        if he { return context.reasonText }
        return context.trigger == .weeklyPresence ? "Another week in the city." : "The city has been quieter than usual over the last three days."
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Button { showInfo = true } label: {
                        Image(systemName: "info.circle").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(he ? "על התוספות בעיר" : "About city additions")
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(he ? "סגירה" : "Close")
                }
                if let friend = joined {
                    VStack(spacing: 24) {
                        hero(friend, size: 120).padding(.vertical, 20)
                        Text(he ? "\(firstName(friend)) \(friend.id == "resident_artist" ? "הצטרפה" : "הצטרף") לעיר" : "\(firstName(friend)) joined the city")
                            .font(.largeTitle.bold()).multilineTextAlignment(.center)
                        Text(description(friend)).font(.body).foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                        action(he ? "למצוא אותו בעיר" : "Find them in the city") { dismiss() }
                    }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.94)))
                } else if !options.isEmpty {
                    VStack(spacing: 10) {
                        Text(he ? "משהו חדש בעיר" : "Something new in the city").font(.subheadline.weight(.medium))
                        Text(he ? "מי מצטרף הפעם?" : "Who’s joining this time?").font(.largeTitle.bold())
                        Text(reason).font(.subheadline).foregroundStyle(Color.textSecondary)
                    }.multilineTextAlignment(.center)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            ForEach(Array(options.prefix(3))) { option in
                                companionCard(option)
                            }
                        }.padding(.horizontal, 6).padding(.vertical, 12)
                    }
                    if let selected {
                        action(he ? "לצרף את \(firstName(selected)) לעיר" : "Welcome \(firstName(selected))") {
                            guard !isClaiming else { return }
                            isClaiming = true
                            if onSelectOption(selected) {
                                Haptics.notify(.success)
                                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.8)) {
                                    joined = selected
                                }
                            } else { saveFailed = true }
                            isClaiming = false
                        }
                        .disabled(isClaiming)
                    }
                } else {
                    Text(he ? "החברים בעיר" : "Friends in the city").font(.largeTitle.bold())
                    Text(he ? "מדי פעם תופיע כאן תוספת חדשה." : "From time to time, someone new will arrive here.")
                        .foregroundStyle(Color.textSecondary).multilineTextAlignment(.center)
                    ForEach(CityProgressEngine.shared.allCatalogOptions.filter { option in
                        unlockedEnrichments.contains { $0.itemId == option.id }
                    }) { option in
                        HStack(spacing: 16) {
                            hero(option, size: 52)
                            Text(title(option)).font(.headline)
                            Spacer()
                        }.padding(.vertical, 8)
                    }
                }
            }.padding(22).foregroundStyle(Color.deepNavy)
        }
        .background(Color.appBackground)
        .presentationBackground(Color.appBackground)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
        .alert(he ? "על החיים בעיר" : "About city life", isPresented: $showInfo) {
            Button(he ? "הבנתי" : "Got it", role: .cancel) {}
        } message: {
            Text(he ? "SPENT מסתכלת על השימוש שלך ועל שינויים בדפוס ההוצאות כדי להוסיף מדי פעם חיים חדשים לעיר." : "SPENT looks at your activity and changes in spending patterns to occasionally bring new life to the city.")
        }
        .alert(he ? "החבר עדיין לא נוסף" : "Your companion wasn’t added", isPresented: $saveFailed) {
            Button(he ? "אישור" : "OK", role: .cancel) {}
        } message: {
            Text(he ? "השמירה לא הצליחה או שהבחירה כבר אינה זמינה. אפשר לנסות שוב." : "Saving failed or the choice is no longer available. Please try again.")
        }
        .onAppear { joined = previewJoined }
    }

    private func companionCard(_ option: ProgressRewardOption) -> some View {
        let isSelected = selected?.id == option.id
        return Button {
            Haptics.selection()
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.8)) {
                selected = option
            }
        } label: {
            VStack(spacing: 18) {
                hero(option, size: 100).padding(.vertical, 14)
                Text(title(option)).font(.title2.bold())
                Text(description(option)).font(.body).foregroundStyle(Color.textSecondary)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2).accessibilityHidden(true)
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(width: dynamicTypeSize.isAccessibilitySize ? 290 : 250)
            .frame(minHeight: 310)
            .background(MoneyCityTheme.warmCream, in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(isSelected ? Color.deepNavy : Color.clear, lineWidth: 2))
            .scaleEffect(isSelected && !reduceMotion ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title(option)). \(description(option))")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func action(_ title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title).font(.headline).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44).padding(12)
                .foregroundStyle(MoneyCityTheme.jetBlack)
                .background(MoneyCityTheme.neonLime, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Weekly companions") {
    CityProgressSheet(
        options: Array(CityProgressEngine.shared.allCatalogOptions.prefix(3)),
        unlockedEnrichments: [],
        rewardContext: CityRewardContext(trigger: .weeklyPresence, unlockedAt: Date()),
        onSelectOption: { _ in true }
    ).environmentObject(LocalizationManager.shared)
}
#endif
