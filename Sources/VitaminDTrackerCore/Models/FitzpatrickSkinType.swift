import Foundation

/// Fitzpatrick skin phototype classification (I–VI).
///
/// Used to adjust:
/// - Sunburn risk thresholds (darker skin → higher threshold)
/// - Vitamin D production rate (darker skin → slower production due to melanin absorption)
///
/// See MODELING.md for scientific references.
public enum FitzpatrickSkinType: Int, Codable, CaseIterable, Sendable {
    case typeI = 1
    case typeII = 2
    case typeIII = 3
    case typeIV = 4
    case typeV = 5
    case typeVI = 6

    /// Human-readable name.
    public var displayName: String {
        switch self {
        case .typeI:   return "Type I — Very Fair"
        case .typeII:  return "Type II — Fair"
        case .typeIII: return "Type III — Medium"
        case .typeIV:  return "Type IV — Olive"
        case .typeV:   return "Type V — Brown"
        case .typeVI:  return "Type VI — Dark"
        }
    }

    /// Short description of the skin type's sun response.
    public var sunResponse: String {
        switch self {
        case .typeI:   return "Always burns, never tans"
        case .typeII:  return "Burns easily, tans minimally"
        case .typeIII: return "Burns moderately, tans gradually"
        case .typeIV:  return "Burns minimally, tans well"
        case .typeV:   return "Rarely burns, tans darkly"
        case .typeVI:  return "Never burns, deeply pigmented"
        }
    }

    /// Minimal Erythemal Dose in Standard Erythemal Doses (SED).
    ///
    /// The UV dose required to produce perceptible redness in unprotected skin.
    /// Values from dermatological reference data.
    ///
    /// Sources:
    /// - Fitzpatrick TB. The validity and practicality of sun-reactive skin types I through VI.
    ///   Arch Dermatol. 1988;124(6):869-871.
    /// - WHO Global Solar UV Index: A Practical Guide. 2002.
    public var sunburnThresholdSED: Double {
        switch self {
        case .typeI:   return 2.0
        case .typeII:  return 2.5
        case .typeIII: return 4.0
        case .typeIV:  return 5.0
        case .typeV:   return 8.0
        case .typeVI:  return 10.0
        }
    }

    /// Vitamin D production multiplier relative to Type II (fair skin, reference = 1.0).
    ///
    /// Melanin absorbs UV-B and reduces previtamin D3 synthesis.
    /// Darker skin requires longer UV exposure to produce the same amount of vitamin D.
    ///
    /// Approximate multipliers based on:
    /// - Clemens TL, et al. Increased skin pigment reduces the capacity of skin to synthesise
    ///   vitamin D3. Lancet. 1982;1(8263):74-76.
    /// - Holick MF. Vitamin D deficiency. N Engl J Med. 2007;357(3):266-281.
    public var vitaminDProductionMultiplier: Double {
        switch self {
        case .typeI:   return 1.2   // Very fair — slightly faster than reference
        case .typeII:  return 1.0   // Fair — reference standard
        case .typeIII: return 0.75  // Medium — moderately reduced
        case .typeIV:  return 0.55  // Olive — substantially reduced
        case .typeV:   return 0.35  // Brown — significantly reduced
        case .typeVI:  return 0.20  // Dark — greatly reduced
        }
    }
}
