import SwiftUI

/// A weekly reward ceremony and city life status sheet.
public struct CityProgressSheet: View {
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let options: [ProgressRewardOption]
    public let unlockedEnrichments: [CityEnrichment]
    public var rewardContext: CityRewardContext? = nil
    public var previewJoined: ProgressRewardOption? = nil
    public var rewardProgress: CityRewardProgress? = nil
    public let onSelectOption: (ProgressRewardOption) -> Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selected: ProgressRewardOption?
    @State private var joined: ProgressRewardOption?
    @State private var saveFailed = false
    @State private var isClaiming = false

    private var he: Bool { l10n.isHebrew }
    private var progress: CityRewardProgress {
        rewardProgress ?? CityRewardEngine().progress()
    }

    public init(
        options: [ProgressRewardOption],
        unlockedEnrichments: [CityEnrichment],
        rewardContext: CityRewardContext? = nil,
        previewJoined: ProgressRewardOption? = nil,
        rewardProgress: CityRewardProgress? = nil,
        onSelectOption: @escaping (ProgressRewardOption) -> Bool
    ) {
        self.options = options
        self.unlockedEnrichments = unlockedEnrichments
        self.rewardContext = rewardContext
        self.previewJoined = previewJoined
        self.rewardProgress = rewardProgress
        self.onSelectOption = onSelectOption
    }

    private func title(_ option: ProgressRewardOption) -> String {
        if he { return option.title }
        return ["pet_cat_rooftop": "Rooftop cat", "pet_golden_dog": "Lakeside dog",
                "resident_artist": "Street artist", "resident_skater": "The skater",
                "resident_musician": "Street musician", "resident_balloon": "Balloon in the park"][option.id] ?? option.title
    }

    private func description(_ option: ProgressRewardOption) -> String {
        if he { return option.subtitle }
        return ["pet_cat_rooftop": "Usually seen around the shops.",
                "pet_golden_dog": "Usually wandering by the lake.",
                "resident_artist": "Paints occasionally in the square.",
                "resident_skater": "Cruising through the commercial district.",
                "resident_musician": "Plays now and then in the city center.",
                "resident_balloon": "A regular walk through the park."][option.id] ?? ""
    }

