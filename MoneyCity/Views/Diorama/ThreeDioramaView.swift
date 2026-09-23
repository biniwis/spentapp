import SwiftUI
import WebKit

#if canImport(UIKit)
import UIKit
public typealias ViewRepresentable = UIViewRepresentable

/// Lightweight WKWebView subclass providing a surgical fallback against text-editing actions
final class DioramaWebView: WKWebView {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(copy(_:)) || action == #selector(select(_:)) || action == #selector(selectAll(_:)) {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }
}
#elseif canImport(AppKit)
import AppKit
public typealias ViewRepresentable = NSViewRepresentable
typealias DioramaWebView = WKWebView
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
    #if DEBUG
    // Only Design Lab supplies this session. Production selects its world through mapStyle.
    var worldPreviewSession: CityWorldPreviewSession?

    func worldPreview(_ session: CityWorldPreviewSession) -> Self {
        var view = self
        view.worldPreviewSession = session
        return view
    }
    #endif
    public let mapStyle: CityMapStyle
    public let isDistrictSample: Bool
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
    public let selectedBuildingId: String?
    public let buildingFocusRequest: CityBuildingFocusRequest?
    /// A building highlighted during the contextual first-use lesson.
    public let tutorialBuildingId: String?
    public let language: String
    public let isPaused: Bool
    public let timeOfDayOverride: Double?
    public let onSelectDistrict: (String?) -> Void
    public let onBuildingSelected: (DistrictBuildingInfo) -> Void
    public let onSlotTapped: ((String, String?) -> Void)?
    public let onCameraOffsetChanged: ((Bool) -> Void)?
    
    /// Current device local time represented as a floating hour (e.g. 14.5 for 14:30)
    public static var currentDeviceLocalHour: Double {
        let cal = Calendar.current
        let comp = cal.dateComponents([.hour, .minute, .second], from: Date())
        let h = Double(comp.hour ?? 12)
        let m = Double(comp.minute ?? 0)
        let s = Double(comp.second ?? 0)
        return h + (m / 60.0) + (s / 3600.0)
    }
    
    public init(
        mapStyle: CityMapStyle = .urban,
        isDistrictSample: Bool = false,
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
        selectedBuildingId: String? = nil,
        buildingFocusRequest: CityBuildingFocusRequest? = nil,
        tutorialBuildingId: String? = nil,
        language: String = "he",
        isPaused: Bool = false,
        timeOfDayOverride: Double? = nil,
        onSelectDistrict: @escaping (String?) -> Void,
        onBuildingSelected: @escaping (DistrictBuildingInfo) -> Void,
        onSlotTapped: ((String, String?) -> Void)? = nil,
        onCameraOffsetChanged: ((Bool) -> Void)? = nil
    ) {
        self.mapStyle = mapStyle
        self.isDistrictSample = isDistrictSample
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
        self.buildingFocusRequest = buildingFocusRequest
        self.tutorialBuildingId = tutorialBuildingId
        self.language = language
        self.isPaused = isPaused
        self.timeOfDayOverride = timeOfDayOverride
        self.onSelectDistrict = onSelectDistrict
        self.onBuildingSelected = onBuildingSelected
        self.onSlotTapped = onSlotTapped
        self.onCameraOffsetChanged = onCameraOffsetChanged
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
            /// Named delivery intensity tier: "quiet" | "normal" | "active" | "high" | "extreme"
            public let deliveryTier: String
            /// 0–1 frequency score for the delivery tier (drives actor counts and crowd).
            public let deliveryFrequencyScore: Double
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
                activeSubscriptionsCount: habits.activeSubscriptionsCount,
                deliveryTier: habits.deliveryIntensity.tier.rawValue,
                deliveryFrequencyScore: habits.deliveryIntensity.frequencyScore
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
    
    public static let knownDistrictIds: Set<String> = [
        "food", "shopping", "housing", "transport", "entertainment",
        "health", "subscriptions", "finance", "savings", "miscellaneous",
        "other", "civic", "city", "groceries", "coffee", "misc"
    ]

    public static let knownSlotIds: Set<String> = [
        "slot_tree_sakura", "slot_pet_golden_dog", "slot_repair_bench",
        "slot_park_bridge", "slot_fountain_marble", "slot_cafe_stand",
        "slot_resident_artist", "slot_repair_lamp", "slot_pet_cat_rooftop",
        "slot_bike_station", "slot_flower_bed_plaza", "slot_public_art_sculpture",
        "slot_repair_sidewalk", "slot_park_center", "slot_park_overlook",
        "slot_food_plaza", "slot_shop_promenade", "slot_housing_terrace",
        "slot_tech_plaza"
    ]

    public static let knownEnrichmentIds: Set<String> = [
        "tree_sakura", "flower_bed_plaza", "repair_bench", "repair_lamp",
        "resident_artist", "pet_cat_rooftop", "bike_station", "cafe_stand",
        "repair_sidewalk", "fountain_marble", "pet_golden_dog", "park_bridge",
        "public_art_sculpture"
    ]

    static func jsonLiteral<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let str = String(data: data, encoding: .utf8) else {
            return "null"
        }
        return str
    }

    /// Explicit district JS that always fires — bypasses optional-nil omission in JSONEncoder
    private var districtJS: String {
        if let d = selectedDistrict, Self.knownDistrictIds.contains(d) {
            let encoded = Self.jsonLiteral(d)
            return "if(window.setDistrict){window.setDistrict(\(encoded));}"
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
        config.userContentController.add(context.coordinator, name: "cameraOffsetChanged")
        
        // Inject current city data payload at document start
        let currentHour = timeOfDayOverride ?? Self.currentDeviceLocalHour
        let safeHour = currentHour.isFinite ? (currentHour * 100).rounded() / 100.0 : 12.0
        let powerLiteral = Self.jsonLiteral(context.coordinator.powerMode)
        // Arctic is a presentation skin of the shared city, including its live simulation.
        var isArctic = mapStyle == .arctic
        var isIsrael = mapStyle == .israel
        var isFuture = mapStyle == .future
        #if DEBUG
        if let session = worldPreviewSession {
            isArctic = session.world == .arctic
            isIsrael = session.world == .israel
            isFuture = session.world == .future
        }
        #endif
        let initScript = WKUserScript(
            source: "window._futureWorld = \(isFuture ? "true" : "false"); window._israelWorld = \(isIsrael ? "true" : "false"); window._arcticWorld = \(isArctic ? "true" : "false"); window._districtSample = \(isDistrictSample ? "true" : "false"); window._initialDataPayload = \(dataPayloadJSON); window._initialRenderPaused = \(isPaused || !context.coordinator.appIsActive ? "true" : "false"); window._initialPowerMode = \(powerLiteral); window._initialTimeOfDay = \(safeHour);",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(initScript)
        
        let webView = DioramaWebView(frame: .zero, configuration: config)
        context.coordinator.observeLifecycle(of: webView)
        webView.navigationDelegate = context.coordinator
        #if DEBUG
        if let session = worldPreviewSession {
            session.attach(webView)
        }
        #endif
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
        loadDioramaResource(into: webView, resourceName: resolvedResourceName)
        
        return webView
    }
    
    /// The bundled HTML the current view must use — the map's own resource, or the
    /// Design Lab override when one is active. Recovery must never fall back to a
    /// hard-coded default world.
    private var resolvedResourceName: String {
        var resourceName = mapStyle.resourceName
        #if DEBUG
        if let session = worldPreviewSession {
            resourceName = session.world.resourceName
        }
        #endif
        return resourceName
    }
    
    /// Single place that loads the bundled city HTML into a web view. Both the initial
    /// creation and renderer recovery go through here so they can never drift apart.
    private func loadDioramaResource(into webView: WKWebView, resourceName: String) {
        if let htmlURL = Bundle.main.url(forResource: resourceName, withExtension: "html"),
           let htmlData = try? Data(contentsOf: htmlURL) {
            webView.load(htmlData, mimeType: "text/html", characterEncodingName: "UTF-8", baseURL: htmlURL.deletingLastPathComponent())
        } else if let htmlPath = Bundle.main.path(forResource: resourceName, ofType: "html"),
                  let htmlData = try? Data(contentsOf: URL(fileURLWithPath: htmlPath)) {
            webView.load(htmlData, mimeType: "text/html", characterEncodingName: "UTF-8", baseURL: URL(fileURLWithPath: htmlPath).deletingLastPathComponent())
        } else {
            #if DEBUG
            worldPreviewSession?.fail("Missing bundled resource: \(resourceName).html")
            #endif
            #if SWIFT_PACKAGE
            if let moduleURL = Bundle.module.url(forResource: resourceName, withExtension: "html"),
               let htmlData = try? Data(contentsOf: moduleURL) {
                webView.load(htmlData, mimeType: "text/html", characterEncodingName: "UTF-8", baseURL: moduleURL.deletingLastPathComponent())
            }
            #endif
        }
    }
    
    private func updateData(in webView: WKWebView, coordinator: Coordinator) {
        guard !coordinator.isDisposed else { return }
        let paused = isPaused || !coordinator.appIsActive
        // The renderer died while the city was hidden; do not send JS into a dead
        // Web Content Process. Restore the scene now that the city is actually visible.
        if coordinator.needsRendererRecovery && !paused {
            coordinator.recoverRendererIfNeeded()
            return
        }
        let currentHour = timeOfDayOverride ?? Self.currentDeviceLocalHour
        let isOverride = timeOfDayOverride != nil
        let animateTime = !isOverride && !coordinator.isInitialDelivery
        coordinator.isInitialDelivery = false
        let roundedHour = currentHour.isFinite ? (currentHour * 100).rounded() / 100.0 : 12.0

        let timeControl = "if(window.setTimeOfDay){window.setTimeOfDay(\(roundedHour), \(animateTime ? "true" : "false"));}"

        let powerLiteral = Self.jsonLiteral(coordinator.powerMode)
        let controls = """
        window._initialRenderPaused = \(paused ? "true" : "false");
        window._initialPowerMode = \(powerLiteral);
        if(window.pauseDioramaRendering){window.pauseDioramaRendering(window._initialRenderPaused);}
        if(window.setDioramaPowerMode){window.setDioramaPowerMode(window._initialPowerMode);}
        \(timeControl)
        """
        // Do not even serialize the city while hidden. The latest model is sent on resume.
        var js: String
        if paused {
            coordinator.stopTimeTimer()
            js = controls
        } else {
            coordinator.startTimeTimer()
            let payload = dataPayloadJSON
            var script = controls + """
            if(window.updateDioramaData){window.updateDioramaData(\(payload));}
            else {window._initialDataPayload = \(payload);}
            \(districtJS)
            if(window.setCityOverview){window.setCityOverview(\(isOverview ? "true" : "false"));}
            if(window.resetCityView){window.resetCityView(\(viewResetToken));}
            """
            if let bId = selectedBuildingId, CityBuilding.allKnownBuildingIds.contains(bId) {
                let bIdLiteral = Self.jsonLiteral(bId)
                script += "\nif(window.selectDioramaBuilding){window.selectDioramaBuilding(\(bIdLiteral));}"
            } else {
                script += "\nif(window.selectDioramaBuilding){window.selectDioramaBuilding(null);}"
            }
            if let focus = buildingFocusRequest, focus.id != coordinator.lastHandledFocusToken {
                coordinator.lastHandledFocusToken = focus.id
                let validBuildingId = CityBuilding.allKnownBuildingIds.contains(focus.buildingId) ? focus.buildingId : "city_sorting_hub"
                let bIdArg = Self.jsonLiteral(validBuildingId)
                let safeAmount = focus.amount.isFinite ? focus.amount : 0.0
                let tokenArg = Self.jsonLiteral(focus.id.uuidString)
                let rawAmtText = focus.formattedAmount ?? "\(safeAmount)"
                let safeAmtText = InputSanitizer.sanitizeSingleLine(rawAmtText, maxLength: 64)
                let amtTextArg = Self.jsonLiteral(safeAmtText)
                let refundArg = focus.isRefund ? "true" : "false"
                script += "\nif(window.focusDioramaBuilding){window.focusDioramaBuilding(\(bIdArg), \(safeAmount), \(tokenArg), \(amtTextArg), \(refundArg));}"
            }
            js = script
        }
        // Apply after navigation/camera updates too: SwiftUI can reuse an existing WebView.
        js += "\nwindow._districtSample = \(isDistrictSample ? "true" : "false"); if(window.setDistrictSample){window.setDistrictSample(window._districtSample);}"
        guard coordinator.lastSentPayload != js else { return }
        coordinator.lastSentPayload = js
        let recoveryGenerationAtSend = coordinator.recoveryGeneration
        webView.evaluateJavaScript(js) { [weak coordinator] _, error in
            if let error {
                if coordinator?.lastSentPayload == js { coordinator?.lastSentPayload = nil }
                MoneyCityLog.error("Diorama delivery failed: \(error.localizedDescription)")
                // Only a dead Web Content Process / invalidated web view justifies a reload.
                // Any other JS error is a regular bug and must not trigger recovery, or a
                // transient JS mistake could cause an endless reload loop.
                guard let coordinator else { return }
                // If a recovery reload already started after this script was sent, the error
                // is stale — ignore it instead of reloading a scene that is being restored.
                guard coordinator.recoveryGeneration == recoveryGenerationAtSend else { return }
                let nsError = error as NSError
                if nsError.domain == WKErrorDomain,
                   let code = WKError.Code(rawValue: nsError.code),
                   code == .webContentProcessTerminated || code == .webViewInvalidated {
                    coordinator.needsRendererRecovery = true
                    coordinator.recoverRendererIfNeeded()
                }
            }
        }
    }
    
    public class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: ThreeDioramaView
        /// Last JS payload actually delivered to the scene, used to skip redundant updates.
        var lastSentPayload: String?
        var isInitialDelivery = true
        var lastHandledFocusToken: UUID?
        private var timeTimer: Timer?
        private weak var observedWebView: WKWebView?
        private(set) var isDisposed = false
        /// Set when the Web Content Process died and the scene needs a reload before it can
        /// render again. Stays set while recovery is deferred (app background / city hidden).
        var needsRendererRecovery = false
        /// Set only while a recovery reload is actually in flight; blocks duplicate reloads.
        var isRecoveringRenderer = false
        /// Bumped every time a recovery reload starts. A JS delivery error that belongs to a
        /// script sent before a reload must be ignored — the reload already superseded it.
        var recoveryGeneration = 0
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

        func startTimeTimer() {
            stopTimeTimer()
            guard !isDisposed, appIsActive, !parent.isPaused, !isRecoveringRenderer else { return }
            timeTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
                guard let self = self, !self.isDisposed, self.appIsActive, !self.parent.isPaused else { return }
                guard self.parent.timeOfDayOverride == nil else { return }
                guard let webView = self.observedWebView else { return }
                let hour = (ThreeDioramaView.currentDeviceLocalHour * 100).rounded() / 100.0
                let safeHour = hour.isFinite ? hour : 12.0
                webView.evaluateJavaScript("if(window.setTimeOfDay){window.setTimeOfDay(\(safeHour), true);}", completionHandler: nil)
            }
        }

        func stopTimeTimer() {
            timeTimer?.invalidate()
            timeTimer = nil
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
            startTimeTimer()
        }
        @objc private func appWillResignActive() {
            appIsActive = false
            stopTimeTimer()
            refreshLifecycle()
        }
        @objc private func appDidBecomeActive() {
            appIsActive = true
            if needsRendererRecovery {
                recoverRendererIfNeeded()
            } else {
                refreshLifecycle()
            }
            // The timer guard keeps it off while a recovery reload is in flight.
            startTimeTimer()
        }
        @objc private func powerChanged() {
            // ProcessInfo notifications need not arrive on the UI thread.
            DispatchQueue.main.async { [weak self] in self?.refreshLifecycle() }
        }
        private func refreshLifecycle() {
            guard !isDisposed, let webView = observedWebView else { return }
            parent.updateData(in: webView, coordinator: self)
        }
        /// Pure gate for renderer recovery. Kept internal (not private) so the decision matrix
        /// can be unit-tested without faking a WKWebView.
        static func shouldRecover(
            isDisposed: Bool,
            needsRendererRecovery: Bool,
            isRecoveringRenderer: Bool,
            appIsActive: Bool,
            isPaused: Bool
        ) -> Bool {
            guard !isDisposed, needsRendererRecovery, !isRecoveringRenderer, appIsActive, !isPaused else { return false }
            return true
        }
        /// Reloads the same bundled HTML after the Web Content Process was killed, but only
        /// while the city is actually visible and the app is active. When it is not, the
        /// pending flag stays set so the scene restores the moment it should be seen again.
        func recoverRendererIfNeeded() {
            guard !isDisposed else { return }
            guard Self.shouldRecover(
                isDisposed: isDisposed,
                needsRendererRecovery: needsRendererRecovery,
                isRecoveringRenderer: isRecoveringRenderer,
                appIsActive: appIsActive,
                isPaused: parent.isPaused
            ) else { return }
            guard let webView = observedWebView else { return }

            needsRendererRecovery = false
            isRecoveringRenderer = true
            recoveryGeneration &+= 1
            lastSentPayload = nil
            isInitialDelivery = true

            MoneyCityLog.error("Diorama renderer recovery started")
            DispatchQueue.main.async { [weak self] in
                NotificationCenter.default.post(name: .dioramaRecoveryStarted, object: nil)
            }

            // Reload the bundled HTML directly (never webView.reload), so recovery reuses the
            // exact same resource and map style the view was created with. The configuration's
            // atDocumentStart user script re-injects the seed payload on this load, and the
            // didFinish handler re-delivers all current city state.
            parent.loadDioramaResource(into: webView, resourceName: parent.resolvedResourceName)
        }
        func tearDown(_ webView: WKWebView) {
            isDisposed = true
            needsRendererRecovery = false
            isRecoveringRenderer = false
            stopTimeTimer()
            NotificationCenter.default.removeObserver(self)
            webView.evaluateJavaScript("if(window.disposeDioramaRendering){window.disposeDioramaRendering();}", completionHandler: nil)
            webView.stopLoading()
            webView.navigationDelegate = nil
            webView.configuration.userContentController.removeAllScriptMessageHandlers()
            webView.configuration.userContentController.removeAllUserScripts()
            observedWebView = nil
        }
        deinit {
            stopTimeTimer()
            NotificationCenter.default.removeObserver(self)
        }

        init(_ parent: ThreeDioramaView) {
            self.parent = parent
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // A recovery reload finished: release the in-flight guard so a future
            // termination can be handled, and let updateData re-deliver all current state.
            if isRecoveringRenderer {
                isRecoveringRenderer = false
                needsRendererRecovery = false
                MoneyCityLog.error("Diorama renderer recovery completed")
            }
            // The page was (re)loaded, so whatever was sent before is gone.
            lastSentPayload = nil
            parent.updateData(in: webView, coordinator: self)
            #if DEBUG
            parent.worldPreviewSession?.finishLoading(webView)
            #endif
        }

        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            // Allow local file/bundle loading and about:blank
            if url.isFileURL || url.absoluteString == "about:blank" {
                decisionHandler(.allow)
                return
            }
            // Block all external network navigation (http, https, arbitrary custom schemes)
            MoneyCityLog.error("Blocked unauthorized navigation in Diorama WebView: \(url.absoluteString)")
            decisionHandler(.cancel)
        }

        #if DEBUG
        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.worldPreviewSession?.fail(error.localizedDescription)
            didFailRecoveryLoadIfNeeded(error)
        }

        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.worldPreviewSession?.fail(error.localizedDescription)
            didFailRecoveryLoadIfNeeded(error)
        }
        #endif

        /// A recovery reload that failed must leave recovery pending again so the next visible
        /// city update retries — without queuing an immediate second reload (no reload loop).
        private func didFailRecoveryLoadIfNeeded(_ error: Error) {
            guard !isDisposed, isRecoveringRenderer else { return }
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled { return }
            isRecoveringRenderer = false
            needsRendererRecovery = true
            MoneyCityLog.error("Diorama renderer recovery failed: \(error.localizedDescription)")
        }

        /// iOS can kill the Web Content Process while the app is backgrounded or under memory
        /// pressure. Detection runs in production: the surviving SwiftUI view would otherwise
        /// keep sending JavaScript into a dead renderer and show a blank city until the app is
        /// force-quit. Recovery itself is deferred until the city is genuinely visible again.
        public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard !isDisposed else { return }

            lastSentPayload = nil
            needsRendererRecovery = true
            isRecoveringRenderer = false
            stopTimeTimer()

            MoneyCityLog.error("Diorama renderer process terminated")

            #if DEBUG
            parent.worldPreviewSession?.fail("The 3D renderer stopped. Automatic recovery scheduled.")
            #endif

            recoverRendererIfNeeded()
            if needsRendererRecovery {
                let reason = parent.isPaused
                    ? "because scene is paused"
                    : (!appIsActive ? "because app is inactive" : "because renderer is unavailable")
                MoneyCityLog.error("Diorama recovery deferred \(reason)")
            }
        }
        
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "dioramaError" {
                #if DEBUG
                if let session = parent.worldPreviewSession {
                    session.fail("\(message.body)")
                    return
                }
                #endif
                lastSentPayload = nil
                MoneyCityLog.error("Diorama contract/rendering failure: \(message.body)")
                // A renderer/content error must not terminate the app in DEBUG. Keep the
                // WebView alive so the concrete JavaScript error can be inspected and the
                // city can recover on the next update.
            } else if message.name == "dioramaReady" {
                if let wv = message.webView {
                    lastSentPayload = nil
                    parent.updateData(in: wv, coordinator: self)
                }
                // Notify wrapper to hide the loading skeleton
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .dioramaReady, object: nil)
                }
            } else if message.name == "districtSelected", let rawDistId = message.body as? String {
                let distId = InputSanitizer.sanitizeIdentifier(rawDistId)
                if ThreeDioramaView.knownDistrictIds.contains(distId) {
                    parent.onSelectDistrict(distId)
                } else {
                    MoneyCityLog.error("Rejected unknown district ID from JS: \(distId)")
                }
            } else if message.name == "zoomReset" {
                parent.onSelectDistrict(nil)
            } else if message.name == "slotTapped", let dict = message.body as? [String: Any] {
                guard let rawSlotId = dict["slotId"] as? String else { return }
                let slotId = InputSanitizer.sanitizeIdentifier(rawSlotId)
                guard ThreeDioramaView.knownSlotIds.contains(slotId) || slotId.hasPrefix("slot_") else {
                    MoneyCityLog.error("Rejected unknown slot ID from JS: \(slotId)")
                    return
                }
                let rawCurrentItem = dict["currentItem"] as? String
                let currentItem: String? = rawCurrentItem.flatMap { item in
                    let sanitized = InputSanitizer.sanitizeIdentifier(item)
                    return ThreeDioramaView.knownEnrichmentIds.contains(sanitized) ? sanitized : nil
                }
                parent.onSlotTapped?(slotId, currentItem)
            } else if message.name == "buildingTapped", let dict = message.body as? [String: Any] {
                guard let rawId = dict["id"] as? String else { return }
                let id = InputSanitizer.sanitizeIdentifier(rawId)
                guard CityBuilding.allKnownBuildingIds.contains(id) else {
                    MoneyCityLog.error("Rejected unknown building ID from JS: \(id)")
                    return
                }
                let rawDistrict = dict["district"] as? String ?? "food"
                let district = ThreeDioramaView.knownDistrictIds.contains(rawDistrict) ? rawDistrict : "civic"
                let rawName = dict["name"] as? String ?? AppLanguage.localized("מסעדה", "Restaurant")
                let name = InputSanitizer.sanitizeSingleLine(rawName, maxLength: 100)
                let rawAmount = dict["amount"] as? Double ?? 0
                let amount = rawAmount.isFinite ? rawAmount : 0
                let rawVisits = dict["visits"] as? Int ?? 0
                let visits = max(0, min(100_000, rawVisits))
                let rawTrend = dict["trend"] as? String ?? ""
                let trend = InputSanitizer.sanitizeSingleLine(rawTrend, maxLength: 100)
                
                let info = DistrictBuildingInfo(id: id, districtId: district, name: name, amount: amount, visitCount: visits, trendText: trend)
                parent.onBuildingSelected(info)
            } else if message.name == "cameraOffsetChanged", let isOff = message.body as? Bool {
                parent.onCameraOffsetChanged?(isOff)
            }
        }
    }
}
