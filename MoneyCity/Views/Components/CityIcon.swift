import SwiftUI

// MARK: - Bespoke Architectural Diorama Vector Icons (Zero Generic Apple SF Symbols)

/// 1. All City Skyline Diorama Icon (Properly padded & centered)
public struct DistrictSkylineVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.primaryBlue) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Main left skyscraper
            RoundedRectangle(cornerRadius: 1.8)
                .fill(color)
                .frame(width: 8, height: 16)
                .offset(x: -3.5, y: 1.5)
            
            // Right lower townhouse / tower
            RoundedRectangle(cornerRadius: 1.8)
                .fill(color.opacity(0.85))
                .frame(width: 7.5, height: 11.5)
                .offset(x: 4, y: 3.8)
            
            // Left tower illuminated window slits
            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 0.4)
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 4, height: 1.4)
                RoundedRectangle(cornerRadius: 0.4)
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 4, height: 1.4)
                RoundedRectangle(cornerRadius: 0.4)
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 4, height: 1.4)
            }
            .offset(x: -3.5, y: 1.5)
            
            // Right tower window
            RoundedRectangle(cornerRadius: 0.4)
                .fill(Color.white.opacity(0.92))
                .frame(width: 3.5, height: 2.5)
                .offset(x: 4, y: 3.2)
            
            // Roof antenna needle (well within bounds)
            Rectangle()
                .fill(color)
                .frame(width: 1.2, height: 3.2)
                .offset(x: -3.5, y: -8)
        }
        .frame(width: 24, height: 24)
    }
}

/// 2. Food Bistro Artisan Diorama Icon
public struct DistrictBistroVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeTurquoise) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Storefront main block
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 16, height: 10.5)
                .offset(y: 3)
            
            // Awning scalloped canopy roof
            HStack(spacing: 1) {
                ForEach(0..<4) { i in
                    RoundedRectangle(cornerRadius: 1.2)
                        .fill(i % 2 == 0 ? color : Color.white)
                        .frame(width: 3.6, height: 5.2)
                }
            }
            .offset(y: -3.5)
            
            // Arched bistro entrance door
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.white)
                .frame(width: 5.2, height: 6)
                .offset(y: 5.2)
        }
        .frame(width: 24, height: 24)
    }
}

/// 3. Shopping Boutique Diorama Icon (Elegant tote bag with smooth unclipped arched handle)
public struct DistrictBoutiqueVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeLavender) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Smooth Curved Arched Handle (no clipping mask)
            BagHandleArcShape()
                .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .frame(width: 8, height: 6)
                .offset(y: -5.5)
            
            // Tote bag trapezoid body
            RoundedRectangle(cornerRadius: 2.8)
                .fill(color)
                .frame(width: 15, height: 12)
                .offset(y: 2)
            
            // Center diamond brand seal
            DiamondShape()
                .fill(Color.white.opacity(0.95))
                .frame(width: 4.5, height: 4.5)
                .offset(y: 2)
        }
        .frame(width: 24, height: 24)
    }
}

private struct BagHandleArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width / 2,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        return p
    }
}

/// 4. Housing & Estate Diorama Icon (Properly padded townhouse)
public struct DistrictHousingVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.primaryBlue) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Chimney
            Rectangle()
                .fill(color)
                .frame(width: 2, height: 4)
                .offset(x: 4.5, y: -5.5)
            
            // Pitched gable roof
            TriangleShape()
                .fill(color)
                .frame(width: 16, height: 7.5)
                .offset(y: -4)
            
            // Townhouse body
            RoundedRectangle(cornerRadius: 1.8)
                .fill(color)
                .frame(width: 14, height: 10)
                .offset(y: 3)
            
            // Attic circular window
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 3.2, height: 3.2)
                .offset(y: -2.2)
            
            // Front door
            RoundedRectangle(cornerRadius: 1.2)
                .fill(Color.white.opacity(0.95))
                .frame(width: 4, height: 5.5)
                .offset(y: 5.2)
        }
        .frame(width: 24, height: 24)
    }
}

/// 5. Savings Botanical Park Diorama Icon (Smoothly centered oak tree)
public struct DistrictParkVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeMint) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Trunk
            RoundedRectangle(cornerRadius: 1)
                .fill(color.opacity(0.85))
                .frame(width: 3, height: 7)
                .offset(y: 5.5)
            
            // Botanical crown cloud (smoothly centered with top headroom)
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 10.5, height: 10.5)
                    .offset(x: -3.5, y: 0.5)
                Circle()
                    .fill(color)
                    .frame(width: 10.5, height: 10.5)
                    .offset(x: 3.5, y: 0.5)
                Circle()
                    .fill(color)
                    .frame(width: 11.5, height: 11.5)
                    .offset(x: 0, y: -3)
                
                // Soft center light leaf highlight
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 3.5, height: 3.5)
                    .offset(x: -1, y: -1.5)
            }
            .offset(y: -1.5)
        }
        .frame(width: 24, height: 24)
    }
}

