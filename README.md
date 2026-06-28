# Pennywise

**A privacy-first iOS expense splitter for group trips.**

Log what was paid, see who owes what, and settle up with the fewest transfers possible — entirely on-device, no account required.

---

## Features

- **Trip management** — Create trips and add participants at any point during the trip
- **Expense logging** — Record who paid, how much, and which participants to split it between
- **Live balances** — See each person's running net balance as expenses are added
- **Optimal settlements** — Get the minimum number of transfers needed to fully settle up (at most N−1 for N participants)
- **Mark as paid** — Record payments with a full audit trail; balances update automatically
- **Email reminders** — Send a nudge directly from the app to anyone who hasn't paid yet
- **Currency support** — Choose from USD, EUR, GBP, CAD, AUD, JPY, and INR

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Architecture | MVVM |
| Persistence | Core Data (programmatic schema) |
| Platform | iOS 17+ |
| Dependencies | None |
| Tests | XCTest |

The Core Data schema is defined entirely in code inside `PersistenceController.makeModel()` rather than an `.xcdatamodeld` file. The full entity graph — attributes, relationships, delete rules, and inverses — lives in one readable place, with no dependency on the Xcode visual editor.

---

## How It Works

### Balance Calculation

For each expense, the payer is credited the full amount and each participant is debited their share. A participant's net balance is the sum of those credits and debits across all expenses — no special cases needed.

### Settlement Minimization

Settlement suggestions use a greedy creditor/debtor algorithm: sort all participants by balance, then repeatedly match the largest creditor with the largest debtor until everyone is settled. This produces at most N−1 transfers for N participants and is optimal for the most common real-world arrangements (one person who fronted most costs, or one person who paid for nothing).

### Self-Correcting Settlements

When a debt is marked as paid, the app records the payment as a regular expense with an `isSettlement` flag rather than mutating existing records. The balance algorithm treats it identically to any other transaction, so balances self-correct without any special logic. Settlement entries are filtered from the expense list in the UI and preserved in `SettlementEntity` for audit history.

---

## Getting Started

**Requirements:** Xcode 15+ · iOS 17+

```bash
git clone https://github.com/Nupoor-K/Pennywise.git
open Pennywise/Pennywise.xcodeproj
```

Press **Run** (⌘R). No configuration, API keys, or accounts needed.

> **Starting from scratch (no `.xcodeproj`):** Create a new iOS App project in Xcode named `Pennywise`, drag in the `Pennywise/` source folder, and link the `MessageUI` framework to the target. No `.xcdatamodeld` file is needed — the schema is built in code.

---

## Running Tests

In Xcode: **⌘U**

From the command line:

```bash
xcodebuild test \
  -scheme Pennywise \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Tests live in `PennywiseTests/ExpenseCalculatorTests.swift` and cover:

- Balance calculation with even splits across varying participant subsets
- Money conservation invariant (balances always sum to zero)
- Settlement minimization correctness
- Floating-point rounding edge cases (e.g. $10.00 ÷ 3)
- Settlement self-correction behavior
- Stable `Identifiable` IDs across Core Data refreshes

---

## Project Structure

```
Pennywise/
├── Models/
│   ├── CoreDataEntities.swift      # Core Data entity definitions (programmatic)
│   └── Balance.swift               # Balance and SettlementSuggestion value types
├── Views/
│   ├── ContentView.swift           # Navigation root
│   ├── TripListView.swift          # All trips
│   ├── TripDetailView.swift        # Expenses, balances, and settlements for a trip
│   ├── AddTripSheet.swift          # New trip form
│   └── AddExpenseView.swift        # New expense form
├── ViewModels/
│   ├── TripListViewModel.swift
│   ├── TripDetailViewModel.swift
│   └── AddExpenseViewModel.swift
├── Services/
│   ├── ExpenseCalculator.swift     # Balance and settlement logic
│   ├── PreferencesStore.swift      # Currency selection and formatting
│   └── MailReminderService.swift   # In-app email composition
└── Persistence/
    └── PersistenceController.swift # Core Data stack and schema
```

---

## Known Limitations

| Feature | Status |
|---|---|
| Custom split amounts | Data model supports it; UI not yet implemented |
| Editing expenses | Delete and re-create for now |
| Deleting participants | Requires a migration strategy for existing shares |
| iCloud sync | Deferred — merge conflict resolution for offline edits is non-trivial |

---

## License

MIT License — see [LICENSE](LICENSE) for details.
