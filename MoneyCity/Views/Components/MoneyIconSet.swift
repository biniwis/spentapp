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
private struct MoneyIconRenderer: View {
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

    // MARK: - Row 1 Implementations

    private var homeIcon: some View {
        ZStack {
            // Walls
            RoundedRectangle(cornerRadius: 1.5)
                .fill(overrideColor != nil ? overrideColor!.opacity(0.18) : IconPalette.white)
                .frame(width: 14, height: 11)
                .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(black, lineWidth: strokeWidth))
                .offset(y: 4)

            // Roof
            RoofTriangleShape()
                .fill(overrideColor ?? IconPalette.red)
                .frame(width: 19, height: 9.5)
                .overlay(RoofTriangleShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
                .offset(y: -4.5)

            // Door
            RoundedRectangle(cornerRadius: 1.2)
                .fill(black)
                .frame(width: 4.5, height: 6)
                .offset(y: 6.5)
        }
    }

    private var barChartIcon: some View {
        ZStack(alignment: .bottom) {
            // Ground baseline shelf
            Capsule()
                .fill(black)
                .frame(width: 19, height: 1.8)
                .offset(y: 1.0)

            // Bar 1 (Left: Blue)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(overrideColor ?? IconPalette.blue)
                .frame(width: 4.5, height: 7.5)
                .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(black, lineWidth: strokeWidth))
                .offset(x: -6.0, y: 0)

            // Bar 2 (Middle: Green)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(overrideColor ?? IconPalette.green)
                .frame(width: 4.5, height: 12.0)
                .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(black, lineWidth: strokeWidth))
                .offset(x: 0, y: 0)

