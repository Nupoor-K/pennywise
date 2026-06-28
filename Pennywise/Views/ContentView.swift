import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var preferences = PreferencesStore.shared

    var body: some View {
        NavigationStack {
            TripListView(context: context)
        }
        .environmentObject(preferences)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
