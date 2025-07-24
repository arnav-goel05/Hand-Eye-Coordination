// HeadsetLineRenderer.swift
// I3D-stroke-rehab
//
// See the LICENSE.txt file for this sample's licensing information.
//
// Abstract:
// Renders a dotted red line from the headset to the target object.
// Now supports “freezing” the dots so they no longer update once tracing begins.

import ARKit
import RealityKit
import simd
import UIKit

@MainActor
class HeadsetLineRenderer {
    // MARK: - Configuration
    private let dotRadius: Float = 0.002
    private let dotSpacing: Float = 0.05
    private let maxDots: Int = Int(5.0 / 0.05) // Maximum line length of 5 meters

    // MARK: - State
    private var isFrozen: Bool = false         // When true, skip updates

    // MARK: - Entities
    private let lineContainer: Entity
    private var dotEntities: [ModelEntity] = []

    init(parentEntity: Entity) {
        // Create container for pooled red-dot spheres
        let container = Entity()
        container.name = "device→object dots"
        parentEntity.addChild(container)
        self.lineContainer = container

        // Pre-pool red-dot spheres for performance
        createDotPool()
    }

    // MARK: - Freeze Control

    /// Once called, subsequent calls to `updateDottedLine` do nothing.
    func freezeDots() {
        isFrozen = true
    }

    // MARK: - Dot Pool Management

    private func createDotPool() {
        let sphereMesh = MeshResource.generateSphere(radius: dotRadius)
        let sphereMaterial = SimpleMaterial(
            color: .init(red: 1, green: 0, blue: 0, alpha: 0.8),
            isMetallic: false
        )

        for _ in 0..<maxDots {
            let dot = ModelEntity(mesh: sphereMesh, materials: [sphereMaterial])
            dot.isEnabled = false
            lineContainer.addChild(dot)
            dotEntities.append(dot)
        }
    }

    // MARK: - Line Rendering

    /// Update the dotted-line visualization from headset to object.
    /// If `freezeDots()` has been called, this will early-exit.
    func updateDottedLine(
        from headsetPos: SIMD3<Float>,
        to objectPos: SIMD3<Float>,
        relativeTo entity: Entity
    ) {
        guard !isFrozen else { return }

        lineContainer.isEnabled = true

        // Compute vector and total length
        let lineVector = objectPos - headsetPos
        let lineLength = simd_length(lineVector)

        // Determine how many dots to show
        let dotCount = min(maxDots - 1, Int(lineLength / dotSpacing))

        for i in 0..<maxDots {
            let dot = dotEntities[i]

            if i <= dotCount {
                let t = Float(i) / Float(max(dotCount, 1))
                let worldPosition = headsetPos + lineVector * t
                let localPosition = entity.convert(position: worldPosition, from: nil)

                dot.transform.translation = localPosition
                dot.isEnabled = true
            } else {
                dot.isEnabled = false
            }
        }
    }

    // MARK: - Visibility

    func hideAllDots() {
        dotEntities.forEach { $0.isEnabled = false }
        lineContainer.isEnabled = false
    }

    func showAllDots() {
        lineContainer.isEnabled = true
    }

    // MARK: - Configuration Adjustments

    func updateDotAppearance(
        radius: Float? = nil,
        color: UIColor? = nil,
        alpha: Float? = nil
    ) {
        let newRadius = radius ?? dotRadius
        let newColor = color ?? UIColor.red
        let newAlpha = alpha ?? 0.8

        let shouldUpdateMesh = radius != nil
        let shouldUpdateMaterial = color != nil || alpha != nil

        if shouldUpdateMesh || shouldUpdateMaterial {
            let mesh = shouldUpdateMesh
                ? MeshResource.generateSphere(radius: newRadius)
                : nil

            let material = shouldUpdateMaterial
                ? SimpleMaterial(
                    color: .init(red: 1, green: 0, blue: 0, alpha: CGFloat(newAlpha)),
                    isMetallic: false
                )
                : nil

            for dot in dotEntities {
                if let m = mesh {
                    dot.model?.mesh = m
                }
                if let mat = material {
                    dot.model?.materials = [mat]
                }
            }
        }
    }

    // MARK: - Diagnostics

    func getVisibleDotCount() -> Int {
        dotEntities.filter { $0.isEnabled }.count
    }

    func getDotSpacing() -> Float {
        dotSpacing
    }

    func getMaxDotCount() -> Int {
        maxDots
    }

    func getMaxLineLength() -> Float {
        Float(maxDots) * dotSpacing
    }
}
