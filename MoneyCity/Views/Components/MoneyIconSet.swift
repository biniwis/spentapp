import SwiftUI

// MARK: - MoneyCity Signature Icon Design System
// Matches the bold-outline, colorful flat-fill, modern doodle/cartoon aesthetic
// based on the canonical 70-icon reference set.

public struct IconPalette {
    public static let black  = Color(red: 24/255, green: 24/255, blue: 27/255)  // #18181B (crisp outline)
    public static let yellow = Color(red: 255/255, green: 197/255, blue: 41/255) // #FFC529 (sunny gold)
    public static let blue   = Color(red: 37/255, green: 140/255, blue: 244/255) // #258CF4 (azure sky)
    public static let green  = Color(red: 34/255, green: 197/255, blue: 94/255)  // #22C55E (fresh emerald)
    public static let red    = Color(red: 255/255, green: 87/255, blue: 87/255)  // #FF5757 (warm coral red)
    public static let coral  = Color(red: 251/255, green: 113/255, blue: 133/255)// #FB7185 (soft rose coral)
    public static let purple = Color(red: 168/255, green: 85/255, blue: 247/255)// #A855F7 (vibrant violet)
    public static let orange = Color(red: 249/255, green: 115/255, blue: 22/255) // #F97316 (warm orange)
    public static let white  = Color.white
}

// MARK: - Icon Catalog Enum
public enum MoneyIconType: String, CaseIterable, Sendable {
    // Row 1
    case home
    case barChart
    case creditCard
    case receipt
    case coins
    case pieChart
    case calendar
    case bell
    case search
    case gear

    // Row 2
    case plusCircle
    case minusCircle
    case upload
    case download
    case exchange
    case camera
    case photo
    case scan
    case sliders
    case chatDots

    // Row 3
    case cart
    case cutlery
    case coffee
    case car
    case gasPump
    case bus
    case airplane
    case dumbbell
    case gamepad
    case paw

    // Row 4
    case medicalCross
    case gradCap
    case shoppingBag
    case tshirt
    case gift
    case ticket
    case heart
    case star
    case island
    case suitcase

    // Row 5
    case mail
    case chatSmile
    case phone
    case paperPlane
    case document
    case folder
    case trash
    case pencil
    case bookmark
    case flag

    // Row 6
    case clock
    case refresh
    case cloud
    case sun
    case moon
    case lightning
    case leaf
    case waterDrop
    case flame
    case snowflake

    // Row 7
    case checkCircle
    case xmarkCircle
    case warningCircle
    case infoCircle
    case questionCircle
    case mapPin
    case navigation
    case globe
    case trophy
    case user

    // Complementary utility icons in identical style
    case chevronLeft
    case chevronRight
    case chevronDown
    case chevronUp
    case backspace
    case target
    case lock
    case citySkyline
}

public typealias MoneyIconName = MoneyIconType

// MARK: - Universal MoneyIcon View
public struct MoneyIcon: View {
    public let type: MoneyIconType
    public let size: CGFloat
    public let customColor: Color?

    public init(_ type: MoneyIconType, size: CGFloat = 24, color: Color? = nil) {
        self.type = type
        self.size = size
        self.customColor = color
    }

    public var body: some View {
        MoneyIconRenderer(type: type, overrideColor: customColor)
            .scaleEffect(size / 24.0)
            .frame(width: size, height: size)
    }
}

// MARK: - Internal Icon Renderer
struct MoneyIconRenderer: View {
    let type: MoneyIconType
    let overrideColor: Color?

    var strokeWidth: CGFloat { 2.0 }
    var black: Color { IconPalette.black }

    var body: some View {
        ZStack {
            switch type {
            // Row 1
            case .home:         homeIcon
            case .barChart:     barChartIcon
            case .creditCard:   creditCardIcon
            case .receipt:      receiptIcon
            case .coins:        coinsIcon
            case .pieChart:     pieChartIcon
            case .calendar:     calendarIcon
            case .bell:         bellIcon
            case .search:       searchIcon
            case .gear:         gearIcon

            // Row 2
            case .plusCircle:   plusCircleIcon
            case .minusCircle:  minusCircleIcon
            case .upload:       uploadIcon
            case .download:     downloadIcon
            case .exchange:     exchangeIcon
            case .camera:       cameraIcon
            case .photo:        photoIcon
            case .scan:         scanIcon
            case .sliders:      slidersIcon
            case .chatDots:     chatDotsIcon

            // Row 3
            case .cart:         cartIcon
            case .cutlery:      cutleryIcon
            case .coffee:       coffeeIcon
            case .car:          carIcon
            case .gasPump:      gasPumpIcon
            case .bus:          busIcon
            case .airplane:     airplaneIcon
            case .dumbbell:     dumbbellIcon
            case .gamepad:      gamepadIcon
            case .paw:          pawIcon

            // Row 4
            case .medicalCross: medicalCrossIcon
            case .gradCap:      gradCapIcon
            case .shoppingBag:  shoppingBagIcon
            case .tshirt:       tshirtIcon
            case .gift:         giftIcon
            case .ticket:       ticketIcon
            case .heart:        heartIcon
            case .star:         starIcon
            case .island:       islandIcon
            case .suitcase:     suitcaseIcon

            // Row 5
            case .mail:         mailIcon
            case .chatSmile:    chatSmileIcon
            case .phone:        phoneIcon
            case .paperPlane:   paperPlaneIcon
            case .document:     documentIcon
            case .folder:       folderIcon
            case .trash:        trashIcon
            case .pencil:       pencilIcon
            case .bookmark:     bookmarkIcon
            case .flag:         flagIcon

            // Row 6
            case .clock:        clockIcon
            case .refresh:      refreshIcon
            case .cloud:        cloudIcon
            case .sun:          sunIcon
            case .moon:         moonIcon
            case .lightning:    lightningIcon
            case .leaf:         leafIcon
            case .waterDrop:    waterDropIcon
            case .flame:        flameIcon
            case .snowflake:    snowflakeIcon

            // Row 7
            case .checkCircle:    checkCircleIcon
            case .xmarkCircle:    xmarkCircleIcon
            case .warningCircle:  warningCircleIcon
            case .infoCircle:     infoCircleIcon
            case .questionCircle: questionCircleIcon
            case .mapPin:         mapPinIcon
            case .navigation:     navigationIcon
            case .globe:          globeIcon
            case .trophy:         trophyIcon
            case .user:           userIcon

            // Utilities
            case .chevronLeft:    chevronLeftIcon
            case .chevronRight:   chevronRightIcon
            case .chevronDown:    chevronDownIcon
            case .chevronUp:      chevronUpIcon
            case .backspace:      backspaceIcon
            case .target:         targetIcon
            case .lock:           lockIcon
            case .citySkyline:    citySkylineIcon
            }
        }
        .frame(width: 24, height: 24)
    }

}
