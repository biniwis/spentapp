#if !SWIFT_PACKAGE
import SwiftUI
import CloudKit
import Charts

private extension Color {
    init(sharedHex: String) {
        let value = UInt32(sharedHex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0x5653E8
        self.init(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
}

/// Uses SPENT's existing editor; only destination and payer are additional.
struct SharedExpenseEditor: View {
    let space: SharedSpace
    var expense: SharedExpense?
    var body: some View {
        QuickAddSheet(
            initialCategory: expense?.category,
            initialCategoryIsExplicit: expense != nil,
            initialCurrency: CurrencyType(rawValue: space.currencyCode),
            initialMerchant: expense?.merchant,
            initialBuildingId: expense?.buildingID,
            initialDate: expense?.date ?? Date(),
            titleOverride: expense == nil ? nil : (AppLanguage.current == .hebrew ? "עריכת הוצאה" : "Edit expense"),
            sharedSpaceID: space.id,
            sharedExpenseID: expense?.id,
            onSaveWithExplicitFlag: { _, _, _, _, _, _, _, _, _ in }
        )
    }
}

// MARK: - Poster arrival
/// One small rise per beat. The page builds itself once, then holds still.
private struct SetupPosterReveal: ViewModifier {
    let phase: Int
    let step: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        let isShown = reduceMotion || phase >= step
        content
            .opacity(isShown ? 1 : 0)
            .offset(y: isShown ? 0 : 14)
    }
}

private extension View {
    func posterReveal(phase: Int, step: Int, reduceMotion: Bool) -> some View {
        modifier(SetupPosterReveal(phase: phase, step: step, reduceMotion: reduceMotion))
    }
}

/// Two equal houses on one street, a tree they share, and a nameplate the user writes.
/// The drawing kit is deliberately the same one onboarding uses, so the two read as one city.
struct SharedSpaceHeroIllustration: View {
    let isJoin: Bool
    let spaceName: String
    let isRTL: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0
    @State private var signPulse = false

    private var artboard: CGSize { CGSize(width: 320, height: 124) }
    private var presentsImmediately: Bool { reduceMotion }

    // One shared street: both houses sit on the same baseline at the same height.
    private static let baseline: CGFloat = 106
    private static let houseY: CGFloat = 58
    private static let houseWidth: CGFloat = 84
    private static let leftHouseX: CGFloat = 20
    private static let rightHouseX: CGFloat = 216
    private static let plate = CGRect(x: 94, y: 6, width: 140, height: 34)

    var body: some View {
        ZStack(alignment: .topLeading) {
            layer(1) { c in
                drawGround(&c)
                drawHouse(&c, x: Self.leftHouseX, color: .babyBlue)
                drawHouse(&c, x: Self.rightHouseX, color: .warmCream)
            }

            layer(2) { c in
                drawTree(&c)
            }

            layer(3) { c in
                drawNameplate(&c)
            }

            lettering
                .opacity(presentsImmediately || phase >= 3 ? 1 : 0)
        }
        .frame(width: artboard.width, height: artboard.height)
        .scaleEffect(signPulse ? 1.04 : 1.0)
        .animation(.spring(response: 0.32, dampingFraction: 0.6), value: signPulse)
        .animation(.easeInOut(duration: 0.3), value: isJoin)
        .accessibilityHidden(true)
        .task(id: "\(isJoin)-\(presentsImmediately)") {
            // A departed scene's build sequence must not fire into the next one.
            var transaction = SwiftUI.Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { phase = presentsImmediately ? 3 : 0 }
            guard !presentsImmediately else { return }
            for nextPhase in 1...3 {
                do { try await Task.sleep(for: .milliseconds(nextPhase == 1 ? 70 : 150)) }
                catch { return }
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.32)) { phase = nextPhase }
            }
        }
        .onChange(of: spaceName) { oldValue, newValue in
            // The street gets its name the moment the first letter lands.
            guard !newValue.isEmpty, oldValue.isEmpty else { return }
            Haptics.impact(.light)
            withAnimation(.spring(response: 0.26, dampingFraction: 0.5)) { signPulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { signPulse = false }
            }
        }
    }

    // MARK: - Build beats

    private func layer(_ step: Int, _ draw: @escaping (inout GraphicsContext) -> Void) -> some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            var c = context
            c.translateBy(x: (size.width - artboard.width) / 2,
                          y: (size.height - artboard.height) / 2)
            draw(&c)
        }
        .opacity(presentsImmediately || phase >= step ? 1 : 0)
        .offset(y: presentsImmediately || phase >= step ? 0 : 10)
        .animation(.easeOut(duration: 0.32), value: phase)
    }

    // MARK: - Nameplate

    private var signText: String {
        let trimmed = spaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if isJoin { return isRTL ? "מרחב משותף" : "SHARED SPACE" }
        return isRTL ? "המרחב שלך" : "YOUR SPACE"
    }

    private var lettering: some View {
        Text(signText)
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .tracking(isRTL ? -0.4 : -0.6)
            .foregroundStyle(Color.jetBlack)
            .lineLimit(1)
            .minimumScaleFactor(0.45)
            .allowsTightening(true)
            .frame(width: Self.plate.width - 18, height: Self.plate.height - 12)
            .offset(x: Self.plate.minX + 9, y: Self.plate.minY + 6)
    }

    private func drawNameplate(_ c: inout GraphicsContext) {
        let plate = Self.plate
        // A mounted plate in the sky, not a post — the two roof lips sit at different
        // heights, so any mast would either float or cut through a facade.
        rectangle(&c, plate.minX, plate.minY, plate.width, plate.height, fill: .white, radius: 3)
        for boltX in [plate.minX + 8, plate.maxX - 8] {
            circle(&c, boltX, plate.midY, 1.6, fill: .jetBlack)
        }
    }

    // MARK: - Scene

    private func drawGround(_ c: inout GraphicsContext) {
        line(&c, [(12, Self.baseline), (308, Self.baseline)], width: 2.4)
    }

    /// Onboarding's house kit: shallow side plane, roof lip, two rows of windows, one door.
    /// `lit` flips the windows from waiting-dark to somebody-is-home.
    private func drawHouse(_ c: inout GraphicsContext, x: CGFloat, color: Color) {
        let width = Self.houseWidth
        let y = Self.houseY
        let height = Self.baseline - y
        let lit = isJoin

        polygon(&c, [(x + width, y), (x + width + 12, y - 8),
                     (x + width + 12, y + height - 8), (x + width, y + height)], fill: .jetBlack)
        rectangle(&c, x, y, width, height, fill: color, radius: 2)
        polygon(&c, [(x - 5, y), (x + 7, y - 10),
                     (x + width + 15, y - 10), (x + width + 5, y)], fill: .white)

        let windowWidth = width * 0.14
        let windowHeight = height * 0.15
        let glass: Color = lit ? .warmCream : .jetBlack
        for row in 0..<2 {
            for column in 0..<3 {
                let windowX = x + width * 0.15 + CGFloat(column) * width * 0.28
                let windowY = y + 20 + CGFloat(row) * height * 0.28
                rectangle(&c, windowX, windowY, windowWidth, windowHeight, fill: glass, radius: 1)
                line(&c, [(windowX + 3, windowY + 3),
                          (windowX + 3, windowY + windowHeight * 0.6)],
                     color: lit ? Color.jetBlack : Color.white, width: 1.6)
            }
        }
        rectangle(&c, x + width * 0.4, y + height * 0.75, width * 0.22, height * 0.25,
                  fill: .violetBlue, radius: 1)
    }

    private func drawTree(_ c: inout GraphicsContext) {
        var local = c
        let size: CGFloat = 0.54
        local.translateBy(x: 164, y: Self.baseline)
        local.scaleBy(x: size, y: size)
        line(&local, [(0, 0), (0, -67)], width: 3)
        let canopy = Path(ellipseIn: CGRect(x: -20, y: -85, width: 40, height: 60))
        local.fill(canopy, with: .color(.luckyGreen))
        local.stroke(canopy, with: .color(ink), style: stroke)
        line(&local, [(0, -19), (0, -61)])
        line(&local, [(0, -39), (-10, -49)])
    }

    // MARK: - Drawing kit

    private var ink: Color { .jetBlack }
    private let stroke = StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)

    private func rectangle(_ c: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat,
                           _ w: CGFloat, _ h: CGFloat, fill: Color, radius: CGFloat = 0) {
        let path = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius)
        c.fill(path, with: .color(fill))
        c.stroke(path, with: .color(ink), style: stroke)
    }

    private func circle(_ c: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, fill: Color) {
        let path = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        c.fill(path, with: .color(fill))
        c.stroke(path, with: .color(ink), style: stroke)
    }

    private func polygon(_ c: inout GraphicsContext, _ points: [(CGFloat, CGFloat)],
                         fill: Color, outlined: Bool = true) {
        let path = path(points, closed: true)
        c.fill(path, with: .color(fill))
        if outlined { c.stroke(path, with: .color(ink), style: stroke) }
    }

    private func line(_ c: inout GraphicsContext, _ points: [(CGFloat, CGFloat)],
                      color: Color = .jetBlack, width: CGFloat = 2.4) {
        c.stroke(path(points), with: .color(color),
                 style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func path(_ points: [(CGFloat, CGFloat)], closed: Bool = false) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: CGPoint(x: first.0, y: first.1))
            for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.0, y: point.1)) }
            if closed { path.closeSubpath() }
        }
    }
}

