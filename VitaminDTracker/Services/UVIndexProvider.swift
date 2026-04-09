import Foundation
import CoreLocation
import VitaminDTrackerCore

#if canImport(WeatherKit)
import WeatherKit
#endif

/// Where a UV index value came from. Surfaced so the UI can label
/// values as "live" vs. "estimated" — important after the user
/// noticed the in-app number disagreeing with the internet.
enum UVIndexSource {
    /// Live current-conditions value from WeatherKit. Accounts for
    /// today's actual cloud, ozone, aerosols.
    case weatherKit
    /// Astronomical clear-sky model from ``BaselineEstimator``.
    /// Accurate for sun position; blind to weather.
    case clearSkyModel
}

struct UVIndexReading {
    let value: Double
    let source: UVIndexSource
    let fetchedAt: Date
}

/// Resolves a UV index for a ``HomeLocation``, preferring WeatherKit
/// when reachable and falling back to the offline clear-sky model
/// when it isn't.
///
/// WeatherKit is the right choice here because:
/// - Native Swift SDK, no API key to ship or proxy.
/// - 500k calls/month included with the paid Apple Developer Program.
/// - Privacy disclosure handled by Apple's Weather attribution.
///
/// **Setup required outside this file:** WeatherKit needs the
/// `com.apple.developer.weatherkit` entitlement on the app target,
/// and the WeatherKit capability checked for the App ID in the
/// developer portal. Without those the call throws an auth error
/// and we silently fall back to the clear-sky model — the app still
/// works, just less accurately.
///
/// The provider caches per location for ``cacheTTL`` to avoid burning
/// quota when the Sun Session screen calls ``currentUVIndex(for:)``
/// on every appear. UV doesn't move meaningfully in 15 minutes.
@MainActor
final class UVIndexProvider {

    static let shared = UVIndexProvider()

    /// How long a WeatherKit response stays valid before we'll hit
    /// the network again for the same location. UV index changes on
    /// a timescale of tens of minutes; 15 min keeps the displayed
    /// value from going stale across a sun session while keeping
    /// requests well under quota even with heavy use.
    private let cacheTTL: TimeInterval = 15 * 60

    private struct CacheKey: Hashable {
        // Round to ~1 km so wandering around the same beach doesn't
        // bust the cache. 0.01° ≈ 1.1 km of latitude.
        let latBucket: Int
        let lonBucket: Int

        init(_ location: HomeLocation) {
            latBucket = Int((location.latitude  * 100).rounded())
            lonBucket = Int((location.longitude * 100).rounded())
        }
    }

    private var cache: [CacheKey: UVIndexReading] = [:]

    private init() {}

    /// Returns the best available UV index for `location` right now.
    ///
    /// Resolution order:
    /// 1. Cached WeatherKit value younger than ``cacheTTL``.
    /// 2. Fresh WeatherKit fetch.
    /// 3. ``BaselineEstimator/estimateUVIndex(location:date:)``.
    ///
    /// Never throws — failure modes degrade to the clear-sky model.
    func currentUVIndex(for location: HomeLocation) async -> UVIndexReading {
        let key = CacheKey(location)

        if let hit = cache[key],
           hit.source == .weatherKit,
           Date().timeIntervalSince(hit.fetchedAt) < cacheTTL {
            return hit
        }

        if let live = await fetchFromWeatherKit(location: location) {
            cache[key] = live
            return live
        }

        // We don't cache the fallback: it's free to compute, and a
        // stale fallback would mask a WeatherKit recovery.
        return UVIndexReading(
            value: BaselineEstimator.estimateUVIndex(location: location),
            source: .clearSkyModel,
            fetchedAt: Date()
        )
    }

    /// Drops every cached entry. Call after the user changes their
    /// home city in Settings, otherwise the next refresh might serve
    /// the old city's reading.
    func invalidateCache() {
        cache.removeAll()
    }

    // MARK: - WeatherKit

    private func fetchFromWeatherKit(location: HomeLocation) async -> UVIndexReading? {
        #if canImport(WeatherKit)
        let coord = CLLocation(latitude: location.latitude,
                               longitude: location.longitude)
        do {
            // `.current` is the smallest, fastest query — we only need
            // the UV index, not hourly forecasts.
            let current = try await WeatherService.shared.weather(
                for: coord,
                including: .current
            )
            return UVIndexReading(
                value: Double(current.uvIndex.value),
                source: .weatherKit,
                fetchedAt: Date()
            )
        } catch {
            // Auth not configured, offline, rate-limited, service down.
            // All of these collapse to "use the math instead". Logged
            // at debug only — this is an expected path on a beach with
            // no signal, not an app error.
            #if DEBUG
            print("[UVIndexProvider] WeatherKit fetch failed: \(error)")
            #endif
            return nil
        }
        #else
        return nil
        #endif
    }
}
