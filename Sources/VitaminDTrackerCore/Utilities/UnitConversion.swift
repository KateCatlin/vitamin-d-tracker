import Foundation

/// Converts between vitamin D measurement units.
public struct UnitConversion {

    /// Convert ng/mL to nmol/L.
    /// Factor: 1 ng/mL = 2.496 nmol/L
    public static func ngMLToNmolL(_ ngML: Double) -> Double {
        ngML * 2.496
    }

    /// Convert nmol/L to ng/mL.
    public static func nmolLToNgML(_ nmolL: Double) -> Double {
        nmolL / 2.496
    }

    /// Normalize any test result to ng/mL.
    public static func toNgML(value: Double, unit: VitaminDUnit) -> Double {
        switch unit {
        case .ngPerML:
            return value
        case .nmolPerL:
            return nmolLToNgML(value)
        }
    }

    /// Normalize any test result to nmol/L.
    public static func toNmolL(value: Double, unit: VitaminDUnit) -> Double {
        switch unit {
        case .ngPerML:
            return ngMLToNmolL(value)
        case .nmolPerL:
            return value
        }
    }

    /// Convert IU of vitamin D to micrograms.
    /// 1 µg = 40 IU
    public static func iuToMicrograms(_ iu: Double) -> Double {
        iu / 40.0
    }

    /// Convert micrograms of vitamin D to IU.
    public static func microgramsToIU(_ mcg: Double) -> Double {
        mcg * 40.0
    }
}
