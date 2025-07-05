// ObjectAnchorVisualization.swift
// I3D-stroke-rehab
//
// See the LICENSE.txt file for this sample's licensing information.
//
// Abstract:
// Attaches a static 3D instruction label above a detected object
// and draws a live dotted red line from the headset.
// Finger-to-line distances are printed to the console.
// NEW: Draws a continuous line tracing the finger's movement path.

import ARKit
import RealityKit
import SwiftUI
import simd

@MainActor
class ObjectAnchorVisualization {
    // MARK: – Configuration
    private let textHeight: Float    = 0.03
    private let dotRadius: Float     = 0.002
    private let dotSpacing: Float    = 0.05
    private let maxDots: Int         = Int(5.0 / 0.05)
    private var distanceObject: Double = 0.0
    private var lastTextUpdateTime: TimeInterval = 0.0
    
    // MARK: - Finger Tracing Configuration
    private let tracePointRadius: Float = 0.003
    private let maxTracePoints: Int = 500
    private let minTraceDistance: Float = 0.005 // Minimum distance to add new point
    
    private let worldInfo: WorldTrackingProvider
    let entity: Entity

    /// Container for pooled red-dot spheres
    private let lineContainer: Entity
    private var dotEntities: [ModelEntity] = []
    
    /// Container for finger trace points
    private let traceContainer: Entity
    private var tracePoints: [SIMD3<Float>] = []
    private var traceEntities: [ModelEntity] = []
    private var isTracing: Bool = false
    
    /// Reference to the instruction text entity for updates
    private var instructionText: ModelEntity?
    private let anchorBoundingBox: ObjectAnchor.AxisAlignedBoundingBox
    
    /// Fixed scale for text to maintain consistent style
    private var textScale: SIMD3<Float> = [1,1,1]

    @MainActor
    init(
        for anchor: ObjectAnchor,
        using worldInfo: WorldTrackingProvider
    ) {
        self.worldInfo = worldInfo
        self.anchorBoundingBox = anchor.boundingBox
        
        // 1) Root entity anchored to the object
        let root = Entity()
        root.transform = Transform(matrix: anchor.originFromAnchorTransform)
        self.entity = root
        
        // 2) Pre-pool red-dot spheres for headset-to-object line
        let container = Entity()
        container.name = "device→object dots"
        root.addChild(container)
        self.lineContainer = container
        
        let sphereMesh = MeshResource.generateSphere(radius: dotRadius)
        let sphereMat  = SimpleMaterial(
            color: .init(red: 1, green: 0, blue: 0, alpha: 1),
            isMetallic: false
        )
        for _ in 0..<maxDots {
            let dot = ModelEntity(mesh: sphereMesh, materials: [sphereMat])
            dot.isEnabled = false
            container.addChild(dot)
            dotEntities.append(dot)
        }
        
        // 3) Create finger trace container and pre-pool trace points
        let traceContainer = Entity()
        traceContainer.name = "finger trace"
        root.addChild(traceContainer)
        self.traceContainer = traceContainer
        
        let traceMesh = MeshResource.generateSphere(radius: tracePointRadius)
        let traceMat = SimpleMaterial(
            color: .init(red: 0, green: 1, blue: 0, alpha: 0.8),
            isMetallic: false
        )
        for _ in 0..<maxTracePoints {
            let tracePoint = ModelEntity(mesh: traceMesh, materials: [traceMat])
            tracePoint.isEnabled = false
            traceContainer.addChild(tracePoint)
            traceEntities.append(tracePoint)
        }
        
        // 4) Create instruction text centered above object
        self.createInstructionText()
    }
    