            // Bar 3 (Right: Yellow)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(overrideColor ?? IconPalette.yellow)
                .frame(width: 4.5, height: 16.5)
                .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(black, lineWidth: strokeWidth))
                .offset(x: 6.0, y: 0)
        }
        .frame(width: 20, height: 18)
    }

    private var creditCardIcon: some View {
        ZStack {
            // Card Body
            RoundedRectangle(cornerRadius: 3.5)
                .fill(overrideColor ?? IconPalette.blue)
                .frame(width: 19, height: 13.5)
                .overlay(RoundedRectangle(cornerRadius: 3.5).stroke(black, lineWidth: strokeWidth))

            // Dark magnetic stripe across the top
            Rectangle()
                .fill(black)
                .frame(width: 19, height: 2.8)
                .offset(y: -2.8)

            // Smart Chip (Gold/Yellow with outline)
            RoundedRectangle(cornerRadius: 1)
                .fill(IconPalette.yellow)
                .frame(width: 4.2, height: 3)
                .overlay(RoundedRectangle(cornerRadius: 1).stroke(black, lineWidth: 1.0))
                .offset(x: -4.2, y: 2.2)

            // Card embossed dots/lines
            HStack(spacing: 1.5) {
                RoundedRectangle(cornerRadius: 0.5).fill(IconPalette.white).frame(width: 2.5, height: 1.5)
                RoundedRectangle(cornerRadius: 0.5).fill(IconPalette.white).frame(width: 2.5, height: 1.5)
                RoundedRectangle(cornerRadius: 0.5).fill(IconPalette.white).frame(width: 2.5, height: 1.5)
            }
            .offset(x: 2.8, y: 2.2)
        }
    }

    private var receiptIcon: some View {
        ZStack {
            // Receipt body
            ReceiptJaggedShape()
                .fill(IconPalette.white)
                .frame(width: 14, height: 18)
                .overlay(ReceiptJaggedShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))

            // Yellow top binding
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(overrideColor ?? IconPalette.yellow)
                    .frame(width: 14, height: 4.5)
                    .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(black, lineWidth: strokeWidth))
                Spacer()
            }
            .frame(width: 14, height: 18)

            // Text lines
            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 0.8)
                    .fill(black)
                    .frame(width: 7, height: 1.6)
                RoundedRectangle(cornerRadius: 0.8)
                    .fill(black)
                    .frame(width: 7, height: 1.6)
            }
            .offset(y: 2.5)
        }
    }

    private var coinsIcon: some View {
        ZStack {
            // Rear Coin (Sitting slightly higher to the right)
            ZStack {
                // Lower 3D rim cylinder
                CoinCylinderShape(depth: 3.2)
                    .fill(Color(red: 217/255, green: 140/255, blue: 18/255))
                    .frame(width: 12.5, height: 6.8)
                    .overlay(CoinCylinderShape(depth: 3.2).stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))

                // Top face
                Ellipse()
                    .fill(overrideColor ?? IconPalette.yellow)
                    .frame(width: 12.5, height: 6.8)
                    .overlay(Ellipse().stroke(black, lineWidth: strokeWidth))
                    .offset(y: -1.6)

                // Embossed rim ring
                Ellipse()
                    .stroke(black.opacity(0.32), lineWidth: 0.8)
                    .frame(width: 9.0, height: 4.5)
                    .offset(y: -1.6)
            }
            .offset(x: 3.2, y: -2.6)

            // Front Coin (Overlapping prominently in front)
            ZStack {
                // Lower 3D rim cylinder
                CoinCylinderShape(depth: 3.6)
                    .fill(Color(red: 217/255, green: 140/255, blue: 18/255))
                    .frame(width: 13.5, height: 7.2)
                    .overlay(CoinCylinderShape(depth: 3.6).stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))

                // Top face
                Ellipse()
                    .fill(overrideColor ?? IconPalette.yellow)
                    .frame(width: 13.5, height: 7.2)
                    .overlay(Ellipse().stroke(black, lineWidth: strokeWidth))
                    .offset(y: -1.8)

                // Embossed inner ring
                Ellipse()
                    .stroke(black.opacity(0.35), lineWidth: 0.8)
                    .frame(width: 9.6, height: 4.8)
                    .offset(y: -1.8)

                // Currency insignia (crisp bold '$' in black)
                Text("$")
                    .font(.system(size: 6.2, weight: .black, design: .rounded))
                    .foregroundColor(black)
                    .offset(y: -1.9)
            }
            .offset(x: -2.8, y: 2.4)
        }
    }

    private var pieChartIcon: some View {
        ZStack {
            // Blue main pacman slice
            Circle()
                .trim(from: 0.25, to: 1.0)
                .fill(overrideColor ?? IconPalette.blue)
                .frame(width: 17, height: 17)
                .overlay(
                    Circle()
                        .trim(from: 0.25, to: 1.0)
                        .stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                )

            // Red wedge (top-right)
            PieSliceShape(startAngle: .degrees(-90), endAngle: .degrees(0))
                .fill(IconPalette.red)
                .frame(width: 17, height: 17)
                .overlay(PieSliceShape(startAngle: .degrees(-90), endAngle: .degrees(0)).stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
                .offset(x: 1.5, y: -1.5)
        }
    }

    private var calendarIcon: some View {
        ZStack {
            // White body
            RoundedRectangle(cornerRadius: 3.5)
                .fill(IconPalette.white)
                .frame(width: 17, height: 15)
                .overlay(RoundedRectangle(cornerRadius: 3.5).stroke(black, lineWidth: strokeWidth))
                .offset(y: 1.5)

            // Red header
            CalendarHeaderShape()
                .fill(overrideColor ?? IconPalette.red)
                .frame(width: 17, height: 5.5)
                .overlay(CalendarHeaderShape().stroke(black, lineWidth: strokeWidth))
                .offset(y: -3.25)

            // 2 top rings
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(black)
                    .frame(width: 2, height: 3.8)
                RoundedRectangle(cornerRadius: 1)
                    .fill(black)
                    .frame(width: 2, height: 3.8)
            }
            .offset(y: -7)

            // Date dots
            HStack(spacing: 3) {
                Circle().fill(black).frame(width: 2, height: 2)
                Circle().fill(black).frame(width: 2, height: 2)
                Circle().fill(black).frame(width: 2, height: 2)
            }
            .offset(y: 3.5)
        }
    }

    private var bellIcon: some View {
        ZStack {
            // Bell dome
            BellDomeShape()
                .fill(overrideColor ?? IconPalette.yellow)
                .frame(width: 14, height: 15)
                .overlay(BellDomeShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
                .offset(y: -1)

            // Top loop
            Circle()
                .stroke(black, lineWidth: strokeWidth)
                .frame(width: 4, height: 4)
                .offset(y: -8.5)

            // Clapper dot
            Circle()
                .fill(black)
                .frame(width: 3.5, height: 3.5)
                .offset(y: 7.5)
        }
    }

    private var searchIcon: some View {
        ZStack {
            // Blue glass circle
            Circle()
                .fill(overrideColor ?? IconPalette.blue)
                .frame(width: 12.5, height: 12.5)
                .overlay(Circle().stroke(black, lineWidth: strokeWidth))
                .offset(x: -2.5, y: -2.5)

            // Thick handle
            RoundedRectangle(cornerRadius: 1.5)
                .fill(black)
                .frame(width: 3, height: 7.5)
                .rotationEffect(.degrees(-45))
                .offset(x: 5.5, y: 5.5)
        }
    }

    private var gearIcon: some View {
        ZStack {
            // Outer gear cogs
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(overrideColor ?? IconPalette.green)
                    .frame(width: 4.5, height: 18)
                    .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(black, lineWidth: strokeWidth))
                    .rotationEffect(.degrees(Double(i) * 45))
            }

            // Gear center rim
            Circle()
                .fill(overrideColor ?? IconPalette.green)
                .frame(width: 13, height: 13)
                .overlay(Circle().stroke(black, lineWidth: strokeWidth))

            // Center hole
            Circle()
                .fill(IconPalette.white)
                .frame(width: 5, height: 5)
                .overlay(Circle().stroke(black, lineWidth: 1.5))
        }
    }

    // MARK: - Row 2 Implementations

    private var plusCircleIcon: some View {
        ZStack {
            Circle()
                .fill(overrideColor ?? IconPalette.green)
                .frame(width: 19, height: 19)
                .overlay(Circle().stroke(black, lineWidth: strokeWidth))

            // Black plus
            ZStack {
                RoundedRectangle(cornerRadius: 1.0)
                    .fill(black)
                    .frame(width: 10.0, height: 2.4)
                RoundedRectangle(cornerRadius: 1.0)
                    .fill(black)
                    .frame(width: 2.4, height: 10.0)
            }
        }
    }

    private var minusCircleIcon: some View {
        ZStack {
            Circle()
                .fill(overrideColor ?? IconPalette.red)
                .frame(width: 19, height: 19)
                .overlay(Circle().stroke(black, lineWidth: strokeWidth))

            RoundedRectangle(cornerRadius: 1.0)
                .fill(black)
                .frame(width: 10.0, height: 2.4)
        }
    }

    private var uploadIcon: some View {
        ZStack {
            // Open tray
            TrayShape()
                .stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
                .frame(width: 17, height: 9)
                .offset(y: 4.5)

            // Upward arrow
            ArrowUpShape()
                .stroke(overrideColor ?? black, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .frame(width: 9, height: 11)
                .offset(y: -2.5)
        }
    }

    private var downloadIcon: some View {
        ZStack {
            // Open tray
            TrayShape()
                .stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
                .frame(width: 17, height: 9)
                .offset(y: 4.5)

            // Downward arrow
            ArrowDownShape()
                .stroke(overrideColor ?? black, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .frame(width: 9, height: 11)
                .offset(y: -1)
        }
    }

    private var exchangeIcon: some View {
        VStack(spacing: 3.5) {
            // Top blue right arrow
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(overrideColor ?? IconPalette.blue)
                    .frame(width: 10, height: 3.2)
                    .overlay(RoundedRectangle(cornerRadius: 1).stroke(black, lineWidth: 1.4))
                TriangleRightShape()
                    .fill(overrideColor ?? IconPalette.blue)
                    .frame(width: 5.5, height: 6.5)
                    .overlay(TriangleRightShape().stroke(black, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)))
            }
            .offset(x: 1.5)

            // Bottom red left arrow
            HStack(spacing: 0) {
                TriangleLeftShape()
                    .fill(IconPalette.red)
                    .frame(width: 5.5, height: 6.5)
                    .overlay(TriangleLeftShape().stroke(black, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)))
                RoundedRectangle(cornerRadius: 1)
                    .fill(IconPalette.red)
                    .frame(width: 10, height: 3.2)
                    .overlay(RoundedRectangle(cornerRadius: 1).stroke(black, lineWidth: 1.4))
            }
            .offset(x: -1.5)
        }
    }

    private var cameraIcon: some View {
        ZStack {
            // Chassis
            RoundedRectangle(cornerRadius: 3.5)
                .fill(overrideColor ?? IconPalette.yellow)
                .frame(width: 18.5, height: 13.5)
                .overlay(RoundedRectangle(cornerRadius: 3.5).stroke(black, lineWidth: strokeWidth))
                .offset(y: 1.5)

            // Flash bump
            RoundedRectangle(cornerRadius: 1)
                .fill(overrideColor ?? IconPalette.yellow)
                .frame(width: 5, height: 3)
                .overlay(RoundedRectangle(cornerRadius: 1).stroke(black, lineWidth: 1.6))
                .offset(x: -3.5, y: -5.5)

            // Center lens
            Circle()
                .fill(IconPalette.white)
                .frame(width: 7.5, height: 7.5)
                .overlay(Circle().stroke(black, lineWidth: strokeWidth))
                .offset(y: 1.5)

            Circle()
                .fill(black)
                .frame(width: 3.5, height: 3.5)
                .offset(y: 1.5)
        }
    }

    private var photoIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(overrideColor ?? IconPalette.green)
                .frame(width: 18, height: 14.5)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(black, lineWidth: strokeWidth))

            // White sun
            Circle()
                .fill(IconPalette.white)
                .frame(width: 3.2, height: 3.2)
                .offset(x: 4, y: -3.2)

            // White mountain peaks
            MountainPeakShape()
                .fill(IconPalette.white)
                .frame(width: 15, height: 6.5)
                .offset(y: 3)
        }
    }

    private var scanIcon: some View {
        ZStack {
            CornerBracketsShape()
                .stroke(overrideColor ?? IconPalette.blue, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                .frame(width: 17, height: 17)
        }
    }

    private var slidersIcon: some View {
        VStack(spacing: 3.5) {
            // Slider 1
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(black)
                    .frame(width: 16, height: 1.8)
                Circle()
                    .fill(overrideColor ?? IconPalette.white)
                    .frame(width: 5, height: 5)
                    .overlay(Circle().stroke(black, lineWidth: 1.6))
                    .offset(x: 3)
            }

            // Slider 2
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(black)
                    .frame(width: 16, height: 1.8)
                Circle()
                    .fill(overrideColor ?? IconPalette.red)
                    .frame(width: 5, height: 5)
                    .overlay(Circle().stroke(black, lineWidth: 1.6))
                    .offset(x: 10)
            }

            // Slider 3
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(black)
                    .frame(width: 16, height: 1.8)
                Circle()
                    .fill(overrideColor ?? IconPalette.blue)
                    .frame(width: 5, height: 5)
                    .overlay(Circle().stroke(black, lineWidth: 1.6))
                    .offset(x: 6)
            }
        }
    }

    private var chatDotsIcon: some View {
        ZStack {
            ChatBubbleShape()
                .fill(overrideColor ?? IconPalette.white)
                .frame(width: 17.5, height: 15.5)
                .overlay(ChatBubbleShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))

            HStack(spacing: 2.2) {
                Circle().fill(black).frame(width: 2.2, height: 2.2)
                Circle().fill(black).frame(width: 2.2, height: 2.2)
                Circle().fill(black).frame(width: 2.2, height: 2.2)
            }
            .offset(y: -1)
        }
    }

    // MARK: - Row 3 Implementations

    private var cartIcon: some View {
        ZStack {
            // Cart Basket Body
            CartBasketShape()
                .fill(overrideColor ?? IconPalette.yellow)
                .frame(width: 14.5, height: 10)
                .overlay(CartBasketShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
                .offset(x: 2, y: -2.5)

            // Basket vertical wire grill
            HStack(spacing: 2.8) {
                Rectangle().fill(black).frame(width: 1.2, height: 6.5)
                Rectangle().fill(black).frame(width: 1.2, height: 6.5)
                Rectangle().fill(black).frame(width: 1.2, height: 6.5)
            }
            .offset(x: 2, y: -2.5)

            // Push handle & chassis support
            Path { p in
                // Handle bar
                p.move(to: CGPoint(x: 5.5, y: 6))
                p.addLine(to: CGPoint(x: 2.5, y: 3))
                // Bottom chassis rail
                p.move(to: CGPoint(x: 7.5, y: 14))
                p.addLine(to: CGPoint(x: 8.5, y: 18))
                p.addLine(to: CGPoint(x: 18.5, y: 18))
            }
            .stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))

            // Wheels
            HStack(spacing: 7) {
                Circle().fill(black).frame(width: 3.5, height: 3.5)
                Circle().fill(black).frame(width: 3.5, height: 3.5)
            }
            .offset(x: 2.5, y: 6.5)
        }
    }

    private var cutleryIcon: some View {
        HStack(spacing: 6) {
            // Fork
            VStack(spacing: 0) {
                ForkProngsShape()
                    .stroke(black, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 5.5, height: 7)
                RoundedRectangle(cornerRadius: 1)
                    .fill(overrideColor ?? IconPalette.red)
                    .frame(width: 2.6, height: 9)
                    .overlay(RoundedRectangle(cornerRadius: 1).stroke(black, lineWidth: 1.4))
            }

            // Knife
            VStack(spacing: 0) {
                KnifeBladeShape()
                    .fill(IconPalette.white)
                    .frame(width: 3.5, height: 8)
                    .overlay(KnifeBladeShape().stroke(black, lineWidth: 1.6))
                RoundedRectangle(cornerRadius: 1)
                    .fill(overrideColor ?? IconPalette.orange)
                    .frame(width: 2.6, height: 9)
                    .overlay(RoundedRectangle(cornerRadius: 1).stroke(black, lineWidth: 1.4))
            }
        }
    }

    private var coffeeIcon: some View {
        ZStack {
            // Saucer plate
            Capsule()
                .fill(black)
                .frame(width: 17, height: 2.2)
                .offset(y: 8.5)

            // Mug Handle (smooth D-loop on right side)
            MugHandleShape()
                .stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
                .frame(width: 5.5, height: 7.5)
                .offset(x: 7.2, y: 1.5)

            // Ceramic Mug Body
            CeramicMugShape()
                .fill(overrideColor ?? IconPalette.orange)
                .frame(width: 13.5, height: 11)
                .overlay(CeramicMugShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
                .offset(x: -0.5, y: 2)

            // Hot Coffee surface inside cup
            Ellipse()
                .fill(Color(red: 78/255, green: 42/255, blue: 24/255))
                .frame(width: 11.5, height: 3.2)
                .offset(x: -0.5, y: -3.2)

            // Delicate rising steam lines
            HStack(spacing: 3) {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 5.5))
                    p.addQuadCurve(to: CGPoint(x: 1, y: 0), control: CGPoint(x: -1.5, y: 2.8))
                }
                .stroke(black, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 2, height: 5.5)

                Path { p in
                    p.move(to: CGPoint(x: 0, y: 6.5))
                    p.addQuadCurve(to: CGPoint(x: -1, y: 0), control: CGPoint(x: 1.5, y: 3.2))
                }
                .stroke(black, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 2, height: 6.5)
            }
            .offset(x: -0.5, y: -7.5)
        }
    }

    private var carIcon: some View {
        ZStack {
            // Car Body
            CarBodyShape()
                .fill(overrideColor ?? IconPalette.blue)
                .frame(width: 18.5, height: 10)
                .overlay(CarBodyShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
                .offset(y: -0.5)

            // Windshield
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 0.8).fill(IconPalette.white).frame(width: 4.5, height: 2.8)
                RoundedRectangle(cornerRadius: 0.8).fill(IconPalette.white).frame(width: 4.5, height: 2.8)
            }
            .offset(y: -2.2)

            // Headlight
            Circle()
                .fill(IconPalette.yellow)
                .frame(width: 2, height: 2)
                .offset(x: 8, y: -0.5)

            // Wheels
            HStack(spacing: 9.5) {
                Circle().fill(black).frame(width: 4, height: 4)
                Circle().fill(black).frame(width: 4, height: 4)
            }
            .offset(y: 5.5)
        }
    }

    private var gasPumpIcon: some View {
        ZStack {
            // Pump tower
            RoundedRectangle(cornerRadius: 2.5)
                .fill(overrideColor ?? IconPalette.blue)
                .frame(width: 11, height: 16)
                .overlay(RoundedRectangle(cornerRadius: 2.5).stroke(black, lineWidth: strokeWidth))
                .offset(x: -2.5)

            // Dial screen
            RoundedRectangle(cornerRadius: 1)
                .fill(IconPalette.white)
                .frame(width: 6.5, height: 4.5)
                .offset(x: -2.5, y: -4)

            // Red hose nozzle
            HoseShape()
                .stroke(IconPalette.red, style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
                .frame(width: 6, height: 11)
                .offset(x: 5.5, y: 1)
        }
    }

    private var busIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(overrideColor ?? IconPalette.green)
                .frame(width: 14, height: 16.5)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(black, lineWidth: strokeWidth))

            // Windshield
            RoundedRectangle(cornerRadius: 1.5)
                .fill(IconPalette.white)
                .frame(width: 10.5, height: 4.5)
                .offset(y: -3.5)

            // Headlights
            HStack(spacing: 7) {
                Circle().fill(IconPalette.white).frame(width: 2.4, height: 2.4)
                Circle().fill(IconPalette.white).frame(width: 2.4, height: 2.4)
            }
            .offset(y: 3)

            // Tires
            HStack(spacing: 11.5) {
                RoundedRectangle(cornerRadius: 1).fill(black).frame(width: 2, height: 4.5)
                RoundedRectangle(cornerRadius: 1).fill(black).frame(width: 2, height: 4.5)
            }
            .offset(y: 8.5)
        }
    }

    private var airplaneIcon: some View {
        ZStack {
            // Main airliner body and wings
            AirlinerShape()
                .fill(overrideColor ?? IconPalette.blue)
                .frame(width: 19, height: 19)
                .overlay(AirlinerShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))

            // Cockpit windshield (Cyan/White capsule at nose)
            Capsule()
                .fill(IconPalette.white)
                .frame(width: 3.2, height: 1.8)
                .overlay(Capsule().stroke(black, lineWidth: 0.8))
                .offset(y: -6.0)

            // Passenger window dots along the fuselage
            VStack(spacing: 1.6) {
                Circle().fill(IconPalette.white).frame(width: 1.3, height: 1.3)
                Circle().fill(IconPalette.white).frame(width: 1.3, height: 1.3)
                Circle().fill(IconPalette.white).frame(width: 1.3, height: 1.3)
            }
            .offset(y: 0.5)
        }
        .rotationEffect(.degrees(-35))
    }

    private var dumbbellIcon: some View {
        ZStack {
            // Bar
            RoundedRectangle(cornerRadius: 1)
                .fill(black)
                .frame(width: 17, height: 2.5)
                .rotationEffect(.degrees(-30))

            // Left Weights
            RoundedRectangle(cornerRadius: 1.5)
                .fill(overrideColor ?? IconPalette.red)
                .frame(width: 3.5, height: 11)
                .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(black, lineWidth: 1.5))
                .rotationEffect(.degrees(-30))
                .offset(x: -6, y: 3.5)

            // Right Weights
            RoundedRectangle(cornerRadius: 1.5)
                .fill(overrideColor ?? IconPalette.red)
                .frame(width: 3.5, height: 11)
                .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(black, lineWidth: 1.5))
                .rotationEffect(.degrees(-30))
                .offset(x: 6, y: -3.5)
        }
    }

    private var gamepadIcon: some View {
        ZStack {
            // Gamepad chassis
            GamepadBodyShape()
                .fill(overrideColor ?? IconPalette.yellow)
                .frame(width: 19, height: 12)
                .overlay(GamepadBodyShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))

            // D-Pad Cross
            ZStack {
                RoundedRectangle(cornerRadius: 0.6).fill(black).frame(width: 4.8, height: 1.8)
                RoundedRectangle(cornerRadius: 0.6).fill(black).frame(width: 1.8, height: 4.8)
            }
            .offset(x: -4.5)

            // Colorful retro action buttons (Red & Blue with crisp outlines)
            HStack(spacing: 2) {
                Circle().fill(IconPalette.red).frame(width: 2.4, height: 2.4).overlay(Circle().stroke(black, lineWidth: 0.8))
                Circle().fill(IconPalette.blue).frame(width: 2.4, height: 2.4).overlay(Circle().stroke(black, lineWidth: 0.8))
            }
            .offset(x: 4.5)
        }
    }

    private var pawIcon: some View {
        ZStack {
            // Main pad
            Ellipse()
                .fill(overrideColor ?? IconPalette.coral)
                .frame(width: 10, height: 8)
                .overlay(Ellipse().stroke(black, lineWidth: strokeWidth))
                .offset(y: 2)

            // 4 Toes
            Circle().fill(overrideColor ?? IconPalette.coral).frame(width: 3.5, height: 3.5).overlay(Circle().stroke(black, lineWidth: 1.4)).offset(x: -5, y: -3)
            Circle().fill(overrideColor ?? IconPalette.coral).frame(width: 3.8, height: 3.8).overlay(Circle().stroke(black, lineWidth: 1.4)).offset(x: -1.8, y: -5.5)
            Circle().fill(overrideColor ?? IconPalette.coral).frame(width: 3.8, height: 3.8).overlay(Circle().stroke(black, lineWidth: 1.4)).offset(x: 1.8, y: -5.5)
            Circle().fill(overrideColor ?? IconPalette.coral).frame(width: 3.5, height: 3.5).overlay(Circle().stroke(black, lineWidth: 1.4)).offset(x: 5, y: -3)
        }
    }

    // MARK: - Row 4 Implementations

    private var medicalCrossIcon: some View {
        MedicalCrossShape()
            .fill(overrideColor ?? IconPalette.red)
            .frame(width: 16.5, height: 16.5)
            .overlay(MedicalCrossShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    private var gradCapIcon: some View {
        ZStack {
            // Diamond board
            DiamondShape()
                .fill(overrideColor ?? IconPalette.blue)
                .frame(width: 18, height: 9.5)
                .overlay(DiamondShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
                .offset(y: -3)

            // Skullcap
            HalfEllipseShape()
                .fill(overrideColor ?? IconPalette.blue)
                .frame(width: 9, height: 5)
                .overlay(HalfEllipseShape().stroke(black, lineWidth: strokeWidth))
                .offset(y: 2.5)

            // Tassel
            Path { p in
                p.move(to: CGPoint(x: 12, y: 9))
                p.addLine(to: CGPoint(x: 18, y: 15))
            }
            .stroke(black, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
    }

    private var shoppingBagIcon: some View {
        ZStack {
            // Prominent U-shaped handle arched above the bag
            BagHandleUshape()
                .stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
                .frame(width: 8.0, height: 7.0)
                .offset(y: -5.5)

            // Bag Body (Warm yellow boutique shopping bag)
            RoundedRectangle(cornerRadius: 2.5)
                .fill(overrideColor ?? IconPalette.yellow)
                .frame(width: 15.5, height: 13.0)
                .overlay(RoundedRectangle(cornerRadius: 2.5).stroke(black, lineWidth: strokeWidth))
                .offset(y: 2.5)

            // Center boutique fold crease
            Rectangle()
                .fill(black.opacity(0.18))
                .frame(width: 1.2, height: 7.5)
                .offset(y: 2.5)
        }
    }

    private var tshirtIcon: some View {
        TShirtShape()
            .fill(overrideColor ?? IconPalette.red)
            .frame(width: 18, height: 15.5)
            .overlay(TShirtShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    private var giftIcon: some View {
        ZStack {
            // Box
            RoundedRectangle(cornerRadius: 2)
                .fill(overrideColor ?? IconPalette.green)
                .frame(width: 14.5, height: 12)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(black, lineWidth: strokeWidth))
                .offset(y: 2.5)

            // Vertical ribbon band
            RoundedRectangle(cornerRadius: 0.8)
                .fill(IconPalette.red)
                .frame(width: 3.2, height: 12)
                .overlay(RoundedRectangle(cornerRadius: 0.8).stroke(black, lineWidth: 1.2))
                .offset(y: 2.5)

            // Lid
            RoundedRectangle(cornerRadius: 1.8)
                .fill(overrideColor ?? IconPalette.green)
                .frame(width: 16.5, height: 4)
                .overlay(RoundedRectangle(cornerRadius: 1.8).stroke(black, lineWidth: strokeWidth))
                .offset(y: -4.2)

            // Lid horizontal ribbon band
            RoundedRectangle(cornerRadius: 0.8)
                .fill(IconPalette.red)
                .frame(width: 3.2, height: 4)
                .overlay(RoundedRectangle(cornerRadius: 0.8).stroke(black, lineWidth: 1.2))
                .offset(y: -4.2)

            // Ribbon Bow loops
            HStack(spacing: 1) {
                Ellipse()
                    .fill(IconPalette.red)
                    .frame(width: 4.5, height: 3.5)
                    .overlay(Ellipse().stroke(black, lineWidth: 1.4))
                    .rotationEffect(.degrees(-25))
                Ellipse()
                    .fill(IconPalette.red)
                    .frame(width: 4.5, height: 3.5)
                    .overlay(Ellipse().stroke(black, lineWidth: 1.4))
                    .rotationEffect(.degrees(25))
            }
            .offset(y: -7.2)
        }
    }

    private var ticketIcon: some View {
        TicketNotchedShape()
            .fill(overrideColor ?? IconPalette.blue)
            .frame(width: 19, height: 12)
            .overlay(TicketNotchedShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
            .rotationEffect(.degrees(-10))
    }

    private var heartIcon: some View {
        HeartShape()
            .fill(overrideColor ?? IconPalette.red)
            .frame(width: 17, height: 15.5)
            .overlay(HeartShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    private var starIcon: some View {
        StarPolygonShape()
            .fill(overrideColor ?? IconPalette.yellow)
            .frame(width: 18, height: 18)
            .overlay(StarPolygonShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    private var islandIcon: some View {
        ZStack {
            // Sand hill
            IslandHillShape()
                .fill(overrideColor ?? IconPalette.yellow)
                .frame(width: 18, height: 6)
                .overlay(IslandHillShape().stroke(black, lineWidth: strokeWidth))
                .offset(y: 7)

            // Palm tree
            PalmTreeShape()
                .fill(IconPalette.green)
                .frame(width: 14, height: 14)
                .overlay(PalmTreeShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
                .offset(y: -3)
        }
    }

    private var suitcaseIcon: some View {
        ZStack {
            // Prominent suitcase handle
            RoundedRectangle(cornerRadius: 1.5)
                .stroke(black, lineWidth: strokeWidth)
                .frame(width: 7, height: 5)
                .offset(y: -7.5)

            // Case body
            RoundedRectangle(cornerRadius: 3.5)
                .fill(overrideColor ?? IconPalette.blue)
                .frame(width: 16, height: 13.5)
                .overlay(RoundedRectangle(cornerRadius: 3.5).stroke(black, lineWidth: strokeWidth))
                .offset(y: 1.5)

            // Rib stripes
            VStack(spacing: 2.5) {
                Rectangle().fill(black).frame(width: 10, height: 1.2)
                Rectangle().fill(black).frame(width: 10, height: 1.2)
            }
            .offset(y: 1.5)
        }
    }

    // MARK: - Row 5 Implementations

    private var mailIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3.5)
                .fill(overrideColor ?? IconPalette.blue)
                .frame(width: 18.5, height: 13.5)
                .overlay(RoundedRectangle(cornerRadius: 3.5).stroke(black, lineWidth: strokeWidth))

            // White envelope flap
            EnvelopeFlapShape()
                .stroke(IconPalette.white, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .frame(width: 18.5, height: 13.5)
        }
    }

    private var chatSmileIcon: some View {
        ZStack {
            ChatBubbleShape()
                .fill(overrideColor ?? IconPalette.green)
                .frame(width: 17.5, height: 15.5)
                .overlay(ChatBubbleShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))

            // Eyes & Smile
            VStack(spacing: 1.5) {
                HStack(spacing: 4) {
                    Circle().fill(black).frame(width: 1.6, height: 1.6)
                    Circle().fill(black).frame(width: 1.6, height: 1.6)
                }
                SmileArcShape()
                    .stroke(black, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                    .frame(width: 6, height: 3)
            }
            .offset(y: -1)
        }
    }

    private var phoneIcon: some View {
        PhoneReceiverShape()
            .fill(overrideColor ?? IconPalette.coral)
            .frame(width: 14.5, height: 14.5)
            .overlay(PhoneReceiverShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
            .rotationEffect(.degrees(10))
    }

    private var paperPlaneIcon: some View {
        PaperPlaneShape()
            .fill(overrideColor ?? IconPalette.yellow)
            .frame(width: 16, height: 16)
            .overlay(PaperPlaneShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
            .rotationEffect(.degrees(15))
    }

    private var documentIcon: some View {
        ZStack {
            DocDogEarShape()
                .fill(IconPalette.white)
                .frame(width: 14, height: 17.5)
                .overlay(DocDogEarShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))

            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 0.5).fill(black).frame(width: 7, height: 1.5)
                RoundedRectangle(cornerRadius: 0.5).fill(black).frame(width: 7, height: 1.5)
                RoundedRectangle(cornerRadius: 0.5).fill(black).frame(width: 4.5, height: 1.5)
            }
            .offset(x: -0.5, y: 2)
        }
    }

    private var folderIcon: some View {
        FolderShape()
            .fill(overrideColor ?? IconPalette.yellow)
            .frame(width: 18, height: 13.5)
            .overlay(FolderShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    private var trashIcon: some View {
        ZStack {
            // Can
            TrashCanShape()
                .fill(overrideColor ?? IconPalette.red)
                .frame(width: 13.5, height: 13)
                .overlay(TrashCanShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
                .offset(y: 2.5)

            // Vertical rib lines
            HStack(spacing: 2.5) {
                Rectangle().fill(black).frame(width: 1.4, height: 7)
                Rectangle().fill(black).frame(width: 1.4, height: 7)
            }
            .offset(y: 2.5)

            // Lid
            RoundedRectangle(cornerRadius: 1)
                .fill(overrideColor ?? IconPalette.red)
                .frame(width: 16.5, height: 2.6)
                .overlay(RoundedRectangle(cornerRadius: 1).stroke(black, lineWidth: strokeWidth))
                .offset(y: -5)
        }
    }

    private var pencilIcon: some View {
        PencilShape()
            .fill(overrideColor ?? IconPalette.blue)
            .frame(width: 7, height: 17)
            .overlay(PencilShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
            .rotationEffect(.degrees(45))
    }

    private var bookmarkIcon: some View {
        BookmarkRibbonShape()
            .fill(overrideColor ?? IconPalette.red)
            .frame(width: 13.5, height: 17)
            .overlay(BookmarkRibbonShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    private var flagIcon: some View {
        ZStack(alignment: .topLeading) {
            // Flag pole
            RoundedRectangle(cornerRadius: 1)
                .fill(black)
                .frame(width: 2.2, height: 18)
                .offset(x: 4, y: 3)

            // Banner
            FlagBannerShape()
                .fill(overrideColor ?? IconPalette.green)
                .frame(width: 13, height: 8.5)
                .overlay(FlagBannerShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
                .offset(x: 6, y: 3)
        }
        .frame(width: 24, height: 24)
    }

    // MARK: - Row 6 Implementations

    private var clockIcon: some View {
        ZStack {
            Circle()
                .fill(overrideColor ?? IconPalette.blue)
                .frame(width: 18.5, height: 18.5)
                .overlay(Circle().stroke(black, lineWidth: strokeWidth))

            // Hands (3 o'clock)
            Path { p in
                p.move(to: CGPoint(x: 12, y: 6.5))
                p.addLine(to: CGPoint(x: 12, y: 12))
                p.addLine(to: CGPoint(x: 16, y: 12))
            }
            .stroke(black, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

            // Center pivot dot
            Circle()
                .fill(black)
                .frame(width: 2.8, height: 2.8)
        }
    }

    private var refreshIcon: some View {
        RefreshArrowsShape()
            .stroke(overrideColor ?? IconPalette.green, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
            .frame(width: 16.5, height: 16.5)
    }

    private var cloudIcon: some View {
        CloudShape()
            .fill(overrideColor ?? IconPalette.blue)
            .frame(width: 18.5, height: 12.5)
            .overlay(CloudShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    private var sunIcon: some View {
        ZStack {
            // Sun rays
            ForEach(0..<8) { i in
                RoundedRectangle(cornerRadius: 0.8)
                    .fill(black)
                    .frame(width: 1.8, height: 18)
                    .rotationEffect(.degrees(Double(i) * 45))
            }

            // Sun center
            Circle()
                .fill(overrideColor ?? IconPalette.yellow)
                .frame(width: 11, height: 11)
                .overlay(Circle().stroke(black, lineWidth: strokeWidth))
        }
    }

    private var moonIcon: some View {
        CrescentMoonShape()
            .fill(overrideColor ?? IconPalette.yellow)
            .frame(width: 14, height: 16.5)
            .overlay(CrescentMoonShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    private var lightningIcon: some View {
        LightningShape()
            .fill(overrideColor ?? IconPalette.green)
            .frame(width: 11.5, height: 18)
            .overlay(LightningShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    private var leafIcon: some View {
        ZStack {
            LeafShape()
                .fill(overrideColor ?? IconPalette.green)
                .frame(width: 15, height: 16.5)
                .overlay(LeafShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))

            // Delicate branched vein lines
            LeafVeinShape()
                .stroke(black, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .frame(width: 15, height: 16.5)
        }
    }

    private var waterDropIcon: some View {
        WaterDropShape()
            .fill(overrideColor ?? IconPalette.blue)
            .frame(width: 13, height: 17)
            .overlay(WaterDropShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    private var flameIcon: some View {
        ZStack {
            FlameOutlineShape()
                .fill(overrideColor ?? IconPalette.red)
                .frame(width: 14.5, height: 18)
                .overlay(FlameOutlineShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))

            // Inner flame highlight
            FlameOutlineShape()
                .fill(IconPalette.yellow)
                .frame(width: 7, height: 9)
                .offset(y: 3)
        }
    }

    private var snowflakeIcon: some View {
        SnowflakeShape()
            .stroke(overrideColor ?? IconPalette.blue, style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
            .frame(width: 18, height: 18)
    }

    // MARK: - Row 7 Implementations

    private var checkCircleIcon: some View {
        ZStack {
            Circle()
                .fill(overrideColor ?? IconPalette.green)
                .frame(width: 18.5, height: 18.5)
                .overlay(Circle().stroke(black, lineWidth: strokeWidth))

            Path { p in
                p.move(to: CGPoint(x: 7.5, y: 12))
                p.addLine(to: CGPoint(x: 10.5, y: 15))
                p.addLine(to: CGPoint(x: 16.5, y: 9))
            }
            .stroke(black, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
        }
    }

    private var xmarkCircleIcon: some View {
        ZStack {
            Circle()
                .fill(overrideColor ?? IconPalette.red)
                .frame(width: 18.5, height: 18.5)
                .overlay(Circle().stroke(black, lineWidth: strokeWidth))

            Path { p in
                p.move(to: CGPoint(x: 8.5, y: 8.5))
                p.addLine(to: CGPoint(x: 15.5, y: 15.5))
                p.move(to: CGPoint(x: 15.5, y: 8.5))
                p.addLine(to: CGPoint(x: 8.5, y: 15.5))
            }
            .stroke(black, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
    }

    private var warningCircleIcon: some View {
        ZStack {
            Circle()
                .fill(overrideColor ?? IconPalette.yellow)
                .frame(width: 18.5, height: 18.5)
                .overlay(Circle().stroke(black, lineWidth: strokeWidth))

            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 1).fill(black).frame(width: 2.4, height: 7)
                Circle().fill(black).frame(width: 2.4, height: 2.4)
            }
        }
    }

    private var infoCircleIcon: some View {
        ZStack {
            Circle()
                .fill(overrideColor ?? IconPalette.blue)
                .frame(width: 18.5, height: 18.5)
                .overlay(Circle().stroke(black, lineWidth: strokeWidth))

            VStack(spacing: 2) {
                Circle().fill(black).frame(width: 2.4, height: 2.4)
                RoundedRectangle(cornerRadius: 1).fill(black).frame(width: 2.4, height: 6.5)
            }
        }
    }

    private var questionCircleIcon: some View {
        ZStack {
            Circle()
                .fill(overrideColor ?? IconPalette.coral)
                .frame(width: 18.5, height: 18.5)
                .overlay(Circle().stroke(black, lineWidth: strokeWidth))

            VStack(spacing: 1.8) {
                Text("?")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(black)
            }
        }
    }

    private var mapPinIcon: some View {
        ZStack {
            MapPinTeardropShape()
                .fill(overrideColor ?? IconPalette.red)
                .frame(width: 14.5, height: 18.5)
                .overlay(MapPinTeardropShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))

            Circle()
                .fill(black)
                .frame(width: 4.5, height: 4.5)
                .offset(y: -2.5)
        }
    }

    private var navigationIcon: some View {
        NavCompassShape()
            .fill(overrideColor ?? IconPalette.blue)
            .frame(width: 16.5, height: 16.5)
            .overlay(NavCompassShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
            .rotationEffect(.degrees(15))
    }

    private var globeIcon: some View {
        ZStack {
            Circle()
                .fill(overrideColor ?? IconPalette.green)
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(black, lineWidth: strokeWidth))

            // Equator
            Rectangle().fill(black).frame(width: 18, height: 1.6)

            // Meridian
            Ellipse().stroke(black, lineWidth: 1.6).frame(width: 9, height: 18)
        }
    }

    private var trophyIcon: some View {
        ZStack {
            TrophyCupShape()
                .fill(overrideColor ?? IconPalette.yellow)
                .frame(width: 17.5, height: 14)
                .overlay(TrophyCupShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
                .offset(y: -2)

            // Pedestal base
            RoundedRectangle(cornerRadius: 1.5)
                .fill(overrideColor ?? IconPalette.yellow)
                .frame(width: 11, height: 3.5)
                .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(black, lineWidth: strokeWidth))
                .offset(y: 8)
        }
    }

    private var userIcon: some View {
        ZStack {
            // Head
            Circle()
                .fill(overrideColor ?? IconPalette.blue)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(black, lineWidth: strokeWidth))
                .offset(y: -5)

            // Bust
            UserBustShape()
                .fill(overrideColor ?? IconPalette.blue)
                .frame(width: 16.5, height: 8.5)
                .overlay(UserBustShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
                .offset(y: 5)
        }
    }

    // MARK: - Utilities

    private var chevronLeftIcon: some View {
        ChevronShape()
            .stroke(overrideColor ?? black, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
            .frame(width: 8, height: 13)
            .rotationEffect(.degrees(180))
    }

    private var chevronRightIcon: some View {
        ChevronShape()
            .stroke(overrideColor ?? black, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
            .frame(width: 8, height: 13)
    }

    private var chevronDownIcon: some View {
        ChevronShape()
            .stroke(overrideColor ?? black, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
            .frame(width: 8, height: 13)
            .rotationEffect(.degrees(90))
    }

    private var chevronUpIcon: some View {
        ChevronShape()
            .stroke(overrideColor ?? black, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
            .frame(width: 8, height: 13)
            .rotationEffect(.degrees(-90))
    }

    private var backspaceIcon: some View {
        ZStack {
            BackspaceTagShape()
                .fill(IconPalette.white)
                .frame(width: 19, height: 13)
                .overlay(BackspaceTagShape().stroke(overrideColor ?? black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))

            // X inside
            Path { p in
                p.move(to: CGPoint(x: 10, y: 9.5))
                p.addLine(to: CGPoint(x: 15, y: 14.5))
                p.move(to: CGPoint(x: 15, y: 9.5))
                p.addLine(to: CGPoint(x: 10, y: 14.5))
            }
            .stroke(overrideColor ?? black, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
    }

    private var targetIcon: some View {
        ZStack {
            Circle().stroke(black, lineWidth: strokeWidth).frame(width: 18, height: 18)
            Circle().fill(overrideColor ?? IconPalette.red).frame(width: 10, height: 10).overlay(Circle().stroke(black, lineWidth: 1.5))
            Circle().fill(IconPalette.white).frame(width: 4, height: 4)
        }
    }

    private var lockIcon: some View {
        ZStack {
            // Shackle
            RoundedRectangle(cornerRadius: 3.5)
                .stroke(black, lineWidth: strokeWidth)
                .frame(width: 8.5, height: 9)
                .offset(y: -4.5)

            // Body
            RoundedRectangle(cornerRadius: 3)
                .fill(overrideColor ?? IconPalette.yellow)
                .frame(width: 14.5, height: 11)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(black, lineWidth: strokeWidth))
                .offset(y: 3.5)

            // Keyhole
            Circle().fill(black).frame(width: 2.6, height: 2.6).offset(y: 3.5)
        }
    }

    private var citySkylineIcon: some View {
        ZStack {
            // Ground baseline
            Capsule()
                .fill(black)
                .frame(width: 20, height: 1.8)
                .offset(y: 9.5)

            // Center Skyscraper (Tallest - Vibrant Blue)
            ZStack {
                // Antenna
                Rectangle()
                    .fill(black)
                    .frame(width: 1.5, height: 4)
                    .offset(y: -9)
                Circle()
                    .fill(IconPalette.red)
                    .frame(width: 2.2, height: 2.2)
                    .offset(y: -11)

                // Building body
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(overrideColor ?? IconPalette.blue)
                    .frame(width: 8, height: 16)
                    .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(black, lineWidth: strokeWidth))

                // Windows (grid of crisp white lights)
                VStack(spacing: 2.2) {
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 0.5).fill(IconPalette.white).frame(width: 1.6, height: 1.6)
                        RoundedRectangle(cornerRadius: 0.5).fill(IconPalette.white).frame(width: 1.6, height: 1.6)
                    }
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 0.5).fill(IconPalette.white).frame(width: 1.6, height: 1.6)
                        RoundedRectangle(cornerRadius: 0.5).fill(IconPalette.white).frame(width: 1.6, height: 1.6)
                    }
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 0.5).fill(IconPalette.white).frame(width: 1.6, height: 1.6)
                        RoundedRectangle(cornerRadius: 0.5).fill(IconPalette.white).frame(width: 1.6, height: 1.6)
                    }
                }
                .offset(y: -1)
            }
            .offset(x: 0, y: 1)

            // Left Building (Sunny Yellow townhouse)
            ZStack {
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(overrideColor ?? IconPalette.yellow)
                    .frame(width: 6, height: 11)
                    .overlay(RoundedRectangle(cornerRadius: 1.2).stroke(black, lineWidth: strokeWidth))

                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 0.5).fill(IconPalette.white).frame(width: 2.5, height: 1.6)
                    RoundedRectangle(cornerRadius: 0.5).fill(IconPalette.white).frame(width: 2.5, height: 1.6)
                }
                .offset(y: -1)
            }
            .offset(x: -6.5, y: 3.5)

            // Right Building (Vibrant Coral/Pink medium tower)
            ZStack {
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(overrideColor ?? IconPalette.coral)
                    .frame(width: 6.5, height: 13)
                    .overlay(RoundedRectangle(cornerRadius: 1.2).stroke(black, lineWidth: strokeWidth))

                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 0.5).fill(IconPalette.white).frame(width: 2.5, height: 1.6)
                    RoundedRectangle(cornerRadius: 0.5).fill(IconPalette.white).frame(width: 2.5, height: 1.6)
                    RoundedRectangle(cornerRadius: 0.5).fill(IconPalette.white).frame(width: 2.5, height: 1.6)
                }
                .offset(y: -1)
            }
            .offset(x: 6.5, y: 2.5)
        }
    }
}

// MARK: - Dedicated Helper Vector Shapes

private struct RoofTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct ReceiptJaggedShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 2))
        // 3 zigzag teeth
        let step = rect.width / 4
        p.addLine(to: CGPoint(x: rect.maxX - step * 0.5, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - step * 1.0, y: rect.maxY - 2))
        p.addLine(to: CGPoint(x: rect.maxX - step * 1.5, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - step * 2.0, y: rect.maxY - 2))
        p.addLine(to: CGPoint(x: rect.maxX - step * 2.5, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - step * 3.0, y: rect.maxY - 2))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct PieSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        p.move(to: center)
        p.addArc(center: center, radius: rect.width / 2, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.closeSubpath()
        return p
    }
}

private struct CalendarHeaderShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = min(3.5, rect.height, rect.width / 2)
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct BellDomeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX + 1, y: rect.minY + 2))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.maxX - 1, y: rect.minY + 2))
        p.closeSubpath()
        return p
    }
}

private struct TrayShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

private struct ArrowUpShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.45))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.45))
        return p
    }
}

private struct ArrowDownShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.45))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.45))
        return p
    }
}

