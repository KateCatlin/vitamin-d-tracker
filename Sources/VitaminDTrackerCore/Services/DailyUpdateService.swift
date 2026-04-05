import Foundation

/// Service that manages the daily update process for vitamin D estimation.
///
/// Handles:
/// - Computing catch-up updates when the app hasn't been opened for a while
/// - Tracking what updates have been applied
/// - Applying new lab results as anchor points
public struct DailyUpdateService {

    /// Perform a catch-up calculation from the last known state to the current date.
    ///
    /// This handles the case where the app hasn't been opened for several days
    /// and needs to compute all missed daily updates.
    ///
    /// - Parameters:
    ///   - lastEstimate: The most recent estimate on record.
    ///   - currentDate: The current date (default: now).
    ///   - supplementPlans: All supplement plans.
    ///   - sunSessions: All completed sun sessions.
    /// - Returns: The new estimate and all daily events generated.
    public static func catchUp(
        lastEstimate: VitaminDStateEstimate,
        currentDate: Date = Date(),
        supplementPlans: [SupplementPlan],
        sunSessions: [SunExposureSession]
    ) -> (newEstimate: VitaminDStateEstimate, events: [DailyUpdateEvent]) {
        let (level, events) = VitaminDModel.computeCurrentLevel(
            anchorLevel: lastEstimate.estimatedLevel,
            anchorDate: lastEstimate.date,
            currentDate: currentDate,
            supplementPlans: supplementPlans,
            sunSessions: sunSessions
        )

        guard !events.isEmpty else {
            return (newEstimate: lastEstimate, events: [])
        }

        let confidence: ConfidenceLevel = lastEstimate.source == .labMeasurement ? .moderate : .low
        let newEstimate = VitaminDStateEstimate(
            estimatedLevel: level,
            source: .modelEstimate,
            confidence: confidence,
            date: currentDate,
            note: "Updated from \(events.count) day(s) of model progression"
        )

        return (newEstimate: newEstimate, events: events)
    }

    /// Apply a new lab test result as a trusted anchor point.
    ///
    /// This resets the estimate to the lab value from the test date,
    /// then replays model progression from there to now.
    ///
    /// - Parameters:
    ///   - testResult: The new lab test result.
    ///   - currentDate: The current date (default: now).
    ///   - supplementPlans: All supplement plans.
    ///   - sunSessions: All completed sun sessions.
    /// - Returns: The new estimate based on the lab anchor.
    public static func applyLabResult(
        testResult: VitaminDTestResult,
        currentDate: Date = Date(),
        supplementPlans: [SupplementPlan],
        sunSessions: [SunExposureSession]
    ) -> (newEstimate: VitaminDStateEstimate, events: [DailyUpdateEvent]) {
        let labLevelNgML = testResult.valueInNgPerML

        // If the test date is today, just return the lab value
        let calendar = Calendar(identifier: .gregorian)
        let testDay = calendar.startOfDay(for: testResult.testDate)
        let today = calendar.startOfDay(for: currentDate)

        if testDay >= today {
            let estimate = VitaminDStateEstimate(
                estimatedLevel: labLevelNgML,
                source: .labMeasurement,
                confidence: .high,
                date: testResult.testDate,
                note: "Direct lab measurement"
            )
            return (newEstimate: estimate, events: [])
        }

        // Replay from lab date to now
        let (level, events) = VitaminDModel.computeCurrentLevel(
            anchorLevel: labLevelNgML,
            anchorDate: testResult.testDate,
            currentDate: currentDate,
            supplementPlans: supplementPlans,
            sunSessions: sunSessions
        )

        let confidence: ConfidenceLevel = events.count <= 14 ? .high : .moderate
        let newEstimate = VitaminDStateEstimate(
            estimatedLevel: level,
            source: events.isEmpty ? .labMeasurement : .modelEstimate,
            confidence: confidence,
            date: currentDate,
            note: events.isEmpty
                ? "Direct lab measurement"
                : "Lab measurement + \(events.count) day(s) of model progression"
        )

        return (newEstimate: newEstimate, events: events)
    }

    /// Create an initial estimate from onboarding data (no lab test available).
    ///
    /// - Parameters:
    ///   - location: User's home location.
    ///   - date: The date for the estimate.
    /// - Returns: A baseline estimate.
    public static func createBaselineEstimate(
        location: HomeLocation,
        date: Date = Date()
    ) -> VitaminDStateEstimate {
        let baseline = BaselineEstimator.estimateBaseline(location: location, date: date)
        return VitaminDStateEstimate(
            estimatedLevel: baseline,
            source: .geographicEstimate,
            confidence: .low,
            date: date,
            note: "Estimated from location (\(location.cityName)) and current season"
        )
    }
}
