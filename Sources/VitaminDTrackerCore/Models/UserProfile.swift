import Foundation

/// Represents the user's profile and onboarding state.
public struct UserProfile: Codable, Equatable, Sendable {
    public var homeLocation: HomeLocation?
    public var skinType: FitzpatrickSkinType?
    public var hasCompletedOnboarding: Bool
    public var disclaimerAccepted: Bool
    public var disclaimerAcceptedDate: Date?
    public var recentLocations: [HomeLocation]

    public init(
        homeLocation: HomeLocation? = nil,
        skinType: FitzpatrickSkinType? = nil,
        hasCompletedOnboarding: Bool = false,
        disclaimerAccepted: Bool = false,
        disclaimerAcceptedDate: Date? = nil,
        recentLocations: [HomeLocation] = []
    ) {
        self.homeLocation = homeLocation
        self.skinType = skinType
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.disclaimerAccepted = disclaimerAccepted
        self.disclaimerAcceptedDate = disclaimerAcceptedDate
        self.recentLocations = recentLocations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        homeLocation = try container.decodeIfPresent(HomeLocation.self, forKey: .homeLocation)
        skinType = try container.decodeIfPresent(FitzpatrickSkinType.self, forKey: .skinType)
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        disclaimerAccepted = try container.decodeIfPresent(Bool.self, forKey: .disclaimerAccepted) ?? false
        disclaimerAcceptedDate = try container.decodeIfPresent(Date.self, forKey: .disclaimerAcceptedDate)
        recentLocations = try container.decodeIfPresent([HomeLocation].self, forKey: .recentLocations) ?? []
    }

    /// Maximum number of recent locations to keep.
    private static let maxRecentLocations = 3

    /// Adds a location to the front of the recent locations list, deduplicating.
    public mutating func addRecentLocation(_ location: HomeLocation) {
        recentLocations.removeAll { $0.cityName == location.cityName && $0.country == location.country }
        recentLocations.insert(location, at: 0)
        if recentLocations.count > Self.maxRecentLocations {
            recentLocations = Array(recentLocations.prefix(Self.maxRecentLocations))
        }
    }
}
