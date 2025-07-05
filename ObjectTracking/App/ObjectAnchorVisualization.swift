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
    private let lineWidth: Float = 0.005 // Width of the continuous line
    private let maxTracePoints: Int = 500
    private let minTraceDistance: Float = 0.005 // Minimum distance to add new point
    
    private let worldInfo: WorldTrackingProvider
    let entity: Entity

    /// Container for pooled red-dot spheres
    private let lineContainer: Entity
    private var dotEntities: [ModelEntity] = []
    
    /// Container for finger trace line
    private let traceContainer: Entity
    private var tracePoints: [SIMD3<Float>] = []
    private var traceLineEntity: ModelEntity?
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
        
        // 3) Create finger trace container for continuous line
        let traceContainer = Entity()
        traceContainer.name = "finger trace line"
        root.addChild(traceContainer)
        self.traceContainer = traceContainer
        
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
        if let lineEntity = traceLineEntity {
            traceContainer.removeChild(lineEntity)
            traceLineEntity = nil
        }
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
    
    /// Update the visual representation of the trace as a continuous line
    private func updateTraceVisualization() {
        guard tracePoints.count >= 2 else {
            // Remove line if not enough points
            if let lineEntity = traceLineEntity {
                traceContainer.removeChild(lineEntity)
                traceLineEntity = nil
            }
            return
        }
        
        // Convert world positions to local positions relative to the entity
        let localPoints = tracePoints.map { worldPos in
            entity.convert(position: worldPos, from: nil)
        }
        
        // Create line mesh from points
        let lineMesh = createLineMesh(from: localPoints, width: lineWidth)
        
        // Create or update line entity
        if let existingLineEntity = traceLineEntity {
            existingLineEntity.model?.mesh = lineMesh
        } else {
            let lineMaterial = SimpleMaterial(
                color: .init(red: 0.5, green: 1.0, blue: 0.5, alpha: 0.8),
                isMetallic: false
            )
            let lineEntity = ModelEntity(mesh: lineMesh, materials: [lineMaterial])
            traceContainer.addChild(lineEntity)
            traceLineEntity = lineEntity
        }
    }
    
    /// Create a line mesh from a series of points
    private func createLineMesh(from points: [SIMD3<Float>], width: Float) -> MeshResource {
        var vertices: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        var normals: [SIMD3<Float>] = []
        
        let halfWidth = width * 0.5
        
        for i in 0..<points.count {
            let currentPoint = points[i]
            
            // Calculate direction vectors
            let forward: SIMD3<Float>
            if i == 0 {
                forward = normalize(points[i + 1] - currentPoint)
            } else if i == points.count - 1 {
                forward = normalize(currentPoint - points[i - 1])
            } else {
                forward = normalize(points[i + 1] - points[i - 1])
            }
            
            // Calculate perpendicular vector for width
            let up = SIMD3<Float>(0, 1, 0)
            let right = normalize(cross(forward, up))
            let actualUp = normalize(cross(right, forward))
            
            // Create quad vertices for this segment
            let v1 = currentPoint + right * halfWidth + actualUp * halfWidth
            let v2 = currentPoint - right * halfWidth + actualUp * halfWidth
            let v3 = currentPoint - right * halfWidth - actualUp * halfWidth
            let v4 = currentPoint + right * halfWidth - actualUp * halfWidth
            
            let baseIndex = UInt32(vertices.count)
            vertices.append(contentsOf: [v1, v2, v3, v4])
            
            // Add normals
            let normal = actualUp
            normals.append(contentsOf: [normal, normal, normal, normal])
            
            // Create triangles for the quad (if not the last point)
            if i < points.count - 1 {
                // Two triangles per quad
                indices.append(contentsOf: [
                    baseIndex, baseIndex + 1, baseIndex + 2,
                    baseIndex, baseIndex + 2, baseIndex + 3
                ])
            }
        }
        
        // Connect segments
        for i in 0..<points.count - 1 {
            let baseIndex = UInt32(i * 4)
            let nextBaseIndex = UInt32((i + 1) * 4)
            
            // Connect the segments with triangles
            indices.append(contentsOf: [
                baseIndex, nextBaseIndex, baseIndex + 1,
                nextBaseIndex, nextBaseIndex + 1, baseIndex + 1,
                baseIndex + 1, nextBaseIndex + 1, baseIndex + 2,
                nextBaseIndex + 1, nextBaseIndex + 2, baseIndex + 2,
                baseIndex + 2, nextBaseIndex + 2, baseIndex + 3,
                nextBaseIndex + 2, nextBaseIndex + 3, baseIndex + 3,
                baseIndex + 3, nextBaseIndex + 3, baseIndex,
                nextBaseIndex + 3, nextBaseIndex, baseIndex
            ])
        }
        
        var descriptor = MeshDescriptor(name: "TraceLine")
        descriptor.positions = MeshBuffer(vertices)
        descriptor.normals = MeshBuffer(normals)
        descriptor.primitives = .triangles(indices)
        
        return try! MeshResource.generate(from: [descriptor])
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
