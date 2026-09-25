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

struct SharedSpacesSetupView: View {
    @ObservedObject private var store = SharedWorkspaceStore.shared
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

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
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ── Header ──
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.text("מרחב משותף", "Shared Space"))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Text(store.text("ניהול תקציב והוצאות משותפות ב־SPENT", "Manage budget and shared expenses in SPENT"))
                                .font(.system(size: 13, weight: .medium, design: .default))
                                .foregroundColor(Color.textSecondary)
                        }
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(Color.textMuted.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // ── Segment Switcher ──
                    HStack(spacing: 8) {
                        Button {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                selectedTab = .create
                            }
                        } label: {
                            Text(store.text("יצירת מרחב", "Create Space"))
                                .font(.system(size: 14, weight: selectedTab == .create ? .bold : .medium, design: .rounded))
                                .foregroundColor(selectedTab == .create ? Color.deepNavy : Color.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedTab == .create ? Color.white : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: selectedTab == .create ? Color.black.opacity(0.04) : Color.clear, radius: 4, y: 1)
                        }
                        .buttonStyle(.plain)

                        Button {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                selectedTab = .join
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(store.text("הצטרפות", "Join Space"))
                                    .font(.system(size: 14, weight: selectedTab == .join ? .bold : .medium, design: .rounded))
                                    .foregroundColor(selectedTab == .join ? Color.deepNavy : Color.textSecondary)
                                if store.invitation != nil {
                                    Circle()
                                        .fill(MoneyCityTheme.spentGreen)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedTab == .join ? Color.white : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: selectedTab == .join ? Color.black.opacity(0.04) : Color.clear, radius: 4, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(4)
                    .background(Color.borderSubtle.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 20)

                    if selectedTab == .create {
                        createSpaceContent
                    } else {
                        joinSpaceContent
                    }

                    // ── Existing Spaces ──
                    if !store.spaces.isEmpty {
                        existingSpacesCard
                    }

                    #if DEBUG
                    if store.database == nil {
                        demoSpaceCard
                    }
                    #endif
                }
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
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
    }

    private var createSpaceContent: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text(store.text("פרטי המרחב החדש", "New Space Details"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                // Space name field
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.text("שם המרחב", "Space Name"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                    TextField(store.text("למשל: הבית שלנו, דירת שותפים", "e.g., Our Home, Flatmates"), text: $name)
                        .font(.system(size: 15, weight: .medium, design: .default))
                        .padding(12)
                        .background(Color.appBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Member name field
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.text("השם שלך במרחב", "Your Name in the Space"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                    TextField(store.text("איך חברי המרחב יראו אותך", "How members will identify you"), text: $memberName)
                        .font(.system(size: 15, weight: .medium, design: .default))
                        .padding(12)
                        .background(Color.appBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Divider().padding(.vertical, 4)

                // Currency row
                Button {
                    Haptics.selection()
                    showCurrencyPicker = true
                } label: {
                    HStack(spacing: 12) {
                        Text(selectedCurrency.symbol)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                            .frame(width: 36, height: 36)
                            .background(MoneyCityTheme.babyBlue.opacity(0.6), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.text("מטבע המרחב", "Space Currency"))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Text(store.text("נקבע בעת היצירה ולא ניתן לשינוי", "Fixed upon creation"))
                                .font(.system(size: 11, weight: .regular, design: .default))
                                .foregroundColor(Color.textMuted)
                        }

                        Spacer()

                        Text(selectedCurrency.rawValue)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(MoneyCityTheme.brandPrimary)

                        Image(systemName: AppLanguage.current == .hebrew ? "chevron.left" : "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.textMuted)
                    }
                    .padding(12)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                // City Map style row
                Button {
                    Haptics.selection()
                    showMapStylePicker = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 16))
                            .foregroundColor(MoneyCityTheme.brandPrimary)
                            .frame(width: 36, height: 36)
                            .background(MoneyCityTheme.spentGreenSoft, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.text("סגנון עיר המרחב", "Space Map Style"))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Text(selectedStyle.title(isHebrew: AppLanguage.current == .hebrew))
                                .font(.system(size: 11, weight: .regular, design: .default))
                                .foregroundColor(Color.textMuted)
                        }

                        Spacer()

                        Image(systemName: AppLanguage.current == .hebrew ? "chevron.left" : "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.textMuted)
                    }
                    .padding(12)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.035), radius: 8, y: 2)
            .padding(.horizontal, 20)

            // CTA Button
            let canCreate = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                            !memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                Text(store.text("יצירת מרחב משותף", "Create Shared Space"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canCreate ? Color.deepNavy : Color.deepNavy.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canCreate)
            .padding(.horizontal, 20)
        }
    }

    private var joinSpaceContent: some View {
        VStack(spacing: 16) {
            if store.invitation != nil {
                // Highlighted Invitation Ready Card
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(MoneyCityTheme.spentGreenSoft)
                            .frame(width: 52, height: 52)
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 24))
                            .foregroundColor(MoneyCityTheme.spentGreen)
                    }

                    VStack(spacing: 4) {
                        Text(store.text("התקבלה הזמנה למרחב!", "Space Invitation Ready!"))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        Text(store.text("הוזמנת להצטרף למרחב הוצאות משותף", "You've been invited to join a shared expense space"))
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundColor(Color.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.text("השם שלך במרחב", "Your Name in Space"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.textSecondary)
                        TextField(store.text("איך תופיע/י בפני שאר החברים", "How others will see you"), text: $memberName)
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .padding(12)
                            .background(Color.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                            .frame(height: 50)
                            .background(memberName.isEmpty ? Color.deepNavy.opacity(0.4) : Color.deepNavy)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                .padding(.horizontal, 20)
            } else {
                // Join via Link Card
                VStack(alignment: .leading, spacing: 14) {
                    Text(store.text("הצטרפות באמצעות קישור", "Join via Link"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)

                    Text(store.text("אם קיבלת קישור הזמנה ב־iCloud / WhatsApp / הודעות, הדבק/י אותו כאן:", "If you received an invitation link via iCloud, paste it here:"))
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundColor(Color.textSecondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.text("קישור להזמנה", "Invitation Link"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.textSecondary)
                        TextField("https://www.icloud.com/share/...", text: $url)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Color.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.text("השם שלך במרחב", "Your Name in Space"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.textSecondary)
                        TextField(store.text("איך תופיע/י בפני שאר החברים", "How others will see you"), text: $memberName)
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .padding(12)
                            .background(Color.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                            .frame(height: 50)
                            .background(canJoin ? Color.deepNavy : Color.deepNavy.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canJoin)
                }
                .padding(18)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.035), radius: 8, y: 2)
                .padding(.horizontal, 20)
            }
        }
    }

    private var existingSpacesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.text("המרחבים שלך", "Your Spaces"))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
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
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 16))
                                .foregroundColor(MoneyCityTheme.brandPrimary)
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isSelected ? MoneyCityTheme.brandPrimary : Color.borderSubtle, lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    #if DEBUG
    private var demoSpaceCard: some View {
        Button {
            Haptics.selection()
            store.perform {
                try await store.startDemo()
                dismiss()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .foregroundColor(MoneyCityTheme.brandPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.text("פתיחת מרחב הדגמה מקומי", "Open Local Demo Space"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    Text(store.text("יוצר מרחב מקומי עם שותף/ה והוצאות לדוגמה", "Creates a local sandbox space with mock partner"))
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundColor(Color.textSecondary)
                }
                Spacer()
            }
            .padding(14)
            .background(MoneyCityTheme.babyBlue.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
    #endif
}

public struct CurrencyPickerModal: View {
    @Binding var selectedCurrency: CurrencyType
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
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
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.textMuted.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
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
                                .background(selectedCurrency == curr ? MoneyCityTheme.brandPrimary.opacity(0.06) : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(selectedCurrency == curr ? MoneyCityTheme.brandPrimary : Color.borderSubtle, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
        }
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
    private struct SharingItem: Identifiable { let id = UUID(); let share: CKShare }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(space.name)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Text(store.text("ניהול מרחב משותף · \(space.currencyCode)", "Manage Shared Space · \(space.currencyCode)"))
                                .font(.system(size: 13, weight: .medium, design: .default))
                                .foregroundColor(Color.textSecondary)
                        }
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.textMuted.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Conflict Alert Banner
                    if store.conflictCount > 0 {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Color.orange)
                            Text(store.text("\(store.conflictCount) עריכות התנגשו עם שינוי במרחב. גרסת השרת מוצגת.",
                                            "\(store.conflictCount) edits conflicted with shared changes. The server version is shown."))
                                .font(.system(size: 12, weight: .medium, design: .default))
                                .foregroundColor(Color.deepNavy)
                            Spacer()
                        }
                        .padding(14)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 20)
                    }

                    // Members Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(store.text("חברי המרחב", "Members"))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Spacer()
                            Text("\(store.members.filter { $0.spaceID == space.id }.count)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Color.textMuted)
                        }

                        VStack(spacing: 10) {
                            ForEach(store.members.filter { $0.spaceID == space.id }) { member in
                                HStack(spacing: 12) {
                                    SharedMemberMark(colorHex: member.colorHex, size: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(member.name)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundColor(Color.deepNavy)
                                        if member.id == store.myMemberID(in: space.id) {
                                            Text(store.text("את/ה", "You"))
                                                .font(.system(size: 11, weight: .medium, design: .default))
                                                .foregroundColor(MoneyCityTheme.brandPrimary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        Divider().padding(.vertical, 2)

                        // Invite Member Button
                        Button {
                            Haptics.impact(.light)
                            showPreInvite = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 15, weight: .semibold))
                                Text(store.text("הזמנת חבר/ה למרחב", "Invite Member"))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(MoneyCityTheme.brandPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(MoneyCityTheme.spentGreenSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(store.demo)
                    }
                    .padding(18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.black.opacity(0.035), radius: 8, y: 2)
                    .padding(.horizontal, 20)

                    // Space Settings Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text(store.text("הגדרות המרחב", "Space Settings"))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)

                        HStack {
                            Text(store.text("מטבע המרחב", "Currency"))
                                .font(.system(size: 14, weight: .medium, design: .default))
                                .foregroundColor(Color.textSecondary)
                            Spacer()
                            Text(space.currencyCode)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                        }

                        Divider()

                        HStack {
                            Text(store.text("אזור זמן", "Timezone"))
                                .font(.system(size: 14, weight: .medium, design: .default))
                                .foregroundColor(Color.textSecondary)
                            Spacer()
                            Text(space.timeZoneID)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.textMuted)
                        }

                        Divider()

                        HStack {
                            Text(store.text("סגנון מפת עיר", "City Style"))
                                .font(.system(size: 14, weight: .medium, design: .default))
                                .foregroundColor(Color.textSecondary)
                            Spacer()
                            Text(space.mapStyle)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                        }
                    }
                    .padding(18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.black.opacity(0.035), radius: 8, y: 2)
                    .padding(.horizontal, 20)

                    // Actions Card
                    VStack(spacing: 12) {
                        let isOwner = store.isOwner(space.id)
                        if isOwner {
                            Button(role: .destructive) {
                                Haptics.impact(.medium)
                                showDeleteConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(store.text("מחיקת המרחב המשותף", "Delete Shared Space"))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(MoneyCityTheme.destructive)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(MoneyCityTheme.destructive.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                Haptics.impact(.medium)
                                showLeaveConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(store.text("עזיבת המרחב", "Leave Space"))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(Color.deepNavy)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.borderSubtle.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
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
                store.text("האם למחוק את המרחב?", "Delete Space?"),
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(store.text("מחק מרחב ונתונים", "Delete Space"), role: .destructive) {
                    store.perform {
                        try await store.deleteSpace(space.id)
                        dismiss()
                    }
                }
                Button(store.text("ביטול", "Cancel"), role: .cancel) {}
            } message: {
                Text(store.text("פעולה זו בלתי הפיכה ותמחק את המרחב והנתונים המשותפים לכל המשתתפים. הנתונים האישיים שלך לא ייפגעו.",
                                "This cannot be undone and deletes the space for all members. Your personal data will not be affected."))
            }
            .confirmationDialog(
                store.text("האם לעזוב את המרחב?", "Leave Space?"),
                isPresented: $showLeaveConfirm,
                titleVisibility: .visible
            ) {
                Button(store.text("עזוב מרחב", "Leave Space"), role: .destructive) {
                    store.perform {
                        try await store.leaveSpace(space.id)
                        dismiss()
                    }
                }
                Button(store.text("ביטול", "Cancel"), role: .cancel) {}
            } message: {
                Text(store.text("הגישה למרחב זה תוסר ממכשירך. הוצאות שהזנת יישארו במרחב.",
                                "Access to this space will be removed. Your recorded expenses will stay in the space."))
            }
        }
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
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.textMuted.opacity(0.6))
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
