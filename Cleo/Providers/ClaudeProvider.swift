import Foundation
import Security

enum ClaudeProviderError: Error {
    case noCredentials
    case http(Int)
    case badPayload
}

/// Récupère les limites rate (5 h / 7 j) de Claude Code via l'endpoint
/// officieux /api/oauth/usage, avec le jeton OAuth stocké par le CLI
/// dans le trousseau macOS ("Claude Code-credentials").
/// Les mutations d'état passent par setState (file principale) : l'exécuteur
/// Swift Concurrency du main actor est inerte dans ce binaire.
final class ClaudeProvider: ObservableObject, QuotaProviding {
    @Published private(set) var state = QuotaState()

    private var accessToken: String?
    private let isFetchingLock = NSLock()
    private var _isFetching = false
    private var isFetching: Bool {
        get { isFetchingLock.withLock { _isFetching } }
        set { isFetchingLock.withLock { _isFetching = newValue } }
    }

    private func setState(_ newValue: QuotaState) {
        if Thread.isMainThread {
            state = newValue
        } else {
            DispatchQueue.main.async { self.state = newValue }
        }
    }

    // MARK: - QuotaProviding

    func refresh() async {
        guard !isFetching else { return }
        guard let token = accessToken ?? KeychainClaude.readToken() else {
            var s = state; s.connectivity = .error("Lancez `claude` une fois pour vous connecter")
            setState(s)
            return
        }
        accessToken = token
        await fetchUsage(token: token, allowRefresh: true)
    }

    // MARK: - Internals

    private func fetchUsage(token: String, allowRefresh: Bool) async {
        isFetching = true
        do {
            let data = try await Self.requestUsage(token: token)
            guard let parsed = Self.parseUsage(data) else { throw ClaudeProviderError.badPayload }
            var s = state
            s.primary = parsed.sevenDay
            s.secondary = parsed.fiveHour
            s.connectivity = .connected
            setState(s)
        } catch ClaudeProviderError.http(401) where allowRefresh {
            do {
                let newToken = try await Self.refreshAccessToken()
                accessToken = newToken
                isFetching = false
                await fetchUsage(token: newToken, allowRefresh: false)
                return
            } catch {
                var s = state; s.connectivity = .error("Session expirée — relancez `claude`")
                setState(s)
            }
        } catch {
            var s = state
            if case .http(let code) = error as? ClaudeProviderError {
                s.connectivity = .error("HTTP \(code) — endpoint indisponible")
            } else {
                s.connectivity = .error(error.localizedDescription)
            }
            setState(s)
        }
        isFetching = false
    }

    private static func requestUsage(token: String) async throws -> Data {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ClaudeProviderError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }

    private struct UsageResponse: Decodable {
        struct Window: Decodable {
            let utilization: Double?
            let resets_at: String?
        }
        let five_hour: Window?
        let seven_day: Window?
    }

    private static func parseUsage(_ data: Data) -> (fiveHour: QuotaWindow, sevenDay: QuotaWindow)? {
        guard let decoded = try? JSONDecoder().decode(UsageResponse.self, from: data),
              let seven = decoded.seven_day else { return nil }
        let five = decoded.five_hour
        return (
            fiveHour: QuotaWindow(percent: five?.utilization ?? 0,
                                  resetsAt: five.flatMap { parseDate($0.resets_at) }),
            sevenDay: QuotaWindow(percent: seven.utilization ?? 0,
                                  resetsAt: parseDate(seven.resets_at))
        )
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

    // MARK: - Rafraîchissement du jeton

    /// Client OAuth public de Claude Code (identique pour tous les utilisateurs,
    /// découvert par rétro-ingénierie — utilisé uniquement pour échanger le refresh token).
    private static let oauthClientID = "9d1c250a-e61b-44d7-88cb-1b08bfc97fea"

    private static func refreshAccessToken() async throws -> String {
        guard let credentials = KeychainClaude.readCredentials(),
              let oauth = credentials["claudeAiOauth"] as? [String: Any],
              let refreshToken = oauth["refreshToken"] as? String else {
            throw ClaudeProviderError.noCredentials
        }

        var request = URLRequest(url: URL(string: "https://console.anthropic.com/v1/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": oauthClientID,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ClaudeProviderError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newToken = json["access_token"] as? String else {
            throw ClaudeProviderError.badPayload
        }

        // Mise à jour best-effort du bloc claudeAiOauth (mcpOAuth préservé)
        // pour que le CLI Claude Code retrouve un jeton valide lui aussi.
        var updatedOauth = oauth
        updatedOauth["accessToken"] = newToken
        if let expiresIn = json["expires_in"] as? TimeInterval {
            updatedOauth["expiresAt"] = Date().timeIntervalSince1970 + expiresIn
        }
        if let newRefresh = json["refresh_token"] as? String {
            updatedOauth["refreshToken"] = newRefresh
        }
        var updated = credentials
        updated["claudeAiOauth"] = updatedOauth
        KeychainClaude.updateCredentials(updated)

        return newToken
    }
}

// MARK: - Accès trousseau

enum KeychainClaude {
    private static let service = "Claude Code-credentials"

    static func readCredentials() -> [String: Any]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    static func readOAuth() -> [String: Any]? {
        readCredentials()?["claudeAiOauth"] as? [String: Any]
    }

    static func readToken() -> String? {
        readOAuth()?["accessToken"] as? String
    }

    @discardableResult
    static func updateCredentials(_ credentials: [String: Any]) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: credentials) else {
            return false
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecAttrAccount as String] = service
            newItem[kSecValueData as String] = data
            return SecItemAdd(newItem as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }
}
