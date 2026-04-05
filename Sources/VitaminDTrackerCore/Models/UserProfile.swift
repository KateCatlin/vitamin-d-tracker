import Foundation

/// Represents the user's profile and onboarding state.
public struct UserProfile: Codable, Equatable, Sendable {
    public var homeLocation: HomeLocation?
    public var hasCompletedOnboarding: Bool
    public var disclaimerAccepted: Bool
    public var disclaimerAcceptedDate: Date?

    public init(
        homeLocation: HomeLocation? = nil,
        hasCompletedOnboarding: Bool = false,
        disclaimerAccepted: Bool = false,
        disclaimerAcceptedDate: Date? = nil
    ) {
        self.homeLocation = homeLocation
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.disclaimerAccepted = disclaimerAccepted
        self.disclaimerAcceptedDate = disclaimerAcceptedDate
    }
}
