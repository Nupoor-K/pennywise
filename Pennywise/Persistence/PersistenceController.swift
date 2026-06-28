import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        let trip = TripEntity(context: context)
        trip.id = UUID()
        trip.name = "Lake Weekend"
        trip.createdAt = Date()

        let participants = ["Maya", "Dev", "Nora"].map { name -> ParticipantEntity in
            let p = ParticipantEntity(context: context)
            p.id = UUID()
            p.name = name
            p.trip = trip
            return p
        }

        guard let payer = participants.first else { return controller }

        let expense = ExpenseEntity(context: context)
        expense.id = UUID()
        expense.title = "Cabin"
        expense.amount = 360
        expense.date = Date()
        expense.isSettlement = false
        expense.trip = trip
        expense.paidBy = payer

        let shareAmount = expense.amount / Double(participants.count)
        participants.forEach { participant in
            let share = ExpenseShareEntity(context: context)
            share.id = UUID()
            share.amount = shareAmount
            share.expense = expense
            share.participant = participant
        }

        try? context.save()
        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Pennywise", managedObjectModel: Self.makeModel())

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Unable to load Pennywise store: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            context.rollback()
            assertionFailure("Core Data save failed: \(error.localizedDescription)")
        }
    }
}

private extension PersistenceController {
    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let trip        = entity("TripEntity",         managedObjectClass: TripEntity.self)
        let participant = entity("ParticipantEntity",  managedObjectClass: ParticipantEntity.self)
        let expense     = entity("ExpenseEntity",      managedObjectClass: ExpenseEntity.self)
        let share       = entity("ExpenseShareEntity", managedObjectClass: ExpenseShareEntity.self)
        let settlement  = entity("SettlementEntity",   managedObjectClass: SettlementEntity.self)

        trip.properties = [
            attribute("id",        .UUIDAttributeType,    optional: false),
            attribute("name",      .stringAttributeType,  optional: false),
            attribute("createdAt", .dateAttributeType,    optional: false),
        ]

        participant.properties = [
            attribute("id",    .UUIDAttributeType,   optional: false),
            attribute("name",  .stringAttributeType, optional: false),
            attribute("email", .stringAttributeType),
        ]

        expense.properties = [
            attribute("id",           .UUIDAttributeType,    optional: false),
            attribute("title",        .stringAttributeType,  optional: false),
            attribute("amount",       .doubleAttributeType,  optional: false),
            attribute("date",         .dateAttributeType,    optional: false),
            attribute("note",         .stringAttributeType),
            attribute("isSettlement", .booleanAttributeType, optional: false),
        ]

        share.properties = [
            attribute("id",     .UUIDAttributeType,   optional: false),
            attribute("amount", .doubleAttributeType, optional: false),
        ]

        settlement.properties = [
            attribute("id",        .UUIDAttributeType,    optional: false),
            attribute("amount",    .doubleAttributeType,  optional: false),
            attribute("isPaid",    .booleanAttributeType, optional: false),
            attribute("createdAt", .dateAttributeType,    optional: false),
        ]

        // MARK: Trip ↔ Participant
        let tripParticipants = relationship("participants", destination: participant, min: 0, max: 0, deleteRule: .cascadeDeleteRule)
        let participantTrip  = relationship("trip",         destination: trip,        min: 1, max: 1, deleteRule: .nullifyDeleteRule)
        tripParticipants.inverseRelationship = participantTrip
        participantTrip.inverseRelationship  = tripParticipants

        // MARK: Trip ↔ Expense
        let tripExpenses = relationship("expenses", destination: expense, min: 0, max: 0, deleteRule: .cascadeDeleteRule)
        let expenseTrip  = relationship("trip",     destination: trip,    min: 1, max: 1, deleteRule: .nullifyDeleteRule)
        tripExpenses.inverseRelationship = expenseTrip
        expenseTrip.inverseRelationship  = tripExpenses

