import SwiftUI

/// Wraps ThreeDioramaView and fires onReady once the JS dioramaReady message is received.
/// Provides a shimmer skeleton while the WebGL scene is initializing.
public struct DioramaReadyWrapper: View {
    // Pass-through all ThreeDioramaView params
    public let totalSpent: Double
    public let totalSavings: Double
    public let categoryTotals: [SpendingCategory: Double]
    public let buildingTotals: [String: Double]
    public let habits: BehavioralHabits
    public let enrichmentIds: [String]
    public let newlyUnlockedEnrichmentId: String?
    public let slotPlacements: [String: String]
    public let selectedDistrict: String?
    public let isPaused: Bool
    public let onSelectDistrict: (String?) -> Void
    public let onBuildingSelected: (DistrictBuildingInfo) -> Void
    public let onSlotTapped: ((String, String?) -> Void)?

    @State private var isLoaded = false

    public init(
        totalSpent: Double,
        totalSavings: Double,
        categoryTotals: [SpendingCategory: Double],
        buildingTotals: [String: Double],
        habits: BehavioralHabits,
        enrichmentIds: [String],
        newlyUnlockedEnrichmentId: String?,
        slotPlacements: [String: String],
        selectedDistrict: String?,
        isPaused: Bool,
        onSelectDistrict: @escaping (String?) -> Void,
        onBuildingSelected: @escaping (DistrictBuildingInfo) -> Void,
        onSlotTapped: ((String, String?) -> Void)?
    ) {
        self.totalSpent = totalSpent
        self.totalSavings = totalSavings
        self.categoryTotals = categoryTotals
        self.buildingTotals = buildingTotals
        self.habits = habits
        self.enrichmentIds = enrichmentIds
        self.newlyUnlockedEnrichmentId = newlyUnlockedEnrichmentId
        self.slotPlacements = slotPlacements
        self.selectedDistrict = selectedDistrict
        self.isPaused = isPaused
        self.onSelectDistrict = onSelectDistrict
        self.onBuildingSelected = onBuildingSelected
        self.onSlotTapped = onSlotTapped
    }

    public var body: some View {
        ZStack {
            ThreeDioramaView(
                totalSpent: totalSpent,
                totalSavings: totalSavings,
                categoryTotals: categoryTotals,
                buildingTotals: buildingTotals,
                habits: habits,
                enrichmentIds: enrichmentIds,
                newlyUnlockedEnrichmentId: newlyUnlockedEnrichmentId,
                slotPlacements: slotPlacements,
                selectedDistrict: selectedDistrict,
                isPaused: isPaused,
                onSelectDistrict: onSelectDistrict,
                onBuildingSelected: onBuildingSelected,
                onSlotTapped: onSlotTapped
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !isLoaded {
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
        .onAppear {
            // Safety timeout: Never stay stuck on skeleton
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !isLoaded {
                    withAnimation(.easeOut(duration: 0.4)) { isLoaded = true }
                }
            }
        }
    }
}

// Notification name ThreeDioramaView will post when ready
public extension Notification.Name {
    static let dioramaReady = Notification.Name("com.moneycity.dioramaReady")
}
