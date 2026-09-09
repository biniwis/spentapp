import SwiftUI

// MARK: - Bespoke Architectural Diorama Vector Icons (Matching Signature Icon Set)

/// 1. All City Skyline Diorama Icon ("כל העיר")
public struct DistrictSkylineVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.primaryBlue) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.citySkyline, size: 24)
    }
}

/// 2. Food Bistro Artisan Diorama Icon ("רובע האוכל")
public struct DistrictBistroVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeTurquoise) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.cutlery, size: 24)
    }
}

/// 3. Shopping Boutique Diorama Icon ("שדרת הקניות")
public struct DistrictBoutiqueVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeLavender) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.shoppingBag, size: 24)
    }
}

/// 4. Housing & Estate Diorama Icon ("מתחם המגורים")
public struct DistrictHousingVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.primaryBlue) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.home, size: 24)
    }
}

/// 5. Savings Botanical Park Diorama Icon ("שמורת הטבע והחיסכון")
public struct DistrictParkVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeMint) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.leaf, size: 24)
    }
}

/// 6. Mobility & Transport Diorama Icon ("תחבורה")
public struct DistrictTransportVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeOrange) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.car, size: 24)
    }
}

/// 7. Entertainment & Leisure Diorama Icon ("בילויים")
public struct DistrictEntertainmentVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeYellow) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.gamepad, size: 24)
    }
}

/// 8. Health & Wellness Diorama Icon ("בריאות")
public struct DistrictHealthVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themePink) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.medicalCross, size: 24)
    }
}

/// 9. Subscriptions & Streaming Media Diorama Icon ("מנויים")
public struct DistrictSubscriptionsVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.primaryBlue) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.refresh, size: 24)
    }
}

/// 10. Finance & Banking Diorama Icon ("בנק ועמלות")
public struct DistrictFinanceVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.deepNavy) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.creditCard, size: 24)
    }
}

/// 11. Other & Gifts Diorama Icon ("שונות")
public struct DistrictOtherVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeLavender) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.gift, size: 24)
    }
}

/// 12. Search Lens Precision Icon
public struct SearchLensVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.textMuted) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.search, size: 18)
    }
}

/// 13. Zen Mode Fullscreen Diorama Expand Icon
public struct DioramaExpandVectorIcon: View {
    public let isExpanded: Bool
    public let color: Color
    
    public init(isExpanded: Bool = false, color: Color = Color.deepNavy) {
        self.isExpanded = isExpanded
        self.color = color
    }
    
    public var body: some View {
        MoneyIcon(isExpanded ? .chevronDown : .chevronUp, size: 16)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isExpanded)
    }
}

/// 14. District Museum Vector Icon (מוזיאון הדברים המשונים)
public struct DistrictMuseumVectorIcon: View {
    public let color: Color
    public init(color: Color = Color(red: 139/255, green: 92/255, blue: 246/255)) {
        self.color = color
    }
    
    public var body: some View {
        MoneyIcon(.trophy, size: 22)
            .frame(width: 24, height: 24)
    }
}

// MARK: - Global Category Vector Icon & Category Badge Components

/// Unified Vector Icon for any SpendingCategory (Matching New Icon Set)
public struct CategoryVectorIcon: View {
    public let category: SpendingCategory
    public let color: Color?
    public let size: CGFloat
    
    public init(category: SpendingCategory, color: Color? = nil, size: CGFloat = 20) {
        self.category = category.canonical
        self.color = color
        self.size = size
    }
    
    public var iconType: MoneyIconType {
        switch category {
        case .housing:
            return .home
        case .food, .groceries, .coffee:
            return .cutlery
        case .transport:
            return .car
        case .shopping:
            return .shoppingBag
        case .entertainment:
            return .gamepad
        case .health:
            return .medicalCross
        case .subscriptions:
            return .refresh
        case .savings:
            return .leaf
        case .finance:
            return .creditCard
        case .miscellaneous, .misc:
            return .gift
        case .other:
            return .mail
        }
    }
    
    public var body: some View {
        MoneyIcon(iconType, size: size, color: color)
    }
}

/// Unified Soft Pastel Circular Badge with Category / Subcategory Vector Icon (Matches Reference Design)
public struct CategoryBadge: View {
    public let category: SpendingCategory
    public let iconOverride: MoneyIconType?
    public let size: CGFloat
    public let isSelected: Bool
    
    public init(category: SpendingCategory, size: CGFloat = 40, isSelected: Bool = false, iconOverride: MoneyIconType? = nil) {
        self.category = category.canonical
        self.iconOverride = iconOverride
        self.size = size
        self.isSelected = isSelected
    }

    public init(transaction: Transaction, size: CGFloat = 40, isSelected: Bool = false) {
        self.category = transaction.category.canonical
        self.iconOverride = SubcategoryBreakdownService.shared.subcategoryIcon(for: transaction)
        self.size = size
        self.isSelected = isSelected
    }
    
    public var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? category.themeColor.opacity(0.18) : category.softBackgroundColor)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(category.themeColor.opacity(isSelected ? 0.9 : 0.18), lineWidth: isSelected ? 2 : 1)
                )
            
            if let icon = iconOverride {
                MoneyIcon(icon, size: size * 0.58)
            } else {
                CategoryVectorIcon(
                    category: category,
                    size: size * 0.58
                )
            }
        }
    }
}

// MARK: - Dedicated Action & Utility Vector Icons (Signature Set)

/// Trash / Delete Action Vector Icon
public struct TrashVectorIcon: View {
    public let color: Color
    public let size: CGFloat
    public init(color: Color = Color.red, size: CGFloat = 20) {
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        MoneyIcon(.trash, size: size, color: color)
    }
}

/// Edit Pencil Vector Icon
public struct EditPencilVectorIcon: View {
    public let color: Color
    public let size: CGFloat
    public init(color: Color = Color.primaryBlue, size: CGFloat = 18) {
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        MoneyIcon(.pencil, size: size, color: color)
    }
}

/// Camera / OCR Viewfinder Vector Icon
public struct CameraVectorIcon: View {
    public let color: Color
    public let size: CGFloat
    public init(color: Color = Color.deepNavy, size: CGFloat = 20) {
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        MoneyIcon(.camera, size: size, color: color)
    }
}

/// Currency Exchange Rates Vector Icon
public struct ExchangeVectorIcon: View {
    public let color: Color
    public let size: CGFloat
    public init(color: Color = Color.primaryBlue, size: CGFloat = 18) {
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        MoneyIcon(.exchange, size: size, color: color)
    }
}

/// Note / Description Vector Icon
public struct NoteVectorIcon: View {
    public let color: Color
    public let size: CGFloat
    public init(color: Color = Color.deepNavy, size: CGFloat = 18) {
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        MoneyIcon(.document, size: size, color: color)
    }
}
