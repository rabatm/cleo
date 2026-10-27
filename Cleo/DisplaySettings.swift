import Foundation

/// Choix d'affichage persistants (UserDefaults) : quels fournisseurs de quota
/// Cleo montre. Un fournisseur masqué disparaît de la barre des menus et du
/// panneau, et n'est plus interrogé (ni réseau, ni trousseau).
final class DisplaySettings: ObservableObject {
    private static let claudeKey = "showClaudeCode"
    private static let kimiKey = "showKimiCode"

    @Published var showClaude: Bool {
        didSet { UserDefaults.standard.set(showClaude, forKey: Self.claudeKey) }
    }
    @Published var showKimi: Bool {
        didSet { UserDefaults.standard.set(showKimi, forKey: Self.kimiKey) }
    }

    init(defaults: UserDefaults = .standard) {
        showClaude = defaults.object(forKey: Self.claudeKey) as? Bool ?? true
        showKimi = defaults.object(forKey: Self.kimiKey) as? Bool ?? true
    }
}
