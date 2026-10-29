import SwiftUI

/// Currency converter with live rates, offline cache and clear status messages.
struct CurrencyConverterView: View {
    @StateObject private var viewModel = CurrencyViewModel()
    @FocusState private var amountFocused: Bool
    @State private var picker: PickerTarget?

    private enum PickerTarget: String, Identifiable {
        case from, to
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView {
                VStack(spacing: 14) {
                    statusArea

                    VStack(spacing: 0) {
                        amountCard

                        HStack {
                            Spacer()
                            CircleIconButton(systemName: "arrow.up.arrow.down",
                                             accessibilityLabel: "Swap currencies") {
                                Haptics.tap()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    viewModel.swapCurrencies()
                                }
                            }
                            Spacer()
                        }
                        .frame(height: 56)

                        resultCard
                    }

                    rateCard
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Button {
                        Task { await viewModel.refresh(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh exchange rates")
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { amountFocused = false }
            }
        }
        .sheet(item: $picker) { target in
            CurrencyPickerView(
                title: target == .from ? "From currency" : "To currency",
                codes: viewModel.availableCodes,
                selection: target == .from ? $viewModel.fromCode : $viewModel.toCode
            )
        }
        .task {
            await viewModel.refresh()
        }
    }

    // MARK: - Status banners

    @ViewBuilder
    private var statusArea: some View {
        if viewModel.isLoading && viewModel.rates == nil {
            HStack(spacing: 12) {
                ProgressView()
                Text("Loading exchange rates…")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
        }

        if let error = viewModel.errorMessage {
            if viewModel.rates == nil {
                NoticeBanner(kind: .error,
                             message: "\(error) Currency conversion needs rates to be downloaded at least once.",
                             actionTitle: "Try again") {
                    Task { await viewModel.refresh(force: true) }
                }
            } else {
                NoticeBanner(kind: .warning,
                             message: "\(error) Showing saved rates from \(viewModel.lastUpdatedText ?? "an earlier download"). They may be out of date.",
                             actionTitle: "Try again") {
                    Task { await viewModel.refresh(force: true) }
                }
            }
        } else if viewModel.isShowingCachedRates {
            NoticeBanner(kind: .warning,
                         message: "Showing saved rates from \(viewModel.lastUpdatedText ?? "an earlier download"). They are not live.")
        }

        if let info = viewModel.infoMessage {
            NoticeBanner(kind: .info, message: info)
        }
    }

    // MARK: - Cards

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AMOUNT")
                .font(.caption.weight(.semibold))
                .foregroundColor(Theme.textSecondary)

            HStack {
                TextField("0", text: $viewModel.amountText)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .minimumScaleFactor(0.5)
                    .accessibilityLabel("Amount to convert")

                if !viewModel.amountText.isEmpty {
                    Button {
                        viewModel.amountText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(Theme.textSecondary)
                    }
                    .accessibilityLabel("Clear amount")
                }
            }

            CurrencyButton(code: viewModel.fromCode) { picker = .from }
        }
        .cardStyle()
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONVERTED")
                .font(.caption.weight(.semibold))
                .foregroundColor(Theme.textSecondary)

            HStack {
                if viewModel.isLoading && viewModel.rates == nil {
                    ProgressView()
                } else {
                    Text(viewModel.convertedText)
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .foregroundColor(viewModel.convertedText == "—" ? Theme.textSecondary : Theme.textPrimary)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .textSelection(.enabled)
                        .accessibilityLabel("Converted amount")
                        .accessibilityValue(viewModel.convertedText == "—"
                                            ? "No result"
                                            : "\(viewModel.convertedText) \(viewModel.toCode)")
                }
                Spacer(minLength: 0)
            }

            CurrencyButton(code: viewModel.toCode) { picker = .to }

            if let message = viewModel.validationMessage {
                NoticeBanner(kind: .error, message: message)
            }
        }
        .cardStyle()
    }

    private var rateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let line = viewModel.rateLine {
                Text(line)
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            } else {
                Text("Exchange rate unavailable")
                    .font(.headline)
                    .foregroundColor(Theme.textSecondary)
            }

            if let updated = viewModel.lastUpdatedText {
                Label("Rates last updated: \(updated)", systemImage: "clock")
                    .font(.footnote)
                    .foregroundColor(Theme.textSecondary)
            }

            Text("The provider publishes new rates once per day, so values can differ from bank or card rates.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let url = URL(string: AppConfiguration.attributionURL) {
                Link(AppConfiguration.attributionText, destination: url)
                    .font(.caption.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

/// Button that shows a currency code + name and opens the picker.
private struct CurrencyButton: View {
    let code: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(code)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text(CurrencyCatalog.name(for: code))
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
        }
        .accessibilityLabel("Currency")
        .accessibilityValue("\(code), \(CurrencyCatalog.name(for: code))")
    }
}
