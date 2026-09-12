import SwiftUI
import UIKit

// MARK: - Story model and authored timing

enum RecapEditorialShot: Equatable, Identifiable {
    case opening, total, activity, district, insight(MonthlyRecapDynamicInsight), portrait
    var id: String {
        switch self {
        case .opening: "opening"
        case .total: "total"
        case .activity: "activity"
        case .district: "district"
        case .insight(let insight): insight.id
        case .portrait: "portrait"
        }
    }
    var duration: Double {
        switch self {
        case .opening: 4.4
        case .total: 5.2
        case .activity: 4.2
        case .district: 5.0
        case .insight: 5.4
        case .portrait: 8.0
        }
    }
    static func sequence(for recap: MonthlyRecap) -> [Self] {
        [.opening, .total, .activity, .district] + recap.dynamicInsights.prefix(2).map { .insight($0) } + [.portrait]
    }
}

/// Manual stories: the timeline directs a shot, never advances it or delays navigation.
public struct MonthlyRecapSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicType
    @EnvironmentObject private var l10n: LocalizationManager
    let recap: MonthlyRecap
    var onNavigateToCity: ((Date) -> Void)?
    @State private var index = 0
    @State private var time = 0.0
    @State private var outgoing: RecapEditorialShot?
    @State private var outgoingTime = 0.0
    @State private var sharedPortrait: RecapShareItem?
    @State private var shareFailed = false
    private var shots: [RecapEditorialShot] { RecapEditorialShot.sequence(for: recap) }
    private var shot: RecapEditorialShot { shots[index] }
    private var he: Bool { l10n.language == .hebrew }
    private var still: Bool { reduceMotion || voiceOver }

    public init(recap: MonthlyRecap, onNavigateToCity: ((Date) -> Void)? = nil) {
        self.recap = recap
        self.onNavigateToCity = onNavigateToCity
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                // ── Canvas — fills edge to edge ─────────────────────────
                ZStack {
                    if let outgoing, time < 0.55, !still {
                        RecapSceneFrame(shot: outgoing, recap: recap, time: outgoingTime,
                                        he: he, currency: l10n.baseCurrency.symbol)
                            .accessibilityHidden(true)
                    }
                    RecapSceneFrame(shot: shot, recap: recap, time: still ? shot.duration : time,
                                    he: he, currency: l10n.baseCurrency.symbol)
                        .clipShape(RecapSceneAperture(progress: outgoing == nil || still ? 1 : min(1, time / 0.55), shot: shot))
                }
                .clipped()
                .ignoresSafeArea()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(RecapEditorialCopy(shot: shot, recap: recap, he: he, currency: l10n.baseCurrency.symbol).accessible)
                .contentShape(Rectangle())
                .onTapGesture { point in navigate(point.x >= proxy.size.width / 2 ? 1 : -1) }
                .gesture(DragGesture(minimumDistance: 35).onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    navigate(value.translation.width < 0 ? 1 : -1)
                })

                // ── Accessibility large-type caption ────────────────────
                if dynamicType.isAccessibilitySize {
                    VStack {
                        Spacer()
                        ScrollView {
                            Text(RecapEditorialCopy(shot: shot, recap: recap, he: he, currency: l10n.baseCurrency.symbol).accessible)
                                .font(.body).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24)
                        }.frame(maxHeight: 150).background(.ultraThinMaterial)
                    }
                }

                // ── Header overlay ──────────────────────────────────────
                VStack {
                    header(topInset: proxy.safeAreaInsets.top)
                    Spacer()
                }

                // ── Footer overlay ──────────────────────────────────────
                VStack {
                    Spacer()
                    footer(bottomInset: proxy.safeAreaInsets.bottom)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .environment(\.layoutDirection, he ? .rightToLeft : .leftToRight)
        .task(id: index) {
            time = still ? shot.duration : 0
            let clock = ContinuousClock()
            var previous = clock.now
            while time < shot.duration, !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
                let now = clock.now
                let delta = previous.duration(to: now)
                previous = now
                guard scenePhase == .active else { continue }
                time = min(shot.duration, time + Double(delta.components.seconds) + Double(delta.components.attoseconds) / 1e18)
            }
            outgoing = nil
        }
        .onChange(of: still) { _, enabled in if enabled { time = shot.duration; outgoing = nil } }
        .accessibilityAction(named: Text(he ? "הבא" : "Next")) { navigate(1) }
        .accessibilityAction(named: Text(he ? "הקודם" : "Previous")) { navigate(-1) }
        .sheet(item: $sharedPortrait) { item in RecapActivitySheet(image: item.image) }
        .alert(he ? "התמונה לא נוצרה" : "Couldn't create the portrait", isPresented: $shareFailed) {
            Button(he ? "אישור" : "OK", role: .cancel) { }
        } message: { Text(he ? "אפשר לנסות לשתף שוב." : "Please try sharing again.") }
    }

    private var windowTopInset: CGFloat {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = scene.windows.first(where: { $0.isKeyWindow }) {
            return window.safeAreaInsets.top
        }
        return 54
    }

    private var windowBottomInset: CGFloat {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = scene.windows.first(where: { $0.isKeyWindow }) {
            return window.safeAreaInsets.bottom
        }
        return 34
    }

    private func header(topInset: CGFloat) -> some View {
        let effectiveTop = max(topInset, windowTopInset, 54)
        return VStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(shots.indices, id: \.self) { step in
                    Capsule().fill(step <= index ? Color.deepNavy.opacity(0.85) : Color.deepNavy.opacity(0.18)).frame(height: 2.5)
                }
            }
            HStack {
                Text("SPENT").font(.appFont(14, weight: .black)).tracking(2)
                Spacer()
                Text(String(format: "%02d / %02d", index + 1, shots.count))
                    .font(.appFont(13, weight: .medium)).monospacedDigit()
                    .accessibilityLabel(he ? "שוט \(index + 1) מתוך \(shots.count)" : "Scene \(index + 1) of \(shots.count)")
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Color.deepNavy.opacity(0.08), in: Circle())
                }.accessibilityLabel(he ? "סגירה" : "Close")
            }
        }
        .foregroundStyle(Color.deepNavy)
        .padding(.horizontal, 20)
        .padding(.top, effectiveTop + 8)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func footer(bottomInset: CGFloat) -> some View {
        let effectiveBottom = max(bottomInset, windowBottomInset, 34)
        return HStack(spacing: 12) {
            Button { navigate(-1) } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.deepNavy)
                    .frame(width: 44, height: 44)
                    .background(Color.white, in: Circle())
            }
            .disabled(index == 0).opacity(index == 0 ? 0.25 : 1)
            .accessibilityLabel(he ? "הקודם" : "Previous")

            Spacer(minLength: 8)

            if shot == .portrait {
                Button { share() } label: {
                    Label(he ? "שיתוף" : "Share", systemImage: "square.and.arrow.up")
                        .font(.appFont(15, weight: .semibold))
                        .foregroundStyle(Color.deepNavy)
                        .padding(.horizontal, 18)
                        .frame(height: 46)
                        .background(Color.white, in: Capsule())
                }
                .opacity(time >= 6.5 || still ? 1 : 0)
                .disabled(time < 6.5 && !still)
            } else {
                Text(he ? "הקשה להמשך" : "Tap to continue")
                    .font(.appFont(12, weight: .semibold))
                    .foregroundStyle(Color.deepNavy.opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white, in: Capsule())
            }

            Button {
                if shot == .portrait { dismiss() } else { navigate(1) }
            } label: {
                Text(shot == .portrait ? (he ? "סיום" : "Done") : (he ? "הבא" : "Next"))
                    .font(.appFont(15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 22)
                    .frame(height: 46)
                    .background(Color.deepNavy, in: Capsule())
            }
        }
        .buttonStyle(.plain)
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 20)
        .padding(.bottom, effectiveBottom + 8)
    }

    private func navigate(_ offset: Int) {
        let next = index + offset
        guard shots.indices.contains(next) else { return }
        outgoing = shot
        outgoingTime = still ? shot.duration : time
        time = 0
        index = next
        Haptics.impact(.light)
    }

    @MainActor private func share() {
        let frame = RecapSceneFrame(shot: .portrait, recap: recap, time: 8.0, he: he, currency: l10n.baseCurrency.symbol, export: true)
            .frame(width: 390, height: 844).environment(\.layoutDirection, he ? .rightToLeft : .leftToRight)
        let renderer = ImageRenderer(content: frame)
        renderer.scale = 3
        renderer.isOpaque = true
        if let image = renderer.uiImage { sharedPortrait = RecapShareItem(image: image) } else { shareFailed = true }
    }
}

