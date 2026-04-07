import Foundation
import VitaminDTrackerCore
import SwiftUI

#if canImport(Combine)
import Combine
#endif

/// View model for sun exposure tracking sessions.
@MainActor
class SunSessionViewModel: ObservableObject {

    // MARK: - Session State

    @Published var isSessionActive = false
    @Published var currentSession: SunExposureSession?
    @Published var elapsedSeconds: TimeInterval = 0
    @Published var estimatedGain: Double = 0.0
    @Published var estimatedUVIndex: Double = 0.0
    @Published var exposurePercentage: Double = 0.0
    @Published var isOverexposed = false
    @Published var hasShownOverexposureWarning = false
    @Published var showOverexposureAlert = false

    // MARK: - Session Parameters

    @Published var skinExposureFraction: Double = 0.25
    @Published var cloudCoverFraction: Double = 0.0
    @Published var sessionLocation: HomeLocation?

    // MARK: - UV Availability

    /// The current estimated UV index for the user's location, updated on view appear.
    @Published var currentLocationUVIndex: Double = 0.0

    /// Whether the current UV index is high enough for meaningful vitamin D production.
    var isUVSufficientForSession: Bool {
        currentLocationUVIndex >= ModelingAssumptions.minimumUVIndexForVitaminD
    }

    /// Formatted string for the current UV index.
    var currentUVIndexFormatted: String {
        String(format: "%.1f", currentLocationUVIndex)
    }

    /// Refreshes the estimated UV index for the user's current location.
    func refreshUVEstimate() {
        let location = sessionLocation ?? persistence.userProfile.homeLocation ?? HomeLocation(
            cityName: "Unknown",
            latitude: 37.7749,
            longitude: -122.4194
        )
        currentLocationUVIndex = BaselineEstimator.estimateUVIndex(location: location)
    }

    // MARK: - Timer

    private var timer: Timer?
    private let persistence = PersistenceManager.shared

    // MARK: - Computed

    var elapsedMinutes: Double { elapsedSeconds / 60.0 }

    /// The user's Fitzpatrick skin type from their profile.
    var userSkinType: FitzpatrickSkinType? {
        persistence.userProfile.skinType
    }

    var elapsedTimeFormatted: String {
        let hours = Int(elapsedSeconds) / 3600
        let minutes = (Int(elapsedSeconds) % 3600) / 60
        let secs = Int(elapsedSeconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    var gainFormatted: String {
        String(format: "+%.2f ng/mL", estimatedGain)
    }

    /// Estimated gain converted to IU (the unit people know from supplements).
    var estimatedGainIU: Double {
        estimatedGain * ModelingAssumptions.iuPerNgMLAcuteDose
    }

    var gainIUFormatted: String {
        let iu = estimatedGainIU
        if iu >= 1000 {
            return String(format: "+%.0f IU", iu)
        }
        return String(format: "+%.0f IU", iu)
    }

    var uvRiskLevel: UVRiskLevel {
        UVRiskCalculator.riskLevel(uvIndex: estimatedUVIndex)
    }

    var maxSafeMinutes: Double? {
        UVRiskCalculator.maxSafeExposureMinutes(
            uvIndex: estimatedUVIndex,
            cloudCoverFraction: cloudCoverFraction,
            skinType: userSkinType
        )
    }

    var maxSafeTimeFormatted: String {
        guard let minutes = maxSafeMinutes else { return "N/A" }
        let mins = Int(minutes)
        if mins >= 60 {
            return "\(mins / 60)h \(mins % 60)m"
        }
        return "\(mins) min"
    }

    var skinExposureLabel: String {
        switch skinExposureFraction {
        case 0..<0.15: return "Minimal (face only)"
        case 0.15..<0.30: return "Light (face + hands)"
        case 0.30..<0.50: return "Moderate (short sleeves)"
        case 0.50..<0.70: return "Good (shorts + t-shirt)"
        case 0.70..<0.90: return "High (swimwear)"
        default: return "Maximum"
        }
    }

    var cloudCoverLabel: String {
        switch cloudCoverFraction {
        case 0..<0.1: return "Clear sky ☀️"
        case 0.1..<0.3: return "Mostly sunny 🌤️"
        case 0.3..<0.6: return "Partly cloudy ⛅"
        case 0.6..<0.9: return "Mostly cloudy 🌥️"
        default: return "Overcast ☁️"
        }
    }

    // MARK: - Actions

    func startSession() {
        let location = sessionLocation ?? persistence.userProfile.homeLocation ?? HomeLocation(
            cityName: "Unknown",
            latitude: 37.7749,
            longitude: -122.4194
        )

        estimatedUVIndex = BaselineEstimator.estimateUVIndex(location: location)

        let session = SunExposureSession(
            location: location,
            startTime: Date(),
            skinExposureFraction: skinExposureFraction,
            cloudCoverFraction: cloudCoverFraction,
            estimatedUVIndex: estimatedUVIndex
        )

        currentSession = session
        persistence.addSunSession(session)

        isSessionActive = true
        elapsedSeconds = 0
        estimatedGain = 0.0
        hasShownOverexposureWarning = false

        AnalyticsService.shared.log(.sunSessionStarted)
        startTimer()
    }

    func stopSession() {
        timer?.invalidate()
        timer = nil
        isSessionActive = false

        guard var session = currentSession else { return }
        session.endTime = Date()
        session.estimatedVitaminDGain = estimatedGain
        session.isCompleted = true
        session.skinExposureFraction = skinExposureFraction
        session.cloudCoverFraction = cloudCoverFraction

        // Update persistence
        persistence.updateSunSession(session)

        // Update the current estimate
        if var estimate = persistence.currentEstimate {
            estimate = VitaminDStateEstimate(
                estimatedLevel: estimate.estimatedLevel + estimatedGain,
                source: .modelEstimate,
                confidence: estimate.confidence,
                date: Date(),
                note: "Updated after sun session (+\(String(format: "%.1f", estimatedGain)) ng/mL)"
            )
            persistence.currentEstimate = estimate
        }

        currentSession = session
        AnalyticsService.shared.log(.sunSessionCompleted)
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard isSessionActive else { return }

        elapsedSeconds += 1

        // Update vitamin D gain estimate
        estimatedGain = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: estimatedUVIndex,
            skinExposureFraction: skinExposureFraction,
            cloudCoverFraction: cloudCoverFraction,
            durationMinutes: elapsedMinutes,
            skinType: userSkinType
        )

        // Update exposure percentage
        exposurePercentage = UVRiskCalculator.exposurePercentage(
            uvIndex: estimatedUVIndex,
            durationMinutes: elapsedMinutes,
            cloudCoverFraction: cloudCoverFraction,
            skinType: userSkinType
        )

        // Check overexposure
        let wasOverexposed = isOverexposed
        isOverexposed = UVRiskCalculator.isOverexposed(
            uvIndex: estimatedUVIndex,
            durationMinutes: elapsedMinutes,
            cloudCoverFraction: cloudCoverFraction,
            skinType: userSkinType
        )

        // Trigger alert on first overexposure detection
        if isOverexposed && !wasOverexposed && !hasShownOverexposureWarning {
            hasShownOverexposureWarning = true
            showOverexposureAlert = true
        }
    }

    deinit {
        timer?.invalidate()
    }
}
