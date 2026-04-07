import Foundation

/// Represents a tracked sun exposure session.
public struct SunExposureSession: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    /// Location during the session.
    public var location: HomeLocation
    /// Start time of the session.
    public var startTime: Date
    /// End time (nil if session is still active).
    public var endTime: Date?
    /// Fraction of skin exposed (0.0 to 1.0).
    /// e.g., 0.25 for face + hands, 0.5 for shorts and t-shirt, 0.8 for swimwear.
    public var skinExposureFraction: Double
    /// Cloud cover fraction (0.0 = clear sky, 1.0 = fully overcast).
    public var cloudCoverFraction: Double
    /// Estimated UV index during the session.
    public var estimatedUVIndex: Double
    /// Estimated vitamin D contribution from this session in ng/mL.
    public var estimatedVitaminDGain: Double
    /// Whether the session was completed (vs abandoned/cancelled).
    public var isCompleted: Bool

    public init(
        id: UUID = UUID(),
        location: HomeLocation,
        startTime: Date = Date(),
        endTime: Date? = nil,
        skinExposureFraction: Double = 0.25,
        cloudCoverFraction: Double = 0.0,
        estimatedUVIndex: Double = 0.0,
        estimatedVitaminDGain: Double = 0.0,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.location = location
        self.startTime = startTime
        self.endTime = endTime
        self.skinExposureFraction = skinExposureFraction
        self.cloudCoverFraction = cloudCoverFraction
        self.estimatedUVIndex = estimatedUVIndex
        self.estimatedVitaminDGain = estimatedVitaminDGain
        self.isCompleted = isCompleted
    }

    /// Duration of the session in seconds.
    public var durationSeconds: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    /// Duration of the session in minutes.
    public var durationMinutes: Double {
        durationSeconds / 60.0
    }
}