/// 6. Mobility & Transport Diorama Icon
public struct DistrictTransportVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeOrange) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Commuter vehicle chassis
            RoundedRectangle(cornerRadius: 3.5)
                .fill(color)
                .frame(width: 16, height: 9.5)
                .offset(y: 0.5)
            
            // Windshield windows
            HStack(spacing: 1.8) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 5, height: 3.2)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 5, height: 3.2)
            }
            .offset(y: -0.8)
            
            // Wheels
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 3.8, height: 3.8)
                Circle()
                    .fill(color)
                    .frame(width: 3.8, height: 3.8)
            }
            .offset(y: 5.5)
        }
        .frame(width: 24, height: 24)
    }
}

/// 7. Entertainment & Leisure Diorama Icon
public struct DistrictEntertainmentVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeYellow) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Cinema Ticket / Pass
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 19, height: 13)
                .rotationEffect(.degrees(-8))
            
            // Perforated notch left/right
            HStack {
                Circle().fill(Color.white.opacity(0.85)).frame(width: 3.5, height: 3.5)
                Spacer()
                Circle().fill(Color.white.opacity(0.85)).frame(width: 3.5, height: 3.5)
            }
            .frame(width: 21)
            .rotationEffect(.degrees(-8))
            
            // Center Star / Crown
            DiamondShape()
                .fill(Color.white.opacity(0.95))
                .frame(width: 6, height: 6)
                .rotationEffect(.degrees(-8))
        }
        .frame(width: 24, height: 24)
    }
}

/// 8. Health & Wellness Diorama Icon
public struct DistrictHealthVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themePink) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Heart Silhouette Outer
            ZStack {
                Circle().fill(color).frame(width: 10, height: 10).offset(x: -4, y: -3)
                Circle().fill(color).frame(width: 10, height: 10).offset(x: 4, y: -3)
                TriangleShape().fill(color).frame(width: 18, height: 10).rotationEffect(.degrees(180)).offset(y: 2.5)
            }
            
            // Medical Plus Cross in center
            ZStack {
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 7, height: 2)
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 2, height: 7)
            }
            .offset(y: -1)
        }
        .frame(width: 24, height: 24)
    }
}

/// 9. Subscriptions & Streaming Media Diorama Icon
public struct DistrictSubscriptionsVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.primaryBlue) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Screen Device Frame
            RoundedRectangle(cornerRadius: 3.5)
                .fill(color)
                .frame(width: 18, height: 13)
            
            // Stand base
            RoundedRectangle(cornerRadius: 0.5)
                .fill(color)
                .frame(width: 8, height: 1.5)
                .offset(y: 8)
            
            // Play Triangle Inside
            TriangleShape()
                .fill(Color.white.opacity(0.95))
                .frame(width: 5.5, height: 6)
                .rotationEffect(.degrees(90))
                .offset(x: 0.5)
        }
        .frame(width: 24, height: 24)
    }
}

/// 10. Finance & Banking Diorama Icon
public struct DistrictFinanceVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.deepNavy) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Card Chassis
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 19, height: 13)
            
            // Magnetic stripe / chip
            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.white.opacity(0.35))
                .frame(width: 19, height: 2.5)
                .offset(y: -3)
            
            // Smart Chip gold square
            RoundedRectangle(cornerRadius: 0.8)
                .fill(Color.white.opacity(0.9))
                .frame(width: 4, height: 3)
                .offset(x: -4.5, y: 1.5)
        }
        .frame(width: 24, height: 24)
    }
}

/// 11. Other & Gifts Diorama Icon
public struct DistrictOtherVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeLavender) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Gift Box base
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 15, height: 12)
                .offset(y: 2)
            
            // Lid
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color)
                .frame(width: 17, height: 3.5)
                .offset(y: -4)
            
            // Ribbon Cross
            Rectangle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 2, height: 16)
                .offset(y: 0)
            
            // Ribbon Bow
            HStack(spacing: 1) {
                Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.2).frame(width: 4, height: 4)
                Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.2).frame(width: 4, height: 4)
            }
            .offset(y: -7)
        }
        .frame(width: 24, height: 24)
    }
}

/// 12. Search Lens Precision Icon
public struct SearchLensVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.textMuted) { self.color = color }
    
    public var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: 1.8)
                .frame(width: 11, height: 11)
                .offset(x: -2, y: -2)
            
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 2, height: 6)
                .rotationEffect(.degrees(-45))
                .offset(x: 4.5, y: 4.5)
        }
        .frame(width: 18, height: 18)
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
        Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(color)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isExpanded)
    }
}

private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// 14. District Museum Vector Icon (מוזיאון הדברים המשונים)
public struct DistrictMuseumVectorIcon: View {
    public let color: Color
    public init(color: Color = Color(red: 139/255, green: 92/255, blue: 246/255)) {
        self.color = color
    }
    
    public var body: some View {
        Image(systemName: "building.columns.fill")
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(color)
            .frame(width: 24, height: 24)
    }
}

// MARK: - Global Category Vector Icon & Category Badge Components