private struct RecapShareItem: Identifiable { let id = UUID(); let image: UIImage }
private struct RecapActivitySheet: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [image], applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

// MARK: - Pure timeline (also used for the exact exported final frame)

struct RecapBeat {
    let time: Double
    func progress(_ start: Double, _ duration: Double = 0.5) -> CGFloat {
        CGFloat(min(1, max(0, (time - start) / duration)))
    }
    func ease(_ start: Double, _ duration: Double = 0.5) -> CGFloat {
        let x = progress(start, duration); return 1 - pow(1 - x, 3)
    }
}

private struct RecapSceneAperture: Shape {
    var progress: Double
    let shot: RecapEditorialShot
    func path(in rect: CGRect) -> Path {
        let p = CGFloat(progress)
        switch shot {
        case .district:
            let side = max(rect.width, rect.height) * 2 * p
            return Path(ellipseIn: CGRect(x: rect.midX - side / 2, y: rect.height * 0.64 - side / 2, width: side, height: side))
        case .activity:
            return Path(CGRect(x: rect.midX * (1-p), y: 0, width: rect.width * p, height: rect.height))
        default:
            return Path(CGRect(x: 0, y: rect.height * (1-p), width: rect.width, height: rect.height * p))
        }
    }
}

struct RecapEditorialCopy {
    let shot: RecapEditorialShot
    let recap: MonthlyRecap
    let he: Bool
    let currency: String
    func money(_ value: Double) -> String { currency + value.formatted(.number.precision(.fractionLength(0))) }
    var month: String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: he ? "he_IL" : "en_US"); f.dateFormat = "MMMM"
        return f.string(from: recap.date)
    }
    var year: String { String(Calendar(identifier: .gregorian).component(.year, from: recap.date)) }
    var hero: String {
        switch shot {
        case .opening: return he ? month : month.uppercased()
        case .total: return money(recap.totalSpent)
        case .activity: return String(recap.transactionCount)
        case .district: return recap.biggestDistrict.map { he ? $0.category.shortName(for: .hebrew) : $0.category.shortNameEn } ?? (he ? "מקום\nלהתחלות" : "Room to\nbegin")
        case .portrait: return he ? "זה היה\n\(month) שלך." : "That was\nyour \(month)."
        case .insight(let insight):
            switch insight.type {
            case .merchantRepeat: return insight.merchant ?? ""
            case .biggestPurchase: return money(insight.primaryValue)
            case .biggestDay:
                let f = DateFormatter(); f.locale = Locale(identifier: he ? "he_IL" : "en_US"); f.dateFormat = "d MMM"
                return f.string(from: insight.date ?? recap.date)
            case .monthChange, .categoryChange: return (insight.primaryValue < 0 ? "−" : "+") + String(Int(abs(insight.primaryValue).rounded())) + "%"
            case .weekendRhythm: return he ? "סוף\nהשבוע." : "The\nweekend."
            }
        }
    }
    var statement: String {
        switch shot {
        case .opening: return he ? "החודש שלך ב־SPENT" : "YOUR MONTH IN SPENT"
        case .total: return he ? "זה הסכום שעבר בעיר החודש." : "What passed through your city this month."
        case .activity: return he ? (recap.transactionCount == 1 ? "רכישה אחת החודש" : "רכישות החודש") : (recap.transactionCount == 1 ? "purchase this month" : "purchases this month")
        case .district: return recap.biggestDistrict == nil ? (he ? "העיר הייתה שקטה החודש." : "A quiet month in your city.") : (he ? "הרובע הכי גדול שלך" : "YOUR BIGGEST DISTRICT")
        case .portrait: return money(recap.totalSpent) + " · " + String(recap.transactionCount) + (he ? (recap.transactionCount == 1 ? " רכישה" : " רכישות") : (recap.transactionCount == 1 ? " purchase" : " purchases"))
        case .insight(let i):
            switch i.type {
            case .merchantRepeat: return he ? "יש מקום שחזרת אליו\nשוב ושוב." : "One place kept\ncalling you back."
            case .biggestPurchase: return he ? "רכישה אחת בלטה\nמעל כולן." : "One purchase stood\nabove the rest."
            case .biggestDay: return he ? "יום אחד שינה\nאת הקצב." : "One day picked\nup the pace."
            case .monthChange: return he ? (i.primaryValue < 0 ? "החודש עבר בעיר\nפחות כסף." : "החודש עבר בעיר\nיותר כסף.") : (i.primaryValue < 0 ? "Less spending.\nA little more space." : "More spending.\nA fuller skyline.")
            case .categoryChange: return (he ? i.category?.shortName(for: .hebrew) : i.category?.shortNameEn).map { name in he ? "\(name).\n\(i.primaryValue < 0 ? "פחות" : "יותר") מקום החודש." : "\(name) took up\n\(i.primaryValue < 0 ? "less" : "more") space." } ?? ""
            case .weekendRhythm: return he ? "העיר התעוררה בעיקר ב…" : "The city came alive on…"
            }
        }
    }
    var detail: String {
        switch shot {
        case .opening: return year
        case .activity: return he ? "כל רכישה הוסיפה אור." : "Every purchase added a little light."
        case .district:
            guard let d = recap.biggestDistrict, recap.totalSpent > 0 else { return "" }
            return money(d.amount) + " · " + String(Int((d.amount / recap.totalSpent * 100).rounded())) + (he ? "% מהחודש" : "% of the month")
        case .portrait:
            let districtText: String = recap.biggestDistrict.map { d in
                he ? "הרובע המוביל: \(d.category.shortName(for: .hebrew))" : "Top: \(d.category.shortNameEn)"
            } ?? ""
            let compText: String = recap.comparisonVsPrevMonth.map { comp in
                let pct = Int(comp.percentChange.rounded())
                let dir = comp.isDecrease ? (he ? "פחות" : "less") : (he ? "יותר" : "more")
                let name = he ? comp.prevMonthNameHe : comp.prevMonthNameEn
                return he ? "\(pct)% \(dir) מ\(name)" : "\(pct)% \(dir) than \(name)"
            } ?? ""
            let merchantText: String = recap.mostRepeatedStop.map { m in
                he ? "\(m.merchantName) \(m.visitCount) פעמים" : "\(m.merchantName) \(m.visitCount) visits"
            } ?? ""
            let parts = [districtText, compText, merchantText].filter { !$0.isEmpty }
            return parts.isEmpty
                ? (he ? "גם לשקט יש מקום בעיר." : "There is room for quiet, too.")
                : parts.joined(separator: ". ")
        case .total: return ""
        case .insight(let i):
            switch i.type {
            case .merchantRepeat: return "\(i.count) " + (he ? "פעמים החודש." : "visits this month.")
            case .biggestPurchase: return i.merchant?.isEmpty == false ? i.merchant! : ((he ? i.category?.shortName(for: .hebrew) : i.category?.shortNameEn) ?? "")
            case .biggestDay: return money(i.primaryValue) + " · \(i.count) " + (he ? "רכישות לא קבועות" : "non-recurring purchases")
            case .monthChange, .categoryChange:
                let f = DateFormatter(); f.locale = Locale(identifier: he ? "he_IL" : "en_US"); f.dateFormat = "MMMM"
                return (he ? "לעומת " : "Compared with ") + f.string(from: i.date ?? recap.date)
            case .weekendRhythm: return "\(Int(i.primaryValue.rounded()))% " + (he ? "מהרכישות היו בשישי ובשבת." : "of purchases fell on Friday and Saturday.")
            }
        }
    }
    var accessible: String { [hero, statement, detail].filter { !$0.isEmpty }.joined(separator: ". ") }
}