#Preview("Shared space poster") {
    ZStack {
        Color.warmCream.ignoresSafeArea()
        SharedSpacesSetupView()
    }
    .environmentObject(LocalizationManager.shared)
}

struct SharedSpacesSetupView: View {
    @ObservedObject private var store = SharedWorkspaceStore.shared
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 42
    @Namespace private var toggleNamespace

    private enum SetupTab: Int, CaseIterable {
        case create = 0
        case join = 1
    }

    private enum SetupField: Hashable {
        case spaceName
        case memberName
        case inviteLink
        case monthlyTarget
    }

    /// Keeps a number's digits in reading order inside a right-to-left layout.
    ///
    /// Mirrors the identical modifier in `OnboardingWizardView`, which is private to that
    /// file. Widening it there would be the better home, but the personal onboarding
    /// screen is meant to stay untouched in this phase.
    private struct NumericLTRField: ViewModifier {
        @ViewBuilder
        func body(content: Content) -> some View {
            if #available(iOS 26.0, *) {
                content
                    .environment(\.layoutDirection, .leftToRight)
                    .multilineTextAlignment(.leading)
                    .multilineTextAlignment(strategy: .layoutBased)
                    .writingDirection(strategy: .layoutBased)
            } else {
                content
                    .environment(\.layoutDirection, .leftToRight)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    /// The create flow's two stages. Everything typed stays in `@State` on this view, so
    /// moving between them cannot lose a draft — the view is never torn down, and nothing
    /// reaches CloudKit until the final button.
    private enum CreateStep: Int, Hashable, CaseIterable {
        case identity
        case monthlyTarget
    }

    @State private var selectedTab: SetupTab = .create
    @State private var createStep: CreateStep = .identity
    @State private var name = ""
    @State private var memberName = ""
    @State private var url = ""
    @State private var budgetInputText = ""
    @State private var selectedCurrency: CurrencyType = LocalizationManager.shared.baseCurrency
    @State private var selectedStyle: CityMapStyle = .urban
    @State private var showCurrencyPicker = false
    @State private var showMapStylePicker = false
    @State private var entrancePhase: Int = 0
    @FocusState private var focusedField: SetupField?

    // MARK: - Shared poster space (same world as onboarding)

    private var isHebrew: Bool { AppLanguage.current == .hebrew }
    private var posterInk: Color { .jetBlack }

    /// The canvas shifts with the tab, the way onboarding shifts it per step.
    private var posterCanvas: Color {
        selectedTab == .create ? Color.warmCream : Color.neonLime
    }

    private var pageAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .easeInOut(duration: 0.3)
    }

    // MARK: - One screen, no scrolling

    /// Short screens (SE, mini) get a smaller drawing and a tighter title so the
    /// whole poster still lands above the fold.
    private var isShortScreen: Bool {
        UIScreen.main.bounds.height < 700 || dynamicTypeSize.isAccessibilitySize
    }

    private var heroHeight: CGFloat { isShortScreen ? 100 : 124 }
    private var titleBase: CGFloat { isShortScreen ? min(titleSize, 36) : titleSize }

    /// The target step carries a longer sentence than the identity step, so it gets a
    /// smaller base and lets the sentence wrap rather than overflow on an SE.
    private var posterTitle: (text: String, size: CGFloat) {
        guard selectedTab == .create else {
            return (store.text("מצטרפים\nלמרחב קיים", "Join an\nexisting Space"), titleBase)
        }
        switch createStep {
        case .identity:
            return (store.text("פותחים\nמרחב משותף", "Start a\nShared Space"), titleBase)
        case .monthlyTarget:
            let base: CGFloat = isShortScreen ? 27 : 31
            return (store.text("כמה תרצו\nלהוציא יחד\nבחודש?", "How much will you\nspend together\nthis month?"), base)
        }
    }

    /// The target, in the space's own currency, or nil when what was typed is not a
    /// usable amount. Conversion goes through `SharedMoney` so the currency's own digit
    /// count is honoured — never a hardcoded ×100.
    private var monthlyTargetMinor: Int64? {
        let digits = OnboardingWizardView.sanitizedBudgetDigits(budgetInputText)
        guard !digits.isEmpty else { return nil }
        return try? SharedMoney.minor(digits, currency: selectedCurrency.rawValue)
    }