private struct TriangleRightShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct TriangleLeftShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct MountainPeakShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.7, y: rect.maxY * 0.6))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct CornerBracketsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let len = rect.width * 0.28
        // Top-Left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
        // Top-Right
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
        // Bottom-Right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
        // Bottom-Left
        p.move(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - len))
        return p
    }
}

private struct CartBasketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + 3, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct ForkProngsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.6))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.6))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}

private struct KnifeBladeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.minY + 2))
        p.closeSubpath()
        return p
    }
}

private struct CeramicMugShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 3.5
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct MugHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control: CGPoint(x: rect.maxX + 1.5, y: rect.midY))
        return p
    }
}

private struct CarBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.5))
        p.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY), control: CGPoint(x: rect.minX + 2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.5), control: CGPoint(x: rect.maxX - 2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct HoseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.maxX + 3, y: rect.minY + 2))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return p
    }
}

private struct AirlinerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midX = rect.midX
        let h = rect.height

        // 1. Nose (Curved aerodynamic nose dome)
        p.move(to: CGPoint(x: midX - 2.2, y: h * 0.08))
        p.addQuadCurve(to: CGPoint(x: midX + 2.2, y: h * 0.08), control: CGPoint(x: midX, y: 0))

        // 2. Right fuselage down to wing root
        p.addLine(to: CGPoint(x: midX + 2.2, y: h * 0.32))

        // 3. Right Swept Wing (Authentic airliner wing with rounded flat tip)
        p.addLine(to: CGPoint(x: rect.maxX - 0.5, y: h * 0.50))
        p.addLine(to: CGPoint(x: rect.maxX - 0.5, y: h * 0.60))
        p.addLine(to: CGPoint(x: midX + 2.2, y: h * 0.60))

        // 4. Right fuselage to tail root
        p.addLine(to: CGPoint(x: midX + 1.8, y: h * 0.82))

        // 5. Right Tail Stabilizer (Small stabilizer wing at tail)
        p.addLine(to: CGPoint(x: midX + 6.0, y: h * 0.94))
        p.addLine(to: CGPoint(x: midX + 5.5, y: rect.maxY))
        p.addLine(to: CGPoint(x: midX, y: h * 0.96))

        // 6. Left Tail Stabilizer
        p.addLine(to: CGPoint(x: midX - 5.5, y: rect.maxY))
        p.addLine(to: CGPoint(x: midX - 6.0, y: h * 0.94))
        p.addLine(to: CGPoint(x: midX - 1.8, y: h * 0.82))

        // 7. Left fuselage from tail to wing
        p.addLine(to: CGPoint(x: midX - 2.2, y: h * 0.60))

        // 8. Left Swept Wing
        p.addLine(to: CGPoint(x: rect.minX + 0.5, y: h * 0.60))
        p.addLine(to: CGPoint(x: rect.minX + 0.5, y: h * 0.50))
        p.addLine(to: CGPoint(x: midX - 2.2, y: h * 0.32))

        p.closeSubpath()
        return p
    }
}

