import Foundation
import VitaminDTrackerCore

#if canImport(Combine)
import Combine
#endif

/// Manages local persistence using JSON files + UserDefaults.
/// Uses the simplest robust approach for on-device storage.
///
/// In a production app, this could be replaced with SwiftData or Core Data.
/// For this initial version, JSON-file persistence is simple and sufficient.
///
/// SECURITY: Sensitive data (skin type via `userProfile`, blood test
/// results) is stored in the **Keychain** with
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Everything else
/// (sun-session timestamps, supplement plans, daily-event log) stays in
/// `UserDefaults` — that data isn't health-identifying on its own.
///
/// A one-time migration moves any pre-existing `UserDefaults` values
/// into the Keychain on first read (see ``migrateSensitiveKeyIfNeeded``).
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
        static let baselineLevel = "baselineLevel"
    }

    // MARK: - Storage

    private let defaults: UserDefaults
    private let keychain: KeychainStorage
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        defaults: UserDefaults = .standard,
        keychain: KeychainStorage = .shared
    ) {
        self.defaults = defaults
        self.keychain = keychain
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - User Profile

    /// Stored in **Keychain** because `UserProfile.skinType` is a
    /// Fitzpatrick phototype — a proxy for race/ethnicity and treated
    /// as special-category data under GDPR Art. 9.
    public var userProfile: UserProfile {
        get {
            migrateSensitiveKeyIfNeeded(Keys.userProfile)
            return keychain.load(forKey: Keys.userProfile) ?? UserProfile()
        }
        set { keychain.save(newValue, forKey: Keys.userProfile) }
    }

    // MARK: - Test Results

    /// Stored in **Keychain** — vitamin D blood test results are
    /// clinical lab data.
    public var testResults: [VitaminDTestResult] {
        get {
            migrateSensitiveKeyIfNeeded(Keys.testResults)
            return keychain.load(forKey: Keys.testResults) ?? []
        }
        set { keychain.save(newValue, forKey: Keys.testResults) }
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

    // MARK: - Baseline Level

    /// Stored baseline vitamin D level from onboarding. Not recalculated when city changes.
    public var baselineLevel: Double? {
        get { defaults.object(forKey: Keys.baselineLevel) as? Double }
        set { defaults.set(newValue, forKey: Keys.baselineLevel) }
    }

    // MARK: - Reset

    public func resetAll() {
        let allKeys = [
            Keys.userProfile, Keys.testResults, Keys.supplementPlans,
            Keys.sunSessions, Keys.currentEstimate, Keys.dailyEvents,
            Keys.lastDailyUpdateDate, Keys.baselineLevel
        ]
        for key in allKeys {
            defaults.removeObject(forKey: key)
        }
        // Sensitive keys also live in Keychain — wipe both stores.
        keychain.delete(key: Keys.userProfile)
        keychain.delete(key: Keys.testResults)
    }

    // MARK: - Private Helpers

    /// One-time migration: if a sensitive key still has data in
    /// `UserDefaults` (from a build before Keychain was adopted) and
    /// nothing exists in Keychain yet, copy it across, verify the
    /// write, then delete the plaintext copy.
    ///
    /// Idempotent — once the Keychain has data for `key`, this is a
    /// cheap no-op (`contains` is one `SecItemCopyMatching` call).
    private func migrateSensitiveKeyIfNeeded(_ key: String) {
        guard !keychain.contains(key: key),
              let legacy = defaults.data(forKey: key)
        else { return }

        // The legacy bytes are already JSON produced by this file's
        // own encoder (.iso8601 dates), so write them straight through.
        // Going via `keychain.save(_:forKey:)` would JSON-encode the
        // `Data` itself (base64-wrapping it) and break decoding.
        keychain.saveRaw(legacy, forKey: key)

        // Only delete the plaintext copy after we've confirmed the
        // Keychain write took. If it didn't (e.g. device locked), we
        // leave the legacy data in place and retry next launch.
        if keychain.contains(key: key) {
            defaults.removeObject(forKey: key)
        }
    }

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