    /// The drawing is authored on a fixed 320pt artboard and scaled down to whatever
    /// width the device actually has, so the composition never crops.
    private var heroBand: some View {
        GeometryReader { geometry in
            let scale = min(1.0, geometry.size.width / 320)
            SharedSpaceHeroIllustration(
                isJoin: selectedTab == .join,
                spaceName: name,
                isRTL: isHebrew
            )
            .scaleEffect(scale)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .frame(height: heroHeight)
        .padding(.horizontal, 24)
    }

    // MARK: - Onboarding's single graphic action

    private func primaryAction(title: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard isEnabled else { return }
            Haptics.impact(.medium)
            action()
        } label: {
            Text(title)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: isShortScreen ? 50 : 54)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(posterInk)
                )
                .opacity(isEnabled ? 1.0 : 0.38)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .bouncyPress(scale: (reduceMotion || !isEnabled) ? 1 : 0.97)
    }

    /// Fields are printed on the canvas with a baseline rule, exactly like onboarding's inputs.
    private func underlineField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: SetupField,
        size: CGFloat,
        design: Font.Design = .rounded,
        submitLabel: SubmitLabel = .next
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(posterInk.opacity(0.7))

            TextField(placeholder, text: text)
                .font(.system(size: size, weight: .bold, design: design))
                .foregroundStyle(posterInk)
                .tint(posterInk)
                .multilineTextAlignment(.leading)
                .focused($focusedField, equals: field)
                .submitLabel(submitLabel)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(field != .inviteLink)
                .padding(.vertical, 5)
                .onChange(of: text.wrappedValue) { _, _ in clearSetupError() }

