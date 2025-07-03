//
//  ObjectAnchorVisualization.swift
//  I3D-stroke-rehab
//
//  See the LICENSE.txt file for this sample’s licensing information.
//
//  Abstract:
//  Attaches an instruction panel above a detected object and draws a live dotted red line from the headset to the object.
//
import ARKit
import RealityKit
import SwiftUI

@MainActor
class ObjectAnchorVisualization {
    // MARK: - Configuration
    private let textHeight: Float       = 0.03
    private let viewWidth: Float        = 0.60
    private let viewHeight: Float       = 0.08
    private let dotRadius: Float        = 0.002
    private let dotSpacing: Float       = 0.05 // meters between centers of dots

    /// Provider for querying the device’s world pose.
    private let worldInfo: WorldTrackingProvider

    /// Root entity anchored to the detected object.
    let entity: Entity

    /// Container for dot segments; created once.
    private var lineContainer: Entity

    @MainActor
    init(
        for anchor: ObjectAnchor,
        using worldInfo: WorldTrackingProvider
    ) {
        self.worldInfo = worldInfo

        // 1) Root container at the object’s anchor transform
        let root = Entity()
        root.transform = Transform(matrix: anchor.originFromAnchorTransform)
        root.isEnabled = anchor.isTracked
        self.entity = root

        // 2) Create instruction text
        let instruction = Entity.createText(
            "Trace the dotted red line from your headset to the object",
            height: textHeight
        )
        let bounds    = instruction.visualBounds(relativeTo: nil).extents
        let textWidth = Float(bounds.x)
        let topOffset = anchor.boundingBox.extent.y + 0.05
        instruction.transform.translation = [
            -textWidth / 2,
            topOffset + textHeight,
            0
        ]

        // 4) Attach panel + text
        root.addChild(instruction)

        // 5) Prepare container for dotted line segments
        let container = Entity()
        container.name = "device→object"
        container.isEnabled = false // hidden until first valid update
        root.addChild(container)
        self.lineContainer = container
    }

    /// Call whenever ARKit updates the ObjectAnchor.
    func update(with anchor: ObjectAnchor) {
        entity.isEnabled = anchor.isTracked
        guard anchor.isTracked else {
            lineContainer.isEnabled = false
            return
        }

        // Move the root entity to the new object pose
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)

        // Query the device’s world-space pose
        guard
            let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        else {
            lineContainer.isEnabled = false
            return
        }
        let devicePos = Transform(matrix: devicePose.originFromAnchorTransform).translation
        let objectPos = entity.transform.translation

        // Compute vector from headset → object
        let vector = objectPos - devicePos
        let length = simd_length(vector)

        // Hide line if too short
        guard length >= dotSpacing else {
            lineContainer.isEnabled = false
            return
        }

        // Show and clear previous dots
        lineContainer.isEnabled = true
        lineContainer.children.forEach { lineContainer.removeChild($0) }

        // Normalize direction
        let dir = normalize(vector)
        // Number of dots along the line
        let count = Int(length / dotSpacing)
        for i in 0...count {
            let t = Float(i) / Float(count)
            let posWorld = devicePos + vector * t
            // Convert to object-local space
            let posLocal = entity.convert(position: posWorld, from: nil)

            // Create a small sphere for this dot
            let mesh    = MeshResource.generateSphere(radius: dotRadius)
            let material = SimpleMaterial(color: .init(red: 1, green: 0, blue: 0, alpha: 1), isMetallic: false)
            let dot     = ModelEntity(mesh: mesh, materials: [material])
            dot.transform.translation = posLocal
            lineContainer.addChild(dot)
        }
    }
}