// MARK: - Poster compositions, deliberately distinct from one another

struct RecapSceneFrame: View {
    let shot: RecapEditorialShot
    let recap: MonthlyRecap
    let time: Double
    let he: Bool
    let currency: String
    var export = false
    private var beat: RecapBeat { .init(time: time) }
    private var copy: RecapEditorialCopy { .init(shot: shot, recap: recap, he: he, currency: currency) }
    // Editorial colors come from the onboarding posters, independent of category chart colors.
    private var accent: Color {
        switch shot {
        case .activity: .violetBlue
        case .district: .orangeRed
        case .insight(let insight):
            switch insight.type {
            case .merchantRepeat, .biggestPurchase: .orangeRed
            case .biggestDay, .monthChange: .babyBlue
            case .categoryChange, .weekendRhythm: .luckyGreen
            }
        default: .babyBlue
        }
    }
    private let W: CGFloat = 390
    private let H: CGFloat = 844

    var body: some View {
        GeometryReader { proxy in
            let scale = max(proxy.size.width / W, proxy.size.height / H)
            canvas.frame(width: W, height: H)
                .scaleEffect(scale)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .background(background)
        .background(Color.appBackground)
    }
    private var background: Color {
        switch shot {
        case .opening, .portrait: .warmCream
        case .total: .neonLime
        case .activity: .babyBlue
        case .district: .warmCream
        case .insight(let insight):
            switch insight.type {
            case .merchantRepeat, .biggestDay: .white
            case .biggestPurchase: .babyBlue
            case .monthChange: .warmCream
            case .categoryChange, .weekendRhythm: .neonLime
            }
        }
    }
    private var canvas: some View {
        ZStack(alignment: .topLeading) {
            background
            switch shot {
            case .opening: opening
            case .total: total
            case .activity: activity
            case .district: district
            case .insight(let insight): dynamic(insight)
            case .portrait: portrait
            }
            if export {
                Text("SPENT  /  \(copy.year)").font(.appFont(13, weight: .black)).tracking(2)
                    .position(x: 98, y: 38)
            }
        }
        .foregroundStyle(Color.deepNavy)
        .frame(width: W, height: H)
        .environment(\.layoutDirection, .leftToRight)
    }
    private var textAlignment: TextAlignment { .leading }
    private var alignment: Alignment { .leading }
    private var hAlignment: HorizontalAlignment { .leading }
    private func text(_ value: String, size: CGFloat, at start: Double, width: CGFloat = 338, hero: Bool = false) -> some View {
        Text(value).font(.appFont(size, weight: hero ? .heavy : .medium))
            .tracking(hero ? (he ? -1 : -1.8) : 0)
            .multilineTextAlignment(textAlignment)
            .lineLimit(hero && (shot == .total || shot == .activity) ? 1 : (hero ? 2 : 3)).minimumScaleFactor(hero ? 0.48 : 0.75)
            .frame(width: width, alignment: alignment)
            .fixedSize(horizontal: false, vertical: true)
            .offset(y: (1 - beat.ease(start, 0.55)) * (hero ? 25 : 14))
            .mask(Rectangle().scaleEffect(y: hero ? beat.ease(start, 0.55) : 1, anchor: .bottom))
            .opacity(hero ? 1 : Double(beat.ease(start, 0.4)))
            .clipped()
            .environment(\.layoutDirection, he ? .rightToLeft : .leftToRight)
    }
    private var opening: some View {
        ZStack(alignment: .topLeading) {
            RecapPosterRays().stroke(Color.jetBlack, style: StrokeStyle(lineWidth: 2.8, lineCap: .round)).frame(width: 320, height: 320)
                .offset(x: 230 - 45 * beat.ease(0.5, 1.8), y: -70)
                .opacity(Double(beat.progress(0.5, 0.3)))

            VStack(alignment: hAlignment, spacing: 10) {
                text(copy.hero, size: he ? 74 : 88, at: 1.0, width: 358, hero: true)
                text(copy.year + " · " + copy.statement, size: 14, at: 1.8)
            }
            .frame(width: 358, alignment: alignment)
            .offset(x: 20, y: 180)

            RecapSkyline(beat: beat, start: 2.3, lights: 3.2, accent: accent, quiet: recap.transactionCount == 0)
                .frame(width: 280, height: 160).offset(x: 84, y: 510)
            RecapRoad(progress: beat.ease(2.3, 0.6), color: .deepNavy).frame(width: W, height: 3).offset(y: 672)
        }.frame(width: W, height: H, alignment: .topLeading)
    }
    private var total: some View {
        ZStack(alignment: .topLeading) {
            RecapSkyline(beat: beat, start: 0.6, lights: 3.5, accent: accent, quiet: recap.transactionCount == 0)
                .frame(width: 390, height: 220).offset(x: 0, y: 450)

            VStack(alignment: hAlignment, spacing: 12) {
                text(copy.hero, size: he ? 74 : 84, at: 1.9, hero: true)
                    .scaleEffect(0.96 + 0.04 * beat.ease(1.9))
                text(copy.statement, size: 22, at: 3.0)
            }
            .frame(width: 338, alignment: alignment)
            .offset(x: 26, y: 175)
        }.frame(width: W, height: H, alignment: .topLeading)
    }
    private var activity: some View {
        ZStack(alignment: .topLeading) {
            // Skyscraper bleeding off the right and bottom edges
            RecapFacade(fill: .violetBlue)
                .frame(width: 350, height: 620)
                .offset(x: 88, y: 310)

            RecapWindowGrid(rows: 8, columns: 5, lit: min(40, recap.transactionCount), beat: beat, start: 1.4, wave: 0.1, light: .white)
                .frame(width: 260, height: 440)
                .offset(x: 120, y: 375)

            VStack(alignment: hAlignment, spacing: 8) {
                text(copy.hero, size: 68, at: 0.5, width: 338, hero: true)
                text(copy.statement, size: 24, at: 2.1, width: 338)
                text(recap.transactionCount == 0 ? (he ? "החלונות מחכים לרגע הבא." : "Windows waiting for the next moment.") : copy.detail,
                     size: 16, at: 2.7, width: 338)
            }
            .frame(width: 338, alignment: alignment)
            .offset(x: 26, y: 105)
        }.frame(width: W, height: H, alignment: .topLeading)
    }
    private var district: some View {
        ZStack(alignment: .topLeading) {
            // District storefront/building enters dynamically from the side
            RecapDistrictBuilding(category: recap.biggestDistrict?.category, accent: accent, beat: beat, start: 0.7)
                .frame(width: 320, height: 380)
                .offset(x: -30, y: 440)

            VStack(alignment: hAlignment, spacing: 10) {
                text(copy.statement, size: 16, at: 2.3)
                text(copy.hero, size: he ? 54 : 64, at: 2.8, hero: true)
                text(copy.detail, size: 20, at: 3.5)
            }
            .frame(width: 338, alignment: alignment)
            .offset(x: 26, y: 115)
        }.frame(width: W, height: H, alignment: .topLeading)
    }
    @ViewBuilder private func dynamic(_ insight: MonthlyRecapDynamicInsight) -> some View {
        Group {
        switch insight.type {
        case .merchantRepeat:
            ZStack(alignment: .topLeading) {
                RecapRoad(progress: beat.ease(0.1), color: .deepNavy).frame(width: 450, height: 3).offset(x: -20, y: 652)
                ForEach(0..<4) { item in
                    RecapStorefront(accent: accent, sign: "", beat: beat, start: 0.6 + [0, 0.5, 0.8, 1.0][item])
                        .frame(width: 125, height: 140)
                        .offset(x: CGFloat(item) * 115 - 40 + (1 - beat.ease(0.6 + [0, 0.5, 0.8, 1.0][item])) * 200, y: 510)
                }
                VStack(alignment: hAlignment, spacing: 10) {
                    text(copy.statement, size: 24, at: 2.0)
                    text(copy.hero, size: he ? 54 : 64, at: 2.5, hero: true)
                    text(copy.detail, size: 19, at: 3.2)
                }
                .frame(width: 338, alignment: alignment)
                .offset(x: 26, y: 110)
            }
        case .biggestPurchase:
            ZStack(alignment: .topLeading) {
                RecapSkyline(beat: beat, start: 0.2, lights: 4.5, accent: accent, quiet: false)
                    .frame(width: 260, height: 120).offset(x: -8, y: 540)
                RecapBuilding(accent: accent, rows: 9, beat: beat, lights: 4.5)
                    .frame(width: 96, height: 320 * beat.ease(1.0, 1.5))
                    .position(x: 320, y: 670 - 320 * beat.ease(1, 1.5) / 2)
                VStack(alignment: hAlignment, spacing: 10) {
                    text(copy.statement, size: 24, at: 2.5)
                    text(copy.hero, size: he ? 58 : 68, at: 3.0, hero: true)
                    text(copy.detail, size: 18, at: 3.6, width: 338)
                }
                .frame(width: 338, alignment: alignment)
                .offset(x: 26, y: 110)
            }
        case .biggestDay:
            ZStack(alignment: .topLeading) {
                RecapStreet(beat: beat, accent: accent).frame(width: W, height: 180).offset(y: 490)
                VStack(alignment: hAlignment, spacing: 10) {
                    text(copy.statement, size: 24, at: 2.2)
                    text(copy.hero, size: he ? 58 : 68, at: 2.6, hero: true)
                    text(copy.detail, size: 19, at: 3.3)
                }
                .frame(width: 338, alignment: alignment)
                .offset(x: 26, y: 110)
            }
        case .monthChange:
            ZStack(alignment: .topLeading) {
                RecapSkyline(beat: beat, start: 0.1, lights: 20, accent: .warmCream, quiet: false)
                    .frame(width: 330, height: 150).offset(x: 34 - 400 * beat.ease(1.1, 0.7), y: 520)
                RecapSkyline(beat: beat, start: 1.3, lights: 4.5, accent: accent, quiet: insight.primaryValue < 0)
                    .frame(width: 350, height: 180).offset(x: 26 + 390 * (1 - beat.ease(1.3, 0.7)), y: 490)
                VStack(alignment: hAlignment, spacing: 10) {
                    text(copy.statement, size: 24, at: 2.0)
                    text(copy.hero, size: he ? 64 : 76, at: 2.6, hero: true)
                    text(copy.detail, size: 19, at: 3.3)
                }
                .frame(width: 338, alignment: alignment)
                .offset(x: 26, y: 110)
            }
        case .categoryChange:
            ZStack(alignment: .topLeading) {
                RecapRoad(progress: beat.ease(0.3, 1.5), color: accent)
                    .frame(width: 480, height: insight.primaryValue > 0 ? 22 + 70 * beat.ease(1.0, 0.8) : 92 - 70 * beat.ease(1.0, 0.8))
                    .rotationEffect(.degrees(-24)).offset(x: -40, y: 550)
                RecapTree(accent: accent).frame(width: 80, height: 120).offset(x: 250, y: 430)
                    .opacity(Double(beat.ease(0.4)))
                VStack(alignment: hAlignment, spacing: 10) {
                    text(copy.statement, size: 24, at: 2.0)
                    text(copy.hero, size: he ? 58 : 68, at: 2.6, hero: true)
                    text(copy.detail, size: 19, at: 3.3)
                }
                .frame(width: 338, alignment: alignment)
                .offset(x: 26, y: 110)
            }
        case .weekendRhythm:
            ZStack(alignment: .topLeading) {
                RecapPark(beat: beat, start: 0.5).frame(width: 330, height: 200).offset(x: 44, y: 470)
                VStack(alignment: hAlignment, spacing: 10) {
                    text(copy.statement, size: 22, at: 1.6)
                    text(copy.hero, size: he ? 54 : 64, at: 2.2, hero: true)
                    text(copy.detail, size: 18, at: 3.2)
                }
                .frame(width: 338, alignment: alignment)
                .offset(x: 26, y: 110)
            }
        }
        }.frame(width: W, height: H, alignment: .topLeading)
    }
    private var portrait: some View {
        ZStack(alignment: .topLeading) {
            // Onboarding-style drawn emphasis, carried by the original reveal beat.
            RecapPosterRays().stroke(Color.jetBlack, style: StrokeStyle(lineWidth: 2.8, lineCap: .round)).frame(width: 220, height: 220)
                .offset(x: 260, y: -20).opacity(Double(beat.ease(2.1)))

            // City illustration (anchored in lower section, ends cleanly above footer)
            ZStack(alignment: .bottom) {
                RecapSkyline(beat: beat, start: 1.2, lights: 5.2, accent: accent, quiet: recap.transactionCount == 0)
                    .frame(width: 300, height: 200).offset(x: 14, y: -38)
                RecapStorefront(accent: Color.warmCream, sign: "SPENT", beat: beat, start: -0.7)
                    .frame(width: 125, height: 130).offset(x: -64, y: -20)
                RecapPark(beat: beat, start: 2.1).frame(width: 175, height: 115).offset(x: 100, y: 22)
            }
            .frame(width: 340, height: 250)
            .scaleEffect(1.65 - 0.65 * beat.ease(0, 2.7), anchor: .bottom)
            .offset(x: 24, y: 430)

            VStack(alignment: hAlignment, spacing: 8) {
                // ── Hero title ──
                text(copy.hero, size: 40, at: 3.2, hero: true)

                // ── Row 1: total spend · transaction count ──
                text(
                    currency + recap.totalSpent.formatted(.number.precision(.fractionLength(0))) +
                    " · " + String(recap.transactionCount) +
                    (he
                        ? (recap.transactionCount == 1 ? " רכישה" : " רכישות")
                        : (recap.transactionCount == 1 ? " purchase" : " purchases")),
                    size: 17, at: 3.7, width: 280
                )

                // ── Row 2: budget remaining OR biggest spending day ──
                if let remaining = recap.remainingBudget, remaining > 0 {
                    let line = he
                        ? "נותרו \(currency)\(Int(remaining.rounded())) מהתקציב החודשי"
                        : "\(currency)\(Int(remaining.rounded())) left of monthly budget"
                    text(line, size: 14, at: 4.1, width: 280)
                } else if let day = recap.biggestSpendingDay {
                    let line = he
                        ? "יום שיא: \(day.formattedDateHe) · \(currency)\(Int(day.amount.rounded()))"
                        : "Peak day: \(day.formattedDateEn) · \(currency)\(Int(day.amount.rounded()))"
                    text(line, size: 14, at: 4.1, width: 280)
                }

                // ── Row 3: biggest district + share-of-total ──
                if let d = recap.biggestDistrict, recap.totalSpent > 0 {
                    let pct = Int((d.amount / recap.totalSpent * 100).rounded())
                    let line = he
                        ? "רובע מוביל: \(d.nameHe) · \(pct)% · \(currency)\(Int(d.amount.rounded()))"
                        : "Top district: \(d.nameEn) · \(pct)% · \(currency)\(Int(d.amount.rounded()))"
                    text(line, size: 14, at: 4.5, width: 280)
                }

                // ── Row 4: month-over-month comparison ──
                if let comp = recap.comparisonVsPrevMonth {
                    let sign = comp.isDecrease ? "↓" : "↑"
                    let dir = comp.isDecrease ? (he ? "פחות" : "less") : (he ? "יותר" : "more")
                    let pct = Int(comp.percentChange.rounded())
                    let name = he ? comp.prevMonthNameHe : comp.prevMonthNameEn
                    let line = he
                        ? "\(sign) \(pct)% \(dir) מ\(name)"
                        : "\(sign) \(pct)% \(dir) than \(name)"
                    text(line, size: 14, at: 5.0, width: 280)
                }

                // ── Row 5: top repeated merchant OR busiest district fallback ──
                if let m = recap.mostRepeatedStop {
                    let line = he
                        ? "\(m.merchantName) — \(m.visitCount) ביקורים החודש"
                        : "\(m.merchantName) — \(m.visitCount) visits this month"
                    text(line, size: 14, at: 5.5, width: 280)
                } else if let b = recap.busiestDistrict, b.category != recap.biggestDistrict?.category {
                    let line = he
                        ? "הכי פעיל: \(b.nameHe) · \(b.transactionCount) עסקאות"
                        : "Most active: \(b.nameEn) · \(b.transactionCount) transactions"
                    text(line, size: 14, at: 5.5, width: 280)
                }
            }
            .frame(width: 290, alignment: alignment)
            .offset(x: 26, y: 130)

            // Car animation sweeps across bottom safely above footer
            RecapCar(accent: accent).frame(width: 44, height: 26)
                .offset(x: -60 + 530 * beat.progress(7.2, 0.8), y: 690)
        }.frame(width: W, height: H, alignment: .topLeading)
    }
}

// MARK: - Shared graphic city vocabulary

// Static drawing only: entrance, illumination and movement remain owned by RecapBeat.
// Matches the onboarding kit: 2.8pt round ink, shallow black side, white roof lip.
private struct RecapFacade: View {
    let fill: Color
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let lip = min(12, w * 0.12)
            let roof = min(10, h * 0.07)
            let stroke = StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)
            func polygon(_ points: [CGPoint], color: Color) {
                var path = Path()
                path.addLines(points)
                path.closeSubpath()
                context.fill(path, with: .color(color))
                context.stroke(path, with: .color(.jetBlack), style: stroke)
            }
            polygon([CGPoint(x: w - lip, y: roof), CGPoint(x: w, y: 0),
                     CGPoint(x: w, y: h - roof), CGPoint(x: w - lip, y: h)], color: .jetBlack)
            let face = Path(roundedRect: CGRect(x: 0, y: roof, width: w - lip, height: max(0, h - roof)), cornerRadius: 2)
            context.fill(face, with: .color(fill))
            context.stroke(face, with: .color(.jetBlack), style: stroke)
            polygon([CGPoint(x: 0, y: roof), CGPoint(x: lip, y: 0),
                     CGPoint(x: w, y: 0), CGPoint(x: w - lip, y: roof)], color: .white)
        }
    }
}

