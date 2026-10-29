import SwiftUI

/// Sheet listing past calculations. Tap one to reuse its result.
struct HistoryView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                if viewModel.history.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(viewModel.history) { entry in
                            Button {
                                viewModel.reuse(entry)
                                dismiss()
                            } label: {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(entry.expression)
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.trailing)
                                    Text("= \(entry.result)")
                                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                        .minimumScaleFactor(0.5)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Theme.card)
                            .accessibilityHint("Loads this result into the calculator")
                        }
                        .onDelete { offsets in
                            viewModel.deleteHistory(at: offsets)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { confirmClear = true }
                        .disabled(viewModel.history.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Clear all calculation history?",
                                isPresented: $confirmClear,
                                titleVisibility: .visible) {
                Button("Clear History", role: .destructive) {
                    viewModel.clearHistory()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 44))
                .foregroundColor(Theme.textSecondary)
            Text("No calculations yet")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            Text("Finished calculations appear here.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}