        // MARK: Expense ↔ Participant (paidBy / paidExpenses)
        let expensePayer          = relationship("paidBy",       destination: participant, min: 1, max: 1, deleteRule: .nullifyDeleteRule)
        let participantPaidExpenses = relationship("paidExpenses", destination: expense,   min: 0, max: 0, deleteRule: .nullifyDeleteRule)
        expensePayer.inverseRelationship          = participantPaidExpenses
        participantPaidExpenses.inverseRelationship = expensePayer

        // MARK: Expense ↔ ExpenseShare
        let expenseShares = relationship("shares",  destination: share,   min: 0, max: 0, deleteRule: .cascadeDeleteRule)
        let shareExpense  = relationship("expense", destination: expense, min: 1, max: 1, deleteRule: .nullifyDeleteRule)
        expenseShares.inverseRelationship = shareExpense
        shareExpense.inverseRelationship  = expenseShares

        // MARK: ExpenseShare ↔ Participant
        let shareParticipant  = relationship("participant", destination: participant, min: 1, max: 1, deleteRule: .nullifyDeleteRule)
        let participantShares = relationship("shares",      destination: share,       min: 0, max: 0, deleteRule: .cascadeDeleteRule)
        shareParticipant.inverseRelationship  = participantShares
        participantShares.inverseRelationship = shareParticipant

        // MARK: Trip ↔ Settlement
        let tripSettlements = relationship("settlements", destination: settlement, min: 0, max: 0, deleteRule: .cascadeDeleteRule)
        let settlementTrip  = relationship("trip",        destination: trip,       min: 1, max: 1, deleteRule: .nullifyDeleteRule)
        tripSettlements.inverseRelationship = settlementTrip
        settlementTrip.inverseRelationship  = tripSettlements

        // MARK: Settlement ↔ Participant (from)
        let settlementFrom          = relationship("fromParticipant",  destination: participant, min: 1, max: 1, deleteRule: .nullifyDeleteRule)
        let participantFromSettlements = relationship("fromSettlements", destination: settlement, min: 0, max: 0, deleteRule: .nullifyDeleteRule)
        settlementFrom.inverseRelationship             = participantFromSettlements
        participantFromSettlements.inverseRelationship = settlementFrom

        // MARK: Settlement ↔ Participant (to)
        let settlementTo          = relationship("toParticipant",    destination: participant, min: 1, max: 1, deleteRule: .nullifyDeleteRule)
        let participantToSettlements = relationship("toSettlements", destination: settlement,  min: 0, max: 0, deleteRule: .nullifyDeleteRule)
        settlementTo.inverseRelationship             = participantToSettlements
        participantToSettlements.inverseRelationship = settlementTo

        // MARK: Assemble property lists
        trip.properties        += [tripParticipants, tripExpenses, tripSettlements]
        participant.properties += [participantTrip, participantPaidExpenses, participantShares,
                                   participantFromSettlements, participantToSettlements]
        expense.properties     += [expenseTrip, expensePayer, expenseShares]
        share.properties       += [shareExpense, shareParticipant]
        settlement.properties  += [settlementTrip, settlementFrom, settlementTo]

        model.entities = [trip, participant, expense, share, settlement]
        return model
    }

    static func entity<T: NSManagedObject>(_ name: String, managedObjectClass: T.Type) -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = name
        e.managedObjectClassName = NSStringFromClass(managedObjectClass)
        return e
    }

    static func attribute(_ name: String, _ type: NSAttributeType, optional: Bool = true) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name
        a.attributeType = type
        a.isOptional = optional
        return a
    }

    static func relationship(
        _ name: String,
        destination: NSEntityDescription,
        min: Int,
        max: Int,
        deleteRule: NSDeleteRule
    ) -> NSRelationshipDescription {
        let r = NSRelationshipDescription()
        r.name = name
        r.destinationEntity = destination
        r.minCount = min
        r.maxCount = max
        r.deleteRule = deleteRule
        return r
    }
}