            Rectangle()
                .fill(posterInk.opacity(focusedField == field ? 1 : 0.35))
                .frame(height: focusedField == field ? 2 : 1)
        }
    }

    // MARK: - Build

    /// The canvas sits behind the scroll view, so it never sees a tap that lands on the
    /// content. Both surfaces route here, and the guard keeps an unfocused field unfocused.
    private func dismissKeyboard() {
        guard focusedField != nil else { return }
        focusedField = nil
    }

    /// A fresh attempt starts from a clean slate, so a stale complaint never greets
    /// someone who has already fixed the link.
    private func clearSetupError() {
        withAnimation(.easeOut(duration: 0.2)) { store.clearSetupError() }
    }

    var body: some View {
        ZStack {
            posterCanvas
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }

            VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Flat poster header ──
                    HStack {
                        Spacer(minLength: 0)
                        Button {
                            Haptics.impact(.light)
                            focusedField = nil
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(posterInk)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .bouncyPress(scale: 0.92)
                        .accessibilityLabel(store.text("סגירה", "Close"))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 2)
                    .posterReveal(phase: entrancePhase, step: 1, reduceMotion: reduceMotion)

                    // ── Create / Join capsule, 44pt targets ──
                    HStack(spacing: 0) {
                        tabButton(.create, title: store.text("יצירת מרחב", "Create Space"), showsDot: false)
                        tabButton(.join, title: store.text("הצטרפות", "Join Space"), showsDot: store.invitation != nil)
                    }
                    .padding(3)
                    .background(
                        Capsule()
                            .fill(posterInk.opacity(0.06))
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                    .posterReveal(phase: entrancePhase, step: 2, reduceMotion: reduceMotion)

                    // ── The two shared buildings, and the name you are giving them ──
                    heroBand
                        .padding(.top, 10)
                        .posterReveal(phase: entrancePhase, step: 3, reduceMotion: reduceMotion)

                    // ── Editorial title: the one thing the poster is saying ──
                    Text(posterTitle.text)
                        .font(.system(size: posterTitle.size, weight: .heavy, design: .rounded))
                        .tracking(isHebrew ? -0.5 : -0.8)
                        .foregroundStyle(posterInk)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .posterReveal(phase: entrancePhase, step: 4, reduceMotion: reduceMotion)

                    if selectedTab == .create {
                        createProgress
                            .padding(.top, 14)
                            .posterReveal(phase: entrancePhase, step: 4, reduceMotion: reduceMotion)
                    }

                    // ── Active tab content ──
                    ZStack {
                        if selectedTab == .create {
                            createSpaceContent
                                .transition(.asymmetric(
                                    insertion: .offset(x: transitionDirection * 30).combined(with: .opacity),
                                    removal: .offset(x: -transitionDirection * 20).combined(with: .opacity)
                                ))
                        } else {
                            joinSpaceContent
                                .transition(.asymmetric(
                                    insertion: .offset(x: transitionDirection * 30).combined(with: .opacity),
                                    removal: .offset(x: -transitionDirection * 20).combined(with: .opacity)
                                ))
                        }
                    }
                    .padding(.top, 26)
                    .id(createStep)
                    .animation(pageAnimation, value: selectedTab)
                    .animation(pageAnimation, value: createStep)
                    .animation(.easeOut(duration: 0.2), value: store.setupError)
                    .posterReveal(phase: entrancePhase, step: 5, reduceMotion: reduceMotion)

                    Spacer(minLength: 4)
                }
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }
            }
            .scrollDismissesKeyboard(.interactively)

            // The action lives on the canvas, outside the scroll — a keyboard can never hide it.
            bottomActionBar
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .background(posterCanvas)
            }
            .disabled(store.busy)
            .overlay {
                if store.busy {
                    ZStack {
                        Color.black.opacity(0.18).ignoresSafeArea()
                        ProgressView()
                            .padding(20)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 10)
                    }
                }
            }
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerModal(selectedCurrency: $selectedCurrency)
                    .environmentObject(l10n)
            }
            .sheet(isPresented: $showMapStylePicker) {
                MapStylePickerView(
                    draft: $selectedStyle,
                    isHebrew: isHebrew,
                    onClose: { showMapStylePicker = false },
                    onSelect: { chosen in
                        selectedStyle = chosen
                        showMapStylePicker = false
                    }
                )
                .environmentObject(l10n)
            }
        }
        .presentationBackground(posterCanvas)
        .animation(pageAnimation, value: selectedTab)
        // The root app can only show this alert while the sheet is closed, so the sheet
        // shows it itself. An alert inside a sheet's own content is ordinary and does not
        // fight the sheet that presents it.
        .alert(l10n.language == .hebrew ? "מרחב משותף" : "Shared space", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } })) {
                Button(l10n.language == .hebrew ? "סגירה" : "Dismiss") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
        .task {
            // Poster arrival: the page builds itself once, then holds still.
            var transaction = SwiftUI.Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { entrancePhase = reduceMotion ? 5 : 0 }
            guard !reduceMotion else { return }
            for nextPhase in 1...5 {
                do { try await Task.sleep(for: .milliseconds(nextPhase == 1 ? 60 : 55)) }
                catch { return }
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) { entrancePhase = nextPhase }
            }
        }
    }

    private var transitionDirection: CGFloat { isHebrew ? -1 : 1 }

    private func tabButton(_ tab: SetupTab, title: String, showsDot: Bool) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            focusedField = nil
            withAnimation(pageAnimation) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? posterInk : posterInk.opacity(0.5))
                if showsDot {
                    Circle()
                        .fill(posterInk)
                        .frame(width: 5.5, height: 5.5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.white)
                        .matchedGeometryEffect(id: "activeTabPill", in: toggleNamespace)
                        .shadow(color: Color.black.opacity(0.06), radius: 1.5, y: 1)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Two quiet dots, the way onboarding shows where you are without announcing a form.
    private var createProgress: some View {
        HStack(spacing: 7) {
            ForEach(CreateStep.allCases, id: \.self) { step in
                Circle()
                    .fill(step == createStep ? posterInk : posterInk.opacity(0.22))
                    .frame(width: step == createStep ? 9 : 7, height: step == createStep ? 9 : 7)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: createStep)
        .accessibilityElement()
        .accessibilityLabel(store.text(
            "שלב \(createStep.rawValue + 1) מתוך \(CreateStep.allCases.count)",
            "Step \(createStep.rawValue + 1) of \(CreateStep.allCases.count)"))
    }

    private var createSpaceContent: some View {
        Group {
            switch createStep {
            case .identity: createIdentityStep
            case .monthlyTarget: createTargetStep
            }
        }
    }

    // MARK: - Create, step one: who this space is

    private var createIdentityStep: some View {
        VStack(alignment: .leading, spacing: isShortScreen ? 14 : 18) {
            underlineField(
                title: store.text("שם המרחב", "Space Name"),
                placeholder: store.text("הבית שלנו", "Our Home"),
                text: $name,
                field: .spaceName,
                size: isShortScreen ? 24 : 26
            )

            underlineField(
                title: store.text("השם שלך", "Your Name"),
                placeholder: store.text("איך קוראים לך?", "What's your name?"),
                text: $memberName,
                field: .memberName,
                size: isShortScreen ? 19 : 21
            )

            // City style stays here on step one. Currency moved to the target, where the
            // number it has to scale actually appears.
            choiceInstrument(
                title: store.text("סגנון עיר", "City Style"),
                value: selectedStyle.title(isHebrew: isHebrew),
                chipColor: MoneyCityTheme.spentGreenSoft,
                chipText: nil,
                isOpen: showMapStylePicker
            ) {
                Haptics.selection()
                focusedField = nil
                showMapStylePicker = true
            }

            #if DEBUG
            if store.database == nil {
                Button {
                    Haptics.selection()
                    store.perform {
                        try await store.startDemo()
                        dismiss()
                    }
                } label: {
                    Text(store.text("התנסות במרחב הדגמה", "Try Demo Space"))
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(posterInk.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 32)
                }
                .buttonStyle(.plain)
            }
            #endif
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Create, step two: what the space is aiming for each month

    private var createTargetStep: some View {
        VStack(alignment: .leading, spacing: isShortScreen ? 12 : 16) {
            backToIdentity

            Text(store.text("הגדירו יעד להוצאות המשותפות. הוא יעזור לעיר שלכם לשקף איך החודש מתקדם.",
                            "Set a target for your shared spending. It lets your city show how the month is going."))
                .font(.system(size: isShortScreen ? 15 : 16, weight: .medium, design: .rounded))
                .foregroundStyle(posterInk.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text(store.text("יעד הוצאה חודשי", "Monthly spending target"))
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(posterInk.opacity(0.7))

                HStack(alignment: .center, spacing: 8) {
                    Text(SharedMoney.symbol(selectedCurrency.rawValue))
                        .font(.system(size: isShortScreen ? 26 : 30, weight: .bold, design: .rounded))
                        .foregroundStyle(posterInk)

                    TextField("8,000", text: $budgetInputText)
                        .font(.system(size: isShortScreen ? 32 : 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(posterInk)
                        .tint(posterInk)
                        .keyboardType(.asciiCapableNumberPad)
                        .focused($focusedField, equals: .monthlyTarget)
                        .modifier(NumericLTRField())
                        .onSubmit { focusedField = nil }
                        .onChange(of: budgetInputText) { _, newValue in
                            // Digits only, whole currency units — the same rule the
                            // personal onboarding step uses.
                            let sanitized = OnboardingWizardView.sanitizedBudgetDigits(newValue)
                            if newValue != sanitized { budgetInputText = sanitized }
                            clearSetupError()
                        }
                        .accessibilityLabel(store.text("יעד הוצאה חודשי", "Monthly spending target"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // Numbers stay left-to-right even in Hebrew, or the digits reorder.
                .environment(\.layoutDirection, .leftToRight)
                .padding(.vertical, 4)

                Rectangle()
                    .fill(posterInk.opacity(focusedField == .monthlyTarget ? 1 : 0.35))
                    .frame(height: focusedField == .monthlyTarget ? 2 : 1)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { targetPresets }
                VStack(alignment: .leading, spacing: 4) { targetPresets }
            }

            choiceInstrument(
                title: store.text("מטבע", "Currency"),
                value: selectedCurrency.rawValue,
                chipColor: MoneyCityTheme.babyBlue,
                chipText: selectedCurrency.symbol,
                isOpen: showCurrencyPicker
            ) {
                Haptics.selection()
                focusedField = nil
                showCurrencyPicker = true
            }

            Text(store.text("אפשר לשנות את היעד אחר כך", "You can change your target later"))
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(posterInk.opacity(0.7))

            if let setupError = store.setupError {
                Text(setupError)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(posterInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(posterInk, lineWidth: 1.5)
                    )
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
    }

    /// The figures come from the currency, so ₪5,000 and ¥500 are the same suggestion
    /// rather than shekels spelled out in a different currency.
    private var targetPresets: some View {
        ForEach(SharedMoney.monthlyTargetPresets(currency: selectedCurrency.rawValue), id: \.self) { amount in
            let isSelected = monthlyTargetMinor == amount
            return Button {
                Haptics.selection()
                budgetInputText = String(Int64(SharedMoney.major(amount, currency: selectedCurrency.rawValue)))
                focusedField = nil
            } label: {
                Text(SharedMoney.formattedMajor(amount, currency: selectedCurrency.rawValue))
                    .font(.system(.subheadline, design: .rounded, weight: isSelected ? .bold : .regular))
                    .fixedSize()
                    .foregroundStyle(posterInk)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 44)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(isSelected ? posterInk : .clear).frame(height: 2)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.text("\(SharedMoney.symbol(selectedCurrency.rawValue))\(SharedMoney.formattedMajor(amount, currency: selectedCurrency.rawValue))",
                                           "\(SharedMoney.formattedMajor(amount, currency: selectedCurrency.rawValue)) \(selectedCurrency.rawValue)"))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    private var backToIdentity: some View {
        Button {
            Haptics.selection()
            focusedField = nil
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { createStep = .identity }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 12, weight: .bold))
                Text(store.text("חזרה", "Back"))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            .foregroundStyle(posterInk)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .bouncyPress(scale: 0.94)
        .accessibilityLabel(store.text("חזרה לפרטי המרחב", "Back to space details"))
    }

    private func choiceInstrument(
        title: String,
        value: String,
        chipColor: Color,
        chipText: String?,
        isOpen: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(posterInk.opacity(0.7))

                HStack(spacing: 8) {
                    if let chipText {
                        Text(chipText)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(posterInk)
                            .frame(width: 26, height: 26)
                            .background(chipColor, in: Circle())
                    } else {
                        MoneyIcon(.globe, size: 15, color: posterInk)
                            .frame(width: 26, height: 26)
                            .background(chipColor, in: Circle())
                    }

                    Text(value)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(posterInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(posterInk.opacity(0.45))
                }
                .frame(minHeight: 34)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(posterInk.opacity(isOpen ? 1 : 0.35))
                        .frame(height: isOpen ? 2 : 1)
                }
                .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .bouncyPress(scale: 0.97)
    }

    private var joinSpaceContent: some View {
        VStack(alignment: .leading, spacing: isShortScreen ? 14 : 18) {
            if store.invitation != nil {
                // A pending invitation is a real object, so it keeps a card — the poster is behind it.
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(MoneyCityTheme.spentGreenSoft)
                            .frame(width: 40, height: 40)
                        MoneyIcon(.mail, size: 20, color: MoneyCityTheme.brandPrimary)
                    }
                    Text(store.text("התקבלה הזמנה למרחב", "Invitation ready"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(posterInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 24)
            } else {
                underlineField(
                    title: store.text("קישור הזמנה", "Invitation Link"),
                    placeholder: "https://www.icloud.com/share/...",
                    text: $url,
                    field: .inviteLink,
                    size: 14,
                    design: .monospaced,
                    submitLabel: .go
                )
                .padding(.horizontal, 24)
            }

            underlineField(
                title: store.text("השם שלך", "Your Name"),
                placeholder: store.text("איך קוראים לך?", "What's your name?"),
                text: $memberName,
                field: .memberName,
                size: isShortScreen ? 19 : 21
            )
            .padding(.horizontal, 24)

            // A link that does not exist is the most common thing to get wrong here, and
            // it deserves a line on the poster — not an alert over the whole app.
            if let setupError = store.setupError {
                Text(setupError)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(posterInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(posterInk, lineWidth: 1.5)
                    )
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .offset(y: 6)))
            }
        }
    }

    // MARK: - The single pinned action

    @ViewBuilder
    private var bottomActionBar: some View {
        if selectedTab == .create {
            switch createStep {
            case .identity:
                // Local draft only. Nothing here reaches CloudKit — the space does not
                // exist until the last button on the second step.
                primaryAction(
                    title: store.text("המשך ליעד", "Continue to target"),
                    isEnabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                               !memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    focusedField = nil
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { createStep = .monthlyTarget }
                }
            case .monthlyTarget:
                primaryAction(
                    title: store.text("יצירת המרחב", "Create Space"),
                    isEnabled: monthlyTargetMinor != nil
                ) {
                    store.perform {
                        // Re-parse inside the call rather than trusting the button state:
                        // the store stays the boundary that decides what is valid.
                        guard let target = try? SharedMoney.minor(
                            OnboardingWizardView.sanitizedBudgetDigits(budgetInputText),
                            currency: selectedCurrency.rawValue) else { throw SharedLedgerError.invalidAmount }
                        try await store.create(
                            name: name,
                            memberName: memberName,
                            currency: selectedCurrency.rawValue,
                            mapStyle: selectedStyle.rawValue,
                            monthlyBudgetMinor: target
                        )
                        // Reached only once create() returned, so activeSpaceID is real.
                        dismiss()
                    }
                }
            }
        } else if store.invitation != nil {
            primaryAction(
                title: store.text("הצטרפות למרחב", "Join Space"),
                isEnabled: !memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                store.perform {
                    // A vanished invitation used to return silently: no dismiss, no error,
                    // no feedback — the button simply did nothing.
                    guard let pending = store.invitation else { throw SharedLedgerError.wrongInvitation }
                    try await store.accept(pending, memberName: memberName)
                    dismiss()
                }
            }
        } else {
            primaryAction(
                title: store.text("הצטרפות למרחב", "Join Space"),
                isEnabled: !memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                           !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                focusedField = nil
                store.perform {
                    let metadata = try await store.metadata(for: url)
                    try await store.accept(metadata, memberName: memberName)
                    dismiss()
                }
            }
        }
    }

    private var existingSpacesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.text("המרחבים שלך", "Your Spaces"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                ForEach(store.spaces) { space in
                    let isSelected = store.activeSpaceID == space.id
                    Button {
                        Haptics.selection()
                        store.select(space.id)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            MoneyIcon(.users, size: 18, color: MoneyCityTheme.brandPrimary)
                                .frame(width: 36, height: 36)
                                .background(MoneyCityTheme.babyBlue.opacity(0.6), in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(space.name)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                Text(space.currencyCode)
                                    .font(.system(size: 12, weight: .medium, design: .default))
                                    .foregroundColor(Color.textSecondary)
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(MoneyCityTheme.brandPrimary)
                            }
                        }
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

public struct CurrencyPickerModal: View {
    @Binding var selectedCurrency: CurrencyType
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l10n.isHebrew ? "בחירת מטבע" : "Select Currency")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        Text(l10n.isHebrew ? "המטבע ישמש את כל חברי המרחב" : "This currency will be used by all space members")
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundColor(Color.textSecondary)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.deepNavy)
                            .frame(width: 32, height: 32)
                            .background(Color.white, in: Circle())
                            .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(CurrencyType.allCases) { curr in
                            Button {
                                Haptics.selection()
                                selectedCurrency = curr
                                dismiss()
                            } label: {
                                HStack(spacing: 16) {
                                    Text(curr.symbol)
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.deepNavy)
                                        .frame(width: 44, height: 44)
                                        .background(MoneyCityTheme.babyBlue.opacity(0.5), in: Circle())

                                    Text(l10n.language == .hebrew ? curr.displayNameHebrew : curr.displayNameEnglish)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color.deepNavy)
                                        .lineLimit(1)

                                    Spacer()

                                    if selectedCurrency == curr {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(MoneyCityTheme.brandPrimary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedCurrency == curr ? MoneyCityTheme.spentGreenSoft : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: Color.black.opacity(0.035), radius: 6, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
            }
        }
        .presentationBackground(Color.appBackground)
        .presentationDetents([.medium, .fraction(0.8)])
        .presentationDragIndicator(.visible)
    }
}

/// Edits a shared space's monthly target.
///
/// Its own small sheet rather than `BudgetSheet`, which edits the personal
/// `monthly_budget` and per-category limits. The currency is shown but not editable here:
/// it is the space's ledger currency, fixed when the space was created, and changing it
/// would mean reinterpreting every amount already recorded in the space.
///
/// Takes the space explicitly instead of reading the active scope, so it can never be
/// opened against a different space than the one the reader is looking at.
struct SharedTargetEditorSheet: View {
    let space: SharedSpace

    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var errorText: String?
    @FocusState private var isAmountFocused: Bool

    private var currencyCode: String { space.currencyCode }

    private var parsedMinor: Int64? {
        guard !amountText.isEmpty else { return nil }
        return try? SharedMoney.minor(amountText, currency: currencyCode)
    }

    private var canSave: Bool { parsedMinor != nil }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.language == .hebrew ? "יעד חודשי" : "Monthly Target")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textSecondary)

                    HStack(spacing: 8) {
                        TextField(l10n.language == .hebrew ? "0" : "0", text: $amountText)
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.leading)
                            .focused($isAmountFocused)
                            .onChange(of: amountText) { _, _ in errorText = nil }
                            .accessibilityLabel(l10n.language == .hebrew ? "סכום היעד החודשי" : "Monthly target amount")
                        Text(SharedMoney.symbol(currencyCode))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(MoneyCityTheme.brandPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.borderSubtle, lineWidth: 1)
                    )
                }

                HStack(spacing: 6) {
                    MoneyIcon(.globe, size: 13, color: Color.textSecondary)
                    Text(l10n.language == .hebrew
                         ? "המטבע של המרחב · \(currencyCode)"
                         : "Space currency · \(currencyCode)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                }

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                }

                Spacer()

                if space.monthlyTarget != nil {
                    Button {
                        save(nil)
                    } label: {
                        Text(l10n.language == .hebrew ? "הסרת היעד" : "Remove Target")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(Color.appBackground)
            .navigationTitle(l10n.language == .hebrew ? "יעד חודשי" : "Monthly Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.language == .hebrew ? "ביטול" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.language == .hebrew ? "שמירה" : "Save") { save(parsedMinor) }
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.height(430)])
        .onAppear {
            // Open on the current value, in major units so the field reads "8000" and not
            // the minor-unit "800000" a user would have to convert in their head.
            if let existing = space.monthlyTarget {
                amountText = String(Int64(SharedMoney.major(existing, currency: currencyCode)))
            }
            isAmountFocused = true
        }
    }

    /// Writes through the store, so the change queues locally and the profile reflects it
    /// immediately rather than after a sync round trip.
    private func save(_ minor: Int64?) {
        do {
            try SharedWorkspaceStore.shared.setMonthlyBudget(minor, for: space.id)
            Haptics.impact(.light)
            dismiss()
        } catch {
            errorText = (error as? SharedLedgerError)?.errorDescription
                ?? (l10n.language == .hebrew ? "לא ניתן לשמור" : "Could not save")
        }
    }
}

struct SharedSpaceManagement: View {
    let space: SharedSpace
    @ObservedObject private var store = SharedWorkspaceStore.shared
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var share: SharingItem?
    @State private var showTargetEditor = false
    @State private var showPreInvite = false
    @State private var showDeleteConfirm = false
    @State private var showLeaveConfirm = false
    @State private var showStopSharingConfirm = false
    @State private var showConflictResolution = false
    private struct SharingItem: Identifiable { let id = UUID(); let share: CKShare }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Header
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(space.name)
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Text(store.text("ניהול מרחב משותף · \(space.currencyCode)", "Manage Shared Space · \(space.currencyCode)"))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(Color.textSecondary)
                        }
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.deepNavy)
                                .frame(width: 32, height: 32)
                                .background(Color.white, in: Circle())
                                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Conflict Review Card
                    let spaceConflicts = store.conflicts.filter { $0.spaceID == space.id }
                    if !spaceConflicts.isEmpty {
                        Button {
                            Haptics.selection()
                            showConflictResolution = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Color.orange)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(store.text("נמצאו \(spaceConflicts.count) התנגשויות עריכה", "Found \(spaceConflicts.count) Edit Conflicts"))
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.deepNavy)
                                    Text(store.text("העריכות המקומיות שלך נשמרו. לחץ להשוואה ובחירה.",
                                                    "Your local edits were saved. Tap to review and resolve."))
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(Color.textSecondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                Image(systemName: l10n.isHebrew ? "chevron.left" : "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.orange)
                            }
                            .padding(16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: Color.orange.opacity(0.06), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                        }
                        .buttonStyle(.plain)
                    }

                    // Members Card
                    let spaceMembers = store.members.filter { $0.spaceID == space.id }
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            HStack(spacing: 8) {
                                MoneyIcon(.users, size: 16, color: MoneyCityTheme.brandPrimary)
                                Text(store.text("חברי המרחב", "Space Members"))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                            }
                            Spacer()
                            Text("\(spaceMembers.count)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(MoneyCityTheme.brandPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(MoneyCityTheme.spentGreenSoft)
                                .clipShape(Capsule())
                        }

                        VStack(spacing: 10) {
                            ForEach(spaceMembers) { member in
                                let isMe = member.id == store.myMemberID(in: space.id)
                                HStack(spacing: 12) {
                                    SharedMemberMark(colorHex: member.colorHex, size: 38)
                                    Text(member.name)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.deepNavy)
                                    Spacer()
                                    if isMe {
                                        Text(store.text("את/ה", "You"))
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundColor(MoneyCityTheme.brandPrimary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(MoneyCityTheme.spentGreenSoft)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        // Invite Member Button
                        Button {
                            Haptics.impact(.light)
                            showPreInvite = true
                        } label: {
                            HStack(spacing: 8) {
                                MoneyIcon(.plusCircle, size: 16, color: MoneyCityTheme.brandPrimary)
                                Text(store.text("הזמנת חבר/ה למרחב", "Invite Member"))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(MoneyCityTheme.brandPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(MoneyCityTheme.spentGreenSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                        .disabled(store.demo)
                    }
                    .padding(18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.black.opacity(0.035), radius: 8, y: 2)
                    .padding(.horizontal, 20)

                    // Monthly Target Card
                    //
                    // Placed under the space's own details, and clickable, because the
                    // onboarding promises the target can be changed after the fact. This
                    // edits the space's `monthlyBudgetMinor` only — not currency, not
                    // members, not colours.
                    Button {
                        Haptics.selection()
                        showTargetEditor = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.themeMintSoft)
                                    .frame(width: 40, height: 40)
                                MoneyIcon(.target, size: 20, color: MoneyCityTheme.brandPrimary)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(store.text("יעד חודשי", "Monthly Target"))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                if let target = space.monthlyTarget {
                                    Text(SharedMoney.formattedMajor(target, currency: space.currencyCode)
                                         + " " + space.currencyCode)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color.deepNavy)
                                } else {
                                    Text(store.text("לא הוגדר · לחיצה להגדרה", "Not set · tap to set"))
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(Color.textSecondary)
                                }
                            }

                            Spacer()

                            Image(systemName: l10n.isHebrew ? "chevron.left" : "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.textSecondary)
                        }
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(0.035), radius: 8, y: 2)
                        .padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)

                    // Space Settings Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            MoneyIcon(.gear, size: 16, color: Color.textSecondary)
                            Text(store.text("פרטי המרחב", "Space Details"))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                        }

                        VStack(spacing: 10) {
                            HStack {
                                Text(store.text("מטבע המרחב", "Space Currency"))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.textSecondary)
                                Spacer()
                                Text(space.currencyCode)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.appBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }

                            HStack {
                                Text(store.text("סגנון עיר", "City Style"))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.textSecondary)
                                Spacer()
                                let localizedStyle = CityMapStyle(rawValue: space.mapStyle)?.title(isHebrew: l10n.isHebrew) ?? space.mapStyle
                                Text(localizedStyle)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.appBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                    .padding(18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.black.opacity(0.035), radius: 8, y: 2)
                    .padding(.horizontal, 20)

                    // Actions
                    VStack(spacing: 10) {
                        let isOwner = store.isOwner(space.id)
                        if isOwner {
                            // Stop Sharing (Owner only) - clean white card button
                            Button {
                                Haptics.impact(.medium)
                                showStopSharingConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    MoneyIcon(.lock, size: 16, color: Color.deepNavy)
                                    Text(store.text("עצירת שיתוף המרחב", "Stop Sharing Space"))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(Color.deepNavy)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: Color.black.opacity(0.035), radius: 6, y: 2)
                            }
                            .buttonStyle(.plain)

                            // Delete Space (Owner only)
                            Button(role: .destructive) {
                                Haptics.impact(.medium)
                                showDeleteConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    MoneyIcon(.trash, size: 16, color: MoneyCityTheme.destructive)
                                    Text(store.text("מחיקת המרחב לצמיתות", "Delete Shared Space"))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(MoneyCityTheme.destructive)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(MoneyCityTheme.destructive.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        } else {
                            // Leave Space (Participant only)
                            Button {
                                Haptics.impact(.medium)
                                showLeaveConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    MoneyIcon(.xmarkCircle, size: 16, color: MoneyCityTheme.destructive)
                                    Text(store.text("עזיבת המרחב", "Leave Space"))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(MoneyCityTheme.destructive)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(MoneyCityTheme.destructive.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .sheet(isPresented: $showConflictResolution) {
                SharedConflictResolutionSheet(spaceID: space.id)
                    .environmentObject(l10n)
            }
            .sheet(isPresented: $showTargetEditor) {
                SharedTargetEditorSheet(space: space)
                    .environmentObject(l10n)
            }
            .sheet(isPresented: $showPreInvite) {
                InviteMemberPreSheet(space: space) {
                    showPreInvite = false
                    store.perform {
                        try store.ensureNoPendingChanges(in: space.id)
                        share = SharingItem(share: try await store.sharingRecord(in: space.id))
                    }
                }
                .environmentObject(l10n)
            }
            .sheet(item: $share, onDismiss: { store.perform { try await store.refresh() } }) { item in
                SharedSharingController(share: item.share, container: store.cloud)
            }
            .confirmationDialog(
                store.text("עצירת שיתוף המרחב?", "Stop Sharing Space?"),
                isPresented: $showStopSharingConfirm,
                titleVisibility: .visible
            ) {
                Button(store.text("עצור שיתוף עם משתתפים", "Stop Sharing"), role: .destructive) {
                    store.perform {
                        try await store.stopSharing(in: space.id)
                    }
                }
                Button(store.text("ביטול", "Cancel"), role: .cancel) {}
            } message: {
                Text(store.text("כל המשתתפים האחרים יאבדו גישה למרחב. המרחב, העיר וכל ההוצאות יישארו אצלך בלבד ולא יימחקו.",
                                "All other members will lose access. The space, city, and expenses will remain yours and will not be deleted."))
            }
            .confirmationDialog(
                store.text("האם למחוק את המרחב לצמיתות?", "Delete Space Permanently?"),
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(store.text("מחק מרחב ונתונים", "Delete Space"), role: .destructive) {
                    store.perform {
                        try await store.deleteSpace(space.id)
                        #if !SWIFT_PACKAGE
                        if AppScopeContext.shared.activeScope.spaceID == space.id {
                            AppScopeContext.shared.selectPersonal()
                        }
                        #endif
                        dismiss()
                    }
                }
                Button(store.text("ביטול", "Cancel"), role: .cancel) {}
            } message: {
                Text(store.text("פעולה זו בלתי הפיכה ותמחק את המרחב ואת כל ההוצאות והנתונים המשותפים לצמיתות עבור כל המשתתפים. הנתונים האישיים שלך לא ייפגעו.",
                                "This cannot be undone and permanently deletes the space and all shared expenses for all members. Your personal data will not be affected."))
            }
            .confirmationDialog(
                store.text("האם לעזוב את המרחב?", "Leave Space?"),
                isPresented: $showLeaveConfirm,
                titleVisibility: .visible
            ) {
                Button(store.text("עזוב מרחב", "Leave Space"), role: .destructive) {
                    store.perform {
                        try await store.leaveSpace(space.id)
                        #if !SWIFT_PACKAGE
                        if AppScopeContext.shared.activeScope.spaceID == space.id {
                            AppScopeContext.shared.selectPersonal()
                        }
                        #endif
                        dismiss()
                    }
                }
                Button(store.text("ביטול", "Cancel"), role: .cancel) {}
            } message: {
                Text(store.text("העזיבה תסיר את השיתוף בענן ותמחק את הנתונים המשותפים ממכשיר זה בלבד. הוצאות שהזנת יישארו במרחב.",
                                "Leaving will remove your participation in iCloud and delete the shared data from this device only. Your recorded expenses will stay in the space."))
            }
        }
        .presentationBackground(Color.appBackground)
    }
}

// ── Real Conflict Resolution Sheet (SPENT Native Design) ──
public struct SharedConflictResolutionSheet: View {
    let spaceID: UUID
    @ObservedObject private var store = SharedWorkspaceStore.shared
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    private var spaceConflicts: [SharedExpenseConflict] {
        store.conflicts.filter { $0.spaceID == spaceID }
    }

    private var space: SharedSpace? {
        store.spaces.first(where: { $0.id == spaceID })
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: l10n.isHebrew ? "he_IL" : "en_US")
        f.dateFormat = "d בMMMM yyyy, HH:mm"
        return f
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.text("פתרון התנגשויות עריכה", "Resolve Edit Conflicts"))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Text(store.text("עריכות שבוצעו במקביל במכשירים שונים. בחר עבור כל עסקה איזו גרסה לשמור.",
                                            "Edits were made concurrently. Choose which version to keep for each expense."))
                                .font(.system(size: 13, weight: .medium, design: .default))
                                .foregroundColor(Color.textSecondary)
                        }
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.deepNavy)
                                .frame(width: 32, height: 32)
                                .background(Color.white, in: Circle())
                                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    if spaceConflicts.isEmpty {
                        // Empty State: All resolved
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(MoneyCityTheme.spentGreenSoft)
                                    .frame(width: 64, height: 64)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(MoneyCityTheme.spentGreen)
                            }
                            .padding(.top, 40)

                            Text(store.text("כל ההתנגשויות נפתרו!", "All conflicts resolved!"))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)

                            Text(store.text("ההוצאות במרחב מעודכנות ומסונכרנות.", "All expenses in the space are up to date and in sync."))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.textSecondary)

                            Button {
                                dismiss()
                            } label: {
                                Text(store.text("סיום", "Done"))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.deepNavy)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 40)
                            .padding(.top, 12)
                        }
                        .padding(.vertical, 30)
                    } else {
                        // Conflicts List
                        VStack(spacing: 18) {
                            ForEach(spaceConflicts) { conflict in
                                conflictCard(conflict)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
        }
        .presentationBackground(Color.appBackground)
    }

    private func conflictCard(_ conflict: SharedExpenseConflict) -> some View {
        let server = conflict.serverExpense
        let local = conflict.localExpense
        let currency = space?.currencyCode ?? server.currencyCode

        return VStack(alignment: .leading, spacing: 14) {
            // Title & Date
            HStack {
                Text(server.merchant.isEmpty ? server.category.displayName : server.merchant)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                Spacer()
                Text(dateFormatter.string(from: server.date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.textMuted)
            }

            // Comparison Grid: Server vs Local
            VStack(spacing: 10) {
                versionComparisonBox(
                    title: store.text("גרסת שרת (פעילה כעת)", "Server Version (Current)"),
                    expense: server,
                    currency: currency,
                    isServer: true
                )

                versionComparisonBox(
                    title: store.text("העריכה המקומית שלך (שנשמרה)", "Your Local Edit (Saved)"),
                    expense: local,
                    currency: currency,
                    isServer: false
                )
            }

            // Resolution Action Buttons
            HStack(spacing: 10) {
                Button {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        do {
                            try store.keepServerVersion(conflict: conflict)
                        } catch {
                            store.errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Text(store.text("השאר גרסת שרת", "Keep Server"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color.borderSubtle.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.impact(.medium)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        do {
                            try store.restoreLocalVersion(conflict: conflict)
                        } catch {
                            store.errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Text(store.text("שחזר עריכה שלי", "Restore My Edit"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color.primaryBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }

    private func versionComparisonBox(title: String, expense: SharedExpense, currency: String, isServer: Bool) -> some View {
        let payerMember = store.members.first { $0.id == expense.paidBy && $0.spaceID == spaceID }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(isServer ? Color.primaryBlue : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(isServer ? Color.primaryBlue : Color.orange)
                }
                Spacer()
                Text("\(String(format: "%.2f", expense.amount)) \(currency)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
            }

            HStack(spacing: 12) {
                Text(expense.category.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.textSecondary)

                if let payer = payerMember {
                    Text("·")
                        .foregroundColor(Color.textMuted)
                    HStack(spacing: 4) {
                        SharedMemberMark(colorHex: payer.colorHex, size: 16)
                        Text(payer.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.textSecondary)
                    }
                }

                if !expense.note.isEmpty {
                    Text("·")
                        .foregroundColor(Color.textMuted)
                    Text(expense.note)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.textMuted)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(isServer ? Color.primaryBlue.opacity(0.04) : Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

public struct InviteMemberPreSheet: View {
    let space: SharedSpace
    let onProceedToSharing: () -> Void
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.deepNavy)
                        .frame(width: 32, height: 32)
                        .background(Color.white, in: Circle())
                        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            ZStack {
                Circle()
                    .fill(MoneyCityTheme.babyBlue.opacity(0.5))
                    .frame(width: 60, height: 60)
                Image(systemName: "person.2.badge.key.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color.deepNavy)
            }

            VStack(spacing: 6) {
                Text(l10n.isHebrew ? "הזמנת חבר/ה ל־\(space.name)" : "Invite to \(space.name)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                Text(l10n.isHebrew ? "חברים שיוזמנו יוכלו לצפות בהוצאות המרחב, להוסיף עסקאות ולראות את העיר המשותפת."
                                   : "Invited members can view shared expenses, add transactions, and see the shared city.")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(l10n.isHebrew ? "מה ישותף?" : "What is shared?")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(MoneyCityTheme.spentGreen)
                    Text(l10n.isHebrew ? "רק עסקאות שנשמרות במרחב זה" : "Only expenses saved to this space")
                        .font(.system(size: 13, weight: .medium))
                }

                HStack(spacing: 10) {
                    Image(systemName: "xmark.shield.fill")
                        .foregroundColor(MoneyCityTheme.brandPrimary)
                    Text(l10n.isHebrew ? "החשבון האישי, התקציב, והיעדים נשארים פרטיים לחלוטין" : "Personal account, budgets, and savings remain 100% private")
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)

            Spacer()

            Button {
                Haptics.impact(.medium)
                onProceedToSharing()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                    Text(l10n.isHebrew ? "המשך לשיתוף של Apple" : "Continue to Apple Sharing")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.deepNavy)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .presentationBackground(Color.appBackground)
        .presentationDetents([.medium, .fraction(0.7)])
        .presentationDragIndicator(.visible)
    }
}

struct SharedSharingController: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator; controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        return controller
    }
    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func itemTitle(for csc: UICloudSharingController) -> String? { "SPENT" }
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            Task { @MainActor in SharedWorkspaceStore.shared.errorMessage = error.localizedDescription }
        }
    }
}

final class SharedSpaceSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata { receive(metadata) }
    }
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) { receive(cloudKitShareMetadata) }
    private func receive(_ metadata: CKShare.Metadata) {
        guard metadata.containerIdentifier == "iCloud.com.moneycity.app" else { return }
        #if DEBUG
        if metadata.share.recordID.zoneID.zoneName.hasPrefix(SharedCloudLab.zonePrefix) {
            SharedCloudLab.shared.invitation = metadata; SharedCloudLab.shared.presentRequested = true
            return
        }
        #endif
        guard metadata.share.recordID.zoneID.zoneName.hasPrefix(SharedWorkspaceStore.zonePrefix) else { return }
        SharedWorkspaceStore.shared.invitation = metadata; SharedWorkspaceStore.shared.showSetup = true
    }
}
#endif
