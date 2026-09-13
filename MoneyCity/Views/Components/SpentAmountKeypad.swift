import SwiftUI

/// Reusable numeric keypad adhering to SPENT design language, tactile haptics, and responsive micro-interactions.
public struct SpentAmountKeypad: View {
    @Binding public var amountText: String
    public var onKeypadPress: ((String) -> Void)?

    public init(
        amountText: Binding<String>,
        onKeypadPress: ((String) -> Void)? = nil
    ) {
        self._amountText = amountText
        self.onKeypadPress = onKeypadPress
    }

    private let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]

    public var body: some View {
        VStack(spacing: 8) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        Button(action: {
                            handleKeyPress(key)
                        }) {
                            keypadCell(key: key)
                        }
                        .buttonStyle(KeypadInteractiveButtonStyle(isDelete: key == "⌫"))
                    }
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder
    private func keypadCell(key: String) -> some View {
        ZStack {
            if key == "⌫" {
                MoneyIcon(.backspace, size: 22)
            } else if key == "." {
                Text("•")
                    .font(.system(size: 24, weight: .black, design: .rounded))
            } else {
                Text(key)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .contentShape(Rectangle())
    }

    private func handleKeyPress(_ key: String) {
        if key == "⌫" {
            Haptics.impact(.medium)
            if !amountText.isEmpty {
                amountText.removeLast()
            }
        } else if key == "." {
            Haptics.selection()
            if !amountText.contains(".") {
                if amountText.isEmpty {
                    amountText = "0."
                } else {
                    amountText += "."
                }
            }
        } else {
            Haptics.impact(.light)
            // Digits 0-9
            if amountText == "0" {
                amountText = key
            } else {
                // Prevent more than 2 decimal places
                if let dotIndex = amountText.firstIndex(of: ".") {
                    let decimals = amountText.distance(from: dotIndex, to: amountText.endIndex)
                    if decimals <= 2 {
                        amountText += key
                    }
                } else if amountText.count < 8 {
                    amountText += key
                }
            }
        }
        onKeypadPress?(key)
    }
}

// MARK: - Keypad Button Style with Tactile Compression & Tint Pulse
public struct KeypadInteractiveButtonStyle: ButtonStyle {
    public let isDelete: Bool

    public init(isDelete: Bool = false) {
        self.isDelete = isDelete
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(
                configuration.isPressed
                    ? (isDelete ? Color.deleteRed : Color.primaryBlue)
                    : Color.deepNavy
            )
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        configuration.isPressed
                            ? (isDelete ? Color.deleteRed.opacity(0.18) : Color.primaryBlue.opacity(0.16))
                            : Color.white
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                configuration.isPressed
                                    ? (isDelete ? Color.deleteRed.opacity(0.85) : Color.primaryBlue.opacity(0.85))
                                    : Color.borderSubtle.opacity(0.40),
                                lineWidth: configuration.isPressed ? 2.0 : 1.0
                            )
                    )
                    .shadow(
                        color: configuration.isPressed
                            ? (isDelete ? Color.deleteRed.opacity(0.25) : Color.primaryBlue.opacity(0.25))
                            : Color.black.opacity(0.04),
                        radius: configuration.isPressed ? 6 : 3.5,
                        y: configuration.isPressed ? 0.5 : 1.5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.86 : 1.0)
            .animation(.spring(response: 0.14, dampingFraction: 0.58), value: configuration.isPressed)
    }
}
