import Foundation
import Security

/// Thin wrapper around the iOS Keychain for storing small `Codable` blobs.
///
/// Why Keychain instead of `UserDefaults` for sensitive data:
/// - `UserDefaults` writes to a plaintext plist that is included in
///   unencrypted iTunes/Finder backups and is readable by anyone with
///   filesystem access to an unlocked device.
/// - The Keychain is hardware-encrypted, excluded from unencrypted
///   backups, and supports per-item access control.
///
/// We use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`:
/// - "WhenUnlocked"   → data unreadable while the device is locked
///   (good enough for an app the user actively opens; we don't need
///   background access).
/// - "ThisDeviceOnly" → excluded from backups and never migrated to a
///   new device. The user's skin type and blood test results stay on
///   the device they entered them on.
///
/// Items are stored as Generic Passwords keyed by `account`. We do NOT
/// set `kSecAttrService`; on iOS the keychain access group is already
/// scoped to the app, so `account` alone is sufficient and simpler.
///
/// All operations are synchronous (Keychain calls are fast for small
/// payloads) and silently no-op on failure to match the existing
/// `PersistenceManager` ergonomics. If you ever need diagnostics, the
/// `OSStatus` results are kept locally and can be logged.
public final class KeychainStorage {

    public static let shared = KeychainStorage()

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Public

    /// Encode and store a `Codable` value under `key`.
    /// Passing `nil` deletes the item.
    public func save<T: Codable>(_ value: T?, forKey key: String) {
        guard let value else {
            delete(key: key)
            return
        }
        guard let data = try? encoder.encode(value) else { return }
        setData(data, forKey: key)
    }

    /// Load and decode a `Codable` value from `key`. Returns `nil` if
    /// the item is missing or fails to decode.
    public func load<T: Codable>(forKey key: String) -> T? {
        guard let data = getData(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    /// True if any item exists at `key` (regardless of decodability).
    public func contains(key: String) -> Bool {
        getData(forKey: key) != nil
    }

    /// Store pre-encoded bytes directly. Used by `PersistenceManager`'s
    /// legacy migration, where the JSON `Data` was already produced by
    /// the old `UserDefaults` encoder and re-encoding through
    /// ``save(_:forKey:)`` would base64-wrap it.
    public func saveRaw(_ data: Data, forKey key: String) {
        setData(data, forKey: key)
    }

    /// Remove the item at `key`. Safe to call when nothing exists.
    public func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
        ]
        // errSecItemNotFound is fine — treat as success.
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Raw data primitives

    private func setData(_ data: Data, forKey key: String) {
        // Try update first — cheaper when the item already exists and
        // avoids the delete-then-add race.
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
        ]
        let attributesToUpdate: [CFString: Any] = [
            kSecValueData: data,
        ]
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            attributesToUpdate as CFDictionary
        )

        if updateStatus == errSecSuccess { return }

        // Not found → add fresh.
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            addQuery[kSecAttrAccessible] =
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(addQuery as CFDictionary, nil)
            return
        }

        // Some other failure (e.g. errSecInteractionNotAllowed during
        // a locked-device background launch). Last-ditch: delete and
        // re-add so we don't leave a stale item.
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] =
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func getData(forKey key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
}
