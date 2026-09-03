import SwiftUI
import WebKit

#if canImport(UIKit)
import UIKit
public typealias ViewRepresentable = UIViewRepresentable
#elseif canImport(AppKit)
import AppKit
public typealias ViewRepresentable = NSViewRepresentable
#endif

/// District inspection detail model
public struct DistrictBuildingInfo: Identifiable, Sendable {
    public let id: String
    public let districtId: String
    public let name: String
    public let amount: Double
    public let visitCount: Int
    public let trendText: String
    
    public init(id: String, districtId: String, name: String, amount: Double, visitCount: Int, trendText: String) {
        self.id = id
        self.districtId = districtId
        self.name = name
        self.amount = amount
        self.visitCount = visitCount
        self.trendText = trendText
    }
}

/// Living 3D Diorama with 2-Level Cinematic Zoom Navigation (Whole City <-> District Deep Dive) and interactive spatial building inspection.
public struct ThreeDioramaView: ViewRepresentable {
    public let totalSpent: Double
    public let totalSavings: Double
    /// The amount that fills the savings park; 0 when the user has no baseline yet.
    public let savingsTarget: Double
    /// How the reserve looks this month, 0 parched to 1 lush. Resets with the month.
    public let parkHealth: Double
    /// How grown the reserve is, 0 to just under 1, from savings across every month. Does
    /// not reset — the colour is this month's weather, this is the land itself.
    public let reserveMaturity: Double
    /// The figure behind that maturity, for the reserve's own sheet.
    public let lifetimeSavings: Double
    public let categoryTotals: [SpendingCategory: Double]
    public let buildingTotals: [String: Double]
    public let habits: BehavioralHabits
    public let enrichmentIds: [String]
    public let newlyUnlockedEnrichmentId: String?
    public let slotPlacements: [String: String]
    public let selectedDistrict: String?
    public let language: String
    public let isPaused: Bool
    public let onSelectDistrict: (String?) -> Void
    public let onBuildingSelected: (DistrictBuildingInfo) -> Void
    public let onSlotTapped: ((String, String?) -> Void)?
    
    public init(
        totalSpent: Double,
        totalSavings: Double,
        savingsTarget: Double = 0,
        parkHealth: Double = 0.78,
        reserveMaturity: Double = 0,
        lifetimeSavings: Double = 0,
        categoryTotals: [SpendingCategory: Double],
        buildingTotals: [String: Double] = [:],
        habits: BehavioralHabits = BehavioralHabits(),
        enrichmentIds: [String] = [],
        newlyUnlockedEnrichmentId: String? = nil,
        slotPlacements: [String: String] = [:],
        selectedDistrict: String?,
        language: String = "he",
        isPaused: Bool = false,
        onSelectDistrict: @escaping (String?) -> Void,
        onBuildingSelected: @escaping (DistrictBuildingInfo) -> Void,
        onSlotTapped: ((String, String?) -> Void)? = nil
    ) {
        self.totalSpent = totalSpent
        self.totalSavings = totalSavings
        self.savingsTarget = savingsTarget
        self.parkHealth = parkHealth
        self.reserveMaturity = reserveMaturity
        self.lifetimeSavings = lifetimeSavings
        self.categoryTotals = categoryTotals
        self.buildingTotals = buildingTotals
        self.habits = habits
        self.enrichmentIds = enrichmentIds
        self.newlyUnlockedEnrichmentId = newlyUnlockedEnrichmentId
        self.slotPlacements = slotPlacements
        self.selectedDistrict = selectedDistrict
        self.language = language
        self.isPaused = isPaused
        self.onSelectDistrict = onSelectDistrict
        self.onBuildingSelected = onBuildingSelected
        self.onSlotTapped = onSlotTapped
    }
    
