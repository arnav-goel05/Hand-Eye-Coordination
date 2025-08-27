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
    
    @State private var buttonPositions: [UUID: CGPoint] = [:]
    @State private var screenSize: CGSize = .zero
    
    @State private var isTracing: Bool = false
    @State private var lastFingerPosition: SIMD3<Float>?
    @State private var tracingStartTime: TimeInterval = 0
    
    @State private var fingerStationary: Bool = false
    @State private var stationaryTimer: Timer?
    @State private var lastMovementTime: TimeInterval = 0
    
    private let stationaryThreshold: Float = 0.01
    private let fingerTouchThreshold: Float = 0.005
    
    @State private var updateTask: Task<Void, Never>? = nil

    @State private var traceArmed: Bool = false
    
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

                            for viz in objectVisualizations.values {
                                if let d = viz.distanceFromFinger(to: indexTipPos) {
                                    viz.updateDistance(d)
                                }
                            }
                            
                            await handleFingerTracing(indexTipPosition: indexTipPos, thumbTipPosition: thumbTipPos)
                        }
                    }
                }
                .ignoresSafeArea()
            }
        }
        .onAppear {
            appState.isImmersiveSpaceOpened = true

            let offset = SIMD3<Float>(0, 0, 0)
            let deviceAnchor = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
            let virtualPoint: SIMD3<Float>
            if let deviceAnchor = deviceAnchor {
                virtualPoint = worldPosition(relativeOffset: offset, deviceTransform: deviceAnchor.originFromAnchorTransform)
            } else {
                virtualPoint = offset
            }
            let viz = ObjectAnchorVisualization(using: worldInfo, dataManager: dataManager, virtualPoint: virtualPoint)
            root.addChild(viz.entity)
            let id = UUID()
            objectVisualizations[id] = viz
            x
            updateTask = Task {
                while !Task.isCancelled {
                    let offset = SIMD3<Float>(0, -0.20, -0.45)
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
                    try? await Task.sleep(nanoseconds: 16_666_667)
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
    
    private func updateButtonPosition(for anchor: ObjectAnchor, id: UUID) async {
        guard let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return
        }
        
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
            let rightOffset: CGFloat = 200
            let buttonPosition = CGPoint(
                x: min(screenPos.x + rightOffset, screenSize.width - 100),
                y: screenPos.y
            )
            
            DispatchQueue.main.async {
                buttonPositions[id] = buttonPosition
            }
        }
    }
    
    private func projectWorldToScreen(
        worldPosition: SIMD3<Float>,
        devicePosition: SIMD3<Float>,
        screenSize: CGSize
    ) -> CGPoint? {
        guard screenSize.width > 0 && screenSize.height > 0 else { return nil }
        
        let objectVector = worldPosition - devicePosition
        
        if objectVector.z > -0.01 { return nil }
        
        let fov: Float = 60.0 * .pi / 180.0
        let aspectRatio = Float(screenSize.width / screenSize.height)
        
        let depth = abs(objectVector.z)
        let x = objectVector.x / depth
        let y = objectVector.y / depth
        
        let tanHalfFov = tan(fov / 2.0)
        let normalizedX = x / tanHalfFov / aspectRatio
        let normalizedY = y / tanHalfFov
        
        if abs(normalizedX) > 1.0 || abs(normalizedY) > 1.0 {
            return nil
        }
        
        let screenX = (normalizedX + 1.0) * 0.5 * Float(screenSize.width)
        let screenY = (1.0 - normalizedY) * 0.5 * Float(screenSize.height)
        
        return CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))
    }
    
    private func handleFingerTracing(indexTipPosition: SIMD3<Float>, thumbTipPosition: SIMD3<Float>) async {
        let currentTime = CACurrentMediaTime()
        if !traceArmed {
            if !isTracingLocked {
                for viz in objectVisualizations.values {
                    if viz.isFingerNearFirstDot(indexTipPosition) {
                        traceArmed = true
                        startTracing()
                        break
                    }
                }
            } else {
                if isTracing {
                    stopTracing()
                }
            }
        } else {
            if !isTracingLocked {
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
    
    private func worldPosition(relativeOffset: SIMD3<Float>, deviceTransform: simd_float4x4) -> SIMD3<Float> {
        let world = deviceTransform * SIMD4<Float>(relativeOffset, 1)
        return SIMD3<Float>(world.x, world.y, world.z)
    }
}

