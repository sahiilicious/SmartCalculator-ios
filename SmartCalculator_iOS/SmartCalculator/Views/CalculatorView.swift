import SwiftUI

/// Standard calculator screen: display on top, 5 × 4 keypad below.
struct CalculatorView: View {
    @StateObject private var viewModel = CalculatorViewModel()
    @State private var showHistory = false

    private let spacing: CGFloat = 12
    private let horizontalPadding: CGFloat = 16

    var body: some View {
        ZStack {
            ScreenBackground()

            GeometryReader { proxy in
                let keys = keySize(for: proxy.size)
                VStack(spacing: 0) {
                    display
                    keypad(width: keys.width, height: keys.height)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, 12)
                }
            }
        }
        .navigationTitle("Calculator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel("History")
            }
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(viewModel: viewModel)
        }
    }

    // MARK: - Display

    private var display: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Spacer(minLength: 0)
            Text(viewModel.expressionText)
                .font(.system(size: 22, weight: .regular, design: .rounded))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.head)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(minHeight: 28)

            Text(viewModel.displayText)
                .font(.system(size: 64, weight: .light, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Display")
        .accessibilityValue(viewModel.accessibilityValue)
    }

    // MARK: - Keypad

    /// Works out button sizes so the keypad fits any iPhone without clipping.
    private func keySize(for size: CGSize) -> CGSize {
        let width = (size.width - horizontalPadding * 2 - spacing * 3) / 4
        let maxKeypadHeight = size.height * 0.62
        let heightLimit = (maxKeypadHeight - spacing * 4) / 5
        let height = max(44, min(width, heightLimit))
        return CGSize(width: max(44, width), height: height)
    }

    private func keypad(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: spacing) {
            ForEach(Array(CalcKey.layout.enumerated()), id: \.offset) { _, row in
                HStack(spacing: spacing) {
                    ForEach(row, id: \.id) { key in
                        CalculatorKeyButton(
                            key: key,
                            isActive: isActive(key),
                            width: width,
                            height: height
                        ) {
                            withAnimation(.easeOut(duration: 0.1)) {
                                viewModel.handle(key)
                            }
                        }
                    }
                }
            }
        }
    }

    private func isActive(_ key: CalcKey) -> Bool {
        if case .op(let op) = key { return viewModel.pendingOperator == op }
        return false
    }
}

/// One rounded key on the keypad.
private struct CalculatorKeyButton: View {
    let key: CalcKey
    let isActive: Bool
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .frame(width: width, height: height)
                .foregroundColor(foreground)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: height * 0.32, style: .continuous))
                .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(key.accessibilityLabel)
    }

    @ViewBuilder
    private var label: some View {
        let size = min(height * 0.42, 30)
        switch key {
        case .backspace:
            Image(systemName: "delete.left")
                .font(.system(size: size, weight: .medium))
        case .sign:
            Image(systemName: "plusminus")
                .font(.system(size: size, weight: .medium))
        case .digit(let digit):
            Text(digit).font(.system(size: size + 4, weight: .medium, design: .rounded))
        case .decimal:
            Text(Locale.current.decimalSeparator ?? ".")
                .font(.system(size: size + 4, weight: .medium, design: .rounded))
        case .op(let op):
            Text(op.rawValue).font(.system(size: size + 6, weight: .medium, design: .rounded))
        case .equals:
            Text("=").font(.system(size: size + 6, weight: .medium, design: .rounded))
        case .clear:
            Text("AC").font(.system(size: size, weight: .semibold, design: .rounded))
        case .percent:
            Text("%").font(.system(size: size + 2, weight: .medium, design: .rounded))
        }
    }

    private var foreground: Color {
        switch key {
        case .equals: return .white
        case .op: return isActive ? Theme.accent : .white
        case .clear, .backspace, .percent, .sign: return Theme.textPrimary
        default: return Theme.textPrimary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch key {
        case .equals:
            LinearGradient(colors: [Theme.accentPurple, Theme.accent],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .op:
            if isActive {
                Color.white
            } else {
                Theme.accentGradient
            }
        case .clear, .backspace, .percent, .sign:
            Theme.keyFunction
        default:
            Theme.keyDigit
        }
    }
}
