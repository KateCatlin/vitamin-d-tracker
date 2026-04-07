import Foundation

/// Units commonly used in vitamin D blood test results.
public enum VitaminDUnit: String, Codable, CaseIterable, Sendable {
    /// ng/mL - commonly used in the United States
    case ngPerML = "ng/mL"
    /// nmol/L - commonly used internationally (SI unit)
    case nmolPerL = "nmol/L"
}

/// A recorded vitamin D blood test result.
public struct VitaminDTestResult: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var value: Double
    public var unit: VitaminDUnit
    public var testDate: Date
    public var enteredDate: Date

    public init(
        id: UUID = UUID(),
        value: Double,
        unit: VitaminDUnit,
        testDate: Date,
        enteredDate: Date = Date()
    ) {
        self.id = id
        self.value = value
        self.unit = unit
        self.testDate = testDate
        self.enteredDate = enteredDate
    }

    /// Returns the value normalized to ng/mL.
    /// Conversion: 1 ng/mL = 2.496 nmol/L
    public var valueInNgPerML: Double {
        switch unit {
        case .ngPerML:
            return value
        case .nmolPerL:
            return value / 2.496
        }
    }

    /// Returns the value normalized to nmol/L.
    public var valueInNmolPerL: Double {
        switch unit {
        case .ngPerML:
            return value * 2.496
        case .nmolPerL:
            return value
        }
    }
}
