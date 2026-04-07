import Foundation

/// Type of vitamin D supplement.
public enum VitaminDType: String, Codable, CaseIterable, Sendable {
    case d2 = "D2"
    case d3 = "D3"

    public var displayName: String {
        switch self {
        case .d2: return "Vitamin D2 (Ergocalciferol)"
        case .d3: return "Vitamin D3 (Cholecalciferol)"
        }
    }

    /// Relative effectiveness multiplier compared to D3.
    /// D3 is considered the reference (1.0).
    /// D2 is estimated at ~30-50% less effective for raising 25(OH)D levels.
    /// We use 0.5 as a conservative estimate based on systematic reviews.
    /// See MODELING.md for sources.
    public var effectivenessMultiplier: Double {
        switch self {
        case .d2: return 0.5
        case .d3: return 1.0
        }
    }
}

/// Records a user's daily vitamin D supplement plan.
/// Each change creates a new record; changes are forward-only.
public struct SupplementPlan: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    /// Daily supplement amount in IU (International Units).
    public var dailyDoseIU: Double
    /// Type of vitamin D supplement.
    public var vitaminDType: VitaminDType
    /// Date this plan became effective.
    public var effectiveDate: Date

    public init(
        id: UUID = UUID(),
        dailyDoseIU: Double,
        vitaminDType: VitaminDType,
        effectiveDate: Date = Date()
    ) {
        self.id = id
        self.dailyDoseIU = dailyDoseIU
        self.vitaminDType = vitaminDType
        self.effectiveDate = effectiveDate
    }

    /// The effective daily dose accounting for D2/D3 difference (in IU-equivalent).
    public var effectiveDailyDoseIU: Double {
        dailyDoseIU * vitaminDType.effectivenessMultiplier
    }
}
