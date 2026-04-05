import Foundation

#if canImport(Combine)
import Combine
#endif

/// Manages local persistence using JSON files + UserDefaults.
/// Uses the simplest robust approach for on-device storage.
///
/// In a production app, this could be replaced with SwiftData or Core Data.
/// For this initial version, JSON-file persistence is simple and sufficient.
public final class PersistenceManager {

    // MARK: - Singleton

    public static let shared = PersistenceManager()

    // MARK: - Keys

    private enum Keys {
        static let userProfile = "userProfile"
        static let testResults = "testResults"
        static let supplementPlans = "supplementPlans"
        static let sunSessions = "sunSessions"
        static let currentEstimate = "currentEstimate"
        static let dailyEvents = "dailyEvents"
        static let lastDailyUpdateDate = "lastDailyUpdateDate"
    }

    // MARK: - Storage

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - User Profile

    public var userProfile: UserProfile {
        get { load(key: Keys.userProfile) ?? UserProfile() }
        set { save(newValue, key: Keys.userProfile) }
    }

    // MARK: - Test Results

    public var testResults: [VitaminDTestResult] {
        get { load(key: Keys.testResults) ?? [] }
        set { save(newValue, key: Keys.testResults) }
    }

    public func addTestResult(_ result: VitaminDTestResult) {
        var results = testResults
        results.append(result)
        testResults = results
    }

    public var mostRecentTestResult: VitaminDTestResult? {
        testResults.sorted { $0.testDate > $1.testDate }.first
    }

    // MARK: - Supplement Plans

    public var supplementPlans: [SupplementPlan] {
        get { load(key: Keys.supplementPlans) ?? [] }
        set { save(newValue, key: Keys.supplementPlans) }
    }

    public func addSupplementPlan(_ plan: SupplementPlan) {
        var plans = supplementPlans
        plans.append(plan)
        supplementPlans = plans
    }

    public var currentSupplementPlan: SupplementPlan? {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        return supplementPlans
            .filter { calendar.startOfDay(for: $0.effectiveDate) <= today }
            .sorted { $0.effectiveDate < $1.effectiveDate }
            .last
    }

    // MARK: - Sun Sessions

    public var sunSessions: [SunExposureSession] {
        get { load(key: Keys.sunSessions) ?? [] }
        set { save(newValue, key: Keys.sunSessions) }
    }

    public func addSunSession(_ session: SunExposureSession) {
        var sessions = sunSessions
        sessions.append(session)
        sunSessions = sessions
    }

    public func updateSunSession(_ session: SunExposureSession) {
        var sessions = sunSessions
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
        sunSessions = sessions
    }

    public var mostRecentSunSession: SunExposureSession? {
        sunSessions
            .filter { $0.isCompleted }
            .sorted { $0.startTime > $1.startTime }
            .first
    }

    // MARK: - Current Estimate

    public var currentEstimate: VitaminDStateEstimate? {
        get { load(key: Keys.currentEstimate) }
        set { save(newValue, key: Keys.currentEstimate) }
    }

    // MARK: - Daily Events

    public var dailyEvents: [DailyUpdateEvent] {
        get { load(key: Keys.dailyEvents) ?? [] }
        set { save(newValue, key: Keys.dailyEvents) }
    }

    public func addDailyEvents(_ events: [DailyUpdateEvent]) {
        var existing = dailyEvents
        existing.append(contentsOf: events)
        dailyEvents = existing
    }

    // MARK: - Last Update Tracking

    public var lastDailyUpdateDate: Date? {
        get { defaults.object(forKey: Keys.lastDailyUpdateDate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastDailyUpdateDate) }
    }

    // MARK: - Reset

    public func resetAll() {
        let allKeys = [
            Keys.userProfile, Keys.testResults, Keys.supplementPlans,
            Keys.sunSessions, Keys.currentEstimate, Keys.dailyEvents,
            Keys.lastDailyUpdateDate
        ]
        for key in allKeys {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Private Helpers

    private func save<T: Codable>(_ value: T, key: String) {
        if let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private func load<T: Codable>(key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
}