private struct GamepadBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 3, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.maxX + 2, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.maxY * 0.8))
        p.addLine(to: CGPoint(x: rect.minX + 4, y: rect.maxY * 0.8))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + 3, y: rect.minY), control: CGPoint(x: rect.minX - 2, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

private struct MedicalCrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let arm = w * 0.35
        let start = (w - arm) / 2
        p.move(to: CGPoint(x: start, y: 0))
        p.addLine(to: CGPoint(x: start + arm, y: 0))
        p.addLine(to: CGPoint(x: start + arm, y: start))
        p.addLine(to: CGPoint(x: w, y: start))
        p.addLine(to: CGPoint(x: w, y: start + arm))
        p.addLine(to: CGPoint(x: start + arm, y: start + arm))
        p.addLine(to: CGPoint(x: start + arm, y: w))
        p.addLine(to: CGPoint(x: start, y: w))
        p.addLine(to: CGPoint(x: start, y: start + arm))
        p.addLine(to: CGPoint(x: 0, y: start + arm))
        p.addLine(to: CGPoint(x: 0, y: start))
        p.addLine(to: CGPoint(x: start, y: start))
        p.closeSubpath()
        return p
    }
}

private struct CoinCylinderShape: Shape {
    let depth: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let ry = rect.height / 2
        let midX = rect.midX
        let topMidY = rect.minY + ry
        let botMidY = topMidY + depth

