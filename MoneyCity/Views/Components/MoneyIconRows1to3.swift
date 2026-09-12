import SwiftUI

extension MoneyIconRenderer {
    // MARK: - Row 1 Implementations

    var homeIcon: some View {
        ZStack {
            // Walls
            RoundedRectangle(cornerRadius: 1.5)
                .fill(overrideColor != nil ? overrideColor!.opacity(0.18) : IconPalette.warmCream)
                .frame(width: 14, height: 11)
                .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(black, lineWidth: strokeWidth))
                .offset(y: 4)

            // Roof
            RoofTriangleShape()
                .fill(overrideColor ?? IconPalette.orangeRed)
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

    var barChartIcon: some View {
        ZStack(alignment: .bottom) {
            // Ground baseline shelf
            Capsule()
                .fill(black)
                .frame(width: 19, height: 1.8)
                .offset(y: 1.0)

            // Bar 1 (Left: Violet Blue)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(overrideColor ?? IconPalette.violetBlue)
                .frame(width: 4.5, height: 7.5)
                .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(black, lineWidth: strokeWidth))
                .offset(x: -6.0, y: 0)

            // Bar 2 (Middle: Lucky Green)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(overrideColor ?? IconPalette.luckyGreen)
                .frame(width: 4.5, height: 12.0)
                .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(black, lineWidth: strokeWidth))
                .offset(x: 0, y: 0)

            // Bar 3 (Right: Orange Red)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(overrideColor ?? IconPalette.orangeRed)
                .frame(width: 4.5, height: 16.5)
                .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(black, lineWidth: strokeWidth))
                .offset(x: 6.0, y: 0)
        }
        .frame(width: 20, height: 18)
    }

    var creditCardIcon: some View {
        ZStack {
            // Card Body
            RoundedRectangle(cornerRadius: 3.5)
                .fill(overrideColor ?? IconPalette.violetBlue)
                .frame(width: 19, height: 13.5)
                .overlay(RoundedRectangle(cornerRadius: 3.5).stroke(black, lineWidth: strokeWidth))

            // Dark magnetic stripe across the top
            Rectangle()
                .fill(black)
                .frame(width: 19, height: 2.8)
                .offset(y: -2.8)

            // Smart Chip (Neon Lime with outline)
            RoundedRectangle(cornerRadius: 1)
                .fill(IconPalette.neonLime)
                .frame(width: 4.2, height: 3)
                .overlay(RoundedRectangle(cornerRadius: 1).stroke(black, lineWidth: 1.0))
                .offset(x: -4.2, y: 2.2)

            // Card embossed dots/lines
            HStack(spacing: 1.5) {
                RoundedRectangle(cornerRadius: 0.5).fill(IconPalette.babyBlue).frame(width: 2.5, height: 1.5)
                RoundedRectangle(cornerRadius: 0.5).fill(IconPalette.babyBlue).frame(width: 2.5, height: 1.5)
                RoundedRectangle(cornerRadius: 0.5).fill(IconPalette.babyBlue).frame(width: 2.5, height: 1.5)
            }
            .offset(x: 2.8, y: 2.2)
        }
    }

    var receiptIcon: some View {
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

    var coinsIcon: some View {
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

    var pieChartIcon: some View {
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

    var calendarIcon: some View {
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

    var bellIcon: some View {
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

    var searchIcon: some View {
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

    var gearIcon: some View {
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

    var plusCircleIcon: some View {
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

    var minusCircleIcon: some View {
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

    var uploadIcon: some View {
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

    var downloadIcon: some View {
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

    var exchangeIcon: some View {
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

    var cameraIcon: some View {
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

    var photoIcon: some View {
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

    var scanIcon: some View {
        ZStack {
            CornerBracketsShape()
                .stroke(overrideColor ?? IconPalette.blue, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                .frame(width: 17, height: 17)
        }
    }

    var slidersIcon: some View {
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

    var chatDotsIcon: some View {
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

    var cartIcon: some View {
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

    var cutleryIcon: some View {
        HStack(spacing: 6) {
            // Fork
            VStack(spacing: 0) {
                ForkProngsShape()
                    .stroke(black, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 5.5, height: 7)
                RoundedRectangle(cornerRadius: 1)
                    .fill(overrideColor ?? IconPalette.orangeRed)
                    .frame(width: 2.6, height: 9)
                    .overlay(RoundedRectangle(cornerRadius: 1).stroke(black, lineWidth: 1.4))
            }

            // Knife
            VStack(spacing: 0) {
                KnifeBladeShape()
                    .fill(IconPalette.warmCream)
                    .frame(width: 3.5, height: 8)
                    .overlay(KnifeBladeShape().stroke(black, lineWidth: 1.6))
                RoundedRectangle(cornerRadius: 1)
                    .fill(overrideColor ?? IconPalette.orangeRed)
                    .frame(width: 2.6, height: 9)
                    .overlay(RoundedRectangle(cornerRadius: 1).stroke(black, lineWidth: 1.4))
            }
        }
    }

    var coffeeIcon: some View {
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

    var carIcon: some View {
        ZStack {
            // Car Body
            CarBodyShape()
                .fill(overrideColor ?? IconPalette.babyBlue)
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
                .fill(IconPalette.neonLime)
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

    var gasPumpIcon: some View {
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

    var busIcon: some View {
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

    var airplaneIcon: some View {
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

    var dumbbellIcon: some View {
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

    var gamepadIcon: some View {
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

    var pawIcon: some View {
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

}
