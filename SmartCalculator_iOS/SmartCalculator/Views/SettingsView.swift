import SwiftUI

/// Simple settings sheet: appearance, haptics, and "about" information.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKeys.appearance) private var appearanceRaw: String = AppearanceMode.system.rawValue
    @AppStorage(SettingsKeys.haptics) private var hapticsEnabled: Bool = true

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearanceRaw) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Feedback") {
                    Toggle("Haptic feedback on calculator keys", isOn: $hapticsEnabled)
                }

                Section("About") {
                    LabeledContent("Version", value: version)
                    Text("Smart Calculator is a college project built with Swift and SwiftUI. Currency rates come from the ExchangeRate-API open endpoint and are updated once per day by the provider.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    if let url = URL(string: AppConfiguration.attributionURL) {
                        Link(AppConfiguration.attributionText, destination: url)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
