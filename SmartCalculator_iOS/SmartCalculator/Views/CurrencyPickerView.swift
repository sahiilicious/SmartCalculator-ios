import SwiftUI

/// Searchable list of currencies, with the popular ones on top.
struct CurrencyPickerView: View {
    let title: String
    let codes: [String]
    @Binding var selection: String

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var popular: [String] {
        CurrencyCatalog.popularCodes.filter { codes.contains($0) && matches($0) }
    }

    private var others: [String] {
        codes.filter { !CurrencyCatalog.popularCodes.contains($0) && matches($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !popular.isEmpty {
                    Section("Popular") {
                        ForEach(popular, id: \.self) { code in row(code) }
                    }
                }
                if !others.isEmpty {
                    Section("All currencies") {
                        ForEach(others, id: \.self) { code in row(code) }
                    }
                }
                if popular.isEmpty && others.isEmpty {
                    Text("No currencies match “\(searchText)”.")
                        .foregroundColor(.secondary)
                }
            }
            .searchable(text: $searchText, prompt: "Search code or name")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func row(_ code: String) -> some View {
        Button {
            selection = code
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(code).font(.headline)
                    Text(CurrencyCatalog.name(for: code))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if code == selection {
                    Image(systemName: "checkmark").foregroundColor(Theme.accent)
                }
            }
        }
        .foregroundColor(.primary)
    }

    private func matches(_ code: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return code.localizedCaseInsensitiveContains(query)
            || CurrencyCatalog.name(for: code).localizedCaseInsensitiveContains(query)
    }
}
