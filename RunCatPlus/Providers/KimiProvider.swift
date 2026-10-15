import Foundation

enum KimiProviderError: Error {
    case noCredentialsFile
    case http(Int)
    case badPayload
}

/// Récupère les quotas Kimi Code (fenêtre 5 h + total mensuel) via
/// l'endpoint GET https://api.kimi.ai/coding/v1/usages, avec le jeton OAuth
/// stocké par le CLI dans ~/.kimi-code/credentials/ (rafraîchi au besoin
/// via POST https://auth.kimi.ai/api/oauth/token).
/// Les mutations d'état passent par setState (file principale).
final class KimiProvider: ObservableObject, QuotaProviding {
    @Published private(set) var state = QuotaState()

    private var accessToken: String?
    private var isFetching = false

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
        do {
            let token = try await validToken()
            await fetchUsages(token: token, allowRefresh: true)
        } catch {
            var s = state; s.connectivity = .error("Lancez `kimi` une fois pour vous connecter")
            setState(s)
        }
    }

    // MARK: - Jeton

    /// Retourne un jeton valide (rafraîchi si expiration proche ou passée).
    private func validToken() async throws -> String {
        let credentials = try readCredentials()
        let expiresAt = credentials["expires_at"] as? TimeInterval ?? 0
        if let token = accessToken, Date().timeIntervalSince1970 < expiresAt - 120,
           let cached = credentials["access_token"] as? String, cached == token {
            return token
        }
        if Date().timeIntervalSince1970 < expiresAt - 120,
           let token = credentials["access_token"] as? String {
            accessToken = token
            return token
        }
        // Rafraîchissement nécessaire.
        let fresh = try await refreshAccessToken(credentials: credentials)
        accessToken = fresh
        return fresh
    }

    private static let clientID = "17e5f671-d194-4dfb-9706-5516cb48c098"

    private func refreshAccessToken(credentials: [String: Any]) async throws -> String {
        guard let refreshToken = credentials["refresh_token"] as? String else {
            throw KimiProviderError.noCredentialsFile
        }
        var request = URLRequest(url: URL(string: "https://auth.kimi.ai/api/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
        ]
        request.httpBody = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw KimiProviderError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else {
            throw KimiProviderError.badPayload
        }

        // Persistance best-effort : le CLI Kimi retrouve un jeton valide.
        var updated = credentials
        updated["access_token"] = token
        if let refresh = json["refresh_token"] as? String { updated["refresh_token"] = refresh }
        if let expiresIn = json["expires_in"] as? TimeInterval {
            updated["expires_at"] = Date().timeIntervalSince1970 + expiresIn
        }
        writeCredentials(updated)
        return token
    }

    // MARK: - Stockage fichier

    /// Le CLI stocke ses identifiants dans ~/.kimi-code/credentials/kimi-code-env-*.json
    /// (le suffixe dépend de l'environnement ; on prend le plus récent).
    private func credentialsURL() throws -> URL {
        let dir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".kimi-code/credentials", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.lastPathComponent.hasPrefix("kimi-code-env-") && $0.pathExtension == "json" }
        guard let newest = files.sorted(by: { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return da > db
        }).first else {
            throw KimiProviderError.noCredentialsFile
        }
        return newest
    }

    private func readCredentials() throws -> [String: Any] {
        let data = try Data(contentsOf: credentialsURL())
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KimiProviderError.badPayload
        }
        return json
    }

    private func writeCredentials(_ credentials: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: credentials) else { return }
        try? data.write(to: credentialsURL(), options: .atomic)
    }

    // MARK: - Quotas

    private func fetchUsages(token: String, allowRefresh: Bool) async {
        isFetching = true
        var request = URLRequest(url: URL(string: "https://api.kimi.ai/coding/v1/usages")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("kimi-cli/2.2.0 (Macintosh; Mac OS X)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            if code == 401, allowRefresh {
                // Jeton rejeté : forcer le rafraîchissement et réessayer une fois.
                accessToken = nil
                isFetching = false
                let fresh = try await validToken()
                await fetchUsages(token: fresh, allowRefresh: false)
                return
            }
            guard code == 200 else { throw KimiProviderError.http(code) }
            guard let parsed = Self.parseUsages(data) else { throw KimiProviderError.badPayload }
            var s = state
            s.primary = parsed.monthTotal
            s.secondary = parsed.fiveHour
            s.connectivity = .connected
            setState(s)
        } catch {
            var s = state
            if case .http(let code) = error as? KimiProviderError {
                s.connectivity = .error("HTTP \(code) — endpoint indisponible")
            } else {
                s.connectivity = .error(error.localizedDescription)
            }
            setState(s)
        }
        isFetching = false
    }

    private struct UsagesResponse: Decodable {
        struct Usage: Decodable {
            let used_ratio: Double?
            let reset_time: String?
        }
        struct Usages: Decodable {
            let limit_5h: Usage?
            let limit_month_total: Usage?
            let limit_month_code: Usage?
        }
        let usages: Usages?
    }

    private static func parseUsages(_ data: Data) -> (fiveHour: QuotaWindow?, monthTotal: QuotaWindow?)? {
        guard let decoded = try? JSONDecoder().decode(UsagesResponse.self, from: data),
              let usages = decoded.usages else { return nil }
        let fiveHour = usages.limit_5h.map {
            QuotaWindow(percent: ($0.used_ratio ?? 0) * 100, resetsAt: parseDate($0.reset_time))
        }
        let monthTotal = usages.limit_month_total.map {
            QuotaWindow(percent: ($0.used_ratio ?? 0) * 100, resetsAt: parseDate($0.reset_time))
        }
        return (fiveHour, monthTotal)
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        // Format attendu : "2026-10-14T20:12:32Z"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
