import Foundation

/// Lightweight privacy-conscious analytics service.
///
/// Uses Apple's built-in App Analytics via App Store Connect as the primary
/// analytics source. This in-app service provides minimal local event tracking
/// that could be extended with a privacy-conscious analytics SDK if desired.
///
/// For download/install counts, use App Store Connect analytics dashboard.
///
/// Currently tracked events:
/// - Onboarding completion
/// - Sun session starts and completions
/// - App open events (for DAU/MAU approximation)
///
/// No personal health data is collected remotely.
public final class AnalyticsService {

    public static let shared = AnalyticsService()

    // MARK: - Event Types

    public enum Event: String {
        case appOpen = "app_open"
        case onboardingCompleted = "onboarding_completed"
        case sunSessionStarted = "sun_session_started"
        case sunSessionCompleted = "sun_session_completed"
        case labResultEntered = "lab_result_entered"
        case supplementUpdated = "supplement_updated"
    }

    // MARK: - Local Event Counts

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Log an analytics event.
    /// Currently stored locally. Can be extended with a remote analytics provider.
    public func log(_ event: Event) {
        let key = "analytics_\(event.rawValue)_count"
        let current = defaults.integer(forKey: key)
        defaults.set(current + 1, forKey: key)

        // Track last event date for DAU approximation
        defaults.set(Date(), forKey: "analytics_\(event.rawValue)_last")

        #if DEBUG
        print("[Analytics] \(event.rawValue)")
        #endif
    }

    /// Get count for an event type (local only).
    public func count(for event: Event) -> Int {
        defaults.integer(forKey: "analytics_\(event.rawValue)_count")
    }

    /// Get last occurrence date for an event.
    public func lastOccurrence(of event: Event) -> Date? {
        defaults.object(forKey: "analytics_\(event.rawValue)_last") as? Date
    }
}
