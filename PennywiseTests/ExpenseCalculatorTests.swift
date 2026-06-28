import XCTest
import CoreData
@testable import Pennywise

final class ExpenseCalculatorTests: XCTestCase {

    // MARK: - Setup

    private var controller: PersistenceController!
    private var context: NSManagedObjectContext!
    private var trip: TripEntity!

    override func setUp() {
        super.setUp()
        controller = PersistenceController(inMemory: true)
        context    = controller.container.viewContext
        trip       = TripEntity(context: context)
        trip.id        = UUID()
        trip.name      = "Test Trip"
        trip.createdAt = Date()
    }

    override func tearDown() {
        trip       = nil
        context    = nil
        controller = nil
        super.tearDown()
    }

    // MARK: - Helpers

    @discardableResult
    private func participant(_ name: String) -> ParticipantEntity {
        let p   = ParticipantEntity(context: context)
        p.id   = UUID()
        p.name = name
        p.trip = trip
        return p
    }

    /// Creates an expense. Pass `shares` to record explicit split amounts; omit it to leave
    /// the expense with no share records (triggering the even-split fallback path).
    @discardableResult
    private func expense(
        _ title: String,
        amount: Double,
        paidBy: ParticipantEntity,
        shares: [(ParticipantEntity, Double)]? = nil
    ) -> ExpenseEntity {
        let e        = ExpenseEntity(context: context)
        e.id         = UUID()
        e.title      = title
        e.amount     = amount
        e.date       = Date()
        e.isSettlement = false
        e.trip       = trip
        e.paidBy     = paidBy

        shares?.forEach { (participant, shareAmount) in
            let s         = ExpenseShareEntity(context: context)
            s.id          = UUID()
            s.amount      = shareAmount
            s.expense     = e
            s.participant = participant
        }
        return e
    }

    /// Returns a name → balance dictionary for the current trip state.
    private func balanceMap() -> [String: Double] {
        Dictionary(
            uniqueKeysWithValues: ExpenseCalculator.balances(for: trip)
                .map { ($0.participant.name, $0.amount) }
        )
    }

    // MARK: - Balance: even split (no share records)

    /// When no ExpenseShareEntity records exist, the calculator divides the expense
    /// evenly among all trip participants.
    func test_balances_evenSplit_noShareRecords() {
        let maya = participant("Maya")
        let dev  = participant("Dev")
        let nora = participant("Nora")

        // Maya pays $300. No shares → split evenly: $100 each.
        // Maya: +300 − 100 = +200 (owed money)
        // Dev:  −100  (owes)
        // Nora: −100  (owes)
        expense("Cabin", amount: 300, paidBy: maya)

        let b = balanceMap()
        XCTAssertEqual(b["Maya"]!,  200.0, accuracy: 0.001)
        XCTAssertEqual(b["Dev"]!,  -100.0, accuracy: 0.001)
        XCTAssertEqual(b["Nora"]!, -100.0, accuracy: 0.001)
    }

    // MARK: - Balance: explicit shares

    func test_balances_customShares_unequalSplit() {
        let maya = participant("Maya")
        let dev  = participant("Dev")

        // Maya pays $100. Her share is $60, Dev's is $40.
        // Maya: +100 − 60 = +40
        // Dev:  −40
        expense("Dinner", amount: 100, paidBy: maya, shares: [(maya, 60), (dev, 40)])

        let b = balanceMap()
        XCTAssertEqual(b["Maya"]!,  40.0, accuracy: 0.001)
        XCTAssertEqual(b["Dev"]!,  -40.0, accuracy: 0.001)
    }

    func test_balances_payerNotInShares_owesNothing() {
        // B pays for A entirely — B has no share of this expense.
        let a = participant("A")
        let b = participant("B")

        expense("B covers A", amount: 60, paidBy: b, shares: [(a, 60)])
        // B: +60 (paid) − 0 (no share) = +60
        // A: −60

        let bal = balanceMap()
        XCTAssertEqual(bal["B"]!,  60.0, accuracy: 0.001)
        XCTAssertEqual(bal["A"]!, -60.0, accuracy: 0.001)
    }

    // MARK: - Balance: multiple expenses

    func test_balances_multipleExpenses_multiplePayersNoShares() {
        let maya = participant("Maya")
        let dev  = participant("Dev")
        let nora = participant("Nora")

        // Cabin: maya pays $300, even split ($100 each)
        // Food:  dev pays $150, even split ($50 each)
        //
        // After Cabin: Maya +200, Dev −100, Nora −100
        // After Food:  Maya +200−50=+150, Dev −100+150−50=0, Nora −100−50=−150
        expense("Cabin", amount: 300, paidBy: maya)
        expense("Food",  amount: 150, paidBy: dev)

        let b = balanceMap()
        XCTAssertEqual(b["Maya"]!,   150.0, accuracy: 0.001)
        XCTAssertEqual(b["Dev"]!,      0.0, accuracy: 0.001)
        XCTAssertEqual(b["Nora"]!,  -150.0, accuracy: 0.001)
    }

    // MARK: - Balance: conservation of money

