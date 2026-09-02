import SwiftUI
import SwiftData

/// State-of-the-art Spotify-Wrapped-inspired Monthly City Story for SPENT.
/// Features vibrant dynamic gradients, cynical humor, multi-stage spring entrance animations,
/// 3D directional slide transitions, and a grand finale shareable poster.
public struct MonthlyRecapSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager
    
    let recap: MonthlyRecap
    var onNavigateToCity: ((Date) -> Void)? = nil
    
    @State private var currentStep: Int = 0
    @State private var slideDirection: Int = 1 // 1 for forward, -1 for backward
    @State private var animateBeat: Bool = false
    
    private let totalSteps: Int = 6
    
    public init(recap: MonthlyRecap, onNavigateToCity: ((Date) -> Void)? = nil) {
        self.recap = recap
        self.onNavigateToCity = onNavigateToCity
    }
    
    private var isHebrew: Bool { l10n.language == .hebrew }
    
    public var body: some View {
        ZStack {
            // Dynamic Gradient Background per Story Beat
            beatBackgroundGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: currentStep)
            
            VStack(spacing: 0) {
                // Top Progress Indicators & Close Button
                topStoryHeader
                    .padding(.top, 16)
                    .padding(.horizontal, 20)
                
                Spacer(minLength: 10)
                
                // Story Beat Content with 3D Slide & Scale Transition
                ZStack {
                    Group {
                        switch currentStep {
                        case 0:
                            storyIntroSkyline
                        case 1:
                            storyBiggestDistrict
                        case 2:
                            storyTallestBuilding
                        case 3:
                            storyFavoriteHangout
                        case 4:
                            storyPeakDay
                        default:
                            storyGrandFinalePoster
                        }
                    }
                    .id(currentStep)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: slideDirection > 0 ? (isHebrew ? .leading : .trailing) : (isHebrew ? .trailing : .leading))
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.88)),
                            removal: .move(edge: slideDirection > 0 ? (isHebrew ? .trailing : .leading) : (isHebrew ? .leading : .trailing))
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.88))
                        )
                    )
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    // Tap right to go next, tap left to go back
                    if isHebrew {
                        if location.x < 120 { nextStep() } else if location.x > 260 { prevStep() } else { nextStep() }
                    } else {
                        if location.x > 260 { nextStep() } else if location.x < 120 { prevStep() } else { nextStep() }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            if value.translation.width < -40 {
                                if isHebrew { prevStep() } else { nextStep() }
                            } else if value.translation.width > 40 {
                                if isHebrew { nextStep() } else { prevStep() }
                            }
                        }
                )
                
                Spacer(minLength: 10)
                
                // Bottom Navigation Row
                bottomNavigationRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 26)
            }
        }
        .onAppear {
            triggerBeatAnimation()
        }
    }
    
    // MARK: - Dynamic Gradient Background
    private var beatBackgroundGradient: some View {
        LinearGradient(
            colors: gradientColorsForCurrentStep,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var gradientColorsForCurrentStep: [Color] {
        switch currentStep {
        case 0:
            // Skyline Archetype (Midnight Indigo to Soft Lavender)
            return [Color(red: 238/255, green: 242/255, blue: 255/255), Color(red: 224/255, green: 231/255, blue: 255/255)]
        case 1:
            // Top District (Warm Sunset / Category Theme)
            let c = recap.biggestDistrict?.category.themeColor ?? Color.themeOrange
            return [c.opacity(0.22), Color(red: 254/255, green: 243/255, blue: 199/255)]
        case 2:
            // Tallest Skyscraper (Neon Sky Blue)
            return [Color(red: 224/255, green: 242/255, blue: 254/255), Color(red: 219/255, green: 234/255, blue: 254/255)]
        case 3:
            // Regular Hangout (Warm Espresso / Peach)
            return [Color(red: 254/255, green: 242/255, blue: 242/255), Color(red: 254/255, green: 237/255, blue: 213/255)]
        case 4:
            // Peak Day (Vibrant Amber / Coral)
            return [Color(red: 254/255, green: 243/255, blue: 199/255), Color(red: 255/255, green: 237/255, blue: 213/255)]
        default:
            // Finale Poster (Deep Luxury Dark Canvas)
            return [Color(red: 15/255, green: 23/255, blue: 42/255), Color(red: 30/255, green: 41/255, blue: 59/255)]
        }
    }
    
    // MARK: - Story Progress Header
    private var topStoryHeader: some View {
        VStack(spacing: 12) {
            // 6 Segment Bars
            HStack(spacing: 5) {
                ForEach(0..<totalSteps, id: \.self) { idx in
                    Capsule()
                        .fill(idx <= currentStep ? (currentStep == 5 ? Color.white : Color.primaryBlue) : Color.slate300.opacity(0.4))
                        .frame(height: 4)
                        .animation(.spring(response: 0.35), value: currentStep)
                }
            }
            
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(isHebrew ? "סיכום חודש " + recap.monthNameHe : recap.monthNameEn + " City Story")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                }
                .foregroundColor(currentStep == 5 ? Color.white : Color.primaryBlue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(currentStep == 5 ? Color.white.opacity(0.15) : Color.primaryBlue.opacity(0.10))
                .clipShape(Capsule())
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(currentStep == 5 ? Color.white : Color.deepNavy.opacity(0.8))
                        .padding(8)
                        .background(currentStep == 5 ? Color.white.opacity(0.15) : Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.06), radius: 4, y: 1)
                }
            }
        }
    }
    
    // MARK: - Beat 0: City Archetype
    private var storyIntroSkyline: some View {
        VStack(spacing: 22) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(vibeColor.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .scaleEffect(animateBeat ? 1.0 : 0.6)
                
                Circle()
                    .fill(vibeColor.opacity(0.28))
                    .frame(width: 100, height: 100)
                    .scaleEffect(animateBeat ? 1.0 : 0.7)
                
                Image(systemName: recap.cityVibe.badgeIcon)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(vibeColor)
                    .scaleEffect(animateBeat ? 1.0 : 0.4)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.68), value: animateBeat)
            
            VStack(spacing: 8) {
                Text(isHebrew ? "טיפוס העיר שלך החודש" : "Your City Archetype")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(Color.primaryBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.primaryBlue.opacity(0.12))
                    .clipShape(Capsule())
                    .offset(y: animateBeat ? 0 : 15)
                    .opacity(animateBeat ? 1 : 0)
                
                Text(isHebrew ? recap.cityVibe.titleHe : recap.cityVibe.titleEn)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .multilineTextAlignment(.center)
                    .offset(y: animateBeat ? 0 : 20)
                    .opacity(animateBeat ? 1 : 0)
                
                Text(isHebrew ? recap.cityVibe.subtitleHe : recap.cityVibe.subtitleEn)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
                    .offset(y: animateBeat ? 0 : 25)
                    .opacity(animateBeat ? 1 : 0)
            }
            .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.08), value: animateBeat)
            
            // Spend pill
            HStack(spacing: 8) {
                Text(isHebrew ? "סך הכל נבנה בעיר:" : "Total Spent:")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                Text(l10n.baseCurrency.symbol + String(Int(recap.totalSpent)))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Color.white)
            .clipShape(Capsule())
            .shadow(color: Color.deepNavy.opacity(0.06), radius: 8, y: 2)
            .scaleEffect(animateBeat ? 1.0 : 0.8)
            .opacity(animateBeat ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.16), value: animateBeat)
            
            Spacer()
        }
    }
    
    // MARK: - Beat 1: Dominant District
    private var storyBiggestDistrict: some View {
        VStack(spacing: 22) {
            Spacer()
            
            if let district = recap.biggestDistrict {
                let pct = recap.totalSpent > 0 ? Int((district.amount / recap.totalSpent) * 100) : 0
                
                ZStack {
                    Circle()
                        .fill(district.category.themeColor.opacity(0.18))
                        .frame(width: 130, height: 130)
                        .scaleEffect(animateBeat ? 1.0 : 0.6)
                    
                    CategoryBadge(category: district.category, size: 78)
                        .scaleEffect(animateBeat ? 1.0 : 0.4)
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.68), value: animateBeat)
                
                VStack(spacing: 8) {
                    Text(isHebrew ? "הרובע ששלט בכיס" : "Dominant District")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(district.category.themeColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(district.category.themeColor.opacity(0.14))
                        .clipShape(Capsule())
                        .offset(y: animateBeat ? 0 : 15)
                        .opacity(animateBeat ? 1 : 0)
                    
                    Text(isHebrew ? district.category.displayName : district.category.displayNameEn)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                        .offset(y: animateBeat ? 0 : 20)
                        .opacity(animateBeat ? 1 : 0)
                    
                    Text(isHebrew
                         ? "\(l10n.format(amount: district.amount)) (\(pct)% מכלל העיר)"
                         : "\(l10n.format(amount: district.amount)) (\(pct)% of total)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                        .offset(y: animateBeat ? 0 : 25)
                        .opacity(animateBeat ? 1 : 0)
                }
                .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.08), value: animateBeat)
                
                Text(isHebrew ? "הבטן והחשקים שלך מימנו את רוב קו הרקיע החודש. הפועלים עבדו בעיקר בשבילם." : "Your appetites bankrolled most of this skyline.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .offset(y: animateBeat ? 0 : 20)
                    .opacity(animateBeat ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.16), value: animateBeat)
            } else {
                Text(isHebrew ? "חודש שקט — לא נרשמו הוצאות ברובעים." : "Quiet month — no district activity.")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Beat 2: Tallest Skyscraper
    private var storyTallestBuilding: some View {
        VStack(spacing: 22) {
            Spacer()
            
            if let skyscraper = recap.tallestBuilding {
                ZStack {
                    Circle()
                        .fill(Color.primaryBlue.opacity(0.15))
                        .frame(width: 130, height: 130)
                        .scaleEffect(animateBeat ? 1.0 : 0.6)
                    
                    DistrictSkylineVectorIcon(color: Color.primaryBlue)
                        .scaleEffect(animateBeat ? 1.6 : 0.6)
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.68), value: animateBeat)
                
                VStack(spacing: 8) {
                    Text(isHebrew ? "גורד השחקים של החודש" : "Tallest Skyscraper")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(Color.primaryBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.primaryBlue.opacity(0.12))
                        .clipShape(Capsule())
                        .offset(y: animateBeat ? 0 : 15)
                        .opacity(animateBeat ? 1 : 0)
                    
                    Text(skyscraper.merchantName)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .offset(y: animateBeat ? 0 : 20)
                        .opacity(animateBeat ? 1 : 0)
                    
                    Text(l10n.baseCurrency.symbol + String(Int(skyscraper.amount)))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                        .scaleEffect(animateBeat ? 1.0 : 0.7)
                        .opacity(animateBeat ? 1 : 0)
                }
                .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.08), value: animateBeat)
                
                Text(isHebrew ? "ההוצאה הבודדת הכי גדולה שהטילה צל על כל שאר השכונה." : "The single largest charge towering over your neighborhood.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .offset(y: animateBeat ? 0 : 20)
                    .opacity(animateBeat ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.16), value: animateBeat)
            } else {
                Text(isHebrew ? "אין מבנה בולט בחודש זה." : "No standout building this month.")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Beat 3: Favorite Hangout
    private var storyFavoriteHangout: some View {
        VStack(spacing: 22) {
            Spacer()
            
            if let hangout = recap.mostRepeatedStop {
                ZStack {
                    Circle()
                        .fill(Color.themeOrange.opacity(0.15))
                        .frame(width: 130, height: 130)
                        .scaleEffect(animateBeat ? 1.0 : 0.6)
                    
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color.themeOrange)
                        .scaleEffect(animateBeat ? 1.0 : 0.4)
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.68), value: animateBeat)
                
                VStack(spacing: 8) {
                    Text(isHebrew ? "תחנת הקבע של ראש העיר" : "Your Resident Hangout")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(Color.themeOrange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.themeOrange.opacity(0.12))
                        .clipShape(Capsule())
                        .offset(y: animateBeat ? 0 : 15)
                        .opacity(animateBeat ? 1 : 0)
                    
                    Text(hangout.merchantName)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                        .multilineTextAlignment(.center)
                        .offset(y: animateBeat ? 0 : 20)
                        .opacity(animateBeat ? 1 : 0)
                    
                    Text(isHebrew ? String(hangout.visitCount) + " ביקורים החודש" : String(hangout.visitCount) + " visits this month")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                        .offset(y: animateBeat ? 0 : 25)
                        .opacity(animateBeat ? 1 : 0)
                }
                .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.08), value: animateBeat)
                
                Text(isHebrew ? "אם הייתה לך שם חניה שמורה עם השם שלך, אף אחד לא היה מופתע." : "You visited often enough that they probably know your order by heart.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .offset(y: animateBeat ? 0 : 20)
                    .opacity(animateBeat ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.16), value: animateBeat)
            } else {
                Text(isHebrew ? "הפיזור היה אחיד — אין תחנת קבע בולטת." : "Evenly distributed visits.")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Beat 4: Peak Spending Day
    private var storyPeakDay: some View {
        VStack(spacing: 22) {
            Spacer()
            
            if let peak = recap.biggestSpendingDay {
                ZStack {
                    Circle()
                        .fill(Color.themeYellow.opacity(0.20))
                        .frame(width: 130, height: 130)
                        .scaleEffect(animateBeat ? 1.0 : 0.6)
                    
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color.themeYellow)
                        .scaleEffect(animateBeat ? 1.0 : 0.4)
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.68), value: animateBeat)
                
                VStack(spacing: 8) {
                    Text(isHebrew ? "היום הכי יקר בעיר" : "Peak Spending Day")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(Color.themeOrange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.themeOrange.opacity(0.12))
                        .clipShape(Capsule())
                        .offset(y: animateBeat ? 0 : 15)
                        .opacity(animateBeat ? 1 : 0)
                    
                    Text(isHebrew ? peak.formattedDateHe : peak.formattedDateEn)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                        .multilineTextAlignment(.center)
                        .offset(y: animateBeat ? 0 : 20)
                        .opacity(animateBeat ? 1 : 0)
                    
                    Text(l10n.baseCurrency.symbol + String(Int(peak.amount)))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                        .scaleEffect(animateBeat ? 1.0 : 0.7)
                        .opacity(animateBeat ? 1 : 0)
                }
                .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.08), value: animateBeat)
                
                Text(isHebrew ? "היום שבו כרטיס האשראי שלך עבד מסביב לשעון והקים שכונה שלמה." : "The single day your wallet worked overtime.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .offset(y: animateBeat ? 0 : 20)
                    .opacity(animateBeat ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.16), value: animateBeat)
            } else {
                Text(isHebrew ? "אין יום בולט במיוחד." : "No peak day detected.")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Beat 5: Grand Spotify Wrapped Finale Poster
    private var storyGrandFinalePoster: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Poster Glass Card
            VStack(alignment: .leading, spacing: 14) {
                // Poster Header Tag
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SPENT // CITY WRAPPED")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(Color.themeTurquoise)
                        Text(isHebrew ? "סיכום חודש " + recap.monthNameHe : recap.monthNameEn + " Recap")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    
                    // Vibe Pill
                    HStack(spacing: 4) {
                        Image(systemName: recap.cityVibe.badgeIcon)
                        Text(isHebrew ? recap.cityVibe.titleHe : recap.cityVibe.titleEn)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    }
                    .foregroundColor(vibeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                
                Divider().background(Color.white.opacity(0.15))
                
                // Top Highlights Grid
                VStack(spacing: 8) {
                    if let district = recap.biggestDistrict {
                        posterMetricRow(
                            icon: "building.columns.fill",
                            label: isHebrew ? "רובע מוביל" : "Top District",
                            value: (isHebrew ? district.category.displayName : district.category.displayNameEn) + " (" + l10n.baseCurrency.symbol + String(Int(district.amount)) + ")"
                        )
                    }
                    
                    if let skyscraper = recap.tallestBuilding {
                        posterMetricRow(
                            icon: "building.2.fill",
                            label: isHebrew ? "גורד שחקים" : "Top Landmark",
                            value: skyscraper.merchantName + " (" + l10n.baseCurrency.symbol + String(Int(skyscraper.amount)) + ")"
                        )
                    }
                    
                    if let hangout = recap.mostRepeatedStop {
                        posterMetricRow(
                            icon: "cup.and.saucer.fill",
                            label: isHebrew ? "תחנת קבע" : "Regular Stop",
                            value: hangout.merchantName + " (" + String(hangout.visitCount) + (isHebrew ? " פעמים)" : " visits)")
                        )
                    }
                    
                    if let peak = recap.biggestSpendingDay {
                        posterMetricRow(
                            icon: "calendar",
                            label: isHebrew ? "יום שיא" : "Peak Day",
                            value: (isHebrew ? peak.formattedDateHe : peak.formattedDateEn) + " (" + l10n.baseCurrency.symbol + String(Int(peak.amount)) + ")"
                        )
                    }
                }
                
                Divider().background(Color.white.opacity(0.15))
                
                // Bottom 3 Core Numbers
                HStack(spacing: 8) {
                    posterStatBox(
                        title: isHebrew ? "סך הכל הוצאות" : "Total Spent",
                        value: l10n.baseCurrency.symbol + String(Int(recap.totalSpent)),
                        color: Color.white
                    )
                    
                    posterStatBox(
                        title: isHebrew ? "מבנים שנבנו" : "Buildings",
                        value: String(recap.transactionCount),
                        color: Color.themeTurquoise
                    )
                    
                    if let remaining = recap.remainingBudget {
                        posterStatBox(
                            title: isHebrew ? "נותר בתקציב" : "Remaining",
                            value: l10n.baseCurrency.symbol + String(Int(remaining)),
                            color: Color.themeMint
                        )
                    } else if let comp = recap.comparisonVsPrevMonth {
                        posterStatBox(
                            title: isHebrew ? "לעומת קודם" : "vs Prev",
                            value: (comp.isDecrease ? "↓ " : "↑ ") + String(Int(comp.percentChange)) + "%",
                            color: comp.isDecrease ? Color.themeMint : Color.themeOrange
                        )
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.08))
                    .background(Color.black.opacity(0.35))
                    .blur(radius: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.3), radius: 16, y: 8)
            .scaleEffect(animateBeat ? 1.0 : 0.88)
            .opacity(animateBeat ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.72), value: animateBeat)
            
            Spacer()
        }
    }
    
    private func posterMetricRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.themeTurquoise)
                .frame(width: 18)
            Text(label + ":")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
    
    private func posterStatBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.6))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Navigation Controls
    private var bottomNavigationRow: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button(action: prevStep) {
                    Image(systemName: isHebrew ? "chevron.right" : "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(currentStep == 5 ? Color.white : Color.deepNavy)
                        .frame(width: 48, height: 48)
                        .background(currentStep == 5 ? Color.white.opacity(0.15) : Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 1)
                }
            }
            
            if currentStep < totalSteps - 1 {
                Button(action: nextStep) {
                    HStack(spacing: 6) {
                        Text(isHebrew ? "המשך" : "Next")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                        Image(systemName: isHebrew ? "arrow.left" : "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.primaryBlue)
                    .clipShape(Capsule())
                }
            } else {
                #if os(iOS)
                ShareLink(item: shareableRecapText) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .bold))
                        Text(isHebrew ? "שתף סיכום" : "Share")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                    }
                    .foregroundColor(Color.deepNavy)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.themeTurquoise)
                    .clipShape(Capsule())
                }
                #endif
                
                Button(action: {
                    dismiss()
                    onNavigateToCity?(recap.date)
                }) {
                    HStack(spacing: 6) {
                        Text(isHebrew ? "חזרה לעיר" : "Back to City")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.primaryBlue)
                    .clipShape(Capsule())
                }
            }
        }
    }
    
    private var shareableRecapText: String {
        let title = isHebrew ? "סיכום עיר SPENT לחודש " + recap.monthNameHe : "SPENT City Recap: " + recap.monthNameEn
        let spend = isHebrew ? "סך הכל: " + l10n.baseCurrency.symbol + String(Int(recap.totalSpent)) : "Total: " + l10n.baseCurrency.symbol + String(Int(recap.totalSpent))
        let txs = isHebrew ? String(recap.transactionCount) + " מבנים נבנו" : String(recap.transactionCount) + " buildings built"
        let vibe = isHebrew ? "מצב עיר: " + recap.cityVibe.titleHe : "City Vibe: " + recap.cityVibe.titleEn
        return title + "\n• " + spend + "\n• " + txs + "\n• " + vibe + "\n#SPENT"
    }
    
    private func nextStep() {
        if currentStep < totalSteps - 1 {
            slideDirection = 1
            animateBeat = false
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                currentStep += 1
            }
            Haptics.impact(.light)
            triggerBeatAnimation()
        }
    }
    
    private func prevStep() {
        if currentStep > 0 {
            slideDirection = -1
            animateBeat = false
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                currentStep -= 1
            }
            Haptics.impact(.light)
            triggerBeatAnimation()
        }
    }
    
    private func triggerBeatAnimation() {
        animateBeat = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                animateBeat = true
            }
        }
    }
    
    private var vibeColor: Color {
        switch recap.cityVibe.type {
        case .recordMetropolis: return Color.themeOrange
        case .greenMonth:        return Color.themeMint
        case .busy:              return Color.primaryBlue
        case .quiet:             return Color.slate400
        case .growing:           return Color.themeMint
        }
    }
}
