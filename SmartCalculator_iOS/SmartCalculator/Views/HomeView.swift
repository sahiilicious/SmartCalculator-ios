import SwiftUI

/// Where each home-screen card leads.
enum AppDestination: Hashable {
    case calculator
    case currency
    case converter(ConversionCategory)
}

/// Home screen: title + a grid of cards, one per tool.
struct HomeView: View {
    @State private var showSettings = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header

                        NavigationLink(value: AppDestination.calculator) {
                            CalculatorHeroCard()
                        }
                        .buttonStyle(PressableButtonStyle())

                        Text("Converters")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(Theme.textPrimary)

                        LazyVGrid(columns: columns, spacing: 14) {
                            NavigationLink(value: AppDestination.currency) {
                                HomeCard(title: "Currency",
                                         subtitle: "Live exchange rates",
                                         symbol: "dollarsign.arrow.circlepath",
                                         gradient: LinearGradient(
                                            colors: [Color(hex: 0x2FBF71), Color(hex: 0x1E8F9E)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                            .buttonStyle(PressableButtonStyle())

                            ForEach(ConversionCategory.allCases) { category in
                                NavigationLink(value: AppDestination.converter(category)) {
                                    HomeCard(title: category.title,
                                             subtitle: category.subtitle,
                                             symbol: category.symbolName,
                                             gradient: category.gradient)
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppDestination.self) { destination in
                destinationView(destination)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Calculator")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("Calculate and convert anything")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.card))
                    .overlay(Circle().stroke(Theme.cardStroke, lineWidth: 1))
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func destinationView(_ destination: AppDestination) -> some View {
        switch destination {
        case .calculator:
            CalculatorView()
        case .currency:
            CurrencyConverterView()
        case .converter(let category):
            UnitConverterView(category: category)
        }
    }
}

/// Large card for the standard calculator.
private struct CalculatorHeroCard: View {
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Calculator")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Text("Standard arithmetic with history")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "plus.forwardslash.minus")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Color.white.opacity(0.18)))
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.accentGradient)
        )
        .shadow(color: Theme.accent.opacity(0.35), radius: 14, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calculator. Standard arithmetic with history.")
    }
}

/// Square-ish card for a converter.
private struct HomeCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let gradient: LinearGradient

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(gradient))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}
