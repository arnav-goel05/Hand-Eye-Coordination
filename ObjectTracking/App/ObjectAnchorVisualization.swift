//
//  ObjectAnchorVisualization.swift
//  I3D-stroke-rehab
//
//  See the LICENSE.txt file for this sample’s licensing information.
//
//  Abstract:
//  Attaches a static 3D instruction label above a detected object
//  and draws a live dotted red line from the headset.
//  Finger-to-line distances are printed to the console.
//
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

    private let worldInfo: WorldTrackingProvider
    let entity: Entity

    /// Container for pooled red‐dot spheres
    private let lineContainer: Entity
    private var dotEntities: [ModelEntity] = []

    @MainActor
    init(
        for anchor: ObjectAnchor,
        using worldInfo: WorldTrackingProvider
    ) {
        self.worldInfo = worldInfo

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

        // 3) Static instruction label
        let topOffset = anchor.boundingBox.extent.y + 0.05
        let yOffset   = topOffset + textHeight
        let instructionText = "Trace the dotted red line from your headset to the object"
        guard let instr = Entity.createText(instructionText, height: textHeight) as? ModelEntity
        else { fatalError("createText must return ModelEntity") }

        // Center it horizontally by shifting left by half its width
        let instrWidth = Float(instr.visualBounds(relativeTo: nil).extents.x)
        instr.transform.translation = [
            -instrWidth/2,
             yOffset,
             0
        ]
        root.addChild(instr)
    }

    // MARK: – Update dotted line
    func update(with anchor: ObjectAnchor) {
        // Toggle visibility of the dot pool
        lineContainer.isEnabled = anchor.isTracked

        guard
          anchor.isTracked,
          let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        else {
            dotEntities.forEach { $0.isEnabled = false }
            return
        }

        // Reposition everything to follow the anchor
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)

        let headsetPos = Transform(matrix: devicePose.originFromAnchorTransform).translation
        let objectPos  = entity.transform.translation

        let v      = objectPos - headsetPos
        let length = simd_length(v)
        let count  = min(maxDots - 1, Int(length / dotSpacing))

        for i in 0..<maxDots {
            let dot = dotEntities[i]
            if i <= count {
                let t      = Float(i) / Float(max(count,1))
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
    /// Call this with your fingertip world-position; it prints the
    /// distance to the red line in the console.
    func updateDistance(_ distance: Float) {
        print(String(format: "Distance to red line: %.3f m", distance))
    }

    // MARK: – Distance calculation
    /// Returns the shortest 3D distance from `fingerWorldPos` to the [headset→object] segment.
    func distanceFromFinger(to fingerWorldPos: SIMD3<Float>) -> Float? {
        guard
          let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        else { return nil }
        let headsetPos = Transform(matrix: devicePose.originFromAnchorTransform).translation
        let objectPos  = entity.transform.translation

        let v  = objectPos - headsetPos
        let w  = fingerWorldPos - headsetPos
        let c1 = simd_dot(w, v)
        let c2 = simd_dot(v, v)
        guard c2 > 0 else { return simd_length(w) }
        var t = c1 / c2
        t     = max(0, min(1, t))
        let c = headsetPos + v * t
        return simd_length(fingerWorldPos - c)
    }
}
