import SwiftUI

@main
struct DocuLlamaApp: App {
    @StateObject private var appModel = DataInterface()
    
    var body: some Scene {
        MenuBarExtra("DocuLlama", systemImage: "brain") {
            ContentView()
                .environmentObject(appModel)
        }
        .menuBarExtraStyle(.window)
    }
}
