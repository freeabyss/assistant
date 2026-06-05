import Foundation

/// ViewModel for the settings view.
/// Will be fully implemented in US-009.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var retentionDays: Int = 30
    @Published var maxStorageMB: Int = 500
    @Published var ocrEnabled: Bool = true
    @Published var pollInterval: Double = 500

    func save() async {
        // Will be implemented in US-009
    }

    func resetToDefaults() async {
        retentionDays = 30
        maxStorageMB = 500
        ocrEnabled = true
        pollInterval = 500
    }
}
