import XCTest
@testable import VitaminDTrackerCore

final class CityDatabaseTests: XCTestCase {

    // MARK: - City Database Validity

    func testAllCitiesHaveNonEmptyCountry() {
        for city in CityDatabase.cities {
            XCTAssertFalse(city.country.isEmpty, "\(city.cityName) has empty country")
        }
    }

    func testAllCitiesHaveValidLatitude() {
        for city in CityDatabase.cities {
            XCTAssertTrue((-90...90).contains(city.latitude),
                          "\(city.cityName) has invalid latitude: \(city.latitude)")
        }
    }

    func testAllCitiesHaveValidLongitude() {
        for city in CityDatabase.cities {
            XCTAssertTrue((-180...180).contains(city.longitude),
                          "\(city.cityName) has invalid longitude: \(city.longitude)")
        }
    }

    func testNoDuplicateCityNames() {
        let names = CityDatabase.cities.map { "\($0.cityName), \($0.country)" }
        let unique = Set(names)
        XCTAssertEqual(names.count, unique.count, "Duplicate city entries found")
    }

    func testCaboSanLucasIsIncluded() {
        let cabo = CityDatabase.cities.first { $0.cityName == "Cabo San Lucas" }
        XCTAssertNotNil(cabo, "Cabo San Lucas should be in the city database")
        XCTAssertEqual(cabo?.country, "Mexico")
    }

    func testCityDatabaseHasInternationalCoverage() {
        let countries = Set(CityDatabase.cities.map { $0.country })
        // Should have cities in at least 15 different countries
        XCTAssertGreaterThanOrEqual(countries.count, 15,
                                     "City database should cover at least 15 countries, found \(countries.count)")
    }

    // MARK: - HomeLocation Display Name

    func testDisplayNameWithCountry() {
        let city = HomeLocation(cityName: "Cabo San Lucas", country: "Mexico", latitude: 22.89, longitude: -109.92)
        XCTAssertEqual(city.displayName, "Cabo San Lucas, Mexico")
    }

    func testDisplayNameWithoutCountry() {
        let city = HomeLocation(cityName: "Unknown", latitude: 0, longitude: 0)
        XCTAssertEqual(city.displayName, "Unknown")
    }

    // MARK: - Recent Locations

    func testAddRecentLocation() {
        var profile = UserProfile()
        let seattle = HomeLocation(cityName: "Seattle", country: "US", latitude: 47.6, longitude: -122.3)

        profile.addRecentLocation(seattle)
        XCTAssertEqual(profile.recentLocations.count, 1)
        XCTAssertEqual(profile.recentLocations.first?.cityName, "Seattle")
    }

    func testRecentLocationsMaxLimit() {
        var profile = UserProfile()
        let cities = [
            HomeLocation(cityName: "A", country: "X", latitude: 0, longitude: 0),
            HomeLocation(cityName: "B", country: "X", latitude: 1, longitude: 1),
            HomeLocation(cityName: "C", country: "X", latitude: 2, longitude: 2),
            HomeLocation(cityName: "D", country: "X", latitude: 3, longitude: 3),
        ]

        for city in cities {
            profile.addRecentLocation(city)
        }

        XCTAssertEqual(profile.recentLocations.count, 3)
        XCTAssertEqual(profile.recentLocations[0].cityName, "D")
        XCTAssertEqual(profile.recentLocations[1].cityName, "C")
        XCTAssertEqual(profile.recentLocations[2].cityName, "B")
    }

    func testRecentLocationsDeduplicates() {
        var profile = UserProfile()
        let seattle = HomeLocation(cityName: "Seattle", country: "US", latitude: 47.6, longitude: -122.3)
        let cabo = HomeLocation(cityName: "Cabo San Lucas", country: "Mexico", latitude: 22.89, longitude: -109.92)

        profile.addRecentLocation(seattle)
        profile.addRecentLocation(cabo)
        profile.addRecentLocation(seattle) // Re-add Seattle

        XCTAssertEqual(profile.recentLocations.count, 2)
        XCTAssertEqual(profile.recentLocations[0].cityName, "Seattle")
        XCTAssertEqual(profile.recentLocations[1].cityName, "Cabo San Lucas")
    }

    func testRecentLocationsMostRecentFirst() {
        var profile = UserProfile()
        let a = HomeLocation(cityName: "A", country: "X", latitude: 0, longitude: 0)
        let b = HomeLocation(cityName: "B", country: "X", latitude: 1, longitude: 1)
        let c = HomeLocation(cityName: "C", country: "X", latitude: 2, longitude: 2)

        profile.addRecentLocation(a)
        profile.addRecentLocation(b)
        profile.addRecentLocation(c)

        XCTAssertEqual(profile.recentLocations[0].cityName, "C")
        XCTAssertEqual(profile.recentLocations[1].cityName, "B")
        XCTAssertEqual(profile.recentLocations[2].cityName, "A")
    }

    // MARK: - Backward Compatibility

    func testHomeLocationDecodesWithoutCountry() throws {
        // Simulate data stored before the country field was added
        let json = """
        {"cityName":"Seattle","latitude":47.6,"longitude":-122.3}
        """
        let data = json.data(using: .utf8)!
        let location = try JSONDecoder().decode(HomeLocation.self, from: data)

        XCTAssertEqual(location.cityName, "Seattle")
        XCTAssertEqual(location.country, "")
        XCTAssertEqual(location.latitude, 47.6, accuracy: 0.01)
    }

    func testUserProfileDecodesWithoutRecentLocations() throws {
        // Simulate data stored before recentLocations was added
        let json = """
        {"hasCompletedOnboarding":true,"disclaimerAccepted":true}
        """
        let data = json.data(using: .utf8)!
        let profile = try JSONDecoder().decode(UserProfile.self, from: data)

        XCTAssertTrue(profile.hasCompletedOnboarding)
        XCTAssertEqual(profile.recentLocations, [])
    }
}
