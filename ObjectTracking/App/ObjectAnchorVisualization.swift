// ObjectAnchorVisualization.swift
// I3D-stroke-rehab
//
// See the LICENSE.txt file for this sample's licensing information.
//
// Abstract:
// Main visualization coordinator for object anchors with instruction text,
// a larger, more rounded “window” pane behind it, and component management,
// refactored to use a virtual point instead of an object anchor.

import ARKit
import RealityKit
import SwiftUI
import simd

@MainActor
class ObjectAnchorVisualization {
    
    private let textHeight: Float = 0.015
    private var distanceObject: Double = 0.0
    private var lastTextUpdateTime: TimeInterval = 0.0

    private let worldInfo: WorldTrackingProvider
    private let dataManager: DataManager
    let entity: Entity
    
    private let straightLineRenderer: StraightLineRenderer
    private let zigZagLineRendererBeginner: ZigZagLineRenderer
    private let zigZagLineRendererAdvanced: ZigZagLineRenderer
    private let fingerTracker: FingerTracker
    private let distanceCalculator: DistanceCalculator
    
    private var windowPane: ModelEntity?
    private var instructionText: ModelEntity?
    private var textScale: SIMD3<Float> = [1, 1, 1]
    
    var virtualPoint: SIMD3<Float>
    
    @MainActor
    init(
        using worldInfo: WorldTrackingProvider,
        dataManager: DataManager,
        virtualPoint: SIMD3<Float>
    ) {
        self.worldInfo = worldInfo
        self.dataManager = dataManager
        self.virtualPoint = [virtualPoint.x, virtualPoint.y, virtualPoint.z]
        
        let root = Entity()
        root.transform = Transform() // Identity transform at origin
        self.entity = root
        
        self.straightLineRenderer = StraightLineRenderer(parentEntity: root)
        self.zigZagLineRendererBeginner = ZigZagLineRenderer(parentEntity: root)
        self.zigZagLineRendererAdvanced = ZigZagLineRenderer(parentEntity: root)
        self.fingerTracker = FingerTracker(
            parentEntity: root,
            objectExtents: [0.1, 0.1, 0.1] // Provide a default small extent
        )
        self.distanceCalculator = DistanceCalculator(worldInfo: worldInfo)
        
        createWindowPane()
        createInstructionText()
    }
    
    func update(virtualPoint newVirtualPoint: SIMD3<Float>) {
        virtualPoint = newVirtualPoint
        
        guard let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            dataManager.currentStep == .straight
            ? straightLineRenderer.hideAllDots()
            : dataManager.currentStep == .zigzagBeginner
            ? zigZagLineRendererBeginner.hideAllDots()
            : zigZagLineRendererAdvanced.hideAllDots()
            return
        }
        
        let headsetPos = Transform(matrix: devicePose.originFromAnchorTransform).translation
        let objectPos = virtualPoint
        // Move headsetPos and objectPos closer to each other by t
        let t1: Float = 0.325
        let t2: Float = 0
        let closerHeadsetPos = simd_mix(headsetPos, objectPos, SIMD3<Float>(repeating: t1))
        let closerObjectPos = simd_mix(objectPos, headsetPos, SIMD3<Float>(repeating: t2))
        
