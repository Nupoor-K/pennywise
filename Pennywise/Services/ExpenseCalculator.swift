import Foundation

enum ExpenseCalculator {
    static func balances(for trip: TripEntity) -> [Balance] {
        var totals = Dictionary(uniqueKeysWithValues: trip.participantsArray.map { ($0.id, 0.0) })

        for expense in trip.expenses {
            totals[expense.paidBy.id, default: 0] += expense.amount

            if expense.shares.isEmpty {
                // No explicit shares recorded — split evenly among all participants.
                let split = expense.amount / Double(max(trip.participants.count, 1))
                trip.participants.forEach { totals[$0.id, default: 0] -= split }
            } else {
                expense.shares.forEach { totals[$0.participant.id, default: 0] -= $0.amount }
            }
        }

        return trip.participantsArray.map { Balance(participant: $0, amount: totals[$0.id, default: 0]) }
    }

    static func settlementSuggestions(for trip: TripEntity) -> [SettlementSuggestion] {
        let allBalances = balances(for: trip)

        var creditors = allBalances
            .filter(\.isOwedMoney)
            .map { MutableBalance(participant: $0.participant, amount: $0.amount) }
        var debtors = allBalances
            .filter(\.owesMoney)
            .map { MutableBalance(participant: $0.participant, amount: abs($0.amount)) }

        var suggestions: [SettlementSuggestion] = []
        var ci = 0
        var di = 0

        while ci < creditors.count, di < debtors.count {
            let amount = min(creditors[ci].amount, debtors[di].amount)
            if amount > 0.005 {
                suggestions.append(SettlementSuggestion(
                    from: debtors[di].participant,
                    to: creditors[ci].participant,
                    amount: amount
                ))
            }

            creditors[ci].amount -= amount
            debtors[di].amount   -= amount

            if creditors[ci].amount <= 0.005 { ci += 1 }
            if debtors[di].amount   <= 0.005 { di += 1 }
        }

        return suggestions
    }
}

private struct MutableBalance {
    let participant: ParticipantEntity
    var amount: Double
}
