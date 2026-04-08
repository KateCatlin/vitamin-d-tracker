import Foundation

/// Represents a daily update event that is recorded when the model
/// recalculates the user's estimated vitamin D level.
public struct DailyUpdateEvent: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    /// The date this update covers.
    public var date: Date
    /// The estimated level before this update.
    public var previousLevel: Double
    /// The amount lost to decay.
    public var decayAmount: Double
    /// The amount gained from supplementation.
    public var supplementGain: Double
    /// The amount gained from sun exposure sessions on this day.
    public var sunExposureGain: Double
    /// The amount gained from background input (diet + incidental sun).
    /// Recorded so the daily ledger sums to `newLevel` exactly.
    /// Older persisted events from before this term existed decode to 0.
    public var backgroundGain: Double
    /// The resulting estimated level after this update.
    public var newLevel: Double
    /// The supplement plan active on this date.
    public var activeDoseIU: Double
    /// The vitamin D type of the active supplement.
    public var activeVitaminDType: VitaminDType

    public init(
        id: UUID = UUID(),
        date: Date,
        previousLevel: Double,
        decayAmount: Double,
        supplementGain: Double,
        sunExposureGain: Double,
        backgroundGain: Double = 0.0,
        newLevel: Double,
        activeDoseIU: Double,
        activeVitaminDType: VitaminDType
    ) {
        self.id = id
        self.date = date
        self.previousLevel = previousLevel
        self.decayAmount = decayAmount
        self.supplementGain = supplementGain
        self.sunExposureGain = sunExposureGain
        self.backgroundGain = backgroundGain
        self.newLevel = newLevel
        self.activeDoseIU = activeDoseIU
        self.activeVitaminDType = activeVitaminDType
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        previousLevel = try c.decode(Double.self, forKey: .previousLevel)
        decayAmount = try c.decode(Double.self, forKey: .decayAmount)
        supplementGain = try c.decode(Double.self, forKey: .supplementGain)
        sunExposureGain = try c.decode(Double.self, forKey: .sunExposureGain)
        // Older builds did not write this key.
        backgroundGain = try c.decodeIfPresent(Double.self, forKey: .backgroundGain) ?? 0.0
        newLevel = try c.decode(Double.self, forKey: .newLevel)
        activeDoseIU = try c.decode(Double.self, forKey: .activeDoseIU)
        activeVitaminDType = try c.decode(VitaminDType.self, forKey: .activeVitaminDType)
    }
}
