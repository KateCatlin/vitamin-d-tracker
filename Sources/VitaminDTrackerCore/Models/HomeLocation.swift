import Foundation

/// Represents a geographic location used for UV and baseline estimation.
public struct HomeLocation: Codable, Equatable, Sendable {
    public var cityName: String
    public var latitude: Double
    public var longitude: Double

    public init(cityName: String, latitude: Double, longitude: Double) {
        self.cityName = cityName
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// A curated list of major cities with their coordinates for quick selection.
public struct CityDatabase {
    public static let cities: [HomeLocation] = [
        HomeLocation(cityName: "New York", latitude: 40.7128, longitude: -74.0060),
        HomeLocation(cityName: "Los Angeles", latitude: 34.0522, longitude: -118.2437),
        HomeLocation(cityName: "Chicago", latitude: 41.8781, longitude: -87.6298),
        HomeLocation(cityName: "Houston", latitude: 29.7604, longitude: -95.3698),
        HomeLocation(cityName: "Phoenix", latitude: 33.4484, longitude: -112.0740),
        HomeLocation(cityName: "San Francisco", latitude: 37.7749, longitude: -122.4194),
        HomeLocation(cityName: "Seattle", latitude: 47.6062, longitude: -122.3321),
        HomeLocation(cityName: "Miami", latitude: 25.7617, longitude: -80.1918),
        HomeLocation(cityName: "Denver", latitude: 39.7392, longitude: -104.9903),
        HomeLocation(cityName: "Boston", latitude: 42.3601, longitude: -71.0589),
        HomeLocation(cityName: "Atlanta", latitude: 33.7490, longitude: -84.3880),
        HomeLocation(cityName: "Dallas", latitude: 32.7767, longitude: -96.7970),
        HomeLocation(cityName: "Minneapolis", latitude: 44.9778, longitude: -93.2650),
        HomeLocation(cityName: "Portland", latitude: 45.5152, longitude: -122.6784),
        HomeLocation(cityName: "Austin", latitude: 30.2672, longitude: -97.7431),
        HomeLocation(cityName: "San Diego", latitude: 32.7157, longitude: -117.1611),
        HomeLocation(cityName: "Nashville", latitude: 36.1627, longitude: -86.7816),
        HomeLocation(cityName: "Honolulu", latitude: 21.3069, longitude: -157.8583),
        HomeLocation(cityName: "Anchorage", latitude: 61.2181, longitude: -149.9003),
        HomeLocation(cityName: "London", latitude: 51.5074, longitude: -0.1278),
        HomeLocation(cityName: "Toronto", latitude: 43.6532, longitude: -79.3832),
        HomeLocation(cityName: "Sydney", latitude: -33.8688, longitude: 151.2093),
        HomeLocation(cityName: "Tokyo", latitude: 35.6762, longitude: 139.6503),
        HomeLocation(cityName: "Mexico City", latitude: 19.4326, longitude: -99.1332),
        HomeLocation(cityName: "Mumbai", latitude: 19.0760, longitude: 72.8777),
    ]
}
