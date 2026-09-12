import SwiftUI
import SwiftData

public struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.openURL) private var openURL
    @Query private var allTransactions: [Transaction]

    @AppStorage("userName") private var userName = ""
    @AppStorage("notifications_enabled", store: UserDefaults(suiteName: "group.com.moneycity.app")) private var notificationsEnabled = true
    @AppStorage("expense_capture_notifications_enabled", store: UserDefaults(suiteName: "group.com.moneycity.app")) private var captureNotificationsEnabled = true
    @AppStorage("haptics_enabled") private var hapticsEnabled = true
    
    @State private var showResetConfirmation = false
    @State private var showPrivacySheet = false
    @State private var showAboutSheet = false
    @State private var showOnboardingTour = false

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // 1. General (Language, Currency, Mayor & Targets)
                        settingsGroup(title: l10n.language == .hebrew ? "כללי" : "General") {
                            HStack {
                                Text(l10n.language == .hebrew ? "שפת ממשק" : "Interface Language")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { l10n.language },
                                    set: { l10n.currentLanguageRaw = $0.rawValue }
                                )) {
                                    ForEach(AppLanguage.allCases) { lang in
                                        Text(lang.displayName).tag(lang)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 170)
                            }
                            .padding(.vertical, 4)

                            Divider().background(Color.borderSubtle).padding(.vertical, 4)

                            HStack {
                                Text(l10n.language == .hebrew ? "מטבע ראשי" : "Base Currency")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                Spacer()
                                Picker("", selection: $l10n.baseCurrency) {
                                    ForEach(CurrencyType.allCases) { cur in
                                        Text("\(cur.symbol) \(cur.rawValue)").tag(cur)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Color.primaryBlue)
                            }
                            .padding(.vertical, 4)

                            Divider().background(Color.borderSubtle).padding(.vertical, 4)

                            Toggle(isOn: $l10n.autoConvertForeign) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(l10n.language == .hebrew ? "המרת מטבע אוטומטית" : "Automatic Currency Conversion")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.deepNavy)
                                    Text(l10n.language == .hebrew ? "שערי יציג עדכניים (הערכה)" : "Live exchange rates (estimated)")
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundColor(Color.textMuted)
                                }
                            }
                            .tint(Color.primaryBlue)
                            .padding(.vertical, 4)

                            Divider().background(Color.borderSubtle).padding(.vertical, 4)

                            HStack(spacing: 12) {
                                Text(l10n.language == .hebrew ? "שם ראש העיר" : "Mayor Name")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                Spacer()
                                TextField(l10n.language == .hebrew ? "שם" : "Name", text: $userName)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(Color.primaryBlue)
                            }
                            .padding(.vertical, 4)

                            Divider().background(Color.borderSubtle).padding(.vertical, 4)

                            HStack(spacing: 12) {
                                Text(l10n.language == .hebrew ? "תקציב חודשי" : "Monthly Budget")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                Spacer()
                                Text(l10n.language == .hebrew ? "במסך התקציב" : "On the budget screen")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.textMuted)
                            }
                            .padding(.vertical, 4)
                        }

                        // 2. Preferences & Notifications
                        settingsGroup(title: l10n.language == .hebrew ? "העדפות ממשק והתראות" : "Preferences & Notifications") {
                            Toggle(isOn: $notificationsEnabled) {
                                Text(l10n.language == .hebrew ? "התראות" : "Notifications")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                            }
                            .tint(Color.primaryBlue)
                            .onChange(of: notificationsEnabled) { _, isOn in
                                NotificationService.sync(
                                    enabled: isOn,
                                    isHebrew: l10n.language == .hebrew
                                )
                            }
                            .padding(.vertical, 4)

                            if notificationsEnabled {
                                Divider().background(Color.borderSubtle).padding(.vertical, 4)

                                Toggle(isOn: $captureNotificationsEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(l10n.language == .hebrew ? "אישור מיידי על כל רכישה" : "Instant Purchase Alerts")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(Color.deepNavy)
                                        Text(l10n.language == .hebrew ? "קבלת פוש מיידי כשרכישה נקלטת בהצלחה בעיר" : "Immediate push alert when a purchase is logged")
                                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                            .foregroundColor(Color.textMuted)
                                    }
                                }
                                .tint(Color.primaryBlue)
                                .padding(.vertical, 4)
                            }

                            Divider().background(Color.borderSubtle).padding(.vertical, 4)

                            Toggle(isOn: $hapticsEnabled) {
                                Text(l10n.language == .hebrew ? "משוב במגע" : "Haptic Feedback")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                            }
                            .tint(Color.primaryBlue)
                            .padding(.vertical, 4)
                        }

                        // 3. SPENT Section (Help & Feedback, Privacy, About)
                        settingsGroup(title: "SPENT") {
                            // Help & Feedback (Mailto to developer)
                            Button(action: {
                                let email = "support@moneycity.app"
                                let subject = "SPENT Feedback"
                                let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
                                if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)") {
                                    openURL(url)
                                }
                            }) {
                                HStack(spacing: 10) {
                                    MoneyIcon(.mail, size: 18, color: Color.primaryBlue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(l10n.language == .hebrew ? "עזרה ומשוב" : "Help & Feedback")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(Color.deepNavy)
                                        Text(l10n.language == .hebrew ? "דיווח על באגים, שאלות והצעות" : "Bug reports, questions & ideas")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundColor(Color.textMuted)
                                    }
                                    Spacer()
                                    MoneyIcon(l10n.language == .hebrew ? .chevronLeft : .chevronRight, size: 12, color: Color.textMuted)
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)

                            Divider().background(Color.borderSubtle).padding(.vertical, 4)

                            // Privacy Policy
                            Button(action: { showPrivacySheet = true }) {
                                HStack(spacing: 10) {
                                    MoneyIcon(.lock, size: 18, color: Color.themeMint)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(l10n.language == .hebrew ? "מדיניות פרטיות" : "Privacy Policy")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(Color.deepNavy)
                                        Text(l10n.language == .hebrew ? "המידע הפיננסי נשמר במכשיר שלך" : "Your financial data stays on your device")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundColor(Color.textMuted)
                                    }
                                    Spacer()
                                    MoneyIcon(l10n.language == .hebrew ? .chevronLeft : .chevronRight, size: 12, color: Color.textMuted)
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)

                            Divider().background(Color.borderSubtle).padding(.vertical, 4)

                            // About SPENT
                            Button(action: { showAboutSheet = true }) {
                                HStack(spacing: 10) {
                                    MoneyIcon(.infoCircle, size: 18, color: Color.deepNavy)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(l10n.language == .hebrew ? "אודות SPENT" : "About SPENT")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(Color.deepNavy)
                                        Text(l10n.language == .hebrew ? "גרסה, זכויות יוצרים ומידע" : "Version, copyright & details")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundColor(Color.textMuted)
                                    }
                                    Spacer()
                                    MoneyIcon(l10n.language == .hebrew ? .chevronLeft : .chevronRight, size: 12, color: Color.textMuted)
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)

                            Divider().background(Color.borderSubtle).padding(.vertical, 4)

                            // Onboarding Replay
                            Button(action: { showOnboardingTour = true }) {
                                HStack(spacing: 10) {
                                    MoneyIcon(.citySkyline, size: 18, color: Color.spentGreen)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(l10n.language == .hebrew ? "הדרכת פתיחה והיכרות" : "Welcome & Onboarding")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(Color.deepNavy)
                                        Text(l10n.language == .hebrew ? "צפייה מחדש בסיור העיר וההגדרות" : "Replay city tour and setup")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundColor(Color.textMuted)
                                    }
                                    Spacer()
                                    MoneyIcon(l10n.language == .hebrew ? .chevronLeft : .chevronRight, size: 12, color: Color.textMuted)
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }

                        // 4. Danger Zone (Data Management)
                        settingsGroup(title: l10n.language == .hebrew ? "אזור איפוס נתונים" : "Data Management") {
                            Button(role: .destructive, action: { showResetConfirmation = true }) {
                                HStack(spacing: 8) {
                                    TrashVectorIcon(color: Color.red)
                                    Text(l10n.language == .hebrew ? "איפוס כל העסקאות והנתונים" : "Reset All Transactions & Data")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.red)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }

                        // 5. Quiet Dynamic Version Footer
                        Text("SPENT \(StoreSnapshotService.currentVersion()) • Build \(StoreSnapshotService.currentBuild())")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Color.textMuted.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                            .padding(.bottom, 24)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle(l10n.language == .hebrew ? "הגדרות" : "Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.language == .hebrew ? "סגור" : "Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color.primaryBlue)
                }
            }
            .sheet(isPresented: $showPrivacySheet) {
                PrivacyPolicySheet()
                    .environmentObject(l10n)
            }
            .sheet(isPresented: $showAboutSheet) {
                AboutSpentSheet()
                    .environmentObject(l10n)
            }
            .fullScreenCover(isPresented: $showOnboardingTour) {
                OnboardingWizardView(
                    initialStep: 1,
                    initialPhase: "intro",
                    canDismiss: true,
                    onComplete: {
                        showOnboardingTour = false
                    },
                    onTriggerSampleTransaction: {}
                )
                .environmentObject(l10n)
            }
            .confirmationDialog(
                l10n.language == .hebrew ? "האם אתה בטוח שברצונך לאפס את כל הנתונים?" : "Are you sure you want to reset all data?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button(l10n.language == .hebrew ? "מחק הכל ואפס" : "Delete & Reset", role: .destructive) {
                    Task {
                        try? await DatabaseService.shared.resetAllData()
                        await MainActor.run { Haptics.notify(.warning) }
                    }
                }
                Button(l10n.language == .hebrew ? "ביטול" : "Cancel", role: .cancel) {}
            } message: {
                Text(l10n.language == .hebrew
                     ? "כל העסקאות, העיר שבנית, התשלומים והכללים שהאפליקציה למדה יימחקו. התקציב, ההכנסות, ההוצאות הקבועות ויעדי החיסכון יישארו — היעדים יתאפסו לאפס."
                     : "Every transaction, the city you built, your instalment plans and the rules the app learned will be deleted. Your budget, income, recurring expenses and savings goals stay — the goals reset to zero.")
            }
        }
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Color.textMuted)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
            .padding(.horizontal, 16)
        }
    }
}

