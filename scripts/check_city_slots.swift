import Foundation

@main
struct CitySlotsCheck {
    static func main() {
        func item(_ id: String, _ slot: String? = nil, active: Bool = true) -> CityPlacement {
            CityPlacement(itemId: id, slotId: slot, isApplied: active)
        }
        func check(_ value: @autoclosure () -> Bool, _ message: String) {
            precondition(value(), message); print("PASS: \(message)")
        }
        let slots = CitySlot.allSlots
        let all = slots.map { item($0.defaultItemId) }
        let resolve = CitySlot.resolvedPlacements
        check(slots.count == 13 && Set(slots.map(\.id)).count == 13, "13 unique canonical locations")
        check(resolve(all).count == 13, "All earned additions coexist")
        check(resolve([]).isEmpty, "No invented rewards")
        check(resolve([item("tree_sakura", active: false)]).isEmpty, "Removed item stays in inventory, not on map")
        check(resolve([item("tree_sakura", "slot_park_center")])["slot_tree_sakura"] == "tree_sakura", "Legacy placement survives")
        check(CitySlot.legacyAliases.keys.allSatisfy { CitySlot.slot(for: $0) != nil }, "All six legacy locations resolve")
        check(resolve([item("tree_sakura", "slot_park_center"), item("repair_bench", "slot_tree_sakura")]).count == 2, "Collisions preserve both earned items")
        check(resolve([item("fountain_marble", "slot_food_plaza")])["slot_fountain_marble"] == "fountain_marble", "Legacy fountain upgrades the existing fountain")
        check(resolve([item("park_bridge", "slot_cafe_stand")])["slot_park_bridge"] == "park_bridge", "Bridge remains over water")
        check(!CitySlot.slot(for: "slot_park_bridge")!.accepts("tree_sakura"), "No trees on bridge anchors")
        check(resolve([item("tree_sakura"), item("tree_sakura", "slot_cafe_stand")]).count == 1, "Duplicate inventory IDs render once")
        check(resolve([item("unknown")]).isEmpty, "Unknown catalog entries are not fabricated")
        check(resolve([item("tree_sakura", "slot_cafe_stand")]) == ["slot_cafe_stand": "tree_sakura"], "Moving an item does not copy it")
        check(resolve(all) == resolve(all), "Placement is deterministic")
    }
}
