import Foundation

/// Une fenêtre de quota (ex : 5 h ou 7 j) avec son % de consommation et sa RAZ.
struct QuotaWindow: Equatable {
    var percent: Double     // 0...100
    var resetsAt: Date?

    /// "3h12", "47m" ou "2j14h" — temps restant avant la remise à zéro.
    var countdownText: String {
        guard let resetsAt else { return "—" }
        let seconds = resetsAt.timeIntervalSinceNow
        guard seconds > 0 else { return "0m" }
        let hours = Int(seconds / 3600)
        let minutes = Int(seconds.truncatingRemainder(dividingBy: 3600)) / 60
        if hours >= 24 { return "\(hours / 24)j\(hours % 24)h" }
        if hours >= 1 { return "\(hours)h\(minutes)" }
        return "\(max(minutes, 1))m"
    }
}

extension QuotaWindow {
    /// "3h 12m", "47m" ou "2j 14h" — version lisible pour le menu.
    var remainingText: String {
        guard let resetsAt else { return "—" }
        let seconds = resetsAt.timeIntervalSinceNow
        guard seconds > 0 else { return "0m" }
        let hours = Int(seconds / 3600)
        let minutes = Int(seconds.truncatingRemainder(dividingBy: 3600)) / 60
        if hours >= 24 { return "\(hours / 24)j \(hours % 24)h" }
        if hours >= 1 { return "\(hours)h \(minutes)m" }
        return "\(max(minutes, 1))m"
    }
}

/// État générique affiché par un anneau de quota dans la barre des menus.
struct QuotaState: Equatable {
    enum Connectivity: Equatable {
        case unknown
        case connected
        case error(String)
    }

    var primary: QuotaWindow?     // ex : fenêtre 7 j (arc extérieur)
    var secondary: QuotaWindow?   // ex : fenêtre 5 h (arc intérieur)
    var connectivity: Connectivity = .unknown

    /// La fenêtre la plus consommée — celle dont on affiche le compte à rebours.
    var mostCritical: QuotaWindow? {
        [primary, secondary].compactMap { $0 }.max { $0.percent < $1.percent }
    }

    var statusText: String {
        switch connectivity {
        case .unknown: return "Non connecté"
        case .connected: return "Connecté"
        case .error(let message): return message
        }
    }
}

protocol QuotaProviding: ObservableObject {
    var state: QuotaState { get }
    func refresh() async
}
