import CoreData

@objc(TripEntity)
public final class TripEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var createdAt: Date
    @NSManaged public var participants: Set<ParticipantEntity>
    @NSManaged public var expenses: Set<ExpenseEntity>
    @NSManaged public var settlements: Set<SettlementEntity>
}

@objc(ParticipantEntity)
public final class ParticipantEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var email: String?
    @NSManaged public var trip: TripEntity
    @NSManaged public var paidExpenses: Set<ExpenseEntity>
    @NSManaged public var shares: Set<ExpenseShareEntity>
    @NSManaged public var fromSettlements: Set<SettlementEntity>
    @NSManaged public var toSettlements: Set<SettlementEntity>
}

@objc(ExpenseEntity)
public final class ExpenseEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var amount: Double
    @NSManaged public var date: Date
    @NSManaged public var note: String?
    @NSManaged public var isSettlement: Bool
    @NSManaged public var trip: TripEntity
    @NSManaged public var paidBy: ParticipantEntity
    @NSManaged public var shares: Set<ExpenseShareEntity>
}

@objc(ExpenseShareEntity)
public final class ExpenseShareEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var amount: Double
    @NSManaged public var expense: ExpenseEntity
    @NSManaged public var participant: ParticipantEntity
}

@objc(SettlementEntity)
public final class SettlementEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var amount: Double
    @NSManaged public var isPaid: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var trip: TripEntity
    @NSManaged public var fromParticipant: ParticipantEntity
    @NSManaged public var toParticipant: ParticipantEntity
}

// MARK: - Identifiable

extension TripEntity: Identifiable {}
extension ParticipantEntity: Identifiable {}
extension ExpenseEntity: Identifiable {}

// MARK: - Convenience accessors

extension TripEntity {
    var participantsArray: [ParticipantEntity] {
        participants.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// User-visible expenses only — settlement entries are excluded from the list.
    var expensesArray: [ExpenseEntity] {
        expenses
            .filter { !$0.isSettlement }
            .sorted { $0.date > $1.date }
    }

    var settlementsArray: [SettlementEntity] {
        settlements.sorted { $0.createdAt > $1.createdAt }
    }

    /// Sum of user-entered expenses, excluding internal settlement entries.
    var totalSpent: Double {
        expenses
            .filter { !$0.isSettlement }
            .reduce(0) { $0 + $1.amount }
    }
}