/// Unified Vector Icon for any SpendingCategory (Zero Apple Emojis)
public struct CategoryVectorIcon: View {
    public let category: SpendingCategory
    public let color: Color?
    public let size: CGFloat
    
    public init(category: SpendingCategory, color: Color? = nil, size: CGFloat = 20) {
        self.category = category.canonical
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        let tint = color ?? category.themeColor
        Group {
            switch category {
            case .housing:
                DistrictHousingVectorIcon(color: tint)
            case .food, .groceries, .coffee:
                DistrictBistroVectorIcon(color: tint)
            case .transport:
                DistrictTransportVectorIcon(color: tint)
            case .shopping:
                DistrictBoutiqueVectorIcon(color: tint)
            case .entertainment:
                DistrictEntertainmentVectorIcon(color: tint)
            case .health:
                DistrictHealthVectorIcon(color: tint)
            case .subscriptions:
                DistrictSubscriptionsVectorIcon(color: tint)
            case .savings:
                DistrictParkVectorIcon(color: tint)
            case .finance:
                DistrictFinanceVectorIcon(color: tint)
            case .miscellaneous, .misc:
                DistrictMuseumVectorIcon(color: tint)
            case .other:
                DistrictOtherVectorIcon(color: tint)
            }
        }
        .scaleEffect(size / 24.0)
        .frame(width: size, height: size)
    }
}

/// Unified Soft Pastel Circular/Rounded Badge with Category Vector Icon
public struct CategoryBadge: View {
    public let category: SpendingCategory
    public let size: CGFloat
    public let isSelected: Bool
    
    public init(category: SpendingCategory, size: CGFloat = 40, isSelected: Bool = false) {
        self.category = category.canonical
        self.size = size
        self.isSelected = isSelected
    }
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(isSelected ? category.themeColor : category.softBackgroundColor)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                        .stroke(category.themeColor.opacity(isSelected ? 0.8 : 0.18), lineWidth: 1.2)
                )
            
            CategoryVectorIcon(
                category: category,
                color: isSelected ? Color.white : category.themeColor,
                size: size * 0.54
            )
        }
    }
}

// MARK: - Dedicated Action & Utility Vector Icons

/// Trash / Delete Action Vector Icon
public struct TrashVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.red) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Can body
            RoundedRectangle(cornerRadius: 1.5)
                .stroke(color, lineWidth: 1.5)
                .frame(width: 13, height: 14)
                .offset(y: 2)
            
            // Vertical slat lines
            HStack(spacing: 2.5) {
                Rectangle().fill(color).frame(width: 1, height: 8)
                Rectangle().fill(color).frame(width: 1, height: 8)
            }
            .offset(y: 2)
            
            // Lid
            RoundedRectangle(cornerRadius: 0.8)
                .fill(color)
                .frame(width: 17, height: 2)
                .offset(y: -6)
            
            // Lid handle
            RoundedRectangle(cornerRadius: 0.5)
                .fill(color)
                .frame(width: 5, height: 2)
                .offset(y: -8)
        }
        .frame(width: 20, height: 20)
    }
}

/// Edit Pencil Vector Icon
public struct EditPencilVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.primaryBlue) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Pencil shaft
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 5, height: 12)
                .rotationEffect(.degrees(45))
            
            // Tip
            TriangleShape()
                .fill(color)
                .frame(width: 5, height: 4)
                .rotationEffect(.degrees(45))
                .offset(x: -6, y: 6)
        }
        .frame(width: 18, height: 18)
    }
}

/// Camera / OCR Viewfinder Vector Icon
public struct CameraVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.deepNavy) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Chassis
            RoundedRectangle(cornerRadius: 2.5)
                .stroke(color, lineWidth: 1.5)
                .frame(width: 17, height: 13)
                .offset(y: 1)
            
            // Flash hump
            RoundedRectangle(cornerRadius: 0.5)
                .fill(color)
                .frame(width: 5, height: 2)
                .offset(x: -3, y: -6.5)
            
            // Lens
            Circle()
                .stroke(color, lineWidth: 1.5)
                .frame(width: 6.5, height: 6.5)
                .offset(y: 1)
        }
        .frame(width: 20, height: 20)
    }
}

/// Currency Exchange Rates Vector Icon
public struct ExchangeVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.primaryBlue) { self.color = color }
    
    public var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.1, to: 0.9)
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 14, height: 14)
            
            // Exchange arrows
            TriangleShape()
                .fill(color)
                .frame(width: 4, height: 4)
                .rotationEffect(.degrees(90))
                .offset(x: 6.5, y: -2)
        }
        .frame(width: 18, height: 18)
    }
}

/// Note / Description Vector Icon
public struct NoteVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.deepNavy) { self.color = color }
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .stroke(color, lineWidth: 1.5)
                .frame(width: 13, height: 16)
            
            VStack(spacing: 2) {
                Rectangle().fill(color).frame(width: 7, height: 1)
                Rectangle().fill(color).frame(width: 7, height: 1)
                Rectangle().fill(color).frame(width: 4, height: 1)
            }
        }
        .frame(width: 18, height: 18)
    }
}
