import XCTest
@testable import VitaminDTrackerCore

final class UnitConversionTests: XCTestCase {

    // MARK: - ng/mL ↔ nmol/L Conversion

    func testNgMLToNmolL() {
        // 1 ng/mL = 2.496 nmol/L
        let result = UnitConversion.ngMLToNmolL(1.0)
        XCTAssertEqual(result, 2.496, accuracy: 0.001)
    }

    func testNmolLToNgML() {
        let result = UnitConversion.nmolLToNgML(2.496)
        XCTAssertEqual(result, 1.0, accuracy: 0.001)
    }

    func testRoundTripConversion() {
        let original = 30.0
        let converted = UnitConversion.nmolLToNgML(UnitConversion.ngMLToNmolL(original))
        XCTAssertEqual(converted, original, accuracy: 0.001)
    }

    func testToNgMLFromNgML() {
        let result = UnitConversion.toNgML(value: 30.0, unit: .ngPerML)
        XCTAssertEqual(result, 30.0, accuracy: 0.001)
    }

    func testToNgMLFromNmolL() {
        let result = UnitConversion.toNgML(value: 74.88, unit: .nmolPerL)
        XCTAssertEqual(result, 30.0, accuracy: 0.01)
    }

    func testToNmolLFromNmolL() {
        let result = UnitConversion.toNmolL(value: 74.88, unit: .nmolPerL)
        XCTAssertEqual(result, 74.88, accuracy: 0.001)
    }

    func testToNmolLFromNgML() {
        let result = UnitConversion.toNmolL(value: 30.0, unit: .ngPerML)
        XCTAssertEqual(result, 74.88, accuracy: 0.01)
    }

    // MARK: - IU ↔ Microgram Conversion

    func testIUToMicrograms() {
        // 1000 IU = 25 µg
        let result = UnitConversion.iuToMicrograms(1000.0)
        XCTAssertEqual(result, 25.0, accuracy: 0.001)
    }

    func testMicrogramsToIU() {
        let result = UnitConversion.microgramsToIU(25.0)
        XCTAssertEqual(result, 1000.0, accuracy: 0.001)
    }

    func testZeroConversion() {
        XCTAssertEqual(UnitConversion.ngMLToNmolL(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(UnitConversion.nmolLToNgML(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(UnitConversion.iuToMicrograms(0.0), 0.0, accuracy: 0.001)
    }

    // MARK: - VitaminDTestResult Unit Methods

    func testTestResultValueInNgPerML() {
        let test = VitaminDTestResult(
            value: 30.0,
            unit: .ngPerML,
            testDate: Date()
        )
        XCTAssertEqual(test.valueInNgPerML, 30.0, accuracy: 0.001)
    }

    func testTestResultValueInNgPerMLFromNmol() {
        let test = VitaminDTestResult(
            value: 74.88,
            unit: .nmolPerL,
            testDate: Date()
        )
        XCTAssertEqual(test.valueInNgPerML, 30.0, accuracy: 0.01)
    }

    func testTestResultValueInNmolPerL() {
        let test = VitaminDTestResult(
            value: 30.0,
            unit: .ngPerML,
            testDate: Date()
        )
        XCTAssertEqual(test.valueInNmolPerL, 74.88, accuracy: 0.01)
    }
}
