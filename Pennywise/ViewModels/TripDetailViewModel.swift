import Combine
import CoreData
import Foundation

final class TripDetailViewModel: ObservableObject {
    @Published var trip: TripEntity
    @Published var participantName = ""
    @Published var participantEmail = ""
    @Published var balances: [Balance] = []
    @Published var suggestions: [SettlementSuggestion] = []

    private let context: NSManagedObjectContext

    init(trip: TripEntity, context: NSManagedObjectContext) {
        self.trip = trip
        self.context = context
        refresh()
    }

    func refresh() {
        context.refresh(trip, mergeChanges: true)
        balances    = ExpenseCalculator.balances(for: trip)
        suggestions = ExpenseCalculator.settlementSuggestions(for: trip)
    }

    func addParticipant() {
        let trimmedName = participantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let participant = ParticipantEntity(context: context)
        participant.id   = UUID()
        participant.name = trimmedName
        let trimmedEmail = participantEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        participant.email = trimmedEmail.isEmpty ? nil : trimmedEmail
        participant.trip  = trip

        PersistenceController.shared.save()
        participantName  = ""
        participantEmail = ""
        refresh()
    }

    func deleteExpenses(at offsets: IndexSet) {
        let toDelete = offsets.map { trip.expensesArray[$0] }
        toDelete.forEach(context.delete)
        PersistenceController.shared.save()
        refresh()
    }

    func markPaid(_ suggestion: SettlementSuggestion) {
        // Record the settlement for history / audit.
        let settlement = SettlementEntity(context: context)
        settlement.id              = UUID()
        settlement.amount          = suggestion.amount
        settlement.isPaid          = true
        settlement.createdAt       = Date()
        settlement.trip            = trip
        settlement.fromParticipant = suggestion.from
        settlement.toParticipant   = suggestion.to

        // Model the payment as an expense so the balance algorithm self-corrects:
        // `from` paid `suggestion.amount`, and `to` owes that share — zeroing both positions.
        let expense = ExpenseEntity(context: context)
        expense.id           = UUID()
        expense.title        = "Settlement: \(suggestion.from.name) → \(suggestion.to.name)"
        expense.amount       = suggestion.amount
        expense.date         = Date()
        expense.isSettlement = true
        expense.trip         = trip
        expense.paidBy       = suggestion.from

        let share = ExpenseShareEntity(context: context)
        share.id          = UUID()
        share.amount      = suggestion.amount
        share.expense     = expense
        share.participant = suggestion.to

        PersistenceController.shared.save()
        refresh()
    }
}