        p.move(to: CGPoint(x: rect.minX, y: topMidY))
        p.addLine(to: CGPoint(x: rect.minX, y: botMidY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: botMidY), control: CGPoint(x: midX, y: botMidY + ry))
        p.addLine(to: CGPoint(x: rect.maxX, y: topMidY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: topMidY), control: CGPoint(x: midX, y: rect.minY))
        p.closeSubpath()
        return p
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

private struct HalfEllipseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.minY), radius: rect.width / 2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.closeSubpath()
        return p
    }
}

private struct BagHandleUshape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 3.0))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + 3.0), control: CGPoint(x: rect.midX, y: rect.minY - 1.0))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}

private struct TShirtShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - rect.width * 0.35, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.minY + 3))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.35))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.minY + rect.height * 0.45))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.45))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.35))
        p.closeSubpath()
        return p
    }
}

private struct TicketNotchedShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - 2.5))
        p.addArc(center: CGPoint(x: rect.maxX, y: rect.midY), radius: 2.5, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY + 2.5))
        p.addArc(center: CGPoint(x: rect.minX, y: rect.midY), radius: 2.5, startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)
        p.closeSubpath()
        return p
    }
}

private struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let side = min(rect.width, rect.height)
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + side * 0.35),
                   control1: CGPoint(x: rect.midX - side * 0.45, y: rect.maxY - side * 0.3),
                   control2: CGPoint(x: rect.minX, y: rect.minY + side * 0.65))
        p.addArc(center: CGPoint(x: rect.minX + side * 0.25, y: rect.minY + side * 0.3),
                 radius: side * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: rect.maxX - side * 0.25, y: rect.minY + side * 0.3),
                 radius: side * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                   control1: CGPoint(x: rect.maxX, y: rect.minY + side * 0.65),
                   control2: CGPoint(x: rect.midX + side * 0.45, y: rect.maxY - side * 0.3))
        p.closeSubpath()
        return p
    }
}

