import SwiftUI

struct TripDetailView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @StateObject private var viewModel: TripDetailViewModel
    @State private var isAddingExpense = false
    @State private var reminder: BalanceReminder?

    init(viewModel: TripDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            totalSection
            peopleSection
            expensesSection
            balancesSection
            settleUpSection
        }
        .navigationTitle(viewModel.trip.name)
        .toolbar {
            Button {
                isAddingExpense = true
            } label: {
                Label("Add Expense", systemImage: "plus")
            }
            .disabled(viewModel.trip.participantsArray.isEmpty)
        }
        .sheet(isPresented: $isAddingExpense, onDismiss: viewModel.refresh) {
            AddExpenseView(viewModel: AddExpenseViewModel(
                trip: viewModel.trip,
                context: viewModel.trip.managedObjectContext ?? PersistenceController.shared.container.viewContext
            ))
        }
        .sheet(item: $reminder) { r in
            MailComposer(reminder: r)
        }
        .onAppear(perform: viewModel.refresh)
    }

    // MARK: - Sections

    private var totalSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(preferences.formatted(viewModel.trip.totalSpent))
                    .font(.largeTitle.weight(.bold))
                Text("Total trip spending")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }

    private var peopleSection: some View {
        Section("People") {
            ForEach(viewModel.trip.participantsArray) { participant in
                VStack(alignment: .leading, spacing: 2) {
                    Text(participant.name)
                    if let email = participant.email, !email.isEmpty {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            DisclosureGroup("Add participant") {
                TextField("Name", text: $viewModel.participantName)
                TextField("Email (optional)", text: $viewModel.participantEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                Button("Add") {
                    viewModel.addParticipant()
                }
                .disabled(viewModel.participantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var expensesSection: some View {
        Section("Expenses") {
            if viewModel.trip.expensesArray.isEmpty {
                ContentUnavailableView("No expenses yet", systemImage: "receipt")
            } else {
                ForEach(viewModel.trip.expensesArray) { expense in
                    ExpenseRow(expense: expense)
                }
                .onDelete(perform: viewModel.deleteExpenses)
            }
        }
    }

    private var balancesSection: some View {
        Section("Balances") {
            ForEach(viewModel.balances) { balance in
                HStack {
                    Text(balance.participant.name)
                    Spacer()
                    Text(preferences.formatted(balance.amount))
                        .foregroundStyle(balanceColor(for: balance.amount))
                }
            }
        }
    }

    private var settleUpSection: some View {
        Section("Settle Up") {
            if viewModel.suggestions.isEmpty {
                Label("Everyone is settled", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.suggestions) { suggestion in
                    SettlementRow(
                        suggestion: suggestion,
                        onRemind: {
                            reminder = MailReminderService.reminder(
                                for: suggestion,
                                trip: viewModel.trip,
                                preferences: preferences
                            )
                        },
                        onMarkPaid: {
                            viewModel.markPaid(suggestion)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func balanceColor(for amount: Double) -> Color {
        if amount > 0.005  { return .green }
        if amount < -0.005 { return .red   }
        return .secondary
    }
}

// MARK: - Subviews

private struct ExpenseRow: View {
    @EnvironmentObject private var preferences: PreferencesStore
    let expense: ExpenseEntity

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(expense.title)
                    .font(.headline)
                Spacer()
                Text(preferences.formatted(expense.amount))
            }
            HStack {
                Text("Paid by \(expense.paidBy.name)")
                Spacer()
                Text(Self.dateFormatter.string(from: expense.date))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let note = expense.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SettlementRow: View {
    @EnvironmentObject private var preferences: PreferencesStore
    let suggestion: SettlementSuggestion
    let onRemind: () -> Void
    let onMarkPaid: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(suggestion.from.name) pays \(suggestion.to.name)")
                .font(.headline)
            Text(preferences.formatted(suggestion.amount))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button(action: onRemind) {
                    Label("Remind", systemImage: "envelope")
                }
                .disabled(!MailReminderService.canSendMail || (suggestion.from.email?.isEmpty ?? true))

                Spacer()

                Button(action: onMarkPaid) {
                    Label("Mark Paid", systemImage: "checkmark")
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}