    private func hero(_ option: ProgressRewardOption, size: CGFloat) -> some View {
        Group {
            if let uiImage = UIImage(named: "companion_\(option.id)") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                MoneyIcon(option.type == .pet ? .paw : (option.id == "resident_artist" ? .pencil : .user), size: size)
            }
        }
        .accessibilityHidden(true)
    }

    private var reason: String {
        guard let context = rewardContext else { return he ? "עוד שבוע עבר בעיר." : "Another week in the city." }
        if he { return context.reasonText }
        return context.trigger == .weeklyPresence ? "Another week in the city." : "The city has been quieter than usual over the last three days."
    }

    private var heroHeadingFont: Font {
        .system(.largeTitle, design: .rounded, weight: .bold)
    }

    private var cardTitleFont: Font {
        .system(.title2, design: .rounded, weight: .bold)
    }

    private var cardEyebrowFont: Font {
        .system(.subheadline, design: .rounded, weight: .medium)
    }

    private var actionButtonFont: Font {
        .system(.headline, design: .rounded, weight: .bold)
    }

    private func countdownTitle(daysRemaining: Int, isReady: Bool) -> String {
        if isReady {
            return he ? "מתנה חדשה מוכנה לעיר" : "A new gift is ready"
        }
        if he {
            switch daysRemaining {
            case 0:
                return "המתנה כמעט כאן"
            case 1:
                return "עוד יום אחד למתנה הבאה"
            case 2:
                return "עוד יומיים למתנה הבאה"
            default:
                return "עוד \(daysRemaining) ימים למתנה הבאה"
            }
        } else {
            switch daysRemaining {
            case 0:
                return "Almost here"
            case 1:
                return "1 day until next gift"
            default:
                return "\(daysRemaining) days until next gift"
            }
        }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top close bar
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 36, height: 36)
                                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.deepNavy)
                        }
                    }
                    .accessibilityLabel(he ? "סגירה" : "Close")
                }

                if let friend = joined {
                    // Ceremony: Just joined
                    VStack(spacing: 24) {
                        hero(friend, size: 120).padding(.vertical, 20)
                        Text(he ? "\(title(friend)) \(friend.id == "resident_artist" ? "נוספה" : "נוסף") לעיר" : "\(title(friend)) added to the city")
                            .font(heroHeadingFont).multilineTextAlignment(.center)
                        Text(description(friend)).font(.body).foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                        action(he ? "לראות בעיר" : "View in city") { dismiss() }
                    }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.94)))
                } else if !options.isEmpty {
                    // Ceremony: Options ready to claim
                    VStack(spacing: 10) {
                        Text(he ? "משהו חדש בעיר" : "Something new in the city").font(cardEyebrowFont)
                        Text(he ? "מה נוסף לעיר?" : "What's added to the city?").font(heroHeadingFont)
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
                        action(he ? "להוסיף לעיר" : "Add to city") {
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
                    // Default State: City life overview & Progress to next reward
                    overviewContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
            .foregroundStyle(Color.deepNavy)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .presentationBackground(Color.appBackground)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.fraction(0.56), .large])
        .presentationDragIndicator(.visible)
        .alert(he ? "החבר עדיין לא נוסף" : "Your companion wasn’t added", isPresented: $saveFailed) {
            Button(he ? "אישור" : "OK", role: .cancel) {}
        } message: {
            Text(he ? "השמירה לא הצליחה או שהבחירה כבר אינה זמינה. אפשר לנסות שוב." : "Saving failed or the choice is no longer available. Please try again.")
        }
        .onAppear {
            joined = previewJoined
            if options.isEmpty {
                let owned = renderedOwnedOptions
                let appliedItems = unlockedEnrichments.map { "\($0.itemId) (isApplied: \($0.isApplied))" }.joined(separator: ", ")
                let renderedIds = owned.map(\.id).joined(separator: ", ")
                print("[CityProgressSheet] Runtime Verification -> Total enrichments: \(unlockedEnrichments.count); Items: [\(appliedItems)]; Rendered owned IDs: [\(renderedIds)]; Visible count: \(owned.count)")
            }
        }
    }

    private var overviewContent: some View {
        VStack(spacing: 16) {
            // Unified Minimalist City Life & Next Reward Card
            VStack(spacing: 16) {
                // Emblem
                ZStack {
                    Circle()
                        .fill(Color.themeLavenderSoft.opacity(0.65))
                        .frame(width: 56, height: 56)
                    MoneyIcon(.gift, size: 26, color: Color.deepNavy)
                }

                // Title & Calm Explanation
                VStack(spacing: 6) {
                    Text(he ? "החיים בעיר" : "City Life")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)

                    Text(he ? "ככל שתמשיך לתעד את ההוצאות שלך, מדי פעם תיפתח מתנה חדשה לעיר — דמות, חפץ או משהו קטן שיכניס בה עוד חיים."
                            : "The more consistently you track your expenses, the more often a new gift will appear in your city — a character, an object, or a small detail that brings it to life.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 6)
                }

                Divider().background(Color.borderSubtle).padding(.horizontal, 6)

                // Minimalist Progress Gauge
                VStack(spacing: 10) {
                    Text(countdownTitle(daysRemaining: progress.daysRemaining, isReady: progress.isReady))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)

                    // 7-day Progress Bar
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            let isDone = dayIndex < progress.daysElapsed
                            let isCurrent = dayIndex == progress.daysElapsed

                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .fill(isDone ? Color.primaryBlue : (isCurrent ? Color.primaryBlue.opacity(0.35) : Color.borderSubtle.opacity(0.6)))
                                .frame(height: 6)
                        }
                    }
                    .padding(.horizontal, 4)

                    Text(he ? "\(progress.daysElapsed) מתוך \(progress.totalCycleDays) ימים"
                            : "\(progress.daysElapsed) of \(progress.totalCycleDays) days")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textMuted)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.025), radius: 6, y: 2)

            // Living in City Section (only shown if user already has companions in the city)
            if !renderedOwnedOptions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(he ? "כבר בעיר" : "In Your City")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)

                    ForEach(renderedOwnedOptions) { option in
                        HStack(spacing: 12) {
                            hero(option, size: 36)
                            Text(title(option))
                                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Spacer()
                        }
                        .padding(10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    public var renderedOwnedOptions: [ProgressRewardOption] {
        CityProgressEngine.shared.allCatalogOptions.filter { option in
            unlockedEnrichments.contains { $0.isApplied && $0.itemId == option.id }
        }
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
                Text(title(option)).font(cardTitleFont)
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
            Text(title).font(actionButtonFont).multilineTextAlignment(.center)
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
