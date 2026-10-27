import Foundation

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

/// Lecture/écriture de l'item « Claude Code-credentials » via /usr/bin/security,
/// comme le fait le CLI Claude Code. Pourquoi pas SecItem* en direct : l'item
/// porte une « partition list » que le CLI remet à `apple-tool:` à chaque
/// rafraîchissement de jeton (`security add-generic-password -U`). Toute
/// autre app, même signée avec un Team ID et « toujours autorisée », se voit
/// alors redemander le mot de passe de session. L'outil `security`, lui, est
/// dans la partition `apple-tool:` en permanence : zéro invite.
enum KeychainClaude {
    private static let service = "Claude Code-credentials"
    private static let securityTool = "/usr/bin/security"

    static func readCredentials() -> [String: Any]? {
        guard let output = runSecurity(["find-generic-password", "-s", service, "-w"]),
              let data = output.data(using: .utf8),
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

    /// Met à jour l'item en place (`-U`), en hexadécimal (`-X`) pour éviter
    /// tout souci d'échappement — même commande que le CLI.
    @discardableResult
    static func updateCredentials(_ credentials: [String: Any]) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: credentials) else {
            return false
        }
        let hex = data.map { String(format: "%02x", $0) }.joined()
        let account = itemAccount() ?? NSUserName()
        return runSecurity(["add-generic-password", "-U", "-a", account, "-s", service, "-X", hex]) != nil
    }

    /// Compte de l'item existant (`"acct"<blob>="…"`), pour que `-U` mette à
    /// jour le bon item au lieu d'en créer un second.
    private static func itemAccount() -> String? {
        guard let listing = runSecurity(["find-generic-password", "-s", service]) else { return nil }
        for line in listing.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\"acct\"<blob>=\"") else { continue }
            return String(trimmed.dropFirst("\"acct\"<blob>=\"".count).dropLast())
        }
        return nil
    }

    /// Lance `security` et renvoie sa sortie standard (sans retour final),
    /// ou nil si l'outil échoue (item absent, accès refusé…).
    private static func runSecurity(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: securityTool)
        process.arguments = arguments
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines)
    }
}
