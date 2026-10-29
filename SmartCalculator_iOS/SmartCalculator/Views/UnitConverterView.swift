import SwiftUI
import UIKit

/// Generic converter screen used by Length, Mass, Volume, Temperature, Speed, Angle and Area.
struct UnitConverterView: View {
    @StateObject private var viewModel: UnitConverterViewModel
    @FocusState private var amountFocused: Bool

    init(category: ConversionCategory) {
        _viewModel = StateObject(wrappedValue: UnitConverterViewModel(category: category))
    }

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView {
                VStack(spacing: 0) {
                    inputCard

                    HStack {
                        Spacer()
                        CircleIconButton(systemName: "arrow.up.arrow.down",
                                         accessibilityLabel: "Swap units") {
                            Haptics.tap()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                viewModel.swapUnits()
                            }
                        }
                        Spacer()
                    }
                    .frame(height: 56)

                    resultCard

                    VStack(spacing: 12) {
                        if let relation = viewModel.relationText {
                            Text(relation)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .accessibilityLabel("Conversion rate: \(relation)")
                        }

                        if let message = viewModel.errorMessage {
                            NoticeBanner(kind: .error, message: message)
                        }

                        Button {
                            amountFocused = false
                            withAnimation { viewModel.reset() }
                        } label: {
                            Label("Clear", systemImage: "xmark.circle")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Theme.card))
                                .overlay(Capsule().stroke(Theme.cardStroke, lineWidth: 1))
                                .foregroundColor(Theme.textPrimary)
                        }
                        .disabled(viewModel.inputText.isEmpty)
                        .opacity(viewModel.inputText.isEmpty ? 0.5 : 1)
                    }
                    .padding(.top, 18)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(viewModel.category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { amountFocused = false }
            }
        }
    }

    // MARK: - Cards

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FROM")
                .font(.caption.weight(.semibold))
                .foregroundColor(Theme.textSecondary)

            HStack {
                TextField("0", text: $viewModel.inputText)
                    .keyboardType(viewModel.keyboardAllowsNegative ? .numbersAndPunctuation : .decimalPad)
                    .focused($amountFocused)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .minimumScaleFactor(0.5)
                    .accessibilityLabel("Amount to convert")

                if !viewModel.inputText.isEmpty {
                    Button {
                        viewModel.inputText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.textSecondary)
                    }
                    .accessibilityLabel("Clear amount")
                }
            }

            UnitMenuButton(title: "From unit",
                           selection: $viewModel.fromUnit,
                           units: viewModel.category.units)
        }
        .cardStyle()
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TO")
                .font(.caption.weight(.semibold))
                .foregroundColor(Theme.textSecondary)

            HStack {
                Text(viewModel.resultText)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundColor(viewModel.hasResult ? Theme.textPrimary : Theme.textSecondary)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .textSelection(.enabled)
                    .accessibilityLabel("Result")
                    .accessibilityValue(viewModel.hasResult
                                        ? "\(viewModel.resultText) \(viewModel.toUnit.name)"
                                        : "No result yet")
                Spacer(minLength: 0)
                if viewModel.hasResult {
                    Button {
                        UIPasteboard.general.string = viewModel.resultText
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(Theme.accent)
                    }
                    .accessibilityLabel("Copy result")
                }
            }

            UnitMenuButton(title: "To unit",
                           selection: $viewModel.toUnit,
                           units: viewModel.category.units)
        }
        .cardStyle()
    }
}

/// Dropdown button that shows the selected unit's name and symbol.
struct UnitMenuButton: View {
    let title: String
    @Binding var selection: ConversionUnit
    let units: [ConversionUnit]

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(units) { unit in
                    Text(menuTitle(for: unit)).tag(unit)
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selection.name)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    HStack(spacing: 6) {
                        Text(selection.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Theme.accent)
                        if let note = selection.note {
                            Text(note)
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
        }
        .accessibilityLabel(title)
        .accessibilityValue(selection.name)
    }

    private func menuTitle(for unit: ConversionUnit) -> String {
        "\(unit.name) (\(unit.symbol))"
    }
}
