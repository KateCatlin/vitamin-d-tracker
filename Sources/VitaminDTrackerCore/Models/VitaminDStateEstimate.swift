import Foundation

/// The source of a vitamin D level value.
public enum EstimateSource: String, Codable, Sendable {
    /// Value came from a lab blood test.
    case labMeasurement = "Lab Measurement"
    /// Value was estimated using the model from geography/season.
    case geographicEstimate = "Geographic Estimate"
    /// Value was computed from model progression (decay + supplements + sun).
    case modelEstimate = "Model Estimate"
}

/// Confidence level of an estimate.
public enum ConfidenceLevel: String, Codable, Sendable {
    case high = "High"
    case moderate = "Moderate"
    case low = "Low"

    public var description: String {
        switch self {
        case .high:
            return "Based on a recent lab measurement"
        case .moderate:
            return "Modeled from lab result with supplement and sun data"
        case .low:
            return "Estimated from geography and season — no lab data"
        }
    }
}

/// A point-in-time estimate of the user's vitamin D level.
public struct VitaminDStateEstimate: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    /// The estimated 25(OH)D level in ng/mL.
    public var estimatedLevel: Double
    /// How this value was determined.
    public var source: EstimateSource
    /// Confidence in this estimate.
    public var confidence: ConfidenceLevel
    /// When this estimate was computed.
    public var date: Date
    /// Optional note about the estimate.
    public var note: String?

    public init(
        id: UUID = UUID(),
        estimatedLevel: Double,
        source: EstimateSource,
        confidence: ConfidenceLevel,
        date: Date = Date(),
        note: String? = nil
    ) {
        self.id = id
        self.estimatedLevel = estimatedLevel
        self.source = source
        self.confidence = confidence
        self.date = date
        self.note = note
    }

    /// Interpretation of the vitamin D level based on common clinical ranges.
    /// These are informational only — not medical advice.
    public var levelInterpretation: String {
        switch estimatedLevel {
        case ..<12:
            return "Very Low"
        case 12..<20:
            return "Low"
        case 20..<30:
            return "Adequate"
        case 30..<50:
            return "Sufficient"
        case 50..<100:
            return "High"
        default:
            return "Very High"
        }
    }

    /// Color hint for UI display based on level.
    /// Returns a string identifier for the UI layer to interpret.
    public var levelColorHint: String {
        switch estimatedLevel {
        case ..<12:
            return "red"
        case 12..<20:
            return "orange"
        case 20..<30:
            return "yellow"
        case 30..<50:
            return "green"
        case 50..<100:
            return "blue"
        default:
            return "purple"
        }
    }
}
