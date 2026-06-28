import SwiftUI

struct AddTripSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TripListViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    TextField("Name", text: $viewModel.newTripName)
                }

                Section("Participants") {
                    TextField("Maya, Dev, Nora", text: $viewModel.participantNames, axis: .vertical)
                }
            }
            .navigationTitle("New Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.addTrip()
                        dismiss()
                    }
                    .disabled(viewModel.newTripName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