    #if canImport(UIKit)
    public func makeUIView(context: Context) -> WKWebView {
        createWebView(context: context)
    }
    public func updateUIView(_ webView: WKWebView, context: Context) {
        updateData(in: webView, coordinator: context.coordinator)
    }
    #elseif canImport(AppKit)
    public func makeNSView(context: Context) -> WKWebView {
        createWebView(context: context)
    }
    public func updateNSView(_ webView: WKWebView, context: Context) {
        updateData(in: webView, coordinator: context.coordinator)
    }
    #endif
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public struct DioramaDataPayload: Codable, Sendable {
        public struct FoodSub: Codable, Sendable {
            public let restaurant: Double
            public let groceries: Double
            public let coffee: Double
            public let delivery: Double
        }
        public struct ShoppingSub: Codable, Sendable {
            public let fashion: Double
            public let tech: Double
            public let travel: Double
            public let entertainment: Double
        }
        public struct HousingSub: Codable, Sendable {
            public let rent: Double
            public let utilities: Double
            public let subs: Double
        }
        public struct HabitsPayload: Codable, Sendable {
            public let woltCount: Int
            public let coffeeCount: Int
            public let onlinePackagesCount: Int
            public let hasTravelOrFlight: Bool
            public let activeSubscriptionsCount: Int
        }
        
        public let food: Double
        public let foodSub: FoodSub
        public let shopping: Double
        public let shoppingSub: ShoppingSub
        public let housing: Double
        public let housingSub: HousingSub
        public let transport: Double
        public let savings: Double
        /// What a full savings park is worth for this user. 0 when there is no baseline.
        public let savingsTarget: Double
        /// How the reserve looks this month, 0 parched to 1 lush.
        public let parkHealth: Double
        /// How grown the reserve is, from savings across every month.
        public let reserveMaturity: Double
        public let lifetimeSavings: Double
        public let otherAmount: Double?
        public let museumAmount: Double?
        public let pendingSortingCount: Int?
        public let targetDistrict: String?
        public let language: String
        public let enrichments: [String]
        public let newlyUnlockedId: String?
        public let slotPlacements: [String: String]
        public let habits: HabitsPayload
    }
    
    private var dataPayloadJSON: String {
        let bistroSpend = buildingTotals["food_bistro"] ?? 0
        let superSpend = buildingTotals["food_super"] ?? 0
        let coffeeSpend = buildingTotals["food_coffee"] ?? 0
        let woltSpend = buildingTotals["food_wolt"] ?? 0
        let food = bistroSpend + superSpend + coffeeSpend + woltSpend
        
        let boutiqueSpend = buildingTotals["shop_boutique"] ?? 0
        let techSpend = buildingTotals["shop_tech"] ?? 0
        let travelSpend = buildingTotals["shop_travel"] ?? 0
        let arcadeSpend = buildingTotals["shop_arcade"] ?? 0
        let shopping = boutiqueSpend + techSpend + travelSpend + arcadeSpend
        
        let towerSpend = buildingTotals["house_tower"] ?? 0
        let utilSpend = buildingTotals["house_util"] ?? 0
        let subsSpend = buildingTotals["house_subs"] ?? 0
        let housing = towerSpend + utilSpend + subsSpend
        
        let transport = categoryTotals[.transport] ?? 0
        let savings = totalSavings
        let otherSpend = buildingTotals["city_sorting_hub"] ?? (categoryTotals[.other] ?? 0)
        let museumSpend = buildingTotals["museum_curiosities"] ?? (categoryTotals[.miscellaneous] ?? 0)
        
        let payload = DioramaDataPayload(
            food: food,
            foodSub: .init(restaurant: bistroSpend, groceries: superSpend, coffee: coffeeSpend, delivery: woltSpend),
            shopping: shopping,
            shoppingSub: .init(fashion: boutiqueSpend, tech: techSpend, travel: travelSpend, entertainment: arcadeSpend),
            housing: housing,
            housingSub: .init(rent: towerSpend, utilities: utilSpend, subs: subsSpend),
            transport: transport,
            savings: savings,
            savingsTarget: savingsTarget,
            parkHealth: parkHealth,
            reserveMaturity: reserveMaturity,
            lifetimeSavings: lifetimeSavings,
            otherAmount: otherSpend,
            museumAmount: museumSpend,
            pendingSortingCount: (categoryTotals[.other] ?? 0) > 0 ? 1 : 0,
            targetDistrict: selectedDistrict,
            language: language,
            enrichments: enrichmentIds,
            newlyUnlockedId: newlyUnlockedEnrichmentId,
            slotPlacements: slotPlacements,
            habits: .init(
                woltCount: habits.woltDeliveryCount,
                coffeeCount: habits.coffeeCount,
                onlinePackagesCount: habits.onlinePackagesCount,
                hasTravelOrFlight: habits.hasTravelOrFlight,
                activeSubscriptionsCount: habits.activeSubscriptionsCount
            )
        )
        
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(payload),
           let jsonStr = String(data: data, encoding: .utf8) {
            return jsonStr
        }
        return "{}"
    }
    
    /// Explicit district JS that always fires — bypasses optional-nil omission in JSONEncoder
    private var districtJS: String {
        if let d = selectedDistrict {
            return "if(window.setDistrict){window.setDistrict('\(d)');}"
        } else {
            return "if(window.setDistrict){window.setDistrict(null);}"
        }
    }
    
    /// Pre-warms WebKit IPC and WebGL subsystem on app launch for zero-latency presentation
    @MainActor
    public static func warmUp() {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        if let htmlURL = Bundle.main.url(forResource: "diorama", withExtension: "html"),
           let htmlData = try? Data(contentsOf: htmlURL) {
            webView.load(htmlData, mimeType: "text/html", characterEncodingName: "UTF-8", baseURL: htmlURL.deletingLastPathComponent())
        }
    }
    
