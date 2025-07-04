//
//  ObjectTrackingRealityView.swift
//
import RealityKit
import ARKit
import SwiftUI
import Combine

extension ARKitSession: ObservableObject {}
extension WorldTrackingProvider: ObservableObject {}
extension HandTrackingProvider: ObservableObject {}

@MainActor
struct ObjectTrackingRealityView: View {
    @State var appState: AppState

    @StateObject private var session      = ARKitSession()
    @StateObject private var worldInfo    = WorldTrackingProvider()
    @StateObject private var handTracking = HandTrackingProvider()

    private let root = Entity()
    @State private var objectVisualizations: [UUID: ObjectAnchorVisualization] = [:]

    var body: some View {
        RealityView { content in
            try? await session.run([worldInfo, handTracking])
            content.add(root)

            // Object anchor handling
            Task {
                guard let objectTracking = await appState.startTracking() else { return }
                for await update in objectTracking.anchorUpdates {
                    let anchor = update.anchor, id = anchor.id
                    switch update.event {
                    case .added:
                        let viz = ObjectAnchorVisualization(
                            for: anchor,
                            using: worldInfo
                        )
                        objectVisualizations[id] = viz
                        root.addChild(viz.entity)

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

            // Hand-tracking for index tip distance
            Task {
                for await update in handTracking.anchorUpdates {
                    let handAnchor = update.anchor
                    guard handAnchor.chirality == .right,
                          let skel = handAnchor.handSkeleton
                    else { continue }

                    let joint = skel.joint(.indexFingerTip)
                    guard joint.isTracked else { continue }

                    let worldMatrix = handAnchor.originFromAnchorTransform
                                    * joint.anchorFromJointTransform
                    let tipPos = SIMD3<Float>(
                        worldMatrix.columns.3.x,
                        worldMatrix.columns.3.y,
                        worldMatrix.columns.3.z
                    )

                    for viz in objectVisualizations.values {
                        if let d = viz.distanceFromFinger(to: tipPos) {
                            viz.updateDistance(d)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            appState.isImmersiveSpaceOpened = true
        }
        .onDisappear {
            for viz in objectVisualizations.values {
                root.removeChild(viz.entity)
            }
            objectVisualizations.removeAll()
            appState.didLeaveImmersiveSpace()
        }
    }
}
