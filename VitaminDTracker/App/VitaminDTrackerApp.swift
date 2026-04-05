import SwiftUI

/// Main app entry point.
@main
struct VitaminDTrackerApp: App {

    init() {
        AnalyticsService.shared.log(.appOpen)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
