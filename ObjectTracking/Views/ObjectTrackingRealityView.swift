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

            // Hand-tracking for index tip distance AND finger tracing
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

                    // Update distance calculations for all visualizations
                    for viz in objectVisualizations.values {
                        if let d = viz.distanceFromFinger(to: tipPos) {
                            viz.updateDistance(d)
                        }
                    }
                    
                    // Handle finger tracing logic
                    await handleFingerTracing(fingerPosition: tipPos)
                }
            }
        }
        .ignoresSafeArea()
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
            appState.didLeaveImmersiveSpace()
        }
        .overlay(alignment: .topTrailing) {
            // Control buttons for tracing
            VStack(spacing: 10) {
                Button(action: startTracing) {
                    Label("Start Trace", systemImage: "pencil")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green.opacity(0.7))
                        .cornerRadius(10)
                }
                .disabled(isTracing)
                
                Button(action: stopTracing) {
                    Label("Stop Trace", systemImage: "stop.fill")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(10)
                }
                .disabled(!isTracing)
                
                Button(action: clearTrace) {
                    Label("Clear", systemImage: "trash")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.orange.opacity(0.7))
                        .cornerRadius(10)
                }
                
                // Status indicator
                Text(isTracing ? "TRACING" : "READY")
                    .foregroundColor(isTracing ? .green : .white)
                    .font(.caption)
                    .padding(.horizontal)
            }
            .padding()
        }
    }
    
    // MARK: - Finger Tracing Functions
    
    private func handleFingerTracing(fingerPosition: SIMD3<Float>) async {
        let currentTime = CACurrentMediaTime()
        
        // Update finger tracing if active
        if isTracing {
            for viz in objectVisualizations.values {
                viz.updateFingerTrace(fingerWorldPos: fingerPosition)
            }
            
            // Check for automatic stop due to inactivity
            if let lastPos = lastFingerPosition {
                let movement = simd_length(fingerPosition - lastPos)
                if movement > stationaryThreshold {
                    lastMovementTime = currentTime
                } else if currentTime - lastMovementTime > tracingTimeout {
                    stopTracing()
                }
            } else {
                lastMovementTime = currentTime
            }
        }
        
        // Gesture recognition for automatic tracing start
        if !isTracing {
            if let lastPos = lastFingerPosition {
                let movement = simd_length(fingerPosition - lastPos)
                
                if movement < stationaryThreshold {
                    if !fingerStationary {
                        fingerStationary = true
                        // Start timer for stationary detection
                        stationaryTimer?.invalidate()
                        stationaryTimer = Timer.scheduledTimer(withTimeInterval: stationaryDuration, repeats: false) { _ in
                            Task { @MainActor in
                                if self.fingerStationary && !self.isTracing {
                                    self.startTracing()
                                }
                            }
                        }
                    }
                } else {
                    fingerStationary = false
                    stationaryTimer?.invalidate()
                }
            }
        }
        
        lastFingerPosition = fingerPosition
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
