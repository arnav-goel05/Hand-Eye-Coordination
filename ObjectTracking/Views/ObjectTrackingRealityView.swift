//
//  ObjectTrackingRealityView.swift
//

import RealityKit
import ARKit
import SwiftUI
import Combine
import simd

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
    private let fingerTouchThreshold: Float = 0.01 
    
    @State private var updateTask: Task<Void, Never>? = nil

    // Added state to track if straight step tracing is armed but not yet started
    // This stays true until the step changes, so the initial first-dot pinch is only required once per step.
    @State private var traceArmed: Bool = false
    
    // New state to lock tracing after last dot touched until step changes
    @State private var isTracingLocked: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RealityView { content in
                    try? await session.run([worldInfo, handTracking])
                    content.add(root)
                    
                    DispatchQueue.main.async {
                        screenSize = geometry.size
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

            let offset = SIMD3<Float>(0, 0, 0) // 0.5m right, 0.5m up, 1m in front of headset
            let deviceAnchor = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
            let virtualPoint: SIMD3<Float>
            if let deviceAnchor = deviceAnchor {
                virtualPoint = worldPosition(relativeOffset: offset, deviceTransform: deviceAnchor.originFromAnchorTransform)
            } else {
                virtualPoint = offset // fallback
            }
            let viz = ObjectAnchorVisualization(using: worldInfo, dataManager: dataManager, virtualPoint: virtualPoint)
            root.addChild(viz.entity)
            let id = UUID()
            objectVisualizations[id] = viz
            
            updateTask = Task {
                while !Task.isCancelled {
                    let offset = SIMD3<Float>(0, -0.05, -0.75)
                    let deviceAnchor = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
                    let virtualPoint: SIMD3<Float>
                    if let deviceAnchor = deviceAnchor {
                        virtualPoint = worldPosition(relativeOffset: offset, deviceTransform: deviceAnchor.originFromAnchorTransform)
                    } else {
                        virtualPoint = offset
                    }
                    for viz in objectVisualizations.values {
                        viz.update(virtualPoint: virtualPoint)
                    }
                    try? await Task.sleep(nanoseconds: 16_666_667) // ~60 FPS
                }
            }
        }
        .onDisappear {
            // Clean up timers
            stationaryTimer?.invalidate()
            stationaryTimer = nil
            
            updateTask?.cancel()
            updateTask = nil
            
            for viz in objectVisualizations.values {
                root.removeChild(viz.entity)
            }
            objectVisualizations.removeAll()
            trackedAnchors.removeAll()
            buttonPositions.removeAll()
            
            appState.didLeaveImmersiveSpace()
        }
        .onChange(of: dataManager.stepDidChange) { newStep in
            for viz in objectVisualizations.values {
                viz.resetVisualizations()
            }
            traceArmed = false
            isTracingLocked = false
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
            // For the "straight" step:
            // Require the initial pinch at the first dot once per step to arm tracing.
            // Once armed, tracing can start/stop from anywhere by pinching, as in other steps.
            if !traceArmed {
                // Check if user pinches at first dot to arm
                if distance < fingerTouchThreshold && !isTracingLocked {
                    for viz in objectVisualizations.values {
                        if viz.isFingerNearFirstDot(indexTipPosition) {
                            traceArmed = true
                            startTracing()
                            break
                        }
                    }
                } else {
                    // Not pinching, do nothing until pinched at first dot once
                    if isTracing {
                        stopTracing()
                    }
                }
            } else {
                // Once armed, tracing can be started/stopped anywhere by pinching, just like other steps
                if distance < fingerTouchThreshold && !isTracingLocked {
                    if !isTracing {
                        startTracing()
                    }
                    for viz in objectVisualizations.values {
                        viz.updateFingerTrace(fingerWorldPos: indexTipPosition)
                        if viz.isFingerNearLastDot(indexTipPosition) {
                            if isTracing {
                                stopTracing()
                                isTracingLocked = true
                            }
                            break
                        }
                    }
                    lastMovementTime = currentTime
                } else {
                    if isTracing {
                        stopTracing()
                    }
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
    
    /// Projects a local-space offset to world-space using the current device transform.
    private func worldPosition(relativeOffset: SIMD3<Float>, deviceTransform: simd_float4x4) -> SIMD3<Float> {
        let world = deviceTransform * SIMD4<Float>(relativeOffset, 1)
        return SIMD3<Float>(world.x, world.y, world.z)
    }
}

