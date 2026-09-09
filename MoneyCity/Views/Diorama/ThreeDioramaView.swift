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
    /// Bumped by the app every time the user asks for the city view back. The map resets its
    /// camera whenever this changes, which is the only way to reset a camera that is already
    /// in city mode.
    public let viewResetToken: Int
    /// Pulls the camera back for the month view, which is looked at rather than worked in.
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
    /// A building highlighted during the contextual first-use lesson.
    public let tutorialBuildingId: String?
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
        viewResetToken: Int = 0,
        isOverview: Bool = false,
        categoryTotals: [SpendingCategory: Double],
        buildingTotals: [String: Double] = [:],
        districtStates: [CityDistrictState] = [],
        venueStates: [CityVenueState] = [],
        habits: BehavioralHabits = BehavioralHabits(),
        enrichmentIds: [String] = [],
        newlyUnlockedEnrichmentId: String? = nil,
        slotPlacements: [String: String] = [:],
        selectedDistrict: String?,
        tutorialBuildingId: String? = nil,
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
        self.tutorialBuildingId = tutorialBuildingId
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
        context.coordinator.parent = self
        updateData(in: webView, coordinator: context.coordinator)
    }
    public static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.tearDown(webView)
    }
    #elseif canImport(AppKit)
    public func makeNSView(context: Context) -> WKWebView {
        createWebView(context: context)
    }
    public func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        updateData(in: webView, coordinator: context.coordinator)
    }
    public static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.tearDown(webView)
    }
    #endif
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public struct DioramaDataPayload: Codable, Sendable {
        public var schemaVersion: Int = 1
        public struct DistrictStatePayload: Codable, Sendable {
            public let id: String
            public let amount: Double
            public let share: Double
            public let activity: Double
            public let prominence: String
        }
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
        public let otherAmount: Double?
        public let museumAmount: Double?
        /// Pharmacy and everyday health spending. The map shows this as a small chemist's
        /// shop; without it the health category never appears in the city at all.
        public let healthAmount: Double?
        public let financeAmount: Double?
        public let districts: [DistrictStatePayload]
        public let venues: [CityVenueState]
        public let pendingSortingCount: Int?
        public let targetDistrict: String?
        public var tutorialBuildingId: String? = nil
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
        let healthSpend = buildingTotals["health_pharmacy"] ?? (categoryTotals[.health] ?? 0)
        let financeSpend = buildingTotals["finance_bank"] ?? (categoryTotals[.finance] ?? 0)
        
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
            otherAmount: otherSpend,
            museumAmount: museumSpend,
            healthAmount: healthSpend,
            financeAmount: financeSpend,
            districts: districtStates.map {
                DioramaDataPayload.DistrictStatePayload(
                    id: $0.id,
                    amount: $0.amount,
                    share: $0.share,
                    activity: $0.activity,
                    prominence: $0.prominence.rawValue
                )
            },
            venues: venueStates,
            pendingSortingCount: venueStates.first(where: { $0.id == "city_sorting_hub" })?.purchaseCount
                ?? ((categoryTotals[.other] ?? 0) > 0 ? 1 : 0),
            targetDistrict: selectedDistrict,
            tutorialBuildingId: tutorialBuildingId,
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
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(payload),
           let jsonStr = String(data: data, encoding: .utf8) {
            return jsonStr
        }
        assertionFailure("Diorama payload could not be encoded")
        MoneyCityLog.error("Diorama payload could not be encoded")
        return "null"
    }
    
    /// Explicit district JS that always fires — bypasses optional-nil omission in JSONEncoder
    private var districtJS: String {
        if let d = selectedDistrict {
            return "if(window.setDistrict){window.setDistrict('\(d)');}"
        } else {
            return "if(window.setDistrict){window.setDistrict(null);}"
        }
    }
    
    private func createWebView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "buildingTapped")
        config.userContentController.add(context.coordinator, name: "districtSelected")
        config.userContentController.add(context.coordinator, name: "zoomReset")
        config.userContentController.add(context.coordinator, name: "dioramaReady")
        config.userContentController.add(context.coordinator, name: "dioramaError")
        config.userContentController.add(context.coordinator, name: "citizenTapped")
        config.userContentController.add(context.coordinator, name: "slotTapped")
        
        // Inject current city data payload at document start
        let initScript = WKUserScript(
            source: "window._initialDataPayload = \(dataPayloadJSON); window._initialRenderPaused = \(isPaused || !context.coordinator.appIsActive ? "true" : "false"); window._initialPowerMode = '\(context.coordinator.powerMode)';",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(initScript)
        
        let webView = WKWebView(frame: .zero, configuration: config)
        context.coordinator.observeLifecycle(of: webView)
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
        guard !coordinator.isDisposed else { return }
        let paused = isPaused || !coordinator.appIsActive
        let controls = """
        window._initialRenderPaused = \(paused ? "true" : "false");
        window._initialPowerMode = '\(coordinator.powerMode)';
        if(window.pauseDioramaRendering){window.pauseDioramaRendering(window._initialRenderPaused);}
        if(window.setDioramaPowerMode){window.setDioramaPowerMode(window._initialPowerMode);}
        """
        // Do not even serialize the city while hidden. The latest model is sent on resume.
        let js: String
        if paused {
            js = controls
        } else {
            let payload = dataPayloadJSON
            js = controls + """
            if(window.updateDioramaData){window.updateDioramaData(\(payload));}
            else {window._initialDataPayload = \(payload);}
            \(districtJS)
            if(window.setCityOverview){window.setCityOverview(\(isOverview ? "true" : "false"));}
            if(window.resetCityView){window.resetCityView(\(viewResetToken));}
            """
        }
        guard coordinator.lastSentPayload != js else { return }
        coordinator.lastSentPayload = js
        webView.evaluateJavaScript(js) { [weak coordinator] _, error in
            if let error {
                if coordinator?.lastSentPayload == js { coordinator?.lastSentPayload = nil }
                MoneyCityLog.error("Diorama delivery failed: \(error.localizedDescription)")
            }
        }
    }
    
    public class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: ThreeDioramaView
        /// Last JS payload actually delivered to the scene, used to skip redundant updates.
        var lastSentPayload: String?
        private weak var observedWebView: WKWebView?
        private(set) var isDisposed = false
        private(set) var appIsActive: Bool = {
            #if canImport(UIKit)
            return UIApplication.shared.applicationState == .active
            #else
            return NSApplication.shared.isActive
            #endif
        }()
        var powerMode: String {
            let process = ProcessInfo.processInfo
            if process.thermalState == .critical { return "critical" }
            return process.isLowPowerModeEnabled || process.thermalState == .serious ? "economy" : "normal"
        }

        func observeLifecycle(of webView: WKWebView) {
            observedWebView = webView
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(powerChanged), name: .NSProcessInfoPowerStateDidChange, object: nil)
            center.addObserver(self, selector: #selector(powerChanged), name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
            #if canImport(UIKit)
            center.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
            center.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.didEnterBackgroundNotification, object: nil)
            center.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
            #else
            center.addObserver(self, selector: #selector(appWillResignActive), name: NSApplication.willResignActiveNotification, object: nil)
            center.addObserver(self, selector: #selector(appDidBecomeActive), name: NSApplication.didBecomeActiveNotification, object: nil)
            #endif
        }
        @objc private func appWillResignActive() {
            appIsActive = false
            refreshLifecycle()
        }
        @objc private func appDidBecomeActive() {
            appIsActive = true
            refreshLifecycle()
        }
        @objc private func powerChanged() {
            // ProcessInfo notifications need not arrive on the UI thread.
            DispatchQueue.main.async { [weak self] in self?.refreshLifecycle() }
        }
        private func refreshLifecycle() {
            guard !isDisposed, let webView = observedWebView else { return }
            parent.updateData(in: webView, coordinator: self)
        }
        func tearDown(_ webView: WKWebView) {
            isDisposed = true
            NotificationCenter.default.removeObserver(self)
            webView.evaluateJavaScript("if(window.disposeDioramaRendering){window.disposeDioramaRendering();}", completionHandler: nil)
            webView.stopLoading()
            webView.navigationDelegate = nil
            webView.configuration.userContentController.removeAllScriptMessageHandlers()
            webView.configuration.userContentController.removeAllUserScripts()
            observedWebView = nil
        }
        deinit { NotificationCenter.default.removeObserver(self) }

        init(_ parent: ThreeDioramaView) {
            self.parent = parent
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // The page was (re)loaded, so whatever was sent before is gone.
            lastSentPayload = nil
            parent.updateData(in: webView, coordinator: self)
        }
        
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "dioramaError" {
                lastSentPayload = nil
                MoneyCityLog.error("Diorama contract/rendering failure: \(message.body)")
                assertionFailure("Diorama contract/rendering failure: \(message.body)")
            } else if message.name == "dioramaReady" {
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
