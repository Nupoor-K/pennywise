import Combine
import CoreData
import Foundation

final class TripListViewModel: ObservableObject {
    @Published var trips: [TripEntity] = []
    @Published var newTripName = ""
    @Published var participantNames = ""

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        fetchTrips()
    }

    func fetchTrips() {
        let request = NSFetchRequest<TripEntity>(entityName: "TripEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TripEntity.createdAt, ascending: false)]
        do {
            trips = try context.fetch(request)
        } catch {
            assertionFailure("Trip fetch failed: \(error.localizedDescription)")
            trips = []
        }
    }

    func addTrip() {
        let trimmedName = newTripName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let trip = TripEntity(context: context)
        trip.id = UUID()
        trip.name = trimmedName
        trip.createdAt = Date()

        participantNames
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .forEach { name in
                let participant = ParticipantEntity(context: context)
                participant.id = UUID()
                participant.name = name
                participant.trip = trip
            }

        PersistenceController.shared.save()
        newTripName = ""
        participantNames = ""
        fetchTrips()
    }

    func deleteTrips(at offsets: IndexSet) {
        offsets.map { trips[$0] }.forEach(context.delete)
        PersistenceController.shared.save()
        fetchTrips()
    }
}