    /// The signed balances must always sum to zero — no money is created or destroyed.
    func test_balances_sumIsAlwaysZero() {
        let maya = participant("Maya")
        let dev  = participant("Dev")
        let nora = participant("Nora")

        expense("Cabin",    amount: 300, paidBy: maya)
        expense("Food",     amount: 90,  paidBy: dev)
        expense("Gas",      amount: 75,  paidBy: nora)
        expense("Supplies", amount: 45,  paidBy: maya, shares: [(maya, 15), (dev, 15), (nora, 15)])

        let sum = ExpenseCalculator.balances(for: trip).reduce(0) { $0 + $1.amount }
        XCTAssertEqual(sum, 0.0, accuracy: 0.001)
    }

    // MARK: - Balance: edge cases

    func test_balances_singleParticipant_netsToZero() {
        let maya = participant("Maya")
        expense("Solo hotel", amount: 200, paidBy: maya)
        // Paid everything, owes everything — net balance is 0.
        let b = balanceMap()
        XCTAssertEqual(b["Maya"]!, 0.0, accuracy: 0.001)
    }

    func test_balances_noExpenses_allZero() {
        participant("Maya")
        participant("Dev")
        let balances = ExpenseCalculator.balances(for: trip)
        XCTAssertTrue(balances.allSatisfy { abs($0.amount) < 0.001 })
    }

    func test_balances_floatingPointRounding_doesNotAccumulate() {
        // $10 split three ways = $3.333... each. The 0.005 threshold in
        // isOwedMoney / owesMoney means rounding dust doesn't produce phantom debts.
        let maya = participant("Maya")
        let dev  = participant("Dev")
        let nora = participant("Nora")

        let third = 10.0 / 3
        expense("Coffee", amount: 10, paidBy: maya,
                shares: [(maya, third), (dev, third), (nora, third)])

        let sum = ExpenseCalculator.balances(for: trip).reduce(0) { $0 + $1.amount }
        XCTAssertEqual(sum, 0.0, accuracy: 0.01)
    }

    // MARK: - Balance: settlement self-correction

    /// When a debt is recorded as a settlement expense (isSettlement = true), the balance
    /// algorithm counts it the same as any other expense, zeroing both parties' positions.
    func test_balances_settlementExpense_zerosOutDebt() {
        let maya = participant("Maya")
        let dev  = participant("Dev")

        expense("Dinner", amount: 100, paidBy: maya, shares: [(maya, 50), (dev, 50)])
        // Before settlement: Maya +50, Dev −50.

        // Simulate what markPaid does: Dev pays Maya $50.
        let settlementExpense       = ExpenseEntity(context: context)
        settlementExpense.id        = UUID()
        settlementExpense.title     = "Settlement"
        settlementExpense.amount    = 50
        settlementExpense.date      = Date()
        settlementExpense.isSettlement = true
        settlementExpense.trip      = trip
        settlementExpense.paidBy    = dev

        let share         = ExpenseShareEntity(context: context)
        share.id          = UUID()
        share.amount      = 50
        share.expense     = settlementExpense
        share.participant = maya

        let b = balanceMap()
        XCTAssertEqual(b["Maya"]!, 0.0, accuracy: 0.001)
        XCTAssertEqual(b["Dev"]!,  0.0, accuracy: 0.001)
    }

    // MARK: - Settlement suggestions

