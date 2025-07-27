// ZigZagLineRenderer.swift
// I3D-stroke-rehab
//
// Abstract:
// Renders a zig-zag dotted red line from the headset to the target object, similar in structure to HeadsetLineRenderer.

import ARKit
import RealityKit
import simd
import UIKit

@MainActor
class ZigZagLineRenderer {
    // MARK: - Configuration
    private let dotRadius: Float = 0.0015
    private let dotSpacing: Float = 0.001 // Reduced spacing for dense line
    private let maxDots: Int = 1000       // Capped to prevent performance issues
    private let zigZagAmplitude: Float = 0.05
    private let zigZagFrequency: Int = 4

    // MARK: - State
    private var isFrozen: Bool = false // When true, skip updates

    // MARK: - Entities
    private let lineContainer: Entity
    private var dotEntities: [ModelEntity] = []

    init(parentEntity: Entity) {
        // Create container for pooled red-dot spheres
        let container = Entity()
        container.name = "device→object zigzag dots"
        parentEntity.addChild(container)
        self.lineContainer = container

        // Pre-pool red-dot spheres for performance
        createDotPool()
    }

    // MARK: - Freeze Control

    /// Once called, subsequent calls to `updateZigZagLine` do nothing.
    func freezeDots() {
        isFrozen = true
    }

    // MARK: - Dot Pool Management

    private func createDotPool() {
        let sphereMesh = MeshResource.generateSphere(radius: dotRadius)
        let sphereMaterial = SimpleMaterial(
            color: .init(red: 1, green: 1, blue: 1, alpha: 1),
            isMetallic: false
        )

        for _ in 0..<maxDots {
            let dot = ModelEntity(mesh: sphereMesh, materials: [sphereMaterial])
            dot.isEnabled = false
            lineContainer.addChild(dot)
            dotEntities.append(dot)
        }
    }

    // MARK: - Zig-Zag Path Calculation

    /// Generate a zig-zag path from `from` to `to`, returning dotCount + 1 points
    private func computeZigZagPoints(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        count dotCount: Int
    ) -> [SIMD3<Float>] {
        guard dotCount > 0 else { return [start, end] }
        let direction = normalize(end - start)
        let totalLength = simd_length(end - start)

        let up: SIMD3<Float> = abs(direction.y) < 0.99 ? [0, 1, 0] : [1, 0, 0]
        let right = normalize(cross(direction, up))

        var points: [SIMD3<Float>] = []
        for i in 0...dotCount {
            let t = Float(i) / Float(dotCount)
            let point = start + direction * (totalLength * t)

            // Zig-zag offset: alternate left/right (sin wave for smoothness)
            let phase = Float(i) * Float(zigZagFrequency) * .pi / Float(dotCount)
            let amplitude = (i == 0 || i == dotCount) ? 0 : zigZagAmplitude * sin(phase)
            let offset = right * amplitude

            points.append(point + offset)
        }

        return points
    }

    // MARK: - Line Rendering

    /// Update the zig-zag dotted-line visualization from headset to object.
    /// If `freezeDots()` has been called, this will early-exit.
    func updateZigZagLine(
        from headsetPos: SIMD3<Float>,
        to objectPos: SIMD3<Float>,
        relativeTo entity: Entity
    ) {
        guard !isFrozen else { return }

        lineContainer.isEnabled = true

        let lineVector = objectPos - headsetPos
        let lineLength = simd_length(lineVector)

        // Dynamically compute dot count with hard cap
        let computedDotCount = Int(lineLength / dotSpacing)
        let dotCount = min(maxDots - 1, computedDotCount)

        let zigZagPoints = computeZigZagPoints(from: headsetPos, to: objectPos, count: dotCount)

        for i in 0..<maxDots {
            let dot = dotEntities[i]
            if i < zigZagPoints.count {
                let worldPosition = zigZagPoints[i]
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
        let newAlpha = alpha ?? 1

        let shouldUpdateMesh = radius != nil
        let shouldUpdateMaterial = color != nil || alpha != nil

        if shouldUpdateMesh || shouldUpdateMaterial {
            let mesh = shouldUpdateMesh
                ? MeshResource.generateSphere(radius: newRadius)
                : nil

            let material = shouldUpdateMaterial
                ? SimpleMaterial(
                    color: color ?? UIColor(white: 1, alpha: CGFloat(newAlpha)),
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
