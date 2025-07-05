// ObjectAnchorVisualization.swift
// I3D-stroke-rehab
//
// See the LICENSE.txt file for this sample's licensing information.
//
// Abstract:
// Attaches a static 3D instruction label above a detected object
// and draws a live dotted red line from the headset.
// Finger-to-line distances are printed to the console.

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
    
    private let worldInfo: WorldTrackingProvider
    let entity: Entity

    /// Container for pooled red-dot spheres
    private let lineContainer: Entity
    private var dotEntities: [ModelEntity] = []
    
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
        
        // 2) Pre-pool red-dot spheres
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
        
        // 3) Create instruction text centered above object
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
        
        let textString = "Trace the dotted red line from your headset to the object: \(String(format: "%.3f", distanceObject))m"
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
