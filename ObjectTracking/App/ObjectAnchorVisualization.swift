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
    
    private let headsetYOffset: Float = -0.15
    private let headsetForwardOffset: Float = 0.25

    private let worldInfo: WorldTrackingProvider
    private let dataManager: DataManager
    let entity: Entity
    
    private let straightLineRenderer1: StraightLineRenderer
    private let straightLineRenderer2: StraightLineRenderer
    private let straightLineRenderer3: StraightLineRenderer
    private let straightLineRenderer4: StraightLineRenderer
    private let zigZagLineRendererBeginner: ZigZagLineRenderer
    private let zigZagLineRendererAdvanced: ZigZagLineRenderer
    private let fingerTracker: FingerTracker
    private let distanceCalculator: DistanceCalculator
    
    private var instructionText: ModelEntity?
    private var textScale: SIMD3<Float> = [1, 1, 1]
    
    var virtualPoint: SIMD3<Float>
    
    /// Returns a point a bit ahead of the headset, with vertical offset, given a Transform.
    private func headsetVirtualPosition(from pose: Transform) -> SIMD3<Float> {
        let forward = normalize(SIMD3<Float>(-pose.matrix.columns.2.x, -pose.matrix.columns.2.y, -pose.matrix.columns.2.z))
        var pos = pose.translation + forward * headsetForwardOffset
        pos.y += headsetYOffset
        return pos
    }
    
    private func adjustedObjectPosition(for step: Step, base: SIMD3<Float>) -> SIMD3<Float> {
        let dx: Float = 0.2
        let dy: Float = 0.25
        switch step {
        case .straight1:
            return base
        case .straight2:
            return SIMD3(base.x + dx, base.y, base.z)
        case .straight3:
            return SIMD3(base.x, base.y + dy, base.z)
        case .straight4:
            return SIMD3(base.x - dx, base.y, base.z)
        default:
            return base
        }
    }
    
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
        
        self.straightLineRenderer1 = StraightLineRenderer(parentEntity: root)
        self.straightLineRenderer2 = StraightLineRenderer(parentEntity: root)
        self.straightLineRenderer3 = StraightLineRenderer(parentEntity: root)
        self.straightLineRenderer4 = StraightLineRenderer(parentEntity: root)
        self.zigZagLineRendererBeginner = ZigZagLineRenderer(parentEntity: root)
        self.zigZagLineRendererAdvanced = ZigZagLineRenderer(parentEntity: root)
        self.fingerTracker = FingerTracker(
            parentEntity: root,
            objectExtents: [0.1, 0.1, 0.1]
        )
        self.distanceCalculator = DistanceCalculator(worldInfo: worldInfo)
        
       // createWindowPane()
       // createInstructionText()
    }
    
    func hideAllButCurrentStepDots() {
        switch dataManager.currentStep {
        case .straight1:
            straightLineRenderer1.showAllDots()
            straightLineRenderer2.hideAllDots()
            straightLineRenderer3.hideAllDots()
            straightLineRenderer4.hideAllDots()
            zigZagLineRendererBeginner.hideAllDots()
            zigZagLineRendererAdvanced.hideAllDots()
        case .straight2:
            straightLineRenderer1.hideAllDots()
            straightLineRenderer2.showAllDots()
            straightLineRenderer3.hideAllDots()
            straightLineRenderer4.hideAllDots()
            zigZagLineRendererBeginner.hideAllDots()
            zigZagLineRendererAdvanced.hideAllDots()
        case .straight3:
            straightLineRenderer1.hideAllDots()
            straightLineRenderer2.hideAllDots()
            straightLineRenderer3.showAllDots()
            straightLineRenderer4.hideAllDots()
            zigZagLineRendererBeginner.hideAllDots()
            zigZagLineRendererAdvanced.hideAllDots()
        case .straight4:
            straightLineRenderer1.hideAllDots()
            straightLineRenderer2.hideAllDots()
            straightLineRenderer3.hideAllDots()
            straightLineRenderer4.showAllDots()
            zigZagLineRendererBeginner.hideAllDots()
            zigZagLineRendererAdvanced.hideAllDots()
        case .zigzagBeginner:
            straightLineRenderer1.hideAllDots()
            straightLineRenderer2.hideAllDots()
            straightLineRenderer3.hideAllDots()
            straightLineRenderer4.hideAllDots()
            zigZagLineRendererBeginner.showAllDots()
            zigZagLineRendererAdvanced.hideAllDots()
        case .zigzagAdvanced:
            straightLineRenderer1.hideAllDots()
            straightLineRenderer2.hideAllDots()
            straightLineRenderer3.hideAllDots()
            straightLineRenderer4.hideAllDots()
            zigZagLineRendererBeginner.hideAllDots()
            zigZagLineRendererAdvanced.showAllDots()
        }
    }
    
    func update(virtualPoint newVirtualPoint: SIMD3<Float>) {
        
        hideAllButCurrentStepDots()
        
        virtualPoint = newVirtualPoint
        
        guard let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            switch dataManager.currentStep {
            case .straight1:
                straightLineRenderer1.hideAllDots()
            case .straight2:
                straightLineRenderer2.hideAllDots()
            case .straight3:
                straightLineRenderer3.hideAllDots()
            case .straight4:
                straightLineRenderer4.hideAllDots()
            case .zigzagBeginner:
                zigZagLineRendererBeginner.hideAllDots()
            case .zigzagAdvanced:
                zigZagLineRendererAdvanced.hideAllDots()
            }
            return
        }
        
        let pose = Transform(matrix: devicePose.originFromAnchorTransform)
        let headsetPos = headsetVirtualPosition(from: pose)
        let objectPos = adjustedObjectPosition(for: dataManager.currentStep, base: virtualPoint)
        
        // Move headsetPos and objectPos closer to each other by t
        let t1: Float = 0
        let t2: Float = 0
        let closerHeadsetPos = simd_mix(headsetPos, objectPos, SIMD3<Float>(repeating: t1))
        let closerObjectPos = simd_mix(objectPos, headsetPos, SIMD3<Float>(repeating: t2))
        
        switch dataManager.currentStep {
        case .straight1:
            straightLineRenderer1.updateDottedLine(
                from: closerHeadsetPos,
                to: closerObjectPos,
                relativeTo: entity
            )
        case .straight2:
            straightLineRenderer2.updateDottedLine(
                from: closerHeadsetPos,
                to: closerObjectPos,
                relativeTo: entity
            )
        case .straight3:
            straightLineRenderer3.updateDottedLine(
                from: closerHeadsetPos,
                to: closerObjectPos,
                relativeTo: entity
            )
        case .straight4:
            straightLineRenderer4.updateDottedLine(
                from: closerHeadsetPos,
                to: closerObjectPos,
                relativeTo: entity
            )
        case .zigzagBeginner:
            zigZagLineRendererBeginner.updateZigZagLine(
                from: closerHeadsetPos,
                to: closerObjectPos,
                relativeTo: entity,
                amplitude: 0.05,
                frequency: 4
            )
        case .zigzagAdvanced:
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
        switch dataManager.currentStep {
        case .straight1:
            straightLineRenderer1.freezeDots()
        case .straight2:
            straightLineRenderer2.freezeDots()
        case .straight3:
            straightLineRenderer3.freezeDots()
        case .straight4:
            straightLineRenderer4.freezeDots()
        case .zigzagBeginner:
            zigZagLineRendererBeginner.freezeDots()
        case .zigzagAdvanced:
            zigZagLineRendererAdvanced.freezeDots()
        }
        fingerTracker.startTracing()
       // updateInstructionText()
    }
    
    func stopTracing() {
        fingerTracker.stopTracing()
        let stepType = dataManager.currentStep
        // userTrace now stores tuples of (position, timestamp)
        let userTrace: [(SIMD3<Float>, TimeInterval)] = fingerTracker.getTimedTracePoints()
        if let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) {
            let pose = Transform(matrix: devicePose.originFromAnchorTransform)
            let headsetPos = headsetVirtualPosition(from: pose)
            
            let objectPos = adjustedObjectPosition(for: stepType, base: virtualPoint)

            let t1: Float = 0
            let t2: Float = 0
            let closerHeadsetPos = simd_mix(headsetPos, objectPos, SIMD3<Float>(repeating: t1))
            let closerObjectPos = simd_mix(objectPos, headsetPos, SIMD3<Float>(repeating: t2))
            
            switch stepType {
            case .straight1:
                dataManager.straight1HeadsetPosition = closerHeadsetPos
                dataManager.straight1ObjectPosition = closerObjectPos
            case .straight2:
                dataManager.straight2HeadsetPosition = closerHeadsetPos
                dataManager.straight2ObjectPosition = closerObjectPos
            case .straight3:
                dataManager.straight3HeadsetPosition = closerHeadsetPos
                dataManager.straight3ObjectPosition = closerObjectPos
            case .straight4:
                dataManager.straight4HeadsetPosition = closerHeadsetPos
                dataManager.straight4ObjectPosition = closerObjectPos
            case .zigzagBeginner:
                dataManager.zigzagBeginnerHeadsetPosition = closerHeadsetPos
                dataManager.zigzagBeginnerObjectPosition = closerObjectPos
            case .zigzagAdvanced:
                dataManager.zigzagAdvancedHeadsetPosition = closerHeadsetPos
                dataManager.zigzagAdvancedObjectPosition = closerObjectPos
            }
        }
        dataManager.setUserTrace(userTrace, for: stepType)
       // updateInstructionText()
    }
    
    func clearTrace() {
        fingerTracker.clearTrace()
       // updateInstructionText()
    }
    
    func updateFingerTrace(fingerWorldPos: SIMD3<Float>) {
        fingerTracker.updateFingerTrace(
            fingerWorldPos: fingerWorldPos,
            relativeTo: entity
        )
    }
    
    func isFingerNearFirstDot(_ fingerWorldPos: SIMD3<Float>, threshold: Float = 0.02) -> Bool {
        let firstDotWorldPos: SIMD3<Float>?
        switch dataManager.currentStep {
        case .straight1:
            firstDotWorldPos = straightLineRenderer1.getFirstDotWorldPosition(relativeTo: entity)
        case .straight2:
            firstDotWorldPos = straightLineRenderer2.getFirstDotWorldPosition(relativeTo: entity)
        case .straight3:
            firstDotWorldPos = straightLineRenderer3.getFirstDotWorldPosition(relativeTo: entity)
        case .straight4:
            firstDotWorldPos = straightLineRenderer4.getFirstDotWorldPosition(relativeTo: entity)
        case .zigzagBeginner:
            firstDotWorldPos = zigZagLineRendererBeginner.getFirstDotWorldPosition(relativeTo: entity)
        case .zigzagAdvanced:
            firstDotWorldPos = zigZagLineRendererAdvanced.getFirstDotWorldPosition(relativeTo: entity)
        }
        guard let firstDot = firstDotWorldPos else { return false }
        return simd_distance(fingerWorldPos, firstDot) < threshold
    }
    
    func isFingerNearLastDot(_ fingerWorldPos: SIMD3<Float>, threshold: Float = 0.02) -> Bool {
        let lastDotWorldPos: SIMD3<Float>?
        switch dataManager.currentStep {
        case .straight1:
            lastDotWorldPos = straightLineRenderer1.getLastDotWorldPosition(relativeTo: entity)
        case .straight2:
            lastDotWorldPos = straightLineRenderer2.getLastDotWorldPosition(relativeTo: entity)
        case .straight3:
            lastDotWorldPos = straightLineRenderer3.getLastDotWorldPosition(relativeTo: entity)
        case .straight4:
            lastDotWorldPos = straightLineRenderer4.getLastDotWorldPosition(relativeTo: entity)
        case .zigzagBeginner:
            lastDotWorldPos = zigZagLineRendererBeginner.getLastDotWorldPosition(relativeTo: entity)
        case .zigzagAdvanced:
            lastDotWorldPos = zigZagLineRendererAdvanced.getLastDotWorldPosition(relativeTo: entity)
        }
        guard let lastDot = lastDotWorldPos else { return false }
        return simd_distance(fingerWorldPos, lastDot) < threshold
    }
    
    func getTracePoints() -> [SIMD3<Float>] {
        let traceWithTime = fingerTracker.getTimedTracePoints()
        return traceWithTime.map { $0.0 }
    }
    
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
        if dataManager.currentStep == .zigzagBeginner {
            zigZagLineRendererBeginner.showAllDots()
        } else {
            zigZagLineRendererAdvanced.showAllDots()
        }
    }

    func hideZigZagLine() {
        if dataManager.currentStep == .zigzagBeginner {
            zigZagLineRendererBeginner.hideAllDots()
        } else {
            zigZagLineRendererAdvanced.hideAllDots()
        }
    }
    
    func updateDistance(_ distance: Float) {
        print(String(format: "Distance to white line: %.3f m", distance))
        let newDistance = Double(distance)
        let now = CACurrentMediaTime()
        if abs(newDistance - distanceObject) > 0.005,
           now - lastTextUpdateTime >= 0.1 {
            distanceObject = newDistance
            lastTextUpdateTime = now
          //  updateInstructionText()
        }
    }
    
    func distanceFromFinger(to fingerWorldPos: SIMD3<Float>) -> Float? {
        if let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) {
            let pose = Transform(matrix: devicePose.originFromAnchorTransform)
            let headsetPos = headsetVirtualPosition(from: pose)
            let objectPos = virtualPoint
            
            let t1: Float = 0
            let t2: Float = 0
            let closerHeadsetPos = simd_mix(headsetPos, objectPos, SIMD3<Float>(repeating: t1))
            let closerObjectPos = simd_mix(objectPos, headsetPos, SIMD3<Float>(repeating: t2))
            
            return distanceCalculator.distanceFromFingerToLine(
                fingerWorldPos: fingerWorldPos,
                objectWorldPos: closerHeadsetPos,
            )
        }
        return nil
    }
    
    func resetVisualizations() {
        switch dataManager.currentStep {
        case .straight1:
            straightLineRenderer1.hideAllDots()
        case .straight2:
            straightLineRenderer2.hideAllDots()
        case .straight3:
            straightLineRenderer3.hideAllDots()
        case .straight4:
            straightLineRenderer4.hideAllDots()
        case .zigzagBeginner:
            zigZagLineRendererBeginner.hideAllDots()
        case .zigzagAdvanced:
            zigZagLineRendererAdvanced.hideAllDots()
        }
        fingerTracker.clearTrace()
       // updateInstructionText()
    }
    