private struct StarPolygonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = rect.width / 2
        let innerR = outerR * 0.45
        for i in 0..<10 {
            let angle = CGFloat(i) * .pi / 5 - .pi / 2
            let r = i % 2 == 0 ? outerR : innerR
            let pt = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

private struct IslandHillShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

private struct PalmTreeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Trunk
        p.move(to: CGPoint(x: rect.midX - 1.5, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.midX - 1, y: rect.midY), control: CGPoint(x: rect.midX - 3, y: rect.maxY * 0.7))
        // Canopy crown leaves
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + 4), control: CGPoint(x: rect.midX - 5, y: rect.minY + 2))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX + 4, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + 4), control: CGPoint(x: rect.midX + 4, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.midX + 1, y: rect.midY), control: CGPoint(x: rect.maxX - 4, y: rect.minY + 4))
        p.addQuadCurve(to: CGPoint(x: rect.midX + 1.5, y: rect.maxY), control: CGPoint(x: rect.midX - 1, y: rect.maxY * 0.7))
        p.closeSubpath()
        return p
    }
}

private struct EnvelopeFlapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY * 0.65))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

private struct ChatBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - 3), cornerSize: CGSize(width: 4, height: 4))
        p.move(to: CGPoint(x: rect.minX + 3, y: rect.maxY - 3))
        p.addLine(to: CGPoint(x: rect.minX + 1, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + 7, y: rect.maxY - 3))
        p.closeSubpath()
        return p
    }
}

