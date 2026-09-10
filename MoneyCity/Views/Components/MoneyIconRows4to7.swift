import SwiftUI

extension MoneyIconRenderer {
    // MARK: - Row 4 Implementations

    var medicalCrossIcon: some View {
        MedicalCrossShape()
            .fill(overrideColor ?? IconPalette.red)
            .frame(width: 16.5, height: 16.5)
            .overlay(MedicalCrossShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    var gradCapIcon: some View {
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

    var shoppingBagIcon: some View {
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

    var tshirtIcon: some View {
        TShirtShape()
            .fill(overrideColor ?? IconPalette.red)
            .frame(width: 18, height: 15.5)
            .overlay(TShirtShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    var giftIcon: some View {
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

    var ticketIcon: some View {
        TicketNotchedShape()
            .fill(overrideColor ?? IconPalette.blue)
            .frame(width: 19, height: 12)
            .overlay(TicketNotchedShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
            .rotationEffect(.degrees(-10))
    }

    var heartIcon: some View {
        HeartShape()
            .fill(overrideColor ?? IconPalette.red)
            .frame(width: 17, height: 15.5)
            .overlay(HeartShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    var starIcon: some View {
        StarPolygonShape()
            .fill(overrideColor ?? IconPalette.yellow)
            .frame(width: 18, height: 18)
            .overlay(StarPolygonShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    var islandIcon: some View {
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

    var suitcaseIcon: some View {
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

    var mailIcon: some View {
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

    var chatSmileIcon: some View {
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

    var phoneIcon: some View {
        PhoneReceiverShape()
            .fill(overrideColor ?? IconPalette.coral)
            .frame(width: 14.5, height: 14.5)
            .overlay(PhoneReceiverShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
            .rotationEffect(.degrees(10))
    }

    var paperPlaneIcon: some View {
        PaperPlaneShape()
            .fill(overrideColor ?? IconPalette.yellow)
            .frame(width: 16, height: 16)
            .overlay(PaperPlaneShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
            .rotationEffect(.degrees(15))
    }

    var documentIcon: some View {
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

    var folderIcon: some View {
        FolderShape()
            .fill(overrideColor ?? IconPalette.yellow)
            .frame(width: 18, height: 13.5)
            .overlay(FolderShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    var trashIcon: some View {
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

    var pencilIcon: some View {
        PencilShape()
            .fill(overrideColor ?? IconPalette.blue)
            .frame(width: 7, height: 17)
            .overlay(PencilShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
            .rotationEffect(.degrees(45))
    }

    var bookmarkIcon: some View {
        BookmarkRibbonShape()
            .fill(overrideColor ?? IconPalette.red)
            .frame(width: 13.5, height: 17)
            .overlay(BookmarkRibbonShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    var flagIcon: some View {
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

    var clockIcon: some View {
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

    var refreshIcon: some View {
        RefreshArrowsShape()
            .stroke(overrideColor ?? IconPalette.green, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
            .frame(width: 16.5, height: 16.5)
    }

    var cloudIcon: some View {
        CloudShape()
            .fill(overrideColor ?? IconPalette.blue)
            .frame(width: 18.5, height: 12.5)
            .overlay(CloudShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    var sunIcon: some View {
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

    var moonIcon: some View {
        CrescentMoonShape()
            .fill(overrideColor ?? IconPalette.yellow)
            .frame(width: 14, height: 16.5)
            .overlay(CrescentMoonShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    var lightningIcon: some View {
        LightningShape()
            .fill(overrideColor ?? IconPalette.green)
            .frame(width: 11.5, height: 18)
            .overlay(LightningShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    var leafIcon: some View {
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

    var waterDropIcon: some View {
        WaterDropShape()
            .fill(overrideColor ?? IconPalette.blue)
            .frame(width: 13, height: 17)
            .overlay(WaterDropShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
    }

    var flameIcon: some View {
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

    var snowflakeIcon: some View {
        SnowflakeShape()
            .stroke(overrideColor ?? IconPalette.blue, style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
            .frame(width: 18, height: 18)
    }

    // MARK: - Row 7 Implementations

    var checkCircleIcon: some View {
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

    var xmarkCircleIcon: some View {
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

    var warningCircleIcon: some View {
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

    var infoCircleIcon: some View {
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

    var questionCircleIcon: some View {
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

    var mapPinIcon: some View {
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

    var navigationIcon: some View {
        NavCompassShape()
            .fill(overrideColor ?? IconPalette.blue)
            .frame(width: 16.5, height: 16.5)
            .overlay(NavCompassShape().stroke(black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)))
            .rotationEffect(.degrees(15))
    }

    var globeIcon: some View {
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

    var trophyIcon: some View {
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

    var userIcon: some View {
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

    var chevronLeftIcon: some View {
        ChevronShape()
            .stroke(overrideColor ?? black, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
            .frame(width: 8, height: 13)
            .rotationEffect(.degrees(180))
    }

    var chevronRightIcon: some View {
        ChevronShape()
            .stroke(overrideColor ?? black, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
            .frame(width: 8, height: 13)
    }

    var chevronDownIcon: some View {
        ChevronShape()
            .stroke(overrideColor ?? black, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
            .frame(width: 8, height: 13)
            .rotationEffect(.degrees(90))
    }

    var chevronUpIcon: some View {
        ChevronShape()
            .stroke(overrideColor ?? black, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
            .frame(width: 8, height: 13)
            .rotationEffect(.degrees(-90))
    }

    var backspaceIcon: some View {
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

    var targetIcon: some View {
        ZStack {
            Circle().stroke(black, lineWidth: strokeWidth).frame(width: 18, height: 18)
            Circle().fill(overrideColor ?? IconPalette.red).frame(width: 10, height: 10).overlay(Circle().stroke(black, lineWidth: 1.5))
            Circle().fill(IconPalette.white).frame(width: 4, height: 4)
        }
    }

    var lockIcon: some View {
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

    var citySkylineIcon: some View {
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
