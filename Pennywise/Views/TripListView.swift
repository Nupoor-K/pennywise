import SwiftUI

struct TripListView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @StateObject private var viewModel: TripListViewModel
    @State private var isAddingTrip = false

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: TripListViewModel(context: context))
    }

    var body: some View {
        List {
            Section("Settings") {
                Picker("Currency", selection: $preferences.currencyCode) {
                    ForEach(preferences.supportedCurrencies, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
            }

            Section("Trips") {
                if viewModel.trips.isEmpty {
                    ContentUnavailableView(
                        "No trips yet",
                        systemImage: "airplane",
                        description: Text("Tap + to create your first trip.")
                    )
                } else {
                    ForEach(viewModel.trips) { trip in
                        NavigationLink {
                            TripDetailView(viewModel: TripDetailViewModel(
                                trip: trip,
                                context: trip.managedObjectContext ?? PersistenceController.shared.container.viewContext
                            ))
                        } label: {
                            TripRow(trip: trip)
                        }
                    }
                    .onDelete(perform: viewModel.deleteTrips)
                }
            }
        }
        .navigationTitle("Pennywise")
        .toolbar {
            Button {
                isAddingTrip = true
            } label: {
                Label("Add Trip", systemImage: "plus")
            }
        }
        .sheet(isPresented: $isAddingTrip) {
            AddTripSheet(viewModel: viewModel)
        }
        .onAppear(perform: viewModel.fetchTrips)
    }
}

private struct TripRow: View {
    @EnvironmentObject private var preferences: PreferencesStore
    let trip: TripEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trip.name)
                .font(.headline)
            Text("\(trip.participants.count) people · \(preferences.formatted(trip.totalSpent)) spent")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
