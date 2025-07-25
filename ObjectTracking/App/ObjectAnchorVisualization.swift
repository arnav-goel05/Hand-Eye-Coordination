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
    // MARK: - Configuration
    private let textHeight: Float = 0.015
    private var distanceObject: Double = 0.0
    private var lastTextUpdateTime: TimeInterval = 0.0
    
    // MARK: - Components
    private let worldInfo: WorldTrackingProvider
    private let dataManager: DataManager
    let entity: Entity
    
    private let headsetLineRenderer: HeadsetLineRenderer
    private let fingerTracker: FingerTracker
    private let distanceCalculator: DistanceCalculator
    
    // MARK: - UI Elements
    private var windowPane: ModelEntity?
    private var instructionText: ModelEntity?
    private let anchorBoundingBox: ObjectAnchor.AxisAlignedBoundingBox
    private var textScale: SIMD3<Float> = [1, 1, 1]
    
    
    // MARK: - Initialization
    @MainActor
    init(
        for anchor: ObjectAnchor,
        using worldInfo: WorldTrackingProvider,
        dataManager: DataManager
    ) {
        self.worldInfo = worldInfo
        self.anchorBoundingBox = anchor.boundingBox
        self.dataManager = dataManager
        
        // 1) Root entity anchored to the object
        let root = Entity()
        root.transform = Transform(matrix: anchor.originFromAnchorTransform)
        self.entity = root
        
        // 2) Initialize components
        self.headsetLineRenderer = HeadsetLineRenderer(parentEntity: root)
        self.fingerTracker = FingerTracker(
            parentEntity: root,
            objectExtents: anchor.boundingBox.extent
        )
        self.distanceCalculator = DistanceCalculator(worldInfo: worldInfo)
        
        // 3) Create UI:
        //    a) Larger, rounded “window” pane behind the text
        createWindowPane()
        //    b) Instruction text on top
        createInstructionText()
    }
    
    // MARK: - Main Update Loop
    func update(with anchor: ObjectAnchor) {
        guard anchor.isTracked,
              let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        else {
            headsetLineRenderer.hideAllDots()
            return
        }
        
        // Update object transform
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
        
        // Update the dotted line from headset to object
        let headsetPos = Transform(matrix: devicePose.originFromAnchorTransform).translation
        let objectPos = entity.transform.translation
        headsetLineRenderer.updateDottedLine(
            from: headsetPos,
            to: objectPos,
            relativeTo: entity
        )
    }
    
    // MARK: - Finger Tracking Interface
    func startTracing() {
        headsetLineRenderer.freezeDots()
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
    
    // MARK: - Distance Interface
    func updateDistance(_ distance: Float) {
        print(String(format: "Distance to red line: %.3f m", distance))
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
    
    // MARK: - Window Pane Creation
    private func createWindowPane() {
        // Increased pane dimensions
        let paneWidth: Float = 0.7
        let paneHeight: Float = 0.08
        let paneDepth: Float = 0
        
        // Larger corner radius for more pronounced rounding
        let cornerRadius: Float = 0.05
        
        // Create a box mesh with rounded corners
        let boxMesh = MeshResource.generateBox(
            size: [paneWidth, paneHeight, paneDepth],
            cornerRadius: cornerRadius
        )
        
        // Semi-transparent white material
        var material = SimpleMaterial()
        material.color = .init(
            tint: UIColor(white: 1.0, alpha: 0.4),
            texture: nil
        )
        
        // Build the pane entity
        let paneEntity = ModelEntity(mesh: boxMesh, materials: [material])
        
        // Position it slightly behind the text
        let yOffset = anchorBoundingBox.extent.y + paneHeight / 2 + 0.045
        let zOffset: Float = -0.01
        paneEntity.transform.translation = [0, yOffset, zOffset]
        
        // Attach to root
        entity.addChild(paneEntity)
        windowPane = paneEntity
    }
    
    // MARK: - Instruction Text Management
    private func createInstructionText() {
        let textString = String(
            format: "Trace the dotted red line from your headset to the object.",
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
        
        // Scale to desired height
        let bounds = textEntity.visualBounds(relativeTo: nil).extents
        let initialHeight = bounds.y
        let scaleValue = textHeight / initialHeight
        textScale = [scaleValue, scaleValue, scaleValue]
        textEntity.transform.scale = textScale
        
        // Center over object, above window pane
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
        let maxAmp = dataManager.maxAmplitude
        let avgAmp = dataManager.averageAmplitude
        let textString = String(
            format: "Trace the dotted red line from your headset to the object.\n Distance from your index finger and the ideal path is %.3f m\n Trace length: %.3f m\n",
            distanceObject,
            traceLength,
        )
        
        // Regenerate mesh and re-center
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

