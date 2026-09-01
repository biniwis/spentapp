import SwiftUI
import SwiftData

/// Sims-style placement & architectural customization modal allowing the user to decide where to place their unlocked enrichments.
public struct CitySlotCustomizerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    public let initialSlotId: String?
    public let unlockedEnrichments: [CityEnrichment]
    public let currentPlacements: [String: String]
    public let onAssignSlot: (String, String?) -> Void // (slotId, enrichmentItemId or nil)
    
    @State private var selectedSlotId: String
    
    public init(
        initialSlotId: String? = nil,
        unlockedEnrichments: [CityEnrichment],
        currentPlacements: [String: String],
        onAssignSlot: @escaping (String, String?) -> Void
    ) {
        self.initialSlotId = initialSlotId
        self.unlockedEnrichments = unlockedEnrichments
        self.currentPlacements = currentPlacements
        self.onAssignSlot = onAssignSlot
        _selectedSlotId = State(initialValue: initialSlotId ?? CitySlot.allSlots.first?.id ?? "slot_park_center")
    }
    
    private var currentSlot: CitySlot {
        CitySlot.slot(for: selectedSlotId) ?? CitySlot.allSlots[0]
    }
    
    private var currentlyPlacedItemId: String? {
        currentPlacements[selectedSlotId]
    }
    
    private var currentlyPlacedEnrichment: CityEnrichment? {
        guard let id = currentlyPlacedItemId else { return nil }
        return unlockedEnrichments.first(where: { $0.itemId == id })
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    // 1. Blueprint Architectural Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 254/255, green: 243/255, blue: 199/255))
                                .frame(width: 58, height: 58)
                            
                            DistrictSkylineVectorIcon(color: Color.primaryBlue)
                                .scaleEffect(1.2)
                        }
                        
                        Text("עיצוב והצבת שדרוגים")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                        
                        Text("בחר מיקום באי והחלט איזה שדרוג יוצב בו (כמו בסימס!)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color(red: 100/255, green: 116/255, blue: 139/255))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 8)
                    
                    // 2. City Slots Horizontal Selector
                    VStack(alignment: .leading, spacing: 10) {
                        Text("בחר מגרש / מיקום בעיר:")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 51/255, green: 65/255, blue: 85/255))
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(CitySlot.allSlots) { slot in
                                    let isSelected = (slot.id == selectedSlotId)
                                    let placedItem = currentPlacements[slot.id]
                                    let itemIcon = unlockedEnrichments.first(where: { $0.itemId == placedItem })?.resolvedIcon ?? slot.icon
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            selectedSlotId = slot.id
                                        }
                                    }) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Image(systemName: slot.icon)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(isSelected ? .white : Color(red: 217/255, green: 119/255, blue: 6/255))
                                                Spacer()
                                                if placedItem != nil {
                                                    Image(systemName: itemIcon)
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(Color(red: 217/255, green: 119/255, blue: 6/255))
                                                        .padding(4)
                                                        .background(Color.white.opacity(0.8))
                                                        .clipShape(Circle())
                                                }
                                            }
                                            
                                            Text(slot.name)
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(isSelected ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                                                .lineLimit(1)
                                            
                                            Text(placedItem != nil ? "מוצב שדרוג" : "מגרש פנוי")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundColor(isSelected ? Color.white.opacity(0.9) : Color(red: 100/255, green: 116/255, blue: 139/255))
                                        }
                                        .padding(12)
                                        .frame(width: 140, height: 95)
                                        .background(isSelected ? Color(red: 217/255, green: 119/255, blue: 6/255) : Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(isSelected ? Color.clear : Color(red: 226/255, green: 232/255, blue: 240/255), lineWidth: 1.5)
                                        )
                                        .shadow(color: isSelected ? Color(red: 217/255, green: 119/255, blue: 6/255).opacity(0.3) : Color.black.opacity(0.03), radius: 6, y: 3)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // 3. Current Selected Slot Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: currentSlot.icon)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(red: 217/255, green: 119/255, blue: 6/255))
                                .frame(width: 40, height: 40)
                                .background(Color(red: 254/255, green: 243/255, blue: 199/255))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(currentSlot.name)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                                
                                Text(currentSlot.subtitle)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(Color(red: 100/255, green: 116/255, blue: 139/255))
                            }
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Status of this slot
                        if let placed = currentlyPlacedEnrichment {
                            HStack(spacing: 6) {
                                Text("מוצב כעת:")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                                Image(systemName: placed.resolvedIcon)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                                Text(placed.name)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                                Spacer()
                                Button(action: {
                                    onAssignSlot(selectedSlotId, nil)
                                }) {
                                    Text("פנה מקום")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(red: 239/255, green: 68/255, blue: 68/255))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color(red: 254/255, green: 242/255, blue: 242/255))
                                        .clipShape(Capsule())
                                }
                            }
                        } else {
                            HStack(spacing: 8) {
                                DistrictParkVectorIcon(color: Color.themeMint)
                                    .scaleEffect(0.7)
                                    .frame(width: 18, height: 18)
                                Text("מגרש פנוי להצבה – בחר שדרוג מהמלאי למטה")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(Color(red: 100/255, green: 116/255, blue: 139/255))
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(red: 248/255, green: 250/255, blue: 252/255))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(red: 226/255, green: 232/255, blue: 240/255), lineWidth: 1.5)
                    )
                    .padding(.horizontal, 20)
                    
                    // 4. Available Inventory to Place
                    VStack(alignment: .leading, spacing: 12) {
                        Text("שדרוגים פתוחים באינוונטר שלך:")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 51/255, green: 65/255, blue: 85/255))
                            .padding(.horizontal, 20)
                        
                        if unlockedEnrichments.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                                Text("טרם נפתחו שדרוגים פיזיים")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 100/255, green: 116/255, blue: 139/255))
                                Text("השג התקדמות שבועית כדי לפתוח מזרקות, עצים, חתולים ופסלים!")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(Color(red: 148/255, green: 163/255, blue: 184/255))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 20)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(unlockedEnrichments) { item in
                                    let isPlacedInThisSlot = (currentPlacements[selectedSlotId] == item.itemId)
                                    let isPlacedElsewhere = currentPlacements.values.contains(item.itemId) && !isPlacedInThisSlot
                                    
                                    Button(action: {
                                        onAssignSlot(selectedSlotId, item.itemId)
                                    }) {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color(red: 254/255, green: 243/255, blue: 199/255))
                                                    .frame(width: 44, height: 44)
                                                Image(systemName: item.resolvedIcon)
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundColor(Color(red: 217/255, green: 119/255, blue: 6/255))
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name)
                                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                                    .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                                                
                                                Text(item.subtitle.isEmpty ? "שדרוג עירוני מוכן להצבה" : item.subtitle)
                                                    .font(.system(size: 11, design: .rounded))
                                                    .foregroundColor(Color(red: 100/255, green: 116/255, blue: 139/255))
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer()
                                            
                                            if isPlacedInThisSlot {
                                                Label("מוצב כאן", systemImage: "checkmark")
                                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                                    .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 5)
                                                    .background(Color(red: 209/255, green: 250/255, blue: 229/255))
                                                    .clipShape(Capsule())
                                            } else {
                                                Text(isPlacedElsewhere ? "העבר לכאן" : "הצב כאן")
                                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                                    .foregroundColor(Color.white)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(Color(red: 217/255, green: 119/255, blue: 6/255))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        .padding(12)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(isPlacedInThisSlot ? Color(red: 16/255, green: 185/255, blue: 129/255) : Color(red: 226/255, green: 232/255, blue: 240/255), lineWidth: 1.5)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(red: 248/255, green: 250/255, blue: 252/255))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("סגור") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
        }
    }
}
