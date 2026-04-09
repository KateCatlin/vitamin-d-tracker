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

    /// Where ``currentLocationUVIndex`` came from. WeatherKit when the
    /// network and entitlement cooperate; clear-sky model otherwise.
    /// Surfaced so the UI can label the value as "live" vs "estimate".
    @Published var uvIndexSource: UVIndexSource = .clearSkyModel

    /// Whether the current UV index is high enough for meaningful vitamin D production.
    var isUVSufficientForSession: Bool {
        currentLocationUVIndex >= ModelingAssumptions.minimumUVIndexForVitaminD
    }

    /// Formatted string for the current UV index.
    var currentUVIndexFormatted: String {
        String(format: "%.1f", currentLocationUVIndex)
    }

    /// Refreshes the UV index for the user's current location.
    ///
    /// The clear-sky value is published synchronously so the screen
    /// never sits at 0 while waiting for the network. Then WeatherKit
    /// is consulted; if it answers, the published value is overwritten
    /// with the live reading. If it doesn't (offline, no entitlement,
    /// service hiccup), the clear-sky value just stays — no error UI.
    func refreshUVEstimate() {
        let location = resolveSessionLocation()

        // Synchronous floor: the (now-correct) astronomical model.
        currentLocationUVIndex = BaselineEstimator.estimateUVIndex(location: location)
        uvIndexSource = .clearSkyModel

        // Best-effort upgrade. Provider returns the same clear-sky
        // number if WeatherKit fails, so the assignment is harmless
        // either way; we just keep the source label honest.
        Task { [weak self] in
            let reading = await UVIndexProvider.shared.currentUVIndex(for: location)
            guard let self else { return }
            self.currentLocationUVIndex = reading.value
            self.uvIndexSource = reading.source
        }
    }

    /// Resolves the location to use for UV lookups: the user-picked
    /// session override, then their home city, then SF as a placeholder.
    private func resolveSessionLocation() -> HomeLocation {
        sessionLocation ?? persistence.userProfile.homeLocation ?? HomeLocation(
            cityName: "Unknown",
            latitude: 37.7749,
            longitude: -122.4194
        )
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
        let location = resolveSessionLocation()

        // Reuse the already-resolved value from `refreshUVEstimate()`.
        // The Start button isn't reachable without `.onAppear` having
        // run, so this is the WeatherKit number when WeatherKit
        // worked, and the clear-sky number when it didn't. Falling
        // through to the estimator handles the edge where a session
        // is started programmatically without the screen mounted.
        estimatedUVIndex = currentLocationUVIndex > 0
            ? currentLocationUVIndex
            : BaselineEstimator.estimateUVIndex(location: location)

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
        finalizeSession(endTime: Date())
    }

    /// Persists the current slider values onto the in-progress session
    /// so that if the app is killed mid-session, restoration picks up
    /// the user's most recent skin/cloud adjustments rather than the
    /// values from session start.
    func persistInProgressParameters() {
        guard isSessionActive, var session = currentSession else { return }
        session.skinExposureFraction = skinExposureFraction
        session.cloudCoverFraction = cloudCoverFraction
        currentSession = session
        persistence.updateSunSession(session)
    }

    // MARK: - Restoration

    /// Sessions older than this are auto-finalized at this cap rather
    /// than resumed. The user gets vitamin D credit for the capped
    /// duration. Per product decision: 1 hour.
    private static let maxRecoverableSessionSeconds: TimeInterval = 60 * 60

    /// Looks for an orphaned in-progress session in persistence (e.g.
    /// the app was killed while a session was running) and either
    /// resumes it or — if it's been too long — finalizes it at the
    /// 1-hour cap with full vitamin D credit for that hour.
    ///
    /// Call from `.onAppear`. No-op if a session is already active or
    /// no orphan exists.
    func restoreActiveSessionIfNeeded() {
        guard !isSessionActive,
              let orphan = persistence.sunSessions
                .last(where: { !$0.isCompleted && $0.endTime == nil })
        else { return }

        // Hydrate VM state from the persisted session so both the
        // resume path and the stale-finalize path compute against the
        // user's actual parameters.
        currentSession = orphan
        skinExposureFraction = orphan.skinExposureFraction
        cloudCoverFraction = orphan.cloudCoverFraction
        estimatedUVIndex = orphan.estimatedUVIndex

        if orphan.durationSeconds > Self.maxRecoverableSessionSeconds {
            // Stale. Assume they stopped at the 1-hour mark and credit
            // them as if they did.
            let cappedEnd = orphan.startTime
                .addingTimeInterval(Self.maxRecoverableSessionSeconds)
            finalizeSession(endTime: cappedEnd)
            return
        }

        // Resume the live session.
        isSessionActive = true

        // Suppress the alert during the restoring sync — if the user
        // was already past safe time when they backgrounded, popping
        // it again on return is just noise. Re-arm afterwards only if
        // they're still under the threshold.
        hasShownOverexposureWarning = true
        syncFromClock()
        if !isOverexposed {
            hasShownOverexposureWarning = false
        }

        startTimer()
    }

    // MARK: - Finalization

    /// Shared completion path used by both the user-initiated stop and
    /// the stale-session auto-cap. Computes the gain for the actual
    /// `startTime → endTime` window so a capped session is credited
    /// for exactly that duration.
    private func finalizeSession(endTime: Date) {
        timer?.invalidate()
        timer = nil
        isSessionActive = false

        guard var session = currentSession else { return }

        let finalDurationSeconds = endTime.timeIntervalSince(session.startTime)
        let finalGain = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: estimatedUVIndex,
            skinExposureFraction: skinExposureFraction,
            cloudCoverFraction: cloudCoverFraction,
            durationMinutes: finalDurationSeconds / 60.0,
            skinType: userSkinType
        )

        session.endTime = endTime
        session.estimatedVitaminDGain = finalGain
        session.isCompleted = true
        session.skinExposureFraction = skinExposureFraction
        session.cloudCoverFraction = cloudCoverFraction

        // Update persistence
        persistence.updateSunSession(session)

        // Update the current estimate
        if var estimate = persistence.currentEstimate {
            estimate = VitaminDStateEstimate(
                estimatedLevel: estimate.estimatedLevel + finalGain,
                source: .modelEstimate,
                confidence: estimate.confidence,
                date: Date(),
                note: "Updated after sun session (+\(String(format: "%.1f", finalGain)) ng/mL)"
            )
            persistence.currentEstimate = estimate
        }

        // Sync published values so SessionCompleteContent reflects the
        // (possibly capped) finalized numbers.
        estimatedGain = finalGain
        elapsedSeconds = finalDurationSeconds
        currentSession = session
        AnalyticsService.shared.log(.sunSessionCompleted)
    }

    // MARK: - Timer

    private func startTimer() {
        // The timer is purely a UI-refresh trigger now — `syncFromClock`
        // recomputes elapsed from the wall clock every fire, so missed
        // ticks while suspended don't matter.
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncFromClock()
            }
        }
        // `.common` keeps the timer firing while the user drags the
        // sliders or scrolls the ScrollView.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Recomputes all session-derived published state from the wall
    /// clock. Because elapsed time is read from
    /// `SunExposureSession.durationSeconds` (which diffs `Date()`
    /// against `startTime`) rather than incremented, this is correct
    /// after any gap — backgrounding, suspension, or app kill.
    ///
    /// Called every second by the timer and immediately by the view
    /// on `scenePhase → .active`.
    func syncFromClock() {
        guard isSessionActive, let session = currentSession else { return }

        elapsedSeconds = session.durationSeconds

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
