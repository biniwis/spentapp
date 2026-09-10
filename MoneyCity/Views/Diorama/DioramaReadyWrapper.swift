import SwiftUI

/// Wraps ThreeDioramaView and fires onReady once the JS dioramaReady message is received.
/// Provides a shimmer skeleton while the WebGL scene is initializing.
public struct DioramaReadyWrapper: View {
    // Pass-through all ThreeDioramaView params
    public let totalSpent: Double
    public let totalSavings: Double
    public let savingsTarget: Double
    public let parkHealth: Double
    /// Bumped whenever the user asks for the default city view back.
    public let viewResetToken: Int
    /// Pulls the camera back for the month view.
    public let isOverview: Bool
    public let categoryTotals: [SpendingCategory: Double]
    public let buildingTotals: [String: Double]
    public let districtStates: [CityDistrictState]
    public let venueStates: [CityVenueState]
    public let habits: BehavioralHabits
    public let enrichmentIds: [String]
    public let newlyUnlockedEnrichmentId: String?
    public let slotPlacements: [String: String]
    public let selectedDistrict: String?
    public let selectedBuildingId: String?
    /// Optional first-use focus rendered on top of the real 3D building.
    public let tutorialBuildingId: String?
    public let language: String
    public let isPaused: Bool
    public let onSelectDistrict: (String?) -> Void
    public let onBuildingSelected: (DistrictBuildingInfo) -> Void
    public let onSlotTapped: ((String, String?) -> Void)?
    public let onCameraOffsetChanged: ((Bool) -> Void)?

    @State private var isLoaded = false
    @State private var hasStarted = false

    public init(
        totalSpent: Double,
        totalSavings: Double,
        savingsTarget: Double = 0,
        parkHealth: Double = 0.78,
        viewResetToken: Int = 0,
        isOverview: Bool = false,
        categoryTotals: [SpendingCategory: Double],
        buildingTotals: [String: Double],
        districtStates: [CityDistrictState],
        venueStates: [CityVenueState] = [],
        habits: BehavioralHabits,
        enrichmentIds: [String],
        newlyUnlockedEnrichmentId: String?,
        slotPlacements: [String: String],
        selectedDistrict: String?,
        selectedBuildingId: String? = nil,
        tutorialBuildingId: String? = nil,
        language: String = "he",
        isPaused: Bool,
        onSelectDistrict: @escaping (String?) -> Void,
        onBuildingSelected: @escaping (DistrictBuildingInfo) -> Void,
        onSlotTapped: ((String, String?) -> Void)? = nil,
        onCameraOffsetChanged: ((Bool) -> Void)? = nil
    ) {
        self.totalSpent = totalSpent
        self.totalSavings = totalSavings
        self.savingsTarget = savingsTarget
        self.parkHealth = parkHealth
        self.viewResetToken = viewResetToken
        self.isOverview = isOverview
        self.categoryTotals = categoryTotals
        self.buildingTotals = buildingTotals
        self.districtStates = districtStates
        self.venueStates = venueStates
        self.habits = habits
        self.enrichmentIds = enrichmentIds
        self.newlyUnlockedEnrichmentId = newlyUnlockedEnrichmentId
        self.slotPlacements = slotPlacements
        self.selectedDistrict = selectedDistrict
        self.selectedBuildingId = selectedBuildingId
        self.tutorialBuildingId = tutorialBuildingId
        self.language = language
        self.isPaused = isPaused
        self.onSelectDistrict = onSelectDistrict
        self.onBuildingSelected = onBuildingSelected
        self.onSlotTapped = onSlotTapped
        self.onCameraOffsetChanged = onCameraOffsetChanged
    }

    public var body: some View {
        ZStack {
            // Do not construct WebGL behind onboarding or an initially inactive scene.
            // Once started, keep the same WebView and only pause its renderer.
            if hasStarted || !isPaused {
            ThreeDioramaView(
                totalSpent: totalSpent,
                totalSavings: totalSavings,
                savingsTarget: savingsTarget,
                parkHealth: parkHealth,
                viewResetToken: viewResetToken,
                isOverview: isOverview,
                categoryTotals: categoryTotals,
                buildingTotals: buildingTotals,
                districtStates: districtStates,
                venueStates: venueStates,
                habits: habits,
                enrichmentIds: enrichmentIds,
                newlyUnlockedEnrichmentId: newlyUnlockedEnrichmentId,
                slotPlacements: slotPlacements,
                selectedDistrict: selectedDistrict,
                selectedBuildingId: selectedBuildingId,
                tutorialBuildingId: tutorialBuildingId,
                language: language,
                isPaused: isPaused,
                onSelectDistrict: onSelectDistrict,
                onBuildingSelected: onBuildingSelected,
                onSlotTapped: onSlotTapped,
                onCameraOffsetChanged: onCameraOffsetChanged
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                guard !hasStarted else { return }
                hasStarted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if !isLoaded {
                        withAnimation(.easeOut(duration: 0.4)) { isLoaded = true }
                    }
                }
            }
            }

            if !isLoaded && !isPaused {
                DioramaSkeletonView(onReady: {
                    withAnimation(.easeOut(duration: 0.5)) { isLoaded = true }
                })
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        // Listen for the notification ThreeDioramaView posts when dioramaReady fires
        .onReceive(NotificationCenter.default.publisher(for: .dioramaReady)) { _ in
            withAnimation(.easeOut(duration: 0.4)) { isLoaded = true }
        }
    }
}

// Notification name ThreeDioramaView will post when ready
public extension Notification.Name {
    static let dioramaReady = Notification.Name("com.moneycity.dioramaReady")
}
