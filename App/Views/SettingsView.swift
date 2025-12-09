import SwiftUI
import LocalAuthentication
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: WorkoutStore
    @AppStorage("prefersBiometrics") private var prefersBiometrics = true
    @State private var exportURL: URL?
    @State private var showExporter = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: Binding(get: { store.themeManager.preference }, set: store.updateTheme)) {
                    ForEach(ThemePreference.allCases) { pref in
                        Text(pref.rawValue.capitalized).tag(pref)
                    }
                }
            }

            Section("Security") {
                Toggle("Require Face ID / PIN", isOn: $prefersBiometrics)
            }

            Section("Data") {
                Button("Export CSV") {
                    exportURL = store.exportCSV()
                    showExporter = exportURL != nil
                }
                .fileExporter(isPresented: $showExporter, document: ExportDocument(url: exportURL), contentType: .commaSeparatedText, defaultFilename: "Workouts") { result in
                    switch result {
                    case .success: break
                    case .failure(let error): print("Export failed: \(error.localizedDescription)")
                    }
                }
                Button("Mark HealthKit export") {
                    store.markExportedToHealth(count: store.workouts.count)
                }
                if let last = store.healthExportStatus.lastExportedAt {
                    Text("Last Apple Health export: \(last, style: .date) \(last, style: .time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                Text("Workouts autosave after each change. iCloud sync uses key-value store; CloudKit/Core Data can be swapped in later.")
                    .font(.caption)
                Text("Location prompts trigger when arriving or leaving saved gyms if a workout wasn’t started.")
                    .font(.caption)
            }
        }
        .navigationTitle("Settings")
    }
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var url: URL?

    init(url: URL?) { self.url = url }

    init(configuration: ReadConfiguration) throws { }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url else { return FileWrapper(regularFileWithContents: Data()) }
        let data = try Data(contentsOf: url)
        return FileWrapper(regularFileWithContents: data)
    }
}