private struct SmileArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.minY), radius: rect.width / 2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        return p
    }
}

private struct PhoneReceiverShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.midX + 2, y: rect.midY), control: CGPoint(x: rect.maxX, y: rect.midY - 2))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - 2, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.midY + 2))
        p.addLine(to: CGPoint(x: rect.minX + 2, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.midX - 2, y: rect.midY), control: CGPoint(x: rect.minX, y: rect.midY + 2))
        p.addQuadCurve(to: CGPoint(x: rect.minX + 2, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.midY - 2))
        p.closeSubpath()
        return p
    }
}

private struct PaperPlaneShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.7))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY * 0.6))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY * 0.6))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX * 0.75, y: rect.maxY * 0.75))
        p.closeSubpath()
        return p
    }
}

private struct DocDogEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let fold: CGFloat = 4.5
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct FolderShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + 3))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.minY + 3))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.5, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct TrashCanShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - 1.5, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + 1.5, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct PencilShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY - 4))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 4))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

private struct BookmarkRibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 4))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct FlagBannerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + 2), control: CGPoint(x: rect.midX, y: rect.minY - 2))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - 2), control: CGPoint(x: rect.midX, y: rect.maxY + 2))
        p.closeSubpath()
        return p
    }
}