//    private func createWindowPane() {
//        let paneWidth: Float = 0.7
//        let paneHeight: Float = 0.08
//        let paneDepth: Float = 0
//        
//        let cornerRadius: Float = 0.05
//        
//        let boxMesh = MeshResource.generateBox(
//            size: [paneWidth, paneHeight, paneDepth],
//            cornerRadius: cornerRadius
//        )
//        
//        var material = SimpleMaterial()
//        material.color = .init(
//            tint: UIColor(white: 1.0, alpha: 0.4),
//            texture: nil
//        )
//        
//        let paneEntity = ModelEntity(mesh: boxMesh, materials: [material])
//
//        let yOffset = virtualPoint.y + paneHeight / 2 + 0.045
//        let zOffset: Float = -0.01
//        paneEntity.transform.translation = [0, yOffset, zOffset]
//        
//       // entity.addChild(paneEntity)
//       // windowPane = paneEntity
//    }
    
//    private func createInstructionText() {
//        let textString = "Trace the white line from your headset to the object."
//        
//        let mesh = MeshResource.generateText(
//            textString,
//            extrusionDepth: 0.001,
//            font: .systemFont(ofSize: 0.1),
//            containerFrame: .zero,
//            alignment: .center,
//            lineBreakMode: .byWordWrapping
//        )
//        let material = SimpleMaterial(color: .black, isMetallic: false)
//        let textEntity = ModelEntity(mesh: mesh, materials: [material])
//        
//        let bounds = textEntity.visualBounds(relativeTo: nil).extents
//        let initialHeight = bounds.y
//        let scaleValue = textHeight / initialHeight
//        textScale = [scaleValue, scaleValue, scaleValue]
//        textEntity.transform.scale = textScale
//        
//        let textWidth = bounds.x * scaleValue
//        let topOffset = virtualPoint.y + 0.05 + textHeight
//        textEntity.transform.translation = [
//            -0.25,
//             topOffset,
//             0
//        ]
//        
//        entity.addChild(textEntity)
//        instructionText = textEntity
//    }
//    
//    private func updateInstructionText() {
//        computeMaxAmplitude()
//        computeAverageAmplitude()
//        
//        guard let textEntity = instructionText else { return }
//        
//        let traceLength = getTraceLength()
//        dataManager.setTotalTraceLength(traceLength)
//        let textString = String(
//            format: "Trace the white line from your headset to the object.\n Distance from your index finger and the ideal path is %.3f m\n Trace length: %.3f m\n",
//            distanceObject,
//            traceLength
//        )
//        
//        let newMesh = MeshResource.generateText(
//            textString,
//            extrusionDepth: 0.001,
//            font: .systemFont(ofSize: 0.1),
//            containerFrame: .zero,
//            alignment: .center,
//            lineBreakMode: .byWordWrapping
//        )
//        textEntity.model?.mesh = newMesh
//        
//        let bounds = textEntity.visualBounds(relativeTo: nil).extents
//        let textWidth = bounds.x
//        let topOffset = virtualPoint.y + 0.05 + textHeight
//        
//        textEntity.transform.translation = [
//            -0.25,
//             topOffset,
//             0
//        ]
//        textEntity.transform.scale = textScale
//    }
//    
//    private func computeAmplitudes() -> [Float] {
//        guard
//            let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()),
//            !fingerTracker.getTimedTracePoints().isEmpty
//        else {
//            return []
//        }
//        
//        let pose = Transform(matrix: devicePose.originFromAnchorTransform)
//        let headsetPos = headsetVirtualPosition(from: pose)
//        let objectPos  = adjustedObjectPosition(for: dataManager.currentStep, base: virtualPoint)
//        
//        // Interpolate positions to move them closer as in update(virtualPoint:)
//        let t1: Float = 0.5
//        let t2: Float = 0
//        let closerHeadsetPos = simd_mix(headsetPos, objectPos, SIMD3<Float>(repeating: t1))
//        let closerObjectPos = simd_mix(objectPos, headsetPos, SIMD3<Float>(repeating: t2))
//        
//        let lineVec    = closerObjectPos - closerHeadsetPos
//        let lineLen    = simd_length(lineVec)
//        guard lineLen > 0 else { return [] }
//        
//        let normLine = lineVec / lineLen
//        
//        // Map using only positions, ignore timestamps
//        return fingerTracker.getTimedTracePoints().map { ptWithTime in
//            let pt = ptWithTime.0
//            let vecToPt        = pt - closerHeadsetPos
//            let projLen        = simd_dot(vecToPt, normLine)
//            let closestOnLine  = closerHeadsetPos + normLine * projLen
//            return simd_length(pt - closestOnLine)
//        }
//    }
//    
//    private func computeMaxAmplitude() {
//        let amplitudes = computeAmplitudes()
//        let maxAmp = amplitudes.max() ?? 0
//        dataManager.setMaxAmplitude(maxAmp)
//    }
//    
//    private func computeAverageAmplitude() {
//        let amplitudes = computeAmplitudes()
//        let avgAmp = amplitudes.isEmpty
//        ? 0
//        : amplitudes.reduce(0, +) / Float(amplitudes.count)
//        dataManager.setAverageAmplitude(avgAmp)
//    }
}

