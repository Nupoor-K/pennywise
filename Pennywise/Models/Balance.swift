import Foundation

struct Balance: Identifiable, Hashable {
    /// Stable across refreshes — the participant doesn't change.
    var id: UUID { participant.id }
    let participant: ParticipantEntity
    let amount: Double

    var isOwedMoney: Bool { amount > 0.005 }
    var owesMoney: Bool   { amount < -0.005 }
}

struct SettlementSuggestion: Identifiable, Hashable {
    /// Stable within a trip: a given from→to pair produces the same ID every time.
    var id: String { "\(from.id)→\(to.id)" }
    let from: ParticipantEntity
    let to: ParticipantEntity
    let amount: Double
}
