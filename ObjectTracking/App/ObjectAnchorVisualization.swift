// ObjectAnchorVisualization.swift
// I3D-stroke-rehab
//
// See the LICENSE.txt file for this sample's licensing information.
//
// Abstract:
// Main visualization coordinator for object anchors with instruction text,
// a larger, more rounded “window” pane behind it, and component management.

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
    private let anchorBoundingBox: ObjectAnchor.AxisAlignedBoundingBox
    private var textScale: SIMD3<Float> = [1, 1, 1]
    
    @MainActor
    init(
        for anchor: ObjectAnchor,
        using worldInfo: WorldTrackingProvider,
        dataManager: DataManager
    ) {
        self.worldInfo = worldInfo
        self.anchorBoundingBox = anchor.boundingBox
        self.dataManager = dataManager
        
        let root = Entity()
        root.transform = Transform(matrix: anchor.originFromAnchorTransform)
        self.entity = root
        
        self.straightLineRenderer = StraightLineRenderer(parentEntity: root)
        self.zigZagLineRendererBeginner = ZigZagLineRenderer(parentEntity: root)
        self.zigZagLineRendererAdvanced = ZigZagLineRenderer(parentEntity: root)
        self.fingerTracker = FingerTracker(
            parentEntity: root,
            objectExtents: anchor.boundingBox.extent
        )
        self.distanceCalculator = DistanceCalculator(worldInfo: worldInfo)
        
        createWindowPane()
        createInstructionText()
    }
    
    func update(with anchor: ObjectAnchor) {
        guard anchor.isTracked,
              let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        else {
            dataManager.currentStep == .straight
            ? straightLineRenderer.hideAllDots()
            : dataManager.currentStep == .zigzagBeginner
            ? zigZagLineRendererBeginner.hideAllDots()
            : zigZagLineRendererAdvanced.hideAllDots()
            return
        }
        
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
        
        let headsetPos = Transform(matrix: devicePose.originFromAnchorTransform).translation
        let objectPos = entity.transform.translation
        if dataManager.currentStep == .straight {
                    straightLineRenderer.updateDottedLine(
                        from: headsetPos,
                        to: objectPos,
                        relativeTo: entity
                    )
        } else if dataManager.currentStep == .zigzagBeginner {
            zigZagLineRendererBeginner.updateZigZagLine(
                from: headsetPos,
                to: objectPos,
                relativeTo: entity,
                amplitude: 0.05,
                frequency: 4
            )
        } else {
            zigZagLineRendererAdvanced.updateZigZagLine(
                from: headsetPos,
                to: objectPos,
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
    
    func getTracePoints() -> [SIMD3<Float>] {
        fingerTracker.getTracePoints()
    }
    
    func getTraceLength() -> Float {
        fingerTracker.getTraceLength()
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
        return distanceCalculator.distanceFromFingerToLine(
            fingerWorldPos: fingerWorldPos,
            objectWorldPos: entity.transform.translation
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

        let yOffset = anchorBoundingBox.extent.y + paneHeight / 2 + 0.045
        let zOffset: Float = -0.01
        paneEntity.transform.translation = [0, yOffset, zOffset]
        
        entity.addChild(paneEntity)
        windowPane = paneEntity
    }
    
    private func createInstructionText() {
        let textString = String(
            format: "Trace the white line from your headset to the object.",
            distanceObject
        )
        
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
        let topOffset = anchorBoundingBox.extent.y + 0.05 + textHeight
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
        
        let traceLength = fingerTracker.getTraceLength()
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
        let topOffset = anchorBoundingBox.extent.y + 0.05 + textHeight
        
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
            !fingerTracker.getTracePoints().isEmpty
        else {
            return []
        }
        
        let headsetPos = Transform(matrix: devicePose.originFromAnchorTransform).translation
        let objectPos  = entity.transform.translation
        let lineVec    = objectPos - headsetPos
        let lineLen    = simd_length(lineVec)
        guard lineLen > 0 else { return [] }
        
        let normLine = lineVec / lineLen
        
        return fingerTracker.getTracePoints().map { pt in
            let vecToPt        = pt - headsetPos
            let projLen        = simd_dot(vecToPt, normLine)
            let closestOnLine  = headsetPos + normLine * projLen
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