private struct RecapGround: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines([
            CGPoint(x: rect.minX, y: rect.height * 0.40),
            CGPoint(x: rect.width * 0.44, y: 0),
            CGPoint(x: rect.maxX, y: rect.height * 0.35),
            CGPoint(x: rect.width * 0.85, y: rect.height * 0.85),
            CGPoint(x: rect.width * 0.28, y: rect.maxY)
        ])
        path.closeSubpath()
        return path
    }
}

private struct RecapPosterRays: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (start, end) in [(CGPoint(x: 0.20, y: 0.66), CGPoint(x: 0.20, y: 0.59)),
                             (CGPoint(x: 0.28, y: 0.70), CGPoint(x: 0.33, y: 0.65))] {
            path.move(to: CGPoint(x: start.x * rect.width, y: start.y * rect.height))
            path.addLine(to: CGPoint(x: end.x * rect.width, y: end.y * rect.height))
        }
        return path
    }
}

private struct RecapWindowGrid: View {
    let rows: Int
    let columns: Int
    let lit: Int
    let beat: RecapBeat
    let start: Double
    var wave: Double = 0.09
    var light: Color = .white
    var body: some View {
        VStack(spacing: 9) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(0..<columns, id: \.self) { column in
                        let on = row * columns + column < lit
                        RoundedRectangle(cornerRadius: 1)
                            .fill(on ? light.opacity(0.16 + 0.84 * Double(beat.ease(start + Double(row + column) * wave, 0.2))) : Color.jetBlack)
                            .background(Color.jetBlack, in: RoundedRectangle(cornerRadius: 1))
                            .overlay(RoundedRectangle(cornerRadius: 1).stroke(Color.jetBlack, lineWidth: 2.8))
                            .overlay(alignment: .topLeading) {
                                Capsule().fill(Color.white).frame(width: 2, height: 7).padding(4)
                            }
                    }
                }
            }
        }
    }
}
private struct RecapBuilding: View {
    let accent: Color
    var rows = 4
    let beat: RecapBeat
    var lights = 3.2
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .top) {
                RecapFacade(fill: accent)
                // Windows
                RecapWindowGrid(rows: rows, columns: 2, lit: rows + 1, beat: beat, start: lights)
                    .padding(.leading, g.size.width * 0.14)
                    .padding(.trailing, g.size.width * 0.26)
                    .padding(.top, g.size.height * 0.11)
                    .padding(.bottom, g.size.height * 0.22)
                Rectangle().fill(Color.violetBlue)
                    .overlay(Rectangle().stroke(Color.jetBlack, lineWidth: 2.8))
                    .frame(width: g.size.width * 0.22, height: g.size.height * 0.16)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
}
private struct RecapSkyline: View {
    let beat: RecapBeat
    let start: Double
    let lights: Double
    let accent: Color
    let quiet: Bool
    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: quiet ? 24 : 8) {
                ForEach(0..<(quiet ? 3 : 5), id: \.self) { item in
                    let fraction: CGFloat = quiet ? [0.3, 0.5, 0.35][item] : [0.35, 0.52, 0.69, 1, 0.6][item]
                    RecapBuilding(accent: item % 2 == 0 ? accent : (item == 3 ? Color.orangeRed : Color.warmCream), rows: item == 3 ? 5 : (item == 0 || quiet ? 2 : 3), beat: beat, lights: lights + Double(item) * 0.08)
                        .frame(height: geo.size.height * fraction)
                        .scaleEffect(y: beat.ease(start + Double(item) * 0.13, 0.65), anchor: .bottom)
                }
            }.frame(height: geo.size.height, alignment: .bottom)
        }
    }
}
private struct RecapStorefront: View {
    let accent: Color
    let sign: String
    let beat: RecapBeat
    let start: Double
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .bottom) {
                RecapFacade(fill: accent)
                    .padding(.top, h * 0.10)
                HStack(spacing: 0) {
                    ForEach(0..<6) { i in
                        Rectangle().fill(i.isMultiple(of: 2) ? Color.orangeRed : Color.warmCream)
                            .overlay(Rectangle().stroke(Color.jetBlack, lineWidth: 2.8))
                    }
                }
                .frame(height: h * 0.13)
                .offset(y: -(h * 0.40))
                Text(sign).font(.appFont(w * 0.10, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.4)
                    .foregroundStyle(Color.jetBlack)
                    .frame(width: w * 0.78, height: h * 0.16)
                    .background(Color.warmCream)
                    .overlay(Rectangle().stroke(Color.jetBlack, lineWidth: 2.8))
                    .offset(y: -(h * 0.64))
                HStack(alignment: .top, spacing: w * 0.18) {
                    Rectangle().fill(Color.jetBlack)
                        .frame(width: w * 0.25, height: h * 0.29)
                    Rectangle().fill(Color.white)
                        .overlay(Rectangle().stroke(Color.jetBlack, lineWidth: 2.8))
                        .frame(width: w * 0.27, height: h * 0.19)
                }
                .frame(maxWidth: .infinity)
            }
            .scaleEffect(y: beat.ease(start, 0.6), anchor: .bottom)
            .frame(width: w, height: h)
        }
    }
}
private struct RecapDistrictBuilding: View {
    let category: SpendingCategory?
    let accent: Color
    let beat: RecapBeat
    let start: Double
    var body: some View {
        ZStack {
            if category == .housing || category == .subscriptions || category == .finance {
                RecapBuilding(accent: accent, rows: 5, beat: beat, lights: 4.1).padding(.horizontal, 42)
                    .scaleEffect(y: beat.ease(start, 0.8), anchor: .bottom)
            } else if category == .transport {
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 4).fill(accent).frame(height: 22)
                    HStack { Rectangle().frame(width: 5); Spacer(); Rectangle().frame(width: 5) }.frame(height: 120)
                    RecapCar(accent: accent).frame(width: 125, height: 64).offset(x: 22)
                    RecapRoad(progress: 1, color: .deepNavy).frame(height: 4)
                }.padding(.top, 34).scaleEffect(y: beat.ease(start, 0.8), anchor: .bottom)
            } else if category == nil {
                RecapPark(beat: beat, start: start)
            } else {
                RecapStorefront(accent: accent, sign: category == .entertainment ? "CINEMA" : "", beat: beat, start: start)
                    .padding(.top, 40)
                if let category {
                    MoneyIcon(category.iconType, size: 55, color: accent)
                        .offset(x: -45, y: 62).opacity(Double(beat.ease(1.5)))
                }
            }
        }
    }
}
private struct RecapTree: View {
    let accent: Color
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            Canvas { context, _ in
                let stroke = StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)
                let canopy = Path(ellipseIn: CGRect(x: w * 0.23, y: h * 0.04, width: w * 0.54, height: h * 0.70))
                context.fill(canopy, with: .color(accent))
                context.stroke(canopy, with: .color(.jetBlack), style: stroke)
                var branches = Path()
                branches.move(to: CGPoint(x: w * 0.5, y: h))
                branches.addLine(to: CGPoint(x: w * 0.5, y: h * 0.32))
                branches.move(to: CGPoint(x: w * 0.5, y: h * 0.57))
                branches.addLine(to: CGPoint(x: w * 0.36, y: h * 0.45))
                context.stroke(branches, with: .color(.jetBlack), style: stroke)
            }.frame(width: w, height: h)
        }
    }
}
private struct RecapPark: View {
    let beat: RecapBeat
    let start: Double
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                // Flat planted island, like the onboarding target poster.
                RecapGround().fill(Color.neonLime)
                    .overlay(RecapGround().stroke(Color.jetBlack, style: StrokeStyle(lineWidth: 2.8, lineJoin: .round)))
                    .frame(width: w * 0.88, height: h * 0.26).offset(y: h * 0.36)
                // Path stripe
                RoundedRectangle(cornerRadius: 2).fill(Color.warmCream)
                    .frame(width: w * 0.10, height: h * 0.24).offset(x: w * 0.04, y: h * 0.30)
                // Bench
                ZStack(alignment: .bottom) {
                    Rectangle().fill(Color.orangeRed).frame(width: w * 0.16, height: 5)
                    HStack(spacing: w * 0.08) {
                        Rectangle().fill(Color.jetBlack).frame(width: 2, height: h * 0.055)
                        Rectangle().fill(Color.jetBlack).frame(width: 2, height: h * 0.055)
                    }
                }.offset(x: w * 0.10, y: h * 0.24)
                // Small left tree
                RecapTree(accent: Color.luckyGreen)
                    .frame(width: w * 0.20, height: h * 0.50).offset(x: -w * 0.28, y: h * 0.16)
                // Tall centre tree
                RecapTree(accent: Color.luckyGreen)
                    .frame(width: w * 0.30, height: h * 0.80).offset(x: w * 0.08)
                // Medium right tree
                RecapTree(accent: Color.luckyGreen)
                    .frame(width: w * 0.22, height: h * 0.58).offset(x: w * 0.29, y: h * 0.10)
            }
            .frame(width: w, height: h)
            .scaleEffect(0.92 + 0.08 * beat.ease(start))
            .opacity(Double(beat.ease(start)))
        }
    }
}
private struct RecapRoad: View {
    let progress: CGFloat
    let color: Color
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(color).scaleEffect(x: progress, anchor: .leading)
                if progress > 0.3 {
                    HStack(spacing: 8) {
                        ForEach(0..<22) { _ in
                            Rectangle().fill(Color.white.opacity(0.30))
                                .frame(width: 14, height: max(1, g.size.height * 0.24))
                        }
                    }.opacity(Double(min(1, (progress - 0.3) / 0.3)))
                }
            }
        }
    }
}
private struct RecapCar: View {
    let accent: Color
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .bottom) {
                // Lower body
                RoundedRectangle(cornerRadius: h * 0.18)
                    .fill(accent)
                    .overlay(RoundedRectangle(cornerRadius: h * 0.18).stroke(Color.deepNavy, lineWidth: 2))
                    .frame(width: w, height: h * 0.52)
                // Cabin roof
                UnevenRoundedRectangle(topLeadingRadius: h * 0.22, bottomLeadingRadius: 0,
                                       bottomTrailingRadius: 0, topTrailingRadius: h * 0.22)
                    .fill(accent)
                    .overlay(UnevenRoundedRectangle(topLeadingRadius: h * 0.22, bottomLeadingRadius: 0,
                                                   bottomTrailingRadius: 0, topTrailingRadius: h * 0.22)
                                .stroke(Color.deepNavy, lineWidth: 2))
                    .frame(width: w * 0.55, height: h * 0.36).offset(y: -(h * 0.50))
                // Windshield
                UnevenRoundedRectangle(topLeadingRadius: h * 0.12, bottomLeadingRadius: 0,
                                       bottomTrailingRadius: 0, topTrailingRadius: h * 0.12)
                    .fill(Color.babyBlue)
                    .frame(width: w * 0.42, height: h * 0.26).offset(y: -(h * 0.53))
                // Wheels — solid discs with hub dots
                HStack(spacing: w * 0.34) {
                    ForEach(0..<2) { _ in
                        ZStack {
                            Circle().fill(Color.deepNavy).frame(width: h * 0.38, height: h * 0.38)
                            Circle().fill(Color.warmCream).frame(width: h * 0.14, height: h * 0.14)
                        }
                    }
                }.padding(.horizontal, w * 0.08).offset(y: h * 0.24)
            }.frame(width: w, height: h)
        }
    }
}
private struct RecapStreet: View {
    let beat: RecapBeat
    let accent: Color
    var body: some View {
        GeometryReader { g in
            ZStack {
                RecapRoad(progress: beat.ease(0.0), color: .jetBlack).frame(height: 64).offset(y: 38)
                ForEach(0..<3) { item in
                    RecapCar(accent: accent).frame(width: 66, height: 36)
                        .offset(x: -240 + 510 * beat.progress(0.8 + Double(item) * 0.25, 0.7), y: 30 + CGFloat(item % 2) * 19)
                        .opacity(beat.time < 2.2 ? 1 : 0)
                }
                RecapStorefront(accent: accent, sign: "", beat: beat, start: 1.3).frame(width: 92, height: 104).offset(x: 100, y: -47)
            }.frame(width: g.size.width, height: g.size.height)
        }
    }
}