    // MARK: – Create instruction text
    private func createInstructionText() {
        let textString = "Trace the dotted red line from your headset to the object: \(String(format: "%.3f", distanceObject))m"
        let textMesh = MeshResource.generateText(
            textString,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.1),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])

        // Measure bounds and establish fixed scale
        let bounds = textEntity.visualBounds(relativeTo: nil).extents
        let initialHeight = bounds.y
        let scaleValue = textHeight / initialHeight
        textScale = [scaleValue, scaleValue, scaleValue]
        textEntity.transform.scale = textScale

        // Position centered above object
        let textWidth = Float(bounds.x)
        let topOffset = anchorBoundingBox.extent.y + 0.05
        textEntity.transform.translation = [
            -textWidth * scaleValue / 2,
             topOffset + textHeight,
             0
        ]

        entity.addChild(textEntity)
        instructionText = textEntity
    }

    // MARK: – Update dotted line
    func update(with anchor: ObjectAnchor) {
        lineContainer.isEnabled = anchor.isTracked
        guard anchor.isTracked,
              let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        else {
            dotEntities.forEach { $0.isEnabled = false }
            return
        }
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)

        let headsetPos = Transform(matrix: devicePose.originFromAnchorTransform).translation
        let objectPos  = entity.transform.translation
        let v = objectPos - headsetPos
        let length = simd_length(v)
        let count = min(maxDots - 1, Int(length / dotSpacing))
        for i in 0..<maxDots {
            let dot = dotEntities[i]
            if i <= count {
                let t = Float(i) / Float(max(count,1))
                let worldP = headsetPos + v * t
                let localP = entity.convert(position: worldP, from: nil)
                dot.transform.translation = localP
                dot.isEnabled = true
            } else {
                dot.isEnabled = false
            }
        }
    }

    // MARK: – Finger Tracing Functions
    
    /// Start tracing the finger's movement
    func startTracing() {
        isTracing = true
        clearTrace()
        print("Started finger tracing")
    }
    
    /// Stop tracing the finger's movement
    func stopTracing() {
        isTracing = false
        print("Stopped finger tracing")
    }
    
    /// Clear the current trace
    func clearTrace() {
        tracePoints.removeAll()
        traceEntities.forEach { $0.isEnabled = false }
        print("Cleared finger trace")
    }
    
    /// Update finger trace with new position
    func updateFingerTrace(fingerWorldPos: SIMD3<Float>) {
        guard isTracing else { return }
        
        // Check if we should add a new point (minimum distance threshold)
        if let lastPoint = tracePoints.last {
            let distance = simd_length(fingerWorldPos - lastPoint)
            if distance < minTraceDistance {
                return // Too close to last point, skip
            }
        }
        
        // Add new trace point
        tracePoints.append(fingerWorldPos)
        
        // Remove oldest point if we exceed max points
        if tracePoints.count > maxTracePoints {
            tracePoints.removeFirst()
        }
        
        // Update visual representation
        updateTraceVisualization()
    }
    
    /// Update the visual representation of the trace
    private func updateTraceVisualization() {
        // Hide all trace entities first
        traceEntities.forEach { $0.isEnabled = false }
        
        // Show entities for current trace points
        for (index, worldPos) in tracePoints.enumerated() {
            if index < traceEntities.count {
                let traceEntity = traceEntities[index]
                let localPos = entity.convert(position: worldPos, from: nil)
                traceEntity.transform.translation = localPos
                traceEntity.isEnabled = true
            }
        }
    }
    
    /// Get the current trace as an array of world positions
    func getTracePoints() -> [SIMD3<Float>] {
        return tracePoints
    }
    
    /// Get the trace length in meters
    func getTraceLength() -> Float {
        guard tracePoints.count > 1 else { return 0 }
        
        var totalLength: Float = 0
        for i in 1..<tracePoints.count {
            totalLength += simd_length(tracePoints[i] - tracePoints[i-1])
        }
        return totalLength
    }

    // MARK: – Distance label API
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

    // MARK: – Update instruction text efficiently
    private func updateInstructionText() {
        guard let textEntity = instructionText else { return }
        
        let tracingStatus = isTracing ? "TRACING" : "READY"
        let traceLength = getTraceLength()
        let textString = "Trace the dotted red line from your headset to the object: \(String(format: "%.3f", distanceObject))m\n\(tracingStatus) - Trace length: \(String(format: "%.3f", traceLength))m"
        
        let newMesh = MeshResource.generateText(
            textString,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.1),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        textEntity.model?.mesh = newMesh

        // Re-calc translation for centering
        let bounds = textEntity.visualBounds(relativeTo: nil).extents
        let scaleValue = textScale.x
        let textWidth = Float(bounds.x)
        let topOffset = anchorBoundingBox.extent.y + 0.05
        textEntity.transform.translation = [
                -textWidth / 2,
                topOffset + textHeight,
                0
            ]
        textEntity.transform.scale = textScale
    }

    // MARK: – Distance calculation
    func distanceFromFinger(to fingerWorldPos: SIMD3<Float>) -> Float? {
        guard let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else { return nil }
        let headsetPos = Transform(matrix: devicePose.originFromAnchorTransform).translation
        let objectPos  = entity.transform.translation
        let v = objectPos - headsetPos
        let w = fingerWorldPos - headsetPos
        let c1 = simd_dot(w, v)
        let c2 = simd_dot(v, v)
        guard c2 > 0 else { return simd_length(w) }
        var t = c1 / c2; t = max(0, min(1, t))
        let c = headsetPos + v * t
        return simd_length(fingerWorldPos - c)
    }
}
