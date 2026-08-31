import SwiftUI

/// Represents an individual 3D isometric tile/building on the island diorama.
public struct BuildingTile: Identifiable, Equatable, Sendable {
    public let id: Int
    public var category: SpendingCategory
    public var title: String
    public var spendingAmount: Double
    public var level: Int // 1 to 5
    public var heightScale: CGFloat // 0.3 (kiosk) to 2.5 (skyscraper)
    public var gridX: Int
    public var gridY: Int
    public var hasRoad: Bool
    public var hasTaxi: Bool
    public var floatingTag: String?
    
    public init(
        id: Int,
        category: SpendingCategory,
        title: String,
        spendingAmount: Double = 0.0,
        level: Int = 1,
        heightScale: CGFloat = 1.0,
        gridX: Int,
        gridY: Int,
        hasRoad: Bool = false,
        hasTaxi: Bool = false,
        floatingTag: String? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.spendingAmount = spendingAmount
        self.level = level
        self.heightScale = heightScale
        self.gridX = gridX
        self.gridY = gridY
        self.hasRoad = hasRoad
        self.hasTaxi = hasTaxi
        self.floatingTag = floatingTag
    }
}
