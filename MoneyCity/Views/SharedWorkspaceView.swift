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
                            Text(store.text("מעקב וניהול הוצאות משותפות ב־SPENT", "Track and manage shared expenses in SPENT"))
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
    @State private var showStopSharingConfirm = false
    @State private var showConflictResolution = false
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
                                        .font(.system(size: 12, weight: .medium, design: .default))
                                        .foregroundColor(Color.textSecondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                Image(systemName: l10n.isHebrew ? "chevron.left" : "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.orange)
                            }
                            .padding(14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.orange.opacity(0.35), lineWidth: 1.5)
                            )
                            .shadow(color: Color.orange.opacity(0.06), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                        }
                        .buttonStyle(.plain)
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
                            // Stop Sharing (Owner only)
                            Button {
                                Haptics.impact(.medium)
                                showStopSharingConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.crop.circle.badge.xmark")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text(store.text("עצירת שיתוף המרחב", "Stop Sharing Space"))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(Color.deepNavy)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.borderSubtle.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            // Delete Space (Owner only)
                            Button(role: .destructive) {
                                Haptics.impact(.medium)
                                showDeleteConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(store.text("מחיקת המרחב לצמיתות", "Delete Shared Space"))
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
                            // Leave Space (Participant only)
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
                                .foregroundColor(MoneyCityTheme.destructive)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(MoneyCityTheme.destructive.opacity(0.08))
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
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.textMuted.opacity(0.6))
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
