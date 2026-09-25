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

private struct TabPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// An architectural drawing of two shared buildings and a tree in the SPENT Onboarding style.
struct SharedSpaceHeroIllustration: View {
    let isJoin: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var bounce = false
    @State private var smokeTick = false

    private let ink = Color.jetBlack
    private let stroke = StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)

    var body: some View {
        Canvas { context, _ in
            var c = context
            // Ground line
            line(&c, [(24, 76), (216, 76)], width: 2.6)

            // Left Building (Partner 1) - Baby Blue
            polygon(&c, [(88, 26), (95, 20), (95, 70), (88, 76)], fill: .jetBlack) // side depth
            rectangle(&c, 32, 26, 56, 50, fill: .babyBlue, radius: 2) // facade
            polygon(&c, [(28, 26), (36, 18), (92, 18), (88, 26)], fill: .white) // roof slab

            // Left Windows (warm glow when in create mode)
            rectangle(&c, 41, 35, 11, 11, fill: isJoin ? .jetBlack : .warmCream, radius: 1)
            line(&c, [(44, 37), (44, 43)], color: isJoin ? .white : .jetBlack, width: 1.5)
            rectangle(&c, 64, 35, 11, 11, fill: isJoin ? .jetBlack : .warmCream, radius: 1)
            line(&c, [(67, 37), (67, 43)], color: isJoin ? .white : .jetBlack, width: 1.5)
            // Left Door
            rectangle(&c, 52, 56, 14, 20, fill: .violetBlue, radius: 1)

            // Right Building (Partner 2) - Warm Cream with Pitched Roof
            // Chimney
            rectangle(&c, 180, 16, 8, 12, fill: .jetBlack, radius: 1)
            // Animated smoke puffs
            let smokeY: CGFloat = smokeTick ? -2.5 : 0
            circle(&c, 184, 11 + smokeY, 2.5, fill: .white)
            circle(&c, 188, 6 + smokeY, 3.2, fill: .white)

            polygon(&c, [(192, 34), (198, 28), (198, 70), (192, 76)], fill: .jetBlack) // side depth
            rectangle(&c, 136, 34, 56, 42, fill: .warmCream, radius: 2) // facade
            // Pitched roof
            polygon(&c, [(132, 34), (164, 14), (196, 34)], fill: .orangeRed)
            line(&c, [(132, 34), (164, 14), (196, 34)])

            // Right Windows (glowing lime when in join mode)
            rectangle(&c, 145, 42, 10, 10, fill: isJoin ? .neonLime : .jetBlack, radius: 1)
            line(&c, [(148, 44), (148, 49)], color: isJoin ? .jetBlack : .white, width: 1.5)
            rectangle(&c, 171, 42, 10, 10, fill: isJoin ? .neonLime : .jetBlack, radius: 1)
            line(&c, [(174, 44), (174, 49)], color: isJoin ? .jetBlack : .white, width: 1.5)
            // Door
            rectangle(&c, 158, 58, 13, 18, fill: .jetBlack, radius: 1)

            // Center Tree (Shared green connection)
            line(&c, [(112, 76), (112, 45)], width: 2.6)
            circle(&c, 112, 36, 15, fill: .luckyGreen)
            line(&c, [(112, 54), (107, 48)], width: 1.8)

            // Stepping stones between buildings
            circle(&c, 100, 76, 2, fill: .white)
            circle(&c, 124, 76, 2, fill: .white)

            if isJoin {
                // Animated invitation envelope flying between them with dashed trajectory
                var arch = Path()
                arch.move(to: CGPoint(x: 75, y: 22))
                arch.addQuadCurve(to: CGPoint(x: 148, y: 24), control: CGPoint(x: 112, y: 4))
                c.stroke(arch, with: .color(ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [3, 3]))

                // Little envelope
                polygon(&c, [(105, 14), (119, 14), (119, 24), (105, 24)], fill: .white)
                polygon(&c, [(105, 14), (112, 19), (119, 14)], fill: .orangeRed)
            } else {
                // Sky detail (two minimalist birds / sparkles)
                line(&c, [(108, 14), (112, 11), (116, 14)], width: 1.8)
                line(&c, [(122, 18), (125, 15), (128, 18)], width: 1.5)
            }
        }
        .frame(width: 240, height: 88)
        .scaleEffect(bounce ? 1.06 : (appeared ? 1.0 : 0.88))
        .opacity(appeared ? 1.0 : 0.0)
        .offset(y: appeared ? 0 : 8)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.impact(.light)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.52)) {
                bounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    bounce = false
                }
            }
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                    appeared = true
                }
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    smokeTick = true
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isJoin)
        .accessibilityHidden(true)
    }

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
                      color: Color = .jetBlack, width: CGFloat = 2.6) {
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

struct SharedSpacesSetupView: View {
    @ObservedObject private var store = SharedWorkspaceStore.shared
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @Namespace private var toggleNamespace

    private enum SetupTab: Int, CaseIterable {
        case create = 0
        case join = 1
    }

    @State private var selectedTab: SetupTab = .create
    @State private var name = ""
    @State private var memberName = ""
    @State private var url = ""
    @State private var selectedCurrency: CurrencyType = LocalizationManager.shared.baseCurrency
    @State private var selectedStyle: CityMapStyle = .urban
    @State private var showCurrencyPicker = false
    @State private var showMapStylePicker = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // ── Top Navigation Bar ──
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
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // ── Centered Compact Capsule Toggle with Fluid Sliding Indicator ──
                    HStack(spacing: 0) {
                        Button {
                            guard selectedTab != .create else { return }
                            Haptics.selection()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                selectedTab = .create
                            }
                        } label: {
                            Text(store.text("יצירת מרחב", "Create Space"))
                                .font(.system(size: 13, weight: selectedTab == .create ? .bold : .medium, design: .rounded))
                                .foregroundColor(selectedTab == .create ? Color.deepNavy : Color.textSecondary)
                                .frame(width: 96, height: 28)
                                .background {
                                    if selectedTab == .create {
                                        Capsule()
                                            .fill(Color.white)
                                            .matchedGeometryEffect(id: "activeTabPill", in: toggleNamespace)
                                            .shadow(color: Color.black.opacity(0.08), radius: 3, y: 1.5)
                                    }
                                }
                                .contentShape(Capsule())
                        }
                        .buttonStyle(TabPressButtonStyle())

                        Button {
                            guard selectedTab != .join else { return }
                            Haptics.selection()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                selectedTab = .join
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(store.text("הצטרפות", "Join Space"))
                                    .font(.system(size: 13, weight: selectedTab == .join ? .bold : .medium, design: .rounded))
                                    .foregroundColor(selectedTab == .join ? Color.deepNavy : Color.textSecondary)
                                if store.invitation != nil {
                                    Circle()
                                        .fill(MoneyCityTheme.spentGreen)
                                        .frame(width: 5.5, height: 5.5)
                                }
                            }
                            .frame(width: 96, height: 28)
                            .background {
                                if selectedTab == .join {
                                    Capsule()
                                        .fill(Color.white)
                                        .matchedGeometryEffect(id: "activeTabPill", in: toggleNamespace)
                                        .shadow(color: Color.black.opacity(0.08), radius: 3, y: 1.5)
                                }
                            }
                            .contentShape(Capsule())
                        }
                        .buttonStyle(TabPressButtonStyle())
                    }
                    .padding(3)
                    .background(
                        Capsule()
                            .fill(Color.jetBlack.opacity(0.05))
                    )
                    .frame(maxWidth: .infinity, alignment: .center)

                    // ── Onboarding-style Animated Architectural Hero Illustration ──
                    SharedSpaceHeroIllustration(isJoin: selectedTab == .join)
                        .padding(.top, 4)

                    // ── Editorial Title & Subtitle ──
                    VStack(spacing: 6) {
                        Text(selectedTab == .create ? store.text("פותחים מרחב משותף", "Start a Shared Space") : store.text("הצטרפות למרחב", "Join a Shared Space"))
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .tracking(AppLanguage.current == .hebrew ? -0.8 : -1.2)
                            .foregroundColor(Color.deepNavy)
                            .multilineTextAlignment(.center)

                        Text(selectedTab == .create ? store.text("מעקב והוצאות משותפות, בעיר אחת לשניכם", "Track shared expenses together in one city") : store.text("הזינו את הקישור שקיבלתם כדי להצטרף", "Enter the invite link to join your partner"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTab)

                    // ── Active Tab Content ──
                    ZStack {
                        if selectedTab == .create {
                            createSpaceContent
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .offset(x: -12)),
                                    removal: .opacity.combined(with: .offset(x: -12))
                                ))
                        } else {
                            joinSpaceContent
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .offset(x: 12)),
                                    removal: .opacity.combined(with: .offset(x: 12))
                                ))
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTab)

                    // ── Existing Spaces ──
                    if !store.spaces.isEmpty {
                        existingSpacesCard
                    }
                }
                .padding(.bottom, 36)
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
                    isHebrew: AppLanguage.current == .hebrew,
                    onClose: { showMapStylePicker = false },
                    onSelect: { chosen in
                        selectedStyle = chosen
                        showMapStylePicker = false
                    }
                )
                .environmentObject(l10n)
            }
        }
        .presentationBackground(Color.appBackground)
    }

    private var createSpaceContent: some View {
        VStack(spacing: 20) {
            // Space name field
            VStack(alignment: .leading, spacing: 8) {
                Text(store.text("שם המרחב", "Space Name"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                TextField(store.text("הבית שלנו", "Our Home"), text: $name)
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(Color.deepNavy)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)
            }

            // Member name field
            VStack(alignment: .leading, spacing: 8) {
                Text(store.text("השם שלך", "Your Name"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                TextField(store.text("איך יראו אותך במרחב", "How members will see you"), text: $memberName)
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(Color.deepNavy)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)
            }

            // Currency & City Map Style side-by-side selection pills
            HStack(spacing: 12) {
                // Currency Button
                Button {
                    Haptics.selection()
                    showCurrencyPicker = true
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(MoneyCityTheme.babyBlue.opacity(0.55))
                                .frame(width: 32, height: 32)
                            Text(selectedCurrency.symbol)
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.text("מטבע", "Currency"))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.textSecondary)
                            Text(selectedCurrency.rawValue)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.textMuted)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)
                }
                .buttonStyle(.plain)

                // City Map Style Button
                Button {
                    Haptics.selection()
                    showMapStylePicker = true
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(MoneyCityTheme.spentGreenSoft)
                                .frame(width: 32, height: 32)
                            MoneyIcon(.globe, size: 18, color: MoneyCityTheme.brandPrimary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.text("סגנון עיר", "City Style"))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.textSecondary)
                            Text(selectedStyle.title(isHebrew: AppLanguage.current == .hebrew))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.textMuted)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)
                }
                .buttonStyle(.plain)
            }

            // Primary CTA & Optional Demo
            let canCreate = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                            !memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            VStack(spacing: 12) {
                Button {
                    Haptics.impact(.medium)
                    store.perform {
                        try await store.create(
                            name: name,
                            memberName: memberName,
                            currency: selectedCurrency.rawValue,
                            mapStyle: selectedStyle.rawValue
                        )
                        dismiss()
                    }
                } label: {
                    Text(store.text("יצירת מרחב", "Create Space"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(canCreate ? MoneyCityTheme.brandPrimary : MoneyCityTheme.brandPrimary.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canCreate)

                #if DEBUG
                if store.database == nil {
                    Button {
                        Haptics.selection()
                        store.perform {
                            try await store.startDemo()
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(store.text("התנסות במרחב הדגמה", "Try Demo Space"))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(MoneyCityTheme.brandPrimary)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                #endif
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
    }

    private var joinSpaceContent: some View {
        VStack(spacing: 20) {
            if store.invitation != nil {
                // Highlighted Invitation Ready Card
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(MoneyCityTheme.spentGreenSoft)
                            .frame(width: 52, height: 52)
                        MoneyIcon(.mail, size: 26, color: MoneyCityTheme.brandPrimary)
                    }

                    Text(store.text("התקבלה הזמנה למרחב!", "Space Invitation Ready!"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.text("השם שלך", "Your Name"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        TextField(store.text("איך יראו אותך במרחב", "How others will see you"), text: $memberName)
                            .font(.system(size: 16, weight: .medium, design: .default))
                            .foregroundColor(Color.deepNavy)
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)
                    }

                    Button {
                        Haptics.impact(.medium)
                        store.perform {
                            guard let pending = store.invitation else { return }
                            try await store.accept(pending, memberName: memberName)
                            dismiss()
                        }
                    } label: {
                        Text(store.text("הצטרפות למרחב", "Join Space"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? MoneyCityTheme.brandPrimary.opacity(0.35) : MoneyCityTheme.brandPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.035), radius: 8, y: 2)
            } else {
                // Join via Link
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.text("קישור הזמנה", "Invitation Link"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        TextField("https://www.icloud.com/share/...", text: $url)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.text("השם שלך", "Your Name"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        TextField(store.text("איך יראו אותך במרחב", "How others will see you"), text: $memberName)
                            .font(.system(size: 16, weight: .medium, design: .default))
                            .foregroundColor(Color.deepNavy)
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)
                    }

                    let canJoin = !memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                                  !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                    Button {
                        Haptics.impact(.medium)
                        store.perform {
                            let metadata = try await store.metadata(for: url)
                            try await store.accept(metadata, memberName: memberName)
                            dismiss()
                        }
                    } label: {
                        Text(store.text("הצטרפות למרחב", "Join Space"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(canJoin ? MoneyCityTheme.brandPrimary : MoneyCityTheme.brandPrimary.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canJoin)
                }
            }
        }
        .padding(.horizontal, 24)
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

struct SharedSpaceManagement: View {
    let space: SharedSpace
    @ObservedObject private var store = SharedWorkspaceStore.shared
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var share: SharingItem?
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
