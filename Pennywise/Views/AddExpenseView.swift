import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddExpenseViewModel

    init(viewModel: AddExpenseViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense") {
                    TextField("Title", text: $viewModel.title)
                    TextField("Amount", text: $viewModel.amount)
                        .keyboardType(.decimalPad)
                    TextField("Note (optional)", text: $viewModel.note, axis: .vertical)
                }

                Section("Paid by") {
                    Picker("Paid by", selection: $viewModel.paidBy) {
                        ForEach(viewModel.participants) { participant in
                            Text(participant.name).tag(Optional(participant))
                        }
                    }
                }

                Section("Split between") {
                    ForEach(viewModel.participants) { participant in
                        Button {
                            viewModel.toggleParticipant(participant)
                        } label: {
                            HStack {
                                Text(participant.name)
                                Spacer()
                                if viewModel.selectedParticipants.contains(participant) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save()
                        dismiss()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
    }
}
