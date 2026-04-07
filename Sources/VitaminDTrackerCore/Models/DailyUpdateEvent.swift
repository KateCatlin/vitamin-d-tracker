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
        self.newLevel = newLevel
        self.activeDoseIU = activeDoseIU
        self.activeVitaminDType = activeVitaminDType
    }
}
