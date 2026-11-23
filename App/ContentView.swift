import SwiftUI

/// The library is the root of the single navigation stack (screens.md §Navigation model).
struct ContentView: View {
    var body: some View {
        LibraryView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Session.self, Segment.self, SessionNote.self], inMemory: true)
}