    private func createWebView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "buildingTapped")
        config.userContentController.add(context.coordinator, name: "districtSelected")
        config.userContentController.add(context.coordinator, name: "zoomReset")
        config.userContentController.add(context.coordinator, name: "dioramaReady")
        config.userContentController.add(context.coordinator, name: "citizenTapped")
        config.userContentController.add(context.coordinator, name: "slotTapped")
        
        // Inject current city data payload at document start
        let initScript = WKUserScript(
            source: "window._initialDataPayload = \(dataPayloadJSON);",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(initScript)
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        #if canImport(UIKit)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        #elseif canImport(AppKit)
        webView.setValue(false, forKey: "drawsBackground")
        #endif
        
        // Load with explicit UTF-8 encoding so Hebrew and non-ASCII strings never degrade to question marks
        if let htmlURL = Bundle.main.url(forResource: "diorama", withExtension: "html"),
           let htmlData = try? Data(contentsOf: htmlURL) {
            webView.load(htmlData, mimeType: "text/html", characterEncodingName: "UTF-8", baseURL: htmlURL.deletingLastPathComponent())
        } else if let htmlPath = Bundle.main.path(forResource: "diorama", ofType: "html"),
                  let htmlData = try? Data(contentsOf: URL(fileURLWithPath: htmlPath)) {
            webView.load(htmlData, mimeType: "text/html", characterEncodingName: "UTF-8", baseURL: URL(fileURLWithPath: htmlPath).deletingLastPathComponent())
        } else {
            #if SWIFT_PACKAGE
            if let moduleURL = Bundle.module.url(forResource: "diorama", withExtension: "html"),
               let htmlData = try? Data(contentsOf: moduleURL) {
                webView.load(htmlData, mimeType: "text/html", characterEncodingName: "UTF-8", baseURL: moduleURL.deletingLastPathComponent())
            }
            #endif
        }
        
        return webView
    }
    
    private func updateData(in webView: WKWebView, coordinator: Coordinator) {
        let pauseStr = isPaused ? "true" : "false"
        let js = """
        if(window.pauseDioramaRendering){
          window.pauseDioramaRendering(\(pauseStr));
        }
        if(!\(pauseStr)){
          if(window.setDioramaLanguage){
            window.setDioramaLanguage('\(language)');
          }
          if(window.updateDioramaData){
            window.updateDioramaData(\(dataPayloadJSON));
          } else {
            window._initialDataPayload = \(dataPayloadJSON);
          }
          // Always explicitly set district so zoom-out to city (null) never gets silently dropped
          \(districtJS)
        }
        """
        // SwiftUI re-runs updateUIView on every parent body evaluation. Pushing an
        // identical payload into the WebGL scene each time is pure waste, so skip it.
        guard coordinator.lastSentPayload != js else { return }
        coordinator.lastSentPayload = js

        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    public class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: ThreeDioramaView
        /// Last JS payload actually delivered to the scene, used to skip redundant updates.
        var lastSentPayload: String?

        init(_ parent: ThreeDioramaView) {
            self.parent = parent
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // The page was (re)loaded, so whatever was sent before is gone.
            lastSentPayload = nil
            parent.updateData(in: webView, coordinator: self)
        }
        
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "dioramaReady" {
                if let wv = message.webView {
                    lastSentPayload = nil
                    parent.updateData(in: wv, coordinator: self)
                }
                // Notify wrapper to hide the loading skeleton
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .dioramaReady, object: nil)
                }
            } else if message.name == "districtSelected", let distId = message.body as? String {
                parent.onSelectDistrict(distId)
            } else if message.name == "zoomReset" {
                parent.onSelectDistrict(nil)
            } else if message.name == "slotTapped", let dict = message.body as? [String: Any] {
                let slotId = dict["slotId"] as? String ?? ""
                let currentItem = dict["currentItem"] as? String
                parent.onSlotTapped?(slotId, currentItem)
            } else if message.name == "buildingTapped", let dict = message.body as? [String: Any] {
                let id = dict["id"] as? String ?? "b1"
                let district = dict["district"] as? String ?? "food"
                let name = dict["name"] as? String ?? "מסעדה"
                // Zero, not an invented figure: MainCityView recomputes all three from the
                // user's own transactions before anything is shown.
                let amount = dict["amount"] as? Double ?? 0
                let visits = dict["visits"] as? Int ?? 0
                let trend = dict["trend"] as? String ?? ""
                
                let info = DistrictBuildingInfo(id: id, districtId: district, name: name, amount: amount, visitCount: visits, trendText: trend)
                parent.onBuildingSelected(info)
            }
        }
    }
}
