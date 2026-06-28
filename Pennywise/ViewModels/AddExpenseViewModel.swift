import Combine
import CoreData
import Foundation

final class AddExpenseViewModel: ObservableObject {
    @Published var title = ""
    @Published var amount = ""
    @Published var note = ""
    @Published var paidBy: ParticipantEntity?
    @Published var selectedParticipants = Set<ParticipantEntity>()

    /// All participants on this trip, stable for the lifetime of the sheet.
    let participants: [ParticipantEntity]

    private let trip: TripEntity
    private let context: NSManagedObjectContext

    init(trip: TripEntity, context: NSManagedObjectContext) {
        self.trip = trip
        self.context = context
        self.participants = trip.participantsArray
        paidBy = participants.first
        selectedParticipants = Set(participants)
    }

    var canSave: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let value = Double(amount), value > 0,
              paidBy != nil,
              !selectedParticipants.isEmpty else { return false }
        return true
    }

    func toggleParticipant(_ participant: ParticipantEntity) {
        if selectedParticipants.contains(participant) {
            selectedParticipants.remove(participant)
        } else {
            selectedParticipants.insert(participant)
        }
    }

    func save() {
        guard canSave,
              let value = Double(amount), value > 0,
              let payer = paidBy else { return }

        let expense = ExpenseEntity(context: context)
        expense.id    = UUID()
        expense.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        expense.amount = value
        expense.date   = Date()
        expense.isSettlement = false
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        expense.note = trimmedNote.isEmpty ? nil : trimmedNote
        expense.trip   = trip
        expense.paidBy = payer

        let shareAmount = value / Double(selectedParticipants.count)
        selectedParticipants.forEach { participant in
            let share = ExpenseShareEntity(context: context)
            share.id          = UUID()
            share.amount      = shareAmount
            share.expense     = expense
            share.participant = participant
        }

        PersistenceController.shared.save()
    }
}
