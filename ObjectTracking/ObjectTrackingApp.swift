/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The app's entry point.
*/

import SwiftUI

private enum UIIdentifier {
    static let immersiveSpace = "Object tracking"
}

@main
@MainActor
struct ObjectTrackingApp: App {
    @State private var appState = AppState()
    @StateObject private var dataManager = DataManager()
    
    var body: some Scene {
        WindowGroup(id: "Main") {
            HomeView(
                appState: appState,
                immersiveSpaceIdentifier: UIIdentifier.immersiveSpace
            )
            .task {
                if appState.allRequiredProvidersAreSupported {
                    await appState.referenceObjectLoader.loadBuiltInReferenceObjects()
                }
            }
        }
        .windowStyle(.plain)
        .environmentObject(dataManager)

        ImmersiveSpace(id: UIIdentifier.immersiveSpace) {
            ObjectTrackingRealityView(appState: appState)
        }
        .environmentObject(dataManager)

        WindowGroup(id: "Summary") {
            SummaryView()
        }
        .environmentObject(dataManager)
    }
}
