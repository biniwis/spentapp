import SwiftUI

public struct SwipeActionRow<ID: Hashable, Content: View>: View {
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.layoutDirection) private var envLayoutDirection

    let id: ID
    @Binding var openSwipeRowID: ID?
    let onEdit: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    // Internal gesture & animation state
    @State private var offset: CGFloat = 0
    @State private var startOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var isCommitArmed: Bool = false
    @State private var didFireCommitHaptic: Bool = false
    @State private var didFireOpenHaptic: Bool = false
    @State private var gestureDirectionLocked: SwipeGestureDirection? = nil

    private enum SwipeGestureDirection {
        case horizontal
        case vertical
    }

    private let actionWidth: CGFloat = 76
    private let openThreshold: CGFloat = 42
    private let commitThreshold: CGFloat = 120
    private let resistanceFactor: CGFloat = 0.22

    public init(
        id: ID,
        openSwipeRowID: Binding<ID?>,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.id = id
        self._openSwipeRowID = openSwipeRowID
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.content = content
    }

    private var isRTL: Bool {
        envLayoutDirection == .rightToLeft || l10n.isHebrew
    }

    public var body: some View {
        ZStack {
            // MARK: - Action Buttons Layer Underneath (Fixed physical LTR coordinates)
            ZStack {
                // Physical RIGHT gap (revealed when row moves LEFT, offset < 0)
                if offset < 0 {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        if isRTL {
                            editActionButton(width: max(actionWidth, -offset))
                        } else {
                            deleteActionButton(width: max(actionWidth, -offset))
                        }
                    }
                }

                // Physical LEFT gap (revealed when row moves RIGHT, offset > 0)
                if offset > 0 {
                    HStack(spacing: 0) {
                        if isRTL {
                            deleteActionButton(width: max(actionWidth, offset))
                        } else {
                            editActionButton(width: max(actionWidth, offset))
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            // MARK: - Foreground Content Layer
            content()
                .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                .background(Color.appBackground)
                .contentShape(Rectangle())
                .offset(x: offset)
                .onTapGesture {
                    if openSwipeRowID != nil || offset != 0 {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            offset = 0
                            openSwipeRowID = nil
                        }
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8, coordinateSpace: .local)
                        .onChanged { value in
                            let transX = value.translation.width
                            let transY = value.translation.height

                            if gestureDirectionLocked == nil {
                                let absX = abs(transX)
                                let absY = abs(transY)
                                if absX > 8 || absY > 8 {
                                    if absX > absY * 1.15 {
                                        gestureDirectionLocked = .horizontal
                                        isDragging = true
                                        startOffset = offset
                                        if openSwipeRowID != id {
                                            openSwipeRowID = nil
                                        }
                                    } else {
                                        gestureDirectionLocked = .vertical
                                        return
                                    }
                                } else {
                                    return
                                }
                            }

                            guard gestureDirectionLocked == .horizontal else { return }

                            let rawTarget = startOffset + transX

                            // In RTL:
                            // Dragging LEFT (rawTarget < 0) -> EDIT
                            // Dragging RIGHT (rawTarget > 0) -> DELETE
                            // In LTR:
                            // Dragging LEFT (rawTarget < 0) -> DELETE
                            // Dragging RIGHT (rawTarget > 0) -> EDIT
                            let isEditDirection = isRTL ? (rawTarget < 0) : (rawTarget > 0)
                            let isDeleteDirection = isRTL ? (rawTarget > 0) : (rawTarget < 0)
                            let dragMagnitude = abs(rawTarget)

                            if isEditDirection {
                                // EDIT DIRECTION - Supports full swipe commit
                                if dragMagnitude >= openThreshold && !didFireOpenHaptic {
                                    Haptics.selection()
                                    didFireOpenHaptic = true
                                }

                                if dragMagnitude >= commitThreshold {
                                    if !isCommitArmed {
                                        withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) {
                                            isCommitArmed = true
                                        }
                                    }
                                    if !didFireCommitHaptic {
                                        Haptics.impact(.medium)
                                        didFireCommitHaptic = true
                                    }
                                    // Rubber-band resistance past commit threshold
                                    let extra = dragMagnitude - commitThreshold
                                    let clamped = commitThreshold + extra * 0.35
                                    offset = isRTL ? -clamped : clamped
                                } else {
                                    if isCommitArmed {
                                        withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) {
                                            isCommitArmed = false
                                        }
                                    }
                                    offset = rawTarget
                                }
                            } else if isDeleteDirection {
                                // DELETE DIRECTION - NEVER auto-commit!
                                isCommitArmed = false

                                if dragMagnitude >= openThreshold && !didFireOpenHaptic {
                                    Haptics.selection()
                                    didFireOpenHaptic = true
                                }

                                // Strong resistance past actionWidth
                                if dragMagnitude > actionWidth {
                                    let extra = dragMagnitude - actionWidth
                                    let dampened = actionWidth + extra * resistanceFactor
                                    offset = isRTL ? dampened : -dampened
                                } else {
                                    offset = rawTarget
                                }
                            } else {
                                offset = 0
                            }
                        }
                        .onEnded { value in
                            guard gestureDirectionLocked == .horizontal else {
                                gestureDirectionLocked = nil
                                isDragging = false
                                return
                            }

                            let predictedX = value.predictedEndTranslation.width
                            let finalTarget = offset
                            let predictedTarget = startOffset + predictedX

                            let isEditDirection = isRTL ? (finalTarget < 0) : (finalTarget > 0)
                            let isDeleteDirection = isRTL ? (finalTarget > 0) : (finalTarget < 0)
                            let dragMagnitude = abs(finalTarget)
                            let predictedMagnitude = abs(predictedTarget)

                            let wasArmed = isCommitArmed
                            isCommitArmed = false
                            didFireCommitHaptic = false
                            didFireOpenHaptic = false
                            gestureDirectionLocked = nil
                            isDragging = false

                            if isEditDirection {
                                let isVelocityCommit = dragMagnitude >= 65 && predictedMagnitude >= 140
                                if wasArmed || isVelocityCommit {
                                    // AUTO-COMMIT EDIT!
                                    openSwipeRowID = nil
                                    withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
                                        offset = 0
                                    }
                                    onEdit()
                                } else if dragMagnitude >= openThreshold {
                                    // Snap open to actionWidth
                                    let snapOffset: CGFloat = isRTL ? -actionWidth : actionWidth
                                    withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                                        offset = snapOffset
                                    }
                                    openSwipeRowID = id
                                } else {
                                    // Snap back closed
                                    withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                                        offset = 0
                                    }
                                    if openSwipeRowID == id { openSwipeRowID = nil }
                                }
                            } else if isDeleteDirection {
                                // DELETE DIRECTION - Tap only, never auto-commit
                                if dragMagnitude >= openThreshold {
                                    let snapOffset: CGFloat = isRTL ? actionWidth : -actionWidth
                                    withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                                        offset = snapOffset
                                    }
                                    openSwipeRowID = id
                                } else {
                                    withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                                        offset = 0
                                    }
                                    if openSwipeRowID == id { openSwipeRowID = nil }
                                }
                            } else {
                                withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                                    offset = 0
                                }
                                if openSwipeRowID == id { openSwipeRowID = nil }
                            }
                        }
                )
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 20)
        .onChange(of: openSwipeRowID) { _, newOpenID in
            if newOpenID != id && offset != 0 {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.85)) {
                    offset = 0
                }
            }
        }
    }

    // MARK: - Edit Action Button View
    private func editActionButton(width: CGFloat) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
                offset = 0
                openSwipeRowID = nil
            }
            onEdit()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.deepNavy)

                VStack(spacing: 3) {
                    Image(systemName: "pencil")
                        .font(.system(size: isCommitArmed ? 20 : 17, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(isCommitArmed ? 1.14 : 1.0)
                        .animation(.spring(response: 0.18, dampingFraction: 0.65), value: isCommitArmed)

                    Text(l10n.language == .hebrew ? "עריכה" : "Edit")
                        .font(.system(size: 11.5, weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(isCommitArmed ? 0.0 : 0.95))
                        .animation(.easeInOut(duration: 0.15), value: isCommitArmed)
                }
            }
            .frame(width: width, height: 50)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Delete Action Button View
    private func deleteActionButton(width: CGFloat) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
                offset = 0
                openSwipeRowID = nil
            }
            onDelete()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 239/255, green: 68/255, blue: 68/255))

                VStack(spacing: 3) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    Text(l10n.language == .hebrew ? "מחיקה" : "Delete")
                        .font(.system(size: 11.5, weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(0.95))
                }
            }
            .frame(width: width, height: 50)
        }
        .buttonStyle(.plain)
    }
}