private struct RefreshArrowsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = rect.width * 0.42
        // Top semi
        p.addArc(center: c, radius: r, startAngle: .degrees(-150), endAngle: .degrees(-10), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - 2))
        // Bottom semi
        p.addArc(center: c, radius: r, startAngle: .degrees(30), endAngle: .degrees(170), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY + 2))
        return p
    }
}

private struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 3, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.maxX - 4, y: rect.maxY - 4), radius: 4, startAngle: .degrees(90), endAngle: .degrees(-45), clockwise: false)
        p.addArc(center: CGPoint(x: rect.midX, y: rect.minY + 4), radius: 5.5, startAngle: .degrees(-30), endAngle: .degrees(-150), clockwise: false)
        p.addArc(center: CGPoint(x: rect.minX + 4, y: rect.maxY - 4), radius: 4, startAngle: .degrees(-135), endAngle: .degrees(90), clockwise: false)
        p.closeSubpath()
        return p
    }
}

private struct CrescentMoonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2, startAngle: .degrees(-110), endAngle: .degrees(110), clockwise: false)
        p.addQuadCurve(to: CGPoint(x: rect.midX + rect.width * 0.15, y: rect.minY + 2), control: CGPoint(x: rect.midX + 2, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

private struct LightningShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX - 2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX + 2, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.minX + 1, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control: CGPoint(x: rect.maxX - 1, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct LeafVeinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 1.5, y: rect.maxY - 1.5))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - 2, y: rect.minY + 2), control: CGPoint(x: rect.midX * 0.9, y: rect.midY * 1.1))
        // Branch veins
        p.move(to: CGPoint(x: rect.width * 0.38, y: rect.height * 0.65))
        p.addLine(to: CGPoint(x: rect.width * 0.22, y: rect.height * 0.50))
        p.move(to: CGPoint(x: rect.width * 0.60, y: rect.height * 0.40))
        p.addLine(to: CGPoint(x: rect.width * 0.74, y: rect.height * 0.54))
        return p
    }
}

private struct WaterDropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.65), control: CGPoint(x: rect.maxX - 1, y: rect.midY))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY * 0.65), radius: rect.width / 2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX + 1, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

private struct FlameOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.7), control: CGPoint(x: rect.maxX + 1, y: rect.minY + 4))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY * 0.7), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX - 1, y: rect.minY + 4))
        p.closeSubpath()
        return p
    }
}

private struct SnowflakeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = rect.width / 2
        for i in 0..<3 {
            let angle = CGFloat(i) * .pi / 3
            let dx = r * cos(angle)
            let dy = r * sin(angle)
            p.move(to: CGPoint(x: c.x - dx, y: c.y - dy))
            p.addLine(to: CGPoint(x: c.x + dx, y: c.y + dy))
        }
        return p
    }
}

private struct MapPinTeardropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + rect.width * 0.5),
                   control1: CGPoint(x: rect.midX - 2, y: rect.maxY * 0.65),
                   control2: CGPoint(x: rect.minX, y: rect.maxY * 0.45))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.minY + rect.width * 0.5),
                 radius: rect.width / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                   control1: CGPoint(x: rect.maxX, y: rect.maxY * 0.45),
                   control2: CGPoint(x: rect.midX + 2, y: rect.maxY * 0.65))
        p.closeSubpath()
        return p
    }
}

private struct NavCompassShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY * 0.75))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct TrophyCupShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 3.5, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - 3.5, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX - 2, y: rect.maxY * 0.75))
        p.addQuadCurve(to: CGPoint(x: rect.minX + 3.5, y: rect.minY), control: CGPoint(x: rect.minX + 2, y: rect.maxY * 0.75))
        // Handles
        p.move(to: CGPoint(x: rect.minX + 3.5, y: rect.minY + 2))
        p.addQuadCurve(to: CGPoint(x: rect.minX + 3.5, y: rect.maxY * 0.55), control: CGPoint(x: rect.minX - 2, y: rect.midY))
        p.move(to: CGPoint(x: rect.maxX - 3.5, y: rect.minY + 2))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - 3.5, y: rect.maxY * 0.55), control: CGPoint(x: rect.maxX + 2, y: rect.midY))
        return p
    }
}

private struct UserBustShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

private struct ChevronShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return p
    }
}

private struct BackspaceTagShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}