        if dataManager.currentStep == .straight {
            straightLineRenderer.updateDottedLine(
                from: closerHeadsetPos,
                to: closerObjectPos,
                relativeTo: entity
            )
        } else if dataManager.currentStep == .zigzagBeginner {
            zigZagLineRendererBeginner.updateZigZagLine(
                from: closerHeadsetPos,
                to: closerObjectPos,
                relativeTo: entity,
                amplitude: 0.05,
                frequency: 4
            )
        } else {
            zigZagLineRendererAdvanced.updateZigZagLine(
                from: closerHeadsetPos,
                to: closerObjectPos,
                relativeTo: entity,
                amplitude: 0.05,
                frequency: 8
            )
        }
    }
    
    func startTracing() {
        dataManager.currentStep == .straight
        ? straightLineRenderer.freezeDots()
        : dataManager.currentStep == .zigzagBeginner
        ? zigZagLineRendererBeginner.freezeDots()
        : zigZagLineRendererAdvanced.freezeDots()
        fingerTracker.startTracing()
        updateInstructionText()
    }
    
    func stopTracing() {
        fingerTracker.stopTracing()
        let stepType = dataManager.currentStep
        // userTrace now stores tuples of (position, timestamp)
        let userTrace: [(SIMD3<Float>, TimeInterval)] = fingerTracker.getTimedTracePoints()
        let headsetPos = Transform(matrix: worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())?.originFromAnchorTransform ?? matrix_identity_float4x4).translation
        let objectPos = virtualPoint
        
        // Interpolate positions to move them closer as in update(with:)
        let t1: Float = 0.325
        let t2: Float = 0
        let closerHeadsetPos = simd_mix(headsetPos, objectPos, SIMD3<Float>(repeating: t1))
        let closerObjectPos = simd_mix(objectPos, headsetPos, SIMD3<Float>(repeating: t2))
        
        switch stepType {
        case .straight:
            dataManager.straightHeadsetPosition = closerHeadsetPos
            dataManager.straightObjectPosition = closerObjectPos
        case .zigzagBeginner:
            dataManager.zigzagBeginnerHeadsetPosition = closerHeadsetPos
            dataManager.zigzagBeginnerObjectPosition = closerObjectPos
        case .zigzagAdvanced:
            dataManager.zigzagAdvancedHeadsetPosition = closerHeadsetPos
            dataManager.zigzagAdvancedObjectPosition = closerObjectPos
        }
        dataManager.setUserTrace(userTrace, for: stepType)
        updateInstructionText()
    }
    
    func clearTrace() {
        fingerTracker.clearTrace()
        updateInstructionText()
    }
    
    func updateFingerTrace(fingerWorldPos: SIMD3<Float>) {
        fingerTracker.updateFingerTrace(
            fingerWorldPos: fingerWorldPos,
            relativeTo: entity
        )
    }
    
    /// For the straight step, checks if the given finger world position is near the first dot of the straight line (within a certain threshold).
    func isFingerNearFirstDot(_ fingerWorldPos: SIMD3<Float>, threshold: Float = 0.02) -> Bool {
        let firstDotWorldPos: SIMD3<Float>?
        switch dataManager.currentStep {
        case .straight:
            firstDotWorldPos = straightLineRenderer.getFirstDotWorldPosition(relativeTo: entity)
        case .zigzagBeginner:
            firstDotWorldPos = zigZagLineRendererBeginner.getFirstDotWorldPosition(relativeTo: entity)
        case .zigzagAdvanced:
            firstDotWorldPos = zigZagLineRendererAdvanced.getFirstDotWorldPosition(relativeTo: entity)
        }
        guard let firstDot = firstDotWorldPos else { return false }
        return simd_distance(fingerWorldPos, firstDot) < threshold
    }
    
    /// For the straight step, checks if the given finger world position is near the last dot of the straight line (within a certain threshold).
    func isFingerNearLastDot(_ fingerWorldPos: SIMD3<Float>, threshold: Float = 0.02) -> Bool {
        let lastDotWorldPos: SIMD3<Float>?
        switch dataManager.currentStep {
        case .straight:
            lastDotWorldPos = straightLineRenderer.getLastDotWorldPosition(relativeTo: entity)
        case .zigzagBeginner:
            lastDotWorldPos = zigZagLineRendererBeginner.getLastDotWorldPosition(relativeTo: entity)
        case .zigzagAdvanced:
            lastDotWorldPos = zigZagLineRendererAdvanced.getLastDotWorldPosition(relativeTo: entity)
        }
        guard let lastDot = lastDotWorldPos else { return false }
        return simd_distance(fingerWorldPos, lastDot) < threshold
    }
    
    /// Returns the trace points as an array of positions, ignoring timestamps.
    func getTracePoints() -> [SIMD3<Float>] {
        let traceWithTime = fingerTracker.getTimedTracePoints()
        return traceWithTime.map { $0.0 }
    }
    
    /// Returns the total length of the trace, calculated from positions only.
    func getTraceLength() -> Float {
        let positions = getTracePoints()
        guard positions.count > 1 else { return 0 }
        var length: Float = 0
        for i in 1..<positions.count {
            length += simd_distance(positions[i], positions[i-1])
        }
        return length
    }
    
    func showZigZagLine() {
        dataManager.currentStep == .zigzagBeginner
        ? zigZagLineRendererBeginner.showAllDots()
        : zigZagLineRendererAdvanced.showAllDots()
    }

    func hideZigZagLine() {
        dataManager.currentStep == .zigzagBeginner
        ? zigZagLineRendererBeginner.hideAllDots()
        : zigZagLineRendererAdvanced.hideAllDots()
    }
    
    func updateDistance(_ distance: Float) {
        print(String(format: "Distance to white line: %.3f m", distance))
        let newDistance = Double(distance)
        let now = CACurrentMediaTime()
        if abs(newDistance - distanceObject) > 0.005,
           now - lastTextUpdateTime >= 0.1 {
            distanceObject = newDistance
            lastTextUpdateTime = now
            updateInstructionText()
        }
    }
    
    func distanceFromFinger(to fingerWorldPos: SIMD3<Float>) -> Float? {
        // Instead of using original positions, interpolate headsetPos and virtualPoint like in update(virtualPoint:)
        let headsetPos = Transform(matrix: worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())?.originFromAnchorTransform ?? matrix_identity_float4x4).translation
        let objectPos = virtualPoint
        
        let t1: Float = 0.325
        let t2: Float = 0
        let closerHeadsetPos = simd_mix(headsetPos, objectPos, SIMD3<Float>(repeating: t1))
        let closerObjectPos = simd_mix(objectPos, headsetPos, SIMD3<Float>(repeating: t2))
        
        return distanceCalculator.distanceFromFingerToLine(
            fingerWorldPos: fingerWorldPos,
            objectWorldPos: closerHeadsetPos,
        )
    }
    
    func resetVisualizations() {
        straightLineRenderer.hideAllDots()
        zigZagLineRendererBeginner.hideAllDots()
        zigZagLineRendererAdvanced.hideAllDots()
        fingerTracker.clearTrace()
        updateInstructionText()
    }
    
    private func createWindowPane() {
        let paneWidth: Float = 0.7
        let paneHeight: Float = 0.08
        let paneDepth: Float = 0
        
        let cornerRadius: Float = 0.05
        
        let boxMesh = MeshResource.generateBox(
            size: [paneWidth, paneHeight, paneDepth],
            cornerRadius: cornerRadius
        )
        
        var material = SimpleMaterial()
        material.color = .init(
            tint: UIColor(white: 1.0, alpha: 0.4),
            texture: nil
        )
        
        let paneEntity = ModelEntity(mesh: boxMesh, materials: [material])

        let yOffset = virtualPoint.y + paneHeight / 2 + 0.045
        let zOffset: Float = -0.01
        paneEntity.transform.translation = [0, yOffset, zOffset]
        
        entity.addChild(paneEntity)
        windowPane = paneEntity
    }
    
    private func createInstructionText() {
        let textString = "Trace the white line from your headset to the object."
        
        let mesh = MeshResource.generateText(
            textString,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.1),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        let material = SimpleMaterial(color: .black, isMetallic: false)
        let textEntity = ModelEntity(mesh: mesh, materials: [material])
        
        let bounds = textEntity.visualBounds(relativeTo: nil).extents
        let initialHeight = bounds.y
        let scaleValue = textHeight / initialHeight
        textScale = [scaleValue, scaleValue, scaleValue]
        textEntity.transform.scale = textScale
        
        let textWidth = bounds.x * scaleValue
        let topOffset = virtualPoint.y + 0.05 + textHeight
        textEntity.transform.translation = [
            -0.25,
             topOffset,
             0
        ]
        
        entity.addChild(textEntity)
        instructionText = textEntity
    }
    
    private func updateInstructionText() {
        computeMaxAmplitude()
        computeAverageAmplitude()
        
        guard let textEntity = instructionText else { return }
        
        let traceLength = getTraceLength()
        dataManager.setTotalTraceLength(traceLength)
        let textString = String(
            format: "Trace the white line from your headset to the object.\n Distance from your index finger and the ideal path is %.3f m\n Trace length: %.3f m\n",
            distanceObject,
            traceLength
        )
        
        let newMesh = MeshResource.generateText(
            textString,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.1),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        textEntity.model?.mesh = newMesh
        
        let bounds = textEntity.visualBounds(relativeTo: nil).extents
        let textWidth = bounds.x
        let topOffset = virtualPoint.y + 0.05 + textHeight
        
        textEntity.transform.translation = [
            -0.25,
             topOffset,
             0
        ]
        textEntity.transform.scale = textScale
    }
    
    private func computeAmplitudes() -> [Float] {
        guard
            let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()),
            !fingerTracker.getTimedTracePoints().isEmpty
        else {
            return []
        }
        
        let headsetPos = Transform(matrix: devicePose.originFromAnchorTransform).translation
        let objectPos  = virtualPoint
        
        // Interpolate positions to move them closer as in update(virtualPoint:)
        let t1: Float = 0.325
        let t2: Float = 0
        let closerHeadsetPos = simd_mix(headsetPos, objectPos, SIMD3<Float>(repeating: t1))
        let closerObjectPos = simd_mix(objectPos, headsetPos, SIMD3<Float>(repeating: t2))
        
        let lineVec    = closerObjectPos - closerHeadsetPos
        let lineLen    = simd_length(lineVec)
        guard lineLen > 0 else { return [] }
        
        let normLine = lineVec / lineLen
        
        // Map using only positions, ignore timestamps
        return fingerTracker.getTimedTracePoints().map { ptWithTime in
            let pt = ptWithTime.0
            let vecToPt        = pt - closerHeadsetPos
            let projLen        = simd_dot(vecToPt, normLine)
            let closestOnLine  = closerHeadsetPos + normLine * projLen
            return simd_length(pt - closestOnLine)
        }
    }
    
    private func computeMaxAmplitude() {
        let amplitudes = computeAmplitudes()
        let maxAmp = amplitudes.max() ?? 0
        dataManager.setMaxAmplitude(maxAmp)
    }
    
    private func computeAverageAmplitude() {
        let amplitudes = computeAmplitudes()
        let avgAmp = amplitudes.isEmpty
        ? 0
        : amplitudes.reduce(0, +) / Float(amplitudes.count)
        dataManager.setAverageAmplitude(avgAmp)
    }
}

