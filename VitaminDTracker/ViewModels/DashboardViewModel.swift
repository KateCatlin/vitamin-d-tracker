import Foundation
import VitaminDTrackerCore
import SwiftUI

#if canImport(Combine)
import Combine
#endif

/// View model for the main dashboard screen.
@MainActor
class DashboardViewModel: ObservableObject {

    @Published var currentEstimate: VitaminDStateEstimate?
    @Published var baselineLevel: Double = 0
    @Published var currentSupplement: SupplementPlan?
    @Published var lastSunSession: SunExposureSession?
    @Published var isLoading = true

    private let persistence = PersistenceManager.shared

    // MARK: - Load Data

    func loadData() {
        performCatchUpIfNeeded()

        currentEstimate = persistence.currentEstimate
        currentSupplement = persistence.currentSupplementPlan
        lastSunSession = persistence.mostRecentSunSession

        // Calculate baseline
        if let location = persistence.userProfile.homeLocation {
            baselineLevel = BaselineEstimator.estimateBaseline(location: location)
        }

        isLoading = false
    }

    // MARK: - Catch-up Logic

    /// Performs catch-up calculations if the app hasn't been opened for a while.
    func performCatchUpIfNeeded() {
        guard let lastEstimate = persistence.currentEstimate else { return }

        let calendar = Calendar(identifier: .gregorian)
        let lastUpdate = persistence.lastDailyUpdateDate ?? lastEstimate.date
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: lastUpdate)

        guard lastDay < today else { return }

        let (newEstimate, events) = DailyUpdateService.catchUp(
            lastEstimate: lastEstimate,
            currentDate: Date(),
            supplementPlans: persistence.supplementPlans,
            sunSessions: persistence.sunSessions
        )

        if !events.isEmpty {
            persistence.currentEstimate = newEstimate
            persistence.addDailyEvents(events)
            persistence.lastDailyUpdateDate = Date()
        }
    }

    // MARK: - Formatted Values

    var estimatedLevelText: String {
        guard let estimate = currentEstimate else { return "--" }
        return String(format: "%.0f", estimate.estimatedLevel)
    }

    var estimatedLevelUnit: String { "ng/mL" }

    var sourceLabel: String {
        currentEstimate?.source.rawValue ?? "Unknown"
    }

    var confidenceLabel: String {
        currentEstimate?.confidence.rawValue ?? "Unknown"
    }

    var levelInterpretation: String {
        currentEstimate?.levelInterpretation ?? "Unknown"
    }

    var baselineLevelText: String {
        String(format: "%.0f ng/mL", baselineLevel)
    }

    var supplementText: String {
        guard let plan = currentSupplement else { return "None" }
        if plan.dailyDoseIU == 0 { return "None" }
        return "\(Int(plan.dailyDoseIU)) IU \(plan.vitaminDType.rawValue)/day"
    }

    var lastSessionSummary: String {
        guard let session = lastSunSession else { return "No sessions yet" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let duration = Int(session.durationMinutes)
        let gain = String(format: "%.1f", session.estimatedVitaminDGain)
        return "\(formatter.string(from: session.startTime)) — \(duration) min, +\(gain) ng/mL"
    }

    /// Color hint for the level indicator.
    var levelColor: Color {
        guard let estimate = currentEstimate else { return .gray }
        switch estimate.levelColorHint {
        case "red": return .warningRed
        case "orange": return .sunOrange
        case "yellow": return .sunYellow
        case "green": return .healthGreen
        case "blue": return .skyBlue
        default: return .purple
        }
    }
}