    func test_suggestions_singleTransferNeeded() {
        let maya = participant("Maya")
        let dev  = participant("Dev")
        let nora = participant("Nora")

        expense("Cabin", amount: 300, paidBy: maya)
        expense("Food",  amount: 150, paidBy: dev)
        // Net: Maya +150, Dev 0, Nora −150 → one transfer: Nora → Maya $150

        let suggestions = ExpenseCalculator.settlementSuggestions(for: trip)
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions[0].from.name, "Nora")
        XCTAssertEqual(suggestions[0].to.name,   "Maya")
        XCTAssertEqual(suggestions[0].amount, 150.0, accuracy: 0.001)
    }

    func test_suggestions_threeWaySplit_twoTransfers() {
        let a = participant("A")
        let b = participant("B")
        let c = participant("C")

        // A pays $90, split equally. B and C each owe A $30.
        expense("Hotel", amount: 90, paidBy: a, shares: [(a, 30), (b, 30), (c, 30)])

        let suggestions = ExpenseCalculator.settlementSuggestions(for: trip)
        XCTAssertEqual(suggestions.count, 2)
        XCTAssertTrue(suggestions.allSatisfy { $0.to.name == "A" },
                      "Both transfers should be directed to A")

        let totalReturned = suggestions.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(totalReturned, 60.0, accuracy: 0.001)
    }

    func test_suggestions_oneDebtorTwoCreditors_correctAmounts() {
        // A owes B $60 and C $40. Two transfers required, no merging possible.
        let a = participant("A")
        let b = participant("B")
        let c = participant("C")

        expense("B paid for A", amount: 60, paidBy: b, shares: [(a, 60)])
        expense("C paid for A", amount: 40, paidBy: c, shares: [(a, 40)])
        // Balances: A −100, B +60, C +40

        let suggestions = ExpenseCalculator.settlementSuggestions(for: trip)
        XCTAssertEqual(suggestions.count, 2)

        let toB = suggestions.first { $0.to.name == "B" }
        let toC = suggestions.first { $0.to.name == "C" }
        XCTAssertNotNil(toB); XCTAssertNotNil(toC)
        XCTAssertEqual(toB?.from.name, "A")
        XCTAssertEqual(toC?.from.name, "A")
        XCTAssertEqual(toB?.amount, 60.0, accuracy: 0.001)
        XCTAssertEqual(toC?.amount, 40.0, accuracy: 0.001)
    }

    func test_suggestions_emptyWhenAllSettled() {
        let maya = participant("Maya")
        let dev  = participant("Dev")

        // Maya pays $100 for both; Dev pays $100 for both.
        // Each person's net share = $100. Each person paid $100. Net: zero each.
        expense("Lunch",  amount: 100, paidBy: maya, shares: [(maya, 50), (dev, 50)])
        expense("Dinner", amount: 100, paidBy: dev,  shares: [(maya, 50), (dev, 50)])

        let suggestions = ExpenseCalculator.settlementSuggestions(for: trip)
        XCTAssertTrue(suggestions.isEmpty)
    }

    func test_suggestions_emptyWhenNoExpenses() {
        participant("Maya")
        participant("Dev")
        XCTAssertTrue(ExpenseCalculator.settlementSuggestions(for: trip).isEmpty)
    }

    func test_suggestions_totalAmountEqualsTotalDebt() {
        // The sum of all suggestion amounts must equal the total owed by debtors.
        let maya = participant("Maya")
        let dev  = participant("Dev")
        let nora = participant("Nora")

        expense("Cabin",    amount: 300, paidBy: maya)
        expense("Food",     amount: 90,  paidBy: dev)
        expense("Activities", amount: 60, paidBy: nora)

        let debtTotal = ExpenseCalculator.balances(for: trip)
            .filter(\.owesMoney)
            .reduce(0) { $0 + abs($1.amount) }

        let suggestionTotal = ExpenseCalculator.settlementSuggestions(for: trip)
            .reduce(0) { $0 + $1.amount }

        XCTAssertEqual(debtTotal, suggestionTotal, accuracy: 0.01)
    }

    // MARK: - Stable Identifiable IDs

    func test_balance_idIsParticipantID() {
        let maya = participant("Maya")
        let b1   = Balance(participant: maya, amount:  100)
        let b2   = Balance(participant: maya, amount: -200) // same participant, different amount
        XCTAssertEqual(b1.id, maya.id, "Balance.id must equal the participant's UUID")
        XCTAssertEqual(b1.id, b2.id,   "Same participant → same ID regardless of amount")
    }

    func test_balance_differentParticipants_differentIDs() {
        let maya = participant("Maya")
        let dev  = participant("Dev")
        let b1   = Balance(participant: maya, amount: 10)
        let b2   = Balance(participant: dev,  amount: 10)
        XCTAssertNotEqual(b1.id, b2.id)
    }

    func test_settlementSuggestion_sameFromTo_sameIDRegardlessOfAmount() {
        let from = participant("Alice")
        let to   = participant("Bob")
        let s1   = SettlementSuggestion(from: from, to: to, amount: 50)
        let s2   = SettlementSuggestion(from: from, to: to, amount: 99)
        XCTAssertEqual(s1.id, s2.id)
    }

    func test_settlementSuggestion_reversedPair_differentID() {
        let alice = participant("Alice")
        let bob   = participant("Bob")
        let s1    = SettlementSuggestion(from: alice, to: bob,   amount: 10)
        let s2    = SettlementSuggestion(from: bob,   to: alice, amount: 10)
        XCTAssertNotEqual(s1.id, s2.id, "A→B and B→A must have distinct IDs")
    }

    // MARK: - Balance flags

    func test_balance_isOwedMoney_aboveThreshold() {
        let p = participant("P")
        XCTAssertTrue(Balance(participant: p,  amount:  1.0).isOwedMoney)
        XCTAssertTrue(Balance(participant: p,  amount:  0.006).isOwedMoney)
        XCTAssertFalse(Balance(participant: p, amount:  0.004).isOwedMoney) // below 0.005 threshold
        XCTAssertFalse(Balance(participant: p, amount: -1.0).isOwedMoney)
    }

    func test_balance_owesMoney_belowThreshold() {
        let p = participant("P")
        XCTAssertTrue(Balance(participant: p,  amount: -1.0).owesMoney)
        XCTAssertTrue(Balance(participant: p,  amount: -0.006).owesMoney)
        XCTAssertFalse(Balance(participant: p, amount: -0.004).owesMoney) // above −0.005 threshold
        XCTAssertFalse(Balance(participant: p, amount:  1.0).owesMoney)
    }

    func test_balance_nearZero_isNeitherFlag() {
        let p = participant("P")
        let b = Balance(participant: p, amount: 0.001)
        XCTAssertFalse(b.isOwedMoney)
        XCTAssertFalse(b.owesMoney)
    }
}
