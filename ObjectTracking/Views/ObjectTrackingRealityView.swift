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
    @EnvironmentObject var dataManager: DataManager

    private let root = Entity()
    @State private var objectVisualizations: [UUID: ObjectAnchorVisualization] = [:]
    @State private var trackedAnchors: [UUID: ObjectAnchor] = [:]
    
    // MARK: - Button Positioning State
    @State private var buttonPositions: [UUID: CGPoint] = [:]
    @State private var screenSize: CGSize = .zero
    
    // MARK: - Finger Tracing State
    @State private var isTracing: Bool = false
    @State private var lastFingerPosition: SIMD3<Float>?
    @State private var tracingStartTime: TimeInterval = 0
    
    // Gesture recognition for tracing control
    @State private var fingerStationary: Bool = false
    @State private var stationaryTimer: Timer?
    @State private var lastMovementTime: TimeInterval = 0
    
    // Configuration
    private let stationaryThreshold: Float = 0.01 // 1cm
    private let stationaryDuration: TimeInterval = 1.0 // 1 second to start tracing
    private let tracingTimeout: TimeInterval = 5.0 // Stop tracing after 5 seconds of no movement
    private let fingerTouchThreshold: Float = 0.02 // 2cm

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RealityView { content in
                    try? await session.run([worldInfo, handTracking])
                    content.add(root)
                    
                    // Store screen size for calculations
                    DispatchQueue.main.async {
                        screenSize = geometry.size
                    }

                    // Object anchor handling
                    Task {
                        guard let objectTracking = await appState.startTracking() else { return }
                        for await update in objectTracking.anchorUpdates {
                            let anchor = update.anchor, id = anchor.id
                            switch update.event {
                            case .added:
                                let viz = ObjectAnchorVisualization(
                                    for: anchor,
                                    using: worldInfo,
                                    dataManager: dataManager
                                )
                                objectVisualizations[id] = viz
                                trackedAnchors[id] = anchor
                                root.addChild(viz.entity)
                                
                                // Calculate initial button position
                                await updateButtonPosition(for: anchor, id: id)

                            case .updated:
                                objectVisualizations[id]?.update(with: anchor)
                                trackedAnchors[id] = anchor
                                
                                // Update button position
                                await updateButtonPosition(for: anchor, id: id)

                            case .removed:
                                if let viz = objectVisualizations[id] {
                                    root.removeChild(viz.entity)
                                    objectVisualizations.removeValue(forKey: id)
                                    trackedAnchors.removeValue(forKey: id)
                                    buttonPositions.removeValue(forKey: id)
                                }
                            }
                        }
                    }

                    // Hand-tracking for index tip distance AND finger tracing
                    Task {
                        for await update in handTracking.anchorUpdates {
                            let handAnchor = update.anchor
                            guard handAnchor.chirality == .right,
                                  let skel = handAnchor.handSkeleton
                            else { continue }

                            let indexTip = skel.joint(.indexFingerTip)
                            let thumbTip = skel.joint(.thumbTip)
                            guard indexTip.isTracked, thumbTip.isTracked else { continue }

                            let indexWorldMatrix = handAnchor.originFromAnchorTransform * indexTip.anchorFromJointTransform
                            let thumbWorldMatrix = handAnchor.originFromAnchorTransform * thumbTip.anchorFromJointTransform

                            let indexTipPos = SIMD3<Float>(
                                indexWorldMatrix.columns.3.x,
                                indexWorldMatrix.columns.3.y,
                                indexWorldMatrix.columns.3.z
                            )
                            let thumbTipPos = SIMD3<Float>(
                                thumbWorldMatrix.columns.3.x,
                                thumbWorldMatrix.columns.3.y,
                                thumbWorldMatrix.columns.3.z
                            )

                            // Update distance calculations for all visualizations
                            for viz in objectVisualizations.values {
                                if let d = viz.distanceFromFinger(to: indexTipPos) {
                                    viz.updateDistance(d)
                                }
                            }
                            
                            // Handle finger tracing logic with two finger tips
                            await handleFingerTracing(indexTipPosition: indexTipPos, thumbTipPosition: thumbTipPos)
                        }
                    }
                }
                .ignoresSafeArea()
            }
        }
        .onAppear {
            appState.isImmersiveSpaceOpened = true
        }
        .onDisappear {
            // Clean up timers
            stationaryTimer?.invalidate()
            stationaryTimer = nil
            
            for viz in objectVisualizations.values {
                root.removeChild(viz.entity)
            }
            objectVisualizations.removeAll()
            trackedAnchors.removeAll()
            buttonPositions.removeAll()
            
            appState.didLeaveImmersiveSpace()
        }
        .onChange(of: dataManager.stepDidChange) { _, _ in
            for viz in objectVisualizations.values {
                viz.resetVisualizations()
            }
        }
    }
    
    // MARK: - Button Positioning
    private func updateButtonPosition(for anchor: ObjectAnchor, id: UUID) async {
        guard let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return
        }
        
        // Extract translation from transform matrices
        let objectWorldPos = SIMD3<Float>(
            anchor.originFromAnchorTransform.columns.3.x,
            anchor.originFromAnchorTransform.columns.3.y,
            anchor.originFromAnchorTransform.columns.3.z
        )
        
        let deviceWorldPos = SIMD3<Float>(
            devicePose.originFromAnchorTransform.columns.3.x,
            devicePose.originFromAnchorTransform.columns.3.y,
            devicePose.originFromAnchorTransform.columns.3.z
        )
        
        if let screenPos = projectWorldToScreen(
            worldPosition: objectWorldPos,
            devicePosition: deviceWorldPos,
            screenSize: screenSize
        ) {
            // Position buttons to the right of the object
            let rightOffset: CGFloat = 200 // 200 points to the right
            let buttonPosition = CGPoint(
                x: min(screenPos.x + rightOffset, screenSize.width - 100), // Keep within screen bounds
                y: screenPos.y
            )
            
            DispatchQueue.main.async {
                buttonPositions[id] = buttonPosition
            }
        }
    }
    
    // MARK: - World to Screen Projection
    private func projectWorldToScreen(
        worldPosition: SIMD3<Float>,
        devicePosition: SIMD3<Float>,
        screenSize: CGSize
    ) -> CGPoint? {
        guard screenSize.width > 0 && screenSize.height > 0 else { return nil }
        
        // Get the vector from device to object in device space
        let objectVector = worldPosition - devicePosition
        
        // Check if object is in front of the camera (negative Z in camera space)
        if objectVector.z > -0.01 { return nil } // Object is behind or too close
        
        // Project to screen coordinates
        let fov: Float = 60.0 * .pi / 180.0 // 60 degrees vertical FOV
        let aspectRatio = Float(screenSize.width / screenSize.height)
        
        // Calculate normalized device coordinates (-1 to 1)
        let depth = abs(objectVector.z)
        let x = objectVector.x / depth
        let y = objectVector.y / depth
        
        // Apply FOV scaling
        let tanHalfFov = tan(fov / 2.0)
        let normalizedX = x / tanHalfFov / aspectRatio
        let normalizedY = y / tanHalfFov
        
        // Check if object is within view frustum
        if abs(normalizedX) > 1.0 || abs(normalizedY) > 1.0 {
            return nil // Object is outside view
        }
        
        // Convert to screen coordinates (0 to screen dimensions)
        let screenX = (normalizedX + 1.0) * 0.5 * Float(screenSize.width)
        let screenY = (1.0 - normalizedY) * 0.5 * Float(screenSize.height) // Flip Y
        
        return CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))
    }
    
    // MARK: - Finger Tracing Functions
    
    private func handleFingerTracing(indexTipPosition: SIMD3<Float>, thumbTipPosition: SIMD3<Float>) async {
        let currentTime = CACurrentMediaTime()
        let distance = simd_length(indexTipPosition - thumbTipPosition)
        if distance < fingerTouchThreshold {
            if !isTracing {
                startTracing()
            }
            for viz in objectVisualizations.values {
                // Pass only the SIMD3<Float> position as required
                viz.updateFingerTrace(fingerWorldPos: indexTipPosition)
            }
            lastMovementTime = currentTime
        } else {
            if isTracing {
                stopTracing()
            }
        }
        lastFingerPosition = indexTipPosition
    }
    
    private func startTracing() {
        isTracing = true
        tracingStartTime = CACurrentMediaTime()
        lastMovementTime = CACurrentMediaTime()
        fingerStationary = false
        stationaryTimer?.invalidate()
        
        for viz in objectVisualizations.values {
            viz.startTracing()
        }
        
        print("Started finger tracing")
    }
    
    private func stopTracing() {
        isTracing = false
        fingerStationary = false
        stationaryTimer?.invalidate()
        
        for viz in objectVisualizations.values {
            viz.stopTracing()
        }
        
        let tracingDuration = CACurrentMediaTime() - tracingStartTime
        print("Stopped finger tracing after \(String(format: "%.2f", tracingDuration)) seconds")
    }
    
    private func clearTrace() {
        for viz in objectVisualizations.values {
            viz.clearTrace()
        }
        print("Cleared all finger traces")
    }
}

