/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The view shown inside the immersive space.
*/

import RealityKit
import ARKit
import SwiftUI
import Combine

@MainActor
struct ObjectTrackingRealityView: View {
    var appState: AppState
    
    /// 1) Create and hold onto your ARKitSession and WorldTrackingProvider
    private let session   = ARKitSession()
    private let worldInfo = WorldTrackingProvider()
    
    /// 2) A single root entity all visualizations get parented under
    private let root = Entity()
    
    @State private var objectVisualizations: [UUID: ObjectAnchorVisualization] = [:]

    var body: some View {
        RealityView { content in
            // 3) Kick off ARKit with worldInfo
            try? await session.run([worldInfo])
            
            // 4) Add your root container once
            content.add(root)

            Task {
                let objectTracking = await appState.startTracking()
                guard let objectTracking else { return }
                
                for await anchorUpdate in objectTracking.anchorUpdates {
                    let anchor = anchorUpdate.anchor
                    let id     = anchor.id
                    
                    switch anchorUpdate.event {
                    case .added:
                        // 5) Pass in worldInfo when you create each visualization:
                        let visualization = ObjectAnchorVisualization(
                          for: anchor,
                          using: worldInfo
                        )
                        objectVisualizations[id] = visualization
                        root.addChild(visualization.entity)
                        
                    case .updated:
                        objectVisualizations[id]?.update(with: anchor)
                        
                    case .removed:
                        if let viz = objectVisualizations[id] {
                            root.removeChild(viz.entity)
                            objectVisualizations.removeValue(forKey: id)
                        }
                    }
                }
            }
        }
        .onAppear {
            appState.isImmersiveSpaceOpened = true
        }
        .onDisappear {
            // clean up
            for (_, viz) in objectVisualizations {
                root.removeChild(viz.entity)
            }
            objectVisualizations.removeAll()
            appState.didLeaveImmersiveSpace()
        }
    }
}
