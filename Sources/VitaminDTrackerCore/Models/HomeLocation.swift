import Foundation

/// Represents a geographic location used for UV and baseline estimation.
public struct HomeLocation: Codable, Equatable, Sendable {
    public var cityName: String
    public var country: String
    public var latitude: Double
    public var longitude: Double

    public init(cityName: String, country: String = "", latitude: Double, longitude: Double) {
        self.cityName = cityName
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Display name including country when available.
    public var displayName: String {
        country.isEmpty ? cityName : "\(cityName), \(country)"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cityName = try container.decode(String.self, forKey: .cityName)
        country = try container.decodeIfPresent(String.self, forKey: .country) ?? ""
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
    }
}

/// A curated list of major cities with their coordinates for quick selection.
public struct CityDatabase {
    public static let cities: [HomeLocation] = [
        // North America — United States
        HomeLocation(cityName: "New York", country: "US", latitude: 40.7128, longitude: -74.0060),
        HomeLocation(cityName: "Los Angeles", country: "US", latitude: 34.0522, longitude: -118.2437),
        HomeLocation(cityName: "Chicago", country: "US", latitude: 41.8781, longitude: -87.6298),
        HomeLocation(cityName: "Houston", country: "US", latitude: 29.7604, longitude: -95.3698),
        HomeLocation(cityName: "Phoenix", country: "US", latitude: 33.4484, longitude: -112.0740),
        HomeLocation(cityName: "San Francisco", country: "US", latitude: 37.7749, longitude: -122.4194),
        HomeLocation(cityName: "Seattle", country: "US", latitude: 47.6062, longitude: -122.3321),
        HomeLocation(cityName: "Miami", country: "US", latitude: 25.7617, longitude: -80.1918),
        HomeLocation(cityName: "Denver", country: "US", latitude: 39.7392, longitude: -104.9903),
        HomeLocation(cityName: "Boston", country: "US", latitude: 42.3601, longitude: -71.0589),
        HomeLocation(cityName: "Atlanta", country: "US", latitude: 33.7490, longitude: -84.3880),
        HomeLocation(cityName: "Dallas", country: "US", latitude: 32.7767, longitude: -96.7970),
        HomeLocation(cityName: "Minneapolis", country: "US", latitude: 44.9778, longitude: -93.2650),
        HomeLocation(cityName: "Portland", country: "US", latitude: 45.5152, longitude: -122.6784),
        HomeLocation(cityName: "Austin", country: "US", latitude: 30.2672, longitude: -97.7431),
        HomeLocation(cityName: "San Diego", country: "US", latitude: 32.7157, longitude: -117.1611),
        HomeLocation(cityName: "Nashville", country: "US", latitude: 36.1627, longitude: -86.7816),
        HomeLocation(cityName: "Honolulu", country: "US", latitude: 21.3069, longitude: -157.8583),
        HomeLocation(cityName: "Anchorage", country: "US", latitude: 61.2181, longitude: -149.9003),

        // North America — Canada
        HomeLocation(cityName: "Toronto", country: "Canada", latitude: 43.6532, longitude: -79.3832),
        HomeLocation(cityName: "Vancouver", country: "Canada", latitude: 49.2827, longitude: -123.1207),
        HomeLocation(cityName: "Montreal", country: "Canada", latitude: 45.5017, longitude: -73.5673),

        // Latin America & Caribbean
        HomeLocation(cityName: "Mexico City", country: "Mexico", latitude: 19.4326, longitude: -99.1332),
        HomeLocation(cityName: "Cabo San Lucas", country: "Mexico", latitude: 22.8905, longitude: -109.9167),
        HomeLocation(cityName: "Cancún", country: "Mexico", latitude: 21.1619, longitude: -86.8515),
        HomeLocation(cityName: "Puerto Vallarta", country: "Mexico", latitude: 20.6534, longitude: -105.2253),
        HomeLocation(cityName: "São Paulo", country: "Brazil", latitude: -23.5505, longitude: -46.6333),
        HomeLocation(cityName: "Rio de Janeiro", country: "Brazil", latitude: -22.9068, longitude: -43.1729),
        HomeLocation(cityName: "Buenos Aires", country: "Argentina", latitude: -34.6037, longitude: -58.3816),
        HomeLocation(cityName: "Bogotá", country: "Colombia", latitude: 4.7110, longitude: -74.0721),
        HomeLocation(cityName: "Lima", country: "Peru", latitude: -12.0464, longitude: -77.0428),
        HomeLocation(cityName: "San Juan", country: "Puerto Rico", latitude: 18.4655, longitude: -66.1057),

        // Europe
        HomeLocation(cityName: "London", country: "UK", latitude: 51.5074, longitude: -0.1278),
        HomeLocation(cityName: "Paris", country: "France", latitude: 48.8566, longitude: 2.3522),
        HomeLocation(cityName: "Barcelona", country: "Spain", latitude: 41.3874, longitude: 2.1686),
        HomeLocation(cityName: "Madrid", country: "Spain", latitude: 40.4168, longitude: -3.7038),
        HomeLocation(cityName: "Rome", country: "Italy", latitude: 41.9028, longitude: 12.4964),
        HomeLocation(cityName: "Berlin", country: "Germany", latitude: 52.5200, longitude: 13.4050),
        HomeLocation(cityName: "Amsterdam", country: "Netherlands", latitude: 52.3676, longitude: 4.9041),
        HomeLocation(cityName: "Lisbon", country: "Portugal", latitude: 38.7223, longitude: -9.1393),
        HomeLocation(cityName: "Athens", country: "Greece", latitude: 37.9838, longitude: 23.7275),
        HomeLocation(cityName: "Dublin", country: "Ireland", latitude: 53.3498, longitude: -6.2603),
        HomeLocation(cityName: "Stockholm", country: "Sweden", latitude: 59.3293, longitude: 18.0686),
        HomeLocation(cityName: "Copenhagen", country: "Denmark", latitude: 55.6761, longitude: 12.5683),
        HomeLocation(cityName: "Reykjavik", country: "Iceland", latitude: 64.1466, longitude: -21.9426),

        // Asia
        HomeLocation(cityName: "Tokyo", country: "Japan", latitude: 35.6762, longitude: 139.6503),
        HomeLocation(cityName: "Seoul", country: "South Korea", latitude: 37.5665, longitude: 126.9780),
        HomeLocation(cityName: "Bangkok", country: "Thailand", latitude: 13.7563, longitude: 100.5018),
        HomeLocation(cityName: "Singapore", country: "Singapore", latitude: 1.3521, longitude: 103.8198),
        HomeLocation(cityName: "Mumbai", country: "India", latitude: 19.0760, longitude: 72.8777),
        HomeLocation(cityName: "Delhi", country: "India", latitude: 28.7041, longitude: 77.1025),
        HomeLocation(cityName: "Shanghai", country: "China", latitude: 31.2304, longitude: 121.4737),
        HomeLocation(cityName: "Beijing", country: "China", latitude: 39.9042, longitude: 116.4074),
        HomeLocation(cityName: "Hong Kong", country: "China", latitude: 22.3193, longitude: 114.1694),
        HomeLocation(cityName: "Taipei", country: "Taiwan", latitude: 25.0330, longitude: 121.5654),
        HomeLocation(cityName: "Bali", country: "Indonesia", latitude: -8.3405, longitude: 115.0920),
        HomeLocation(cityName: "Manila", country: "Philippines", latitude: 14.5995, longitude: 120.9842),

        // Middle East
        HomeLocation(cityName: "Dubai", country: "UAE", latitude: 25.2048, longitude: 55.2708),
        HomeLocation(cityName: "Tel Aviv", country: "Israel", latitude: 32.0853, longitude: 34.7818),
        HomeLocation(cityName: "Istanbul", country: "Turkey", latitude: 41.0082, longitude: 28.9784),

        // Oceania
        HomeLocation(cityName: "Sydney", country: "Australia", latitude: -33.8688, longitude: 151.2093),
        HomeLocation(cityName: "Melbourne", country: "Australia", latitude: -37.8136, longitude: 144.9631),
        HomeLocation(cityName: "Auckland", country: "New Zealand", latitude: -36.8485, longitude: 174.7633),

        // Africa
        HomeLocation(cityName: "Cape Town", country: "South Africa", latitude: -33.9249, longitude: 18.4241),
        HomeLocation(cityName: "Nairobi", country: "Kenya", latitude: -1.2921, longitude: 36.8219),
        HomeLocation(cityName: "Cairo", country: "Egypt", latitude: 30.0444, longitude: 31.2357),
        HomeLocation(cityName: "Marrakech", country: "Morocco", latitude: 31.6295, longitude: -7.9811),
    ]
}
